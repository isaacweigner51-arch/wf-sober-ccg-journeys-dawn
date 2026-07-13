---
name: GitHub connector credential outage
description: listConnections('github') returning an empty array even immediately after fresh authorization/re-authorization — a platform-side credential-proxy issue, not a slug or auth mistake.
---

Observed a session where `listConnections('github')` inside a `"use impure"` CodeExecution block consistently returned `[]`, even though:
- `searchIntegrations` reported the connection `status: "added"`.
- The connector slug was confirmed correct (`github`) via `viewIntegration`.
- The connection was re-authorized twice via `ProposeIntegration` (once re-binding the existing connection, once after fully removing and re-adding a brand-new connection with `addIntegration` + `ProposeIntegration`), and checked immediately after each acceptance.

**Why:** The query-integration-data skill already documents this as a known failure mode — "withheld credentials" — where the credential proxy can serve nothing for a given Repl/session even though the account-level connection is genuinely valid. Re-authorizing does not always fix it within the same session.

**How to apply:** If `listConnections(slug)` returns `[]` after confirming (a) the slug is right and (b) `searchIntegrations` status is `added`, retry only a couple of times, and try one re-authorization cycle if the user wants (ProposeIntegration on the existing connection, or addIntegration+ProposeIntegration on a fresh one). If it's still empty after that, stop — surface the outage to the user plainly rather than looping. Do not keep re-proposing the integration; it wastes the user's time on a path that isn't fixable client-side. Native `git push` over HTTPS from the shell is a separate, unrelated credential path (also commonly blocked with "Invalid username or token") and retrying it does not diagnose or fix the connector issue.

Fallback delivery options when this blocks pushing committed local work to GitHub: ask the user whether to attempt a Replit project zip export, or leave the work committed locally (confirm the exact local commit SHA/branch so it's easy to resume) and retry the GitHub push in a later session.
