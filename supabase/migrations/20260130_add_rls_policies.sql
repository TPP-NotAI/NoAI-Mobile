-- ============================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- Apply this migration to your Supabase project to enforce
-- ownership and privacy at the database level.
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- 1. PROFILES
-- ────────────────────────────────────────────────────────────
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Anyone can view profiles (app handles visibility filtering)
CREATE POLICY "Profiles are viewable by everyone"
  ON public.profiles FOR SELECT
  USING (true);

-- Users can only update their own profile
CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Profiles are created by database trigger on auth.users insert
CREATE POLICY "Profiles are created via trigger"
  ON public.profiles FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- ────────────────────────────────────────────────────────────
-- 2. POSTS
-- ────────────────────────────────────────────────────────────
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;

-- Anyone can view published posts (app handles privacy filtering)
CREATE POLICY "Published posts are viewable by everyone"
  ON public.posts FOR SELECT
  USING (true);

-- Authenticated users can create posts (as themselves only)
CREATE POLICY "Users can create own posts"
  ON public.posts FOR INSERT
  WITH CHECK (auth.uid() = author_id);

-- Users can only update their own posts
CREATE POLICY "Users can update own posts"
  ON public.posts FOR UPDATE
  USING (auth.uid() = author_id)
  WITH CHECK (auth.uid() = author_id);

-- Users can only delete their own posts
CREATE POLICY "Users can delete own posts"
  ON public.posts FOR DELETE
  USING (auth.uid() = author_id);

-- ────────────────────────────────────────────────────────────
-- 3. POST MEDIA
-- ────────────────────────────────────────────────────────────
ALTER TABLE public.post_media ENABLE ROW LEVEL SECURITY;

-- Anyone can view post media
CREATE POLICY "Post media is viewable by everyone"
  ON public.post_media FOR SELECT
  USING (true);

-- Users can insert media for their own posts
CREATE POLICY "Users can add media to own posts"
  ON public.post_media FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.posts
      WHERE posts.id = post_id AND posts.author_id = auth.uid()
    )
  );

-- Users can delete media from their own posts
CREATE POLICY "Users can delete media from own posts"
  ON public.post_media FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.posts
      WHERE posts.id = post_id AND posts.author_id = auth.uid()
    )
  );

-- ────────────────────────────────────────────────────────────
-- 4. COMMENTS
-- ────────────────────────────────────────────────────────────
ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;

-- Anyone can view comments (app handles privacy filtering)
CREATE POLICY "Comments are viewable by everyone"
  ON public.comments FOR SELECT
  USING (true);

-- Authenticated users can create comments (as themselves only)
CREATE POLICY "Users can create own comments"
  ON public.comments FOR INSERT
  WITH CHECK (auth.uid() = author_id);

-- Users can only update their own comments
CREATE POLICY "Users can update own comments"
  ON public.comments FOR UPDATE
  USING (auth.uid() = author_id)
  WITH CHECK (auth.uid() = author_id);

-- Users can only delete their own comments
CREATE POLICY "Users can delete own comments"
  ON public.comments FOR DELETE
  USING (auth.uid() = author_id);

-- ────────────────────────────────────────────────────────────
-- 5. REACTIONS
-- ────────────────────────────────────────────────────────────
ALTER TABLE public.reactions ENABLE ROW LEVEL SECURITY;

-- Anyone can view reactions
CREATE POLICY "Reactions are viewable by everyone"
  ON public.reactions FOR SELECT
  USING (true);

-- Users can only create their own reactions
CREATE POLICY "Users can create own reactions"
  ON public.reactions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can only delete their own reactions
CREATE POLICY "Users can delete own reactions"
  ON public.reactions FOR DELETE
  USING (auth.uid() = user_id);

-- ────────────────────────────────────────────────────────────
-- 6. BOOKMARKS
-- ────────────────────────────────────────────────────────────
ALTER TABLE public.bookmarks ENABLE ROW LEVEL SECURITY;

-- Users can only view their own bookmarks
CREATE POLICY "Users can view own bookmarks"
  ON public.bookmarks FOR SELECT
  USING (auth.uid() = user_id);

-- Users can only create their own bookmarks
CREATE POLICY "Users can create own bookmarks"
  ON public.bookmarks FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can only delete their own bookmarks
CREATE POLICY "Users can delete own bookmarks"
  ON public.bookmarks FOR DELETE
  USING (auth.uid() = user_id);

-- ────────────────────────────────────────────────────────────
-- 7. REPOSTS
-- ────────────────────────────────────────────────────────────
ALTER TABLE public.reposts ENABLE ROW LEVEL SECURITY;

