extends Node

signal update_available(version: String, notes: String, required: bool)
signal update_check_finished(has_update: bool)

const LOCAL_MANIFEST := "res://data/version_manifest.json"
var current_version := "0.7.2"
var remote_manifest_url := ""

func _ready() -> void:
    var f := FileAccess.open(LOCAL_MANIFEST, FileAccess.READ)
    if f != null:
        var parsed = JSON.parse_string(f.get_as_text())
        if parsed is Dictionary:
            current_version = str(parsed.get("version", current_version))
            remote_manifest_url = str(parsed.get("remote_manifest_url", ""))

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
                    update_available.emit(latest, str(parsed.get("notes", "A new update is available.")), bool(parsed.get("required", false)))
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
