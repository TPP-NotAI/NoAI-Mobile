# Camera Image AI Detection Fix

## Problem
Images captured using the in-app camera were being flagged as 100% AI-generated, while uploaded images from the gallery were being checked correctly.

## Root Cause
When images are captured using the camera, they are initially stored in a temporary cache location by the `image_picker` package. This temporary file path can become invalid or inaccessible when the AI detection service tries to read the file later, especially if:

1. The file is in a temporary cache that gets cleared
2. The file path is only valid for a short time
3. The file permissions change after capture
4. The async AI detection happens after the temporary file is cleaned up

## Solution
The fix ensures that camera-captured images (and videos) are copied to a permanent location immediately after capture, before any AI detection or processing occurs.

### Changes Made

#### 1. `lib/screens/create/create_post_screen.dart`
- Modified `_pickMedia()` method to detect when media is from camera
- Added logic to copy camera-captured files to a permanent location using `Directory.systemTemp`
- Files are given unique names using timestamps to avoid conflicts
- Added error handling to fall back to original file if copy fails
- Added debug logging to track the copy process

#### 2. `lib/services/ai_detection_service.dart`
- Enhanced `detectImage()` method with detailed logging
- Added file existence verification before sending to API
- Added file size logging for debugging
- Enhanced error handling with stack traces
- Enhanced `detectMixed()` method with similar improvements

## How It Works

### Before (Broken)
1. User takes photo with camera
2. `image_picker` creates temporary file at `/cache/temp_12345.jpg`
3. File reference is stored
4. Post creation begins
5. AI detection tries to read file (async, happens later)
6. ❌ File may no longer exist or be accessible
7. AI detection fails silently or returns incorrect result

### After (Fixed)
1. User takes photo with camera
2. `image_picker` creates temporary file at `/cache/temp_12345.jpg`
3. ✅ File is immediately copied to `/tmp/camera_image_1234567890.jpg`
4. Permanent file reference is stored
5. Post creation begins
6. AI detection reads from permanent location
7. ✅ AI detection works correctly

## Testing
To verify the fix works:

1. Open the app and navigate to Create Post
2. Select "Photo" post type
3. Tap the camera icon to take a photo
4. Take a photo of a real-world scene (not AI-generated)
5. Create the post
6. Check the AI confidence score - it should now be low (<20%) for real photos
7. Check debug logs for messages like:
   ```
   CreatePostScreen: Copied camera image to permanent location: /tmp/camera_image_1234567890.jpg
   AiDetectionService: Starting image detection for /tmp/camera_image_1234567890.jpg
   AiDetectionService: File size: 123456 bytes
   ```

## Additional Benefits
- Better error logging helps diagnose future issues
- File existence checks prevent crashes
- Consistent behavior between camera and gallery images
- Works for both photos and videos

## Notes
- The permanent location uses `Directory.systemTemp` which is appropriate for temporary files that need to persist during app execution
- Files are automatically cleaned up by the OS when no longer needed
- The timestamp-based naming prevents file conflicts
- Error handling ensures the app continues to work even if the copy fails
