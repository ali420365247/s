# mobile — Flutter scaffold

This folder contains a minimal Flutter scaffold for the Nexus MVP.

How to run (locally):

```bash
cd mobile
flutter pub get
flutter run
```

Notes:
- UI is intentionally minimal and contains plugin buttons for the mesh transport, ZK-KYC, and libsignal initialization.
- We'll wire Rust FFI crates into the Flutter app later using `flutter_rust_bridge` or platform channels.
