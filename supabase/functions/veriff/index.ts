
// Follow this setup guide to integrate the function into your project:
// https://supabase.com/docs/guides/functions

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const VERIFF_METHOD = 'id_document';

serve(async (req) => {
    // Handle CORS preflight requests
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const authHeader = req.headers.get('Authorization')
        const signature = req.headers.get('x-hmac-signature')

        console.log(`Request received. Auth: ${authHeader ? 'Yes' : 'No'}, Signature: ${signature ? 'Yes' : 'No'}`)

        // CASE 1: Webhook from Veriff (Has Signature)
        // We prioritize signature check because Veriff might send an Auth header 
        // that causes auth.getUser() to fail if we check it first.
        if (signature) {
            console.log('Signature found. Handling as Webhook...')
            return await handleWebhook(req)
        }

        // CASE 2: Request from App (Has Auth)
        if (authHeader) {
            console.log('Auth header found without signature. Handling as App Request...')
            // Initialize Supabase Client with the Auth Header (to impersonate user)
            const supabase = createClient(
                Deno.env.get('SUPABASE_URL') ?? '',
                Deno.env.get('SUPABASE_ANON_KEY') ?? '',
                { global: { headers: { Authorization: authHeader } } }
            )

            // Verify the User Token
            const { data: { user }, error } = await supabase.auth.getUser()

            if (error || !user) {
                console.error('Auth Error:', error)
                return new Response(JSON.stringify({ error: 'Auth failed', details: error }), {
                    status: 401,
                    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                })
            }

            console.log(`User authenticated: ${user.id}`)

            const body = await req.json()
            const { action, firstName, lastName } = body

            if (action === 'create_session') {
                return await createVeriffSession(user.id, firstName, lastName)
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

// --------------------------------------------------------------------------
// 1. Create Veriff Session (Called by App)
// --------------------------------------------------------------------------
async function createVeriffSession(userId: string, firstName?: string, lastName?: string) {
    const apiKey = Deno.env.get('VERIFF_API_KEY');
    const sharedSecret = Deno.env.get('VERIFF_SHARED_SECRET');
    const baseUrl = Deno.env.get('VERIFF_BASE_URL') || 'https://stationapi.veriff.com';

    if (!apiKey || !apiKey) {
        throw new Error('Missing Veriff configuration on server');
    }

    const payload = {
        verification: {
            callback: 'https://veriff.com', // User redirect URL
            person: {
                firstName: firstName,
                lastName: lastName
            },
            vendorData: userId // Store userId to link back later
        }
    };

    const body = JSON.stringify(payload);
    const signature = await generateSignature(body, sharedSecret!);

    const response = await fetch(`${baseUrl}/v1/sessions`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'x-auth-client': apiKey,
            'x-hmac-signature': signature
        },
        body: body
    });

    const data = await response.json();

    if (!response.ok) {
        console.error('Veriff API Error:', data);
        throw new Error(`Veriff API Error: ${JSON.stringify(data)}`);
    }

    // Persist session details so webhook upsert doesn't fail on NOT NULL fields
    const supabaseAdmin = createClient(
        Deno.env.get('SUPABASE_URL') ?? '',
        Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    const sessionId = data?.verification?.id;
    const sessionUrl = data?.verification?.url;
    const sessionToken = data?.verification?.sessionToken;

    if (sessionId && sessionUrl) {
        const { error: sessionInsertError } = await supabaseAdmin
            .from('veriff_sessions')
            .upsert({
                veriff_session_id: sessionId,
                user_id: userId,
                session_url: sessionUrl,
                session_token: sessionToken,
                vendor_data: userId,
                status: 'created',
                created_at: new Date().toISOString(),
                updated_at: new Date().toISOString()
            }, { onConflict: 'veriff_session_id' });

        if (sessionInsertError) {
            console.error('Error inserting veriff_sessions from create_session:', sessionInsertError);
        }
    } else {
        console.warn('Veriff session response missing id or url; skipping veriff_sessions insert');
    }

    return new Response(JSON.stringify(data), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
}

// --------------------------------------------------------------------------
// 2. Handle Veriff Webhook (Called by Veriff)
// --------------------------------------------------------------------------
async function handleWebhook(req: Request) {
    const signature = req.headers.get('x-hmac-signature');
    const sharedSecret = Deno.env.get('VERIFF_SHARED_SECRET');
    const bodyText = await req.text();

    if (!signature || !sharedSecret) {
        console.error('Webhook Error: Missing signature or secret');
        return new Response('Missing signature or secret', { status: 401 });
    }

    // Verify signature
    const localSignature = await generateSignature(bodyText, sharedSecret);
    if (localSignature !== signature) {
        console.error('Webhook Error: Invalid signature');
        return new Response('Invalid signature', { status: 401 });
    }

    const data = JSON.parse(bodyText);
    console.log('Webhook Payload received:', JSON.stringify(data, null, 2));

    const verification = data.verification;
    if (!verification) {
        console.warn('Webhook received but no verification data found');
        return new Response(JSON.stringify({ received: true, status: 'no_verification_data' }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
    }

    const status = verification.status; // 'approved', 'declined', etc.
    const userId = verification.vendorData; // We store userId here
    const sessionId = verification.id;
    const reason = verification.reason;

    console.log(`Processing Webhook: Session ${sessionId}, User ${userId}, Status: ${status}`);

    if (!userId) {
        console.error('Webhook Error: Missing userId in vendorData');
        return new Response(JSON.stringify({ error: 'Missing userId' }), { status: 400 });
    }

    const supabaseAdmin = createClient(
        Deno.env.get('SUPABASE_URL') ?? '',
        Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    // 1. Update veriff_sessions table (for history/audit)
    const { error: sessionError } = await supabaseAdmin
        .from('veriff_sessions')
        .upsert({
            veriff_session_id: sessionId,
            user_id: userId,
            status: status,
            vendor_data: userId,
            verification_result: data,
            updated_at: new Date().toISOString()
        }, { onConflict: 'veriff_session_id' });

    if (sessionError) {
        console.error('Error updating veriff_sessions:', sessionError);
    }

    // 2. If approved, update profile and human_verifications
    if (status === 'approved') {
        console.log(`User ${userId} approved. Updating profile and verification records...`);

        // Update Profile
        const { error: profileError } = await supabaseAdmin
            .from('profiles')
            .update({
                verified_human: 'verified',
                verification_method: VERIFF_METHOD,
                verified_at: new Date().toISOString(),
                status: 'active' // Ensure user is active after verification
            })
            .eq('user_id', userId);

        if (profileError) {
            console.error('Error updating profile:', profileError);
        } else {
            console.log(`Successfully updated profile for user ${userId}`);
        }

        // Update human_verifications table (no unique constraint on user_id+method in schema)
        const { data: hvExisting, error: hvFindError } = await supabaseAdmin
            .from('human_verifications')
            .select('id')
            .eq('user_id', userId)
            .eq('method', VERIFF_METHOD)
            .limit(1)
            .maybeSingle();

        if (hvFindError) {
            console.error('Error finding human_verifications:', hvFindError);
        } else if (hvExisting?.id) {
            const { error: hvUpdateError } = await supabaseAdmin
                .from('human_verifications')
                .update({
                    status: 'verified',
                    reviewed_at: new Date().toISOString(),
                    reviewer_notes: `Auto-verified via Veriff. Session: ${sessionId}`
                })
                .eq('id', hvExisting.id);

            if (hvUpdateError) {
                console.error('Error updating human_verifications:', hvUpdateError);
            }
        } else {
            const { error: hvInsertError } = await supabaseAdmin
                .from('human_verifications')
                .insert({
                    user_id: userId,
                    method: VERIFF_METHOD,
                    status: 'verified',
                    reviewed_at: new Date().toISOString(),
                    reviewer_notes: `Auto-verified via Veriff. Session: ${sessionId}`
                });

            if (hvInsertError) {
                console.error('Error inserting human_verifications:', hvInsertError);
            }
        }
    } else if (status === 'declined') {
        console.log(`User ${userId} declined. Reason: ${reason}`);

        const { data: hvExisting, error: hvFindError } = await supabaseAdmin
            .from('human_verifications')
            .select('id')
            .eq('user_id', userId)
            .eq('method', VERIFF_METHOD)
            .limit(1)
            .maybeSingle();

        if (hvFindError) {
            console.error('Error finding human_verifications:', hvFindError);
        } else if (hvExisting?.id) {
            const { error: hvUpdateError } = await supabaseAdmin
                .from('human_verifications')
                .update({
                    status: 'failed',
                    rejection_reason: reason,
                    reviewed_at: new Date().toISOString()
                })
                .eq('id', hvExisting.id);

            if (hvUpdateError) {
                console.error('Error updating human_verifications:', hvUpdateError);
            }
        } else {
            const { error: hvInsertError } = await supabaseAdmin
                .from('human_verifications')
                .insert({
                    user_id: userId,
                    method: VERIFF_METHOD,
                    status: 'failed',
                    rejection_reason: reason,
                    reviewed_at: new Date().toISOString()
                });

            if (hvInsertError) {
                console.error('Error inserting human_verifications:', hvInsertError);
            }
        }
    }

    return new Response(JSON.stringify({ received: true }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
}

// Helper: HMAC-SHA256 Hex Signature
async function generateSignature(payload: string, secret: string): Promise<string> {
    const encoder = new TextEncoder();
    const keyData = encoder.encode(secret);
    const msgData = encoder.encode(payload);

    const key = await crypto.subtle.importKey(
        "raw", keyData, { name: "HMAC", hash: "SHA-256" },
        false, ["sign"]
    );

    const signatureBuffer = await crypto.subtle.sign(
        "HMAC", key, msgData
    );

    // Convert buffer to hex string
    return Array.from(new Uint8Array(signatureBuffer))
        .map(b => b.toString(16).padStart(2, '0'))
        .join('');
}
