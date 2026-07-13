# WF Sober CCG v0.7 Mobile Update Foundation

- Landscape Android layout based on the existing 1280x720 board.
- Touch input is translated to mouse input for existing controls.
- Long-press any visible card to open its full card/effect view.
- Larger on-card info buttons for phone and tablet use.
- Stable Android package ID: `com.walkingfree.ccg.journeysdawn`.
- Version code 7 / version name 0.7.0 for future Play Store updates.
- Player saves remain under `user://` and are preserved between app updates.
- Local version manifest and UpdateManager are included. Add a hosted JSON URL to `data/version_manifest.json` when the update endpoint is ready.
- Android export preset included; configure your signing keystore before release.
