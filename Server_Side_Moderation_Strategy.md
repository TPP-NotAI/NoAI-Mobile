# Server-Side Moderation Strategy (Alternative Method)
### NoAI.org — Web/Backend-Driven AI Approval Pipeline

**Document Purpose:** Alternative architecture to the Keyframe Method. Instead of the mobile app calling the LLM directly, the server handles all AI detection after upload. The app uploads media and moves on — the backend does the rest.

---

## Table of Contents
1. [Core Concept](#1-core-concept)
2. [How It Works — Step by Step](#2-how-it-works--step-by-step)
3. [Architecture Diagram](#3-architecture-diagram)
4. [Timing Estimate — 400MB Video](#4-timing-estimate--400mb-video)
5. [Advantages](#5-advantages)
6. [Disadvantages & Risks](#6-disadvantages--risks)
7. [Solving the Disadvantages](#7-solving-the-disadvantages)
8. [Existing Infrastructure You Can Use](#8-existing-infrastructure-you-can-use)
9. [Implementation Plan](#9-implementation-plan)
10. [Code Reference — What to Build](#10-code-reference--what-to-build)
11. [Comparison: Keyframe vs Server-Side](#11-comparison-keyframe-vs-server-side)
12. [Recommended Hybrid Approach](#12-recommended-hybrid-approach)

---

## 1. Core Concept

### The Problem with the Current Approach

Right now the **mobile app** does everything:
- Uploads the file to Supabase
- Calls the LLM
- Waits for the response
- Updates the database
- User sits waiting the whole time

This means the user's phone is the processing engine. If they close the app, everything dies.

### The Server-Side Idea

**Move all LLM work off the phone and onto the server.**

```
CURRENT (Mobile-driven):
Phone → uploads file → phone calls LLM → phone waits → phone updates DB → post live

ALTERNATIVE (Server-driven):
Phone → uploads file → phone is done ✓ → server detects upload → server calls LLM → server updates DB → post live
```

The phone's only job is to upload the file. Everything after that is the server's responsibility. The user can close the app, lock their phone, switch apps — the post will still be processed and approved automatically.

---

## 2. How It Works — Step by Step

```
1. User taps "Post"
        ↓
2. App creates post record in DB (status: 'under_review')
        ↓
3. App uploads video to Supabase Storage
        ↓
4. App notifies the server (one lightweight HTTP call):
   "Hey, post [postId] is ready for AI check"
        ↓
5. App is DONE — user sees post as "Pending Review" on feed
   User can close app, lock phone, do anything
        ↓
6. Supabase Edge Function receives the notification
        ↓
7. Edge Function calls detectorllm.rooverse.app with the file
        ↓
8. LLM responds (seconds to minutes — server doesn't care, it has no timeout pressure)
        ↓
9. Edge Function updates post status in DB
   (published / under_review / deleted)
        ↓
10. App receives realtime DB change notification
    Post badge updates automatically: "Pending Review" → live post
```

The user experience at step 5 is: "My post is there, it says Pending Review." By step 10, it silently becomes live. They don't wait. They don't watch a spinner.

---

## 3. Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                        MOBILE APP                           │
│                                                             │
│  User posts → Upload to Supabase → Notify server → DONE    │
│                                        ↓                    │
│                              Realtime subscription          │
│                              (listens for status change)    │
└─────────────────────────────────────────────────────────────┘
                              ↑ Realtime update
                              │
┌─────────────────────────────────────────────────────────────┐
│                    SUPABASE PLATFORM                        │
│                                                             │
│  ┌─────────────────┐    ┌──────────────────────────────┐   │
│  │ Storage Bucket  │    │     PostgreSQL Database       │   │
│  │  (post-media)   │    │                              │   │
│  │                 │    │  posts table                 │   │
│  │  400MB video ───┼────┼─ status: under_review        │   │
│  │  stored here    │    │  ai_score: null              │   │
│  └─────────────────┘    │  → status: published ✓       │   │
│           │             └──────────────────────────────┘   │
│           │                           ↑                    │
│  ┌────────▼────────────────────────────────────────────┐   │
│  │              Edge Function                          │   │
│  │         post-ai-analysis/index.ts                   │   │
│  │                                                     │   │
│  │  1. Receives notification from app                  │   │
│  │  2. Gets file from Storage                          │   │
│  │  3. Calls detectorllm.rooverse.app                  │   │
│  │  4. Updates posts table with result                 │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│               detectorllm.rooverse.app                      │
│                                                             │
│  /api/v1/detect/full                                        │
│  Receives file → Runs AI → Returns result                   │
└─────────────────────────────────────────────────────────────┘
```

---

## 4. Timing Estimate — 400MB Video

### User's Felt Experience

| Event | Time | What User Sees |
|-------|------|---------------|
| User taps "Post" | T+0s | Spinner briefly |
| Post created in DB | T+0.5s | Post appears as "Pending Review" |
| App uploads 400MB to Supabase | T+0.5s–7min | Upload progress bar (background) |
| App notifies Edge Function | T+7min | Nothing visible — app already done |
| Edge Function calls LLM | T+7min | User is scrolling feed, unaware |
| LLM processes 400MB | T+7min–22min | User is using app normally |
| Edge Function updates DB | T+22min | Post badge silently changes to live |
| **User felt wait** | **< 1 second** | "My post is pending" then it goes live |

### Compared to Current System

| | Current | Server-Side |
|--|---------|-------------|
| User waits | 18–30 min staring at spinner | < 1 second (sees post immediately) |
| App must stay open | Yes | No |
| Server handles LLM | No | Yes |
| Scales with users | Poorly | Well |

> **The user experience is essentially identical to the Keyframe method** in terms of felt speed — both show the post immediately. The difference is WHERE the AI runs (phone vs server) and WHAT gets analyzed (3 tiny frames vs the full video).

---

## 5. Advantages

### ✅ App Does Not Need to Stay Open
The biggest advantage. The user can:
- Close the app immediately after posting
- Lock their phone
- Have poor signal
- Switch to another app

The server will process the video and approve it regardless. When the user reopens the app, their post is live.

### ✅ Full Video Analysis — 100% Accuracy
Unlike the keyframe method (which sends 3 frames), the server sends the **full video** to the LLM. This means:
- No hidden scenes slip through
- Motion artifacts are fully analyzed
- Audio can be extracted and analyzed server-side
- Same detection quality as the current system, but without blocking the user

### ✅ No Phone CPU/GPU Used for Processing
The phone only uploads the file. It doesn't extract keyframes, compress, or run any local media processing. This is better for:
- Battery life
- Low-end devices
- Older iPhones and budget Android phones

### ✅ Centralized Control
All moderation logic lives in one place — the Edge Function. To change thresholds, add new rules, or update the LLM model:
- Update one server-side function
- No app update required
- No waiting for App Store / Play Store review
- Takes effect for all users instantly

### ✅ Retries Are Reliable
If the LLM call fails on the server, the Edge Function can retry automatically with exponential backoff. On a phone, a failed LLM call is gone forever (no retry infrastructure exists in the current app).

### ✅ Works Across Platforms
The same Edge Function handles moderation for:
- iOS app
- Android app
- Any future web app
- Any future third-party integrations

One server, all clients.

### ✅ Easier Audit Trail
All AI detection requests, responses, timings, errors, and retries are logged server-side. You get a complete audit trail for every moderation decision without relying on client-side logs.

### ✅ Cost Visibility
LLM API costs are tracked server-side. You can see exactly how much each post costs to moderate, set per-user or per-day limits, and cut off bad actors who spam uploads to drain your LLM budget.

---

## 6. Disadvantages & Risks

### ❌ Post Approval Is Slower for Videos (Invisible to User, But Real)
Because the full 400MB video is analyzed, LLM processing still takes 10–20 minutes. The user doesn't wait — but the post doesn't actually go fully live until after that. If someone opens the app 5 minutes after posting, they'll still see "Pending Review."

**Mitigation:** See Section 7.

### ❌ Supabase Edge Function Has a 150-Second Timeout
Supabase Edge Functions (Deno runtime) have a hard execution limit of **150 seconds (2.5 minutes)**. A 400MB video takes 10–20 minutes to process. The Edge Function would time out before the LLM responds.

**Mitigation:** See Section 7 — this is solvable with a polling/callback pattern.

### ❌ Cold Start Latency
Edge Functions have a "cold start" delay of ~200–500ms on first invocation. Not a user-facing problem, but adds slight processing delay.

### ❌ The LLM Endpoint Requires File Upload, Not a URL
The `detectorllm.rooverse.app/api/v1/detect/full` endpoint requires a **multipart file upload** — it does not accept a Supabase storage URL. The Edge Function would need to:
1. Download the file from Supabase Storage server-side
2. Upload it to the LLM API

For a 400MB file, this means the server downloads 400MB and uploads 400MB. This uses Supabase bandwidth and takes time.

**Mitigation:** Use keyframes server-side too (best of both worlds — see Section 12).

### ❌ More Infrastructure to Build and Maintain
Requires:
- Writing and deploying a new Supabase Edge Function
- Setting up job queuing (using the existing `background_jobs` table)
- Handling Edge Function timeouts
- Monitoring server-side failures

More moving parts = more things that can break.

### ❌ App-to-Server Notification Can Fail
If the app's notification call to the Edge Function fails (bad network at that exact moment), the post sits in `under_review` forever with no detection triggered.

**Mitigation:** See Section 7.

---

## 7. Solving the Disadvantages

---

### Problem 1: Edge Function 150-Second Timeout

**Solution: Job Queue Pattern**

Instead of the Edge Function running the LLM call directly, it **enqueues a job** and returns immediately. A separate worker processes the queue.

```
App → Edge Function (fast, < 1s)
         ↓
  Inserts row into background_jobs table
  (job_type: 'ai_detection', status: 'queued', payload: {postId, storagePath})
         ↓
  Returns 200 OK immediately (no timeout risk)

Background Worker (runs separately, no timeout):
  Polls background_jobs for 'queued' jobs
  Picks up job → calls LLM (takes as long as needed)
  Updates post → marks job 'completed'
```

The `background_jobs` table **already exists** in your Supabase schema with all the fields needed:
- `job_type`, `status` (queued/processing/completed/failed)
- `payload` (jsonb — store postId, storagePath, authorId)
- `max_attempts`, `attempt_count` (built-in retry support)
- `error_message`, `locked_by`, `locked_at` (worker locking)

The worker can be:
- Another Supabase Edge Function triggered by a pg_cron schedule (every 30 seconds)
- An external worker (Railway, Render, Fly.io) that polls the table
- A Supabase Database Function triggered via pg_cron

---

### Problem 2: File Download + Re-upload Bandwidth Cost

**Solution: Extract Keyframes Server-Side**

Instead of the server downloading 400MB and uploading 400MB to the LLM, the server:
1. Downloads a **short 3-second video clip** (or requests a thumbnail from Supabase)
2. Sends that small clip to the LLM

OR — even simpler — use Supabase's Storage Image Transformation API to generate a thumbnail server-side:

```
Supabase Storage URL for thumbnail:
https://[project].supabase.co/storage/v1/render/image/public/post-media/[path]?width=1280&height=720

→ Returns a JPEG thumbnail of the video's first frame, server-side, no download required
→ Send this URL directly... wait, LLM requires file upload, so:
→ HTTP GET the thumbnail (~80KB) → upload to LLM
→ Total bandwidth: 80KB instead of 400MB
```

This is the **server-side equivalent of keyframe extraction** — tiny bandwidth, fast, accurate enough.

---

### Problem 3: App Notification Failure

**Solution: Dual Trigger**

Don't rely on the app to trigger detection. Use two independent triggers:

**Trigger 1 (Primary):** App calls Edge Function after upload ← fast, immediate

**Trigger 2 (Safety net):** A scheduled pg_cron job runs every 5 minutes and checks for posts where:
- `status = 'under_review'`
- `ai_score IS NULL` (never been analyzed)
- `created_at < NOW() - INTERVAL '5 minutes'` (been waiting too long)

```sql
-- pg_cron job (runs every 5 minutes):
SELECT id FROM posts
WHERE status = 'under_review'
  AND ai_score IS NULL
  AND created_at < NOW() - INTERVAL '5 minutes';
-- Any results → insert into background_jobs as 'queued'
```

If the app's notification fails, the cron job catches it within 5 minutes. No post is ever stuck forever.

---

### Problem 4: Post Still Shows "Pending" for 10–20 Minutes

**Solution: Server-Side Keyframes for Fast Pass, Full Video for Deep Check**

Run two jobs:

```
Job 1 (fast, < 30 seconds):
  Server extracts thumbnail → sends to LLM → if passes: publish immediately
  This runs first, gets the post live fast

Job 2 (slow, background, no user impact):
  Server downloads full video → sends to LLM → secondary check
  If this later flags the post: update status, notify user
```

User sees post go live within 30 seconds (from Job 1). Job 2 provides safety net in background. Same two-pass approach as described in the Keyframe document, but running on the server instead of the phone.

---

## 8. Existing Infrastructure You Can Use

Your codebase already has most of what's needed. Nothing needs to be built from scratch.

| Component | Status | Location |
|-----------|--------|----------|
| **Edge Function framework** | ✅ Exists | `supabase/functions/didit/index.ts` (proven pattern) |
| **Webhook signature verification** | ✅ Exists | `supabase/functions/didit/index.ts` (HMAC-SHA256) |
| **Background jobs table** | ✅ Exists | `supabase_schema2.sql` lines 101–118 |
| **Realtime subscriptions** | ✅ Exists | Used in feed_provider.dart (Postgres Changes) |
| **Push notification dispatch** | ✅ Exists | `supabase/functions/notify-social/index.ts` |
| **Post status update logic** | ✅ Exists | `post_repository.dart` lines 1933–1979 |
| **AI scoring thresholds** | ✅ Exists | `post_repository.dart` (just needs to move server-side) |
| **LLM API calls** | ✅ Exists | `ai_detection_service.dart` (needs Deno port) |

**What needs to be built:**
- New Edge Function: `supabase/functions/post-ai-analysis/index.ts`
- pg_cron job for the safety-net trigger
- Worker script for processing `background_jobs` queue (if not using pg_cron)

---

## 9. Implementation Plan

### Phase 1 — Optimistic UI (Zero Risk, Do First)
Same as Keyframe approach. Show post as "Pending Review" immediately. No moderation logic changes.

**Files:** `lib/widgets/post_card.dart`, `lib/providers/feed_provider.dart`

### Phase 2 — Create the Edge Function

Create `supabase/functions/post-ai-analysis/index.ts`:

```typescript
import { serve } from "https://deno.land/std/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js"

serve(async (req) => {
  const { postId, authorId, storagePath } = await req.json()

  // 1. Insert job into background_jobs
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  await supabase.from('background_jobs').insert({
    job_type: 'ai_detection',
    status: 'queued',
    priority: 'normal',
    payload: { postId, authorId, storagePath },
    max_attempts: 3,
  })

  // Return immediately — don't wait for LLM
  return new Response(JSON.stringify({ queued: true }), {
    headers: { 'Content-Type': 'application/json' }
  })
})
```

### Phase 3 — Create the Worker

Create `supabase/functions/process-ai-jobs/index.ts` (triggered by pg_cron every 30 seconds):

```typescript
serve(async (_req) => {
  const supabase = createClient(...)

  // Pick up next queued job (with locking to prevent double-processing)
  const { data: job } = await supabase
    .from('background_jobs')
    .update({ status: 'processing', locked_by: 'worker-1', locked_at: new Date() })
    .eq('status', 'queued')
    .eq('job_type', 'ai_detection')
    .order('created_at', { ascending: true })
    .limit(1)
    .select()
    .single()

  if (!job) return new Response('No jobs', { status: 200 })

  const { postId, storagePath } = job.payload

  try {
    // Get thumbnail from storage (tiny file, fast)
    const { data: fileData } = await supabase.storage
      .from('post-media')
      .download(storagePath)

    // Call LLM
    const formData = new FormData()
    formData.append('file', fileData, 'media')
    formData.append('models', 'gpt-4.1')

    const llmResponse = await fetch(
      'https://detectorllm.rooverse.app/api/v1/detect/full',
      { method: 'POST', body: formData }
    )
    const result = await llmResponse.json()

    // Apply scoring logic
    const newStatus = determinePostStatus(result)
    const aiScore = result.confidence

    // Update post in DB
    await supabase.from('posts').update({
      status: newStatus,
      ai_score: aiScore,
      ai_score_status: determineScoreStatus(result),
      ai_metadata: result,
    }).eq('id', postId)

    // Mark job complete
    await supabase.from('background_jobs').update({
      status: 'completed',
      finished_at: new Date(),
    }).eq('id', job.id)

  } catch (error) {
    // Increment attempt count, retry later
    await supabase.from('background_jobs').update({
      status: job.attempt_count + 1 >= job.max_attempts ? 'failed' : 'queued',
      attempt_count: job.attempt_count + 1,
      error_message: error.message,
      locked_by: null,
    }).eq('id', job.id)
  }
})
```

### Phase 4 — Modify the App

In `lib/repositories/post_repository.dart`, replace the direct LLM call with a server notification:

```dart
// OLD (app calls LLM directly):
unawaited(_aiDetectionService.detectFull(file: mediaFile, ...));

// NEW (app notifies server, server does the work):
unawaited(_supabase.functions.invoke('post-ai-analysis', body: {
  'postId': postId,
  'authorId': authorId,
  'storagePath': storagePath,
}));
```

That's the only app-side change needed. One function call replaces the entire LLM pipeline.

### Phase 5 — pg_cron Safety Net

```sql
-- Runs every 5 minutes, catches any posts that missed the app notification
SELECT cron.schedule(
  'catch-pending-posts',
  '*/5 * * * *',
  $$
  INSERT INTO background_jobs (job_type, status, payload, max_attempts)
  SELECT 'ai_detection', 'queued',
    jsonb_build_object('postId', id, 'authorId', author_id),
    3
  FROM posts
  WHERE status = 'under_review'
    AND ai_score IS NULL
    AND created_at < NOW() - INTERVAL '5 minutes'
    AND NOT EXISTS (
      SELECT 1 FROM background_jobs
      WHERE job_type = 'ai_detection'
        AND payload->>'postId' = posts.id::text
        AND status != 'failed'
    );
  $$
);
```

---

## 10. Code Reference — What to Build

| File | Action | Notes |
|------|--------|-------|
| `supabase/functions/post-ai-analysis/index.ts` | **Create new** | Receives app notification, enqueues job |
| `supabase/functions/process-ai-jobs/index.ts` | **Create new** | Worker: dequeues jobs, calls LLM, updates DB |
| `lib/repositories/post_repository.dart` line ~1685 | **Modify** | Replace `unawaited(_aiDetectionService...)` with `supabase.functions.invoke(...)` |
| `lib/widgets/post_card.dart` | **Modify** | Add "Pending Review" badge for `under_review` posts |
| `lib/providers/feed_provider.dart` lines 83–98 | **Modify** | Show author's own `under_review` posts |
| `supabase_schema2.sql` | **Reference only** | `background_jobs` table already exists |

**Existing files to reference (pattern/reuse):**
- `supabase/functions/didit/index.ts` — webhook handler pattern, signature verification
- `supabase/functions/notify-social/index.ts` — DB update → push notification pattern
- `lib/services/ai_detection_service.dart` — scoring logic to port to Deno/TypeScript

---

## 11. Comparison: Keyframe vs Server-Side

| Factor | Keyframe Method | Server-Side Method |
|--------|----------------|-------------------|
| **User felt wait** | ~5–10 seconds | < 1 second |
| **Full video analyzed** | No (3 frames) | Yes (full file) |
| **Accuracy** | ~95% | ~99% |
| **App must stay open** | Until keyframes sent (~10s) | No — app can close after upload |
| **Phone CPU/battery used** | Yes (frame extraction) | No |
| **New infrastructure needed** | Minimal | Edge Functions + worker |
| **LLM cost per video** | Lower (small files) | Higher (full files) |
| **Implementation complexity** | Low | Medium |
| **Audio detection possible** | With extra work | Yes (server has full file) |
| **Moderation coverage** | ~95% | ~99% |
| **Edge Function timeout risk** | None (app-side) | Yes (requires job queue) |

---

## 12. Recommended Hybrid Approach

The best real-world solution combines both methods:

```
FAST PATH (Phone-side, Keyframe):
  App extracts 3 keyframes → sends to LLM → result in 5–10 seconds
  → If flagged: block post immediately (don't even upload full video)
  → If passed: publish post immediately, user sees it live

DEEP PATH (Server-side, Full Video):
  Server queues full-video job → worker calls LLM with full file
  → If flagged: update post to 'under_review', notify user
  → If passed: no action needed (already live)
```

**Why this is best:**

- User sees post live in **5–10 seconds** (keyframe pass)
- **99% accuracy** (full video backup catches anything missed)
- **App can close** after the keyframe check (10 seconds) — full video runs server-side
- **No false positives** slow down good content
- **No hidden content** survives (two-pass catches it)
- **Phone does minimal work** — just 3 frame extractions
- **Server does heavy lifting** on the full video — without the user waiting

This hybrid eliminates the weaknesses of both approaches individually.

---

