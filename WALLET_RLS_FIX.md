# Quick Fix Guide - Wallet RLS Error

## Problem
App shows: `WalletRepository: RLS prevents wallet repair for user: new row violates row-level security policy for table "wallets"`

## Current Status
✅ **App is working** - The code now handles this gracefully with an in-memory workaround
⚠️ **Database needs fixing** - The RLS policy is still blocking updates

## Immediate Action Required

### Option 1: Supabase Dashboard (Recommended)
1. Go to your Supabase project dashboard
2. Navigate to **SQL Editor**
3. Copy and paste the contents of `supabase/migrations/fix_wallet_rls_policies.sql`
4. Click **Run**
5. Verify the policies were created by checking the output

### Option 2: Supabase CLI
```bash
cd d:\noai_org
supabase db push
```

## What the Fix Does
The SQL script adds a missing RLS policy that allows users to UPDATE their own wallet records. Currently, users can only SELECT and INSERT, which is why the wallet repair fails.

## Verification
After running the SQL:
1. Restart your app
2. Check the logs - you should no longer see RLS errors
3. The wallet address should be properly updated in the database

## What Happens If You Don't Fix It?
- ✅ App will continue to work normally
- ⚠️ Database will still have invalid 32-character addresses
- ⚠️ Logs will continue to show RLS warnings
- ⚠️ Any backend operations that rely on the database address will fail

## Files Created
- `supabase/migrations/fix_wallet_rls_policies.sql` - The SQL fix
- `.gemini/wallet_error_fixes.md` - Detailed documentation
- This file - Quick reference

## Need Help?
Check `.gemini/wallet_error_fixes.md` for complete details about all the fixes applied.
