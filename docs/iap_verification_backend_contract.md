# IAP Verification Backend Contract

This document is the Flutter app contract for Apple subscription verification.
The Flutter repository does not contain backend code.

## Build-Time Modes

- `USE_LOCAL_IAP_VERIFICATION=true` enables local subscription verification for
  App Review or sandbox smoke tests only. It is defined only in
  `dart_defines/app_store_review.json`.
- `APPLE_IAP_VERIFICATION_BASE_URL` enables HTTP server verification. Production
  App Store builds should use `dart_defines/production.json` after the backend
  passes sandbox verification.
- Optional path and timeout defines:
  - `APPLE_IAP_VERIFY_PURCHASE_PATH`, default `/iap/apple/verify-purchase`
  - `APPLE_IAP_CURRENT_ENTITLEMENT_PATH`, default `/iap/apple/current-entitlement`
  - `APPLE_IAP_REQUEST_TIMEOUT_SECONDS`, default `10`
- A build with neither verification define keeps the purchase flow disabled and
  uses `PendingServerSubscriptionVerificationRepository`.

The current expected production base URL is
`https://api.yuyuan.net.cn/fleet-ledger`. Confirm this against the deployed
backend before using `dart_defines/production.json` for submission.

## Products And Entitlements

The app uses a tier-based yearly subscription model:

| Tier | Product ID | Period | China target price | Entitlement |
| --- | --- | --- | --- | --- |
| Pro | `com.yuyuan.assetledger.pro.yearly` | 1 year | CNY 6 / year | `pro` |
| Max | `com.yuyuan.assetledger.max.yearly` | 1 year | CNY 24 / year | `max` |

The purchase UI must display the localized StoreKit price returned by App Store
or StoreKit testing. The CNY prices above are App Store Connect configuration
targets, not hardcoded client display prices.

Max is a higher entitlement tier and includes Pro capability. If Max-specific
features are not implemented yet, the app must not claim specific unavailable
Max features. It may expose the tier and reserve it for later advanced
capabilities.

Backend product allowlists for new production verification should contain only:

- `com.yuyuan.assetledger.pro.yearly`
- `com.yuyuan.assetledger.max.yearly`

## Stable Identity

The app generates a UUID v4 `appAccountToken` and stores it in
`SharedPreferences` under `subscription.appAccountToken`.

The same value is used in three places:

- `PurchaseParam.applicationUserName` when starting a purchase.
- `restorePurchases(applicationUserName: appAccountToken)` when restoring.
- Backend verification requests, as documented below.

This token is an app-install stable identifier. It is not a fabricated
entitlement and does not unlock Pro or Max locally. The backend must still
verify Apple transaction data before returning an active entitlement.

## Endpoint Requirements

All endpoint paths are relative to `APPLE_IAP_VERIFICATION_BASE_URL`. Requests
and responses are JSON. The backend must be reachable over public HTTPS and must
support both Apple Sandbox and Production environments because App Review uses
sandbox transactions.

### POST `/iap/apple/verify-purchase`

Purchase and restore flows call this endpoint once per StoreKit transaction.

Request body:

```json
{
  "platform": "ios",
  "productId": "com.yuyuan.assetledger.pro.yearly",
  "purchaseId": "Apple transaction id when exposed by Flutter",
  "transactionDate": "1700000000000",
  "serverVerificationData": "App Store receipt/JWS payload from Flutter",
  "localVerificationData": "Local verification payload from Flutter",
  "source": "app_store",
  "status": "purchased",
  "appAccountToken": "00000000-0000-4000-8000-000000000000",
  "bundleId": "com.yuyuan.assetledger"
}
```

Required fields from the app:

- `platform`
- `productId`
- `serverVerificationData`
- `localVerificationData`
- `source`
- `status`
- `appAccountToken`

Optional fields:

- `purchaseId`
- `transactionDate`
- `bundleId`

Backend handling notes:

1. Validate `bundleId`, `productId`, `source`, and `appAccountToken`.
2. Verify `serverVerificationData` with App Store Server API or JWS
   verification. Do not trust `transactionDate` as authoritative.
3. Accept both Sandbox and Production Apple environments.
4. Persist the verified entitlement keyed by `appAccountToken`.

### GET `/iap/apple/current-entitlement`

The app calls this on startup and when entering subscription surfaces.

Query parameters:

