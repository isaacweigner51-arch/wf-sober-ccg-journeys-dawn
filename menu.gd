extends Control

const GOLD_COLOR := Color(0.95, 0.78, 0.34)
const PANEL := Color(0.025, 0.045, 0.08, 0.97)
const SAVE_PATH := "user://journeys_dawn_profile.cfg"
const APP_VERSION := "0.5.7"
const BUILD_NAME := "v0.8.4 • AUDIO & CARD ART RECOVERY"
const CLASSES := ["Hope", "Courage", "Serenity", "Purpose"]
const RARITIES := ["Bronze", "Silver", "Gold", "Epic", "Legendary", "Signature Platinum"]
const COPY_LIMITS := {"Bronze":3, "Silver":3, "Gold":3, "Epic":3, "Legendary":2, "Platinum":1, "Signature Gold":1, "Signature Platinum":1}
const DUST_VALUES := {"Bronze":10, "Silver":40, "Gold":150, "Epic":275, "Legendary":600, "Platinum":1500, "Signature Platinum":1500}
const CRAFT_COSTS := {"Bronze":50, "Silver":150, "Gold":500, "Epic":900, "Legendary":2000, "Platinum":4500, "Signature Platinum":4500}
const DAILY_REWARDS := [
    {"packs":1, "vials":0},
    {"packs":2, "vials":0},
    {"packs":3, "vials":0},
    {"packs":4, "vials":0},
    {"packs":4, "vials":300}
]

const STORY_STAGES := [
    {
        "id":1, "name":"The First Step", "class":"Hope", "gold":0, "packs":1,
        "subtitle":"Learn to stay in the fight.",
        "story":"The hardest battle is the one where you finally admit you need to fight at all. Today isn't about winning — it's about showing up and staying in the fight one more round than you thought you could."
    },
    {
        "id":2, "name":"Finding Strength", "class":"Courage", "gold":150, "packs":0,
        "subtitle":"Face pressure without backing down.",
        "story":"An old trigger finds you when you least expect it. You don't have to be fearless to face it — you just have to be willing to stand your ground long enough to remember you can."
    },
    {
        "id":3, "name":"Quieting the Noise", "class":"Serenity", "gold":0, "packs":1,
        "subtitle":"Patience can control the battlefield.",
        "story":"The cravings are loud tonight, but loud isn't the same as strong. You've learned to sit with the noise instead of running from it — and in that stillness, you find you're steadier than it is."
    },
    {
        "id":4, "name":"A Reason to Continue", "class":"Purpose", "gold":250, "packs":0,
        "subtitle":"Build toward something greater.",
        "story":"Somewhere along the way, recovery stopped being about what you were running from and became about what you're building toward. Today you fight for that reason, not away from the old one."
    },
    {
        "id":5, "name":"Community Test", "class":"Courage", "gold":300, "packs":2,
        "subtitle":"Use everything you have learned.",
        "story":"You're not walking this road alone anymore — and now it's your turn to prove that everything you've learned holds up when someone else is counting on you. Everything you've built comes together here."
    }
]

const CHALLENGES := [
    {"name":"Hope Mentor", "class":"Hope", "reward":25, "stars":"★"},
    {"name":"Courage Veteran", "class":"Courage", "reward":40, "stars":"★★"},
    {"name":"Serenity Guardian", "class":"Serenity", "reward":60, "stars":"★★★"},
    {"name":"Purpose Champion", "class":"Purpose", "reward":80, "stars":"★★★★"},
    {"name":"Recovery Master", "class":"All Classes", "reward":150, "stars":"★★★★★"}
]

var root_layer: Control
var cards: Array = []
var gold_balance := 0
var dust_balance := 0
var pack_inventory := 0
var packs_opened := 0
var platinum_pity := 0
var selected_class := ""
var collection_owned: Dictionary = {}
var _menu_art_cache: Dictionary = {}
var saved_deck: Array = []
var saved_decks: Dictionary = {}
var recovery_challenge_progress: Dictionary = {}
var selected_deck_class := "Hope"
var battle_select_class := "Hope"
var battle_select_mode := "custom"
var battle_opponent_class := "Courage"
var battle_opponent_mode := "prebuilt"
var status_label: Label
var academy_complete := false
var academy_step := 0
var academy_reward_claimed := false
var academy_action_stage := 0
var academy_feedback: Label
var access_status: Label
var access_token_input: LineEdit
var daily_reward_day := 0
var daily_last_claim_day := -1
var online_server_input: LineEdit
var online_room_input: LineEdit
var online_status: Label
var online_selected_class := "Hope"
var online_selected_deck_mode := "custom"
var online_hosting := false
var launch_status: Label
var launch_email: LineEdit
var launch_password: LineEdit
var launch_screen_active := false
var home_music: AudioStreamPlayer

func ensure_home_music() -> void:
    # Home music lives in the AudioManager autoload so screen rebuilds cannot
    # delete the player. clear_screen() removes menu children every time the UI
    # changes, which was silently freeing the old local AudioStreamPlayer.
    AudioManager.play_home_music()

func stop_home_music() -> void:
    AudioManager.stop_music()

func is_mobile_device() -> bool:
    return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")

func ui_font_size(value: int) -> int:
    return int(round(float(value) * (1.18 if is_mobile_device() else 1.0)))

func safe_set_text(node: Object, value: String) -> void:
    if node != null and is_instance_valid(node) and "text" in node:
        node.set("text", value)

func _ready() -> void:
    randomize()
    ensure_home_music()
    if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
        get_viewport().size_changed.connect(_on_viewport_size_changed)
    if not AccessManager.authentication_finished.is_connected(_on_access_authentication_finished):
        AccessManager.authentication_finished.connect(_on_access_authentication_finished)
    if not BillingManager.purchase_completed.is_connected(_on_billing_purchase_completed):
        BillingManager.purchase_completed.connect(_on_billing_purchase_completed)
    if not BillingManager.purchase_failed.is_connected(_on_billing_purchase_failed):
        BillingManager.purchase_failed.connect(_on_billing_purchase_failed)
    if not BillingManager.products_updated.is_connected(_on_billing_products_updated):
        BillingManager.products_updated.connect(_on_billing_products_updated)
    if not NetworkManager.connected_to_service.is_connected(_on_online_connected):
        NetworkManager.connected_to_service.connect(_on_online_connected)
    if not NetworkManager.room_created.is_connected(_on_online_room_created):
        NetworkManager.room_created.connect(_on_online_room_created)
    if not NetworkManager.room_joined.is_connected(_on_online_room_joined):
        NetworkManager.room_joined.connect(_on_online_room_joined)
    if not NetworkManager.lobby_updated.is_connected(_on_online_lobby_updated):
        NetworkManager.lobby_updated.connect(_on_online_lobby_updated)
    if not NetworkManager.match_started.is_connected(_on_online_match_started):
        NetworkManager.match_started.connect(_on_online_match_started)
    if not NetworkManager.network_error.is_connected(_on_online_error):
        NetworkManager.network_error.connect(_on_online_error)
    if not NetworkManager.account_authenticated.is_connected(_on_launch_auth_result):
        NetworkManager.account_authenticated.connect(_on_launch_auth_result)
    cards = load_cards()
    load_profile()
    show_launch_screen()
    if NetworkManager.connected and not NetworkManager.access_token.is_empty():
        launch_status.text = "Restoring account session..."
        NetworkManager.validate_saved_session()

func show_launch_screen() -> void:
    ensure_home_music()
    launch_screen_active = true
    clear_screen()
    add_background(0.58)

    var title := centered_label("WF SOBER CCG", Vector2(240, 54), Vector2(800, 62), 42, root_layer)
    title.add_theme_color_override("font_color", GOLD_COLOR)
    centered_label("JOURNEYS DAWN", Vector2(340, 115), Vector2(600, 42), 25, root_layer)
    centered_label("Loading your recovery journey...", Vector2(390, 158), Vector2(500, 30), 16, root_layer).modulate = Color(0.72, 0.82, 0.92)

    var panel := Panel.new()
    panel.position = Vector2(330, 210)
    panel.size = Vector2(620, 430)
    panel.add_theme_stylebox_override("panel", style(GOLD_COLOR, 20))
    root_layer.add_child(panel)

    centered_label("PLAYER ACCOUNT", Vector2(40, 22), Vector2(540, 44), 26, panel).add_theme_color_override("font_color", GOLD_COLOR)
    centered_label("Sign in to keep your collection and Vials tied to your account, or continue as a guest for testing.", Vector2(70, 72), Vector2(480, 58), 15, panel)

    launch_email = LineEdit.new()
    launch_email.position = Vector2(80, 145)
    launch_email.size = Vector2(460, 48)
    launch_email.placeholder_text = "Email address"
    launch_email.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
    launch_email.add_theme_font_size_override("font_size", 17)
    panel.add_child(launch_email)

    launch_password = LineEdit.new()
    launch_password.position = Vector2(80, 205)
    launch_password.size = Vector2(460, 48)
    launch_password.placeholder_text = "Password (6+ characters)"
    launch_password.secret = true
    launch_password.add_theme_font_size_override("font_size", 17)
    panel.add_child(launch_password)

    button("SIGN IN", Vector2(80, 275), Vector2(220, 50), func():
        launch_status.text = "Signing in..."
        NetworkManager.sign_in_with_email(launch_email.text, launch_password.text)
    , panel)
    button("CREATE ACCOUNT", Vector2(320, 275), Vector2(220, 50), func():
        launch_status.text = "Creating account..."
        NetworkManager.create_account_with_email(launch_email.text, launch_password.text)
    , panel)
    button("CONTINUE AS GUEST", Vector2(180, 338), Vector2(260, 46), func():
        launch_status.text = "Starting guest session..."
        NetworkManager.continue_as_guest()
    , panel)

    launch_status = centered_label("", Vector2(55, 388), Vector2(510, 28), 14, panel)

func _on_launch_auth_result(success: bool, message: String) -> void:
    if is_instance_valid(launch_status):
        launch_status.text = message
        launch_status.add_theme_color_override("font_color", Color(0.55, 1.0, 0.70) if success else Color(1.0, 0.55, 0.55))
    if not success:
        return
    if NetworkManager.account_role == "owner":
        message += " Developer access enabled."
    elif NetworkManager.account_role == "tester":
        message += " Tester account ready."
    if is_instance_valid(launch_status):
        launch_status.text = message
    launch_screen_active = false
    await get_tree().create_timer(0.35).timeout
    # Daily rewards are automatic after a successful sign-in/session restore.
    # Players never need to visit a separate daily-reward menu.
    if can_claim_daily_reward():
        auto_claim_daily_reward_after_login()
    elif academy_complete:
        show_home()
    else:
        show_first_day_intro()

func _on_viewport_size_changed() -> void:
    # Keep the account launch screen active during rotation/resizing.
    if launch_screen_active:
        show_launch_screen()
    elif academy_complete:
        show_home()

func load_cards() -> Array:
    var file := FileAccess.open("res://data/cards.json", FileAccess.READ)
    if file == null:
        return []
    var parsed = JSON.parse_string(file.get_as_text())
    return parsed if parsed is Array else []

func load_profile() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(SAVE_PATH) == OK:
        gold_balance = int(cfg.get_value("economy", "gold", 0))
        dust_balance = int(cfg.get_value("economy", "dust", 0))
        pack_inventory = int(cfg.get_value("economy", "packs", 0))
        packs_opened = int(cfg.get_value("packs", "opened", 0))
        platinum_pity = int(cfg.get_value("packs", "platinum_pity", 0))
        selected_class = str(cfg.get_value("profile", "class", ""))
        collection_owned = cfg.get_value("collection", "owned", {})
        selected_deck_class = str(cfg.get_value("deck", "class", "Hope"))
        saved_decks = cfg.get_value("decks", "by_class", {})
        if saved_decks.is_empty():
            # Migrate the older single-deck save into its original class slot.
            saved_deck = cfg.get_value("deck", "cards", [])
            if not saved_deck.is_empty():
                saved_decks[selected_deck_class] = saved_deck.duplicate()
        saved_deck = Array(saved_decks.get(selected_deck_class, []))
        academy_complete = bool(cfg.get_value("academy", "complete", false))
        academy_step = int(cfg.get_value("academy", "step", 0))
        academy_reward_claimed = bool(cfg.get_value("academy", "reward_claimed", false))
        daily_reward_day = int(cfg.get_value("daily", "reward_day", 0))
        daily_last_claim_day = int(cfg.get_value("daily", "last_claim_day", -1))
        recovery_challenge_progress = cfg.get_value("challenge", "recovery_progress", {})
        # Existing players from earlier builds should not lose access.
        if selected_class != "" and not cfg.has_section_key("academy", "complete"):
            academy_complete = true
            academy_reward_claimed = true
        migrate_sponsor_out_of_prebuilt_deck()

func migrate_sponsor_out_of_prebuilt_deck() -> void:
    # v0.6.3 migration: Sponsor used to be inserted into every starter deck.
    # Remove that automatic copy while preserving the rest of the player's deck.
    var removed := false
    while saved_deck.has("JD-080"):
        saved_deck.erase("JD-080")
        removed = true
    if not removed:
        return
    # Fill the open slot with an owned, legal class/Neutral card so the deck
    # remains at 40. Sponsor stays in the collection and may be added manually.
    while saved_deck.size() < 40:
        var added := false
        for card_data in cards:
            var id := str(card_data.get("id", ""))
            var card_class := str(card_data.get("class", ""))
            if id == "JD-080":
                continue
            if card_class != selected_deck_class and card_class != "Neutral":
                continue
            var rarity := str(card_data.get("rarity", "Bronze"))
            var limit := int(COPY_LIMITS.get(rarity, int(card_data.get("max_copies", 1))))
            var owned := int(collection_owned.get(id, 0))
            if count_in_deck(id) < mini(limit, owned):
                saved_deck.append(id)
                added = true
                break
        if not added:
            break

func save_profile() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("economy", "gold", gold_balance)
    cfg.set_value("economy", "dust", dust_balance)
    cfg.set_value("economy", "packs", pack_inventory)
    cfg.set_value("packs", "opened", packs_opened)
    cfg.set_value("packs", "platinum_pity", platinum_pity)
    cfg.set_value("profile", "class", selected_class)
    cfg.set_value("collection", "owned", collection_owned)
    saved_decks[selected_deck_class] = saved_deck.duplicate()
    cfg.set_value("deck", "cards", saved_deck) # Backward-compatible active deck.
    cfg.set_value("deck", "class", selected_deck_class)
    cfg.set_value("decks", "by_class", saved_decks)
    cfg.set_value("academy", "complete", academy_complete)
    cfg.set_value("academy", "step", academy_step)
    cfg.set_value("academy", "reward_claimed", academy_reward_claimed)
    cfg.set_value("daily", "reward_day", daily_reward_day)
    cfg.set_value("daily", "last_claim_day", daily_last_claim_day)
    cfg.set_value("challenge", "recovery_progress", recovery_challenge_progress)
    cfg.save(SAVE_PATH)

func clear_screen() -> void:
    for child in get_children(): child.queue_free()
    root_layer = Control.new()
    root_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(root_layer)

func add_background(darken := 0.36) -> void:
    var bg := TextureRect.new()
    bg.texture = load("res://assets/ui/home_bg.png")
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    root_layer.add_child(bg)
    var shade := ColorRect.new()
    shade.color = Color(0.005, 0.01, 0.025, darken)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root_layer.add_child(shade)

func style(border := GOLD_COLOR, radius := 12) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = PANEL
    s.border_color = border
    s.set_border_width_all(2)
    s.set_corner_radius_all(radius)
    s.shadow_color = Color(0,0,0,0.65)
    s.shadow_size = 8
    return s

func class_color(name: String) -> Color:
    match name:
        "Hope": return Color(0.52,0.42,0.94)
        "Courage": return Color(0.92,0.28,0.20)
        "Serenity": return Color(0.25,0.72,0.86)
        "Purpose": return Color(0.80,0.58,0.20)
        _: return Color(0.55,0.80,0.55)

func button(text_value: String, pos: Vector2, size_value: Vector2, callback: Callable, parent: Control = root_layer) -> Button:
    var b := Button.new()
    b.text = text_value
    b.position = pos
    b.size = size_value
    b.add_theme_font_size_override("font_size", ui_font_size(18))
    b.add_theme_stylebox_override("normal", style(Color(0.55,0.45,0.22), 9))
    b.add_theme_stylebox_override("hover", style(GOLD_COLOR, 9))
    b.pressed.connect(callback)
    parent.add_child(b)
    return b

func label(text_value: String, pos: Vector2, size_value: Vector2, font_size := 18, parent: Control = root_layer) -> Label:
    var l := Label.new()
    l.text = text_value
    l.position = pos
    l.size = size_value
    l.add_theme_font_size_override("font_size", ui_font_size(font_size))
    l.add_theme_color_override("font_color", Color(0.94,0.95,1.0))
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    parent.add_child(l)
    return l

func header(title: String, subtitle: String) -> void:
    var p := Panel.new(); p.position=Vector2(22,16); p.size=Vector2(1236,84); p.add_theme_stylebox_override("panel",style()); root_layer.add_child(p)
    var t := label(title,Vector2(24,8),Vector2(760,38),30,p); t.add_theme_color_override("font_color",GOLD_COLOR)
    label(subtitle,Vector2(26,48),Vector2(900,25),15,p)
    button("HOME",Vector2(1080,17),Vector2(125,48),show_home,p)

func currency_bar() -> void:
    var p := Panel.new(); p.position=Vector2(846,112); p.size=Vector2(390,54); p.add_theme_stylebox_override("panel",style(Color(0.32,0.72,0.95))); root_layer.add_child(p)
    var l := label("GOLD %d   •   VIALS %d   •   PACKS %d" % [gold_balance,dust_balance,pack_inventory],Vector2(8,10),Vector2(374,34),17,p); l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER

