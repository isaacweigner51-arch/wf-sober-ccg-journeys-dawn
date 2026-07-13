# WF Sober CCG v0.1.10 — Owner PIN Access

- Secret menu still opens after seven taps on the WF Sober CCG logo.
- Replaced the owner/tester access-token prompt with a four-digit owner PIN.
- PIN access grants Owner tools for the current app session only.
- Signing out or restarting the app locks the tools again.
- The PIN is compared using a SHA-256 hash rather than stored as visible plain text.
