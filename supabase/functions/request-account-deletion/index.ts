// request-account-deletion — Supabase Edge Function
//
// Schedules account deletion in 30 days and immediately notifies the user
// via email, push notification (FCM), and an in-app DM from a system account.
//
// Body: { userId, email, password }
// The function re-verifies credentials server-side before scheduling anything.

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { create, getNumericDate } from 'https://deno.land/x/djwt@v3.0.2/mod.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const FIREBASE_SERVICE_ACCOUNT = Deno.env.get('FIREBASE_SERVICE_ACCOUNT') ?? '';
const FIREBASE_PROJECT_ID = 'rooverse-production-760d4';

// Optional: username of a system/bot account used to send the DM warning.
// Create a bot profile in your DB and set this env var to its user_id.
const SYSTEM_BOT_USER_ID = Deno.env.get('SYSTEM_BOT_USER_ID') ?? '';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// ─── FCM helpers ────────────────────────────────────────────────────────────

function pemToDer(pem: string): ArrayBuffer {
  const base64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s/g, '');
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

async function getFcmAccessToken(): Promise<string | null> {
  if (!FIREBASE_SERVICE_ACCOUNT) return null;
  try {
    const sa = JSON.parse(FIREBASE_SERVICE_ACCOUNT);
    const now = getNumericDate(0);
    const exp = getNumericDate(60 * 60);
    const privateKey = await crypto.subtle.importKey(
      'pkcs8',
      pemToDer(sa.private_key),
      { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
      false,
      ['sign'],
    );
    const jwt = await create(
      { alg: 'RS256', typ: 'JWT' },
      {
        iss: sa.client_email,
        sub: sa.client_email,
        aud: 'https://oauth2.googleapis.com/token',
        iat: now,
        exp,
        scope: 'https://www.googleapis.com/auth/firebase.messaging',
      },
      privateKey,
    );
    const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion: jwt,
      }),
    });
    const tokenData = await tokenRes.json();
    return tokenData.access_token ?? null;
  } catch (e) {
    console.error('getFcmAccessToken error:', e);
    return null;
  }
}

async function sendFcmPush(
  fcmToken: string,
  title: string,
  body: string,
  accessToken: string,
): Promise<void> {
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify({
        message: {
          token: fcmToken,
          notification: { title, body },
          data: { type: 'account_deletion_scheduled' },
          android: {
            priority: 'high',
            notification: { channel_id: 'rooverse_social', sound: 'default' },
          },
          apns: {
            payload: { aps: { sound: 'default', badge: 1 } },
            headers: { 'apns-priority': '10' },
          },
        },
      }),
    },
  );
  if (!res.ok) {
    console.error('FCM push failed:', await res.text());
  }
}

