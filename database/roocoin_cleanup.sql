-- ═══════════════════════════════════════════════════════════════════════════
-- ROOCOIN DATABASE CLEANUP SCRIPT
-- ═══════════════════════════════════════════════════════════════════════════
-- Purpose: Clean up duplicate rewards and verify wallet balance accuracy
-- Run this BEFORE deploying the new duplicate prevention code
-- ═══════════════════════════════════════════════════════════════════════════

-- ───────────────────────────────────────────────────────────────────────────
-- STEP 1: IDENTIFY DUPLICATE REWARDS
-- ───────────────────────────────────────────────────────────────────────────

-- Find duplicate POST_CREATE rewards
SELECT 
  'POST_CREATE' as activity_type,
  to_user_id,
  reference_post_id,
  COUNT(*) as duplicate_count,
  SUM(amount_rc) as total_awarded,
  ARRAY_AGG(id ORDER BY created_at) as transaction_ids,
  ARRAY_AGG(created_at ORDER BY created_at) as created_dates
FROM roocoin_transactions
WHERE tx_type = 'engagement_reward'
  AND metadata->>'activityType' = 'POST_CREATE'
  AND reference_post_id IS NOT NULL
  AND status = 'completed'
GROUP BY to_user_id, reference_post_id
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC, total_awarded DESC;

-- Find duplicate POST_COMMENT rewards
SELECT 
  'POST_COMMENT' as activity_type,
  to_user_id,
  reference_comment_id,
  COUNT(*) as duplicate_count,
  SUM(amount_rc) as total_awarded,
  ARRAY_AGG(id ORDER BY created_at) as transaction_ids,
  ARRAY_AGG(created_at ORDER BY created_at) as created_dates
FROM roocoin_transactions
WHERE tx_type = 'engagement_reward'
  AND metadata->>'activityType' = 'POST_COMMENT'
  AND reference_comment_id IS NOT NULL
  AND status = 'completed'
GROUP BY to_user_id, reference_comment_id
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC, total_awarded DESC;

-- Find duplicate POST_LIKE rewards
SELECT 
  'POST_LIKE' as activity_type,
  to_user_id,
  reference_post_id,
  COUNT(*) as duplicate_count,
  SUM(amount_rc) as total_awarded,
  ARRAY_AGG(id ORDER BY created_at) as transaction_ids
FROM roocoin_transactions
WHERE tx_type = 'engagement_reward'
  AND metadata->>'activityType' = 'POST_LIKE'
  AND reference_post_id IS NOT NULL
  AND status = 'completed'
GROUP BY to_user_id, reference_post_id
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

-- Find users with multiple welcome bonuses
SELECT 
  'WELCOME_BONUS' as activity_type,
  to_user_id,
  COUNT(*) as duplicate_count,
  SUM(amount_rc) as total_awarded,
  ARRAY_AGG(id ORDER BY created_at) as transaction_ids
FROM roocoin_transactions
WHERE tx_type = 'engagement_reward'
  AND (
    metadata->>'activityType' = 'WELCOME_BONUS' 
    OR metadata->>'source' = 'faucet'
  )
  AND status = 'completed'
GROUP BY to_user_id
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

-- ───────────────────────────────────────────────────────────────────────────
-- STEP 2: REMOVE DUPLICATE REWARDS (KEEP FIRST, DELETE REST)
-- ───────────────────────────────────────────────────────────────────────────
-- WARNING: This will permanently delete duplicate transactions
-- Review the results from STEP 1 before running this
-- ───────────────────────────────────────────────────────────────────────────

-- UNCOMMENT TO EXECUTE (after reviewing duplicates)
/*

-- Remove duplicate POST_CREATE rewards (keep oldest)
WITH duplicates AS (
  SELECT 
    id,
    to_user_id,
    reference_post_id,
    amount_rc,
    ROW_NUMBER() OVER (
      PARTITION BY to_user_id, reference_post_id 
      ORDER BY created_at ASC
    ) as rn
  FROM roocoin_transactions
  WHERE tx_type = 'engagement_reward'
    AND metadata->>'activityType' = 'POST_CREATE'
    AND reference_post_id IS NOT NULL
    AND status = 'completed'
)
DELETE FROM roocoin_transactions
WHERE id IN (
  SELECT id FROM duplicates WHERE rn > 1
)
RETURNING id, to_user_id, reference_post_id, amount_rc;

-- Remove duplicate POST_COMMENT rewards (keep oldest)
WITH duplicates AS (
  SELECT 
    id,
    to_user_id,
    reference_comment_id,
    amount_rc,
    ROW_NUMBER() OVER (
      PARTITION BY to_user_id, reference_comment_id 
      ORDER BY created_at ASC
    ) as rn
  FROM roocoin_transactions
  WHERE tx_type = 'engagement_reward'
    AND metadata->>'activityType' = 'POST_COMMENT'
    AND reference_comment_id IS NOT NULL
    AND status = 'completed'
)
DELETE FROM roocoin_transactions
WHERE id IN (
  SELECT id FROM duplicates WHERE rn > 1
)
RETURNING id, to_user_id, reference_comment_id, amount_rc;

-- Remove duplicate WELCOME_BONUS (keep oldest)
WITH duplicates AS (
  SELECT 
    id,
    to_user_id,
    amount_rc,
    ROW_NUMBER() OVER (
      PARTITION BY to_user_id 
      ORDER BY created_at ASC
    ) as rn
  FROM roocoin_transactions
  WHERE tx_type = 'engagement_reward'
    AND (
      metadata->>'activityType' = 'WELCOME_BONUS' 
      OR metadata->>'source' = 'faucet'
    )
    AND status = 'completed'
)
DELETE FROM roocoin_transactions
WHERE id IN (
  SELECT id FROM duplicates WHERE rn > 1
)
RETURNING id, to_user_id, amount_rc;

*/

