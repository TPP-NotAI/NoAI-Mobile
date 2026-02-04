-- Create referral_codes table
CREATE TABLE IF NOT EXISTS public.referral_codes (
    user_id uuid NOT NULL PRIMARY KEY REFERENCES public.profiles(user_id) ON DELETE CASCADE,
    code text NOT NULL UNIQUE,
    created_at timestamp with time zone DEFAULT now()
);

-- Create referrals table
CREATE TABLE IF NOT EXISTS public.referrals (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    referrer_user_id uuid NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE,
    referred_user_id uuid NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE,
    referral_code text NOT NULL,
    status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed')),
    created_at timestamp with time zone DEFAULT now(),
    completed_at timestamp with time zone,
    UNIQUE(referred_user_id)
);

-- Add RLS policies
ALTER TABLE public.referral_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.referrals ENABLE ROW LEVEL SECURITY;

-- Referral Codes Policies
CREATE POLICY "Referral codes are viewable by everyone" 
ON public.referral_codes FOR SELECT 
USING (true);

CREATE POLICY "Users can manage their own referral code" 
ON public.referral_codes FOR ALL 
USING (auth.uid() = user_id);

-- Referrals Policies
CREATE POLICY "Users can view their own referrals" 
ON public.referrals FOR SELECT 
USING (auth.uid() = referrer_user_id OR auth.uid() = referred_user_id);

CREATE POLICY "Users can insert their own referrals" 
ON public.referrals FOR INSERT 
WITH CHECK (auth.uid() = referred_user_id);

CREATE POLICY "System/Admin can update referrals" 
ON public.referrals FOR UPDATE 
USING (true);
