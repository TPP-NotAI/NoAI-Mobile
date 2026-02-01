-- Migration: Add missing tables and columns to match app code expectations
-- Run this against your Supabase database

-- ============================================================
-- 1. Add missing columns to 'profiles' table
-- ============================================================

-- Add 'interests' column (JSONB array of interest strings)
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS interests jsonb DEFAULT '[]'::jsonb;

-- Add 'last_seen' column (kept for any direct references; app uses last_active_at)
-- Note: profiles already has 'last_active_at'. This is a synonym alias if needed.

-- Add 'phone_number' column
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS phone_number text;

-- Add privacy/visibility columns
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS posts_visibility text NOT NULL DEFAULT 'everyone'
    CHECK (posts_visibility IN ('everyone', 'followers', 'private'));

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS comments_visibility text NOT NULL DEFAULT 'everyone'
    CHECK (comments_visibility IN ('everyone', 'followers', 'private'));

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS messages_visibility text NOT NULL DEFAULT 'everyone'
    CHECK (messages_visibility IN ('everyone', 'followers', 'private'));

-- ============================================================
-- 1b. Add missing columns to 'posts' table
-- ============================================================

-- Location text for posts (nullable)
ALTER TABLE public.posts
  ADD COLUMN IF NOT EXISTS location text;

-- ============================================================
-- 2. Add missing 'mutes' table
-- ============================================================

CREATE TABLE IF NOT EXISTS public.mutes (
  muter_id uuid NOT NULL,
  muted_id uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT mutes_pkey PRIMARY KEY (muter_id, muted_id),
  CONSTRAINT mutes_muter_id_fkey FOREIGN KEY (muter_id) REFERENCES public.profiles(user_id),
  CONSTRAINT mutes_muted_id_fkey FOREIGN KEY (muted_id) REFERENCES public.profiles(user_id),
  CONSTRAINT mutes_no_self_mute CHECK (muter_id <> muted_id)
);

-- Index for fast lookups
CREATE INDEX IF NOT EXISTS idx_mutes_muter_id ON public.mutes(muter_id);
CREATE INDEX IF NOT EXISTS idx_mutes_muted_id ON public.mutes(muted_id);

-- ============================================================
-- 3. Enable Row Level Security on new table
-- ============================================================

ALTER TABLE public.mutes ENABLE ROW LEVEL SECURITY;

-- Users can only see their own mutes
CREATE POLICY "Users can view their own mutes"
  ON public.mutes FOR SELECT
  USING (auth.uid() = muter_id);

-- Users can mute others
CREATE POLICY "Users can mute others"
  ON public.mutes FOR INSERT
  WITH CHECK (auth.uid() = muter_id);

-- Users can unmute
CREATE POLICY "Users can unmute"
  ON public.mutes FOR DELETE
  USING (auth.uid() = muter_id);

-- ============================================================
-- 4. RLS policies for posts (allow authors to update/unpublish/delete)
-- ============================================================

ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;

-- Allow authors to update their own posts (includes status changes to draft/removed)
CREATE POLICY "Authors can update their posts"
  ON public.posts
  FOR UPDATE
  USING (auth.uid() = author_id)
  WITH CHECK (auth.uid() = author_id);

-- Allow authors to delete/soft-delete their posts (if DELETE used elsewhere)
CREATE POLICY "Authors can delete their posts"
  ON public.posts
  FOR DELETE
  USING (auth.uid() = author_id);
