# RENTAMAC - Registration, Mobile Access & App Publishing Guide

## Part 1: Registering with Rentamac

1. **Visit Pricing Page** - Go to Rentamac.io and navigate to the Pricing page
2. **Select a Plan** - Choose your plan and click **Buy Plan**
3. **Complete Payment** - Pay using Link, Amazon Pay, Apple Pay, or credit card
   - Standard plan: **US$99/month** (~$3.30/day)
   - Includes: 24/7 access, remote desktop via DeskIn, full admin privileges, dedicated Mac mini, immediate access, high-speed internet
4. **Provisioning** - Setup page displays while your Mac Mini is being provisioned
5. **Receive Credentials** - Get your remote access ID and password via dashboard and email
6. **Connect** - Use DeskIn (recommended for paid plans) or AnyDesk to access your Mac

---

## Part 2: Using Rentamac on iOS

1. **Download** - Install **DeskIn Remote Desktop** from the App Store
2. **Sign In** - Open the app and sign in or create a DeskIn account
3. **Enter Credentials** - Input your Mac's ID and password from Rentamac
4. **Connect** - Access your Mac Mini with full functionality

---

## Part 3: Using Rentamac on Android

1. **Download** - Install **DeskIn Remote Desktop** from Google Play
2. **Sign In** - Open the app and log into your DeskIn account
3. **Enter Credentials** - Input the device ID and password from Rentamac
4. **Connect** - Access your Mac Mini with full administrator privileges

---

## Part 4: Publishing Your App on iOS (App Store)

### Prerequisites
- Apple Developer Account (**US$99/year**)
- Mac computer (use your Rentamac Mac Mini)
- Xcode installed
- App icons, screenshots, and marketing assets

### Step-by-Step Process

1. **Enroll in Apple Developer Program**
   - Go to developer.apple.com
   - Sign in with your Apple ID
   - Pay the $99/year fee
   - Wait for approval (up to 48 hours)

2. **Prepare Your App in Xcode**
   - Open your project in Xcode on your Rentamac Mac
   - Set your Bundle Identifier (unique app ID)
   - Configure signing certificates and provisioning profiles
   - Set version number and build number
   - Add app icons (all required sizes)

3. **Create App Store Connect Listing**
   - Log into appstoreconnect.apple.com
   - Click "My Apps" → "+" → "New App"
   - Fill in: App name, primary language, bundle ID, SKU
   - Add app description, keywords, support URL, privacy policy URL

4. **Upload Screenshots & Assets**
   - Screenshots for each device size (iPhone, iPad if applicable)
   - App preview videos (optional)
   - Promotional text and subtitle

5. **Archive and Upload**
   - In Xcode: Product → Archive
   - Click "Distribute App" → "App Store Connect"
   - Upload the build

6. **Submit for Review**
   - In App Store Connect, select your uploaded build
   - Complete the App Review Information section
   - Answer export compliance questions
   - Click "Submit for Review"

7. **Wait for Approval**
   - Review typically takes 24-48 hours
   - Address any rejection feedback if needed
   - Once approved, your app goes live

---

## Part 5: Publishing Your App on Android (Google Play Store)

### Prerequisites
- Google Play Developer Account (**US$25 one-time fee**)
- Signed APK or AAB (Android App Bundle)
- App icons, screenshots, and marketing assets

### Step-by-Step Process

1. **Register as Google Play Developer**
   - Go to play.google.com/console
   - Sign in with your Google account
   - Pay the $25 one-time registration fee
   - Complete identity verification

2. **Create Your App Listing**
   - In Play Console, click "Create app"
   - Enter app name, default language, app/game type
   - Declare if it's free or paid

3. **Set Up Store Listing**
   - Add short description (80 chars max)
   - Add full description (4000 chars max)
   - Upload app icon (512x512 PNG)
   - Upload feature graphic (1024x500)
   - Add screenshots (min 2, max 8 per device type)

4. **Complete Content Rating**
   - Fill out the content rating questionnaire
   - Receive IARC rating automatically

5. **Set Up Pricing & Distribution**
   - Choose free or paid
   - Select countries for distribution
   - Opt into Google Play programs (optional)

6. **Prepare Release**
   - Go to "Production" → "Create new release"
   - Upload your signed AAB or APK file
   - Add release notes

7. **Complete App Content Section**
   - Privacy policy URL
   - Ads declaration
   - App access (login credentials for review if needed)
   - Content ratings
   - Target audience and content
   - Data safety section

8. **Submit for Review**
   - Review all sections (green checkmarks required)
   - Click "Review release" then "Start rollout to Production"

9. **Wait for Approval**
   - Review typically takes a few hours to 7 days
   - Address any policy issues if flagged
   - Once approved, your app goes live on Google Play

---

## Cost Summary

| Item | Cost |
|------|------|
| Rentamac (Mac access) | $99/month |
| Apple Developer Account | $99/year |
| Google Play Developer | $25 one-time |

---

## Note
For demos, use **AnyDesk** instead of DeskIn with the demo credentials provided on Rentamac's demo page.
Copy the Demo Instance Credentials
Use the following credentials to connect to our demo Mac Mini instance:

AnyDesk ID: 1713587112
AnyDesk Password: 0958tvu0439

