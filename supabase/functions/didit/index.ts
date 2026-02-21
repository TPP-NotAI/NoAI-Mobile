// Didit KYC Identity Verification - Supabase Edge Function
// Handles:
//   1. App requests  → create a Didit verification session
//   2. Didit webhooks → process verification decisions and update profiles

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const DIDIT_BASE_URL = 'https://verification.didit.me'
const DIDIT_METHOD = 'id_document'

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get('Authorization')
    const diditSignature = req.headers.get('X-Signature')
    const diditTimestamp = req.headers.get('X-Timestamp')

    console.log(`Request received. Auth: ${authHeader ? 'Yes' : 'No'}, Didit-Signature: ${diditSignature ? 'Yes' : 'No'}`)

    // CASE 1: Webhook from Didit (has X-Signature)
    if (diditSignature) {
      console.log('X-Signature found — handling as Didit webhook...')
      return await handleWebhook(req, diditSignature, diditTimestamp)
    }

    // CASE 2: Request from Flutter app (has Authorization)
    if (authHeader) {
      console.log('Auth header found — handling as app request...')

      // The gateway (--no-verify-jwt disabled) has already verified the JWT.
      // Decode the payload to extract the user id without re-validating.
      const jwt = authHeader.replace('Bearer ', '')
      let gatewayUserId: string | null = null
      try {
        const payloadB64 = jwt.split('.')[1]
        const payloadJson = atob(payloadB64.replace(/-/g, '+').replace(/_/g, '/'))
        const payload = JSON.parse(payloadJson)
        gatewayUserId = payload.sub ?? null
      } catch {
        // malformed token — reject
      }

      if (!gatewayUserId) {
        return new Response(JSON.stringify({ error: 'Auth failed: could not decode token' }), {
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }

      console.log(`User authenticated: ${gatewayUserId}`)

      const body = await req.json()
      const { action, vendor_data, email } = body

      if (action === 'create_session') {
        return await createDiditSession(vendor_data ?? gatewayUserId, email)
      }

      return new Response(JSON.stringify({ error: 'Invalid action' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    return new Response(JSON.stringify({ error: 'Missing headers' }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })

  } catch (error) {
    console.error('Server Error:', error)
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})

// ---------------------------------------------------------------------------
// 1. Create Didit Session  (called by Flutter app)
// ---------------------------------------------------------------------------
async function createDiditSession(userId: string, email?: string) {
  const apiKey = Deno.env.get('DIDIT_API_KEY')
  const workflowId = Deno.env.get('DIDIT_WORKFLOW_ID')

  if (!apiKey || !workflowId) {
    throw new Error('Missing Didit configuration: DIDIT_API_KEY or DIDIT_WORKFLOW_ID not set')
  }

  const payload: Record<string, unknown> = {
    workflow_id: workflowId,
    vendor_data: userId,
    callback: 'rooverse://verification/callback', // deep link back into the app
  }

  if (email) {
    payload.contact_details = { email }
  }

  const response = await fetch(`${DIDIT_BASE_URL}/v2/session/`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Api-Key': apiKey,
    },
    body: JSON.stringify(payload),
  })

  const data = await response.json()

  if (!response.ok) {
    console.error('Didit API Error:', data)
    throw new Error(`Didit API Error: ${JSON.stringify(data)}`)
  }

  console.log(`Didit session created: ${data.session_id}`)

  // Persist session to Supabase for audit trail
  const supabaseAdmin = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  )

  if (data.session_id) {
    const { error: insertError } = await supabaseAdmin
      .from('didit_sessions')
      .upsert({
        session_id: data.session_id,
        user_id: userId,
        session_url: data.url,
        workflow_id: workflowId,
        vendor_data: userId,
        status: 'Not Started',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      }, { onConflict: 'session_id' })

    if (insertError) {
      // Non-fatal: log but don't fail the whole request
      console.warn('Error inserting didit_sessions:', insertError)
    }
  }

  // Return the fields the Flutter app expects
  return new Response(JSON.stringify({
    session_id: data.session_id,
    url: data.url,
    status: data.status,
  }), {
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

// ---------------------------------------------------------------------------
// 2. Handle Didit Webhook  (called by Didit)
// ---------------------------------------------------------------------------
async function handleWebhook(req: Request, signature: string, timestamp: string | null) {
  const webhookSecret = Deno.env.get('DIDIT_WEBHOOK_SECRET')
  if (!webhookSecret) {
    console.error('DIDIT_WEBHOOK_SECRET not set')
    return new Response('Webhook secret not configured', { status: 500 })
  }

  const bodyText = await req.text()

  // Reject stale webhooks (> 5 minutes)
  if (timestamp) {
    const ts = parseInt(timestamp, 10)
    const nowSec = Math.floor(Date.now() / 1000)
    if (Math.abs(nowSec - ts) > 300) {
      console.error('Webhook rejected: timestamp too old')
      return new Response('Timestamp too old', { status: 401 })
    }
  }

  // Verify HMAC-SHA256 signature
  const expectedSig = await generateSignature(bodyText, webhookSecret)
  if (expectedSig !== signature) {
    console.error('Webhook Error: Invalid signature')
    return new Response('Invalid signature', { status: 401 })
  }

  const payload = JSON.parse(bodyText)
  console.log('Didit webhook payload:', JSON.stringify(payload, null, 2))

  const sessionId = payload.session_id as string | undefined
  const status = payload.status as string | undefined          // 'Approved', 'Declined', etc.
  const userId = payload.vendor_data as string | undefined     // We stored userId here
  const decision = payload.decision                            // present when status is final

  if (!sessionId || !status) {
    console.warn('Webhook missing session_id or status')
    return new Response(JSON.stringify({ received: true, status: 'missing_fields' }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  const supabaseAdmin = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  )

  // Update audit table
  // session_url is required (NOT NULL) — use empty string as fallback so an
  // early webhook (arriving before the create-session response is stored) won't
  // fail the constraint. The real URL will have been written by createDiditSession.
  const { error: sessionError } = await supabaseAdmin
    .from('didit_sessions')
    .upsert({
      session_id: sessionId,
      user_id: userId ?? null,
      session_url: payload.url ?? '',
      status: status,
      vendor_data: userId ?? null,
      verification_result: payload,
      updated_at: new Date().toISOString(),
    }, { onConflict: 'session_id' })

  if (sessionError) {
    console.error('Error updating didit_sessions:', sessionError)
  }

  if (!userId) {
    console.error('Webhook: missing userId in vendor_data')
    return new Response(JSON.stringify({ received: true, error: 'Missing userId' }), {
      status: 200, // Return 200 so Didit doesn't retry
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  const statusLower = status.toLowerCase()

  if (statusLower === 'approved') {
    console.log(`User ${userId} approved. Updating profile...`)

    const { error: profileError } = await supabaseAdmin
      .from('profiles')
      .update({
        verified_human: 'verified',
        verification_method: DIDIT_METHOD,
        verified_at: new Date().toISOString(),
        status: 'active',
      })
      .eq('user_id', userId)

    if (profileError) {
      console.error('Error updating profile:', profileError)
    } else {
      console.log(`Profile updated for user ${userId}`)
    }

    await upsertHumanVerification(supabaseAdmin, userId, sessionId, 'verified', null)

  } else if (statusLower === 'declined') {
    const reason = decision?.kyc?.document_status ?? payload.reason ?? 'Declined'
    console.log(`User ${userId} declined. Reason: ${reason}`)

    await upsertHumanVerification(supabaseAdmin, userId, sessionId, 'failed', reason)

  } else {
    // In Review / Abandoned / In Progress — mark as pending
    console.log(`Session ${sessionId} status: ${status}`)

    if (statusLower === 'in review') {
      await supabaseAdmin
        .from('profiles')
        .update({ verified_human: 'pending' })
        .eq('user_id', userId)
    }
  }

  return new Response(JSON.stringify({ received: true }), {
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

// ---------------------------------------------------------------------------
// Helper: upsert human_verifications row
// ---------------------------------------------------------------------------
async function upsertHumanVerification(
  supabaseAdmin: ReturnType<typeof createClient>,
  userId: string,
  sessionId: string,
  status: 'verified' | 'failed',
  rejectionReason: string | null
) {
  const { data: existing, error: findErr } = await supabaseAdmin
    .from('human_verifications')
    .select('id')
    .eq('user_id', userId)
    .eq('method', DIDIT_METHOD)
    .limit(1)
    .maybeSingle()

  if (findErr) {
    console.error('Error finding human_verifications:', findErr)
    return
  }

  const record = {
    status,
    rejection_reason: rejectionReason,
    reviewed_at: new Date().toISOString(),
    reviewer_notes: `Auto-${status} via Didit. Session: ${sessionId}`,
  }

  if (existing?.id) {
    const { error } = await supabaseAdmin
      .from('human_verifications')
      .update(record)
      .eq('id', existing.id)
    if (error) console.error('Error updating human_verifications:', error)
  } else {
    const { error } = await supabaseAdmin
      .from('human_verifications')
      .insert({ user_id: userId, method: DIDIT_METHOD, ...record })
    if (error) console.error('Error inserting human_verifications:', error)
  }
}

// ---------------------------------------------------------------------------
// Helper: HMAC-SHA256 hex signature
// ---------------------------------------------------------------------------
async function generateSignature(payload: string, secret: string): Promise<string> {
  const encoder = new TextEncoder()
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  )
  const sig = await crypto.subtle.sign('HMAC', key, encoder.encode(payload))
  return Array.from(new Uint8Array(sig))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('')
}
