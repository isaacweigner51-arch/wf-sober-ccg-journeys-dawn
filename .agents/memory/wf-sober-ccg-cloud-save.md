---
name: wf-sober-ccg cloud save architecture
description: How player profile data is persisted to the cloud via Supabase and restored on login.
---

## The pattern

- All profile data lives locally in `user://journeys_dawn_profile.cfg` (ConfigFile).
- `network_manager.gd` has `upload_save_data(data: Dictionary)` which PATCHes `player_profiles.save_data` (JSONB column) on the player's Supabase row.
- `_load_account_profile()` SELECTs `save_data` alongside the normal fields; emits `cloud_save_loaded(data)` **before** `account_authenticated` fires.
- `menu.gd` handles `cloud_save_loaded` → `_apply_cloud_profile(data)` writes cloud dict into the local CFG → `load_profile()` re-reads it so in-memory state is fresh by the time the home screen renders.
- Every `save_profile()` call ends with `_queue_cloud_upload.call_deferred()` — fire-and-forget async PATCH.

## Required Supabase SQL (must be run once by the user)

```sql
ALTER TABLE player_profiles ADD COLUMN IF NOT EXISTS save_data JSONB;
```

Until this column exists, uploads fail silently (PATCH returns 400 and the game continues normally).

## Profile upsert on new accounts

Previously, email-signup accounts had no `player_profiles` row (only anonymous signups got one via a DB trigger). Fixed: `_load_account_profile()` now detects an empty SELECT result and immediately POSTs a new row with `resolution=merge-duplicates` so the row always exists after first login.

**Why:** Without the row, `save_data` PATCH would create no record and cloud save would silently do nothing every session.
