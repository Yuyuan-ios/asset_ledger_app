# FleetLedger Cloud Backup Backend

This is the minimal backend for the existing Flutter contract:

```text
FleetLedger App -> HTTPS /v1/backups -> backend -> private Aliyun OSS bucket
```

The App still uses `CloudApiClient` and `HttpCloudBackupGateway`. No OSS key,
bucket policy, or object path is placed in the Flutter client.

## API

- `POST /v1/backups`
  - Auth: `Authorization: Bearer <app-login-token>`
  - Body: the existing cloud backup envelope JSON.
  - Response: `{"backup_id":"..."}`
- `GET /v1/backups`
  - Response: `{"backups":[{"backup_id","created_at","db_schema_version","payload_bytes"}]}`
- `GET /v1/backups/{backup_id}`
  - Response: the original cloud backup envelope JSON.
- `GET /v1/account/backup-key`
  - Auth: `Authorization: Bearer <app-login-token>`
  - Response: `{"backup_secret":"..."}`
  - Returns the stable high-entropy account secret used by the App as
    `CloudBackupCipher` key material.
- `GET /healthz`
  - No auth; for local health checks and non-secret config diagnostics.

## Storage

- Metadata is stored in SQLite:
  `backup_id / user_id / object_key / db_schema_version / payload_sha256 / payload_bytes / created_at`.
- Payload envelopes are stored as private OSS objects under:
  `<ALIYUN_OSS_PREFIX>/<sha256(user_id)[0:32]>/<backup_id>.json`.

## Runtime

Python 3.9+ is enough. No third-party packages are required.

```bash
cd /opt/fleet-ledger-cloud-backup
cp env.example .env
# ensure server/common is available as ./common or ../common
# edit .env, then:
set -a
. ./.env
set +a
python3 app.py
```

Put nginx with HTTPS in front of `127.0.0.1:8008`, and route the app backend
base path to this service. Production Flutter builds must explicitly set
`FLEET_LEDGER_CLOUD_BACKUP_BASE_URL` to this HTTPS service. Development and
test builds may fall back to `FLEET_LEDGER_API_BASE_URL`; release builds must
not rely on that fallback unless the production API host has already been
verified to serve `/v1/backups`.

## Trust Model

The backend separates token use into three auth planes:

- `USER_AUTH_TOKEN`: the app login bearer token on public cloud-backup APIs.
  The backend validates it and resolves a stable FleetLedger account `user_id`.
- `SERVICE_INTERNAL_TOKEN`: server-to-server authority for CloudBackup -> IAP
  internal entitlement verification. Internal endpoints must use this plane.
- `EXTERNAL_CLIENT_TOKEN`: Flutter/App-only client identity. This backend does
  not accept it as server authority and never uses it for entitlement or
  account binding. `EXTERNAL_CLIENT_TOKEN_REQUIRED = False` is a config
  statement only; there is no runtime token fallback.

`user_id` means the unique FleetLedger account identity. It is not a session
identity, not a device identity, and not an Apple `appAccountToken`. Token
refresh must resolve back to the same `user_id` for the same account.

## User Auth

Production should configure one of these:

- `USER_AUTH_HS256_SECRET`: same HS256 secret used by the account
  service that issues the phone-login token. The token must contain one of
  `sub`, `user_id`, or `phone`, and may contain `exp`.
- `USER_AUTH_INTROSPECTION_URL`: HTTPS endpoint on the account service
  for opaque login tokens. The backend posts `{"token":"..."}` and accepts
  JSON containing `active:true` or `ok:true` plus one of `sub`, `user_id`,
  `phone`, or `user.id`.

`USER_AUTH_INTROSPECTION_SERVICE_TOKEN` is optional server-to-server
authorization to the introspection endpoint. Successful token -> `user_id`
resolutions are cached briefly by digest only; failed resolutions are not
cached.

For one-machine smoke tests only, set:

```bash
FLEET_BACKUP_DEV_TOKENS_JSON='{"local-test-token":"test-user"}'
```

Do not enable dev tokens in production.

Optional JWT hardening:

- `USER_AUTH_JWT_ISSUER`: expected `iss` claim.
- `USER_AUTH_JWT_AUDIENCE`: expected `aud` claim.