-- Anyone can view reposts
CREATE POLICY "Reposts are viewable by everyone"
  ON public.reposts FOR SELECT
  USING (true);

-- Users can only create their own reposts
CREATE POLICY "Users can create own reposts"
  ON public.reposts FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can only delete their own reposts
CREATE POLICY "Users can delete own reposts"
  ON public.reposts FOR DELETE
  USING (auth.uid() = user_id);

-- ────────────────────────────────────────────────────────────
-- 8. FOLLOWS
-- ────────────────────────────────────────────────────────────
ALTER TABLE public.follows ENABLE ROW LEVEL SECURITY;

-- Anyone can view follows
CREATE POLICY "Follows are viewable by everyone"
  ON public.follows FOR SELECT
  USING (true);

-- Users can only create follows as themselves (follower)
CREATE POLICY "Users can follow others"
  ON public.follows FOR INSERT
  WITH CHECK (auth.uid() = follower_id);

-- Users can only delete their own follows
CREATE POLICY "Users can unfollow"
  ON public.follows FOR DELETE
  USING (auth.uid() = follower_id);

-- ────────────────────────────────────────────────────────────
-- 9. BLOCKS
-- ────────────────────────────────────────────────────────────
ALTER TABLE public.blocks ENABLE ROW LEVEL SECURITY;

-- Users can see blocks they are involved in (as blocker or blocked)
CREATE POLICY "Users can view own blocks"
  ON public.blocks FOR SELECT
  USING (auth.uid() = blocker_id OR auth.uid() = blocked_id);

-- Users can only create blocks as themselves
CREATE POLICY "Users can block others"
  ON public.blocks FOR INSERT
  WITH CHECK (auth.uid() = blocker_id);

-- Users can only remove blocks they created
CREATE POLICY "Users can unblock"
  ON public.blocks FOR DELETE
  USING (auth.uid() = blocker_id);

-- ────────────────────────────────────────────────────────────
-- 10. MUTES
-- ────────────────────────────────────────────────────────────
ALTER TABLE public.mutes ENABLE ROW LEVEL SECURITY;

-- Users can only view their own mutes
CREATE POLICY "Users can view own mutes"
  ON public.mutes FOR SELECT
  USING (auth.uid() = muter_id);

-- Users can only create mutes as themselves
CREATE POLICY "Users can mute others"
  ON public.mutes FOR INSERT
  WITH CHECK (auth.uid() = muter_id);

-- Users can only remove their own mutes
CREATE POLICY "Users can unmute"
  ON public.mutes FOR DELETE
  USING (auth.uid() = muter_id);

-- ────────────────────────────────────────────────────────────
-- 11. NOTIFICATIONS
-- ────────────────────────────────────────────────────────────
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Users can only view their own notifications
CREATE POLICY "Users can view own notifications"
  ON public.notifications FOR SELECT
  USING (auth.uid() = user_id);

-- Authenticated users can create notifications (for other users)
CREATE POLICY "Authenticated users can create notifications"
  ON public.notifications FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

-- Users can only update their own notifications (mark as read)
CREATE POLICY "Users can update own notifications"
  ON public.notifications FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Users can only delete their own notifications
CREATE POLICY "Users can delete own notifications"
  ON public.notifications FOR DELETE
  USING (auth.uid() = user_id);

-- ────────────────────────────────────────────────────────────
-- 12. NOTIFICATION PREFERENCES
-- ────────────────────────────────────────────────────────────
ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;

-- Users can only view their own preferences
CREATE POLICY "Users can view own notification preferences"
  ON public.notification_preferences FOR SELECT
  USING (auth.uid() = user_id);

-- Users can only create their own preferences
CREATE POLICY "Users can create own notification preferences"
  ON public.notification_preferences FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can only update their own preferences
CREATE POLICY "Users can update own notification preferences"
  ON public.notification_preferences FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ────────────────────────────────────────────────────────────
-- 13. MENTIONS
-- ────────────────────────────────────────────────────────────
ALTER TABLE public.mentions ENABLE ROW LEVEL SECURITY;

-- Anyone can view mentions
CREATE POLICY "Mentions are viewable by everyone"
  ON public.mentions FOR SELECT
  USING (true);

-- Authenticated users can create mentions
CREATE POLICY "Authenticated users can create mentions"
  ON public.mentions FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

-- Authenticated users can delete mentions (from their own posts/comments)
CREATE POLICY "Users can delete mentions from own content"
  ON public.mentions FOR DELETE
  USING (
    (post_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM public.posts WHERE posts.id = post_id AND posts.author_id = auth.uid()
    ))
    OR
    (comment_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM public.comments WHERE comments.id = comment_id AND comments.author_id = auth.uid()
    ))
  );

