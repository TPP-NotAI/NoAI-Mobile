# Alternative Moderation Strategies
### NoAI.org — Beyond Keyframes & Server-Side Processing

**Document Purpose:** Three additional architecturally distinct approaches for AI moderation latency, each solving the problem from a completely different angle. None of these overlap with the Keyframe Method or Server-Side Method already documented.

---

## The Three Alternatives

| # | Method | Core Idea | Best For |
|---|--------|-----------|----------|
| 1 | **Hash-Based Pre-Screening** | Check a fingerprint of the media before sending to LLM | Repeat content, known AI generators |
| 2 | **On-Device ML (Client-Side AI)** | Run a small AI model on the phone itself, no server needed | Instant decisions, offline capability |
| 3 | **Progressive Upload + Streaming Analysis** | Analyze the video while it's still uploading, in parallel | Large files, fastest full-video accuracy |

---

---

# Method 1: Hash-Based Pre-Screening

## Core Concept

Before sending any media to the LLM (which takes seconds to minutes), generate a **fingerprint (hash)** of the file on the device and look it up in a database. If the fingerprint is already known — either as a known AI-generated video or a previously approved human video — you get the answer **instantly**, with zero LLM cost.

```
User selects video
      ↓
Generate perceptual hash of video (~0.5 seconds on device)
      ↓
Query hash database: "Have we seen this before?"
      ↓
Match found (known AI) → block immediately, 0 seconds
Match found (known human) → approve immediately, 0 seconds
No match → fall back to LLM (keyframe or full video)
      ↓
Store result in hash DB for next time
```

---

## What Is a Perceptual Hash?

A **perceptual hash** (pHash) is a compact fingerprint of an image or video that captures its visual "essence." Unlike a cryptographic hash (MD5/SHA256) which changes completely if even one pixel changes, a perceptual hash is designed so that:

- **Similar-looking content → similar hash**
- **Exact duplicate → identical hash**
- **Minor edits (resize, recolor, re-encode) → still very similar hash**

```
Original AI-generated video:    pHash = a3f2b1c4d5e6...
Same video, re-encoded to MP4:  pHash = a3f2b1c4d5e7...  ← 1 bit different = MATCH
Same video, brightness adjusted: pHash = a3f2b1c5d5e6... ← 2 bits different = MATCH

Completely different video:     pHash = 7c9a2d4f1e3b... ← many bits different = NO MATCH
```

You compare hashes using **Hamming distance** — the number of differing bits. If distance < threshold (e.g., 8 bits), it's a match.

---

## How It Works in the App

### Step 1 — Generate Hash on Device

```dart
// Using the 'image' package (already in pubspec.yaml: image: ^3.3.0)
// For video: extract 1 frame, hash that frame

import 'package:image/image.dart' as img;
import 'package:video_thumbnail/video_thumbnail.dart'; // already installed

Future<String> generateVideoHash(File videoFile) async {
  // Extract middle frame
  final thumbnailBytes = await VideoThumbnail.thumbnailData(
    video: videoFile.path,
    imageFormat: ImageFormat.JPEG,
    maxWidth: 32,  // Very small — 32x32 pixels is enough for pHash
    maxHeight: 32,
    quality: 50,
  );

  // Decode and compute DCT-based perceptual hash
  final image = img.decodeImage(thumbnailBytes!);
  final resized = img.copyResize(image!, width: 8, height: 8);

  // Convert to grayscale, compute average, generate 64-bit hash
  // Returns 64-character hex string like "a3f2b1c4d5e6f7a8"
  return _computePHash(resized);
}
```

**Speed:** < 500ms on any device. The hash is tiny (64 bits = 16 hex characters).

---

### Step 2 — Query Hash Database

```dart
// Query Supabase for this hash (or similar hashes)
final result = await _supabase
    .from('media_hashes')
    .select('ai_result, confidence, created_at')
    .filter('hash_distance', 'lte', 8)  // Within 8 bits = match
    .eq('phash', videoHash)
    .maybeSingle();

if (result != null) {
  // Known content — instant decision
  return result['ai_result']; // 'human' or 'ai_generated'
}

// Not seen before — fall back to LLM
return await runLlmDetection(videoFile);
```

---

### Step 3 — Store Result After LLM Runs

Every time the LLM analyzes a new video, store its hash:

```dart
await _supabase.from('media_hashes').insert({
  'phash': videoHash,
  'ai_result': llmResult.result,
  'confidence': llmResult.confidence,
  'source': 'llm_analysis',
  'created_at': DateTime.now().toIso8601String(),
});
```

Over time, the hash database grows. More matches = fewer LLM calls. The system gets faster as it learns.

---

## Database Table Needed

```sql
CREATE TABLE public.media_hashes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  phash text NOT NULL,           -- 64-bit hash as hex string
  ai_result text NOT NULL,       -- 'human' | 'ai_generated' | 'flagged'
  confidence numeric,            -- 0-100
  source text,                   -- 'llm_analysis' | 'manual_review' | 'known_db'
  created_at timestamptz DEFAULT now(),
  hit_count integer DEFAULT 0    -- How many times this hash was matched
);

-- Index for fast lookup
CREATE INDEX idx_media_hashes_phash ON media_hashes(phash);
```

---

## Advantages

| Advantage | Detail |
|-----------|--------|
| **Zero LLM cost on repeat content** | If 100 users upload the same AI-generated video, LLM runs once. All 99 after that are instant. |
| **Instant decision** | Hash lookup is a DB query — returns in < 50ms |
| **Works offline** | Hash generation happens on device, no network needed |
| **Catches re-uploads of known bad content** | Even if the user re-encodes or resizes the video, the perceptual hash still matches |
| **Builds over time** | Hash DB grows with every new piece of content. Gets smarter automatically. |
| **Pairs with any other method** | Works as a pre-filter before keyframes, full video, or server-side analysis |
| **Industry proven** | PhotoDNA (Microsoft), YouTube Content ID, and Facebook's PDQ all use this approach |

---

## Disadvantages

| Disadvantage | Mitigation |
|-------------|-----------|
| **Only catches known content** | New, never-seen AI videos still need LLM. Use as pre-filter, not replacement. |
| **Hash collisions possible** | Very rare at 64-bit pHash. Keep threshold at 8 bits max to minimize false positives. |
| **Can be gamed** | Adversary adds a small watermark to change hash. Mitigation: use multiple hash algorithms (pHash + dHash + aHash). |
| **Cold start problem** | Hash DB is empty on day one — all videos go to LLM until DB builds up. Expected. |
| **Video hash vs image hash** | Video perceptual hashing is more complex than image hashing. Use single keyframe hash as proxy (works for most cases). |

---

## Timing Estimate for 400MB Video

| Scenario | Time |
|----------|------|
| Hash match found (repeat content) | **< 100ms** — instant |
| No match — falls back to keyframe method | ~5–10 seconds |
| No match — falls back to full video | ~20 minutes |

**After 1 month of usage** (assuming hash DB has built up): Estimated 30–60% of uploads will be hash matches (social platforms see high duplication rates), meaning 30–60% of videos are approved instantly with zero LLM cost.

---

---

# Method 2: On-Device ML (Client-Side AI)

## Core Concept

Instead of sending media to a server at all, run a **small, fast AI model directly on the user's phone**. The model makes the moderation decision locally, in under 2 seconds, with no network required.

```
User selects video
      ↓
Extract 3 keyframes (already on device)
      ↓
Run on-device ML model (TFLite / ONNX)
      ↓
Model returns: probability this is AI-generated (0–100%)
      ↓
If < 40%: approve immediately, post published
If 40–80%: send to server LLM for second opinion
If > 80%: block immediately, no LLM needed
      ↓
No network call for the easy cases (most content)
```

---

## What Is On-Device ML?

A normal AI model (like GPT-4) runs on massive server clusters. But **small, specialized models** can be compressed to run on a phone's processor:

- **TensorFlow Lite (TFLite):** Google's framework for mobile ML. Models are typically 1–20MB.
- **ONNX Runtime Mobile:** Cross-platform format, works on iOS and Android.
- **Core ML (iOS only):** Apple's optimized framework, uses Neural Engine chip.

For AI-generated image/video detection specifically, models like **MobileNet** or custom CNNs can be trained and compressed to ~5MB and still achieve 85–92% accuracy — running in under 500ms on a mid-range phone.

---

## How It Works in the App

### Step 1 — Bundle a TFLite Model

Add a small detection model to the app's assets:

```yaml
# pubspec.yaml additions
dependencies:
  tflite_flutter: ^0.10.4   # TFLite inference engine

flutter:
  assets:
    - assets/models/ai_detector.tflite  # ~5MB model file
```

The model is downloaded once with the app and lives on the device permanently. No network needed to run it.

---

### Step 2 — Run Inference on Keyframes

```dart
import 'package:tflite_flutter/tflite_flutter.dart';

class OnDeviceAiDetector {
  late Interpreter _interpreter;

  Future<void> initialize() async {
    _interpreter = await Interpreter.fromAsset(
      'assets/models/ai_detector.tflite'
    );
  }

  Future<double> detectAiProbability(File imageFile) async {
    // Preprocess: resize to 224x224, normalize to [0,1]
    final inputTensor = await _preprocessImage(imageFile);

    // Run inference
    final output = List.filled(1, 0.0).reshape([1, 1]);
    _interpreter.run(inputTensor, output);

    // Returns probability 0.0 (human) to 1.0 (AI-generated)
    return output[0][0] as double;
  }
}
```

**Speed on device:**
- High-end phone (iPhone 15, Pixel 8): **~50–150ms per frame**
- Mid-range Android: **~200–500ms per frame**
- 3 frames: **~150ms–1.5 seconds total**

---

### Step 3 — Decision Logic

```dart
Future<ModerationDecision> runOnDeviceCheck(File videoFile) async {
  final keyframes = await extractKeyframes(videoFile); // 3 frames

  double maxAiScore = 0.0;
  for (final frame in keyframes) {
    final score = await _onDeviceDetector.detectAiProbability(frame);
    maxAiScore = max(maxAiScore, score);
  }

  if (maxAiScore < 0.40) {
    // Confident it's human — approve immediately, no server call
    return ModerationDecision.approve();
  } else if (maxAiScore > 0.80) {
    // Confident it's AI — block immediately, no server call
    return ModerationDecision.block(confidence: maxAiScore);
  } else {
    // Uncertain — send to server LLM for second opinion
    return ModerationDecision.escalate(onDeviceScore: maxAiScore);
  }
}
```

**Result:** Only the "uncertain" 40–80% range needs to go to the server LLM. The confident cases (which may be 70–80% of all content) are handled entirely on-device.

---

## Model Training

You would need to train or fine-tune a model specifically for AI-generated video detection:

| Option | Effort | Accuracy | Cost |
|--------|--------|----------|------|
| **Use pre-trained open source model** (e.g., CNNDetect, UniversalFakeDetect) | Low | 85–90% | Free |
| **Fine-tune on your own data** (posts flagged by your LLM) | Medium | 90–95% | GPU compute cost |
| **Train from scratch** | High | 92–97% | High compute cost |

**Recommended start:** Use an existing open-source detector (CNNDetect is available on GitHub), convert it to TFLite using TensorFlow's conversion tools, and ship it. Fine-tune later with your own labeled data.

---

## Advantages

| Advantage | Detail |
|-----------|--------|
| **Works completely offline** | No network needed for the on-device decision |
| **Truly instant for clear cases** | 150ms–1.5 seconds, no server round-trip |
| **Zero LLM API cost for easy cases** | 70–80% of content never touches the LLM |
| **Privacy-preserving** | Video never leaves the device for the decision |
| **Scales infinitely** | 1 million users = no extra server cost for on-device checks |
| **Reduces LLM server load** | Only genuinely ambiguous content reaches the LLM |
| **Works in poor network conditions** | User on 2G or offline can still have their post screened |

---

## Disadvantages

| Disadvantage | Mitigation |
|-------------|-----------|
| **Lower accuracy than LLM** (~85–92% vs ~99%) | Use as first pass only; escalate uncertain cases to LLM |
| **Model can be extracted and studied by adversaries** | Obfuscate model, use multiple models, keep LLM as final authority |
| **App size increases** | 5–10MB model file added to app download. Accept the tradeoff or offer as optional download. |
| **Model gets outdated** | New AI generators emerge. Need periodic model updates via OTA asset delivery (Firebase Remote Config + ML Kit). |
| **Device capability varies** | Very old devices may be too slow. Set minimum spec or fall back to server on older hardware. |
| **Requires ML expertise to set up** | One-time effort. Once pipeline is built, updates are straightforward. |

---

## Timing Estimate for 400MB Video

