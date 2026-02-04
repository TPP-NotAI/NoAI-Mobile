-- Fix RLS policies for roocoin_transactions table
-- This allows users to insert and view their own transactions

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view their own transactions" ON roocoin_transactions;
DROP POLICY IF EXISTS "Users can insert their own transactions" ON roocoin_transactions;

-- Enable RLS on roocoin_transactions table
ALTER TABLE roocoin_transactions ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view transactions where they are sender or receiver
CREATE POLICY "Users can view their own transactions"
ON roocoin_transactions
FOR SELECT
USING (
  auth.uid() = from_user_id OR 
  auth.uid() = to_user_id
);

-- Policy: Users can insert transactions where they are the sender or receiver
-- This allows users to record their own transactions (rewards, transfers, etc.)
CREATE POLICY "Users can insert their own transactions"
ON roocoin_transactions
FOR INSERT
WITH CHECK (
  auth.uid() = from_user_id OR 
  auth.uid() = to_user_id OR
  from_user_id IS NULL  -- Allow system rewards (no sender)
);

-- Optional: Service role can manage all transactions (for admin/system operations)
-- Uncomment if you need backend services to manage transactions
-- CREATE POLICY "Service role can manage all transactions"
-- ON roocoin_transactions
-- FOR ALL
-- USING (auth.jwt() ->> 'role' = 'service_role');

-- Verify policies are created
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'roocoin_transactions';
