#!/usr/bin/env bash
# Builds the signed Android release AAB for Play Store upload.
#
# Requires (not installed in this Replit sandbox):
#   - Android SDK (Platform-Tools 35+, Build-Tools, Platform for target API)
#   - Gradle (via the Godot gradle build system)
#   - Godot 4 export templates for Android
#
# Signing credentials are never read from a file -- Godot 4 supports
# overriding keystore settings via environment variables at export time
# (see https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html#environment-variables),
# so the release password only ever exists as the ANDROID_KEYSTORE_PASSWORD
# Replit secret, never written to export_presets.cfg or any tracked file.
#
# Usage: bash scripts/build_android_release.sh [output_path]

set -euo pipefail

OUTPUT_PATH="${1:-build/WF_Sober_CCG_release.aab}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -z "${ANDROID_KEYSTORE_PASSWORD:-}" ]; then
  echo "ANDROID_KEYSTORE_PASSWORD is not set. Add it via Replit Secrets first." >&2
  exit 1
fi

if [ ! -f "$PROJECT_DIR/android_keystore/release.jks" ]; then
  echo "Release keystore not found at android_keystore/release.jks" >&2
  exit 1
fi

mkdir -p "$(dirname "$PROJECT_DIR/$OUTPUT_PATH")"

GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$PROJECT_DIR/android_keystore/release.jks" \
GODOT_ANDROID_KEYSTORE_RELEASE_USER="wf_sober_release" \
GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$ANDROID_KEYSTORE_PASSWORD" \
godot4 --headless --path "$PROJECT_DIR" --export-release "Android" "$OUTPUT_PATH"

echo "Built $OUTPUT_PATH"
