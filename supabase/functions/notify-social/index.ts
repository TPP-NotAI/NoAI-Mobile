import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { create, getNumericDate } from 'https://deno.land/x/djwt@v3.0.2/mod.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const FIREBASE_SERVICE_ACCOUNT = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')!;

const FIREBASE_PROJECT_ID = 'rooverse-production-760d4';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

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

async function getFcmAccessToken(): Promise<string> {
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
  if (!tokenData.access_token) {
    throw new Error(`Failed to get FCM access token: ${JSON.stringify(tokenData)}`);
  }
  return tokenData.access_token;
}

/** Map notification type to Android channel id */
function channelForType(type: string): string {
  switch (type) {
    case 'message':
    case 'dm':
    case 'chat':
      return 'rooverse_messages';
    case 'transaction':
    case 'reward':
    case 'wallet':
    case 'roo_received':
    case 'roo_sent':
    case 'tip_received':
    case 'tip_sent':
      return 'rooverse_wallet';
    default:
      return 'rooverse_social';
  }
}

async function sendFcmMessage(
  token: string,
  title: string,
  body: string,
  data: Record<string, string>,
  channelId: string,
  accessToken: string,
): Promise<void> {
  const message = {
    message: {
      token,
      notification: { title, body },
      data,
      android: {
        priority: 'high',
        notification: { channel_id: channelId, sound: 'default' },
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
  try {
    const payload = await req.json();
    const record = payload.record;
    if (!record) return new Response('No record', { status: 400 });

    const userId: string = record.user_id;
    const type: string = record.type ?? 'social';
    const title: string = record.title ?? 'New notification';
    const body: string = record.body ?? '';
    const notificationId: string = record.id ?? '';
    const postId: string | null = record.post_id ?? null;
    const actorId: string | null = record.actor_id ?? null;
    const commentId: string | null = record.comment_id ?? null;
    const ticketId: string | null = record.ticket_id ?? null;

    if (!userId || !body) {
      return new Response('Missing user_id or body', { status: 400 });
    }

    // Get FCM tokens for this user
    const { data: tokenRows, error: tokenError } = await supabase
      .from('user_fcm_tokens')
      .select('token')
      .eq('user_id', userId);

    if (tokenError || !tokenRows || tokenRows.length === 0) {
      return new Response('No FCM tokens found', { status: 200 });
    }

    const accessToken = await getFcmAccessToken();
    const channelId = channelForType(type);

    // Build data payload (all values must be strings for FCM data)
    const data: Record<string, string> = {
      type,
      notification_id: notificationId,
    };
    if (postId) data.post_id = postId;
    if (actorId) data.actor_id = actorId;
    if (commentId) data.comment_id = commentId;
    if (ticketId) data.ticket_id = ticketId;

    await Promise.all(
      tokenRows.map((r: any) =>
        sendFcmMessage(r.token, title, body, data, channelId, accessToken)
      ),
    );

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (err) {
    console.error('notify-social error:', err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});
