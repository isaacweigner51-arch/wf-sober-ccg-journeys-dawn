# WF Sober CCG v0.3.8 — Auth Session & Account Role Fix

- Validates saved Supabase sessions on launch.
- Refreshes expired access tokens with the stored refresh token.
- Retrieves the authenticated user when a token response omits the nested user object.
- Loads `player_profiles` after login and applies `player`, `tester`, or `owner` access.
- Owner tools are enabled only when Supabase returns `app_role = owner`.
- Tester accounts are recognized without receiving owner controls.
- Stores the refreshed access token, refresh token, user ID, role, and profile locally.
- Clears unusable sessions and returns the player to sign-in instead of remaining stuck.
- Version updated to 0.3.8.