Breaking migration required: deprecated auth env names are rejected at startup
with `ConfigMigrationError`. Use only `USER_AUTH_*`; the deprecated names are
listed in `env.example` for operator cleanup.

## Max Entitlement

Bearer auth only identifies the account. Every cloud-backup API also requires a
server-side Max entitlement check before backup-key issuance, upload, list, or
download. Production must configure a trusted HTTPS entitlement source:

```bash
APP_ENV=production
CLOUD_BACKUP_ENTITLEMENT_URL=https://api.example.com/internal/v1/entitlements/verify
SERVICE_INTERNAL_TOKEN=replace-with-cloud-backup-to-iap-token
CLOUD_BACKUP_ENTITLEMENT_TIMEOUT_SECONDS=5
CLOUD_BACKUP_ENTITLEMENT_CACHE_TTL_SECONDS=60
```

The verifier posts the authenticated `user_id` server-to-server with
`required_capability:"cloud_backup"` and `required_plan:"max"`, authenticated by
`Authorization: Bearer <SERVICE_INTERNAL_TOKEN>`. It accepts only JSON
that explicitly proves active Max entitlement, for example
`{"allowed":true,"entitlementTier":"max","entitlementActive":true}` or an equivalent nested
entitlement/subscription object. Free, Pro, expired, unknown, missing fields,
malformed JSON, non-2xx service errors, timeouts, or exceptions fail closed.

Response semantics:

- Missing/invalid app Bearer token: `401 unauthorized`.
- Authenticated but Free/Pro/expired/not entitled: `403 cloud_backup_requires_max`.
- Entitlement service unavailable, timed out, returned 500, or returned malformed
  JSON: `503 subscription_verification_unavailable`.

Production and staging fail fast at startup if `CLOUD_BACKUP_ENTITLEMENT_URL` or
`SERVICE_INTERNAL_TOKEN` is missing. If `APP_ENV` is unset, the backend
treats it as production for this entitlement check. Deprecated service-plane
aliases are rejected at startup with `ConfigMigrationError`; migrate to
`CLOUD_BACKUP_ENTITLEMENT_URL` and `SERVICE_INTERNAL_TOKEN`.

For local or test-only smoke checks, a static allow-list can be enabled only
when `APP_ENV` is `test`, `local`, or `development`:

```bash
APP_ENV=local
CLOUD_BACKUP_MAX_ENTITLED_USERS_JSON='["test-user"]'
```

Do not enable the static allow-list in production. The backend never trusts
client-declared subscription headers such as `X-Subscription-Tier: max`; only the
server-to-server entitlement source can grant Max cloud backup access.

`GET /healthz` returns non-secret diagnostics:

```json
{
  "ok": true,
  "app_env": "production",
  "cloud_backup_entitlement_required": true,
  "entitlement_verifier": "configured"
}
```

`entitlement_verifier` can be `configured`, `missing`, or `disabled_for_test`.
The response never includes tokens, secrets, receipts, or full account data.

Deployment checklist:

- Set `APP_ENV=production` or `APP_ENV=staging`.
- Set `CLOUD_BACKUP_ENTITLEMENT_URL` to an HTTPS account/subscription endpoint.
- Set `SERVICE_INTERNAL_TOKEN` to the CloudBackup -> IAP server-to-server token.
- Confirm no `CLOUD_BACKUP_MAX_ENTITLED_USERS_JSON` or
  static entitlement allowlist variables are present in production.
- Confirm Free, Pro, expired, and entitlement-service-unavailable states fail
  closed before enabling cloud backup for users.

Env migration checklist:

- Replace deprecated auth variables with the `USER_AUTH_*` names in
  `env.example`.
- Replace deprecated service-to-service entitlement variables with
  `CLOUD_BACKUP_ENTITLEMENT_URL` and `SERVICE_INTERNAL_TOKEN`.
- Remove deprecated static entitlement allowlist variables from production
  env files; use `CLOUD_BACKUP_MAX_ENTITLED_USERS_JSON` only for explicit
  local/test smoke checks.
- Confirm startup fails with `ConfigMigrationError` if any deprecated name
  remains set.

