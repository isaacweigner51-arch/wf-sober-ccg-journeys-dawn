# WF Sober CCG v0.2.0 — Supabase Online Alpha

## Included
- Replaced the local `ws://127.0.0.1:8765` relay with the production Supabase project.
- Anonymous Supabase sign-in from Godot.
- Host Match calls `create_private_room()`.
- Join Match calls `join_private_room(code)`.
- Room and ready-state polling through Supabase REST.
- Match events are written to `match_actions` and received by the other phone.
- Existing online battle snapshots, Second Chance, turns, attacks, evolution, Momentum, and match-end messages use the Supabase transport.
- Android INTERNET permission remains enabled.
- Platinum and Signature Platinum crafting enabled for 4,500 Recovery Vials.

## Supabase requirements
The project must have anonymous authentication enabled, the multiplayer tables and RPC functions installed, and these tables included in `supabase_realtime`:
- `game_rooms`
- `room_members`
- `match_actions`

## Testing
Use two separate Android devices on different networks. Host on one device, join with the six-digit code on the other, and complete a full match before treating online play as production-ready.