func show_home() -> void:
    clear_screen()
    add_background(0.58)
    ensure_home_music()

    var active_class := selected_class if selected_class != "" else "Hope"

    # Stable 1280x720 layout. Everything stays inside fixed, non-overlapping regions.
    var top := Panel.new()
    top.position = Vector2(16, 12)
    top.size = Vector2(1248, 64)
    top.add_theme_stylebox_override("panel", style(Color(0.38, 0.30, 0.17), 12))
    root_layer.add_child(top)

    var avatar := TextureRect.new()
    avatar.texture = load("res://assets/leaders/%s.png" % active_class.to_lower())
    avatar.position = Vector2(10, 8)
    avatar.size = Vector2(48, 48)
    avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    top.add_child(avatar)
    label("WALKING FREE CCG", Vector2(70, 8), Vector2(330, 28), 21, top).add_theme_color_override("font_color", GOLD_COLOR)
    label("Journey's Dawn  •  " + active_class + " Leader", Vector2(70, 35), Vector2(390, 21), 13, top)
    var wallet := label("GOLD %d     VIALS %d     PACKS %d" % [gold_balance, dust_balance, pack_inventory], Vector2(680, 17), Vector2(450, 30), 16, top)
    wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    button("SETTINGS", Vector2(1140, 10), Vector2(96, 44), show_test_tools if AccessManager.role_at_least(AccessManager.ROLE_TESTER) else show_launch_screen, top)

    var nav := Panel.new()
    nav.position = Vector2(16, 88)
    nav.size = Vector2(218, 616)
    nav.add_theme_stylebox_override("panel", style(Color(0.24, 0.20, 0.14), 14))
    root_layer.add_child(nav)
    var brand := centered_label("JOURNEY'S\nDAWN", Vector2(14, 20), Vector2(190, 72), 27, nav)
    brand.add_theme_color_override("font_color", GOLD_COLOR)
    centered_label("One day at a time.", Vector2(14, 99), Vector2(190, 28), 14, nav)
    var nav_items = [
        ["HOME", show_home], ["BATTLE", start_battle], ["DECK BUILDER", show_deck_builder],
        ["COLLECTION", show_collection], ["STORE", show_store], ["STORY MODE", show_story_mode],
        ["ONLINE VS", show_online_vs_setup]
    ]
    for i in range(nav_items.size()):
        button(str(nav_items[i][0]), Vector2(14, 145 + i * 57), Vector2(190, 46), nav_items[i][1], nav)
    var reward := Panel.new()
    reward.position = Vector2(14, 558)
    reward.size = Vector2(190, 44)
    reward.add_theme_stylebox_override("panel", style(Color(0.58, 0.40, 0.14), 8))
    nav.add_child(reward)
    centered_label("DAILY REWARD CLAIMED", Vector2(4, 7), Vector2(182, 28), 11, reward).add_theme_color_override("font_color", GOLD_COLOR)

    # Main content panel.
    var main := Panel.new()
    main.position = Vector2(248, 88)
    main.size = Vector2(1016, 616)
    main.add_theme_stylebox_override("panel", style(Color(0.17, 0.24, 0.34), 16))
    root_layer.add_child(main)

    centered_label("CHOOSE YOUR LEADER", Vector2(20, 10), Vector2(976, 34), 22, main).add_theme_color_override("font_color", GOLD_COLOR)
    var order := ["Hope", "Purpose", "Serenity", "Courage"]
    for i in range(order.size()):
        var c: String = order[i]
        var tab := Button.new()
        tab.position = Vector2(24 + i * 241, 50)
        tab.size = Vector2(224, 48)
        tab.text = c.to_upper()
        tab.add_theme_font_size_override("font_size", ui_font_size(15))
        var tab_style := style(class_color(c), 10)
        tab_style.bg_color = Color(0.025, 0.04, 0.075, 0.96)
        tab_style.set_border_width_all(4 if c == active_class else 2)
        tab.add_theme_stylebox_override("normal", tab_style)
        tab.add_theme_stylebox_override("hover", tab_style)
        tab.add_theme_stylebox_override("pressed", tab_style)
        tab.add_theme_color_override("font_color", Color(0.96, 0.97, 1.0))
        tab.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
        tab.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0))
        tab.pressed.connect(func():
            selected_class = c
            selected_deck_class = c
            save_profile()
            show_home()
        )
        main.add_child(tab)

    # Frameless hero showcase. The leader is presented as character art, not as a card.
    var showcase := Panel.new()
    showcase.position = Vector2(24, 114)
    showcase.size = Vector2(548, 430)
    var showcase_style := StyleBoxFlat.new()
    showcase_style.bg_color = Color(0.015, 0.025, 0.05, 0.60)
    showcase_style.border_color = class_color(active_class)
    showcase_style.set_border_width_all(2)
    showcase_style.set_corner_radius_all(18)
    showcase_style.shadow_color = Color(class_color(active_class), 0.28)
    showcase_style.shadow_size = 10
    showcase.add_theme_stylebox_override("panel", showcase_style)
    main.add_child(showcase)

    # Dedicated clipped viewport for the leader art. This prevents the texture from
    # drawing below or outside the showcase on different display scales.
    showcase.clip_contents = true

    var art_frame := Panel.new()
    art_frame.position = Vector2(8, 8)
    art_frame.size = Vector2(532, 344)
    art_frame.clip_contents = true
    var art_frame_style := StyleBoxFlat.new()
    art_frame_style.bg_color = Color(0.008, 0.014, 0.028, 1.0)
    art_frame_style.set_corner_radius_all(14)
    art_frame.add_theme_stylebox_override("panel", art_frame_style)
    showcase.add_child(art_frame)

    var art := TextureRect.new()
    art.texture = load("res://assets/leaders/%s.png" % active_class.to_lower())
    art.position = Vector2.ZERO
    art.size = art_frame.size
    art.custom_minimum_size = Vector2.ZERO
    art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    # COVERED, not CENTERED: this frame (532x344) is much wider than the
    # square 512x512 source art. CENTERED left large empty bars down both
    # sides; COVERED fills the whole frame with the portrait.
    art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    art.clip_contents = true
    art_frame.add_child(art)

    var info_strip := Panel.new()
    info_strip.position = Vector2(8, 356)
    info_strip.size = Vector2(532, 66)
    var info_style := StyleBoxFlat.new()
    info_style.bg_color = Color(0.015, 0.025, 0.05, 0.94)
    info_style.border_color = Color(class_color(active_class), 0.85)
    info_style.set_border_width_all(1)
    info_style.set_corner_radius_all(12)
    info_strip.add_theme_stylebox_override("panel", info_style)
    showcase.add_child(info_strip)

    var leader_name := label(active_class.to_upper(), Vector2(16, 7), Vector2(180, 28), 21, info_strip)
    leader_name.add_theme_color_override("font_color", class_color(active_class))
    var desc := label(class_description(active_class), Vector2(202, 7), Vector2(214, 48), 12, info_strip)
    desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    var preview_button := button("PREVIEW", Vector2(326, 9), Vector2(94, 46), show_deck_preview, info_strip)
    preview_button.add_theme_font_size_override("font_size", ui_font_size(13))
    var decks_button := button("DECKS", Vector2(426, 9), Vector2(94, 46), show_deck_builder, info_strip)
    decks_button.add_theme_font_size_override("font_size", ui_font_size(15))

    # Right-side actions have their own reserved region and cannot overlap the art.
    var right := Panel.new()
    right.position = Vector2(590, 114)
    right.size = Vector2(402, 430)
    right.add_theme_stylebox_override("panel", style(Color(0.30, 0.24, 0.18), 14))
    main.add_child(right)
    label("RECOVERY CHALLENGE", Vector2(20, 18), Vector2(362, 32), 20, right).add_theme_color_override("font_color", GOLD_COLOR)
    label("Win 3 matches with " + active_class + ".", Vector2(20, 58), Vector2(362, 30), 15, right)
    var challenge_progress := int(recovery_challenge_progress.get(active_class, 0))
    var progress_bg := ColorRect.new(); progress_bg.position = Vector2(20, 98); progress_bg.size = Vector2(362, 12); progress_bg.color = Color(0.05,0.06,0.09); right.add_child(progress_bg)
    var progress := ColorRect.new(); progress.position = Vector2(20, 98); progress.size = Vector2(362.0 * (float(challenge_progress) / 3.0), 12); progress.color = class_color(active_class); right.add_child(progress)
    label("%d / 3" % challenge_progress, Vector2(20, 116), Vector2(362, 24), 13, right).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    label("DAILY REFLECTION", Vector2(20, 160), Vector2(362, 30), 18, right).add_theme_color_override("font_color", GOLD_COLOR)
    var reflection := label("Progress begins with one honest choice. Keep moving forward.", Vector2(20, 198), Vector2(362, 76), 15, right)
    reflection.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    var enter := button("ENTER BATTLE", Vector2(20, 310), Vector2(362, 72), start_battle, right)
    enter.add_theme_font_size_override("font_size", ui_font_size(22))
    enter.add_theme_stylebox_override("normal", style(GOLD_COLOR, 14))
    enter.add_theme_color_override("font_color", Color(0.04, 0.06, 0.10))

    centered_label(BUILD_NAME, Vector2(20, 566), Vector2(976, 28), 12, main).modulate = Color(0.72, 0.78, 0.86)

func show_online_vs_setup() -> void:
    clear_screen(); add_background(0.68); header("VS FRIEND — ONLINE", "Private room codes for two separate phones")
    online_hosting = false
    online_selected_class = selected_class if selected_class != "" else "Hope"
    var panel := Panel.new(); panel.position=Vector2(150,115); panel.size=Vector2(980,535); panel.add_theme_stylebox_override("panel",style(Color(0.36,0.66,0.95),20)); root_layer.add_child(panel)
    var server_title := label("ONLINE BACKEND",Vector2(55,36),Vector2(250,34),20,panel); server_title.add_theme_color_override("font_color",GOLD_COLOR)
    var backend := label("SUPABASE ONLINE SERVICE",Vector2(55,76),Vector2(870,48),22,panel); backend.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; backend.add_theme_color_override("font_color",Color(0.45,0.95,0.72))
    label("CLASS",Vector2(55,145),Vector2(160,34),20,panel).add_theme_color_override("font_color",GOLD_COLOR)
    var group := ButtonGroup.new()
    for i in range(CLASSES.size()):
        var c: String = CLASSES[i]
        var b := Button.new(); b.toggle_mode=true; b.button_group=group; b.position=Vector2(55+i*218,190); b.size=Vector2(195,70); b.text=c.to_upper(); b.add_theme_font_size_override("font_size",ui_font_size(17)); b.add_theme_stylebox_override("normal",style(class_color(c),12)); b.add_theme_stylebox_override("pressed",style(GOLD_COLOR,12)); panel.add_child(b)
        b.pressed.connect(func(): online_selected_class=c)
        if c==online_selected_class: b.button_pressed=true
    label("DECK",Vector2(55,270),Vector2(160,30),18,panel).add_theme_color_override("font_color",GOLD_COLOR)
    var deck_group := ButtonGroup.new()
    var deck_modes := [{"id":"custom","label":"MY DECK"}]
    if AccessManager.role_at_least(AccessManager.ROLE_OWNER):
        deck_modes.append({"id":"meta","label":"DEV META"})
        deck_modes.append({"id":"final_boss","label":"FINAL BOSS"})
    for i in range(deck_modes.size()):
        var mode_data: Dictionary = deck_modes[i]
        var db := Button.new(); db.toggle_mode=true; db.button_group=deck_group; db.position=Vector2(210+i*225,260); db.size=Vector2(205,48); db.text=str(mode_data["label"]); db.add_theme_font_size_override("font_size",ui_font_size(15)); db.add_theme_stylebox_override("normal",style(Color(0.28,0.40,0.62),10)); db.add_theme_stylebox_override("pressed",style(GOLD_COLOR,10)); panel.add_child(db)
        var mode_id := str(mode_data["id"])
        db.pressed.connect(func(): online_selected_deck_mode=mode_id)
        if mode_id==online_selected_deck_mode: db.button_pressed=true
    button("HOST MATCH",Vector2(55,340),Vector2(255,62),_online_host_pressed,panel)
    online_room_input = LineEdit.new(); online_room_input.position=Vector2(350,340); online_room_input.size=Vector2(250,62); online_room_input.placeholder_text="6-DIGIT CODE"; online_room_input.max_length=6; online_room_input.add_theme_font_size_override("font_size",ui_font_size(22)); online_room_input.alignment=HORIZONTAL_ALIGNMENT_CENTER; panel.add_child(online_room_input)
    button("JOIN MATCH",Vector2(630,340),Vector2(255,62),_online_join_pressed,panel)
    online_status = label("Choose a class and deck, then host or join.",Vector2(55,430),Vector2(870,55),18,panel); online_status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    button("HOME",Vector2(40,645),Vector2(160,48),show_home)

func _connect_online_service() -> void:
    safe_set_text(online_status,"Signing in to Supabase...")
    NetworkManager.connect_service()

func _online_host_pressed() -> void:
    online_hosting = true
    if not NetworkManager.connected:
        _connect_online_service()
    else:
        NetworkManager.create_room(online_selected_class, online_selected_deck_mode)

func _online_join_pressed() -> void:
    online_hosting = false
    if online_room_input == null or online_room_input.text.strip_edges().length() != 6:
        safe_set_text(online_status,"Enter the six-digit room code.")
        return
    if not NetworkManager.connected:
        _connect_online_service()
    else:
        NetworkManager.join_room(online_room_input.text,online_selected_class, online_selected_deck_mode)

func _on_online_connected() -> void:
    if online_hosting:
        NetworkManager.create_room(online_selected_class, online_selected_deck_mode)
    elif online_room_input != null:
        NetworkManager.join_room(online_room_input.text,online_selected_class, online_selected_deck_mode)

func _on_online_room_created(code: String) -> void:
    if online_room_input != null: online_room_input.text=code
    safe_set_text(online_status,"ROOM %s — share this code. Waiting for your brother..." % code)
    NetworkManager.set_ready(online_selected_class, online_selected_deck_mode)

func _on_online_room_joined(code: String) -> void:
    safe_set_text(online_status,"Joined room %s. Waiting for host..." % code)
    NetworkManager.set_ready(online_selected_class, online_selected_deck_mode)

func _on_online_lobby_updated(payload: Dictionary) -> void:
    safe_set_text(online_status,"Room %s • Players %d/2 • Ready %d/2" % [str(payload.get("room","")),int(payload.get("players",0)),int(payload.get("ready",0))])

func _on_online_match_started(payload: Dictionary) -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("battle","mode","online")
    cfg.set_value("battle","role",str(payload.get("role","join")))
    cfg.set_value("battle","room",str(payload.get("room","")))
    cfg.set_value("battle","your_class",str(payload.get("your_class",online_selected_class)))
    cfg.set_value("battle","opponent_class",str(payload.get("opponent_class","Courage")))
    cfg.set_value("battle","seed",int(payload.get("seed",1)))
    cfg.set_value("battle","your_deck_mode",str(payload.get("your_deck_mode",online_selected_deck_mode)))
    cfg.set_value("battle","opponent_deck_mode",str(payload.get("opponent_deck_mode","custom")))
    cfg.save("user://battle_setup.cfg")
    await _show_battle_intro(str(payload.get("your_class", online_selected_class)), str(payload.get("opponent_class", "Courage")))

func _on_online_error(message: String) -> void:
    safe_set_text(online_status,message)

func show_brother_battle_setup() -> void:
    clear_screen(); add_background(0.68); header("VS BROTHER", "Choose both classes, then pass the device between turns")
    var cfg := ConfigFile.new(); cfg.set_value("battle", "mode", "hotseat"); cfg.set_value("battle", "p1_class", selected_class if selected_class != "" else "Hope")
    cfg.set_value("battle", "p2_class", "Courage"); cfg.save("user://battle_setup.cfg")
    var instruction := label("PLAYER 1",Vector2(120,142),Vector2(460,42),28); instruction.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; instruction.add_theme_color_override("font_color",GOLD_COLOR)
    var instruction2 := label("PLAYER 2",Vector2(700,142),Vector2(460,42),28); instruction2.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; instruction2.add_theme_color_override("font_color",GOLD_COLOR)
    build_hotseat_class_column(Vector2(90,195), true)
    build_hotseat_class_column(Vector2(670,195), false)
    button("START BROTHER BATTLE",Vector2(455,620),Vector2(370,62),start_brother_battle)

func build_hotseat_class_column(origin: Vector2, player_one: bool) -> void:
    var group := ButtonGroup.new()
    for i in range(CLASSES.size()):
        var c: String = CLASSES[i]
        var b := Button.new(); b.toggle_mode=true; b.button_group=group; b.position=origin+Vector2((i%2)*235,(i/2)*190); b.size=Vector2(210,168)
        b.text=c.to_upper()+"\n"+class_description(c); b.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; b.add_theme_font_size_override("font_size",ui_font_size(16)); b.add_theme_stylebox_override("normal",style(class_color(c),14)); b.add_theme_stylebox_override("pressed",style(GOLD_COLOR,14))
        b.pressed.connect(func():
            var cfg := ConfigFile.new(); cfg.load("user://battle_setup.cfg"); cfg.set_value("battle", "p1_class" if player_one else "p2_class", c); cfg.save("user://battle_setup.cfg")
        )
        root_layer.add_child(b)
        if (player_one and c == (selected_class if selected_class != "" else "Hope")) or ((not player_one) and c == "Courage"):
            b.button_pressed=true

func start_brother_battle() -> void:
    get_tree().change_scene_to_file("res://battle.tscn")


func auto_claim_daily_reward_after_login() -> void:
    if not can_claim_daily_reward():
        if academy_complete:
            show_home()
        else:
            show_first_day_intro()
        return
    var today := current_calendar_day()
    var reward_index := normalized_daily_reward_index()
    var reward: Dictionary = DAILY_REWARDS[reward_index]
    pack_inventory += int(reward.get("packs", 0))
    dust_balance += int(reward.get("vials", 0))
    daily_last_claim_day = today
    daily_reward_day = (reward_index + 1) % DAILY_REWARDS.size()
    save_profile()
    show_daily_reward_claimed(reward_index, reward)

