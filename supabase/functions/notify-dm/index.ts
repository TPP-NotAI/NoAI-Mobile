import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const FCM_SERVER_KEY = Deno.env.get('FCM_SERVER_KEY')!;

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

serve(async (req) => {
  try {
    const payload = await req.json();

    // Supabase database webhook sends { type, table, record, old_record }
    const record = payload.record;
    if (!record) {
      return new Response('No record', { status: 400 });
    }

    const threadId: string = record.thread_id;
    const senderId: string = record.sender_id;
    const body: string = record.body ?? '';
    const mediaType: string | null = record.media_type ?? null;
    const aiScoreStatus: string | null = record.ai_score_status ?? null;

    // Don't notify for flagged messages
    if (aiScoreStatus === 'flagged') {
      return new Response('Skipped: flagged', { status: 200 });
    }

    // 1. Get the other participant(s) in the thread
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
      senderProfile?.display_name?.trim() ||
      senderProfile?.username ||
      'Someone';

    // 3. Build notification body
    let notifBody: string;
    if (mediaType === 'image') {
      notifBody = '📷 Photo';
    } else if (mediaType === 'video') {
      notifBody = '🎥 Video';
    } else if (mediaType === 'document') {
      notifBody = '📎 Document';
    } else if (mediaType === 'audio') {
      notifBody = '🎤 Voice message';
    } else {
      notifBody = body.length > 100 ? `${body.substring(0, 100)}…` : body;
    }

    // 4. Get FCM tokens for all recipients
    const { data: tokenRows, error: tokenError } = await supabase
      .from('user_fcm_tokens')
      .select('token, platform')
      .in('user_id', recipientIds);

    if (tokenError || !tokenRows || tokenRows.length === 0) {
      return new Response('No FCM tokens found', { status: 200 });
    }

    const tokens: string[] = tokenRows.map((r: any) => r.token);

    // 5. Send FCM notification via HTTP v1 API (legacy multicast)
    const fcmPayload = {
      registration_ids: tokens,
      notification: {
        title: senderName,
        body: notifBody,
        sound: 'default',
      },
      data: {
        type: 'message',
        thread_id: threadId,
        sender_id: senderId,
      },
      android: {
        priority: 'high',
        notification: {
          channel_id: 'rooverse_messages',
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
    console.error('notify-dm error:', err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});