-- ───────────────────────────────────────────────────────────────────────────
-- STEP 3: RECALCULATE WALLET BALANCES
-- ───────────────────────────────────────────────────────────────────────────
-- After removing duplicates, recalculate accurate balances
-- ───────────────────────────────────────────────────────────────────────────

-- Calculate accurate balances from transaction history
WITH transaction_totals AS (
  SELECT 
    user_id,
    COALESCE(SUM(CASE WHEN to_user_id = user_id THEN amount_rc ELSE 0 END), 0) as total_earned,
    COALESCE(SUM(CASE WHEN from_user_id = user_id THEN amount_rc ELSE 0 END), 0) as total_spent
  FROM (
    SELECT user_id FROM wallets
  ) users
  LEFT JOIN roocoin_transactions t ON (
    t.to_user_id = users.user_id OR t.from_user_id = users.user_id
  ) AND t.status = 'completed'
  GROUP BY user_id
)
SELECT 
  w.user_id,
  w.balance_rc as current_balance,
  tt.total_earned - tt.total_spent as calculated_balance,
  w.balance_rc - (tt.total_earned - tt.total_spent) as difference,
  w.lifetime_earned_rc as current_lifetime_earned,
  tt.total_earned as calculated_lifetime_earned,
  w.lifetime_spent_rc as current_lifetime_spent,
  tt.total_spent as calculated_lifetime_spent
FROM wallets w
JOIN transaction_totals tt ON tt.user_id = w.user_id
WHERE 
  ABS(w.balance_rc - (tt.total_earned - tt.total_spent)) > 0.01
  OR ABS(w.lifetime_earned_rc - tt.total_earned) > 0.01
  OR ABS(w.lifetime_spent_rc - tt.total_spent) > 0.01
ORDER BY ABS(w.balance_rc - (tt.total_earned - tt.total_spent)) DESC;

-- ───────────────────────────────────────────────────────────────────────────
-- STEP 4: UPDATE WALLET BALANCES (IF NEEDED)
-- ───────────────────────────────────────────────────────────────────────────
-- UNCOMMENT TO EXECUTE (after reviewing discrepancies from STEP 3)
-- ───────────────────────────────────────────────────────────────────────────

/*

WITH transaction_totals AS (
  SELECT 
    user_id,
    COALESCE(SUM(CASE WHEN to_user_id = user_id THEN amount_rc ELSE 0 END), 0) as total_earned,
    COALESCE(SUM(CASE WHEN from_user_id = user_id THEN amount_rc ELSE 0 END), 0) as total_spent
  FROM (
    SELECT user_id FROM wallets
  ) users
  LEFT JOIN roocoin_transactions t ON (
    t.to_user_id = users.user_id OR t.from_user_id = users.user_id
  ) AND t.status = 'completed'
  GROUP BY user_id
)
UPDATE wallets w
SET 
  balance_rc = tt.total_earned - tt.total_spent,
  lifetime_earned_rc = tt.total_earned,
  lifetime_spent_rc = tt.total_spent,
  updated_at = NOW()
FROM transaction_totals tt
WHERE w.user_id = tt.user_id
  AND (
    ABS(w.balance_rc - (tt.total_earned - tt.total_spent)) > 0.01
    OR ABS(w.lifetime_earned_rc - tt.total_earned) > 0.01
    OR ABS(w.lifetime_spent_rc - tt.total_spent) > 0.01
  )
RETURNING 
  w.user_id,
  w.balance_rc as new_balance,
  w.lifetime_earned_rc as new_lifetime_earned,
  w.lifetime_spent_rc as new_lifetime_spent;

*/

-- ───────────────────────────────────────────────────────────────────────────
-- STEP 5: VERIFICATION QUERIES
-- ───────────────────────────────────────────────────────────────────────────