func current_calendar_day() -> int:
    return int(floor(Time.get_unix_time_from_system() / 86400.0))

func can_claim_daily_reward() -> bool:
    return current_calendar_day() != daily_last_claim_day

func normalized_daily_reward_index() -> int:
    # The five-day track repeats forever. Day 6 becomes Day 1, and missed
    # calendar days do not erase progress; the player resumes the next reward.
    return posmod(daily_reward_day, DAILY_REWARDS.size())

func show_daily_rewards() -> void:
    clear_screen(); add_background(0.68); header("DAILY RECOVERY REWARDS", "Return each day to keep building your collection"); currency_bar()
    var today_index := normalized_daily_reward_index()
    var accent := class_color(selected_class) if selected_class != "" else GOLD_COLOR

    # A connecting streak rail behind the day cards makes the five-day track
    # read as one continuous journey instead of five disconnected boxes.
    var rail := ColorRect.new()
    rail.position = Vector2(96, 296); rail.size = Vector2(1088, 6)
    rail.color = Color(0.20, 0.24, 0.30); root_layer.add_child(rail)
    var rail_progress := ColorRect.new()
    rail_progress.position = Vector2(96, 296); rail_progress.size = Vector2(1088 * (float(today_index) / max(1.0, DAILY_REWARDS.size() - 1.0)), 6)
    rail_progress.color = accent; root_layer.add_child(rail_progress)

    for i in range(DAILY_REWARDS.size()):
        var reward: Dictionary = DAILY_REWARDS[i]
        var is_today := i == today_index
        var is_claimed := (daily_last_claim_day >= 0 and i < today_index) or (is_today and not can_claim_daily_reward())
        var panel := Panel.new(); panel.position = Vector2(78 + i * 235, 205); panel.size = Vector2(205, 275)
        var border := accent if is_today else (Color(0.42,0.56,0.42) if is_claimed else Color(0.32,0.40,0.50))
        var pstyle := style(border, 16)
        if is_today:
            pstyle.set_border_width_all(4)
            pstyle.shadow_color = Color(accent, 0.45); pstyle.shadow_size = 14
        elif is_claimed:
            pstyle.bg_color = pstyle.bg_color.lightened(0.03)
        panel.add_theme_stylebox_override("panel", pstyle); root_layer.add_child(panel)
        if is_claimed:
            panel.modulate = Color(0.82, 0.86, 0.82) if not is_today else Color.WHITE

        var badge_text := "DAY %d" % (i + 1)
        var title_label := label(badge_text, Vector2(18,16), Vector2(169,36), 22, panel); title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        if is_claimed:
            title_label.add_theme_color_override("font_color", Color(0.6, 0.92, 0.62))

        var pack_icon := centered_label("\U0001F4E6", Vector2(18, 55), Vector2(169, 46), 30, panel)
        var reward_text := "%d CARD PACK%s" % [int(reward["packs"]), "" if int(reward["packs"]) == 1 else "S"]
        if int(reward["vials"]) > 0:
            reward_text += "\n+ %d VIALS" % int(reward["vials"])
        var reward_label := label(reward_text, Vector2(18,104), Vector2(169,80), 19, panel); reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; reward_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

        var state := "UP NEXT"
        if is_claimed:
            state = "\u2713 CLAIMED"
        elif is_today:
            state = "TODAY — READY"
        var state_style := StyleBoxFlat.new()
        state_style.bg_color = Color(0.20, 0.42, 0.24, 0.9) if is_claimed else (Color(accent, 0.30) if is_today else Color(0.12, 0.14, 0.18, 0.7))
        state_style.set_corner_radius_all(10)
        var state_wrap := Panel.new(); state_wrap.position = Vector2(14, 205); state_wrap.size = Vector2(177, 40)
        state_wrap.add_theme_stylebox_override("panel", state_style); panel.add_child(state_wrap)
        var state_label := label(state, Vector2(0,0), Vector2(177,40), 15, state_wrap); state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        if is_today:
            state_label.add_theme_color_override("font_color", accent.lightened(0.4))

    var claim_button := button("CLAIM TODAY'S REWARD", Vector2(460,535), Vector2(360,68), claim_daily_reward)
    claim_button.add_theme_stylebox_override("normal", style(accent, 14))
    claim_button.disabled = not can_claim_daily_reward()
    if not can_claim_daily_reward():
        safe_set_text(claim_button, "COME BACK TOMORROW")

func claim_daily_reward() -> void:
    if not can_claim_daily_reward():
        return
    var today := current_calendar_day()
    var reward_index := normalized_daily_reward_index()
    var reward: Dictionary = DAILY_REWARDS[reward_index]
    pack_inventory += int(reward.get("packs", 0))
    dust_balance += int(reward.get("vials", 0))
    daily_last_claim_day = today
    daily_reward_day = (reward_index + 1) % DAILY_REWARDS.size()
    save_profile()
    show_daily_reward_claimed(reward_index, reward)

func show_daily_reward_claimed(reward_index: int, reward: Dictionary) -> void:
    clear_screen(); add_background(0.72)
    var p := Panel.new(); p.position=Vector2(265,115); p.size=Vector2(750,500); p.add_theme_stylebox_override("panel",style(GOLD_COLOR,22)); root_layer.add_child(p)
    var t := label("DAY %d REWARD CLAIMED" % (reward_index + 1),Vector2(50,45),Vector2(650,60),34,p); t.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; t.add_theme_color_override("font_color",GOLD_COLOR)
    var reward_text := "%d CARD PACK%s" % [int(reward.get("packs",0)), "" if int(reward.get("packs",0)) == 1 else "S"]
    if int(reward.get("vials",0)) > 0:
        reward_text += "\n%d RECOVERY VIALS" % int(reward.get("vials",0))
    var r := label(reward_text,Vector2(95,150),Vector2(560,150),30,p); r.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; r.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
    label("Your next reward unlocks tomorrow.",Vector2(95,325),Vector2(560,44),19,p).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    button("RETURN HOME",Vector2(245,405),Vector2(260,58),show_home,p)

func show_first_day_intro() -> void:
    clear_screen(); add_background(0.68)
    header("RECOVERY ACADEMY", "Choose a class, learn its growth resource, then complete a real training battle")

    var intro := centered_label("Each class grows differently. Pick the path you want to learn first.", Vector2(170, 88), Vector2(940, 48), 20)
    intro.add_theme_color_override("font_color", Color(0.96,0.91,0.72))

    var resource_names := {"Courage":"RESOLVE", "Hope":"HOPE", "Serenity":"PEACE", "Purpose":"PROGRESS"}
    var resource_text := {
        "Courage":"Build Resolve by fighting, surviving combat, and defeating enemy followers.",
        "Hope":"Build Hope through healing, recovery, and returning followers from the Relapse Zone.",
        "Serenity":"Build Peace through patience, healing, and Recovery Skills.",
        "Purpose":"Build Progress through discipline and spending your Play Points efficiently."
    }
    var battle_lessons := {
        "Courage":"TRAINING FOCUS: Trade followers, build Resolve, then spend it to seize the board.",
        "Hope":"TRAINING FOCUS: Heal, recover a follower, and outlast the opposing deck.",
        "Serenity":"TRAINING FOCUS: Play a Recovery Skill, build Peace, and grow your board through healing.",
        "Purpose":"TRAINING FOCUS: Spend all Play Points, build Progress, and reach Walking Free."
    }

    for i in range(CLASSES.size()):
        var c: String = CLASSES[i]
        var panel := Panel.new()
        panel.position = Vector2(30 + i * 310, 150)
        panel.size = Vector2(286, 465)
        panel.add_theme_stylebox_override("panel", style(class_color(c), 18))
        root_layer.add_child(panel)

        var art := TextureRect.new()
        art.texture = load("res://assets/leaders/%s.png" % c.to_lower())
        art.position = Vector2(45, 18)
        art.size = Vector2(196, 176)
        art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        panel.add_child(art)

        var class_title := centered_label(c.to_upper(), Vector2(18, 198), Vector2(250, 38), 25, panel)
        class_title.add_theme_color_override("font_color", class_color(c).lightened(0.25))
        var resource_title := centered_label(str(resource_names[c]), Vector2(25, 242), Vector2(236, 34), 18, panel)
        resource_title.add_theme_color_override("font_color", GOLD_COLOR)
        var resource_body := centered_label(str(resource_text[c]), Vector2(24, 280), Vector2(238, 78), 15, panel)
        resource_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        var focus := centered_label(str(battle_lessons[c]), Vector2(22, 356), Vector2(242, 62), 13, panel)
        focus.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        focus.add_theme_color_override("font_color", Color(0.80,0.88,1.0))
        var cfg := ConfigFile.new(); cfg.load(SAVE_PATH)
        var completed := bool(cfg.get_value("academy", "class_%s_complete" % c.to_lower(), false))
        var train_text := "REPLAY ✓" if completed else "TRAIN AS " + c.to_upper()
        button(train_text, Vector2(45, 420), Vector2(196, 38), func(): begin_class_training(c), panel)

    button("HOME", Vector2(560, 642), Vector2(160, 42), show_home)

func begin_class_training(class_name_value: String) -> void:
    selected_class = class_name_value
    selected_deck_class = class_name_value
    var opponent_map := {"Courage":"Serenity", "Hope":"Courage", "Serenity":"Purpose", "Purpose":"Hope"}
    var cfg := ConfigFile.new()
    cfg.set_value("battle", "mode", "training")
    cfg.set_value("battle", "your_class", class_name_value)
    cfg.set_value("battle", "opponent_class", str(opponent_map.get(class_name_value, "Courage")))
    cfg.set_value("battle", "your_deck_mode", "prebuilt")
    cfg.set_value("battle", "opponent_deck_mode", "prebuilt")
    cfg.set_value("training", "class", class_name_value)
    cfg.save("user://battle_setup.cfg")
    await _show_battle_intro(class_name_value, str(opponent_map.get(class_name_value, "Courage")))

func begin_academy() -> void:
    academy_step = 0
    academy_action_stage = 0
    show_academy_lesson()

func centered_label(text_value: String, pos: Vector2, size_value: Vector2, font_size := 18, parent: Control = root_layer) -> Label:
    var l := label(text_value, pos, size_value, font_size, parent)
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    return l

func academy_card(title_text: String, subtitle: String, pos: Vector2, border: Color, callback: Callable, parent: Control) -> Button:
    var b := button(title_text + "\n" + subtitle, pos, Vector2(180, 118), callback, parent)
    b.add_theme_font_size_override("font_size", ui_font_size(16))
    b.add_theme_stylebox_override("normal", style(border, 14))
    b.add_theme_stylebox_override("hover", style(border.lightened(0.22), 14))
    return b

func academy_feedback_text(text_value: String, positive := true) -> void:
    if academy_feedback != null and is_instance_valid(academy_feedback):
        academy_feedback.text = text_value
        academy_feedback.add_theme_color_override("font_color", Color(0.55, 1.0, 0.70) if positive else Color(1.0, 0.55, 0.55))

func show_academy_lesson() -> void:
    clear_screen(); add_background(0.68)
    academy_action_stage = 0
    var lesson_titles := ["PROVING YOURSELF", "THE BATTLEFIELD", "PLAY A FOLLOWER", "COMBAT", "SPELLS & AMULETS", "RECOVERY & REVIVE", "SPONSOR & SPONSEE"]
    var mentors := ["Purpose Champion", "Hope Mentor", "Courage Veteran", "Courage Veteran", "Serenity Guardian", "Hope Mentor", "Purpose Champion"]
    header(lesson_titles[academy_step], "Lesson %d of 7 • %s" % [academy_step + 1, mentors[academy_step]])

    var board := Panel.new()
    board.position = Vector2(95, 126)
    board.size = Vector2(1090, 535)
    board.add_theme_stylebox_override("panel", style(class_color(CLASSES[academy_step % CLASSES.size()]), 20))
    root_layer.add_child(board)

    var instruction := centered_label("", Vector2(70, 24), Vector2(950, 78), 21, board)
    instruction.add_theme_color_override("font_color", Color(0.96,0.93,0.82))
    academy_feedback = centered_label("Complete the highlighted actions to continue.", Vector2(170, 456), Vector2(750, 48), 18, board)

    match academy_step:
        0:
            instruction.text = "Use Second Chance, understand its cost, then spend Momentum yourself."
            build_second_chance_lesson(board)
        1:
            instruction.text = "Learn the battlefield by selecting each important zone."
            build_zone_lesson(board)
        2:
            instruction.text = "Spend Play Points to place a follower onto the battlefield."
            build_play_follower_lesson(board)
        3:
            instruction.text = "Attack an enemy follower, then finish by striking the enemy leader."
            build_combat_lesson(board)
        4:
            instruction.text = "Cast a spell for an immediate effect, then play an Amulet for ongoing value."
            build_spell_amulet_lesson(board)
        5:
            instruction.text = "Move a follower to the Relapse Zone, recover it, then see how overdraw is Revived."
            build_recovery_lesson(board)
        6:
            instruction.text = "Play Sponsor, choose a Sponsee, and trigger the protective bond."
            build_sponsor_lesson(board)

func build_second_chance_lesson(board: Control) -> void:
    var selected: Array[int] = []
    var card_buttons: Array[Button] = []
    var controls := {"confirm": null, "momentum": null}
    var costs := [8, 7, 6, 2]
    var names := ["Purpose Eternal", "Architect of Tomorrow", "Grand Design", "Vision Board"]

    for i in range(4):
        var index := i
        var b := academy_card(names[i], "%d PP" % costs[i], Vector2(105 + i * 220, 130), class_color("Purpose"), func():
            if academy_action_stage != 0:
                return
            var target: Button = null
            if index >= 0 and index < card_buttons.size():
                target = card_buttons[index]
            if selected.has(index):
                selected.erase(index)
                if is_instance_valid(target):
                    target.modulate = Color.WHITE
            else:
                selected.append(index)
                if is_instance_valid(target):
                    target.modulate = Color(0.58, 0.86, 1.0)
            var momentum_value := 0 if selected.size() <= 1 else (1 if selected.size() <= 3 else 2)
            academy_feedback_text("%d selected • Opponent would gain %d Momentum." % [selected.size(), momentum_value])
            var confirm_button = controls.get("confirm")
            if is_instance_valid(confirm_button):
                confirm_button.disabled = selected.is_empty()
        , board)
        card_buttons.append(b)

    var momentum_button := button("MOMENTUM LOCKED", Vector2(420, 370), Vector2(250, 62), func():
        if academy_action_stage != 1:
            return
        academy_action_stage = 2
        var current_momentum = controls.get("momentum")
        if is_instance_valid(current_momentum):
            current_momentum.disabled = true
            current_momentum.text = "MOMENTUM USED  ✓"
        academy_feedback_text("Momentum gives +1 temporary Play Point for one turn. Proving Yourself complete.")
        call_deferred("lesson_complete")
    , board)
    momentum_button.disabled = true
    controls["momentum"] = momentum_button

    var confirm_button := button("USE SECOND CHANCE", Vector2(370, 285), Vector2(350, 65), func():
        if academy_action_stage != 0 or selected.is_empty():
            return
        academy_action_stage = 1
        for i in range(card_buttons.size()):
            var card_button := card_buttons[i]
            if not is_instance_valid(card_button):
                continue
            if selected.has(i):
                card_button.text = "REPLACED\n↻ NEW CARD"
                card_button.modulate = Color(0.70, 1.0, 0.76)
            card_button.disabled = true
        var current_confirm = controls.get("confirm")
        if is_instance_valid(current_confirm):
            current_confirm.disabled = true
        var momentum_value := 0 if selected.size() <= 1 else (1 if selected.size() <= 3 else 2)
        academy_feedback_text("Second Chance complete. The opponent earned %d Momentum. Now activate Momentum." % momentum_value)
        var current_momentum = controls.get("momentum")
        if is_instance_valid(current_momentum):
            current_momentum.disabled = false
            current_momentum.text = "ACTIVATE MOMENTUM\n+1 TEMPORARY PP"
    , board)
    confirm_button.disabled = true
    controls["confirm"] = confirm_button

func lesson_complete() -> void:
    academy_feedback_text("Lesson complete — moving forward.")
    await get_tree().create_timer(0.55).timeout
    academy_step += 1
    academy_action_stage = 0
    save_profile()
    if academy_step >= 7:
        show_academy_graduation()
    else:
        show_academy_lesson()

func build_zone_lesson(board: Control) -> void:
    var selected := {"leader":false, "hand":false, "deck":false, "relapse":false, "points":false}
    var counter := [0]
    var make_zone := func(text_value: String, pos: Vector2, key: String):
        var b: Button
        b = button(text_value, pos, Vector2(170, 70), func():
            if selected[key]: return
            selected[key] = true
            counter[0] += 1
            if is_instance_valid(b):
                b.disabled = true
                b.text += "  ✓"
            academy_feedback_text("%s identified. %d of 5 zones found." % [text_value, counter[0]])
            if counter[0] == 5: lesson_complete()
        , board)
    make_zone.call("YOUR LEADER\n20 DEFENSE", Vector2(90, 130), "leader")
    make_zone.call("YOUR HAND\nCards available", Vector2(290, 320), "hand")
    make_zone.call("YOUR DECK\nCards remaining", Vector2(830, 130), "deck")
    make_zone.call("RELAPSE ZONE\nFallen followers", Vector2(830, 320), "relapse")
    make_zone.call("PLAY POINTS\n3 / 3", Vector2(90, 320), "points")

func build_play_follower_lesson(board: Control) -> void:
    centered_label("PLAY POINTS: 2 / 2", Vector2(65, 122), Vector2(220, 54), 22, board)
    var field := Panel.new(); field.position=Vector2(390,126); field.size=Vector2(310,180); field.add_theme_stylebox_override("panel",style(Color(0.25,0.65,0.45),16)); board.add_child(field)
    centered_label("YOUR BATTLEFIELD\n(empty)",Vector2(20,45),Vector2(270,90),20,field)
    var card: Button
    card = academy_card("NEWCOMER", "2 Cost • 2/2", Vector2(130, 280), class_color("Hope"), func():
        if academy_action_stage != 0: return
        academy_action_stage = 1
        if is_instance_valid(card):
            card.disabled = true
            card.text = "NEWCOMER\nPLAYED ✓"
        var field_label := field.get_child(0) if field.get_child_count() > 0 else null
        safe_set_text(field_label, "NEWCOMER\n2 ATTACK • 2 DEFENSE")
        academy_feedback_text("You spent 2 Play Points and placed a follower. Followers normally wait one turn before attacking.")
        await get_tree().create_timer(0.8).timeout
        lesson_complete()
    , board)
    centered_label("Click the card to play it.", Vector2(340, 354), Vector2(410, 40), 18, board)

