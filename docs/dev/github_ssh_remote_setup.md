# GitHub SSH Remote Setup

## 1. Background

This repository previously failed to push through the HTTPS remote because the
local Git credential helper was unavailable:

```text
git: 'credential-osxkeychain' is not a git command
fatal: could not read Username for 'https://github.com': Device not configured
```

Use the SSH remote for this repository to avoid HTTPS credential-helper
failures.

Current origin:

```text
git@github.com:Yuyuan-ios/asset_ledger_app.git
```

## 2. Recommended SSH Key

Recommended key path:

```text
~/.ssh/id_ed25519_github_asset_ledger_app
```

Record only the path. Do not record the private key, public key text, tokens,
or secrets in repository files.

## 3. Check Remote

Run:

```bash
git remote -v
```

Expected:

```text
origin  git@github.com:Yuyuan-ios/asset_ledger_app.git (fetch)
origin  git@github.com:Yuyuan-ios/asset_ledger_app.git (push)
```

## 4. Test GitHub SSH Connection

Run:

```bash
ssh -T git@github.com
```

Success looks like:

```text
Hi <username>! You've successfully authenticated, but GitHub does not provide shell access.
```

If the command returns `Permission denied (publickey)`, add the matching
`.pub` public key to GitHub.

Do not output or copy the private key. Copy only the `.pub` public key when
adding a key to GitHub.

## 5. Temporary Push When ssh-agent Is Unavailable

If the current shell session cannot find or use `ssh-agent`, push with an
explicit identity for that command:

```bash
GIT_SSH_COMMAND='ssh -i ~/.ssh/id_ed25519_github_asset_ledger_app -o IdentitiesOnly=yes' git push origin develop
```

This does not write a token into the Git remote URL. It is suitable when the
current shell session cannot access `ssh-agent`.

Do not copy private key contents into the command line or into documentation.

## 6. Set origin to SSH

Only run this after confirming the repository is
`Yuyuan-ios/asset_ledger_app`:

```bash
git remote set-url origin git@github.com:Yuyuan-ios/asset_ledger_app.git
```

Do not write a GitHub token into the remote URL.

## 7. Forbidden Actions

- Do not use an HTTPS remote that contains a token.
- Do not write a GitHub token into the remote URL.
- Do not commit any file from `~/.ssh`.
- Do not `cat` a private key.
- Do not write a private key, token, or secret into README files, scripts,
  logs, or issues.
- If a push is rejected and asks for rebase or merge, do not force push. Stop
  and review the divergence first.

## 8. Common Failures

`git: 'credential-osxkeychain' is not a git command`

Use the SSH remote, or repair the macOS Git credential helper.

`fatal: could not read Username for 'https://github.com'`

Check whether `origin` is still an HTTPS remote.

`Permission denied (publickey)`

Confirm that GitHub has the matching `.pub` public key.

`ssh-agent unavailable`

Use `GIT_SSH_COMMAND` with the recommended key path for a temporary push.
