# WF Sober CCG v0.3.5

## Battle controls
- Removed action menus from card inspection.
- Drag hand cards directly to the follower or Recovery Skill row to play them.
- Drag friendly followers directly to an enemy follower or leader to attack.
- Hold a card for 0.45 seconds without moving to inspect it.
- Moving beyond the drag threshold cancels inspection immediately.
- Card details appear in a solid compact side panel, not a transparent full-screen overlay.
- The detail panel contains no Play or Attack buttons and does not change game state.

## Launch and accounts
- Added a dedicated opening screen before the main menu.
- Players may sign in with email/password, create an account, or continue as a guest.
- Account authentication uses the configured Supabase project.
- Existing multiplayer sessions reuse the authenticated account instead of creating another anonymous session.
