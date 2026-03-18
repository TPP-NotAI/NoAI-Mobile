# Crash Prevention & Scale Guide (1M+ Users)

## Status: Implemented
Items marked ✅ are already done in code. Items marked ⬜ are pending.

---

## Priority 1 — Crashes That Happen Today ✅ (all done)

### 1. ✅ `setState` after dispose on stream listeners
**Files:** `lib/screens/chat/conversation_thread_page.dart`, `lib/screens/dm/dm_thread_page.dart`
Added `onError` handlers and `mounted` checks to all stream subscriptions.

### 2. ✅ Unsafe casts and missing `orElse`
**File:** `lib/services/chat_service.dart`
- `(response as List? ?? [])` — null-safe
- `firstWhere(..., orElse: () => null)` + null check
- `DateTime.tryParse()` instead of `DateTime.parse()`

### 3. ✅ Concurrent auth profile loads (race condition)
**File:** `lib/providers/auth_provider.dart`
Added `_isLoadingUser` flag — concurrent calls bail out immediately.

### 4. ✅ Timer leaks in dm_thread_page
**File:** `lib/screens/dm/dm_thread_page.dart`
All timers (`_statusUpdateTimer`, `_recordingTimer`) cancelled in `dispose()` and before recreation.

### 5. ✅ Global error handler in main.dart
**File:** `lib/main.dart`
`FlutterError.onError`, `PlatformDispatcher.instance.onError`, `runZonedGuarded` all wired up.

---

## Priority 2 — Degradation at Scale ✅ (all done)

### 6. ✅ Realtime channels properly unsubscribed
**Files:** `lib/providers/chat_provider.dart`, `lib/providers/dm_provider.dart`
Both call `removeChannel()` in `stopListening()` / `_clearRealtimeSubscriptions()`.

### 7. ✅ `_pendingMessages` not cleared on logout
**File:** `lib/providers/chat_provider.dart` — `_pendingMessages.clear()` added to `clear()`.

### 8. ✅ SharedPreferences JSON corruption guard
**File:** `lib/providers/chat_provider.dart` — `jsonDecode()` wrapped in try/catch, corrupted key cleared.

### 9. ✅ Firebase Crashlytics integrated
**Files:** `pubspec.yaml`, `lib/main.dart`, `lib/services/analytics_service.dart`
- `firebase_crashlytics: ^4.1.3` added
- All 3 error handlers report to Crashlytics
- `setUserId` sets identity in both Analytics and Crashlytics on login

---

## Priority 3 — Still Pending ⬜

### 10. ⬜ Pagination for messages
**File:** `lib/services/chat_service.dart` → `subscribeToMessages()`
Load last 50 messages on open, fetch older on scroll-up (cursor pagination).
Without this: 10,000+ message threads crash the UI and exhaust memory.

### 11. ⬜ Pagination for conversations list
Load first 20 conversations, paginate on scroll.
Without this: users with 500+ threads will see slow loads.

### 12. ⬜ Pending messages expire after 30s
**File:** `lib/providers/chat_provider.dart` → `getMessageStream()`
Pending messages that never get confirmed by the server accumulate in memory forever (O(n²) comparison on every stream event).
```dart
final pending = (_pendingMessages[conversationId] ?? [])
    .where((p) => DateTime.now().difference(p.sentAt).inSeconds < 30)
    ...
```

### 13. ⬜ File size limit before upload
**Files:** `lib/screens/chat/conversation_thread_page.dart`, `lib/screens/dm/dm_thread_page.dart`
Add max file size check before calling `video_compress` — no timeout on large files causes infinite hangs.

### 14. ⬜ Add Firebase Performance Monitoring
**Package:** `firebase_performance`
Measures how long key operations take (load conversations, send message, load feed).
Catches slow Supabase queries before users complain.
```dart
final trace = FirebasePerformance.instance.newTrace('load_conversations');
await trace.start();
// ... your operation
await trace.stop();
```

---

## Priority 4 — Backend / Supabase (no code changes, dashboard actions) ⬜

