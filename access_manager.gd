extends Node

signal role_changed(role: String)
signal authentication_finished(success: bool, message: String)

const ROLE_PLAYER := "player"
const ROLE_TESTER := "tester"
const ROLE_OWNER := "owner"
const CONFIG_PATH := "res://data/live_config.json"

var current_role: String = ROLE_PLAYER
var access_token: String = ""
var authenticated_account_id: String = ""
var _request: HTTPRequest
var _pending_token := ""

func _ready() -> void:
    _request = HTTPRequest.new()
    add_child(_request)
    _request.request_completed.connect(_on_request_completed)

func role_at_least(required_role: String) -> bool:
    var ranks := {ROLE_PLAYER: 0, ROLE_TESTER: 1, ROLE_OWNER: 2}
    return int(ranks.get(current_role, 0)) >= int(ranks.get(required_role, 99))


func apply_authenticated_role(role: String, token: String, account_id: String) -> void:
    role = role.to_lower()
    if role not in [ROLE_PLAYER, ROLE_TESTER, ROLE_OWNER]:
        role = ROLE_PLAYER
    current_role = role
    access_token = token
    authenticated_account_id = account_id
    role_changed.emit(current_role)

func sign_out() -> void:
    current_role = ROLE_PLAYER
    access_token = ""
    authenticated_account_id = ""
    role_changed.emit(current_role)

func authenticate(pin: String) -> void:
    pin = pin.strip_edges()
    if pin.is_empty():
        authentication_finished.emit(false, "Enter the 4-digit owner PIN.")
        return
    var pin_hash := pin.sha256_text()
    const OWNER_PIN_HASH := "b98f7dad337a57c1b9bdb2e054ef47a059b1a5a4e7587274925c090137b5436a"
    if pin_hash != OWNER_PIN_HASH:
        authentication_finished.emit(false, "Incorrect owner PIN.")
        return
    access_token = "local_owner_session"
    authenticated_account_id = "local_owner"
    current_role = ROLE_OWNER
    role_changed.emit(current_role)
    authentication_finished.emit(true, "Owner tools unlocked for this session.")

func _load_live_config() -> Dictionary:
    if not FileAccess.file_exists(CONFIG_PATH):
        return {}
    var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
    if file == null:
        return {}
    var parsed = JSON.parse_string(file.get_as_text())
    return parsed if parsed is Dictionary else {}

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
        authentication_finished.emit(false, "Access verification failed.")
        return
    var parsed = JSON.parse_string(body.get_string_from_utf8())
    if not parsed is Dictionary:
        authentication_finished.emit(false, "The access service returned an invalid response.")
        return
    var allowed := bool(parsed.get("allowed", false))
    var role := str(parsed.get("role", ROLE_PLAYER)).to_lower()
    if not allowed or role not in [ROLE_TESTER, ROLE_OWNER]:
        authentication_finished.emit(false, "This account is not authorized for test tools.")
        return
    access_token = _pending_token
    authenticated_account_id = str(parsed.get("account_id", ""))
    current_role = role
    role_changed.emit(current_role)
    authentication_finished.emit(true, "Authenticated as %s." % role.capitalize())
