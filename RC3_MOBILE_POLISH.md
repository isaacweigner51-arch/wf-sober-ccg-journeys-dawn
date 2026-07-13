# WF Sober CCG — RC3 Mobile Polish

This release is intended for Android phone and tablet testing.

## Changes
- Forces sensor-landscape orientation, allowing either landscape direction.
- Uses expanded aspect scaling so wide phones and tablets fill the screen instead of shrinking into a portrait-sized box.
- Enables Android immersive fullscreen.
- Raises mobile UI and card text sizes for readability.
- Enlarges key battle touch targets, leader interaction areas, and card information buttons.
- Keeps mouse and desktop controls intact.
- Android version code increased to 9 and output renamed `WF_Sober_CCG_RC3_Mobile.apk`.

## Test checklist
1. Launch while holding the phone vertically; the game should rotate to landscape.
2. Rotate the phone 180 degrees; the game should use the opposite landscape direction.
3. Check menu text, End Turn, leaders, cards, card inspection, and hand reordering.
4. Test on a tablet if available.