func build_combat_lesson(board: Control) -> void:
    var ally: Button
    ally = academy_card("COURAGE ROOKIE", "3/3 • Ready", Vector2(160, 270), class_color("Courage"), func():
        academy_feedback_text("Select a target first.", false)
    , board)
    var enemy: Button
    enemy = academy_card("ENEMY GUARD", "2/2", Vector2(455, 125), Color(0.85,0.30,0.25), func():
        if academy_action_stage != 0: return
        academy_action_stage = 1
        if is_instance_valid(enemy):
            enemy.disabled = true
            enemy.text = "ENEMY GUARD\nDEFEATED ✓"
        if is_instance_valid(ally):
            ally.text = "COURAGE ROOKIE\n3/1 • Ready"
        academy_feedback_text("Good trade. Your follower survived combat and may now attack the leader in this lesson.")
    , board)
    var leader: Button
    leader = button("ENEMY LEADER\n20 DEFENSE", Vector2(745,125), Vector2(210,118), func():
        if academy_action_stage == 0:
            academy_feedback_text("Defeat the enemy guard before attacking the leader.", false)
            return
        if academy_action_stage != 1: return
        academy_action_stage = 2
        if is_instance_valid(leader):
            leader.text = "ENEMY LEADER\n17 DEFENSE"
        if is_instance_valid(ally):
            ally.disabled = true
        academy_feedback_text("Direct hit! The enemy leader lost 3 defense.")
        await get_tree().create_timer(0.8).timeout
        lesson_complete()
    , board)
    centered_label("1. Click ENEMY GUARD   2. Click ENEMY LEADER", Vector2(260,405), Vector2(570,38), 18, board)

func build_spell_amulet_lesson(board: Control) -> void:
    var status := centered_label("Enemy follower: 4/4\nOngoing effects: none",Vector2(415,125),Vector2(280,125),20,board)
    var spell: Button
    spell = academy_card("DEEP BREATH", "Spell • Freeze enemy", Vector2(120,285), class_color("Serenity"), func():
        if academy_action_stage != 0: return
        academy_action_stage = 1
        if is_instance_valid(spell):
            spell.disabled = true
            spell.text = "DEEP BREATH\nCAST ✓"
        safe_set_text(status, "Enemy follower: 4/4\nFROZEN — cannot attack")
        academy_feedback_text("Spells resolve immediately and then leave play. Now play the Amulet.")
    , board)
    var amulet: Button
    amulet = academy_card("HOME GROUP", "Amulet • Ongoing healing", Vector2(790,285), GOLD_COLOR, func():
        if academy_action_stage != 1:
            academy_feedback_text("Cast Deep Breath first.", false)
            return
        academy_action_stage = 2
        if is_instance_valid(amulet):
            amulet.disabled = true
            amulet.text = "HOME GROUP\nACTIVE ✓"
        if is_instance_valid(status):
            status.text += "\nHome Group: restore 1 each turn"
        academy_feedback_text("Amulets stay in play and keep providing value.")
        await get_tree().create_timer(0.8).timeout
        lesson_complete()
    , board)

func build_recovery_lesson(board: Control) -> void:
    var status := centered_label("BATTLEFIELD\nONE DAY AT A TIME • 2/2",Vector2(375,105),Vector2(340,100),20,board)
    var relapse: Button
    relapse = button("RELAPSE ZONE\n0 cards",Vector2(100,285),Vector2(220,95),func():
        if academy_action_stage != 0: return
        academy_action_stage = 1
        safe_set_text(relapse, "RELAPSE ZONE\n1 card")
        safe_set_text(status, "BATTLEFIELD\n(empty)")
        academy_feedback_text("The follower entered the Relapse Zone. Now use Second Chance.")
    ,board)
    var recover: Button
    recover = button("SECOND CHANCE\nRecover a follower",Vector2(435,285),Vector2(220,95),func():
        if academy_action_stage != 1:
            academy_feedback_text("Move the follower into the Relapse Zone first.", false)
            return
        academy_action_stage = 2
        safe_set_text(relapse, "RELAPSE ZONE\n0 cards")
        safe_set_text(status, "BATTLEFIELD\nONE DAY AT A TIME • 3/3")
        if is_instance_valid(recover):
            recover.disabled = true
        academy_feedback_text("Recovered followers can return stronger. Now test an overdraw.")
    ,board)
    var overdraw: Button
    overdraw = button("DRAW AT 10 / 10\nTest overdraw",Vector2(770,285),Vector2(220,95),func():
        if academy_action_stage != 2:
            academy_feedback_text("Recover the follower first.", false)
            return
        academy_action_stage = 3
        safe_set_text(overdraw, "REVIVED ✓\nCard moved to deck bottom")
        academy_feedback_text("A full hand never destroys the card. It is Revived to the bottom of the deck.")
        await get_tree().create_timer(0.9).timeout
        lesson_complete()
    ,board)

func build_sponsor_lesson(board: Control) -> void:
    var sponsor: Button
    sponsor = academy_card("THE SPONSOR", "Signature Platinum", Vector2(120,275), GOLD_COLOR, func():
        if academy_action_stage != 0: return
        academy_action_stage = 1
        safe_set_text(sponsor, "THE SPONSOR\nIN PLAY ✓")
        academy_feedback_text("Sponsor entered play. Choose another allied follower as the Sponsee.")
    ,board)
    var sponsee: Button
    sponsee = academy_card("NEWCOMER", "Choose as Sponsee", Vector2(455,275), class_color("Hope"), func():
        if academy_action_stage != 1:
            academy_feedback_text("Play The Sponsor first.", false)
            return
        academy_action_stage = 2
        safe_set_text(sponsee, "SPONSEE\n4/4 • BONDED ✓")
        academy_feedback_text("The bond is active. Trigger protection to save the Sponsee from destruction.")
    ,board)
    var protect: Button
    protect = button("ENEMY STRIKE\nDeal lethal damage",Vector2(790,285),Vector2(220,95),func():
        if academy_action_stage != 2:
            academy_feedback_text("Choose the Sponsee first.", false)
            return
        academy_action_stage = 3
        safe_set_text(protect, "PROTECTED ✓\nSponsee survives at 1")
        safe_set_text(sponsee, "SPONSEE\n4/1 • PROTECTED")
        academy_feedback_text("The Sponsor protected its Sponsee. Build-around cards make this bond even stronger.")
        await get_tree().create_timer(1.0).timeout
        lesson_complete()
    ,board)

func show_academy_graduation() -> void:
    clear_screen(); add_background(0.58)
    var p := Panel.new(); p.position=Vector2(220,72); p.size=Vector2(840,575); p.add_theme_stylebox_override("panel",style(GOLD_COLOR,22)); root_layer.add_child(p)
    var t := label("THE FIRST DAY COMPLETE",Vector2(40,42),Vector2(760,58),34,p); t.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; t.add_theme_color_override("font_color",GOLD_COLOR)
    label("You learned the foundations of WF Sober CCG.",Vector2(80,125),Vector2(680,50),21,p).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    label("YOUR REWARD\n\nChoose one legal 40-card starter deck\n500 Gold",Vector2(120,210),Vector2(600,150),27,p).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    if academy_complete:
        label("Training already completed — rewards can only be claimed once.",Vector2(130,390),Vector2(580,45),17,p).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
        button("RETURN HOME",Vector2(270,470),Vector2(300,58),show_home,p)
    else:
        button("CHOOSE YOUR STARTER DECK",Vector2(220,455),Vector2(400,64),show_graduation_class_choice,p)

func show_graduation_class_choice() -> void:
    clear_screen(); add_background(0.70); header("CHOOSE YOUR PATH","Your reward is one exact 40-card starter deck and 500 Gold")
    for i in range(CLASSES.size()):
        var c: String = CLASSES[i]
        var panel := Panel.new(); panel.position=Vector2(42+i*310,154); panel.size=Vector2(286,430); panel.add_theme_stylebox_override("panel",style(class_color(c),16)); root_layer.add_child(panel)
        var art := TextureRect.new(); art.texture=load("res://assets/leaders/%s.png" % c.to_lower()); art.position=Vector2(31,22); art.size=Vector2(224,224); art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; panel.add_child(art)
        var n := label(c.to_upper(),Vector2(23,260),Vector2(240,38),25,panel); n.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; n.add_theme_color_override("font_color",class_color(c).lightened(0.25))
        label(class_description(c),Vector2(24,307),Vector2(238,58),15,panel).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
        button("CLAIM DECK",Vector2(48,374),Vector2(190,42),func(): graduate_with_class(c),panel)

func graduate_with_class(c: String) -> void:
    selected_class = c
    selected_deck_class = c
    grant_starter_collection(c)
    build_starter_deck(c)
    academy_complete = true
    academy_step = 7
    if not academy_reward_claimed:
        gold_balance += 500
        academy_reward_claimed = true
    save_profile()
    show_home()

func start_developer_meta_battle(c: String) -> void:
    if not AccessManager.role_at_least(AccessManager.ROLE_OWNER):
        return
    launch_selected_battle(c, "meta")

func start_developer_final_boss_battle() -> void:
    if not AccessManager.role_at_least(AccessManager.ROLE_OWNER):
        return
    launch_selected_battle(selected_class if selected_class != "" else "Purpose", "final_boss")

func launch_selected_battle(c: String, deck_mode: String, opponent_class_value: String = "Courage", opponent_mode_value: String = "prebuilt") -> void:
    selected_class = c
    var cfg := ConfigFile.new()
    cfg.set_value("battle","mode","ai")
    cfg.set_value("battle","your_class",c)
    cfg.set_value("battle","your_deck_mode",deck_mode)
    cfg.set_value("battle","opponent_class",opponent_class_value)
    # Computer opponents are always restricted to legal prebuilt decks.
    opponent_mode_value = "prebuilt"
    cfg.set_value("battle","opponent_deck_mode",opponent_mode_value)
    cfg.set_value("battle","developer_meta",deck_mode == "meta")
    cfg.save("user://battle_setup.cfg")
    await _show_battle_intro(c, opponent_class_value)


func _show_battle_intro(player_class_name: String, opponent_class_name: String) -> void:
    # Premium versus transition before the battlefield loads.
    var intro := ColorRect.new()
    intro.color = Color(0.005, 0.008, 0.018, 1.0)
    intro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    intro.z_index = 5000
    intro.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(intro)

    var title := Label.new()
    title.text = "WALKING FREE CCG\nJOURNEY'S DAWN"
    title.position = Vector2(390, 44)
    title.size = Vector2(500, 90)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", ui_font_size(28))
    title.add_theme_color_override("font_color", GOLD_COLOR)
    intro.add_child(title)

    var left_art := TextureRect.new()
    left_art.texture = load("res://assets/leaders/%s.png" % player_class_name.to_lower())
    left_art.position = Vector2(105, 165)
    left_art.size = Vector2(390, 390)
    left_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    left_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    left_art.modulate = Color(1,1,1,0)
    intro.add_child(left_art)

    var right_art := TextureRect.new()
    right_art.texture = load("res://assets/leaders/%s.png" % opponent_class_name.to_lower())
    right_art.position = Vector2(785, 165)
    right_art.size = Vector2(390, 390)
    right_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    right_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    right_art.modulate = Color(1,1,1,0)
    intro.add_child(right_art)

    var left_name := centered_label(player_class_name.to_upper(), Vector2(120, 575), Vector2(360, 44), 25, intro)
    left_name.add_theme_color_override("font_color", class_color(player_class_name).lightened(0.25))
    var right_name := centered_label(opponent_class_name.to_upper(), Vector2(800, 575), Vector2(360, 44), 25, intro)
    right_name.add_theme_color_override("font_color", class_color(opponent_class_name).lightened(0.25))
    var vs := centered_label("VS", Vector2(540, 290), Vector2(200, 100), 64, intro)
    vs.add_theme_color_override("font_color", GOLD_COLOR)
    vs.scale = Vector2(0.35, 0.35)
    vs.pivot_offset = vs.size * 0.5

    var tween := create_tween().set_parallel(true)
    tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(left_art, "position:x", 155.0, 0.45)
    tween.tween_property(left_art, "modulate:a", 1.0, 0.35)
    tween.tween_property(right_art, "position:x", 735.0, 0.45)
    tween.tween_property(right_art, "modulate:a", 1.0, 0.35)
    tween.tween_property(vs, "scale", Vector2.ONE, 0.5)
    await tween.finished
    await get_tree().create_timer(1.15).timeout
    AudioManager.stop_music(0.55)
    var fade := create_tween()
    fade.tween_property(intro, "modulate:a", 0.0, 0.55)
    await fade.finished
    get_tree().change_scene_to_file("res://battle.tscn")

func _battle_selection_set_class(class_name_value: String) -> void:
    battle_select_class = class_name_value
    show_match_deck_selection()

func _battle_selection_set_opponent_class(class_name_value: String) -> void:
    battle_opponent_class = class_name_value
    show_match_deck_selection()

func _battle_selection_set_mode(mode_value: String) -> void:
    battle_select_mode = mode_value
    show_match_deck_selection()

func _battle_selection_set_opponent_mode(_mode_value: String) -> void:
    battle_opponent_mode = "prebuilt"
    show_match_deck_selection()

func _battle_selection_start() -> void:
    battle_opponent_mode = "prebuilt"
    launch_selected_battle(battle_select_class, battle_select_mode, battle_opponent_class, "prebuilt")

func _battle_preview_deck_ids(class_name_value: String, mode_value: String) -> Array:
    if mode_value == "custom":
        var current: Array = Array(saved_decks.get(class_name_value, []))
        if not current.is_empty():
            return current.duplicate()
    if mode_value == "meta":
        var meta_recipe: Dictionary = {}
        match class_name_value:
            "Courage":
                meta_recipe = {
                    "JD-030":1, "JD-016":3, "JD-017":3, "JD-018":3,
                    "JD-020":3, "JD-021":3, "JD-022":3, "JD-025":3,
                    "JD-026":2, "JD-029":2, "JD-089":3, "JD-090":3,
                    "JD-091":3, "JD-092":2
                }
            "Hope":
                meta_recipe = {
                    "JD-015":1, "JD-121":3, "JD-001":3, "JD-002":3,
                    "JD-003":3, "JD-005":3, "JD-006":3, "JD-007":3,
                    "JD-009":3, "JD-011":2, "JD-013":2, "JD-081":3,
                    "JD-082":3, "JD-083":2
                }
            "Serenity":
                meta_recipe = {
                    "JD-045":1, "JD-123":3, "JD-031":3, "JD-032":3,
                    "JD-033":3, "JD-034":3, "JD-035":3, "JD-036":3,
                    "JD-038":3, "JD-039":3, "JD-040":3, "JD-042":2,
                    "JD-043":2, "JD-098":2
                }
            "Purpose":
                meta_recipe = {
                    "JD-060":1, "JD-080":1, "JD-122":3, "JD-078":3,
                    "JD-061":3, "JD-046":3, "JD-047":3, "JD-048":3,
                    "JD-051":3, "JD-054":3, "JD-110":3, "JD-114":3,
                    "JD-117":3, "JD-119":2
                }
        return _recipe_to_exact_40(meta_recipe)
    if mode_value == "final_boss":
        # Cohesive benchmark deck: Purpose Progress + Sponsor/Sponsee engine.
        var boss_recipe := {
            "JD-046":3, "JD-047":3, "JD-048":3, "JD-049":3,
            "JD-051":3, "JD-054":3, "JD-057":2, "JD-060":1,
            "JD-061":3, "JD-078":3, "JD-080":1, "JD-110":2,
            "JD-114":3, "JD-117":2, "JD-119":2, "JD-077":2
        }
        return _recipe_to_exact_40(boss_recipe)
    var recipe: Dictionary = starter_recipe(class_name_value)
    var result: Array = []
    for card_id in recipe.keys():
        for _copy_index in range(int(recipe[card_id])):
            result.append(str(card_id))
    return result

func _recipe_to_exact_40(recipe: Dictionary) -> Array:
    var result: Array = []
    for card_id in recipe.keys():
        for _i in range(int(recipe[card_id])):
            if result.size() < 40:
                result.append(str(card_id))
    # Fill remaining slots with legal low-cost neutral consistency cards.
    var fillers := ["JD-061", "JD-071", "JD-072", "JD-073"]
    var fi := 0
    while result.size() < 40:
        result.append(fillers[fi % fillers.size()])
        fi += 1
    return result.slice(0, 40)

func _battle_preview_stats(class_name_value: String, mode_value: String) -> Dictionary:
    var ids: Array = _battle_preview_deck_ids(class_name_value, mode_value)
    var total_cost := 0
    var followers := 0
    var skills := 0
    var spells := 0
    var curve: Array = [0,0,0,0,0,0,0,0,0]
    for card_id_value in ids:
        var found: Dictionary = {}
        for card_data in cards:
            if str(card_data.get("id", "")) == str(card_id_value):
                found = Dictionary(card_data)
                break
        if found.is_empty():
            continue
        var cost_value := int(found.get("cost", 0))
        total_cost += cost_value
        curve[mini(cost_value, 8)] = int(curve[mini(cost_value, 8)]) + 1
        var type_text := str(found.get("type", "Follower")).to_lower()
        var effect_text := str(found.get("effect", "")).to_lower()
        if "amulet" in type_text or "recovery skill" in type_text or "recovery skill" in effect_text:
            skills += 1
        elif "spell" in type_text or (int(found.get("attack", 0)) == 0 and int(found.get("health", 0)) == 0):
            spells += 1
        else:
            followers += 1
    var count_value := maxi(ids.size(), 1)
    return {
        "count": ids.size(),
        "average": float(total_cost) / float(count_value),
        "followers": followers,
        "skills": skills,
        "spells": spells,
        "curve": curve
    }