// ─── Main handler ─────────────────────────────────────────────────────────

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  // 1. Parse & validate body
  let userId: string, email: string, password: string;
  try {
    const body = await req.json();
    userId = body.userId;
    email = body.email;
    password = body.password;
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid request body' }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  if (!userId || !email || !password) {
    return new Response(JSON.stringify({ error: 'userId, email and password are required' }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  // 2. Re-verify credentials
  const anonClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  const { data: signInData, error: signInError } = await anonClient.auth.signInWithPassword({
    email,
    password,
  });
  if (signInError || !signInData.user) {
    return new Response(JSON.stringify({ error: 'Invalid credentials' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
  if (signInData.user.id !== userId) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), {
      status: 403,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  // 3. Check if already scheduled
  const { data: profile } = await admin
    .from('profiles')
    .select('status, deletion_scheduled_at, username, display_name, phone_number')
    .eq('user_id', userId)
    .maybeSingle();

  if (profile?.status === 'pending_deletion') {
    return new Response(
      JSON.stringify({ error: 'Account deletion already scheduled', deletion_scheduled_at: profile.deletion_scheduled_at }),
      { status: 409, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }

  // 4. Schedule deletion in 30 days
  const deletionDate = new Date();
  deletionDate.setDate(deletionDate.getDate() + 30);
  const deletionIso = deletionDate.toISOString();
  const deletionReadable = deletionDate.toDateString(); // e.g. "Sat Apr 19 2026"

  const { error: updateError } = await admin
    .from('profiles')
    .update({ status: 'pending_deletion', deletion_scheduled_at: deletionIso })
    .eq('user_id', userId);

  if (updateError) {
    console.error('Failed to schedule deletion:', updateError.message);
    return new Response(JSON.stringify({ error: 'Failed to schedule deletion' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const displayName: string = profile?.display_name?.trim() || profile?.username || 'there';
  const notifTitle = '⚠️ Account Deletion Scheduled';
  const notifBody =
    `Hi ${displayName}, your Rooverse account has been scheduled for permanent deletion on ${deletionReadable}. ` +
    `If this was a mistake, you can cancel the deletion from Settings before that date.`;

  // 5a. In-app notification (notifications table → triggers FCM via notify-social webhook)
  await admin.from('notifications').insert({
    user_id: userId,
    type: 'account_deletion_scheduled',
    title: notifTitle,
    body: notifBody,
  });

  // 5b. Push notification via FCM directly (belt-and-suspenders alongside the webhook)
  try {
    const { data: tokenRows } = await admin
      .from('user_fcm_tokens')
      .select('token')
      .eq('user_id', userId);

    if (tokenRows && tokenRows.length > 0) {
      const accessToken = await getFcmAccessToken();
      if (accessToken) {
        await Promise.all(
          tokenRows.map((r: any) => sendFcmPush(r.token, notifTitle, notifBody, accessToken)),
        );
      }
    }
  } catch (e) {
    console.error('FCM push error (non-fatal):', e);
  }

  // 5c. Email via Supabase Auth admin email
  try {
    await admin.auth.admin.sendRawEmail({
      to: email,
      subject: 'Your Rooverse account is scheduled for deletion',
      html: `
        <div style="font-family:sans-serif;max-width:560px;margin:auto">
          <h2 style="color:#e53935">Account Deletion Notice</h2>
          <p>Hi <strong>${displayName}</strong>,</p>
          <p>
            We received a request to permanently delete your Rooverse account.
            Your account will be <strong>permanently deleted on ${deletionReadable}</strong>.
          </p>
          <p>
            <strong>Changed your mind?</strong><br>
            Open the Rooverse app, go to <em>Settings → Danger Zone → Cancel Deletion</em>
            before ${deletionReadable} to keep your account.
          </p>
          <p style="color:#888;font-size:12px">
            If you did not request this, contact support immediately at support@rooverse.app.
          </p>
        </div>
      `,
    });
  } catch (e) {
    // sendRawEmail may not be available on all Supabase plans — log and continue.
    console.warn('Email send failed (non-fatal):', e);
  }

  // 5d. DM from system bot (if a bot account is configured)
  if (SYSTEM_BOT_USER_ID) {
    try {
      // Find or create a thread between the bot and the user
      const myThreads = await admin
        .from('dm_participants')
        .select('thread_id')
        .eq('user_id', SYSTEM_BOT_USER_ID);

      const myThreadIds = ((myThreads.data ?? []) as any[]).map((t) => t.thread_id);
      let threadId: string | null = null;

      if (myThreadIds.length > 0) {
        const common = await admin
          .from('dm_participants')
          .select('thread_id')
          .eq('user_id', userId)
          .in('thread_id', myThreadIds);

        if (common.data && common.data.length > 0) {
          threadId = common.data[0].thread_id;
        }
      }

      if (!threadId) {
        // Create a new thread
        const { data: thread } = await admin
          .from('dm_threads')
          .insert({ last_message_at: new Date().toISOString() })
          .select()
          .single();

        if (thread) {
          threadId = thread.id;
          await admin.from('dm_participants').insert([
            { thread_id: threadId, user_id: SYSTEM_BOT_USER_ID },
            { thread_id: threadId, user_id: userId },
          ]);
        }
      }

      if (threadId) {
        const dmBody =
          `⚠️ Hi ${displayName}, your account is scheduled for permanent deletion on ${deletionReadable}. ` +
          `If this was a mistake, go to Settings → Danger Zone → Cancel Deletion before that date. ` +
          `Need help? Reply to this message.`;

        await admin.from('dm_messages').insert({
          thread_id: threadId,
          sender_id: SYSTEM_BOT_USER_ID,
          body: dmBody,
          ai_score_status: 'pass', // system messages bypass AI review
        });

        await admin
          .from('dm_threads')
          .update({
            last_message_at: new Date().toISOString(),
            last_message_preview: dmBody.substring(0, 100),
          })
          .eq('id', threadId);
      }
    } catch (e) {
      console.error('DM send error (non-fatal):', e);
    }
  }

  // 5e. SMS via Supabase Auth phone (if phone is registered — Supabase sends OTPs,
  //     but for custom SMS you'd integrate Twilio here. We log for now.)
  //
  //   If you add Twilio later, plug it in here using profile?.phone_number.
  //   const phone = profile?.phone_number;
  //   if (phone) { await sendTwilioSms(phone, notifBody); }

  return new Response(
    JSON.stringify({ success: true, deletion_scheduled_at: deletionIso }),
    { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
  );
});
