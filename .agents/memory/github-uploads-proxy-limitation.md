---
name: GitHub uploads.github.com proxy limitation
description: The Replit GitHub connector's proxyFetch only authenticates api.github.com — release asset uploads go to uploads.github.com and get 404 without auth.
---

## Rule

The Replit GitHub connector's `createProxyFetch('github')` only injects Authorization headers for `api.github.com`. Release asset uploads must go to `uploads.github.com` — a different domain the proxy does not cover. Calls to `uploads.github.com` via proxyFetch return 404 (GitHub's unauthenticated response for upload endpoints).

**Why:** The connector proxy is domain-scoped. `api.github.com` and `uploads.github.com` are separate services; the proxy only covers the former.

**How to apply:** To upload GitHub release assets from this environment, use a real PAT (with `repo` scope) stored as a Replit Secret (`GITHUB_PAT`), then call `curl` directly:
```bash
curl -H "Authorization: token $GITHUB_PAT" \
     -H "Content-Type: application/zip" \
     --data-binary @file.zip \
     "https://uploads.github.com/repos/OWNER/REPO/releases/RELEASE_ID/assets?name=file.zip"
```

Also: `gh auth login --with-token` fails if the PAT lacks `read:org` scope — curl is the more reliable fallback.

## Bonus: workflow scope

The built-in Replit GitHub connector token has scopes: `read:org, read:project, read:user, repo, user:email`. It does NOT have `workflow`. Pushing `.github/workflows/` files via gitPush or the Git Data API returns PUSH_REJECTED. Use the GITHUB_PAT (which the user creates with `workflow` scope) and a short-lived `git remote set-url` to push workflow files, then reset the remote URL.