## Account Backup Key Issuer

Set `FLEET_BACKUP_ACCOUNT_KEY_SECRET` to a separate 32+ character random value.
The backend derives a per-account backup secret as:

```text
HMAC-SHA256(FLEET_BACKUP_ACCOUNT_KEY_SECRET, "fleet-ledger-backup-key:v1:<user_id>")
```

The returned `backup_secret` is stable for the account, so a user can reinstall
or switch phones, log in again, and decrypt old encrypted backups. Do not reuse
JWT, SMS, OSS, or database secrets for this value. Keep it backed up securely:
rotating or losing it makes existing encrypted backups unrecoverable.

## OSS Permissions

Use a RAM user or role with the narrowest possible permission for the private
bucket/prefix:

- `oss:PutObject`
- `oss:GetObject`
- `oss:DeleteObject` for cleanup when metadata writing fails after upload

The App never receives AK/SK. The backend signs OSS requests server-side.

Request size limits are configured with `FLEET_BACKUP_MAX_PAYLOAD_BYTES`
and `FLEET_BACKUP_MAX_REQUEST_BYTES`. Keep the request limit greater than or
equal to the payload limit.

Production requirements:

- Keep the OSS bucket private; never use public-read-write.
- Prefer an ECS RAM role or a least-privilege RAM user limited to the backup
  bucket/prefix.
- Store environment variables outside the repository with `0600` permissions.
- Put HTTPS in front of the service. Do not expose the Python process directly
  to the public internet.
- Set nginx `client_max_body_size` to at least `70m`, with send/read/body
  timeouts around `180s`, so 64MB backup envelopes are not rejected by nginx
  before the app enforces its own limit.
- If this service is later wrapped with Gunicorn or another process manager,
  set worker timeout to at least `180s`. The current stdlib service example is
  intended to run behind nginx on `127.0.0.1`.
- Keep systemd logs and access logs free of Authorization headers, app tokens,
  OSS secrets, JWT secrets, and backup payload bodies.
- The health check exposes only non-secret config status and must never expose
  tokens, receipts, Authorization headers, OSS secrets, JWT secrets, or payloads.

## Test

```bash
python3 -m py_compile app.py handlers.py entitlements.py tests/test_app.py ../common/auth_identity/resolver.py
python3 -m unittest discover -s tests
```

Tests use local file storage and a temporary SQLite database; they do not call
Aliyun OSS.

## Deployment Assets

`deploy/` contains an ECS installer, Nginx sample, and smoke-test script. The
installer creates the service user, venv, data/log directories, systemd unit,
and root-owned `0600` env file, but it does not start the service while the env
file still contains placeholders.

## 客户端加密（账号绑定，OSS 存密文）

App 端可对备份 payload 做 **AES-256-GCM 客户端加密**（密钥经 HKDF-SHA256 从
账号绑定的高熵秘密派生）。此时信封：

- `payload_encoding`: `"aes-256-gcm"`
- `payload_json`: base64(密文 ++ GCM tag) —— 后端**不解密、不解析为 JSON**，
  仅做大小/哈希等传输校验后原样存入 OSS。
- `encryption`: `{ algo, kdf, salt, nonce, key_id, plaintext_sha256,
  plaintext_bytes }` —— 仅非秘密元数据，随包透传。`account secret` 永不出现在
  信封或 OSS 对象里。

明文备份（`payload_encoding` 缺省/`"plaintext"`）保持原有「payload_json 必须为
JSON 对象」的防御，向后兼容旧包。

### 部署者必读：账号密钥下发（P0-A 集成点）

「账号绑定派生」要求账号服务向 App 下发一份**高熵且稳定**的备份秘密（不是手机
号、不是会轮换的 access token）。本服务通过受鉴权保护的
`GET /v1/account/backup-key` 返回该秘密，App 的生产装配已通过
`HttpCloudBackupKeyProvider` 接入。未配置 `FLEET_BACKUP_ACCOUNT_KEY_SECRET` 时，
端点返回 `backup_key_unavailable`，App 生产构建会**拒绝上传明文**
（requireEncryption=true），即云备份在密钥就绪前不可用——这是刻意的合规兜底。
