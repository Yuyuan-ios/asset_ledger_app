# Version Policy Deployment Assets

These files describe static delivery of the FleetLedger version policy. They do
not contain production secrets or live policy values.

## ECS File Placement

Create a static policy directory on ECS:

```bash
sudo install -d -m 0755 /opt/fleet-ledger-version-policy
sudo install -m 0644 version-policy.json /opt/fleet-ledger-version-policy/version-policy.json
```

The repository sample is `server/version_policy/version-policy.example.json`.
Copy it as a starting point only; production values are maintained outside the
repository by operations.

## Nginx Include

Copy `deploy/nginx.conf.example` into an nginx snippet, for example:

```bash
sudo install -m 0644 deploy/nginx.conf.example /etc/nginx/snippets/fleet-ledger-version-policy.conf
```

Then include it in the existing HTTPS server block that already serves
sync/backup on the main API host:

```nginx
include /etc/nginx/snippets/fleet-ledger-version-policy.conf;
```

Run `sudo nginx -t` and reload nginx after installing or changing the nginx
snippet. Later JSON-only policy updates are static file replacements and do not
need nginx reloads.

## Verification

Check that the endpoint is reachable and returns JSON:

```bash
curl -i https://<host>/app/version-policy.json
python3 -m json.tool /opt/fleet-ledger-version-policy/version-policy.json
python3 deploy/smoke_test.py https://<host>/app/version-policy.json
```

Expected result:

- HTTP status is `200`.
- Response is parseable JSON.
- Top-level `ios` and `android` keys exist.
- Each platform has `latestVersion`, `minSupportedVersion`, and `updateUrl`.
- Android has all seven `channelUrls` keys:
  `xiaomi`, `huawei`, `oppo`, `vivo`, `tencent`, `official`, `play`.

If the URL is unreachable, `smoke_test.py` prints a skip message and exits
successfully so it can be used before DNS/firewall rollout is complete.