### 15. ⬜ Add database indexes
Run these in Supabase SQL Editor. Without them, every query does a full table scan at scale.
```sql
CREATE INDEX IF NOT EXISTS idx_dm_messages_thread_created
  ON dm_messages(thread_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_dm_participants_user
  ON dm_participants(user_id);

CREATE INDEX IF NOT EXISTS idx_dm_participants_thread
  ON dm_participants(thread_id);

CREATE INDEX IF NOT EXISTS idx_profiles_user_id
  ON profiles(user_id);
```

### 16. ⬜ Verify Row Level Security (RLS) policies
Every table must filter by `auth.uid()` at the policy level, not just in app code.
Example of a correct policy:
```sql
CREATE POLICY "Users see own threads"
ON dm_participants FOR SELECT
USING (user_id = auth.uid());
```
Without tight RLS, Postgres scans all rows then filters — collapses at scale.

### 17. ⬜ Enable connection pooling in Supabase
Go to: **Supabase Dashboard → Settings → Database → Connection Pooling**
Enable PgBouncer in **Transaction mode**.
Without it, each Flutter client opens a raw Postgres connection — Postgres fails around 200–500 concurrent connections.

### 18. ⬜ Supabase plan upgrade before launch
- Free plan: 200 concurrent realtime connections
- Pro plan: 500 concurrent realtime connections
- Your app uses **3 realtime channels per user** (messages + threads + DMs)
- At 200 concurrent users you're already at the free limit
- Need **Team or Enterprise plan** for 1M users, or self-host Supabase

### 19. ⬜ CDN for media (Supabase Storage)
Enable CDN in **Supabase Dashboard → Storage → Settings**.
Without it, every image/video hits the storage server directly — collapses under load.

### 20. ⬜ Rate limiting
Add a Supabase Edge Function or policy to limit requests per user per second.
Without it, one bad actor can spam the DB and degrade performance for all users.

---

## Priority 5 — Push Notifications at Scale ⬜

### 21. ⬜ Batch FCM sends
At 1M users, sending individual FCM calls per notification (e.g. viral post liked by 50,000 people) will hit FCM rate limits and exhaust server resources.
- Use **FCM topic messaging** for broadcast notifications
- Use **FCM batch send API** for targeted multi-user sends
- Never fire N individual FCM calls in a loop

---

## Monitoring Checklist

| Tool | Status | What it catches |
|------|--------|----------------|
| Firebase Crashlytics | ✅ Done | App crashes with stack traces |
| Firebase Analytics | ✅ Already had | User retention, drop-off |
| Firebase Performance | ⬜ Add | Slow network calls, slow screen loads |
| Supabase Dashboard → Reports | ⬜ Check regularly | Slow queries, high DB load |

---

## Quick Wins (do these first, zero code needed)

1. **Run the SQL indexes** (15) — 2 minutes in Supabase SQL Editor, massive query speed improvement
2. **Check RLS policies** (16) — verify every table filters by `auth.uid()`
3. **Enable connection pooling** (17) — checkbox in Supabase dashboard
4. **Enable CDN on Storage** (19) — checkbox in Supabase dashboard
5. **Upgrade Supabase plan** (18) before any real user traffic

---

## Files Modified (implemented)

| File | Change |
|------|--------|
| `pubspec.yaml` | Added `firebase_crashlytics: ^4.1.3` |
| `lib/main.dart` | All 3 error handlers report to Crashlytics |
| `lib/services/analytics_service.dart` | `setUserId` also sets Crashlytics user identity |
| `lib/providers/auth_provider.dart` | `_isLoadingUser` race condition guard |
| `lib/providers/chat_provider.dart` | `_pendingMessages.clear()` on logout, JSON corruption guard |
| `lib/services/chat_service.dart` | Null-safe casts, `tryParse`, `orElse` |
| `lib/screens/chat/conversation_thread_page.dart` | `onError` on all stream subscriptions |
| `lib/screens/dm/dm_thread_page.dart` | `onError` on all streams, timer leak fix |
