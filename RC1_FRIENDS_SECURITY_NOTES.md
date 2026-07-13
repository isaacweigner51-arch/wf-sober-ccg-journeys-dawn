# WF Sober CCG — RC1 Friends Edition

## Secure roles
- Player: normal game access.
- Tester: temporary sandbox tools only.
- Owner: tester tools plus explicitly marked owner actions.
- No developer password is embedded in the project or APK.
- The hidden entry is seven taps on the Walking Free logo.
- Access requires a server-issued token verified by `access_verify_url` in `data/live_config.json`.
- The server must return JSON such as:
  `{"allowed":true,"role":"owner","account_id":"..."}`
- When the URL is blank, privileged access remains disabled.

## Important
Before distributing the APK, configure an HTTPS endpoint that validates your signed-in account and returns the authorized role. Keep permanent economy-changing commands server-authoritative for a public release.
