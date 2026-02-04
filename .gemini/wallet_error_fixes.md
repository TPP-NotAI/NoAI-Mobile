# Wallet Error Fixes - Summary

## Issues Identified

Based on the error logs, there were four main issues:

### 1. Invalid Wallet Addresses
**Error:** `Repairing wallet for user: Invalid address 81063ff6d0b5446b68bc333621544760`

**Root Cause:** 
- The database schema has a default value for `wallet_address` that generates a 32-character hex string using `encode(gen_random_bytes(16), 'hex')`
- The application expects EVM-compatible addresses (42 characters: `0x` + 40 hex chars)
- When wallets were created directly in the database (possibly through triggers or other processes), they got the default 32-char address instead of a proper EVM address

### 2. Row Level Security (RLS) Policy Blocking Updates
**Error:** `new row violates row-level security policy for table "wallets"`

**Root Cause:**
- The RLS policies on the `wallets` table are preventing users from updating their own wallet addresses
- The policy likely allows SELECT and INSERT but not UPDATE operations
- This blocks the wallet repair mechanism from fixing invalid addresses

**Fix Required:**
- Run the SQL migration script: `supabase/migrations/fix_wallet_rls_policies.sql`
- This adds an UPDATE policy that allows users to update their own wallets

### 3. PostgrestException PGRST116 Errors
**Error:** `PostgrestException(message: {"code":"PGRST116","details":"The result contains 0 rows"...})`

**Root Cause:**
- Operations were trying to use `.single()` when no wallet existed yet
- Daily login service was attempting to earn ROO before wallet was fully initialized

**Fix:**
- Updated wallet repair to use `update` instead of `upsert` (simpler approach)
- Added wallet existence check before attempting daily login rewards
- Added 500ms delay to allow wallet initialization to complete before checking daily login

### 4. Race Conditions During Startup
**Root Cause:**
- Wallet initialization, welcome bonus, and daily login checks were all happening simultaneously
- This created race conditions where operations tried to access wallets that didn't exist yet

**Fix:**
- Added comprehensive error handling in `WalletProvider.initWallet()` to prevent app crashes
- Wrapped welcome bonus check in try-catch
- Added wallet existence validation before daily login check
- Ensured app continues to function even if wallet operations fail

## Files Modified

### 1. **lib/repositories/wallet_repository.dart**
   - Changed `_repairWallet()` to use `update` instead of `upsert`
   - Added RLS error handling with in-memory workaround
   - When RLS blocks the update, creates a valid blockchain wallet and returns a corrected Wallet object
   - Uses `copyWith()` to return existing wallet data with corrected address
   - Falls back to creating a minimal wallet object if needed

### 2. **lib/providers/wallet_provider.dart**
   - Added try-catch around welcome bonus check in `initWallet()`
   - Added comment to clarify that errors shouldn't crash the app

### 3. **lib/main.dart**
   - Added 500ms delay before daily login check
   - Added wallet existence validation before attempting daily login
   - Improved error handling

### 4. **supabase/migrations/fix_wallet_rls_policies.sql** (NEW)
   - SQL script to fix RLS policies on the wallets table
   - Adds UPDATE policy for users to update their own wallets
   - Includes verification query to check policies

## Solution Approach

### Immediate Workaround (Already Implemented)
The app now works around the RLS issue by:
1. Creating a valid blockchain wallet and storing the private key
2. Attempting to update the database
3. If RLS blocks the update, using the existing wallet data with the corrected address in-memory
4. This allows the app to function normally even though the database has an invalid address

### Permanent Fix (Requires Database Migration)
Run the SQL migration to fix the RLS policies:

```bash
# Option 1: Using Supabase CLI
supabase db push

# Option 2: Run the SQL directly in Supabase Dashboard
# Navigate to SQL Editor and run the contents of:
# supabase/migrations/fix_wallet_rls_policies.sql
```

## Testing Recommendations

1. **Test with a fresh user account** (no existing wallet)
2. **Test with an existing user that has an invalid wallet address**
3. **Test daily login rewards after fresh login**
4. **Verify welcome bonus is awarded correctly**
5. **Ensure app doesn't crash if wallet operations fail**
6. **After running the SQL migration, verify that wallet addresses can be updated in the database**

## Current Behavior

### Before Database Fix:
- ✅ App starts successfully without crashing
- ✅ Wallet operations work using in-memory corrected address
- ⚠️ Database still contains invalid address (32 chars instead of 42)
- ⚠️ Logs show RLS error but app continues functioning

### After Database Fix:
- ✅ App starts successfully
- ✅ Wallet addresses are corrected in the database
- ✅ No RLS errors in logs
- ✅ All wallet operations work normally

## Next Steps

1. **Run the SQL migration** in your Supabase project to fix the RLS policies
2. **Monitor logs** to ensure RLS errors disappear
3. **Consider updating the database schema** to remove the default value for `wallet_address` or change it to generate proper EVM addresses
4. **Optional**: Create a data migration script to fix existing invalid addresses in the database

