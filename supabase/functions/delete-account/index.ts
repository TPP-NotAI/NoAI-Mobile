// Delete Account — Supabase Edge Function
//
// Handles two modes:
//
//  A) User-initiated immediate deletion (legacy path, kept for compatibility).
//     Body: { userId, email, password }
//     Re-verifies credentials before deleting.
//
//  B) Scheduled auto-deletion (called by pg_cron daily).
//     Body: { cronSecret, dryRun? }
//     Deletes all accounts where status = 'pending_deletion'
//     AND deletion_scheduled_at <= now().
//     Only accepted when the request includes the correct CRON_SECRET header.

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
// Set this secret in Supabase dashboard → Edge Function secrets, and use it
// in your pg_cron job: SELECT net.http_post(url, headers=>..., body=>...).
const CRON_SECRET = Deno.env.get('CRON_SECRET') ?? '';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

/** Delete all data for a single userId, then remove the auth user. */
async function deleteUserData(admin: ReturnType<typeof createClient>, userId: string): Promise<void> {
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

  const { error } = await admin.auth.admin.deleteUser(userId);
  if (error) throw new Error(`Failed to delete auth user ${userId}: ${error.message}`);
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  let body: Record<string, any>;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid request body' }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  // ── Mode B: scheduled auto-deletion ───────────────────────────────────────
  if (body.cronSecret !== undefined) {
    if (!CRON_SECRET || body.cronSecret !== CRON_SECRET) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const dryRun: boolean = body.dryRun === true;

    // Find all accounts due for deletion (scheduled date has passed)
    const { data: due, error: fetchError } = await admin
      .from('profiles')
      .select('user_id, username')
      .eq('status', 'pending_deletion')
      .lte('deletion_scheduled_at', new Date().toISOString());

    if (fetchError) {
      console.error('Failed to fetch pending deletions:', fetchError.message);
      return new Response(JSON.stringify({ error: fetchError.message }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (!due || due.length === 0) {
      return new Response(JSON.stringify({ success: true, deleted: 0 }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    console.log(`[delete-account cron] ${due.length} account(s) due for deletion. dryRun=${dryRun}`);

    const results: { userId: string; ok: boolean; error?: string }[] = [];
    for (const row of due as any[]) {
      if (dryRun) {
        results.push({ userId: row.user_id, ok: true });
        continue;
      }
      try {
        await deleteUserData(admin, row.user_id);
        results.push({ userId: row.user_id, ok: true });
        console.log(`[delete-account cron] Deleted user ${row.user_id} (${row.username})`);
      } catch (e: any) {
        results.push({ userId: row.user_id, ok: false, error: e.message });
        console.error(`[delete-account cron] Failed to delete ${row.user_id}:`, e.message);
      }
    }

    const deleted = results.filter((r) => r.ok).length;
    return new Response(JSON.stringify({ success: true, deleted, dryRun, results }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  // ── Mode A: user-initiated immediate deletion (password-verified) ──────────
  const { userId, email, password } = body;

  if (!userId || !email || !password) {
    return new Response(JSON.stringify({ error: 'userId, email and password are required' }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

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

  try {
    await deleteUserData(admin, userId);
  } catch (e: any) {
    console.error('delete-account error:', e.message);
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
