# WF Sober CCG v0.3.7 — Account Session Fix

- Correctly handles Supabase sign-up responses that return a user without an active session.
- Automatically signs in after account creation when email confirmation is disabled.
- Shows a clear confirmation-required message when email confirmation is enabled.
- Saves access token, refresh token, and user ID locally for session persistence.
- Restores the saved session on app launch.
- Keeps anonymous guest sessions persistent on the device.
