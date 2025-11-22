Platform setup checklist (Android + iOS)

Android
- Add to `android/app/build.gradle` dependencies:
  - `implementation "androidx.biometric:biometric:1.2.0"`
- Ensure `minSdkVersion` is >= 23 and `targetSdkVersion` is up-to-date.
- Add runtime permission requests for NFC, Bluetooth, Nearby devices, and location using `permission_handler`.
- Copy `mobile/android/AndroidManifest.snippet.xml` entries into your `AndroidManifest.xml` (permissions + optional deep link intent-filter).
- Register the Kotlin plugin if necessary (embedding v2 should auto-register placed plugin files).

iOS
- Add usage descriptions to `Info.plist` (see `mobile/ios/InfoPlist.snippet.plist`).
- Ensure you run on real devices for biometric/Keychain tests.
- If you use FaceID, ensure `NSFaceIDUsageDescription` is present if required by your iOS version.
- No extra CocoaPods are required for Keychain usage; Biometric UI is triggered by Keychain APIs.

Notes
- Biometric flows require real devices; emulators won't prompt for fingerprints/FaceID.
- Test both biometric and non-biometric paths.
