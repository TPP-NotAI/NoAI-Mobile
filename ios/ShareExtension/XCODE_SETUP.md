# iOS Share Extension — Xcode Setup (one-time, on Mac)

All Swift/plist files are already written. You just need to register the
target in Xcode so it gets built and signed.

## Steps

### 1. Open the workspace
Open `ios/Runner.xcworkspace` in Xcode (not the .xcodeproj).

### 2. Add the ShareExtension target
- File → New → Target
- Choose **Share Extension** → Next
- Product Name: `ShareExtension`
- Language: **Swift**
- Uncheck "Activate scheme" when prompted
- Finish

### 3. Replace the generated files with ours
Xcode will have created placeholder files. Replace them with the files
already in `ios/ShareExtension/`:
- Delete Xcode's generated `ShareViewController.swift` → use ours
- Delete Xcode's generated `Info.plist` → use ours
- Delete Xcode's generated `MainInterface.storyboard` → use ours

(In Xcode's file navigator: right-click → Delete → Remove Reference,
then drag our files in from Finder)

### 4. Configure the target settings
Select the **ShareExtension** target → General tab:
- Bundle Identifier: `com.theprescientpachyderm.rooverse.ShareExtension`
- Deployment Target: **iOS 13.0**
- Signing: same Team as Runner

### 5. Add App Group capability to BOTH targets
For **Runner** target:
- Signing & Capabilities → + Capability → App Groups
- Add `group.com.rooverse.app`
- The file `Runner/Runner.entitlements` already declares this group

For **ShareExtension** target:
- Signing & Capabilities → + Capability → App Groups
- Add `group.com.rooverse.app`
- In Build Settings → Code Signing Entitlements, set to `ShareExtension/ShareExtension.entitlements`
- The file `ShareExtension/ShareExtension.entitlements` already declares this group

### 6. Add URL scheme to ShareExtension target
ShareExtension target → Info tab → URL Types → +:
- Identifier: `ShareMedia`
- URL Schemes: `ShareMedia`

### 7. Run pod install
```bash
cd ios && pod install
```

### 8. Build & test
Run on a real device (share extensions don't work in Simulator).
Share an image from Photos → tap the share icon → "Share to Rooverse"
should appear in the share sheet.
