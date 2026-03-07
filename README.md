# asset_ledger

A new Flutter project.

## Architecture Rules

- `components/`: Pure visual, reusable UI. No business semantics. Must not read Store.
- `patterns/`: Layout/structure composition. May contain business semantics but must not read Store.
- `features/*/view`: Page assembly only. Responsible for `context.watch/read`, routing params, callbacks.
- `data/*`, `features/*/controller`: Must not import `components/`, `patterns/`, or `features/*/view`.

## Typography Rules

- UI layers (`features/`, `components/`, `patterns/`) must not set `fontFamily` directly.
- Prefer `Theme.of(context).textTheme` + semantic helpers (`AppTypography`) over ad-hoc `TextStyle`.
- Reuse semantic typography tokens (`pageTitle`, `sectionTitle`, `body`, `bodySecondary`, `caption`, `actionText`) rather than scattering raw font sizes.
- Migrated modules (`account`, `fuel`, `maintenance`, `timing`, plus migrated `components/*` subdirectories) must not instantiate `TextStyle` directly (except documented painter-level exceptions).

## Architecture Checks

- `bash tools/agent_preflight.sh`: Startup preflight for agent work. By default it checks command availability, verifies the local GitNexus index metadata, runs architecture boundary scan, `flutter analyze`, `dart run custom_lint`, and the Patrol smoke test on `macos`. Use `--skip-patrol` or set `PATROL_DEVICE=<deviceId>` when needed.
- `dart run custom_lint`: Enforces architecture rules inside the analyzer, including forbidden UI imports from `lib/data/**` and `lib/features/*/state/**`, `context.watch/read` usage inside `lib/components/**` and `lib/patterns/**`, and direct `fontFamily` usage in UI layers.
- `./tools/check_architecture.sh`: Runs the same boundary checks with `rg` today. The checked-in `sgconfig.yml` reserves the ast-grep layout, but the local `ast-grep 0.41.0` in this workspace does not support Dart yet.
- `patrol test -t integration_test/device_flow_test.dart -d <deviceId>`: Runs the minimal Patrol-backed device page smoke flow. This requires the `patrol` CLI; `flutter test` initializes the wrong binding for `patrolTest`.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
