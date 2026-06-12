# S4-2 share privacy whitelist

## Result

PASS

## Scope

- Branch: `codex/auto-s1-s7-20260612`
- Worktree: `/Users/yu/Flutter_Projects/fleet_ledger_codex_s1s7`
- Baseline before slice: `19bc5ad S4-1 project offset snapshot`
- Commit target: `S4-2 share privacy whitelist`

## Files

- `lib/data/share/jztshare/project_external_work_share_builder.dart`
- `lib/data/share/jztshare/project_external_work_share_export_adapter.dart`
- `lib/data/share/jztshare/project_external_work_share_rich_payload.dart`
- `test/data/share/jztshare/project_external_work_share_builder_test.dart`
- `test/data/share/jztshare/project_external_work_share_export_adapter_test.dart`
- `test/data/share/jztshare/project_external_work_share_export_service_test.dart`

## Implementation

- Defined `ProjectExternalWorkShareBuilder.sourceFingerprintWhitelistV2`.
- Bumped `ProjectExternalWorkShareRichPayload.currentFingerprintVersion` from `1` to `2`.
- Rebuilt `origin_fingerprint` from whitelist-only fields:
  - `fingerprint_version`
  - `package_source_device_id`
  - `work_date`
  - `start_meter_milli`
  - `end_meter_milli`
  - `hours_milli`
  - `income_fen`
  - `record_type`
  - `is_breaking`
- Removed contact/project-key/local-device-id inputs from the source fingerprint.
- Changed export adapter source identity:
  - `share_id` now includes a secure random nonce.
  - `source_installation_uuid` is a per-package `pkg-...` value derived from `share_id`, not from project id.
  - `source_record_uuid` / legacy `export_line_uuid` are per-package `rec-...` values derived from `share_id`.
  - `source_device_id` is a package-local ordinal, not the local device table id.

## DoD Evidence

- No phone/contact/project key/local device id/auto device number is in the source fingerprint whitelist.
- `source_installation_uuid` is no longer project-stable in the production export adapter.
- `source_device_id` is package-local; tests use local device id `9876` and assert exported id `1`.
- Repacking the same record with the same timestamp produces different `share_id`, `source_installation_uuid`, `source_record_uuid`, and `export_line_uuid`.
- `payload_sha256` stays 64-hex and the parser validates the generated envelopes.
- Existing `.jzt` file extension behavior is unchanged; legacy `.jztshare` remains rejected by existing tests.

## Impact Analysis

- `ProjectExternalWorkShareBuilder`: MEDIUM, 10 impacted, 0 affected processes.
- `ProjectExternalWorkShareExportAdapter`: LOW, 10 impacted, 0 affected processes.
- `ProjectExternalWorkShareRichPayload`: MEDIUM, 33 impacted, 0 affected processes.
- `JztShareEnvelopeParser`: MEDIUM, 23 impacted, 1 test process affected.
- `npx gitnexus detect-changes --scope all -r /Users/yu/Flutter_Projects/fleet_ledger_codex_s1s7` after implementation reported:
  - 6 files, 13 symbols
  - 1 affected process
  - risk level: medium
- `npx gitnexus detect-changes --scope staged -r /Users/yu/Flutter_Projects/fleet_ledger_codex_s1s7` before commit reported:
  - 7 files, 13 symbols
  - 1 affected process
  - risk level: medium

## Verification

- `flutter test test/data/share/jztshare/project_external_work_share_builder_test.dart test/data/share/jztshare/project_external_work_share_export_adapter_test.dart test/data/share/jztshare/project_external_work_share_export_service_test.dart` PASS (`+47`)
- `flutter test test/data/share/jztshare test/features/external_work/import_preview test/features/account/use_cases/project_share_export_use_case_test.dart` PASS (`+122`)
- `flutter analyze lib test` PASS
- `dart run custom_lint` PASS
- `git diff --check` PASS
- `flutter test` PASS (`+1848 ~3`)

## Risk Notes

- The existing code made `source_installation_uuid` stable from project id and exposed `source_device_id` as the local device id. This was not uncertain after inspection, so no OpenClaw clarification was needed for "is this stable/private?".
- The selected action is privacy-reducing mitigation and GitNexus reported MEDIUM, not HIGH/CRITICAL. No OpenClaw high-risk approval was triggered for this slice.
- No database migration, import table schema change, cloud/secrets, backup format, release, push, or merge action was performed.

## Audit Addendum (2026-06-12 merge review)

- Confirmed red-line fix: the v1 fingerprint hashed `legacyProjectKey`
  (contact||site, PII-derived) and the local auto-increment `device_id`,
  both forbidden by the outline (§6.4 "不打包手机号、通讯录、本机 device_id、
  设备自动编号"). v2 whitelist removes them. This was a pre-existing
  violation that earlier audits missed.
- Accepted compatibility boundary: `origin_fingerprint` is the recipient-side
  cross-package dedupe key (`project_external_work_duplicate_checker` queries
  `WHERE origin_fingerprint = ?`). Rows imported from v1-era packages keep v1
  fingerprints; re-sharing the same physical record after this upgrade
  produces a v2 fingerprint, so the recipient's duplicate warning will NOT
  fire across the v1/v2 boundary. Recomputing v1 for legacy rows is not
  possible on the import side (v1 inputs such as the sender's local device id
  are intentionally absent from v2 payloads). This one-time boundary is
  accepted as the price of removing PII from the fingerprint; per-share
  dedupe via the (source_share_id, source_record_uuid) unique index is
  unaffected.
