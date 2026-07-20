extends Node

signal update_available(version: String, notes: String, required: bool)
signal update_check_finished(has_update: bool)

const LOCAL_MANIFEST := "res://data/version_manifest.json"

# ── Current-build metadata (populated from data/version_manifest.json) ────────
# To ship a new version:
#   1. Bump "version" in version_manifest.json to match export_presets.cfg.
#   2. Replace "sections" with that build's notes (see format below).
#   3. Done — the popup auto-shows once per new version; old notes are gone.
#
# "sections" format:
#   [
#     {
#       "category": "New Features",   ← one of the recognised categories (see
#       "items": ["...", "..."]          CATEGORY_STYLES in menu.gd for the list)
#     },
#     ...
#   ]
# ─────────────────────────────────────────────────────────────────────────────
var current_version    := "0.9.0"
var current_build_name := ""
var current_notes      := ""
var remote_manifest_url := ""

## Structured sections for the What's New popup.
## Each entry: { "category": String, "items": Array[String] }
var current_sections:       Array = []

## New cards introduced in this build.
## Each entry: { "id": String, "name": String, "class": String, "rarity": String }
var current_new_cards:      Array = []

## Teaser text for upcoming features.
var current_upcoming_events: Array = []

# Legacy flat lists — populated only when the manifest uses the old format
# (no "sections" key). Kept for backward compatibility.
var current_fixes:    Array = []
var current_features: Array = []

func _ready() -> void:
    var f := FileAccess.open(LOCAL_MANIFEST, FileAccess.READ)
    if f == null:
        return
    var parsed = JSON.parse_string(f.get_as_text())
    if not parsed is Dictionary:
        return

    current_version         = str(parsed.get("version",         current_version))
    current_build_name      = str(parsed.get("build_name",      ""))
    current_notes           = str(parsed.get("notes",           ""))
    remote_manifest_url     = str(parsed.get("remote_manifest_url", ""))
    current_new_cards       = parsed.get("new_cards",       [])
    current_upcoming_events = parsed.get("upcoming_events", [])

    if parsed.has("sections"):
        # ── New structured format ──────────────────────────────────────────
        current_sections = parsed.get("sections", [])
    else:
        # ── Legacy flat format: convert to sections on load ────────────────
        current_fixes    = parsed.get("fixes",    [])
        # The old JSON had a duplicated "features" key; take the last one
        # (the most complete one) by iterating raw.  JSON.parse_string gives
        # us only the last duplicate, which is what we want.
        current_features = parsed.get("features", [])

        if not current_features.is_empty():
            current_sections.append({
                "category": "New Features",
                "items":    current_features
            })
        if not current_fixes.is_empty():
            current_sections.append({
                "category": "Bug Fixes",
                "items":    current_fixes
            })

## Snapshot of what changed in the build currently installed.
## Menu code compares `version` against the last version it recorded seeing
## and only shows the popup when they differ.
func get_whats_new() -> Dictionary:
    return {
        "version":           current_version,
        "build_name":        current_build_name,
        "notes":             current_notes,
        "sections":          current_sections,
        "new_cards":         current_new_cards,
        "upcoming_events":   current_upcoming_events,
        # Legacy keys — still returned so any callers that read them directly
        # continue to work without changes.
        "fixes":             current_fixes,
        "features":          current_features,
    }

func check_for_updates() -> void:
    if remote_manifest_url.is_empty():
        update_check_finished.emit(false)
        return
    var request := HTTPRequest.new()
    add_child(request)
    request.request_completed.connect(func(_result, response_code, _headers, body):
        var has_update := false
        if response_code == 200:
            var parsed = JSON.parse_string(body.get_string_from_utf8())
            if parsed is Dictionary:
                var latest := str(parsed.get("version", current_version))
                has_update = _version_is_newer(latest, current_version)
                if has_update:
                    update_available.emit(
                        latest,
                        str(parsed.get("notes", "A new update is available.")),
                        bool(parsed.get("required", false))
                    )
        update_check_finished.emit(has_update)
        request.queue_free()
    )
    var err := request.request(remote_manifest_url)
    if err != OK:
        update_check_finished.emit(false)
        request.queue_free()

func _version_is_newer(candidate: String, installed: String) -> bool:
    var a := candidate.split(".")
    var b := installed.split(".")
    for i in range(max(a.size(), b.size())):
        var av := int(a[i]) if i < a.size() else 0
        var bv := int(b[i]) if i < b.size() else 0
        if av != bv:
            return av > bv
    return false