-- ────────────────────────────────────────────────────────────
-- 14. TAGS & POST_TAGS
-- ────────────────────────────────────────────────────────────
ALTER TABLE public.tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_tags ENABLE ROW LEVEL SECURITY;

-- Anyone can view tags
CREATE POLICY "Tags are viewable by everyone"
  ON public.tags FOR SELECT
  USING (true);

-- Authenticated users can create tags
CREATE POLICY "Authenticated users can create tags"
  ON public.tags FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

-- Anyone can view post_tags
CREATE POLICY "Post tags are viewable by everyone"
  ON public.post_tags FOR SELECT
  USING (true);

-- Users can add tags to their own posts
CREATE POLICY "Users can tag own posts"
  ON public.post_tags FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.posts
      WHERE posts.id = post_id AND posts.author_id = auth.uid()
    )
  );

-- Users can remove tags from their own posts
CREATE POLICY "Users can untag own posts"
  ON public.post_tags FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.posts
      WHERE posts.id = post_id AND posts.author_id = auth.uid()
    )
  );

-- ────────────────────────────────────────────────────────────
-- 15. CONVERSATIONS & MESSAGES
-- ────────────────────────────────────────────────────────────
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversation_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- Users can only view conversations they participate in
CREATE POLICY "Users can view own conversations"
  ON public.conversations FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.conversation_participants
      WHERE conversation_participants.conversation_id = id
        AND conversation_participants.user_id = auth.uid()
    )
  );

-- Authenticated users can create conversations
CREATE POLICY "Authenticated users can create conversations"
  ON public.conversations FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

-- Users can update conversations they participate in
CREATE POLICY "Participants can update conversations"
  ON public.conversations FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.conversation_participants
      WHERE conversation_participants.conversation_id = id
        AND conversation_participants.user_id = auth.uid()
    )
  );

-- Users can view participant records for their conversations
CREATE POLICY "Users can view conversation participants"
  ON public.conversation_participants FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.conversation_participants AS cp
      WHERE cp.conversation_id = conversation_id
        AND cp.user_id = auth.uid()
    )
  );

-- Authenticated users can add participants
CREATE POLICY "Authenticated users can add participants"
  ON public.conversation_participants FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

-- Users can only view messages in their conversations
CREATE POLICY "Users can view messages in own conversations"
  ON public.messages FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.conversation_participants
      WHERE conversation_participants.conversation_id = conversation_id
        AND conversation_participants.user_id = auth.uid()
    )
  );

-- Users can send messages to conversations they participate in
CREATE POLICY "Users can send messages in own conversations"
  ON public.messages FOR INSERT
  WITH CHECK (
    auth.uid() = sender_id
    AND EXISTS (
      SELECT 1 FROM public.conversation_participants
      WHERE conversation_participants.conversation_id = conversation_id
        AND conversation_participants.user_id = auth.uid()
    )
  );

-- Users can update messages in their conversations (mark read)
CREATE POLICY "Participants can update messages"
  ON public.messages FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.conversation_participants
      WHERE conversation_participants.conversation_id = conversation_id
        AND conversation_participants.user_id = auth.uid()
    )
  );

-- ────────────────────────────────────────────────────────────
-- 16. PROFILE LINKS
-- ────────────────────────────────────────────────────────────
ALTER TABLE public.profile_links ENABLE ROW LEVEL SECURITY;

-- Anyone can view profile links
CREATE POLICY "Profile links are viewable by everyone"
  ON public.profile_links FOR SELECT
  USING (true);

-- Users can only manage their own profile links
CREATE POLICY "Users can create own profile links"
  ON public.profile_links FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own profile links"
  ON public.profile_links FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own profile links"
  ON public.profile_links FOR DELETE
  USING (auth.uid() = user_id);

-- ────────────────────────────────────────────────────────────
-- 17. USER REPORTS
-- ────────────────────────────────────────────────────────────
ALTER TABLE public.user_reports ENABLE ROW LEVEL SECURITY;

-- Users can only view their own reports
CREATE POLICY "Users can view own reports"
  ON public.user_reports FOR SELECT
  USING (auth.uid() = reporter_id);

-- Users can create reports
CREATE POLICY "Users can create reports"
  ON public.user_reports FOR INSERT
  WITH CHECK (auth.uid() = reporter_id);

-- ────────────────────────────────────────────────────────────
-- 18. WALLETS (future feature - protect now)
-- ────────────────────────────────────────────────────────────
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;

