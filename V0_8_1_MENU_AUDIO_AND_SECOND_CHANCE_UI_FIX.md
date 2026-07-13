# v0.8.1 Menu Audio and Second Chance UI Fix

- Persistent menu music player now self-initializes before every play request.
- Master audio bus is unmuted and restored if an old saved setting left it effectively silent.
- Menu playback is deferred one frame for reliable Android audio-driver startup.
- Added fallback to the known-working OGG home track if the long WAV cannot be loaded.
- Second Chance card buttons now clip all child visuals.
- Card artwork is constrained to a fixed art viewport and uses aspect-covered rendering.
- Removed the oversized texture spill that covered adjacent cards and the confirmation controls.