| Phase | Time |
|-------|------|
| Extract 3 keyframes | ~1–2 seconds |
| Run on-device ML on 3 frames | ~0.5–1.5 seconds |
| Decision: approve / block (confident cases) | **Total: ~2–4 seconds, zero network** |
| Decision: escalate (uncertain cases) → LLM | +5–10 seconds (keyframe to LLM) |

**For 70–80% of posts: decision in under 4 seconds with no server call at all.**

---

---

# Method 3: Progressive Upload + Streaming Analysis

## Core Concept

Instead of uploading the entire file first and then analyzing it, start analyzing the video **while it is still uploading**. The first chunk of the video arrives at the server, the LLM begins processing it, and by the time the last chunk arrives, analysis may already be partially or fully complete.

```
CURRENT (Sequential):
[====Upload====][====LLM Analysis====]
Total: 13 + 15 = 28 minutes

PROGRESSIVE (Parallel):
[====Upload====]
        [==========LLM Analysis==========]
                (starts when first chunk arrives)
Total: max(13, 18) = 18 minutes

But with smart analysis:
[====Upload====]
[LLM on chunk1][LLM on chunk2][LLM on chunk3]...
                                              ↓
                                  Early decision at 30% of upload
Total: 4–5 minutes (decision made before full upload completes)
```

---

## How It Works

### Current Chunked Upload (Existing Code)

Your `ai_detection_service.dart` already has a 3-step chunked upload:

```
1. POST /upload/init    → get upload_id
2. POST /upload/chunk   → send 20MB chunks (× N)
3. POST /upload/complete → trigger analysis
```

Currently, analysis only starts at step 3 — **after all chunks are uploaded**. This is purely sequential.

### Progressive Analysis (What Changes)

Modify the server (`detectorllm.rooverse.app`) to begin analyzing each chunk as it arrives, building a running confidence score:

```
Chunk 1 arrives (first 20MB = first ~30 seconds of a 5-min video)
  → Server extracts frames from chunk 1
  → Runs AI detection on those frames
  → Confidence after chunk 1: 87% AI-generated
  → If > threshold (e.g., 90%): early decision — stop upload, block post

Chunk 2 arrives (next 20MB)
  → Server refines confidence
  → Confidence after chunk 2: 91%
  → Early decision triggered → block post, notify app to cancel remaining upload

App receives early decision signal → stops upload
Post marked as flagged
User notified
```

**Key point:** If the LLM is highly confident after the first 2–3 chunks, the remaining 17 chunks never need to be uploaded. For clearly AI-generated or clearly clean content, the decision comes in **as soon as enough data has been received** — not after the entire file.

---

## What This Requires

### Server-Side Change (detectorllm.rooverse.app)

The LLM endpoint needs a new capability: **streaming chunk analysis** with early-exit signaling.

New endpoint behavior:
```
POST /upload/chunk  → server analyzes the chunk immediately
                    → returns running confidence score in response
                    → if confidence > 90%: response includes early_decision flag

Response body example:
{
  "upload_id": "abc123",
  "chunk_index": 2,
  "running_confidence": 0.91,
  "early_decision": true,     ← App sees this and stops uploading
  "result": "AI-GENERATED",
  "rationale": "Strong DCT artifacts visible in frames 1-3"
}
```

### App-Side Change

Modify the chunked upload loop in `lib/services/ai_detection_service.dart` to check each chunk response:

```dart
// In _uploadChunked() method (currently lines 332-372):
for (int i = 0; i < totalChunks; i++) {
  final start = i * _chunkSizeBytes;
  final end = min(start + _chunkSizeBytes, fileBytes.length);
  final chunk = fileBytes.sublist(start, end);

  final chunkResponse = await _sendChunk(uploadId, i, chunk);

  // NEW: Check for early decision
  if (chunkResponse['early_decision'] == true) {
    // Server already has enough data to decide
    // Cancel remaining upload, return early result
    return AiDetectionResult.fromJson(chunkResponse);
  }
}
// If no early decision, complete as normal
return await _completeUpload(uploadId, models, content);
```

---

## Advantages