-- Users can only view their own wallet
CREATE POLICY "Users can view own wallet"
  ON public.wallets FOR SELECT
  USING (auth.uid() = user_id);

-- Wallets are created by database trigger
CREATE POLICY "Wallets created via trigger"
  ON public.wallets FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users cannot directly update wallets (done via server-side functions)
-- No UPDATE policy = no direct updates allowed

-- ────────────────────────────────────────────────────────────
-- 19. ROOCOIN TRANSACTIONS (future feature - protect now)
-- ────────────────────────────────────────────────────────────
ALTER TABLE public.roocoin_transactions ENABLE ROW LEVEL SECURITY;

-- Users can view transactions they are involved in
CREATE POLICY "Users can view own transactions"
  ON public.roocoin_transactions FOR SELECT
  USING (auth.uid() = from_user_id OR auth.uid() = to_user_id);

-- No INSERT/UPDATE/DELETE policies: transactions handled server-side

-- ────────────────────────────────────────────────────────────
-- 20. STAKING (future feature - protect now)
-- ────────────────────────────────────────────────────────────
ALTER TABLE public.staking_positions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staking_rewards ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own staking positions"
  ON public.staking_positions FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can view own staking rewards"
  ON public.staking_rewards FOR SELECT
  USING (auth.uid() = user_id);

-- ────────────────────────────────────────────────────────────
-- 21. HUMAN VERIFICATIONS
-- ────────────────────────────────────────────────────────────
ALTER TABLE public.human_verifications ENABLE ROW LEVEL SECURITY;

-- Users can view their own verifications
CREATE POLICY "Users can view own verifications"
  ON public.human_verifications FOR SELECT
  USING (auth.uid() = user_id);

-- Users can submit verifications
CREATE POLICY "Users can submit verifications"
  ON public.human_verifications FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- ────────────────────────────────────────────────────────────
-- 22. DM SYSTEM (future - protect now)
-- ────────────────────────────────────────────────────────────
ALTER TABLE public.dm_threads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dm_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dm_participants ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own DM threads"
  ON public.dm_threads FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.dm_participants
      WHERE dm_participants.thread_id = id
        AND dm_participants.user_id = auth.uid()
    )
  );

CREATE POLICY "Authenticated users can create DM threads"
  ON public.dm_threads FOR INSERT
  WITH CHECK (auth.uid() = created_by);

CREATE POLICY "Users can view own DM messages"
  ON public.dm_messages FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.dm_participants
      WHERE dm_participants.thread_id = thread_id
        AND dm_participants.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can send DM messages"
  ON public.dm_messages FOR INSERT
  WITH CHECK (
    auth.uid() = sender_id
    AND EXISTS (
      SELECT 1 FROM public.dm_participants
      WHERE dm_participants.thread_id = thread_id
        AND dm_participants.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can view DM participants for own threads"
  ON public.dm_participants FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.dm_participants AS dp
      WHERE dp.thread_id = thread_id
        AND dp.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can add DM participants"
  ON public.dm_participants FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

-- ────────────────────────────────────────────────────────────
-- 23. MODERATION (admin-only tables)
-- ────────────────────────────────────────────────────────────
ALTER TABLE public.moderation_cases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.appeals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_permissions ENABLE ROW LEVEL SECURITY;

-- Users can view moderation cases about their own content
CREATE POLICY "Users can view own moderation cases"
  ON public.moderation_cases FOR SELECT
  USING (auth.uid() = reported_user_id);

-- Users can view and create their own appeals
CREATE POLICY "Users can view own appeals"
  ON public.appeals FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can create own appeals"
  ON public.appeals FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Admin tables: no public access (managed via service role key)
-- No policies = default deny for admin_users, admin_permissions, audit_logs

-- ────────────────────────────────────────────────────────────
-- 24. TRUST EVENTS
-- ────────────────────────────────────────────────────────────
ALTER TABLE public.trust_events ENABLE ROW LEVEL SECURITY;

-- Users can view their own trust events
CREATE POLICY "Users can view own trust events"
  ON public.trust_events FOR SELECT
  USING (auth.uid() = user_id);

-- No INSERT/UPDATE/DELETE: managed server-side

-- ────────────────────────────────────────────────────────────
-- 25. PLATFORM CONFIG & TREASURY (admin-only)
-- ────────────────────────────────────────────────────────────
ALTER TABLE public.platform_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.treasury_wallet ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.treasury_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.background_jobs ENABLE ROW LEVEL SECURITY;

-- Platform config: read-only for authenticated users
CREATE POLICY "Authenticated users can read platform config"
  ON public.platform_config FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- Treasury/admin tables: no public access
-- No policies = default deny
