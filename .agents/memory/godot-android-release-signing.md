---
name: Godot Android release signing without storing secrets in files
description: How to wire a real Play Store release keystore for a Godot 4 project without ever writing the password into a tracked (or even untracked) file.
---

Godot 4's Android exporter supports environment-variable overrides for every
keystore field, applied at export time regardless of what's saved in
`export_presets.cfg`:

- `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`
- `GODOT_ANDROID_KEYSTORE_RELEASE_USER`
- `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`

(and the `_DEBUG_` equivalents). Source: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html#environment-variables

**Why this matters:** the release keystore is the one credential Google Play
uses to trust app updates as coming from the same developer — it can't be
rotated or recovered if lost/leaked. Godot's own editor UI stores the release
password in `export_presets.cfg` in plaintext by default, which is unsafe in
any repo that gets pushed to a remote (e.g. GitHub). Using the env var
override means the password only ever needs to exist as a platform secret
(Replit secret), never in `export_presets.cfg`, never in an
`export_credentials.cfg`, never in git history at all.

**How to apply:** generate the keystore with `keytool` (needs a JDK — not
installed by default in this sandbox, install via `jdk17` system dependency).
`keytool` requires both `-storepass` and `-keypass` to be at least 6 chars,
but note Godot's own docs say the keystore password and key password
"currently have to be the same" for its exporter to work — request a single
password value from the user for both roles rather than two independent
ones. Put the *path* and *user/alias* (non-secret) into `export_presets.cfg`
tracked in git; gitignore the actual `.jks` keystore file; pass the password
only via the `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD` env var sourced from a
Replit secret at export time (e.g. in a small build script), never written
to disk.
