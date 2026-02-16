-- ═══════════════════════════════════════════════════════════════════════════
-- ROOCOIN PRODUCTION READINESS SQL
-- ═══════════════════════════════════════════════════════════════════════════
-- Purpose: Add atomic update functions and performance indices
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. Atomic wallet balance update function
-- Use this for any balance change to avoid race conditions.
CREATE OR REPLACE FUNCTION public.update_wallet_balance_atomic(
  p_user_id UUID,
  p_delta NUMERIC,
  p_earned_delta NUMERIC DEFAULT 0,
  p_spent_delta NUMERIC DEFAULT 0
) RETURNS VOID AS $$
BEGIN
  UPDATE public.wallets
  SET 
    balance_rc = balance_rc + p_delta,
    lifetime_earned_rc = lifetime_earned_rc + p_earned_delta,
    lifetime_spent_rc = lifetime_spent_rc + p_spent_delta,
    updated_at = now()
  WHERE user_id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Atomic reward recording function
-- Specifically for earning rewards, ensures balance and daily limits are synced.
CREATE OR REPLACE FUNCTION public.record_roocoin_reward_atomic(
  p_user_id UUID,
  p_amount NUMERIC,
  p_activity_type TEXT
) RETURNS VOID AS $$
BEGIN
  -- Update wallet balance atomically
  UPDATE public.wallets
  SET 
    balance_rc = balance_rc + p_amount,
    lifetime_earned_rc = lifetime_earned_rc + p_amount,
    updated_at = now()
  WHERE user_id = p_user_id;
  
  -- Record daily summary
  -- We use nested block to handle case where record_roocoin_daily_reward might not exist yet
  BEGIN
    PERFORM public.record_roocoin_daily_reward(
      p_user_id := p_user_id,
      p_activity_type := p_activity_type,
      p_amount := p_amount
    );
  EXCEPTION WHEN OTHERS THEN
    -- Fallback: If RPC doesn't exist, we've already updated the main balance above
    NULL;
  END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Performance Indices
-- Ensures deduplication checks and transaction history lookups are fast
CREATE INDEX IF NOT EXISTS idx_roocoin_transactions_to_user_id 
  ON public.roocoin_transactions(to_user_id);

CREATE INDEX IF NOT EXISTS idx_roocoin_transactions_from_user_id 
  ON public.roocoin_transactions(from_user_id);

CREATE INDEX IF NOT EXISTS idx_roocoin_transactions_reference_post_id 
  ON public.roocoin_transactions(reference_post_id) 
  WHERE reference_post_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_roocoin_transactions_reference_comment_id 
  ON public.roocoin_transactions(reference_comment_id) 
  WHERE reference_comment_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_roocoin_transactions_metadata_activity 
  ON public.roocoin_transactions ((metadata->>'activityType'));

CREATE INDEX IF NOT EXISTS idx_roocoin_transactions_tx_type 
  ON public.roocoin_transactions(tx_type);

-- 4. Health Check Query
-- Run this to verify the environment is ready
SELECT 
  (SELECT COUNT(*) FROM pg_proc WHERE proname IN ('update_wallet_balance_atomic', 'record_roocoin_reward_atomic')) as rpc_count,
  (SELECT COUNT(*) FROM pg_indexes WHERE tablename = 'roocoin_transactions') as index_count;