- `appAccountToken`: the stable token previously sent with purchase and restore
  requests.

Example:

```text
GET /iap/apple/current-entitlement?appAccountToken=00000000-0000-4000-8000-000000000000
```

## Response

Both endpoints return the same shape:

```json
{
  "outcome": "verifiedActivePro",
  "entitlementTier": "pro",
  "productId": "com.yuyuan.assetledger.pro.yearly",
  "appAccountToken": "00000000-0000-4000-8000-000000000000",
  "originalTransactionId": "2000000000000000",
  "expiresAt": "2026-05-21T00:00:00.000Z",
  "environment": "Sandbox"
}
```

`outcome` must be one of:

Unlocking outcomes:

- `verifiedActivePro`
- `verifiedActiveMax`
- `verifiedGracePeriodPro`
- `verifiedGracePeriodMax`

Non-unlocking outcomes:

- `billingRetry`
- `expired`
- `revoked`
- `verificationFailed`
- `verificationUnavailable`
- `noActiveEntitlement`

`entitlementTier` must be one of:

- `pro`
- `max`
- `none`

`expiresAt` is optional. When present, it must be ISO-8601 parseable by
`DateTime.parse`; otherwise the client treats the response as
`verificationFailed`.

## Client Semantics

- `verifiedActivePro` and `verifiedGracePeriodPro` unlock Pro.
- `verifiedActiveMax` and `verifiedGracePeriodMax` unlock Max and include Pro
  capability.
- `billingRetry`, `expired`, `revoked`, `verificationFailed`, and
  `noActiveEntitlement` do not unlock Pro or Max.
- Non-2xx responses and `verificationUnavailable` do not complete the StoreKit
  transaction. StoreKit can redeliver the purchase after backend recovery.
- `verificationFailed` completes the transaction and does not unlock anything.
- Current-entitlement sync falls back to the local entitlement cache when the
  backend is unavailable.

## Backend Implementation Checklist

The backend must implement this outside the Flutter repository:

1. Accept `POST /iap/apple/verify-purchase`.
2. Validate required fields and reject unknown products.
3. Verify Apple transaction payloads against App Store Server API or JWS
   verification.
4. Support both Sandbox and Production Apple environments.
5. Persist `entitlementTier`, `originalTransactionId`, latest transaction ID,
   `productId`, environment, expiration/revocation state, latest outcome, and
   update timestamp keyed by `appAccountToken`.
6. Accept `GET /iap/apple/current-entitlement?appAccountToken=...`.
7. Return only the response fields and `outcome` values listed above.
8. Return `verificationUnavailable` or a non-2xx response for temporary backend
   outages so the app does not close the transaction.
9. Return `verificationFailed` only for definitive invalid purchases.
10. Add backend unit tests for Pro active, Max active, Pro/Max grace period,
    billing retry, expired, revoked, invalid purchase, missing token, unknown
    token, and Apple outage cases.

Pseudo handler shape:

```text
POST /iap/apple/verify-purchase
  parse request
  reject missing appAccountToken/productId/serverVerificationData
  verify productId is in the Pro/Max yearly allowlist
  verify Apple payload against Sandbox or Production
  map Apple subscription state and productId to outcome + entitlementTier
  persist entitlement by appAccountToken
  return { outcome, entitlementTier, productId, appAccountToken,
           originalTransactionId, expiresAt, environment }

GET /iap/apple/current-entitlement
  read appAccountToken query
  reject missing appAccountToken without returning any entitlement
  load latest entitlement for token
  refresh with App Store Server API if needed
  return { outcome, entitlementTier, productId, appAccountToken,
           originalTransactionId, expiresAt, environment }
```

## Sandbox Integration Checklist

1. Configure App Store Connect with Pro yearly and Max yearly in the same
   subscription group, with Max at the higher subscription level.
2. Build the app with `dart_defines/production.json` pointed at the
   sandbox-ready backend.
3. Start a Pro and Max sandbox purchase.
4. Confirm the backend receives the same `appAccountToken` in purchase and
   current-entitlement requests.
5. Confirm active Pro purchases unlock Pro.
6. Confirm active Max purchases unlock Max and include Pro capability.
7. Simulate backend outage and confirm the client leaves the StoreKit
   transaction unfinished.
8. Simulate definitive invalid verification and confirm the client completes
   the transaction without unlocking Pro or Max.
