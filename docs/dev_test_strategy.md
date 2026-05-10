# Dev/Test and Release Dependency Strategy

The release `pubspec.yaml` intentionally does not include native test-only
dependencies such as `integration_test`, `patrol`, or `sqflite_common_ffi`.

This keeps iOS release archives clean and avoids shipping native test
frameworks or sqlite FFI artifacts in App Store builds.

For the 1.0.1 release line, use this release check:

```bash
./tool/analyze_release.sh
flutter build appbundle --release
flutter build ipa --release
```

Full widget, database, Patrol, and integration tests need a separate dev/test
workflow. That workflow can be designed later with a dedicated script, branch,
or dependency strategy, but should not be mixed into the release pubspec.
