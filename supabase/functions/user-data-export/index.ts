// User Data Export — Supabase Edge Function (GDPR Article 20 — Data Portability)
//
// Called by the Flutter app with the user's JWT.
// Returns a JSON bundle of all personal data held for that user.
//
// Required Supabase secrets (auto-available in edge functions):
//   SUPABASE_URL
//   SUPABASE_SERVICE_ROLE_KEY  ← needed to bypass RLS for a full export

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const ALLOWED_ORIGIN = Deno.env.get('ALLOWED_ORIGIN') ?? 'https://rooverse.app';

const corsHeaders = {
  'Access-Control-Allow-Origin': ALLOWED_ORIGIN,
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const securityHeaders = {
  'X-Content-Type-Options': 'nosniff',
  'X-Frame-Options': 'DENY',
  'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
};

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  // ── 1. Authenticate caller ────────────────────────────────────────────────
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return new Response(JSON.stringify({ error: 'Missing Authorization header' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  // Verify JWT using anon client
  const anonClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user }, error: authError } = await anonClient.auth.getUser();
  if (authError || !user) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const userId = user.id;
  const userEmail = user.email ?? null;

  // ── 2. Collect data using service role (bypasses RLS for user's own data) ─
  const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  const [
    profileRes,
    walletRes,
    postsRes,
    commentsRes,
    transactionsRes,
    activitiesRes,
    bookmarksRes,
    notificationsRes,
    followersRes,
    followingRes,
  ] = await Promise.all([
    admin.from('profiles').select('*').eq('user_id', userId).maybeSingle(),
    admin.from('wallets').select('user_id, wallet_address, balance_rc, lifetime_earned_rc, lifetime_spent_rc, created_at').eq('user_id', userId).maybeSingle(),
    admin.from('posts').select('id, content, media_urls, created_at, updated_at, visibility').eq('user_id', userId).order('created_at', { ascending: false }),
    admin.from('comments').select('id, content, post_id, created_at').eq('user_id', userId).order('created_at', { ascending: false }),
    admin.from('roocoin_transactions').select('id, tx_type, amount_rc, memo, created_at, from_user_id, to_user_id').or(`from_user_id.eq.${userId},to_user_id.eq.${userId}`).order('created_at', { ascending: false }),
    admin.from('user_activities').select('activity_type, description, created_at').eq('user_id', userId).order('created_at', { ascending: false }).limit(1000),
    admin.from('bookmarks').select('post_id, created_at').eq('user_id', userId),
    admin.from('notifications').select('type, title, body, is_read, created_at').eq('user_id', userId).order('created_at', { ascending: false }).limit(500),
    admin.from('followers').select('follower_id, created_at').eq('following_id', userId),
    admin.from('followers').select('following_id, created_at').eq('follower_id', userId),
  ]);

  // ── 3. Build export bundle ────────────────────────────────────────────────
  const exportBundle = {
    export_generated_at: new Date().toISOString(),
    account: {
      id: userId,
      email: userEmail,
      created_at: user.created_at,
      last_sign_in_at: user.last_sign_in_at,
    },
    profile: profileRes.data ?? null,
    wallet: walletRes.data ?? null,
    posts: postsRes.data ?? [],
    comments: commentsRes.data ?? [],
    transactions: transactionsRes.data ?? [],
    activity_log: activitiesRes.data ?? [],
    bookmarks: bookmarksRes.data ?? [],
    notifications: notificationsRes.data ?? [],
    followers: followersRes.data ?? [],
    following: followingRes.data ?? [],
  };

  // Log the export request for audit trail
  await admin.from('user_activities').insert({
    user_id: userId,
    activity_type: 'settings_change',
    description: 'User requested GDPR data export',
    metadata: { action: 'data_export' },
  });

  return new Response(JSON.stringify(exportBundle), {
    status: 200,
    headers: {
      ...corsHeaders,
      ...securityHeaders,
      'Content-Type': 'application/json',
      'Content-Disposition': `attachment; filename="rooverse-data-export-${userId}.json"`,
    },
  });
});
