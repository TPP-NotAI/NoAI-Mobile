-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.admin_permissions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  role text NOT NULL,
  permission text NOT NULL,
  CONSTRAINT admin_permissions_pkey PRIMARY KEY (id)
);
CREATE TABLE public.admin_users (
  user_id uuid NOT NULL,
  role text NOT NULL DEFAULT 'moderator'::text CHECK (role = ANY (ARRAY['viewer'::text, 'support'::text, 'moderator'::text, 'admin'::text, 'super_admin'::text])),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT admin_users_pkey PRIMARY KEY (user_id),
  CONSTRAINT admin_users_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.appeals (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  moderation_case_id uuid NOT NULL,
  statement text NOT NULL,
  evidence_storage_path text,
  status USER-DEFINED NOT NULL DEFAULT 'pending'::appeal_status,
  assigned_admin_id uuid,
  outcome_notes text,
  decided_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT appeals_pkey PRIMARY KEY (id),
  CONSTRAINT appeals_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(user_id),
  CONSTRAINT appeals_moderation_case_id_fkey FOREIGN KEY (moderation_case_id) REFERENCES public.moderation_cases(id),
  CONSTRAINT appeals_assigned_admin_id_fkey FOREIGN KEY (assigned_admin_id) REFERENCES public.admin_users(user_id)
);
CREATE TABLE public.audit_logs (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  actor_user_id uuid,
  actor_role text,
  action text NOT NULL,
  target_type text,
  target_id uuid,
  status text NOT NULL DEFAULT 'success'::text CHECK (status = ANY (ARRAY['success'::text, 'failed'::text])),
  ip text,
  user_agent text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT audit_logs_pkey PRIMARY KEY (id),
  CONSTRAINT audit_logs_actor_user_id_fkey FOREIGN KEY (actor_user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.background_jobs (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  job_type text NOT NULL,
  status USER-DEFINED NOT NULL DEFAULT 'queued'::job_status,
  priority text NOT NULL DEFAULT 'normal'::text CHECK (priority = ANY (ARRAY['low'::text, 'normal'::text, 'high'::text])),
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  started_at timestamp with time zone,
  finished_at timestamp with time zone,
  error_message text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT background_jobs_pkey PRIMARY KEY (id)
);
CREATE TABLE public.blocks (
  blocker_id uuid NOT NULL,
  blocked_id uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT blocks_pkey PRIMARY KEY (blocker_id, blocked_id),
  CONSTRAINT blocks_blocker_id_fkey FOREIGN KEY (blocker_id) REFERENCES public.profiles(user_id),
  CONSTRAINT blocks_blocked_id_fkey FOREIGN KEY (blocked_id) REFERENCES public.profiles(user_id)
);
CREATE TABLE public.bookmarks (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  post_id uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT bookmarks_pkey PRIMARY KEY (id),
  CONSTRAINT bookmarks_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(user_id),
  CONSTRAINT bookmarks_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id)
);
CREATE TABLE public.comments (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL,
  author_id uuid NOT NULL,
  parent_comment_id uuid,
  body text NOT NULL,
  status USER-DEFINED NOT NULL DEFAULT 'published'::post_status,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  media_url text,
  media_type text,
  CONSTRAINT comments_pkey PRIMARY KEY (id),
  CONSTRAINT comments_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id),
  CONSTRAINT comments_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.profiles(user_id),
  CONSTRAINT comments_parent_comment_id_fkey FOREIGN KEY (parent_comment_id) REFERENCES public.comments(id)
);
CREATE TABLE public.conversation_participants (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL,
  user_id uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT conversation_participants_pkey PRIMARY KEY (id),
  CONSTRAINT conversation_participants_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.conversations(id),
  CONSTRAINT conversation_participants_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(user_id)
);
CREATE TABLE public.conversations (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  last_message_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT conversations_pkey PRIMARY KEY (id)
);
CREATE TABLE public.dm_messages (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  thread_id uuid NOT NULL,
  sender_id uuid NOT NULL,
  body text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT dm_messages_pkey PRIMARY KEY (id),
  CONSTRAINT dm_messages_thread_id_fkey FOREIGN KEY (thread_id) REFERENCES public.dm_threads(id),
  CONSTRAINT dm_messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES public.profiles(user_id)
);
CREATE TABLE public.dm_participants (
  thread_id uuid NOT NULL,
  user_id uuid NOT NULL,
  joined_at timestamp with time zone NOT NULL DEFAULT now(),
  muted boolean NOT NULL DEFAULT false,
  CONSTRAINT dm_participants_pkey PRIMARY KEY (thread_id, user_id),
  CONSTRAINT dm_participants_thread_id_fkey FOREIGN KEY (thread_id) REFERENCES public.dm_threads(id),
  CONSTRAINT dm_participants_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(user_id)
);
CREATE TABLE public.dm_threads (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_by uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  last_message_at timestamp with time zone,
  CONSTRAINT dm_threads_pkey PRIMARY KEY (id),
  CONSTRAINT dm_threads_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(user_id)
);
CREATE TABLE public.follows (
  follower_id uuid NOT NULL,
  following_id uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT follows_pkey PRIMARY KEY (follower_id, following_id),
  CONSTRAINT follows_follower_id_fkey FOREIGN KEY (follower_id) REFERENCES public.profiles(user_id),
  CONSTRAINT follows_following_id_fkey FOREIGN KEY (following_id) REFERENCES public.profiles(user_id)
);
CREATE TABLE public.human_verifications (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  status USER-DEFINED NOT NULL DEFAULT 'pending'::verification_status,
  method text NOT NULL DEFAULT 'unknown'::text CHECK (method = ANY (ARRAY['unknown'::text, 'phone_otp'::text, 'selfie_liveness'::text, 'id_document'::text, 'manual_review'::text])),
  evidence_storage_path text,
  reviewer_admin_id uuid,
  reviewer_notes text,
  submitted_at timestamp with time zone NOT NULL DEFAULT now(),
  reviewed_at timestamp with time zone,
  CONSTRAINT human_verifications_pkey PRIMARY KEY (id),
  CONSTRAINT human_verifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(user_id),
  CONSTRAINT human_verifications_reviewer_admin_id_fkey FOREIGN KEY (reviewer_admin_id) REFERENCES public.admin_users(user_id)
);
CREATE TABLE public.mentions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  post_id uuid,
  comment_id uuid,
  mentioned_user_id uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT mentions_pkey PRIMARY KEY (id),
  CONSTRAINT mentions_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id),
  CONSTRAINT mentions_comment_id_fkey FOREIGN KEY (comment_id) REFERENCES public.comments(id),
  CONSTRAINT mentions_mentioned_user_id_fkey FOREIGN KEY (mentioned_user_id) REFERENCES public.profiles(user_id)
);
CREATE TABLE public.messages (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL,
  sender_id uuid NOT NULL,
  content text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  is_read boolean NOT NULL DEFAULT false,
  message_type text DEFAULT 'text'::text,
  media_url text,
  reply_to_id uuid,
  reply_content text,
  CONSTRAINT messages_pkey PRIMARY KEY (id),
  CONSTRAINT messages_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.conversations(id),
  CONSTRAINT messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES public.profiles(user_id),
  CONSTRAINT messages_reply_to_id_fkey FOREIGN KEY (reply_to_id) REFERENCES public.messages(id)
);
CREATE TABLE public.moderation_cases (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  post_id uuid,
  comment_id uuid,
  reported_user_id uuid,
  reason USER-DEFINED NOT NULL,
  source text NOT NULL DEFAULT 'ai'::text CHECK (source = ANY (ARRAY['ai'::text, 'user_report'::text, 'system'::text])),
  description text,
  ai_confidence numeric,
  ai_model text,
  ai_metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  status USER-DEFINED NOT NULL DEFAULT 'pending'::moderation_status,
  assigned_admin_id uuid,
  decision USER-DEFINED,
  decision_notes text,
  decided_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT moderation_cases_pkey PRIMARY KEY (id),
  CONSTRAINT moderation_cases_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id),
  CONSTRAINT moderation_cases_comment_id_fkey FOREIGN KEY (comment_id) REFERENCES public.comments(id),
  CONSTRAINT moderation_cases_reported_user_id_fkey FOREIGN KEY (reported_user_id) REFERENCES public.profiles(user_id),
  CONSTRAINT moderation_cases_assigned_admin_id_fkey FOREIGN KEY (assigned_admin_id) REFERENCES public.admin_users(user_id)
);
CREATE TABLE public.mutes (
  muter_id uuid NOT NULL,
  muted_id uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT mutes_pkey PRIMARY KEY (muter_id, muted_id),
  CONSTRAINT mutes_muter_id_fkey FOREIGN KEY (muter_id) REFERENCES public.profiles(user_id),
  CONSTRAINT mutes_muted_id_fkey FOREIGN KEY (muted_id) REFERENCES public.profiles(user_id)
);
CREATE TABLE public.notification_preferences (
  user_id uuid NOT NULL,
  notify_follows boolean NOT NULL DEFAULT true,
  notify_comments boolean NOT NULL DEFAULT true,
  notify_reactions boolean NOT NULL DEFAULT true,
  notify_mentions boolean NOT NULL DEFAULT true,
  notify_moderation boolean NOT NULL DEFAULT true,
  notify_roocoin boolean NOT NULL DEFAULT true,
  notify_staking boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT notification_preferences_pkey PRIMARY KEY (user_id),
  CONSTRAINT notification_preferences_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(user_id)
);
CREATE TABLE public.notifications (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  type USER-DEFINED NOT NULL,
  title text,
  body text,
  is_read boolean NOT NULL DEFAULT false,
  actor_id uuid,
  post_id uuid,
  comment_id uuid,
  appeal_id uuid,
  moderation_case_id uuid,
  roocoin_tx_id uuid,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT notifications_pkey PRIMARY KEY (id),
  CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(user_id),
  CONSTRAINT notifications_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.profiles(user_id),
  CONSTRAINT notifications_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id),
  CONSTRAINT notifications_comment_id_fkey FOREIGN KEY (comment_id) REFERENCES public.comments(id),
  CONSTRAINT notifications_appeal_fk FOREIGN KEY (appeal_id) REFERENCES public.appeals(id),
  CONSTRAINT notifications_moderation_case_fk FOREIGN KEY (moderation_case_id) REFERENCES public.moderation_cases(id),
  CONSTRAINT notifications_roocoin_tx_fk FOREIGN KEY (roocoin_tx_id) REFERENCES public.roocoin_transactions(id)
);
CREATE TABLE public.platform_config (
  id smallint NOT NULL DEFAULT 1 CHECK (id = 1),
  allow_new_signups boolean NOT NULL DEFAULT true,
  maintenance_mode boolean NOT NULL DEFAULT false,
  roocoin_trading_enabled boolean NOT NULL DEFAULT true,
  ai_flag_threshold numeric NOT NULL DEFAULT 85,
  auto_ban_threshold numeric NOT NULL DEFAULT 98,
  max_post_length integer NOT NULL DEFAULT 5000,
  max_comment_length integer NOT NULL DEFAULT 2000,
  default_publish_fee_rc numeric NOT NULL DEFAULT 0,
  default_staking_apy_percent numeric NOT NULL DEFAULT 0,
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT platform_config_pkey PRIMARY KEY (id)
);
CREATE TABLE public.post_media (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL,
  media_type USER-DEFINED NOT NULL,
  storage_path text NOT NULL,
  mime_type text,
  width integer,
  height integer,
  duration_seconds numeric,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT post_media_pkey PRIMARY KEY (id),
  CONSTRAINT post_media_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id)
);
CREATE TABLE public.post_tags (
  post_id uuid NOT NULL,
  tag_id uuid NOT NULL,
  CONSTRAINT post_tags_pkey PRIMARY KEY (post_id, tag_id),
  CONSTRAINT post_tags_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id),
  CONSTRAINT post_tags_tag_id_fkey FOREIGN KEY (tag_id) REFERENCES public.tags(id)
);
CREATE TABLE public.posts (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  author_id uuid NOT NULL,
  title text,
  body text NOT NULL DEFAULT ''::text,
  body_format text NOT NULL DEFAULT 'markdown'::text CHECK (body_format = ANY (ARRAY['plain'::text, 'markdown'::text])),
  status USER-DEFINED NOT NULL DEFAULT 'draft'::post_status,
  human_certified boolean NOT NULL DEFAULT false,
  authenticity_notes text,
  publish_fee_rc numeric NOT NULL DEFAULT 0,
  is_sensitive boolean NOT NULL DEFAULT false,
  sensitive_reason USER-DEFINED,
  published_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  location text,
  CONSTRAINT posts_pkey PRIMARY KEY (id),
  CONSTRAINT posts_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.profiles(user_id)
);
CREATE TABLE public.profile_links (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  label text NOT NULL,
  url text NOT NULL,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT profile_links_pkey PRIMARY KEY (id),
  CONSTRAINT profile_links_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(user_id)
);
CREATE TABLE public.profiles (
  user_id uuid NOT NULL,
  username text NOT NULL UNIQUE CHECK (char_length(username) >= 3 AND char_length(username) <= 32),
  display_name text NOT NULL DEFAULT ''::text,
  bio text NOT NULL DEFAULT ''::text,
  avatar_url text,
  website_url text,
  location text,
  status USER-DEFINED NOT NULL DEFAULT 'active'::user_status,
  trust_score numeric NOT NULL DEFAULT 0,
  ml_score numeric NOT NULL DEFAULT 0,
  verified_human USER-DEFINED NOT NULL DEFAULT 'unverified'::verification_status,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  last_seen timestamp with time zone DEFAULT now(),
  interests jsonb DEFAULT '[]'::jsonb,
  posts_visibility text DEFAULT 'everyone'::text,
  comments_visibility text DEFAULT 'everyone'::text,
  messages_visibility text DEFAULT 'everyone'::text,
  CONSTRAINT profiles_pkey PRIMARY KEY (user_id),
  CONSTRAINT profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.reactions (
  user_id uuid NOT NULL,
  post_id uuid,
  comment_id uuid,
  reaction USER-DEFINED NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  CONSTRAINT reactions_pkey PRIMARY KEY (id),
  CONSTRAINT reactions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(user_id),
  CONSTRAINT reactions_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id),
  CONSTRAINT reactions_comment_id_fkey FOREIGN KEY (comment_id) REFERENCES public.comments(id)
);
CREATE TABLE public.reposts (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  post_id uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT reposts_pkey PRIMARY KEY (id),
  CONSTRAINT reposts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(user_id),
  CONSTRAINT reposts_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id)
);
CREATE TABLE public.roocoin_transactions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  tx_type USER-DEFINED NOT NULL,
  status USER-DEFINED NOT NULL DEFAULT 'pending'::roocoin_tx_status,
  from_user_id uuid,
  to_user_id uuid,
  amount_rc numeric NOT NULL CHECK (amount_rc >= 0::numeric),
  fee_rc numeric NOT NULL DEFAULT 0,
  reference_post_id uuid,
  reference_comment_id uuid,
  memo text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  completed_at timestamp with time zone,
  CONSTRAINT roocoin_transactions_pkey PRIMARY KEY (id),
  CONSTRAINT roocoin_transactions_from_user_id_fkey FOREIGN KEY (from_user_id) REFERENCES public.wallets(user_id),
  CONSTRAINT roocoin_transactions_to_user_id_fkey FOREIGN KEY (to_user_id) REFERENCES public.wallets(user_id),
  CONSTRAINT roocoin_transactions_reference_post_id_fkey FOREIGN KEY (reference_post_id) REFERENCES public.posts(id),
  CONSTRAINT roocoin_transactions_reference_comment_id_fkey FOREIGN KEY (reference_comment_id) REFERENCES public.comments(id)
);
CREATE TABLE public.staking_positions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  amount_rc numeric NOT NULL CHECK (amount_rc > 0::numeric),
  apy_percent numeric NOT NULL DEFAULT 0,
  lock_days integer NOT NULL DEFAULT 0,
  status USER-DEFINED NOT NULL DEFAULT 'active'::staking_status,
  started_at timestamp with time zone NOT NULL DEFAULT now(),
  unlock_at timestamp with time zone,
  closed_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT staking_positions_pkey PRIMARY KEY (id),
  CONSTRAINT staking_positions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.wallets(user_id)
);
CREATE TABLE public.staking_rewards (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  position_id uuid NOT NULL,
  user_id uuid NOT NULL,
  amount_rc numeric NOT NULL CHECK (amount_rc >= 0::numeric),
  period_start timestamp with time zone,
  period_end timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT staking_rewards_pkey PRIMARY KEY (id),
  CONSTRAINT staking_rewards_position_id_fkey FOREIGN KEY (position_id) REFERENCES public.staking_positions(id),
  CONSTRAINT staking_rewards_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.wallets(user_id)
);
CREATE TABLE public.tags (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  tag text NOT NULL UNIQUE,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT tags_pkey PRIMARY KEY (id)
);
CREATE TABLE public.treasury_actions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  admin_id uuid NOT NULL,
  action text NOT NULL CHECK (action = ANY (ARRAY['mint'::text, 'burn'::text, 'freeze_global_trading'::text, 'unfreeze_global_trading'::text, 'adjust_user_balance'::text, 'freeze_user_wallet'::text, 'unfreeze_user_wallet'::text])),
  target_user_id uuid,
  amount_rc numeric,
  reason text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT treasury_actions_pkey PRIMARY KEY (id),
  CONSTRAINT treasury_actions_admin_id_fkey FOREIGN KEY (admin_id) REFERENCES public.admin_users(user_id),
  CONSTRAINT treasury_actions_target_user_id_fkey FOREIGN KEY (target_user_id) REFERENCES public.profiles(user_id)
);
CREATE TABLE public.treasury_wallet (
  id smallint NOT NULL DEFAULT 1 CHECK (id = 1),
  balance_rc numeric NOT NULL DEFAULT 0,
  trading_frozen boolean NOT NULL DEFAULT false,
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT treasury_wallet_pkey PRIMARY KEY (id)
);
CREATE TABLE public.trust_events (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  event_type text NOT NULL,
  delta numeric NOT NULL DEFAULT 0,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT trust_events_pkey PRIMARY KEY (id),
  CONSTRAINT trust_events_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(user_id)
);
CREATE TABLE public.user_reports (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  reporter_id uuid NOT NULL,
  post_id uuid,
  comment_id uuid,
  reported_user_id uuid,
  reason USER-DEFINED NOT NULL,
  details text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT user_reports_pkey PRIMARY KEY (id),
  CONSTRAINT user_reports_reporter_id_fkey FOREIGN KEY (reporter_id) REFERENCES public.profiles(user_id),
  CONSTRAINT user_reports_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id),
  CONSTRAINT user_reports_comment_id_fkey FOREIGN KEY (comment_id) REFERENCES public.comments(id),
  CONSTRAINT user_reports_reported_user_id_fkey FOREIGN KEY (reported_user_id) REFERENCES public.profiles(user_id)
);
CREATE TABLE public.wallets (
  user_id uuid NOT NULL,
  balance_rc numeric NOT NULL DEFAULT 0,
  is_frozen boolean NOT NULL DEFAULT false,
  frozen_reason text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT wallets_pkey PRIMARY KEY (user_id),
  CONSTRAINT wallets_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(user_id)
);