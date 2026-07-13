# v0.5.5 — Recovery Home Music

- Added a persistent `AudioManager` autoload.
- Added `assets/audio/home_recovery_theme.ogg`.
- Music begins on the account/login screen and continues across Home, Deck Builder, Collection, Store, Story Mode, and menu screens.
- The track loops continuously and cannot be deleted by `clear_screen()`.
- Music fades out when a battle scene starts so battle audio can take over.
- Fixed the previous implementation where the AudioStreamPlayer was created under the menu and then destroyed during screen rebuilds.
