// Delete Account — Supabase Edge Function
//
// JWT verification is disabled for this function.
// Caller must supply { userId, email, password } in the request body.
// The function re-verifies credentials server-side before deleting anything.

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  // ── 1. Parse body ─────────────────────────────────────────────────────────
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

  // ── 2. Re-verify credentials (prevents anyone from deleting arbitrary accounts) ──
  const anonClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  const { data: signInData, error: signInError } = await anonClient.auth.signInWithPassword({ email, password });
  if (signInError || !signInData.user) {
    return new Response(JSON.stringify({ error: 'Invalid credentials' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  // Ensure the authenticated user matches the requested userId
  if (signInData.user.id !== userId) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), {
      status: 403,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  // ── 3. Delete user data (order matters for FK constraints) ────────────────
  await Promise.all([
    admin.from('notifications').delete().eq('user_id', userId),
    admin.from('bookmarks').delete().eq('user_id', userId),
    admin.from('user_activities').delete().eq('user_id', userId),
    admin.from('followers').delete().eq('follower_id', userId),
    admin.from('followers').delete().eq('following_id', userId),
    admin.from('post_likes').delete().eq('user_id', userId),
    admin.from('reposts').delete().eq('user_id', userId),
  ]);

  await admin.from('comments').delete().eq('user_id', userId);
  await admin.from('posts').delete().eq('user_id', userId);
  await admin.from('wallets').delete().eq('user_id', userId);
  await admin.from('profiles').delete().eq('user_id', userId);

  // ── 4. Delete the auth user ───────────────────────────────────────────────
  const { error: deleteError } = await admin.auth.admin.deleteUser(userId);
  if (deleteError) {
    console.error('Failed to delete auth user:', deleteError.message);
    return new Response(JSON.stringify({ error: 'Failed to delete account' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  return new Response(JSON.stringify({ success: true }), {
    status: 200,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
});
