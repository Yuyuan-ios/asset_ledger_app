# Subscription Billing Milestone

## 1. Milestone Scope

This milestone records the subscription billing system state after completing:

- Unified multi-channel subscription gateway.
- Apple / Google / OPPO / Xiaomi / Huawei / Vivo adapter architecture.
- Server-side entitlement engine.
- SCP v1-v3.
- RBL / PWPI.
- BOL Phase 1 / Phase 2.
- Runtime deployment + smoke.
- Deploy runbook / smoke guards.
- SSH remote setup.

## 2. Final Architecture

The final architecture for this milestone is:

purchase/webhook event
-> adapter verification
-> authority / ordering / state machine
-> append-only event ledger
-> hash-chain integrity verification
-> deterministic replay
-> cache-only projection
-> explainability
-> decision graph
-> internal-only observability API

Architecture invariants:

- The event store is the source of truth.
- The projection is cache only.
- Explainability and the decision graph are observability only.
- The graph does not participate in entitlement decisions.
- Public clients do not access the internal observability API.

## 3. Runtime Services

Runtime ownership:

- 8009 = `fleet-ledger-cloud-sync.service`.
- 8010 = `fleet-ledger-iap.service`.
- IAP code dir = `/opt/fleet-ledger-iap`.
- IAP venv = `/opt/fleet-ledger-iap/venv`.
- IAP env = `/etc/fleet-ledger/iap.env`.
- Shared dependency = `/opt/common`.
- BOL explain/graph runtime = 8010 only.

## 4. Security Invariants

Security invariants:

- No client-provided tier is trusted.
- Entitlement derives from the server-side ledger.
- `SERVICE_INTERNAL_TOKEN` protects internal explain/graph APIs.
- There is no public nginx route for internal explain/graph.
- Sensitive fields are redacted:
  - `purchaseToken`
  - `signature`
  - `transaction_id`
  - `transactionId`
  - `bearer`
  - `secret`
  - `JWS`
  - `rawPayload`
  - `raw_payload`
- No raw purchase payload appears in observability responses.
- Wrong token returns 401.
- Public route returns 404 / not routed.

## 5. Verification Completed

Completed verification:

- Local unittest count: 117 tests.
- ResourceWarning strict unittest passed.
- `check_fast` passed.
- `check_full` passed after escalated Flutter SDK cache rerun.
- `check_architecture` passed.
- Git diff checks passed.
- GitNexus low risk / 0 affected processes.
- Runtime graph API valid token 200.
- Wrong token 401.
- No token 401.
- Public graph route 404.
- Explain regression passed.
- Sensitive leak scan passed.
- IAP service active on 8010.
- 8009 not affected.

## 6. Known Deployment Lessons

Issues exposed and closed during this milestone:

- HTTPS `credential-osxkeychain` failure; switched origin to SSH.
- Service venv path mismatch; standardized `/opt/fleet-ledger-iap/venv`.
- `/opt/common` shared package missing caused `ModuleNotFoundError`.
- Missing `SERVICE_INTERNAL_TOKEN` blocked valid smoke.
- 8009/8010 ownership ambiguity resolved.
- `/event/test-event` smoke was invalid; use numeric `/event/1`.
- Avoid fixed `/tmp/bol_*` paths; use `mktemp` + `trap` cleanup.

## 7. Current Git State

Current git state template:

- `develop` contains the milestone commits through `docs/dev/github_ssh_remote_setup.md`.
- Origin uses SSH remote: `git@github.com:Yuyuan-ios/asset_ledger_app.git`.
- Push should be done after this milestone note commit.
- Do not force push.

## 8. What Not To Do Next

Do not:

- Do not expose internal explain/graph APIs publicly.
- Do not let graph influence entitlement decisions.
- Do not add client access to BOL APIs without a separate product/security review.
- Do not start SCP v4 distributed ledger unless multi-node/multi-region billing becomes real.
- Do not proceed to BOL Phase 3 before this milestone note is committed and pushed.

## 9. Next Recommended Phase

BOL Phase 3 - Billing Timeline & Operational Metrics.

Goals:

- User subscription timeline.
- Channel/event counts.
- Ignored/rejected/correction stats.
- Webhook/replay/order anomaly metrics.
- Internal operational summaries.
- No public dashboard by default.
