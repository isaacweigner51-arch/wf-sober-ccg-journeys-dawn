# v0.8.4 — Audio and Card Art Recovery

- Moved home music playback entirely to the persistent AudioManager autoload.
- Fixed clear_screen() deleting the local menu music player during every UI rebuild.
- Added standard 44.1 kHz stereo Ogg versions of home and dynamic battle music.
- Battle music now falls back to the prior WAV resources if an Ogg resource fails.
- Removed the ResourceLoader.exists() gate that rejected valid JPG card resources.
- Second Chance and all CardView instances now resolve full card artwork by ID or card name.
- Added direct JPG/PNG buffer loading as an editor/source fallback.