func show_match_deck_selection() -> void:
    if battle_select_class == "":
        battle_select_class = selected_class if selected_class != "" else "Hope"
    if battle_opponent_class == "":
        battle_opponent_class = "Courage"
    if battle_select_mode != "custom" and not AccessManager.role_at_least(AccessManager.ROLE_OWNER):
        battle_select_mode = "custom"
    battle_opponent_mode = "prebuilt"

    clear_screen()
    add_background(0.78)
    header("BATTLE PREPARATION", "Choose leaders and decks, preview them, then begin battle.")

    var shell := Panel.new()
    shell.position = Vector2(28, 108)
    shell.size = Vector2(1224, 566)
    shell.add_theme_stylebox_override("panel", style(Color(0.20, 0.31, 0.48), 18))
    root_layer.add_child(shell)

    # Class selectors stay above their own side and never overlap portraits.
    centered_label("YOUR LEADER", Vector2(28, 12), Vector2(340, 28), 18, shell).add_theme_color_override("font_color", GOLD_COLOR)
    centered_label("OPPONENT", Vector2(856, 12), Vector2(340, 28), 18, shell).add_theme_color_override("font_color", GOLD_COLOR)
    for i in range(CLASSES.size()):
        var c: String = CLASSES[i]
        var left_b := Button.new()
        left_b.position = Vector2(28 + (i % 2) * 164, 46 + (i / 2) * 44)
        left_b.size = Vector2(154, 38)
        left_b.text = c.to_upper()
        left_b.add_theme_font_size_override("font_size", ui_font_size(12))
        left_b.add_theme_stylebox_override("normal", style(class_color(c).lightened(0.10) if c == battle_select_class else Color(0.08,0.12,0.19), 8))
        left_b.add_theme_color_override("font_color", Color.WHITE)
        left_b.pressed.connect(func(): _battle_selection_set_class(c))
        shell.add_child(left_b)

        var right_b := Button.new()
        right_b.position = Vector2(868 + (i % 2) * 164, 46 + (i / 2) * 44)
        right_b.size = Vector2(154, 38)
        right_b.text = c.to_upper()
        right_b.add_theme_font_size_override("font_size", ui_font_size(12))
        right_b.add_theme_stylebox_override("normal", style(class_color(c).lightened(0.10) if c == battle_opponent_class else Color(0.08,0.12,0.19), 8))
        right_b.add_theme_color_override("font_color", Color.WHITE)
        right_b.pressed.connect(func(): _battle_selection_set_opponent_class(c))
        shell.add_child(right_b)

    _build_battle_leader_panel(battle_select_class, "YOUR LEADER", Vector2(28, 142), shell, false)
    _build_battle_leader_panel(battle_opponent_class, "COMPUTER", Vector2(868, 142), shell, true)

    var center := Panel.new()
    center.position = Vector2(386, 20)
    center.size = Vector2(452, 466)
    center.add_theme_stylebox_override("panel", style(Color(0.30, 0.43, 0.66), 16))
    shell.add_child(center)
    centered_label("VS", Vector2(176, 8), Vector2(100, 44), 30, center).add_theme_color_override("font_color", GOLD_COLOR)

    var your_stats: Dictionary = _battle_preview_stats(battle_select_class, battle_select_mode)
    var opp_stats: Dictionary = _battle_preview_stats(battle_opponent_class, "prebuilt")

    centered_label("YOUR DECK", Vector2(18, 58), Vector2(198, 28), 16, center)
    centered_label("AI DECK", Vector2(236, 58), Vector2(198, 28), 16, center)

    var your_modes: Array = [{"id":"custom", "label":"MY DECK"}]
    if AccessManager.role_at_least(AccessManager.ROLE_OWNER):
        your_modes.append({"id":"meta", "label":"DEV META"})
        your_modes.append({"id":"final_boss", "label":"FINAL BOSS"})
    for i in range(your_modes.size()):
        var option: Dictionary = Dictionary(your_modes[i])
        var mode_id := str(option.get("id", "custom"))
        var b := Button.new()
        b.position = Vector2(18, 92 + i * 45)
        b.size = Vector2(198, 38)
        b.text = str(option.get("label", "DECK"))
        b.add_theme_font_size_override("font_size", ui_font_size(11))
        b.add_theme_stylebox_override("normal", style(GOLD_COLOR if mode_id == battle_select_mode else Color(0.20,0.30,0.48), 8))
        if mode_id == battle_select_mode: b.add_theme_color_override("font_color", Color(0.04,0.06,0.10))
        b.pressed.connect(func(): _battle_selection_set_mode(mode_id))
        center.add_child(b)

    var ai_badge := Button.new()
    ai_badge.position = Vector2(236, 92)
    ai_badge.size = Vector2(198, 38)
    ai_badge.text = "LEGAL PREBUILT"
    ai_badge.disabled = true
    ai_badge.add_theme_stylebox_override("disabled", style(Color(0.18,0.28,0.44), 8))
    center.add_child(ai_badge)

    centered_label("%s • %d CARDS" % [battle_select_class.to_upper(), int(your_stats.get("count",0))], Vector2(18, 236), Vector2(198, 26), 13, center).add_theme_color_override("font_color", class_color(battle_select_class).lightened(0.25))
    centered_label("%s • %d CARDS" % [battle_opponent_class.to_upper(), int(opp_stats.get("count",0))], Vector2(236, 236), Vector2(198, 26), 13, center).add_theme_color_override("font_color", class_color(battle_opponent_class).lightened(0.25))
    centered_label("AVG %.1f  •  F %d  •  S %d" % [float(your_stats.get("average",0.0)), int(your_stats.get("followers",0)), int(your_stats.get("skills",0))], Vector2(14, 268), Vector2(206, 24), 11, center)
    centered_label("AVG %.1f  •  F %d  •  S %d" % [float(opp_stats.get("average",0.0)), int(opp_stats.get("followers",0)), int(opp_stats.get("skills",0))], Vector2(232, 268), Vector2(206, 24), 11, center)
    _draw_curve(center, Array(your_stats.get("curve", [])), Vector2(18, 320), class_color(battle_select_class), 198)
    _draw_curve(center, Array(opp_stats.get("curve", [])), Vector2(236, 320), class_color(battle_opponent_class), 198)
    button("PREVIEW YOUR DECK", Vector2(18, 414), Vector2(198, 38), func(): _show_battle_deck_preview(battle_select_class, battle_select_mode, false), center)
    button("PREVIEW OPPONENT", Vector2(236, 414), Vector2(198, 38), func(): _show_battle_deck_preview(battle_opponent_class, "prebuilt", true), center)

    button("BACK", Vector2(28, 506), Vector2(180, 44), show_home, shell)
    var begin := button("BEGIN BATTLE", Vector2(306, 498), Vector2(612, 54), _battle_selection_start, shell)
    begin.add_theme_font_size_override("font_size", ui_font_size(21))
    begin.add_theme_stylebox_override("normal", style(GOLD_COLOR, 14))
    begin.add_theme_color_override("font_color", Color(0.04,0.06,0.10))

func _show_battle_deck_preview(class_name_value: String, mode_value: String, opponent_preview: bool) -> void:
    if opponent_preview:
        mode_value = "prebuilt"
    clear_screen()
    add_background(0.82)
    var side_title := "OPPONENT DECK PREVIEW" if opponent_preview else "YOUR DECK PREVIEW"
    header(side_title, "%s • %s" % [class_name_value.to_upper(), ("LEGAL PREBUILT" if opponent_preview else mode_value.to_upper())])

    var panel := Panel.new()
    panel.position = Vector2(84, 106)
    panel.size = Vector2(1112, 560)
    panel.add_theme_stylebox_override("panel", style(class_color(class_name_value), 20))
    root_layer.add_child(panel)

    var ids: Array = _battle_preview_deck_ids(class_name_value, mode_value)
    var counts: Dictionary = {}
    for card_id_value in ids:
        counts[str(card_id_value)] = int(counts.get(str(card_id_value), 0)) + 1

    # Every prebuilt/custom deck preview is anchored by its dedicated leader art.
    var leader_frame := Panel.new()
    leader_frame.position = Vector2(24, 58)
    leader_frame.size = Vector2(246, 430)
    leader_frame.clip_contents = true
    leader_frame.add_theme_stylebox_override("panel", style(class_color(class_name_value).lightened(0.12), 14))
    panel.add_child(leader_frame)
    var leader_art := TextureRect.new()
    leader_art.texture = load("res://assets/leaders/%s.png" % class_name_value.to_lower())
    leader_art.position = Vector2(10, 10)
    leader_art.size = Vector2(226, 226)
    leader_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    leader_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    leader_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    leader_frame.add_child(leader_art)
    centered_label(class_name_value.to_upper(), Vector2(10, 246), Vector2(226, 34), 22, leader_frame).add_theme_color_override("font_color", GOLD_COLOR)
    centered_label("DEDICATED LEADER", Vector2(10, 282), Vector2(226, 24), 12, leader_frame)
    var leader_desc := centered_label(class_description(class_name_value), Vector2(18, 314), Vector2(210, 70), 13, leader_frame)
    leader_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    leader_desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    centered_label("ORIGINAL LEADER ART", Vector2(10, 392), Vector2(226, 24), 11, leader_frame).add_theme_color_override("font_color", Color(0.82,0.88,1.0))

    var scroll := ScrollContainer.new()
    scroll.position = Vector2(286, 58)
    scroll.size = Vector2(800, 430)
    panel.add_child(scroll)
    var list := VBoxContainer.new()
    list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    list.add_theme_constant_override("separation", 8)
    scroll.add_child(list)

    var rows: Array = []
    for card_id in counts.keys():
        var found: Dictionary = {}
        for card_data in cards:
            if str(card_data.get("id", "")) == str(card_id):
                found = Dictionary(card_data)
                break
        if found.is_empty():
            rows.append({"name": str(card_id), "cost": 0, "rarity": "", "count": int(counts[card_id])})
        else:
            rows.append({"name": str(found.get("name", card_id)), "cost": int(found.get("cost", 0)), "rarity": str(found.get("rarity", "")), "count": int(counts[card_id])})
    rows.sort_custom(func(a: Dictionary, b: Dictionary):
        if int(a.get("cost", 0)) == int(b.get("cost", 0)):
            return str(a.get("name", "")) < str(b.get("name", ""))
        return int(a.get("cost", 0)) < int(b.get("cost", 0))
    )

    for row_data in rows:
        var row: Dictionary = Dictionary(row_data)
        var row_panel := Panel.new()
        row_panel.custom_minimum_size = Vector2(760, 42)
        row_panel.add_theme_stylebox_override("panel", style(Color(0.08,0.12,0.20,0.94), 9))
        list.add_child(row_panel)
        var cost_label := centered_label(str(row.get("cost", 0)), Vector2(8, 5), Vector2(42, 32), 18, row_panel)
        cost_label.add_theme_color_override("font_color", GOLD_COLOR)
        label("%dx  %s" % [int(row.get("count", 1)), str(row.get("name", "Card"))], Vector2(62, 7), Vector2(530, 28), 16, row_panel)
        var rarity_label := centered_label(str(row.get("rarity", "")), Vector2(566, 7), Vector2(180, 28), 13, row_panel)
        rarity_label.add_theme_color_override("font_color", Color(0.82,0.88,1.0))

    centered_label("%d cards total" % ids.size(), Vector2(30, 500), Vector2(260, 34), 15, panel)
    button("BACK TO BATTLE SETUP", Vector2(790, 500), Vector2(290, 38), show_match_deck_selection, panel)

func _build_battle_leader_panel(class_name_value: String, heading: String, panel_position: Vector2, parent: Control, dim_art: bool) -> Panel:
    var panel := Panel.new()
    panel.position = panel_position
    panel.size = Vector2(328, 344)
    panel.clip_contents = true
    panel.add_theme_stylebox_override("panel", style(Color(0.025, 0.045, 0.075, 0.98), 16))
    parent.add_child(panel)
    centered_label(heading, Vector2(14, 8), Vector2(300, 26), 15, panel).add_theme_color_override("font_color", GOLD_COLOR)

    var frame := ColorRect.new()
    frame.position = Vector2(14, 40)
    frame.size = Vector2(300, 250)
    frame.color = Color(0.02, 0.03, 0.05, 1)
    frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
    frame.clip_contents = true
    panel.add_child(frame)

    var art := TextureRect.new()
    art.texture = load("res://assets/leaders/%s.png" % class_name_value.to_lower())
    art.position = Vector2(6, 6)
    art.size = Vector2(288, 238)
    art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    if dim_art:
        art.modulate = Color(0.92, 0.94, 0.98)
    frame.add_child(art)

    var banner := Panel.new()
    banner.position = Vector2(14, 298)
    banner.size = Vector2(300, 34)
    banner.add_theme_stylebox_override("panel", style(Color(0.06,0.09,0.14,0.96), 8))
    panel.add_child(banner)
    centered_label(class_name_value.to_upper(), Vector2(4, 1), Vector2(292, 30), 20, banner).add_theme_color_override("font_color", Color.WHITE)
    return panel

func _draw_curve(parent: Control, curve: Array, origin: Vector2, curve_color: Color, width: float) -> void:
    centered_label("COST CURVE", origin + Vector2(0,-20), Vector2(width,20), 12, parent).add_theme_color_override("font_color", GOLD_COLOR)
    var safe_curve: Array = curve.duplicate()
    while safe_curve.size() < 9:
        safe_curve.append(0)
    var max_curve := 1
    for value in safe_curve:
        max_curve = maxi(max_curve, int(value))
    var step := width / 9.0
    for i in range(9):
        var bar_height := 58.0 * float(int(safe_curve[i])) / float(max_curve)
        var bar := ColorRect.new()
        bar.position = origin + Vector2(i * step + 4, 70 - bar_height)
        bar.size = Vector2(maxf(step - 8.0, 8.0), bar_height)
        bar.color = curve_color.lightened(0.15)
        parent.add_child(bar)
        var lbl := label("8+" if i == 8 else str(i), origin + Vector2(i * step, 74), Vector2(step,18), 9, parent)
        lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func start_battle() -> void:
    # Keep the recovery theme active throughout deck selection.
    ensure_home_music()
    show_match_deck_selection()

func show_class_choice() -> void:
    clear_screen()
    add_background(0.78)
    header("PREBUILT DECKS", "Choose a leader and inspect the complete legal 40-card deck before battle.")

    # Four equal hero deck panels. These intentionally mirror the home-screen
    # leader presentation instead of squeezing the art into old card frames.
    var grid := Control.new()
    grid.position = Vector2(24, 106)
    grid.size = Vector2(1232, 512)
    root_layer.add_child(grid)

    for i in range(CLASSES.size()):
        var c: String = CLASSES[i]
        var card := Panel.new()
        card.position = Vector2(i * 304, 0)
        card.size = Vector2(290, 500)
        card.clip_contents = true
        card.add_theme_stylebox_override("panel", style(Color(0.025, 0.045, 0.075, 0.98), 18))
        grid.add_child(card)

        # Dedicated clipped art viewport. Full leader composition is shown with
        # aspect-fit and can never spill into the deck information below it.
        var art_shell := Panel.new()
        art_shell.position = Vector2(10, 10)
        art_shell.size = Vector2(270, 278)
        art_shell.clip_contents = true
        art_shell.add_theme_stylebox_override("panel", style(class_color(c).darkened(0.58), 15))
        card.add_child(art_shell)

        var art := TextureRect.new()
        art.texture = load("res://assets/leaders/%s.png" % c.to_lower())
        art.position = Vector2(7, 7)
        art.size = Vector2(256, 264)
        art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
        art.mouse_filter = Control.MOUSE_FILTER_IGNORE
        art_shell.add_child(art)

        var name_bar := Panel.new()
        name_bar.position = Vector2(10, 296)
        name_bar.size = Vector2(270, 48)
        name_bar.add_theme_stylebox_override("panel", style(Color(0.035, 0.055, 0.09, 0.98), 10))
        card.add_child(name_bar)
        var title := centered_label(c.to_upper(), Vector2(4, 3), Vector2(262, 40), 23, name_bar)
        title.add_theme_color_override("font_color", class_color(c).lightened(0.28))

        centered_label("PREBUILT • 40 CARDS", Vector2(10, 350), Vector2(270, 22), 12, card).add_theme_color_override("font_color", GOLD_COLOR)

        var desc := centered_label(class_description(c), Vector2(18, 376), Vector2(254, 48), 13, card)
        desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

        var stats: Dictionary = _battle_preview_stats(c, "prebuilt")
        var stat_text := "%d Followers  •  %d Skills
Avg Cost %.1f" % [int(stats.get("followers", 0)), int(stats.get("skills", 0)), float(stats.get("average", 0.0))]
        var stat_label := centered_label(stat_text, Vector2(16, 426), Vector2(258, 36), 11, card)
        stat_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

        var selected_class_value := c
        var select_btn := button("VIEW / SELECT", Vector2(22, 464), Vector2(246, 30), func(): choose_class(selected_class_value), card)
        select_btn.add_theme_stylebox_override("normal", style(class_color(c).darkened(0.25), 9))
        select_btn.add_theme_stylebox_override("hover", style(class_color(c).lightened(0.02), 9))
        select_btn.add_theme_font_size_override("font_size", ui_font_size(12))

    button("BACK HOME", Vector2(500, 630), Vector2(280, 42), show_home, root_layer)

func class_description(c: String) -> String:
    match c:
        "Hope": return "Healing, renewal, and card advantage"
        "Courage": return "Fast attacks and relentless pressure"
        "Serenity": return "Defense, control, and protection"
        _: return "Growth, planning, and powerful finishers"

func choose_class(c: String) -> void:
    if not academy_complete:
        show_first_day_intro()
        return
    selected_class = c; selected_deck_class = c
    grant_starter_collection(c)
    build_starter_deck(c)
    save_profile(); show_home()

