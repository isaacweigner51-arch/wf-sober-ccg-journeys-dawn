---
name: Connector stuck not_setup despite active account
description: A connector (e.g. ElevenLabs) can appear "active"/installed in the workspace's Integrations settings, yet searchIntegrations keeps reporting status "not_setup" and every ProposeIntegration attempt reopens the same OAuth/setup dialog with the Connect button disabled.
---

Observed with the ElevenLabs connector on a Godot desktop-game project: user confirmed
via Replit's own Integrations panel that ElevenLabs was "installed and active," but
`searchIntegrations({ query: "elevenlabs" })` continued to return
`{ integrationType: "connector", status: "not_setup" }` no matter how many times
`ProposeIntegration` was called. The user described the connect dialog as showing
"Use Replit default configurations" pre-selected with the Connect button permanently
disabled — i.e. the OAuth handshake never completes, so the platform backend never
flips the connector to a bound `connection`.

**Why:** This is a platform-side state mismatch, not something fixable by retrying
`ProposeIntegration` or asking the user to re-click connect. Repeated retries just
reopen the same broken dialog and burn the user's patience/turns for zero effect.

**How to apply:** If `ProposeIntegration` is declined/cancelled 2+ times in a row for
the same connector AND the user reports the integration already looks "active" in
their account/workspace settings, stop retrying immediately. Tell the user plainly
what status the backend reports vs. what they see, and point them to contact Replit
support with the specific symptom (e.g. "dialog has default config selected, Connect
button disabled, backend still says not_setup"). Offer the non-connector fallback
(e.g. user-supplied files) instead of looping.
