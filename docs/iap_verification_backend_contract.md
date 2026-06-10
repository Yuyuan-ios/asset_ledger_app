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
- A build with neither define keeps the purchase flow disabled and uses
  `PendingServerSubscriptionVerificationRepository`.

## Stable Identity

The app generates a UUID v4 `appAccountToken` and stores it in
`SharedPreferences` under `subscription.appAccountToken`.

The same value is used in three places:

- `PurchaseParam.applicationUserName` when starting a purchase.
- `restorePurchases(applicationUserName: appAccountToken)` when restoring.
- Backend verification requests, as documented below.

This token is an app-install stable identifier. It is not a fabricated
entitlement and does not unlock Pro locally. The backend must still verify
Apple transaction data before returning an active entitlement.

## Endpoints

All endpoint paths are relative to `APPLE_IAP_VERIFICATION_BASE_URL`.

### POST `/iap/apple/verify-purchase`

Request body:

```json
{
  "platform": "ios",
  "productId": "com.yuyuan.assetledger.pro.monthly",
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

### GET `/iap/apple/current-entitlement`

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
  "outcome": "verifiedActiveMonthly",
  "productId": "com.yuyuan.assetledger.pro.monthly",
  "expiryDate": "2026-05-21T00:00:00.000Z"
}
```

`outcome` must be one of:

- `verifiedActiveMonthly`
- `verifiedActiveYearly`
- `verifiedGracePeriod`
- `verifiedBillingRetry`
- `verifiedInactive`
- `verifiedExpired`
- `verifiedRevoked`
- `verificationFailed`
- `verificationUnavailable`

Legacy aliases currently accepted by the app:

- `expired` maps to `verifiedExpired`
- `revoked` maps to `verifiedRevoked`
- `inactive` maps to `verifiedInactive`

## Client Semantics

- Non-2xx responses and `verificationUnavailable` do not complete the StoreKit
  transaction. StoreKit can redeliver the purchase after backend recovery.
- `verificationFailed` completes the transaction and does not unlock Pro.
- Verified active monthly/yearly and grace period unlock Pro.
- Billing retry is verified but does not unlock Pro in the current app status
  mapping.

## Backend Implementation Checklist

The backend must implement this outside the Flutter repository:

1. Accept `POST /iap/apple/verify-purchase`.
2. Validate `bundleId`, `productId`, `source`, and `appAccountToken`.
3. Verify `serverVerificationData` with App Store Server API or JWS
   verification.
4. Support both Sandbox and Production Apple environments.
5. Persist the verified entitlement keyed by `appAccountToken`.
6. Accept `GET /iap/apple/current-entitlement?appAccountToken=...`.
7. Return only the response fields and `outcome` values listed above.
8. Return `verificationUnavailable` or a non-2xx response for temporary backend
   outages so the app does not close the transaction.
9. Return `verificationFailed` only for definitive invalid purchases.
10. Add backend unit tests for active, expired, revoked, grace period, billing
    retry, invalid, and Apple outage cases.

Pseudo handler shape:

```text
POST /iap/apple/verify-purchase
  parse request
  reject missing appAccountToken/productId/serverVerificationData
  verify Apple payload against Sandbox or Production
  map Apple subscription state to outcome
  persist entitlement by appAccountToken
  return { outcome, productId, expiryDate }

GET /iap/apple/current-entitlement
  read appAccountToken query
  load latest entitlement for token
  refresh with App Store Server API if needed
  return { outcome, productId, expiryDate }
```

Sandbox integration checklist:

1. Build the app with `dart_defines/production.json` pointed at the sandbox-ready
   backend.
2. Start a monthly and yearly sandbox purchase.
3. Confirm the backend receives the same `appAccountToken` in purchase and
   current-entitlement requests.
4. Confirm active purchases unlock Pro after verified responses.
5. Simulate backend outage and confirm the client leaves the StoreKit
   transaction unfinished.
6. Simulate definitive invalid verification and confirm the client completes
   the transaction without unlocking Pro.