| Advantage | Detail |
|-----------|--------|
| **Full video analyzed, not just frames** | Unlike keyframe method, every frame of the video is eventually seen (if upload completes) |
| **Early exit saves bandwidth** | Clearly AI videos stop uploading after 1–2 chunks. 400MB video might only upload 40MB before being blocked. |
| **No change to app architecture** | Chunked upload already exists. Only adds early-exit logic. |
| **Fastest path for bad content** | AI-generated videos are detected and blocked faster than any other method |
| **Natural for long videos** | The longer the video, the more benefit from progressive analysis |
| **No new packages needed** | All logic in existing `ai_detection_service.dart` |

---

## Disadvantages

| Disadvantage | Mitigation |
|-------------|-----------|
| **Requires server-side changes to detectorllm.rooverse.app** | Need to add streaming analysis capability to the LLM backend |
| **Doesn't help for clean content** | If video is human-generated, all chunks must upload before a positive decision. No speed benefit for approved posts. | Combine with keyframe pre-screening for the clean-content fast path. |
| **Still slower than keyframe for the common case** | Most posts are approved (not flagged). Those still wait for full upload. | Use progressive analysis for flagging bad content fast, keyframes for approving good content fast. |
| **Complex server implementation** | Streaming inference pipeline is non-trivial to build | Worth the investment at scale |
| **Upload can't be reliably cancelled mid-way** | HTTP chunked uploads can be stopped but the server needs to handle incomplete uploads gracefully | Already handled by `upload/init` session management |

---

## Timing Estimate for 400MB Video

| Content Type | Time to Decision |
|-------------|-----------------|
| Clearly AI-generated (confidence >90% early) | **~1–2 minutes** (early exit after 2–3 chunks) |
| Ambiguous (needs full video) | ~20 minutes (same as current) |
| Clearly human (all chunks needed) | ~20 minutes upload + ~2 min analysis |

**For bad content (the most important case to catch fast): 10× faster than current.** For good content, use keyframes in parallel to approve immediately.

---

---

# Comparison of All 5 Methods

| Method | Speed (Good Content) | Speed (Bad Content) | Accuracy | Infrastructure Needed | Complexity |
|--------|---------------------|---------------------|----------|----------------------|------------|
| **Current (broken)** | 18–30 min | 18–30 min | ~99% | Nothing new | None |
| **Keyframe** | 5–10 sec | 5–10 sec | ~95% | `video_thumbnail` (already installed) | Low |
| **Server-Side** | <1 sec felt | <1 sec felt | ~99% | Edge Function + worker | Medium |
| **Hash-Based** | <100ms (if known) | <100ms (if known) | 100% for known content | `media_hashes` table + pHash logic | Low |
| **On-Device ML** | 2–4 sec (no network) | 2–4 sec | ~88–92% | TFLite model file (~5MB) | Medium |
| **Progressive Upload** | 18–20 min (no change) | 1–2 min (early exit) | ~99% | LLM backend change | High |

---

# The Optimal Stack: All Methods Combined

No single method is perfect. The best real-world system layers all of them:

```
User posts video
      ↓
Layer 1 — Hash Check (< 100ms)
  Known content? → Instant decision (approve or block)
  Unknown? → Continue
      ↓
Layer 2 — On-Device ML (< 4 seconds, no network)
  Confident human (< 40%)? → Approve instantly
  Confident AI (> 80%)? → Block instantly
  Uncertain (40–80%)? → Continue
      ↓
Layer 3 — Keyframe to LLM (< 10 seconds)
  3 frames to server LLM → fast second opinion
  Clear pass? → Approve. User sees post live.
  Clear fail? → Block. User notified.
  Still uncertain? → Continue
      ↓
Layer 4 — Progressive Full Upload (background)
  Full video uploads while user is on feed
  LLM analyzes each chunk as it arrives
  Early exit if clearly AI (saves bandwidth)
  Final authoritative decision
      ↓
Layer 5 — Human Review Queue
  Posts that passed all automated checks but are edge cases
  Manual moderation team reviews flagged content
  Feedback fed back into on-device model training
```

**What this stack delivers:**

- **< 100ms** for repeat/known content (Layer 1)
- **< 4 seconds** for clearly human or clearly AI content (Layer 2)
- **< 10 seconds** for most new content (Layer 3)
- **Full accuracy** for edge cases (Layers 4 + 5)
- **Zero false positives** — human content is never blocked without human review confirmation
- **Gets smarter over time** — Hash DB grows, on-device model improves with feedback

---

*Document prepared for NoAI.org engineering team — March 2026*