func grant_starter_collection(c: String) -> void:
    for card_data in cards:
        if str(card_data.get("id", "")) == "JD-080":
            continue
        if str(card_data["class"]) == c or str(card_data["class"]) == "Neutral":
            var id := str(card_data["id"])
            var limit := int(COPY_LIMITS.get(str(card_data["rarity"]),1))
            collection_owned[id] = maxi(int(collection_owned.get(id,0)), limit)

func starter_recipe(c: String) -> Dictionary:
    # v0.2.4: Every prebuilt deck is exactly 40 cards and is rebuilt to teach
    # its class resource. Cards below Legendary may use up to 3 copies,
    # Legendaries use up to 2, and the class Platinum remains a single copy.
    var recipes := {
        "Hope": {
            # Hope generators: healing, recovery, and Relapse Zone value.
            "JD-001":3, "JD-003":3, "JD-005":3, "JD-006":3, "JD-009":3,
            "JD-010":3, "JD-081":3, "JD-082":3, "JD-085":3,
            # Hope payoffs and finishers.
            "JD-007":3, "JD-012":2, "JD-015":1,
            # Neutral consistency package.
            "JD-061":3, "JD-071":2, "JD-072":2
        },
        "Courage": {
            # Resolve generators: combat, survival, and efficient trading.
            "JD-016":3, "JD-018":3, "JD-020":3, "JD-021":3, "JD-022":3,
            "JD-089":3, "JD-090":3, "JD-093":3,
            # Resolve spenders and board payoffs.
            "JD-024":3, "JD-025":3, "JD-029":2, "JD-030":1,
            # Neutral tempo package.
            "JD-061":3, "JD-071":2, "JD-073":2
        },
        "Serenity": {
            # Peace generators: patience, healing, and Recovery Skill play.
            "JD-031":3, "JD-033":3, "JD-035":3, "JD-036":3, "JD-037":3,
            "JD-097":3, "JD-098":3, "JD-101":3,
            # Peace spenders, control tools, and finishers.
            "JD-039":3, "JD-040":3, "JD-042":2, "JD-045":1,
            # Neutral sustain package.
            "JD-061":3, "JD-071":2, "JD-072":2
        },
        "Purpose": {
            # Progress engine: three copies of Daily Progress for consistency.
            "JD-046":3, "JD-047":3, "JD-048":3, "JD-049":3, "JD-054":3,
            "JD-105":3, "JD-106":3, "JD-109":3,
            # Progress support, ramp, and payoffs.
            "JD-051":3, "JD-052":3, "JD-057":2, "JD-060":1,
            # Neutral utility package.
            "JD-061":3, "JD-071":2, "JD-073":2
        }
    }
    return recipes.get(c, {})

func build_starter_deck(c: String) -> void:
    selected_deck_class = c
    saved_deck.clear()
    var recipe: Dictionary = starter_recipe(c)
    for id in recipe.keys():
        var copies := int(recipe[id])
        collection_owned[id] = maxi(int(collection_owned.get(id, 0)), copies)
        for i in range(copies):
            saved_deck.append(str(id))
    saved_decks[c] = saved_deck.duplicate()
    if saved_deck.size() != 40:
        push_error("Starter deck %s has %d cards instead of 40." % [c, saved_deck.size()])

func show_story_mode() -> void:
    clear_screen(); add_background(0.66)
    header("STORY MODE — CHAPTER 1", "Every victory moves the journey forward")
    currency_bar()
    var cfg := ConfigFile.new(); cfg.load(SAVE_PATH)
    var unlocked := int(cfg.get_value("story", "unlocked_stage", 1))

    # A connecting road behind the stage cards so the chapter reads as one
    # continuous journey instead of five disconnected panels — cleared and
    # unlocked stretches light up, the rest of the road stays dim.
    var road := ColorRect.new()
    road.color = Color(0.9, 0.82, 0.5, 0.35)
    road.position = Vector2(95, 218)
    road.size = Vector2(1090, 4)
    root_layer.add_child(road)
    for i in range(STORY_STAGES.size() - 1):
        var stage_id := int(STORY_STAGES[i]["id"])
        var lit := stage_id < unlocked or bool(cfg.get_value("story", "cleared_%d" % stage_id, false))
        var seg := ColorRect.new()
        seg.color = GOLD_COLOR if lit else Color(0.35, 0.37, 0.42, 0.4)
        seg.position = Vector2(95 + i * 234 + 5, 216)
        seg.size = Vector2(224, 8)
        root_layer.add_child(seg)

    for i in range(STORY_STAGES.size()):
        var stage: Dictionary = STORY_STAGES[i]
        var stage_id := int(stage["id"])
        var cleared := bool(cfg.get_value("story", "cleared_%d" % stage_id, false))
        var available := stage_id <= unlocked
        var pos := Vector2(60 + i * 234, 168)
        var size_value := Vector2(210, 400)

        # A round waypoint marker sitting on the road above each card — filled
        # gold when cleared, outlined when it's the current stage, dim/locked
        # otherwise — so progress reads at a glance before you even look at
        # the cards themselves.
        var marker := Panel.new()
        marker.position = Vector2(pos.x + size_value.x / 2.0 - 16, 200)
        marker.size = Vector2(32, 32)
        var marker_style := StyleBoxFlat.new()
        marker_style.set_corner_radius_all(16)
        marker_style.border_color = Color(0.05, 0.06, 0.09)
        marker_style.set_border_width_all(2)
        if cleared:
            marker_style.bg_color = GOLD_COLOR
        elif available:
            marker_style.bg_color = class_color(str(stage["class"]))
        else:
            marker_style.bg_color = Color(0.22, 0.24, 0.28)
        marker.add_theme_stylebox_override("panel", marker_style)
        root_layer.add_child(marker)
        var marker_label := label("✓" if cleared else str(stage_id), Vector2(0, 4), Vector2(32, 24), 14, marker)
        marker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

        var panel := Panel.new(); panel.position = pos; panel.size = size_value
        panel.clip_contents = false
        panel.add_theme_stylebox_override("panel", style(class_color(str(stage["class"])) if available else Color(0.18, 0.20, 0.24), 16))
        root_layer.add_child(panel)

        var badge_text := "COMPLETE" if cleared else ("NEXT UP" if available and stage_id == unlocked else ("UNLOCKED" if available else "LOCKED"))
        var badge_color := GOLD_COLOR if cleared else (Color(0.82, 0.92, 1.0) if available else Color(0.55, 0.57, 0.62))
        var st := label("STAGE %d — %s" % [stage_id, badge_text], Vector2(14, 16), Vector2(182, 20), 13, panel)
        st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        st.add_theme_color_override("font_color", badge_color)

        var nm := label(str(stage["name"]), Vector2(12, 42), Vector2(186, 56), 19, panel)
        nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

        var desc := label(str(stage["subtitle"]), Vector2(16, 102), Vector2(178, 46), 13, panel)
        desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        desc.add_theme_color_override("font_color", Color(0.78, 0.84, 0.92))

        if available:
            var opponent := label("OPPONENT\n%s" % str(stage["class"]).to_upper(), Vector2(16, 156), Vector2(178, 40), 12, panel)
            opponent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            opponent.add_theme_color_override("font_color", class_color(str(stage["class"])))
        else:
            var lock_notice := label("🔒\nCLEAR THE PREVIOUS STAGE", Vector2(16, 150), Vector2(178, 55), 13, panel)
            lock_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            lock_notice.add_theme_color_override("font_color", Color(0.6, 0.62, 0.68))

        var reward_parts: Array[String] = []
        if int(stage["gold"]) > 0: reward_parts.append("%d GOLD" % int(stage["gold"]))
        if int(stage["packs"]) > 0: reward_parts.append("%d PACK%s" % [int(stage["packs"]), "" if int(stage["packs"]) == 1 else "S"])
        var rw := label("REWARD\n%s" % (" + ".join(reward_parts) if not reward_parts.is_empty() else "—"), Vector2(16, 260), Vector2(178, 46), 14, panel)
        rw.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        rw.add_theme_color_override("font_color", GOLD_COLOR)

        var play := button("REPLAY" if cleared else "BATTLE", Vector2(20, 336), Vector2(170, 46), func(): show_story_stage_intro(stage), panel)
        play.disabled = not available

    var footer := Panel.new()
    footer.position = Vector2(0, 615)
    footer.size = Vector2(1280, 90)
    footer.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
    root_layer.add_child(footer)
    button("HOME", Vector2(40, 645), Vector2(180, 48), show_home)
    button("REPLAY TRAINING", Vector2(1060, 645), Vector2(180, 48), show_first_day_intro)

func show_story_stage_intro(stage: Dictionary) -> void:
    # A short narrative beat before the fight itself, so a story stage reads
    # as a chapter of a story rather than just another entry on a battle
    # select list.
    clear_screen(); add_background(0.82)
    header("STAGE %d — %s" % [int(stage["id"]), str(stage["name"])], str(stage["subtitle"]))
    currency_bar()

    var panel := Panel.new()
    panel.position = Vector2(240, 190)
    panel.size = Vector2(800, 380)
    panel.add_theme_stylebox_override("panel", style(class_color(str(stage["class"])), 20))
    root_layer.add_child(panel)

    var quote_mark := label("“", Vector2(24, 8), Vector2(60, 60), 46, panel)
    quote_mark.add_theme_color_override("font_color", class_color(str(stage["class"])))

    var story_label := label(str(stage.get("story", "")), Vector2(70, 40), Vector2(660, 190), 20, panel)
    story_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    story_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

    var opponent := label("YOUR OPPONENT: %s" % str(stage["class"]).to_upper(), Vector2(40, 250), Vector2(720, 30), 16, panel)
    opponent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    opponent.add_theme_color_override("font_color", class_color(str(stage["class"])))

    var reward_parts: Array[String] = []
    if int(stage["gold"]) > 0: reward_parts.append("%d GOLD" % int(stage["gold"]))
    if int(stage["packs"]) > 0: reward_parts.append("%d PACK%s" % [int(stage["packs"]), "" if int(stage["packs"]) == 1 else "S"])
    var rw := label("REWARD: %s" % (" + ".join(reward_parts) if not reward_parts.is_empty() else "—"), Vector2(40, 285), Vector2(720, 30), 16, panel)
    rw.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    rw.add_theme_color_override("font_color", GOLD_COLOR)

    button("BEGIN BATTLE", Vector2(490, 335), Vector2(280, 56), func(): begin_story_stage(stage), panel)
    button("BACK", Vector2(40, 335), Vector2(140, 56), show_story_mode, panel)

func begin_story_stage(stage: Dictionary) -> void:
    var cfg := ConfigFile.new(); cfg.load(SAVE_PATH)
    var stage_id := int(stage["id"])
    var already_cleared := bool(cfg.get_value("story", "cleared_%d" % stage_id, false))
    cfg.set_value("challenge","pending_reward",0 if already_cleared else int(stage["gold"]))
    cfg.set_value("challenge","pending_packs",0 if already_cleared else int(stage["packs"]))
    cfg.set_value("challenge","name",str(stage["name"]))
    cfg.set_value("challenge","story_stage",stage_id)
    cfg.save(SAVE_PATH)
    var battle_cfg := ConfigFile.new()
    battle_cfg.set_value("battle","mode","story")
    battle_cfg.set_value("battle","your_class",selected_class if selected_class != "" else "Hope")
    battle_cfg.set_value("battle","opponent_class",str(stage["class"]))
    battle_cfg.save("user://battle_setup.cfg")
    start_battle()

func show_recovery_road() -> void:
    clear_screen(); add_background(0.70); header("RECOVERY ROAD","Defeat increasingly overpowered class decks to earn gold"); currency_bar()
    for i in range(CHALLENGES.size()):
        var ch: Dictionary = CHALLENGES[i]
        var p := Panel.new(); p.position=Vector2(90+i*230,200); p.size=Vector2(205,350); p.add_theme_stylebox_override("panel",style(class_color(str(ch["class"])),14)); root_layer.add_child(p)
        label(str(ch["stars"]),Vector2(10,18),Vector2(185,35),20,p).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
        var n := label(str(ch["name"]),Vector2(16,70),Vector2(173,70),22,p); n.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
        label("Overpowered %s deck\n\nVictory reward\n%d GOLD" % [str(ch["class"]),int(ch["reward"])],Vector2(15,155),Vector2(175,110),16,p).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
        button("CHALLENGE",Vector2(26,285),Vector2(153,45),func(): begin_challenge(ch),p)
    status_label = label("Winning a Recovery Road battle awards the listed gold. Recovery Master also grants a 500-gold first-clear bonus.",Vector2(250,600),Vector2(780,55),17)
    status_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER

func begin_challenge(ch: Dictionary) -> void:
    var cfg := ConfigFile.new(); cfg.load(SAVE_PATH)
    cfg.set_value("challenge","pending_reward",int(ch["reward"]))
    cfg.set_value("challenge","name",str(ch["name"]))
    cfg.save(SAVE_PATH)
    start_battle()

func show_store() -> void:
    clear_screen(); add_background(0.72); header("JOURNEY'S DAWN STORE","Buy packs with earned Gold or securely through Google Play"); currency_bar()
    var p := Panel.new(); p.position=Vector2(90,145); p.size=Vector2(1100,440); p.add_theme_stylebox_override("panel",style(Color(0.72,0.46,0.95),18)); root_layer.add_child(p)
    label("BOOSTER PACKS",Vector2(25,18),Vector2(1050,45),32,p).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    label("Every pack contains 5 cards • Duplicate protection • Signature Platinum guaranteed by pack 40",Vector2(70,62),Vector2(960,35),17,p).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    button("5 PACKS\n200 GOLD",Vector2(35,120),Vector2(190,92),buy_gold,p)
    button("5 PACKS\n%s" % BillingManager.formatted_price("wf_sober_packs_5", "$2.99"),Vector2(245,120),Vector2(190,92),func(): buy_cash("wf_sober_packs_5"),p)
    button("15 PACKS\n%s" % BillingManager.formatted_price("wf_sober_packs_15", "$7.99"),Vector2(455,120),Vector2(190,92),func(): buy_cash("wf_sober_packs_15"),p)
    button("40 PACKS\n%s" % BillingManager.formatted_price("wf_sober_packs_40", "$19.99"),Vector2(665,120),Vector2(190,92),func(): buy_cash("wf_sober_packs_40"),p)
    button("80 PACKS\n%s" % BillingManager.formatted_price("wf_sober_packs_80", "$39.99"),Vector2(875,120),Vector2(190,92),func(): buy_cash("wf_sober_packs_80"),p)
    button("OPEN OWNED PACKS",Vector2(185,265),Vector2(280,58),show_pack_opening,p)
    button("BUILD A DECK",Vector2(485,265),Vector2(220,58),show_deck_builder,p)
    button("CHECK PURCHASES",Vector2(725,265),Vector2(220,58),BillingManager.restore_pending_purchases,p)
    var billing_text := "Google Play Billing connected" if BillingManager.is_available() else "Cash purchases activate in an installed Google Play test/release build"
    label(billing_text,Vector2(150,345),Vector2(800,34),16,p).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    status_label = label("Next guaranteed Signature Platinum: %d packs" % (40-platinum_pity),Vector2(300,610),Vector2(680,44),20); status_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER

func buy_gold() -> void:
    if gold_balance < 200:
        safe_set_text(status_label, "Not enough gold."); return
    gold_balance -= 200; pack_inventory += 5; save_profile(); show_store()

func buy_cash(product_id: String) -> void:
    safe_set_text(status_label, "Opening Google Play purchase…")
    BillingManager.buy(product_id)

func _on_billing_purchase_completed(product_id: String, pack_count: int) -> void:
    pack_inventory += pack_count
    save_profile()
    show_store()
    safe_set_text(status_label, "Purchase complete — %d packs added." % pack_count)

func _on_billing_purchase_failed(message: String) -> void:
    safe_set_text(status_label, message)

func _on_billing_products_updated(_products: Dictionary) -> void:
    if is_instance_valid(root_layer) and status_label != null:
        show_store()

func show_pack_opening() -> void:
    clear_screen(); add_background(0.78); header("OPEN PACKS","Each opening permanently updates your collection"); currency_bar()
    if pack_inventory <= 0:
        label("NO PACKS OWNED",Vector2(390,275),Vector2(500,70),34).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
        button("RETURN TO STORE",Vector2(490,385),Vector2(300,55),show_store)
        return
    button("OPEN ONE JOURNEY'S DAWN PACK",Vector2(430,250),Vector2(420,120),open_pack)
    label("Platinum pity: %d / 40   •   Average pull target: 1 in 11 packs" % platinum_pity,Vector2(310,420),Vector2(660,42),19).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER

func open_pack() -> void:
    if pack_inventory <= 0: return
    pack_inventory -= 1; packs_opened += 1; platinum_pity += 1
    var guaranteed_platinum := platinum_pity >= 40
    var platinum_hit := guaranteed_platinum or randi_range(1,11) == 1
    var pulled: Array = []
    for i in range(5):
        var rarity := roll_rarity(i == 4, platinum_hit and i == 4)
        var cd := random_card_of_rarity(rarity)
        pulled.append(cd)
        add_card_to_collection(cd)
    if platinum_hit: platinum_pity = 0
    save_profile(); show_pack_results(pulled, platinum_hit)

func roll_rarity(guaranteed_silver: bool, force_platinum: bool) -> String:
    if force_platinum: return "Platinum"
    var r := randi_range(1,1000)
    if r <= 25: return "Legendary"
    if r <= 65: return "Epic"
    if r <= 140: return "Gold"
    if guaranteed_silver or r <= 320: return "Silver"
    return "Bronze"

func random_card_of_rarity(rarity: String) -> Dictionary:
    var pool: Array = []
    for cd in cards:
        if str(cd["rarity"]) == rarity: pool.append(cd)
    if pool.is_empty(): pool = cards
    return pool[randi_range(0,pool.size()-1)]

