iOS: Manual Xcode step required
iOS Share Extensions cannot be created by editing files — they require a new Xcode target. You need to do this once in Xcode:

Open ios/Runner.xcworkspace in Xcode
File → New → Target → choose Share Extension → name it ShareExtension
Set the App Group to group.com.rooverse.app on both the Runner and ShareExtension targets (Signing & Capabilities → + Capability → App Groups)
Follow the receive_sharing_intent iOS setup guide to configure the extension's Info.plist and ShareViewController.swift
After that, run flutter pub get and rebuild the app.