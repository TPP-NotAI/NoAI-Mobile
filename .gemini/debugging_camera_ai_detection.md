# Debugging Camera Image AI Detection

## How to Debug

### Step 1: Enable Debug Logging
The code now has comprehensive logging. When you take a camera photo and create a post, you should see these log messages in order:

1. **When picking the image:**
   ```
   CreatePostScreen: Copied camera image to permanent location: /path/to/file.jpg
   ```

2. **When AI detection starts:**
   ```
   PostRepository: Running IMAGE-ONLY detection for post <post_id>
   PostRepository: Media file: /path/to/file.jpg
   PostRepository: File exists: true
   AiDetectionService: Starting image detection for /path/to/file.jpg
   AiDetectionService: File size: 123456 bytes
   AiDetectionService: Sending request to API...
   ```

3. **When AI detection completes:**
   ```
   AiDetectionService: Received response with status 200
   PostRepository: AI detection result: HUMAN-GENERATED (or AI-GENERATED)
   PostRepository: AI confidence: 15.5 (or whatever the score is)
   ```

### Step 2: Test Camera vs Gallery
1. Take a photo with the camera
2. Note the AI confidence score
3. Upload the SAME photo from gallery
4. Compare the AI confidence scores

If they're different, there's a processing issue. If they're the same, the API is correctly analyzing the image.

### Step 3: Check the Logs

Look for these specific issues:

#### Issue 1: File Not Found
```
AiDetectionService: ERROR - File does not exist: /path/to/file.jpg
```
**Solution:** The file copy failed. Check for storage permission issues.

#### Issue 2: API Error
```
AiDetectionService: API error response: <error message>
```
**Solution:** The API rejected the request. Check the error message for details.

#### Issue 3: File Size Zero
```
AiDetectionService: File size: 0 bytes
```
**Solution:** The file is empty. Camera capture failed.

### Step 4: Verify Image Quality

Camera images might be flagged if:
- They're very low quality/blurry
- They have heavy compression artifacts
- They're very small resolution
- They have unusual color profiles

### Step 5: Test with Known Human Content

Take photos of:
1. A handwritten note
2. A printed book page
3. Your hand/face
4. A natural outdoor scene

These should all score LOW (<20%) AI confidence.

## Expected Behavior

### Gallery Image (Working)
```
1. User selects image from gallery
2. File path: /storage/emulated/0/DCIM/Camera/IMG_20260214_090000.jpg
3. File exists: true
4. File size: 2458624 bytes
5. API returns: HUMAN-GENERATED, confidence: 85.3
6. AI probability: 14.7% (100 - 85.3)
7. Post published with low AI score ✓
```

### Camera Image (Should Work Now)
```
1. User takes photo with camera
2. Original path: /data/user/0/com.app/cache/image_picker123.jpg
3. Copied to: /tmp/camera_image_1707898920000.jpg
4. File exists: true
5. File size: 2458624 bytes
6. API returns: HUMAN-GENERATED, confidence: 85.3
7. AI probability: 14.7% (100 - 85.3)
8. Post published with low AI score ✓
```

## Common Issues

### Issue: All camera images flagged as 100% AI

**Possible Causes:**
1. **File not being sent correctly** - Check logs for file existence
2. **API receiving corrupted data** - Check file size in logs
3. **Image metadata issues** - Camera images have different EXIF data
4. **API model bias** - The AI model might be biased against certain image characteristics

**Debug Steps:**
1. Check if file exists: Look for "File exists: true" in logs
2. Check file size: Should be > 0 bytes
3. Check API response: Should be 200 status code
4. Check actual AI result: Look for "AI detection result:" in logs

### Issue: Inconsistent results

If sometimes it works and sometimes it doesn't:
1. **Timing issue** - File being cleaned up too quickly
2. **Permission issue** - Intermittent storage access problems
3. **Network issue** - API request failing sometimes

## Next Steps

If camera images are STILL being flagged after this fix:

1. **Collect the debug logs** - Copy all the log output when creating a post
2. **Test the API directly** - Try uploading a camera image to the API manually
3. **Check image properties** - Compare EXIF data between camera and gallery images
4. **Contact API support** - The AI model might need retraining

## Manual API Test

To test the API directly with a camera image:

```bash
# Save a camera photo to your computer
# Then test with curl:

curl -X POST https://noai-lm-production.up.railway.app/api/v1/detect/image \
  -F "file=@/path/to/camera_photo.jpg"
```

Compare the result with a gallery image:

```bash
curl -X POST https://noai-lm-production.up.railway.app/api/v1/detect/image \
  -F "file=@/path/to/gallery_photo.jpg"
```

If both return similar results, the API is working correctly and the issue is in how we're sending the data.
