extends Node

signal connected_to_service
signal disconnected_from_service(reason: String)
signal room_created(code: String)
signal room_joined(code: String)
signal lobby_updated(payload: Dictionary)
signal match_started(payload: Dictionary)
signal game_message(payload: Dictionary)
signal network_error(message: String)
signal account_authenticated(success: bool, message: String)
signal account_role_loaded(role: String, profile: Dictionary)

const SUPABASE_URL := "https://zlsbznebcmprfxngyogg.supabase.co"
const SUPABASE_KEY := "sb_publishable_U8LP7Qgg-2nZIfeb7CTp3g_YLQaOXAx"
const POLL_INTERVAL := 0.8

var room_code := ""
var room_id := ""
var role := ""
var connected := false
var connecting := false
var user_id := ""
var access_token := ""
var refresh_token := ""
var account_role := "player"
var account_profile: Dictionary = {}
const SESSION_PATH := "user://supabase_session.json"
var player_class := "Hope"
var player_deck_mode := "custom"
var last_action_id := 0
var poll_elapsed := 0.0
var request_busy := false
var match_start_sent := false
var battle_begin_sent := false
var last_lobby_signature := ""

func _ready() -> void:
    set_process(true)
    _restore_saved_session()

func configure(_url: String) -> void:
    # Kept for compatibility with older menu code. Supabase is now fixed to the
    # production project instead of accepting a local relay URL.
    pass


func continue_as_guest() -> void:
    if connected and not access_token.is_empty():
        account_authenticated.emit(true, "Guest session ready.")
        return
    connecting = true
    _authenticate_anonymously()

