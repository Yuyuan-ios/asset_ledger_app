# Version Policy Static JSON

This directory defines the V1 static version-policy format for FleetLedger app
update checks. It is a deployment aid and schema example only; the live
production policy file is managed by operations on ECS and should not be
committed to the repository.

The public endpoint is same-domain path delivery:

```text
GET https://<host>/app/version-policy.json
```

V1 uses nginx static file serving. It does not add a Python service, backend
route, database table, or application dependency.

## Fields

Top-level keys are split by platform:

- `ios`: iOS App Store update policy.
- `android`: Android update policy.

Platform fields:

- `latestVersion`: latest available semantic version, compared as
  `major.minor.patch`.
- `minSupportedVersion`: minimum usable semantic version. A client derives the
  force-update state from `current < minSupportedVersion`.
- `updateUrl`: fallback update target. iOS points to App Store. Android points
  to the official landing page.
- `title`: update prompt title. Clients may use built-in fallback copy if
  missing.
- `content`: update prompt body. Clients may use built-in fallback copy if
  missing.

Android additionally has `channelUrls`, keyed by the same namespace as the
client `APP_CHANNEL` build define:

- `xiaomi`
- `huawei`
- `oppo`
- `vivo`
- `tencent`
- `official`
- `play`

`forceUpdate` is intentionally not a stored field. It is derived from
`current < minSupportedVersion` to avoid conflicting policy sources.

## Update Flow

Production updates should use atomic replacement:

```bash
cd /opt/fleet-ledger-version-policy
python3 -m json.tool version-policy.json.tmp >/dev/null
mv -f version-policy.json.tmp version-policy.json
```

Nginx serves the file directly, so normal policy edits do not require restarting
or reloading nginx. Reload nginx only when changing nginx configuration.

## Reliability Model

The client treats policy fetch or parse failures as fail-open and continues as
if there is no update. Real emergency blocking is handled by the later server
426 guard for core APIs. The static policy endpoint itself must never be
blocked by that guard, so old clients can still learn where to update.

This keeps version-policy delivery in a separate fault domain from sync/backup
application logic while reusing the same ECS/nginx deployment infrastructure.
