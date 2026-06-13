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
- `GET /healthz`
  - No auth; for local health checks.

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

## Auth

Production should configure one of these:

- `FLEET_BACKUP_AUTH_HS256_SECRET`: same HS256 secret used by the account
  service that issues the phone-login token. The token must contain one of
  `sub`, `user_id`, or `phone`, and may contain `exp`.
- `FLEET_BACKUP_AUTH_INTROSPECTION_URL`: HTTPS endpoint on the account service
  for opaque login tokens. The backend posts `{"token":"..."}` and accepts
  JSON containing `active:true` or `ok:true` plus one of `sub`, `user_id`,
  `phone`, or `user.id`.

`FLEET_BACKUP_AUTH_INTROSPECTION_BEARER_TOKEN` is optional for server-to-server
authorization to the introspection endpoint.

For one-machine smoke tests only, set:

```bash
FLEET_BACKUP_DEV_TOKENS_JSON='{"local-test-token":"test-user"}'
```

Do not enable dev tokens in production.

Optional JWT hardening:

- `FLEET_BACKUP_AUTH_JWT_ISSUER`: expected `iss` claim.
- `FLEET_BACKUP_AUTH_JWT_AUDIENCE`: expected `aud` claim.

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
- The health check only returns `{"ok":true}` and must not expose config.

## Test

```bash
python3 -m py_compile app.py tests/test_app.py
python3 -m unittest discover -s tests
```

Tests use local file storage and a temporary SQLite database; they do not call
Aliyun OSS.

## Deployment Assets

`deploy/` contains an ECS installer, Nginx sample, and smoke-test script. The
installer creates the service user, venv, data/log directories, systemd unit,
and root-owned `0600` env file, but it does not start the service while the env
file still contains placeholders.

## 客户端加密（账号绑定，零知识）

App 端可对备份 payload 做 **AES-256-GCM 客户端加密**（密钥经 HKDF-SHA256 从
账号绑定的高熵秘密派生）。此时信封：

- `payload_encoding`: `"aes-256-gcm"`
- `payload_json`: base64(密文 ++ GCM tag) —— 后端**不解密、不解析为 JSON**，
  仅做大小/哈希等传输校验后原样存入 OSS。
- `encryption`: `{ algo, kdf, salt, nonce, key_id, plaintext_sha256,
  plaintext_bytes }` —— 仅非秘密元数据，随包透传。`account secret` 永不出现在
  信封里，后端无法解密（零知识）。

明文备份（`payload_encoding` 缺省/`"plaintext"`）保持原有「payload_json 必须为
JSON 对象」的防御，向后兼容旧包。

### 部署者必读：账号密钥下发（P0-A 集成点）

「账号绑定派生」要求账号服务在登录时向 App 下发一份**高熵且稳定**的备份秘密
（不是手机号、不是会轮换的 access token）。换机重新登录拿到同一份秘密即可解密
旧备份。后端就绪后，需提供一个受鉴权保护的接口返回该秘密，并在 App 的
`_resolveAccountBackupSecret`（lib/app/providers/device_fleet_providers.dart）
接入。未接入时，App 生产构建会**拒绝上传明文**（requireEncryption=true），即云
备份在密钥就绪前不可用——这是刻意的合规兜底。