func add_card_to_collection(cd: Dictionary) -> void:
    var id := str(cd["id"]); var rarity := str(cd["rarity"]); var owned := int(collection_owned.get(id,0)); var limit := int(COPY_LIMITS.get(rarity,1))
    if owned >= limit:
        dust_balance += int(DUST_VALUES.get(rarity,10))
    else:
        collection_owned[id] = owned + 1

func pack_card_back(pos: Vector2, size_value: Vector2) -> Panel:
    # A face-down placeholder so the reveal reads as an actual pack being
    # opened one card at a time, instead of five cards just appearing flat
    # and static on the screen at once.
    var back := Panel.new()
    back.position = pos
    back.size = size_value
    back.pivot_offset = size_value / 2.0
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.05, 0.09, 0.16, 1.0)
    style.border_color = Color(0.62, 0.72, 0.92, 0.9)
    style.set_border_width_all(3)
    style.set_corner_radius_all(12)
    style.shadow_color = Color(0, 0, 0, 0.55)
    style.shadow_size = 6
    back.add_theme_stylebox_override("panel", style)
    var glyph := label("✦", Vector2(0, size_value.y / 2.0 - 34), size_value, 40, back)
    glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    glyph.add_theme_color_override("font_color", Color(0.72, 0.82, 1.0, 0.85))
    var wordmark := label("JOURNEY'S\nDAWN", Vector2(0, size_value.y / 2.0 + 16), size_value, 12, back)
    wordmark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    wordmark.add_theme_color_override("font_color", Color(0.72, 0.82, 1.0, 0.6))
    return back

