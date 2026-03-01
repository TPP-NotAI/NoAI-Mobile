import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const FCM_SERVER_KEY = Deno.env.get('FCM_SERVER_KEY')!;

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

// Called directly from Flutter after a successful ROO transfer or tip.
// Body: { recipientUserId, type, title, body, data }
serve(async (req) => {
  try {
    const { recipientUserId, type, title, body, data } = await req.json();

    if (!recipientUserId || !title || !body) {
      return new Response('Missing required fields', { status: 400 });
    }

    // 1. Get FCM tokens for recipient
    const { data: tokenRows, error: tokenError } = await supabase
      .from('user_fcm_tokens')
      .select('token')
      .eq('user_id', recipientUserId);

    if (tokenError || !tokenRows || tokenRows.length === 0) {
      return new Response('No FCM tokens found', { status: 200 });
    }

    const tokens: string[] = tokenRows.map((r: any) => r.token);

    // 2. Send FCM push
    const fcmPayload = {
      registration_ids: tokens,
      notification: {
        title,
        body,
        sound: 'default',
      },
      data: {
        type: type ?? 'roo_received',
        ...data,
      },
      android: {
        priority: 'high',
        notification: {
          channel_id: 'rooverse_wallet',
          sound: 'default',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    const fcmResponse = await fetch('https://fcm.googleapis.com/fcm/send', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `key=${FCM_SERVER_KEY}`,
      },
      body: JSON.stringify(fcmPayload),
    });

    const fcmResult = await fcmResponse.json();
    console.log('FCM response:', JSON.stringify(fcmResult));

    return new Response(JSON.stringify({ success: true, fcmResult }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (err) {
    console.error('notify-wallet error:', err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});