func sign_in_with_email(email: String, password: String) -> void:
    email = email.strip_edges()
    if email.is_empty() or password.length() < 6:
        account_authenticated.emit(false, "Enter a valid email and a password of at least 6 characters.")
        return
    connecting = true
    var result := await _request(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=password", {"email":email, "password":password}, false)
    _complete_account_auth(result, "Signed in.")

func create_account_with_email(email: String, password: String) -> void:
    email = email.strip_edges()
    if email.is_empty() or password.length() < 6:
        account_authenticated.emit(false, "Enter a valid email and a password of at least 6 characters.")
        return
    connecting = true
    var signup_result := await _request(HTTPClient.METHOD_POST, "/auth/v1/signup", {"email":email, "password":password}, false)
    if not signup_result.ok:
        connecting = false
        account_authenticated.emit(false, _error_text(signup_result))
        return

    var signup_data: Dictionary = signup_result.data if signup_result.data is Dictionary else {}
    if not str(signup_data.get("access_token", "")).is_empty():
        _complete_account_auth(signup_result, "Account created.")
        return

    # Some Supabase configurations return a user but no session after signup.
    # Attempt a normal password login immediately. This succeeds when email
    # confirmation is disabled and gives a clear message when it is required.
    var login_result := await _request(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=password", {"email":email, "password":password}, false)
    if login_result.ok:
        _complete_account_auth(login_result, "Account created and signed in.")
        return

    connecting = false
    var signup_user: Dictionary = signup_data.get("user", {}) if signup_data.get("user", {}) is Dictionary else {}
    if not str(signup_user.get("id", "")).is_empty():
        account_authenticated.emit(false, "Account created. Confirm your email, then return and press SIGN IN.")
    else:
        account_authenticated.emit(false, _error_text(login_result))

func _complete_account_auth(result: Dictionary, success_message: String) -> void:
    if not result.ok:
        connecting = false
        account_authenticated.emit(false, _error_text(result))
        return
    var data: Dictionary = result.data if result.data is Dictionary else {}
    access_token = str(data.get("access_token", ""))
    refresh_token = str(data.get("refresh_token", ""))
    var user: Dictionary = data.get("user", {}) if data.get("user", {}) is Dictionary else {}
    user_id = str(user.get("id", ""))

    # Some auth responses contain the session tokens but omit the nested user.
    # Resolve the authenticated user directly before treating the login as failed.
    if not access_token.is_empty() and user_id.is_empty():
        var user_result := await _request(HTTPClient.METHOD_GET, "/auth/v1/user", null, true)
        if user_result.ok and user_result.data is Dictionary:
            user_id = str(user_result.data.get("id", ""))

    if access_token.is_empty() or user_id.is_empty():
        connecting = false
        account_authenticated.emit(false, "Supabase returned no usable session. Check the password or email-confirmation setting.")
        return

    connected = true
    connecting = false
    _save_session()
    await _load_account_profile()
    account_authenticated.emit(true, success_message)

func validate_saved_session() -> void:
    if access_token.is_empty() or user_id.is_empty():
        account_authenticated.emit(false, "No saved account session.")
        return
    connecting = true
    var user_result := await _request(HTTPClient.METHOD_GET, "/auth/v1/user", null, true)
    if not user_result.ok and not refresh_token.is_empty():
        var refresh_result := await _request(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=refresh_token", {"refresh_token":refresh_token}, false)
        if refresh_result.ok:
            var data: Dictionary = refresh_result.data if refresh_result.data is Dictionary else {}
            access_token = str(data.get("access_token", ""))
            refresh_token = str(data.get("refresh_token", refresh_token))
            var refreshed_user: Dictionary = data.get("user", {}) if data.get("user", {}) is Dictionary else {}
            user_id = str(refreshed_user.get("id", user_id))
            _save_session()
            user_result = await _request(HTTPClient.METHOD_GET, "/auth/v1/user", null, true)
    if not user_result.ok:
        connecting = false
        clear_saved_session()
        account_authenticated.emit(false, "Your saved session expired. Please sign in again.")
        return
    connected = true
    connecting = false
    await _load_account_profile()
    account_authenticated.emit(true, "Welcome back.")

func _load_account_profile() -> void:
    account_role = "player"
    account_profile = {}
    if user_id.is_empty() or access_token.is_empty():
        account_role_loaded.emit(account_role, account_profile)
        return
    var path := "/rest/v1/player_profiles?select=user_id,display_name,app_role,recovery_vials&user_id=eq.%s&limit=1" % user_id.uri_encode()
    var result := await _request(HTTPClient.METHOD_GET, path, null, true)
    if result.ok and result.data is Array and not result.data.is_empty() and result.data[0] is Dictionary:
        account_profile = Dictionary(result.data[0])
        account_role = str(account_profile.get("app_role", "player")).to_lower()
    account_role_loaded.emit(account_role, account_profile)
    if Engine.has_singleton("AccessManager"):
        pass
    if get_node_or_null("/root/AccessManager") != null:
        get_node("/root/AccessManager").apply_authenticated_role(account_role, access_token, user_id)

func clear_saved_session() -> void:
    access_token = ""
    refresh_token = ""
    user_id = ""
    account_role = "player"
    account_profile = {}
    connected = false
    if FileAccess.file_exists(SESSION_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_PATH))
    if get_node_or_null("/root/AccessManager") != null:
        get_node("/root/AccessManager").sign_out()

func sign_out_account() -> void:
    clear_saved_session()
    account_authenticated.emit(false, "Signed out.")

func _save_session() -> void:
    var file := FileAccess.open(SESSION_PATH, FileAccess.WRITE)
    if file == null:
        return
    file.store_string(JSON.stringify({
        "access_token": access_token,
        "refresh_token": refresh_token,
        "user_id": user_id,
        "account_role": account_role,
        "account_profile": account_profile
    }))

func _restore_saved_session() -> void:
    if not FileAccess.file_exists(SESSION_PATH):
        return
    var file := FileAccess.open(SESSION_PATH, FileAccess.READ)
    if file == null:
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary):
        return
    var saved: Dictionary = parsed
    access_token = str(saved.get("access_token", ""))
    refresh_token = str(saved.get("refresh_token", ""))
    user_id = str(saved.get("user_id", ""))
    account_role = str(saved.get("account_role", "player"))
    account_profile = saved.get("account_profile", {}) if saved.get("account_profile", {}) is Dictionary else {}
    connected = not access_token.is_empty() and not user_id.is_empty()
    if connected and get_node_or_null("/root/AccessManager") != null:
        get_node("/root/AccessManager").apply_authenticated_role(account_role, access_token, user_id)

func connect_service(_url: String = "") -> void:
    if connected and not access_token.is_empty():
        connected_to_service.emit()
        return
    if connecting:
        return
    connecting = true
    _authenticate_anonymously()

func disconnect_service() -> void:
    connected = false
    connecting = false
    room_code = ""
    room_id = ""
    role = ""
    last_action_id = 0
    match_start_sent = false
    battle_begin_sent = false

func _process(delta: float) -> void:
    if not connected or room_id.is_empty() or request_busy:
        return
    poll_elapsed += delta
    if poll_elapsed >= POLL_INTERVAL:
        poll_elapsed = 0.0
        _poll_room_and_actions()

func _headers(authenticated := true, prefer := "") -> PackedStringArray:
    var h := PackedStringArray([
        "apikey: %s" % SUPABASE_KEY,
        "Content-Type: application/json"
    ])
    if authenticated and not access_token.is_empty():
        h.append("Authorization: Bearer %s" % access_token)
    if not prefer.is_empty():
        h.append("Prefer: %s" % prefer)
    return h

func _request(method: int, path: String, body: Variant = null, authenticated := true, prefer := "") -> Dictionary:
    request_busy = true
    var http := HTTPRequest.new()
    add_child(http)
    var payload := "" if body == null else JSON.stringify(body)
    var err := http.request(SUPABASE_URL + path, _headers(authenticated, prefer), method, payload)
    if err != OK:
        http.queue_free()
        request_busy = false
        return {"ok":false, "status":0, "error":"Request could not start (%d)." % err}
    var completed: Array = await http.request_completed
    http.queue_free()
    request_busy = false
    var status := int(completed[1])
    var raw: PackedByteArray = completed[3]
    var text := raw.get_string_from_utf8()
    var parsed: Variant = null
    if not text.is_empty():
        parsed = JSON.parse_string(text)
    return {"ok": status >= 200 and status < 300, "status":status, "data":parsed, "text":text}

func _authenticate_anonymously() -> void:
    var result := await _request(HTTPClient.METHOD_POST, "/auth/v1/signup", {}, false)
    if not result.ok:
        connecting = false
        network_error.emit("Supabase sign-in failed (%d): %s" % [result.status, _error_text(result)])
        return
    var data: Dictionary = result.data if result.data is Dictionary else {}
    access_token = str(data.get("access_token", ""))
    refresh_token = str(data.get("refresh_token", ""))
    var user: Dictionary = data.get("user", {}) if data.get("user", {}) is Dictionary else {}
    user_id = str(user.get("id", ""))
    if access_token.is_empty() or user_id.is_empty():
        connecting = false
        network_error.emit("Supabase did not return a player session.")
        return
    connected = true
    connecting = false
    _save_session()
    connected_to_service.emit()
    account_authenticated.emit(true, "Guest session ready.")

func _error_text(result: Dictionary) -> String:
    if result.data is Dictionary:
        return str(result.data.get("message", result.data.get("error_description", result.data.get("error", result.text))))
    return str(result.text)

func create_room(chosen_class: String, chosen_deck_mode: String = "custom") -> void:
    player_class = chosen_class
    player_deck_mode = chosen_deck_mode
    var result := await _request(HTTPClient.METHOD_POST, "/rest/v1/rpc/create_private_room", {})
    if not result.ok:
        network_error.emit("Could not create room: %s" % _error_text(result))
        return
    var rows: Array = result.data if result.data is Array else []
    if rows.is_empty() or not (rows[0] is Dictionary):
        network_error.emit("Supabase created no room record.")
        return
    room_id = str(rows[0].get("room_id", ""))
    room_code = str(rows[0].get("room_code", ""))
    role = "host"
    last_action_id = 0
    await _save_class_to_room()
    room_created.emit(room_code)

func join_room(code: String, chosen_class: String, chosen_deck_mode: String = "custom") -> void:
    player_class = chosen_class
    player_deck_mode = chosen_deck_mode
    var clean_code := code.strip_edges().to_upper()
    var result := await _request(HTTPClient.METHOD_POST, "/rest/v1/rpc/join_private_room", {"code":clean_code})
    if not result.ok:
        network_error.emit("Could not join room: %s" % _error_text(result))
        return
    room_id = str(result.data)
    if room_id.begins_with("\""):
        room_id = room_id.trim_prefix("\"").trim_suffix("\"")
    room_code = clean_code
    role = "join"
    last_action_id = 0
    await _save_class_to_room()
    room_joined.emit(room_code)

func _save_class_to_room() -> void:
    if room_id.is_empty():
        return
    var field := "host_deck" if role == "host" else "guest_deck"
    var body := {field:{"class":player_class,"deck_mode":player_deck_mode}}
    await _request(HTTPClient.METHOD_PATCH, "/rest/v1/game_rooms?id=eq.%s" % room_id, body, true, "return=minimal")

func set_ready(chosen_class: String, chosen_deck_mode: String = "custom") -> void:
    player_class = chosen_class
    player_deck_mode = chosen_deck_mode
    await _save_class_to_room()
    var result := await _request(HTTPClient.METHOD_PATCH, "/rest/v1/room_members?room_id=eq.%s&user_id=eq.%s" % [room_id,user_id], {"is_ready":true}, true, "return=minimal")
    if not result.ok:
        network_error.emit("Could not mark ready: %s" % _error_text(result))

func send_packet(payload: Dictionary) -> void:
    var kind := str(payload.get("type", ""))
    match kind:
        "game":
            var copy := payload.duplicate(true)
            copy.erase("type")
            copy.erase("room")
            _insert_action("game", copy)
        "mulligan_done":
            _insert_action("mulligan_done", {"state":payload.get("state", {})})

func send_game(payload: Dictionary) -> void:
    if not connected or room_id.is_empty():
        network_error.emit("Not connected to a Supabase room.")
        return
    await _insert_action("game", payload)

func send_mulligan_done(state: Dictionary) -> void:
    _insert_action("mulligan_done", {"state":state})

func _insert_action(action_type: String, payload: Dictionary) -> void:
    if room_id.is_empty():
        return
    var action_number := int(Time.get_unix_time_from_system() * 1000.0) * 1000 + randi_range(0,999)
    var body := {
        "room_id":room_id,
        "actor_id":user_id,
        "action_number":action_number,
        "action_type":action_type,
        "payload":payload
    }
    var result := await _request(HTTPClient.METHOD_POST, "/rest/v1/match_actions", body, true, "return=representation")
    if not result.ok:
        network_error.emit("Could not send match action: %s" % _error_text(result))

func _poll_room_and_actions() -> void:
    var room_result := await _request(HTTPClient.METHOD_GET, "/rest/v1/game_rooms?id=eq.%s&select=*" % room_id)
    if room_result.ok:
        var rooms: Array = room_result.data if room_result.data is Array else []
        if not rooms.is_empty() and rooms[0] is Dictionary:
            await _handle_room_row(rooms[0])
    var actions_result := await _request(HTTPClient.METHOD_GET, "/rest/v1/match_actions?room_id=eq.%s&id=gt.%d&select=*&order=id.asc" % [room_id,last_action_id])
    if actions_result.ok:
        var actions: Array = actions_result.data if actions_result.data is Array else []
        for action in actions:
            if action is Dictionary:
                last_action_id = maxi(last_action_id, int(action.get("id",0)))
                if str(action.get("actor_id","")) == user_id:
                    continue
                _handle_action(action)
    if role == "host":
        await _host_check_mulligans()

func _handle_room_row(room: Dictionary) -> void:
    var members_result := await _request(HTTPClient.METHOD_GET, "/rest/v1/room_members?room_id=eq.%s&select=*" % room_id)
    var members: Array = members_result.data if members_result.ok and members_result.data is Array else []
    var ready_count := 0
    for member in members:
        if member is Dictionary and bool(member.get("is_ready",false)):
            ready_count += 1
    var signature := "%d:%d:%s" % [members.size(),ready_count,str(room.get("status","waiting"))]
    if signature != last_lobby_signature:
        last_lobby_signature = signature
        lobby_updated.emit({"room":room_code,"players":members.size(),"ready":ready_count})
    if role == "host" and members.size() == 2 and ready_count == 2 and not match_start_sent:
        match_start_sent = true
        var host_data: Dictionary = room.get("host_deck", {}) if room.get("host_deck", {}) is Dictionary else {}
        var guest_data: Dictionary = room.get("guest_deck", {}) if room.get("guest_deck", {}) is Dictionary else {}
        var seed_value := randi_range(1,2000000000)
        await _request(HTTPClient.METHOD_PATCH, "/rest/v1/game_rooms?id=eq.%s" % room_id, {"status":"playing","turn_number":0}, true, "return=minimal")
        await _insert_action_await("match_start", {
            "seed":seed_value,
            "host_class":str(host_data.get("class","Hope")),
            "guest_class":str(guest_data.get("class","Courage")),
            "host_deck_mode":str(host_data.get("deck_mode","custom")),
            "guest_deck_mode":str(guest_data.get("deck_mode","custom"))
        })

func _insert_action_await(action_type: String, payload: Dictionary) -> void:
    var action_number := int(Time.get_unix_time_from_system() * 1000.0) * 1000 + randi_range(0,999)
    await _request(HTTPClient.METHOD_POST, "/rest/v1/match_actions", {
        "room_id":room_id,"actor_id":user_id,"action_number":action_number,
        "action_type":action_type,"payload":payload
    }, true, "return=representation")
    if action_type == "match_start":
        _emit_match_start(payload)

func _handle_action(action: Dictionary) -> void:
    var action_type := str(action.get("action_type",""))
    var payload: Dictionary = action.get("payload", {}) if action.get("payload", {}) is Dictionary else {}
    match action_type:
        "match_start":
            _emit_match_start(payload)
        "game":
            game_message.emit(payload)
        "mulligan_done":
            game_message.emit({"event":"snapshot","state":payload.get("state",{})})
        "battle_begin":
            game_message.emit({"event":"battle_begin","first_role":str(payload.get("first_role","host"))})

func _emit_match_start(payload: Dictionary) -> void:
    var host_class := str(payload.get("host_class","Hope"))
    var guest_class := str(payload.get("guest_class","Courage"))
    match_started.emit({
        "room":room_code,
        "role":role,
        "your_class":host_class if role == "host" else guest_class,
        "opponent_class":guest_class if role == "host" else host_class,
        "seed":int(payload.get("seed",1))
    })

func _host_check_mulligans() -> void:
    if battle_begin_sent or room_id.is_empty():
        return
    var result := await _request(HTTPClient.METHOD_GET, "/rest/v1/match_actions?room_id=eq.%s&action_type=eq.mulligan_done&select=actor_id" % room_id)
    if not result.ok or not (result.data is Array):
        return
    var actors := {}
    for row in result.data:
        if row is Dictionary:
            actors[str(row.get("actor_id",""))] = true
    if actors.size() >= 2:
        battle_begin_sent = true
        await _insert_action_await("battle_begin", {"first_role":"host"})
        game_message.emit({"event":"battle_begin","first_role":"host"})
