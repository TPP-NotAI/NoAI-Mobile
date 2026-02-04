-- Fix for Wallet RLS Policy Issues
-- This script updates the RLS policies for the wallets table to allow users to update their own wallet addresses

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view their own wallet" ON wallets;
DROP POLICY IF EXISTS "Users can insert their own wallet" ON wallets;
DROP POLICY IF EXISTS "Users can update their own wallet" ON wallets;

-- Enable RLS on wallets table
ALTER TABLE wallets ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own wallet
CREATE POLICY "Users can view their own wallet"
ON wallets
FOR SELECT
USING (auth.uid() = user_id);

-- Policy: Users can insert their own wallet (for new users)
CREATE POLICY "Users can insert their own wallet"
ON wallets
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own wallet
-- This is the critical policy that was missing/blocking wallet repairs
CREATE POLICY "Users can update their own wallet"
ON wallets
FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Optional: Allow service role to manage all wallets (for admin operations)
-- Uncomment if you need backend services to manage wallets
-- CREATE POLICY "Service role can manage all wallets"
-- ON wallets
-- FOR ALL
-- USING (auth.jwt() ->> 'role' = 'service_role');

-- Verify policies are created
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'wallets';