func pack_rarity_burst(center: Vector2, rarity: String) -> void:
    # A brief radial flash sized and colored by rarity so a Legendary/Platinum
    # pull actually feels bigger than a Bronze one, instead of every card
    # revealing with identical, flat presentation.
    var scale_by_rarity := {"Bronze": 60.0, "Silver": 75.0, "Gold": 95.0, "Signature Gold": 95.0, "Epic": 115.0, "Legendary": 140.0, "Platinum": 175.0}
    var radius: float = scale_by_rarity.get(rarity, 70.0)
    var glow := ColorRect.new()
    glow.color = card_rarity_color(rarity)
    glow.color.a = 0.55
    glow.size = Vector2(radius, radius)
    glow.position = center - glow.size / 2.0
    glow.pivot_offset = glow.size / 2.0
    glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    glow.z_index = 40
    root_layer.add_child(glow)
    glow.scale = Vector2(0.2, 0.2)
    var burst_tween := create_tween().set_parallel(true)
    burst_tween.tween_property(glow, "scale", Vector2(1.0, 1.0), 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    burst_tween.tween_property(glow, "color:a", 0.0, 0.42)
    burst_tween.chain().tween_callback(glow.queue_free)

func show_pack_results(pulled: Array, platinum_hit: bool) -> void:
    clear_screen(); add_background(0.80); header("PACK OPENED", "SIGNATURE PLATINUM!" if platinum_hit else "Cards added to your collection"); currency_bar()
    var backs: Array[Panel] = []
    for i in range(pulled.size()):
        var pos := Vector2(55 + i * 244, 178)
        var back := pack_card_back(pos, Vector2(220, 340))
        root_layer.add_child(back)
        backs.append(back)
    button("OPEN ANOTHER (%d)" % pack_inventory,Vector2(405,550),Vector2(230,55),show_pack_opening)
    button("COLLECTION",Vector2(645,550),Vector2(180,55),show_collection)
    button("DECK BUILDER",Vector2(835,550),Vector2(200,55),show_deck_builder)
    # Fire-and-forget: the reveal animation must never gate the buttons above
    # from appearing (a stuck tween here should never be able to strand the
    # player on this screen with no way forward).
    _animate_pack_reveal(pulled, backs, platinum_hit)

func _animate_pack_reveal(pulled: Array, backs: Array, platinum_hit: bool) -> void:
    for i in range(pulled.size()):
        await get_tree().create_timer(0.30).timeout
        if i >= backs.size() or not is_instance_valid(backs[i]):
            continue
        var back: Panel = backs[i]
        var pos := back.position
        var size_value := back.size
        var flip_out := create_tween()
        flip_out.tween_property(back, "scale:x", 0.0, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        await flip_out.finished
        if not is_instance_valid(back):
            continue
        var parent := back.get_parent()
        back.queue_free()
        if not is_instance_valid(parent):
            continue
        var cd: Dictionary = pulled[i]
        var rarity := str(cd.get("rarity", "Bronze"))
        pack_rarity_burst(pos + size_value / 2.0, rarity)
        var real := card_panel(cd, pos, size_value)
        real.pivot_offset = size_value / 2.0
        real.scale.x = 0.0
        parent.add_child(real)
        var flip_in := create_tween()
        flip_in.tween_property(real, "scale:x", 1.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        if rarity in ["Legendary", "Platinum"]:
            await flip_in.finished
            if not is_instance_valid(real):
                continue
            var pop := create_tween()
            pop.tween_property(real, "scale", Vector2(1.1, 1.1), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
            pop.tween_property(real, "scale", Vector2(1.0, 1.0), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _load_menu_art_path(path: String) -> Texture2D:
    if _menu_art_cache.has(path):
        return _menu_art_cache[path] as Texture2D
    # load() resolves Godot-imported JPG/PNG resources in both editor and export.
    var imported: Texture2D = load(path) as Texture2D
    if imported != null:
        _menu_art_cache[path] = imported
        return imported
    # Editor/source fallback for images that have not been imported yet.
    if FileAccess.file_exists(path):
        var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
        var image := Image.new()
        var error: Error = ERR_FILE_UNRECOGNIZED
        if path.to_lower().ends_with(".jpg") or path.to_lower().ends_with(".jpeg"):
            error = image.load_jpg_from_buffer(bytes)
        elif path.to_lower().ends_with(".png"):
            error = image.load_png_from_buffer(bytes)
        if error == OK and not image.is_empty():
            var texture := ImageTexture.create_from_image(image)
            _menu_art_cache[path] = texture
            return texture
    return null

func card_art_texture(cd: Dictionary) -> Texture2D:
    # Use each card's own unique illustration (same lookup as battlefield/hand
    # cards) everywhere in the menus: collection, crafting, deck builder,
    # rewards, and packs. Only fall back to the shared 16-image pool when a
    # card has no catalog ID or no matching art file exists.
    var card_id: String = str(cd.get("id", "")).strip_edges().to_lower()
    if not card_id.is_empty():
        for extension in ["jpg", "png", "jpeg"]:
            var direct_texture: Texture2D = _load_menu_art_path("res://assets/cards/full/%s.%s" % [card_id, extension])
            if direct_texture != null:
                return direct_texture
    var seed_value: int = absi(str(cd.get("id", cd.get("name", "card"))).hash())
    var art_index: int = seed_value % 16
    return _load_menu_art_path("res://assets/cards/art_%02d.png" % art_index)

func card_rarity_color(rarity: String) -> Color:
    if rarity in ["Gold", "Signature Gold"]:
        return Color(1.0, 0.76, 0.20)
    elif rarity == "Epic":
        return Color(0.72, 0.38, 1.0)
    elif rarity == "Legendary":
        return Color(1.0, 0.42, 0.16)
    elif rarity == "Platinum":
        return Color(0.75, 0.95, 1.0)
    return Color(0.6, 0.66, 0.74)

func card_panel(cd: Dictionary, pos: Vector2, size_value: Vector2, previewable := true) -> Panel:
    var p := Panel.new()
    p.position = pos
    p.size = size_value
    p.custom_minimum_size = size_value
    p.clip_contents = true

    var rarity := str(cd.get("rarity", "Bronze"))
    var border := class_color(str(cd.get("class", "Neutral")))
    if rarity not in ["Bronze", "Silver"]:
        border = card_rarity_color(rarity)

    var frame_style := StyleBoxFlat.new()
    frame_style.bg_color = Color(0.015, 0.025, 0.055, 1.0)
    frame_style.border_color = border
    frame_style.set_border_width_all(3)
    frame_style.corner_radius_top_left = 12
    frame_style.corner_radius_top_right = 12
    frame_style.corner_radius_bottom_left = 12
    frame_style.corner_radius_bottom_right = 12
    frame_style.shadow_color = Color(0, 0, 0, 0.55)
    frame_style.shadow_size = 6
    p.add_theme_stylebox_override("panel", frame_style)

    # A slim inset highlight line reads as a stamped metal card edge instead
    # of a flat rectangle photo pasted on a background — the same two-tone
    # frame trick used by physical trading cards.
    var inner_frame := Panel.new()
    inner_frame.position = Vector2(4, 4)
    inner_frame.size = size_value - Vector2(8, 8)
    inner_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var inner_style := StyleBoxFlat.new()
    inner_style.bg_color = Color(0, 0, 0, 0)
    inner_style.border_color = Color(border.r, border.g, border.b, 0.55).lightened(0.3)
    inner_style.set_border_width_all(1)
    inner_style.corner_radius_top_left = 9
    inner_style.corner_radius_top_right = 9
    inner_style.corner_radius_bottom_left = 9
    inner_style.corner_radius_bottom_right = 9
    inner_frame.add_theme_stylebox_override("panel", inner_style)
    p.add_child(inner_frame)

    var compact_panel := size_value.y < 230.0
    var outer_pad := 7.0
    var art_height := size_value.y * (0.61 if compact_panel else 0.60)

    var art := TextureRect.new()
    art.texture = card_art_texture(cd)
    art.position = Vector2(outer_pad, outer_pad)
    art.size = Vector2(size_value.x - outer_pad * 2.0, art_height)
    art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    p.add_child(art)

    # Diagonal glass sheen across the art — a cheap, standard trick that makes
    # a flat photo read as a coated/printed card instead of a pasted image.
    var sheen := GradientTexture2D.new()
    var sheen_gradient := Gradient.new()
    sheen_gradient.colors = PackedColorArray([Color(1,1,1,0.16), Color(1,1,1,0.0)])
    sheen_gradient.offsets = PackedFloat32Array([0.0, 1.0])
    sheen.gradient = sheen_gradient
    sheen.fill_from = Vector2(0.05, 0.0)
    sheen.fill_to = Vector2(0.6, 0.75)
    var sheen_rect := TextureRect.new()
    sheen_rect.texture = sheen
    sheen_rect.position = art.position
    sheen_rect.size = art.size
    sheen_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    p.add_child(sheen_rect)

    # Dark fade keeps the card name readable without hiding the art.
    var fade := GradientTexture2D.new()
    var gradient := Gradient.new()
    gradient.colors = PackedColorArray([Color(0,0,0,0.0), Color(0.01,0.02,0.05,0.96)])
    gradient.offsets = PackedFloat32Array([0.0, 1.0])
    fade.gradient = gradient
    fade.fill_from = Vector2(0.5, 0.0)
    fade.fill_to = Vector2(0.5, 1.0)
    var shade := TextureRect.new()
    shade.texture = fade
    shade.position = Vector2(outer_pad, max(outer_pad, art_height * 0.43))
    shade.size = Vector2(size_value.x - outer_pad * 2.0, art_height * 0.58)
    shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    p.add_child(shade)

    var cost_orb := Label.new()
    cost_orb.text = str(cd.get("cost", 0))
    cost_orb.position = Vector2(8, 7)
    cost_orb.size = Vector2(34, 34)
    cost_orb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    cost_orb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    cost_orb.add_theme_font_size_override("font_size", 17 if compact_panel else 20)
    cost_orb.add_theme_color_override("font_color", Color.WHITE)
    cost_orb.add_theme_color_override("font_shadow_color", Color.BLACK)
    cost_orb.add_theme_constant_override("shadow_offset_x", 2)
    cost_orb.add_theme_constant_override("shadow_offset_y", 2)
    cost_orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
    p.add_child(cost_orb)

    var name_y := art_height - (43.0 if compact_panel else 48.0)
    var n := label(str(cd.get("name", "Card")), Vector2(9, name_y), Vector2(size_value.x-18, 42), 13 if compact_panel else 16, p)
    n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    n.add_theme_color_override("font_shadow_color", Color.BLACK)
    n.add_theme_constant_override("shadow_offset_x", 2)
    n.add_theme_constant_override("shadow_offset_y", 2)

    var rarity_y := art_height + 10.0
    var r := label(rarity.to_upper(), Vector2(9, rarity_y), Vector2(size_value.x-18, 20), 10 if compact_panel else 12, p)
    r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    r.add_theme_color_override("font_color", border)

    var stats_y := rarity_y + 22.0
    var stats_text := "%s PP    %s/%s" % [str(cd.get("cost",0)), str(cd.get("attack",0)), str(cd.get("health",0))]
    var st := label(stats_text, Vector2(9, stats_y), Vector2(size_value.x-18, 24), 11 if compact_panel else 13, p)
    st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

    if not compact_panel:
        var effect_y := stats_y + 28.0
        var effect := label(str(cd.get("effect", "")), Vector2(11, effect_y), Vector2(size_value.x-22, size_value.y-effect_y-9), 11, p)
        effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        effect.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

    if previewable:
        var tap_catcher := Button.new()
        tap_catcher.flat = true
        tap_catcher.focus_mode = Control.FOCUS_NONE
        tap_catcher.position = Vector2.ZERO
        tap_catcher.size = size_value
        tap_catcher.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        tap_catcher.tooltip_text = "Tap to inspect this card"
        tap_catcher.pressed.connect(show_card_preview.bind(cd))
        p.add_child(tap_catcher)

    return p

func show_card_preview(cd: Dictionary) -> void:
    # Full-size read-only inspection popup so players can check a card's
    # exact wording and stats from the deck builder or collection grid
    # without it being confused for a playable/drag target.
    var scrim := ColorRect.new()
    scrim.color = Color(0.02, 0.03, 0.06, 0.82)
    scrim.position = Vector2.ZERO
    scrim.size = Vector2(1280, 720)
    scrim.mouse_filter = Control.MOUSE_FILTER_STOP
    scrim.z_index = 900
    scrim.gui_input.connect(func(event):
        if event is InputEventMouseButton and event.pressed:
            scrim.queue_free()
    )
    root_layer.add_child(scrim)

    var rarity := str(cd.get("rarity", "Bronze"))
    var border := class_color(str(cd.get("class", "Neutral")))
    if rarity in ["Gold", "Signature Gold"]:
        border = Color(1.0, 0.76, 0.20)
    elif rarity == "Epic":
        border = Color(0.72, 0.38, 1.0)
    elif rarity == "Legendary":
        border = Color(1.0, 0.42, 0.16)
    elif rarity == "Platinum":
        border = Color(0.75, 0.95, 1.0)

    var big_card := card_panel(cd, Vector2(490, 40), Vector2(300, 460), false)
    big_card.z_index = 901
    scrim.add_child(big_card)

    # Parent directly to scrim instead of the label()/centered_label() default
    # of root_layer — calling add_child() on a node that already has a parent
    # is a no-op error in Godot, which was silently leaving this caption
    # detached from the popup (and, depending on draw order, invisible).
    var caption := label("%s  •  %s" % [str(cd.get("class", "Neutral")).to_upper(), rarity.to_upper()], Vector2(390, 520), Vector2(500, 30), 16, scrim)
    caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    caption.add_theme_color_override("font_color", border)
    caption.z_index = 901

    var close_btn := button("CLOSE", Vector2(560, 570), Vector2(160, 48), scrim.queue_free, scrim)
    close_btn.z_index = 901

func show_collection() -> void:
    clear_screen(); add_background(0.82); header("COLLECTION & CRAFTING","Craft any card from any class • Deck class only matters when building"); currency_bar()
    var guide := label("CREATE: Bronze 50  •  Silver 150  •  Gold 500  •  Epic 900  •  Legendary 2,000  •  Platinum 4,500",Vector2(90,142),Vector2(1100,30),16)
    guide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    guide.add_theme_color_override("font_color", Color(0.78,0.90,1.0))
    var binder := Panel.new()
    binder.position = Vector2(28,176)
    binder.size = Vector2(1224,500)
    var binder_style := StyleBoxFlat.new()
    binder_style.bg_color = Color(0.01,0.02,0.045,0.78)
    binder_style.border_color = GOLD_COLOR
    binder_style.set_border_width_all(2)
    binder_style.corner_radius_top_left = 14
    binder_style.corner_radius_top_right = 14
    binder_style.corner_radius_bottom_left = 14
    binder_style.corner_radius_bottom_right = 14
    binder.add_theme_stylebox_override("panel",binder_style)
    root_layer.add_child(binder)
    var scroll := ScrollContainer.new()
    scroll.position=Vector2(12,12)
    scroll.size=Vector2(1200,476)
    binder.add_child(scroll)
    var grid := GridContainer.new()
    grid.columns=6
    grid.add_theme_constant_override("h_separation",16)
    grid.add_theme_constant_override("v_separation",18)
    scroll.add_child(grid)
    for cd in cards:
        var id := str(cd["id"])
        var rarity := str(cd["rarity"])
        var owned := int(collection_owned.get(id,0))
        var limit := int(COPY_LIMITS.get(rarity,1))
        var wrap := VBoxContainer.new()
        wrap.custom_minimum_size=Vector2(180,348)
        var cp := card_panel(cd,Vector2.ZERO,Vector2(174,248))
        wrap.add_child(cp)
        if owned <= 0:
            cp.modulate = Color(0.48,0.52,0.60,0.90)
            var lock_badge := Label.new()
            lock_badge.text = "LOCKED"
            lock_badge.position = Vector2(36,102)
            lock_badge.size = Vector2(102,30)
            lock_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            lock_badge.add_theme_font_size_override("font_size",12)
            lock_badge.add_theme_color_override("font_color",Color.WHITE)
            lock_badge.add_theme_color_override("font_shadow_color",Color.BLACK)
            lock_badge.add_theme_constant_override("shadow_offset_x",2)
            lock_badge.add_theme_constant_override("shadow_offset_y",2)
            lock_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
            cp.add_child(lock_badge)
        var own := Label.new(); own.text="Owned %d/%d" % [owned,limit]; own.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; wrap.add_child(own)
        if rarity in ["Bronze", "Silver"]:
            var vial := Button.new()
            vial.text = "VIAL +%d" % int(DUST_VALUES.get(rarity,0))
            vial.disabled = owned <= count_in_deck(id)
            vial.tooltip_text = "Copies currently used in your saved deck are protected."
            vial.pressed.connect(dust_card.bind(id))
            wrap.add_child(vial)
        elif rarity in ["Gold", "Epic", "Legendary"]:
            var auto_note := Label.new(); auto_note.text="Extras auto-vial"; auto_note.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; auto_note.add_theme_font_size_override("font_size",11); wrap.add_child(auto_note)
        else:
            var protected_note := Label.new(); protected_note.text="Signature — pack only"; protected_note.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; protected_note.add_theme_font_size_override("font_size",11); wrap.add_child(protected_note)
        if CRAFT_COSTS.has(rarity):
            var craft := Button.new()
            var cost := int(CRAFT_COSTS[rarity])
            craft.text = "CREATE %d" % cost
            craft.disabled = owned >= limit or dust_balance < cost
            craft.pressed.connect(craft_card.bind(id))
            wrap.add_child(craft)
        grid.add_child(wrap)

func dust_card(id: String) -> void:
    var cd := card_by_id(id)
    if cd.is_empty():
        return
    var rarity := str(cd.get("rarity", "Bronze"))
    if rarity not in ["Bronze", "Silver"]:
        return
    var owned := int(collection_owned.get(id, 0))
    # Never dismantle a copy currently required by the active saved deck.
    if owned <= count_in_deck(id):
        return
    collection_owned[id] = owned - 1
    dust_balance += int(DUST_VALUES.get(rarity, 0))
    save_profile()
    show_collection()

func craft_card(id: String) -> void:
    var cd := card_by_id(id)
    if cd.is_empty():
        return
    var rarity := str(cd.get("rarity", "Bronze"))
    if not CRAFT_COSTS.has(rarity):
        return
    var cost := int(CRAFT_COSTS[rarity])
    var owned := int(collection_owned.get(id, 0))
    var limit := int(COPY_LIMITS.get(rarity, 1))
    if owned >= limit or dust_balance < cost:
        return
    dust_balance -= cost
    collection_owned[id] = owned + 1
    save_profile()
    show_collection()

func switch_deck_class(c: String) -> void:
    # Preserve each class deck independently so players can build every class.
    saved_decks[selected_deck_class] = saved_deck.duplicate()
    selected_deck_class = c
    saved_deck = Array(saved_decks.get(c, []))
    save_profile()
    show_deck_builder()

func show_deck_preview() -> void:
    # Read-only view of the currently active class's saved deck, reachable
    # straight from the home screen without entering the full deck builder.
    # Tapping any card still opens the same full-detail inspector.
    clear_screen(); add_background(0.82)
    var active_class := selected_class if selected_class != "" else "Hope"
    header("DECK PREVIEW — " + active_class.to_upper(), "Tap any card to inspect it • Go to DECKS to add or remove cards")
    var deck: Array = Array(saved_decks.get(active_class, []))
    if deck.is_empty():
        centered_label("This deck is empty.", Vector2(340, 260), Vector2(600, 40), 22).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        centered_label("Visit DECKS from the home screen to add cards.", Vector2(340, 310), Vector2(600, 30), 15)
        button("BACK", Vector2(540, 400), Vector2(200, 54), show_home)
        return
    var counts: Dictionary = {}
    for id in deck:
        counts[str(id)] = int(counts.get(str(id), 0)) + 1
    var binder := Panel.new()
    binder.position = Vector2(28, 176); binder.size = Vector2(1224, 470)
    var binder_style := StyleBoxFlat.new()
    binder_style.bg_color = Color(0.01, 0.02, 0.045, 0.78)
    binder_style.border_color = GOLD_COLOR
    binder_style.set_border_width_all(2)
    binder_style.set_corner_radius_all(14)
    binder.add_theme_stylebox_override("panel", binder_style)
    root_layer.add_child(binder)
    var scroll := ScrollContainer.new(); scroll.position = Vector2(12, 12); scroll.size = Vector2(1200, 446); binder.add_child(scroll)
    var grid := GridContainer.new(); grid.columns = 7
    grid.add_theme_constant_override("h_separation", 14); grid.add_theme_constant_override("v_separation", 16)
    scroll.add_child(grid)
    var seen: Dictionary = {}
    for id in deck:
        var sid := str(id)
        if seen.has(sid):
            continue
        seen[sid] = true
        var cd := card_by_id(sid)
        if cd.is_empty():
            continue
        var wrap := VBoxContainer.new(); wrap.custom_minimum_size = Vector2(156, 245)
        var cp := card_panel(cd, Vector2.ZERO, Vector2(150, 214))
        wrap.add_child(cp)
        var count_label := Label.new()
        count_label.text = "Copies: %d" % int(counts.get(sid, 1))
        count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        count_label.add_theme_font_size_override("font_size", 12)
        wrap.add_child(count_label)
        grid.add_child(wrap)
    button("BACK TO HOME", Vector2(28, 656), Vector2(220, 48), show_home)
    button("EDIT THIS DECK", Vector2(264, 656), Vector2(220, 48), show_deck_builder)

func show_deck_builder() -> void:
    clear_screen(); add_background(0.82); header("DECK BUILDER","Separate saved deck for every class • Exactly 40 cards • Class plus Neutral"); currency_bar()
    if selected_class == "":
        label("CHOOSE A CLASS FIRST",Vector2(380,245),Vector2(520,60),34).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
        label("Your class unlocks a starter deck. Pack pulls can then be added here.",Vector2(340,320),Vector2(600,70),19).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
        button("CHOOSE MY CLASS",Vector2(485,420),Vector2(310,60),show_class_choice)
        return
    var class_row := HBoxContainer.new(); class_row.position=Vector2(45,180); class_row.size=Vector2(500,45); root_layer.add_child(class_row)
    for c in CLASSES:
        var b:=Button.new()
        b.text=str(c)
        b.custom_minimum_size=Vector2(115,40)
        b.pressed.connect(switch_deck_class.bind(str(c)))
        class_row.add_child(b)
    var scroll := ScrollContainer.new(); scroll.position=Vector2(45,240); scroll.size=Vector2(780,400); root_layer.add_child(scroll)
    var grid := GridContainer.new(); grid.columns=5; grid.add_theme_constant_override("h_separation",12); grid.add_theme_constant_override("v_separation",12); scroll.add_child(grid)
    for cd in cards:
        if str(cd["class"]) != selected_deck_class and str(cd["class"]) != "Neutral": continue
        var id := str(cd["id"])
        var rarity := str(cd["rarity"])
        var owned := int(collection_owned.get(id, 0))
        var box:=VBoxContainer.new()
        box.custom_minimum_size=Vector2(140,235)
        var cp := card_panel(cd,Vector2.ZERO,Vector2(135,170))
        if owned <= 0:
            cp.modulate = Color(0.48,0.52,0.60,0.90)
        box.add_child(cp)
        if owned > 0:
            var add:=Button.new()
            var allowed := mini(owned,int(COPY_LIMITS.get(rarity,1)))
            add.text="ADD (%d/%d)" % [count_in_deck(id),allowed]
            add.disabled=saved_deck.size()>=40 or count_in_deck(id)>=allowed
            add.pressed.connect(add_card_to_deck.bind(id))
            box.add_child(add)
        elif CRAFT_COSTS.has(rarity):
            var craft := Button.new()
            var cost := int(CRAFT_COSTS[rarity])
            craft.text = "CREATE %d" % cost
            craft.disabled = dust_balance < cost
            craft.pressed.connect(craft_from_deck_builder.bind(id))
            box.add_child(craft)
        else:
            var locked := Label.new()
            locked.text = "PACK ONLY"
            locked.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            box.add_child(locked)
        grid.add_child(box)
    var side:=Panel.new(); side.position=Vector2(860,210); side.size=Vector2(360,430); side.add_theme_stylebox_override("panel",style(class_color(selected_deck_class),14)); root_layer.add_child(side)
    var deck_leader_frame := Panel.new()
    deck_leader_frame.position = Vector2(92, 14)
    deck_leader_frame.size = Vector2(176, 166)
    deck_leader_frame.clip_contents = true
    deck_leader_frame.add_theme_stylebox_override("panel", style(class_color(selected_deck_class).lightened(0.12), 12))
    side.add_child(deck_leader_frame)
    var deck_leader_art := TextureRect.new()
    deck_leader_art.texture = load("res://assets/leaders/%s.png" % selected_deck_class.to_lower())
    deck_leader_art.position = Vector2(6, 6)
    deck_leader_art.size = Vector2(164, 154)
    deck_leader_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    deck_leader_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    deck_leader_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    deck_leader_frame.add_child(deck_leader_art)
    label("%s DECK" % selected_deck_class.to_upper(),Vector2(20,184),Vector2(320,36),24,side).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    label("%d / 40 CARDS\n%s" % [saved_deck.size(),deck_validation_text()],Vector2(30,226),Vector2(300,78),16,side)
    button("REMOVE LAST",Vector2(45,318),Vector2(270,42),remove_last,side)
    button("RESET STARTER DECK",Vector2(45,370),Vector2(270,42),func(): build_starter_deck(selected_deck_class); save_profile(); show_deck_builder(),side)

func add_card_to_deck(id: String) -> void:
    var cd := card_by_id(id)
    if cd.is_empty():
        return
    var owned := int(collection_owned.get(id, 0))
    var limit := mini(owned, int(COPY_LIMITS.get(str(cd.get("rarity", "Bronze")), 1)))
    if saved_deck.size() >= 40 or count_in_deck(id) >= limit:
        return
    saved_deck.append(id)
    save_profile()
    show_deck_builder()

func craft_from_deck_builder(id: String) -> void:
    var cd := card_by_id(id)
    if cd.is_empty():
        return
    var rarity := str(cd.get("rarity", "Bronze"))
    if not CRAFT_COSTS.has(rarity):
        return
    var cost := int(CRAFT_COSTS[rarity])
    var owned := int(collection_owned.get(id, 0))
    var limit := int(COPY_LIMITS.get(rarity, 1))
    if owned >= limit or dust_balance < cost:
        return
    dust_balance -= cost
    collection_owned[id] = owned + 1
    save_profile()
    show_deck_builder()

func remove_last() -> void:
    if not saved_deck.is_empty(): saved_deck.pop_back(); save_profile()
    show_deck_builder()

func count_in_deck(id: String) -> int:
    var total:=0
    for entry in saved_deck:
        if str(entry)==id: total+=1
    return total

func deck_validation_text() -> String:
    if saved_deck.size() != 40:
        return "Deck needs exactly 40 cards (%d/40)." % saved_deck.size()
    for id in saved_deck:
        var cd := card_by_id(str(id))
        if cd.is_empty():
            return "Unknown card found."
        var card_class := str(cd["class"])
        if card_class != selected_deck_class and card_class != "Neutral":
            return "Wrong class card: %s" % str(cd["name"])
        if count_in_deck(str(id)) > int(COPY_LIMITS.get(str(cd["rarity"]), 1)):
            return "Copy limit exceeded: %s" % str(cd["name"])
    return "DECK VALID — EXACTLY 40 CARDS"

func card_by_id(id: String) -> Dictionary:
    for cd in cards:
        if str(cd["id"])==id: return cd
    return {}

func unique_collected() -> int:
    var total:=0
    for id in collection_owned.keys():
        if int(collection_owned[id])>0: total+=1
    return total


func show_access_login() -> void:
    clear_screen(); add_background(0.72)
    var p := Panel.new(); p.position=Vector2(300,120); p.size=Vector2(680,480); p.add_theme_stylebox_override("panel",style(GOLD_COLOR,18)); root_layer.add_child(p)
    centered_label("AUTHORIZED ACCESS",Vector2(50,34),Vector2(580,52),32,p).add_theme_color_override("font_color",GOLD_COLOR)
    centered_label("Enter the owner PIN to unlock the private test tools. Access closes when the app is restarted or you sign out.",Vector2(75,105),Vector2(530,90),18,p)
    access_token_input = LineEdit.new()
    access_token_input.position = Vector2(110,225)
    access_token_input.size = Vector2(460,52)
    access_token_input.placeholder_text = "Enter 4-digit owner PIN"
    access_token_input.secret = true
    access_token_input.max_length = 4
    access_token_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
    access_token_input.add_theme_font_size_override("font_size",18)
    p.add_child(access_token_input)
    access_status = centered_label("",Vector2(85,292),Vector2(510,56),17,p)
    button("UNLOCK OWNER TOOLS",Vector2(185,360),Vector2(310,56),func(): AccessManager.authenticate(access_token_input.text),p)
    button("BACK",Vector2(260,425),Vector2(160,38),show_home,p)

func _on_access_authentication_finished(success: bool, message: String) -> void:
    if access_status != null and is_instance_valid(access_status):
        access_status.text = message
        access_status.add_theme_color_override("font_color", Color(0.55,1.0,0.70) if success else Color(1.0,0.55,0.55))
    if success:
        await get_tree().create_timer(0.8).timeout
        show_test_tools()

func show_test_tools() -> void:
    if not AccessManager.role_at_least(AccessManager.ROLE_TESTER):
        show_access_login()
        return
    clear_screen(); add_background(0.64)
    header("TEST TOOLS", "%s role • Session-only access" % AccessManager.current_role.capitalize())
    var p := Panel.new(); p.position=Vector2(130,135); p.size=Vector2(1020,515); p.add_theme_stylebox_override("panel",style(Color(0.62,0.42,0.95),18)); root_layer.add_child(p)
    centered_label("TESTER SANDBOX",Vector2(40,24),Vector2(940,48),28,p).add_theme_color_override("font_color",Color(0.78,0.68,1.0))
    centered_label("Sandbox actions never alter a player's permanent collection or economy unless an Owner deliberately uses an Owner-only command.",Vector2(120,78),Vector2(780,72),17,p)
    if AccessManager.role_at_least(AccessManager.ROLE_OWNER):
        centered_label("DEVELOPER META GAUNTLET — OWNER ONLY",Vector2(40,150),Vector2(940,32),18,p).add_theme_color_override("font_color",GOLD_COLOR)
        var meta_classes := ["Hope","Courage","Serenity","Purpose"]
        for i in range(meta_classes.size()):
            var c := str(meta_classes[i])
            button("%s META DECK" % c.to_upper(),Vector2(40+i*238,195),Vector2(220,52),func(): start_developer_meta_battle(c),p)
        button("FINAL BOSS — ALL CLASSES",Vector2(315,255),Vector2(390,48),start_developer_final_boss_battle,p)
    else:
        centered_label("Developer decks require Owner access.",Vector2(40,170),Vector2(940,48),18,p)
    button("OPEN DECK BUILDER",Vector2(110,315),Vector2(350,58),show_deck_builder,p)
    button("VIEW COLLECTION",Vector2(560,315),Vector2(350,58),show_collection,p)
    button("STANDARD TEST BATTLE",Vector2(110,385),Vector2(350,58),start_battle,p)
    button("AUDIO / DEVICE TEST",Vector2(560,385),Vector2(350,58),show_mobile_info,p)
    if AccessManager.role_at_least(AccessManager.ROLE_OWNER):
        var owner_note := centered_label("OWNER CONTROLS",Vector2(40,340),Vector2(940,36),22,p)
        owner_note.add_theme_color_override("font_color",GOLD_COLOR)
        button("ADD 500 TEST GOLD",Vector2(110,390),Vector2(350,52),func():
            gold_balance += 500
            save_profile()
            show_test_tools()
        ,p)
        button("ADD 5 TEST PACKS",Vector2(560,390),Vector2(350,52),func():
            pack_inventory += 5
            save_profile()
            show_test_tools()
        ,p)
    button("SIGN OUT",Vector2(430,460),Vector2(160,38),func():
        AccessManager.sign_out()
        show_home()
    ,p)

func show_mobile_info() -> void:
    clear_screen()
    add_background(0.64)
    header("AUDIO / DEVICE TEST", "RC diagnostics for phones, tablets, desktop, and sound")

    var panel := Panel.new()
    panel.position = Vector2(170, 135)
    panel.size = Vector2(940, 500)
    panel.add_theme_stylebox_override("panel", style(Color(0.30, 0.68, 0.95), 18))
    root_layer.add_child(panel)

    centered_label("DEVICE", Vector2(35, 24), Vector2(410, 36), 23, panel)
    var device_text := "Platform: %s\nScreen: %d × %d\nTouchscreen available: %s\nBuild: %s" % [
        OS.get_name(),
        int(get_viewport_rect().size.x),
        int(get_viewport_rect().size.y),
        "Yes" if DisplayServer.is_touchscreen_available() else "No",
        APP_VERSION
    ]
    centered_label(device_text, Vector2(35, 70), Vector2(410, 150), 17, panel)

    centered_label("AUDIO", Vector2(495, 24), Vector2(410, 36), 23, panel)
    centered_label("Use these checks before exporting the APK.", Vector2(495, 70), Vector2(410, 44), 17, panel)

    button("TEST BUTTON SOUND", Vector2(525, 132), Vector2(350, 48), func():
        if has_node("/root/AudioManager"):
            var audio_manager := get_node_or_null("/root/AudioManager")
            if is_instance_valid(audio_manager) and audio_manager.has_method("play_ui"):
                audio_manager.call("play_ui")
        else:
            academy_feedback_text("Audio manager is not loaded in this scene.", false)
    , panel)

    button("TEST BATTLE", Vector2(525, 196), Vector2(350, 48), start_battle, panel)
    button("TEST CARD VIEW", Vector2(525, 260), Vector2(350, 48), show_collection, panel)

    var checklist := "PRE-APK CHECK\n• Buttons fit within the safe area\n• Touch taps do not double-trigger\n• Music loops without stacking\n• Card text remains readable\n• Back navigation returns safely"
    centered_label(checklist, Vector2(55, 245), Vector2(390, 175), 16, panel)

    button("BACK TO TEST TOOLS", Vector2(310, 435), Vector2(320, 42), show_test_tools, panel)