-- Verify no duplicates remain
SELECT 
  'POST_CREATE' as activity_type,
  COUNT(*) as remaining_duplicates
FROM (
  SELECT to_user_id, reference_post_id, COUNT(*) as cnt
  FROM roocoin_transactions
  WHERE tx_type = 'engagement_reward'
    AND metadata->>'activityType' = 'POST_CREATE'
    AND reference_post_id IS NOT NULL
    AND status = 'completed'
  GROUP BY to_user_id, reference_post_id
  HAVING COUNT(*) > 1
) duplicates

UNION ALL

SELECT 
  'POST_COMMENT' as activity_type,
  COUNT(*) as remaining_duplicates
FROM (
  SELECT to_user_id, reference_comment_id, COUNT(*) as cnt
  FROM roocoin_transactions
  WHERE tx_type = 'engagement_reward'
    AND metadata->>'activityType' = 'POST_COMMENT'
    AND reference_comment_id IS NOT NULL
    AND status = 'completed'
  GROUP BY to_user_id, reference_comment_id
  HAVING COUNT(*) > 1
) duplicates

UNION ALL

SELECT 
  'WELCOME_BONUS' as activity_type,
  COUNT(*) as remaining_duplicates
FROM (
  SELECT to_user_id, COUNT(*) as cnt
  FROM roocoin_transactions
  WHERE tx_type = 'engagement_reward'
    AND (metadata->>'activityType' = 'WELCOME_BONUS' OR metadata->>'source' = 'faucet')
    AND status = 'completed'
  GROUP BY to_user_id
  HAVING COUNT(*) > 1
) duplicates;

-- Verify all balances are accurate
SELECT 
  COUNT(*) as wallets_with_discrepancies
FROM wallets w
LEFT JOIN (
  SELECT 
    user_id,
    COALESCE(SUM(CASE WHEN to_user_id = user_id THEN amount_rc ELSE 0 END), 0) -
    COALESCE(SUM(CASE WHEN from_user_id = user_id THEN amount_rc ELSE 0 END), 0) as calculated_balance
  FROM (
    SELECT user_id FROM wallets
  ) users
  LEFT JOIN roocoin_transactions t ON (
    t.to_user_id = users.user_id OR t.from_user_id = users.user_id
  ) AND t.status = 'completed'
  GROUP BY user_id
) tt ON tt.user_id = w.user_id
WHERE ABS(w.balance_rc - tt.calculated_balance) > 0.01;

-- ───────────────────────────────────────────────────────────────────────────
-- STEP 6: SUMMARY STATISTICS
-- ───────────────────────────────────────────────────────────────────────────

-- Overall statistics
SELECT 
  COUNT(DISTINCT user_id) as total_users_with_wallets,
  SUM(balance_rc) as total_roo_in_circulation,
  SUM(lifetime_earned_rc) as total_roo_earned,
  SUM(lifetime_spent_rc) as total_roo_spent,
  AVG(balance_rc) as avg_balance_per_user,
  MAX(balance_rc) as max_balance,
  MIN(balance_rc) as min_balance
FROM wallets;

-- Reward distribution by activity type
SELECT 
  metadata->>'activityType' as activity_type,
  COUNT(*) as transaction_count,
  SUM(amount_rc) as total_distributed,
  AVG(amount_rc) as avg_amount,
  COUNT(DISTINCT to_user_id) as unique_recipients
FROM roocoin_transactions
WHERE tx_type = 'engagement_reward'
  AND status = 'completed'
GROUP BY metadata->>'activityType'
ORDER BY total_distributed DESC;

-- Transfer statistics
SELECT 
  COUNT(*) as total_transfers,
  SUM(amount_rc) as total_transferred,
  AVG(amount_rc) as avg_transfer_amount,
  COUNT(DISTINCT from_user_id) as unique_senders,
  COUNT(DISTINCT to_user_id) as unique_recipients
FROM roocoin_transactions
WHERE tx_type = 'transfer'
  AND status = 'completed';

-- ═══════════════════════════════════════════════════════════════════════════
-- END OF CLEANUP SCRIPT
-- ═══════════════════════════════════════════════════════════════════════════
-- 
-- EXECUTION CHECKLIST:
-- [ ] Run STEP 1 to identify duplicates
-- [ ] Review duplicate results carefully
-- [ ] Uncomment and run STEP 2 to remove duplicates
-- [ ] Run STEP 3 to check for balance discrepancies
-- [ ] Uncomment and run STEP 4 to fix balances (if needed)
-- [ ] Run STEP 5 to verify cleanup was successful
-- [ ] Run STEP 6 to review overall statistics
-- [ ] Document results and any manual adjustments made
-- 
-- ═══════════════════════════════════════════════════════════════════════════
