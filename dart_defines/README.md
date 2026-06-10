# IAP Dart Defines

The subscription purchase flow is intentionally disabled unless a verification
mode is selected at build time. Xcode Archive does not add Flutter
`--dart-define` values by default, so App Store and production archives must be
built with one of the files in this directory.

## Files

- `app_store_review.json` sets `USE_LOCAL_IAP_VERIFICATION=true`.
  Use this only as a short-term stopgap to unblock App Review while the backend
  verification service is being finished and sandbox-tested. Do not use it as a
  long-term production build mode.
- `production.json` sets `APPLE_IAP_VERIFICATION_BASE_URL`.
  This enables server-side App Store verification. The current value is
  `https://api.yuyuan.net.cn/fleet-ledger`; confirm this base URL against the
  deployed backend and pass a sandbox purchase verification before using it for
  an App Store production submission.

## Commands

Immediate App Review resubmission:

```bash
flutter build ipa --release --dart-define-from-file=dart_defines/app_store_review.json
```

Production build after backend verification is live:

```bash
flutter build ipa --release --dart-define-from-file=dart_defines/production.json
```

If local iOS signing is unavailable, verify the defines with tests:

```bash
flutter test test/features/upgrade_page_iap_define_test.dart --dart-define-from-file=dart_defines/app_store_review.json
flutter test test/features/upgrade_page_iap_define_test.dart --dart-define-from-file=dart_defines/production.json
```

Increase the iOS build number before uploading a new App Store binary. For
example, update `CFBundleVersion` through the normal Flutter/iOS release flow or
run the release build with the next approved build number.

## CI

CI and release automation should pass the same file explicitly:

```bash
flutter test --dart-define-from-file=dart_defines/production.json
flutter build ipa --release --dart-define-from-file=dart_defines/production.json
```

Do not add `USE_LOCAL_IAP_VERIFICATION` to default or production build scripts.
After the backend is deployed and sandbox verification passes, switch App Store
builds from `app_store_review.json` to `production.json`. The backend request
and response contract is documented in `docs/iap_verification_backend_contract.md`.
