# asset_ledger

A new Flutter project.

## Architecture Rules

- `components/`: Pure visual, reusable UI. No business semantics. Must not read Store.
- `patterns/`: Layout/structure composition. May contain business semantics but must not read Store.
- `features/*/view`: Page assembly only. Responsible for `context.watch/read`, routing params, callbacks.
- `data/*`, `features/*/controller`: Must not import `components/`, `patterns/`, or `features/*/view`.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
