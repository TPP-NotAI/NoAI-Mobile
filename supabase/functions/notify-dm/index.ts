import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { create, getNumericDate } from 'https://deno.land/x/djwt@v3.0.2/mod.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
// Shared secret set in Supabase dashboard → Webhooks → Secret
const WEBHOOK_SECRET = Deno.env.get('WEBHOOK_SECRET') ?? '';
// Firebase service account JSON string (set as edge function secret)
const FIREBASE_SERVICE_ACCOUNT = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')!;
const FIREBASE_PROJECT_ID = 'rooverse-production-760d4';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

/** Get a short-lived OAuth2 access token for FCM HTTP v1 API */
async function getFcmAccessToken(): Promise<string> {
  const sa = JSON.parse(FIREBASE_SERVICE_ACCOUNT);
  const now = getNumericDate(0);
  const exp = getNumericDate(60 * 60); // 1 hour

  // Import the RSA private key
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
      exp: exp,
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
  if (!tokenData.access_token) {
    throw new Error(`Failed to get FCM access token: ${JSON.stringify(tokenData)}`);
  }
  return tokenData.access_token;
}

/** Convert PEM private key string to DER ArrayBuffer */
function pemToDer(pem: string): ArrayBuffer {
  const base64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s/g, '');
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

/** Send FCM v1 notification to a single token */
async function sendFcmMessage(
  token: string,
  title: string,
  body: string,
  data: Record<string, string>,
  accessToken: string,
): Promise<void> {
  const message = {
    message: {
      token,
      notification: { title, body },
      data,
      android: {
        priority: 'high',
        notification: { channel_id: 'rooverse_messages', sound: 'default' },
      },
      apns: {
        payload: { aps: { sound: 'default', badge: 1 } },
        headers: { 'apns-priority': '10' },
      },
    },
  };

  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify(message),
    },
  );

  if (!res.ok) {
    const err = await res.text();
    console.error(`FCM send failed for token ${token.slice(-8)}: ${err}`);
  }
}

serve(async (req) => {
  // Verify webhook shared secret
  if (WEBHOOK_SECRET) {
    const incoming = req.headers.get('x-webhook-secret') ?? '';
    if (incoming !== WEBHOOK_SECRET) {
      return new Response('Unauthorized', { status: 401 });
    }
  }

  try {
    const payload = await req.json();
    const record = payload.record;
    if (!record) return new Response('No record', { status: 400 });

    const threadId: string = record.thread_id;
    const senderId: string = record.sender_id;
    const body: string = record.body ?? '';
    const mediaType: string | null = record.media_type ?? null;
    const aiScoreStatus: string | null = record.ai_score_status ?? null;

    // Don't notify for flagged messages
    if (aiScoreStatus === 'flagged') {
      return new Response('Skipped: flagged', { status: 200 });
    }

    // 1. Get the other participant(s)
    const { data: participants, error: partError } = await supabase
      .from('dm_participants')
      .select('user_id')
      .eq('thread_id', threadId)
      .neq('user_id', senderId);

    if (partError || !participants || participants.length === 0) {
      return new Response('No recipients found', { status: 200 });
    }

    const recipientIds: string[] = participants.map((p: any) => p.user_id);

    // 2. Get sender display name
    const { data: senderProfile } = await supabase
      .from('profiles')
      .select('display_name, username')
      .eq('user_id', senderId)
      .maybeSingle();

    const senderName: string =
      senderProfile?.display_name?.trim() || senderProfile?.username || 'Someone';

    // 3. Build notification body
    let notifBody: string;
    if (mediaType === 'image') notifBody = '📷 Photo';
    else if (mediaType === 'video') notifBody = '🎥 Video';
    else if (mediaType === 'document') notifBody = '📎 Document';
    else if (mediaType === 'audio') notifBody = '🎤 Voice message';
    else notifBody = body.length > 100 ? `${body.substring(0, 100)}…` : body;

    if (!notifBody) notifBody = 'Sent you a message';

    // 4. Get FCM tokens for recipients
    const { data: tokenRows, error: tokenError } = await supabase
      .from('user_fcm_tokens')
      .select('token')
      .in('user_id', recipientIds);

    if (tokenError || !tokenRows || tokenRows.length === 0) {
      return new Response('No FCM tokens found', { status: 200 });
    }

    // 5. Get FCM v1 access token and send
    const accessToken = await getFcmAccessToken();
    const data = { type: 'message', thread_id: threadId, sender_id: senderId };

    await Promise.all(
      tokenRows.map((r: any) =>
        sendFcmMessage(r.token, senderName, notifBody, data, accessToken)
      ),
    );

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (err) {
    console.error('notify-dm error:', err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});
