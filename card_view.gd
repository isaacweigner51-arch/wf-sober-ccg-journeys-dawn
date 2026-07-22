class_name CardView
extends Button

signal card_chosen(card_index: int)
signal inspect_requested(card_data: Dictionary)

static var _catalog_by_name: Dictionary = {}
static var _catalog_loaded: bool = false
static var _art_cache: Dictionary = {}
signal drag_action_requested(card_index: int, context: String, global_release_position: Vector2)
signal drag_position_updated(card_index: int, context: String, global_pos: Vector2)

var card_index := -1
var data: Dictionary = {}
var compact := false
var hidden_card := false
var sleeve_class := ""
var base_position := Vector2.ZERO
var selected := false

var art_rect: TextureRect
var name_label: Label
var cost_label: Label
var stats_label: Label
var ability_label: Label
var ready_glow: ColorRect
var foil_glow: ColorRect
var living_glow: Panel
var shine_strip: ColorRect
var shiny_rainbow: ColorRect
var shiny_sparks: Array = []
var _spark_timers: Array = []
var hovering := false
var shimmer_time := 0.0
var idle_phase := 0.0
var _rarity_tier_cache := -1
var _orb_nodes: Array = []
var _aura_time := 0.0
var _idle_paused := false    # true during attacks/death/evolution — stops competing scale tweens
var art_home := Vector2.ZERO
var art_clip: Panel          # clip container: keeps art drift/float inside the card window
static var graphics_quality := 2  # 0 = Low  1 = Medium  2 = High

## Display context — controls which animations and effects are active.
## Set BEFORE calling setup() so _build() / _init_rarity_vfx() can read it.
## BATTLEFIELD:   full idle breathing, orbs, hover lift, attack feel.
## PREVIEW:       fixed size, no breathing, no orbs, no hover, no attack transforms.
##                Used for Second Chance, Pack Opening, and any fixed-slot display.
## HAND:          breathing off, hover lift on, no combat animations.
## COLLECTION:    preview-like — fixed size, rarity VFX visible but no scale drift.
## DECK_BUILDER:  same as COLLECTION.
## DETAIL_VIEW:   static render; all interactive animations off.
enum DisplayMode { BATTLEFIELD, PREVIEW, HAND, COLLECTION, DECK_BUILDER, DETAIL_VIEW }
var display_mode := DisplayMode.BATTLEFIELD
var allow_reorder := false
var show_inspect_button := false
var inspect_button: Button
var tap_to_inspect := false
var touch_holding := false
var touch_hold_time := 0.0
var touch_hold_fired := false
var drag_press_global := Vector2.ZERO
var drag_origin_position := Vector2.ZERO
var gesture_dragging := false
var suppress_next_press := false
const LONG_PRESS_SECONDS := 0.45
const DRAG_THRESHOLD := 16.0

func is_mobile_device() -> bool:
    return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")

func card_font(value: int) -> int:
    return int(round(float(value) * (1.15 if is_mobile_device() else 1.0)))

func setup(card_data: Dictionary, index: int, is_compact: bool = false, is_hidden: bool = false, sleeve_class_name: String = "") -> void:
    data = _hydrate_card_data(card_data.duplicate(true))
    card_index = index
    compact = is_compact
    hidden_card = is_hidden
    sleeve_class = sleeve_class_name
    focus_mode = Control.FOCUS_NONE
    flat = true
    mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    custom_minimum_size = Vector2(142, 186) if not compact else Vector2(126, 146)
    size = custom_minimum_size
    pivot_offset = custom_minimum_size * 0.5
    idle_phase = float(absi(str(data.get("name", "card")).hash()) % 628) / 100.0
    _build()
    pressed.connect(func():
        if suppress_next_press:
            suppress_next_press = false
            return
        card_chosen.emit(card_index)
    )
    mouse_entered.connect(_hover_on)
    mouse_exited.connect(_hover_off)
    set_process(true)

func enable_card_interactions(can_reorder: bool = false, can_inspect: bool = true) -> void:
    allow_reorder = can_reorder
    tap_to_inspect = can_inspect and not hidden_card
    show_inspect_button = false
    if is_instance_valid(inspect_button):
        inspect_button.queue_free()
        inspect_button = null

func _add_inspect_button() -> void:
    # Inspection is handled by tapping the card itself.
    return

func set_inspect_controls_visible(_value: bool) -> void:
    return

func _gui_input(event: InputEvent) -> void:
    if hidden_card:
        return
    # On mobile, Project Settings emulates a synthetic mouse event for every
    # touch event (pointing/emulate_mouse_from_touch). Handling both streams
    # here would process one physical tap/drag twice — resetting/overwriting
    # this gesture state machine mid-gesture — which is what made a single
    # tap intermittently fail to play a card (it silently "ate" the first
    # tap and only a clean second tap got through). Touch devices are fully
    # covered by the InputEventScreenTouch/ScreenDrag branches below, so
    # ignore their emulated mouse counterparts entirely.
    if is_mobile_device() and (event is InputEventMouseButton or event is InputEventMouseMotion):
        return
    var context := str(data.get("_ui_context", ""))
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            _gesture_press(context)
        else:
            _gesture_release(context, get_global_mouse_position())
            mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        _gesture_motion(context)
        if gesture_dragging:
            mouse_default_cursor_shape = Control.CURSOR_DRAG
    elif event is InputEventScreenTouch:
        if event.pressed:
            _gesture_press(context)
        else:
            # Use get_global_mouse_position() (canvas coords) instead of
            # event.position (screen/viewport coords). On mobile with viewport
            # scaling the two coordinate spaces differ, making release-point
            # detection against Control.get_global_rect() fail silently.
            _gesture_release(context, get_global_mouse_position())
    elif event is InputEventScreenDrag:
        _gesture_motion(context)

func _gesture_press(_context: String) -> void:
    drag_press_global = get_global_mouse_position()
    drag_origin_position = position
    gesture_dragging = false
    touch_holding = tap_to_inspect
    touch_hold_time = 0.0
    touch_hold_fired = false

func _gesture_motion(context: String) -> void:
    if touch_hold_fired:
        return
    # Track the pointer in global/screen space rather than this control's
    # own local coordinates. Local-space comparisons break here because (a)
    # hovering already animates this node's own `position` (the hand "lift"
    # on touch-down) independently of pointer motion, and (b) this node's
    # `scale` changes during hover/drag, which rescales any local-space
    # delta relative to the true finger movement. Global position is
    # unaffected by either, so it stays accurate throughout the gesture.
    var current_global := get_global_mouse_position()
    var delta := current_global - drag_press_global
    if not gesture_dragging and delta.length() >= DRAG_THRESHOLD and context in ["hand", "player_board"]:
        gesture_dragging = true
        touch_holding = false
        z_index = 500
        var lift_tween := create_tween()
        lift_tween.tween_property(self, "scale", Vector2(1.16, 1.16) if not compact else Vector2(1.1, 1.1), 0.08)
        accept_event()
    if gesture_dragging:
        position = drag_origin_position + delta
        if context == "player_board":
            drag_position_updated.emit(card_index, context, get_global_mouse_position())
        accept_event()

func _gesture_release(context: String, release_global: Vector2) -> void:
    touch_holding = false
    var was_dragging := gesture_dragging
    gesture_dragging = false
    if touch_hold_fired:
        suppress_next_press = true
        accept_event()
    elif was_dragging and context in ["hand", "player_board"]:
        suppress_next_press = true
        drag_action_requested.emit(card_index, context, release_global)
        accept_event()
    if was_dragging:
        _snap_back()

func _snap_back() -> void:
    if not is_instance_valid(self):
        return
    z_index = 100 if hovering else 0
    var tween := create_tween().set_parallel(true)
    tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "position", base_position, 0.18)
    tween.tween_property(self, "scale", Vector2.ONE, 0.18)


func _keyword_definitions() -> Array:
    return [
        {"names": ["Protector", "Ward"], "icon": "🛡", "label": "PROTECTOR", "color": Color(0.38, 0.72, 1.0, 0.96)},
        {"names": ["Guidance", "Bane"], "icon": "☠", "label": "GUIDANCE", "color": Color(0.74, 0.42, 0.92, 0.96)},
        {"names": ["Determination", "Rush"], "icon": "⚡", "label": "DETERMINATION", "color": Color(1.0, 0.64, 0.20, 0.96)},
        {"names": ["Breakthrough", "Storm"], "icon": "➤", "label": "BREAKTHROUGH", "color": Color(1.0, 0.34, 0.26, 0.96)},
        {"names": ["Restore", "Drain"], "icon": "♥", "label": "RESTORE", "color": Color(0.32, 0.88, 0.56, 0.96)},
        {"names": ["Recovery"], "icon": "↺", "label": "RECOVERY", "color": Color(0.34, 0.86, 0.92, 0.96)},
        {"names": ["Legacy", "Last Words"], "icon": "✦", "label": "LEGACY", "color": Color(0.78, 0.72, 0.52, 0.96)},
        {"names": ["Arrival", "Fanfare"], "icon": "✧", "label": "ARRIVAL", "color": Color(0.98, 0.82, 0.34, 0.96)}
    ]

func _card_keywords() -> Array:
    var text := str(data.get("display_text", data.get("text", "")))
    var explicit = data.get("keywords", [])
    var result: Array = []
    for definition in _keyword_definitions():
        var found := false
        for keyword_name in definition["names"]:
            if text.to_lower().contains(str(keyword_name).to_lower()):
                found = true
                break
            if typeof(explicit) == TYPE_ARRAY:
                for explicit_keyword in explicit:
                    if str(explicit_keyword).to_lower() == str(keyword_name).to_lower():
                        found = true
                        break
            if found:
                break
        if found:
            result.append(definition)
    return result

func _add_keyword_badges(frame: Control) -> void:
    if hidden_card:
        return
    var keywords := _card_keywords()
    if keywords.is_empty():
        return
    var _kw_ctx: String = str(data.get("_ui_context", ""))
    var _bf_badge := (_kw_ctx == "player_board" or _kw_ctx == "enemy_board")
    var use_compact := compact or _bf_badge
    var badge_row := HBoxContainer.new()
    # BATTLEFIELD: small icon badges sit below the stat row (y≈164)
    badge_row.position = Vector2(8, 162 if _bf_badge else (88 if not compact else 67))
    badge_row.size = Vector2(custom_minimum_size.x - 16, 22 if use_compact else 24)
    badge_row.alignment = BoxContainer.ALIGNMENT_CENTER
    badge_row.add_theme_constant_override("separation", 3)
    badge_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    badge_row.z_index = 90
    frame.add_child(badge_row)
    var max_badges := mini(4 if use_compact else 2, keywords.size())
    for i in range(max_badges):
        var definition: Dictionary = keywords[i]
        var badge := Label.new()
        badge.text = str(definition.get("icon", "•")) if use_compact else str(definition.get("label", "ABILITY"))
        badge.tooltip_text = str(definition.get("label", "ABILITY"))
        badge.custom_minimum_size = Vector2(24, 20) if use_compact else Vector2(92, 24)
        badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        badge.add_theme_font_size_override("font_size", card_font(11 if use_compact else 13))
        badge.add_theme_color_override("font_color", Color.WHITE)
        badge.add_theme_color_override("font_shadow_color", Color.BLACK)
        badge.add_theme_constant_override("shadow_offset_x", 1)
        badge.add_theme_constant_override("shadow_offset_y", 1)
        var style := StyleBoxFlat.new()
        style.bg_color = definition.get("color", Color(0.2, 0.3, 0.4, 0.95))
        style.border_color = Color(1.0, 1.0, 1.0, 0.75)
        style.set_border_width_all(1)
        style.set_corner_radius_all(8)
        badge.add_theme_stylebox_override("normal", style)
        badge.mouse_filter = Control.MOUSE_FILTER_PASS
        badge_row.add_child(badge)

func _build() -> void:
    var frame := Panel.new()
    frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
    frame.add_theme_stylebox_override("panel", _frame_style())
    add_child(frame)

    ready_glow = ColorRect.new()
    ready_glow.color = Color(0.35, 0.95, 0.75, 0.18)
    ready_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ready_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ready_glow.visible = bool(data.get("can_attack", false))
    frame.add_child(ready_glow)

    # Clip container — art drift/float stays strictly inside the card's art window.
    # Battlefield: art fills the entire card face (name bar only stays).
    # Other modes: original compact art window with room for ability text.
    # Only cards actually on the board get the compact portrait layout.
    # display_mode defaults to BATTLEFIELD for every CardView and is never
    # changed, so we use _ui_context (set by rebuild_board) as the real signal.
    var _ui_ctx: String = str(data.get("_ui_context", ""))
    var _bf: bool = (_ui_ctx == "player_board" or _ui_ctx == "enemy_board") and not hidden_card
    var art_top: float = 24.0 if not compact else 20.0
    # BATTLEFIELD board cards: 124×124 circle portrait centred in the card.
    # All other contexts: original compact rect with room for ability text below.
    var art_x: float = (custom_minimum_size.x - 124.0) * 0.5 if _bf else 8.0
    var art_w: float = 124.0 if _bf else (custom_minimum_size.x - 16.0)
    var art_h: float = 124.0 if _bf else (82.0 if not compact else 64.0)
    art_clip = Panel.new()
    art_clip.position = Vector2(art_x, 6.0 if _bf else art_top)
    art_clip.size = Vector2(art_w, art_h)
    art_clip.clip_contents = true
    art_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
    if _bf:
        var circle_st := StyleBoxFlat.new()
        circle_st.bg_color = Color(0.04, 0.06, 0.10)
        circle_st.set_corner_radius_all(62)   # radius = half of 124 → full circle
        art_clip.add_theme_stylebox_override("panel", circle_st)
    else:
        art_clip.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
    frame.add_child(art_clip)

    art_rect = TextureRect.new()
    art_rect.position = Vector2.ZERO
    art_rect.size = art_clip.size
    art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    art_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    if hidden_card:
        if sleeve_class != "":
            art_rect.texture = _svg_texture(_class_card_back_svg(sleeve_class))
        else:
            art_rect.texture = _svg_texture(_card_back_svg())
    else:
        art_rect.texture = _art_texture()
    art_clip.add_child(art_rect)
    art_home = Vector2.ZERO

    _add_keyword_badges(frame)

    if bool(data.get("evolved", false)) and not hidden_card:
        var evolved_label := Label.new()
        evolved_label.text = "EVOLVED"
        evolved_label.position = Vector2(18, 4)
        evolved_label.size = Vector2(custom_minimum_size.x - 52, 22)
        evolved_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        evolved_label.add_theme_font_size_override("font_size", card_font(11))
        evolved_label.add_theme_color_override("font_color", Color(0.75,1.0,1.0))
        evolved_label.add_theme_color_override("font_shadow_color", Color.BLACK)
        evolved_label.add_theme_constant_override("shadow_offset_x",1)
        evolved_label.add_theme_constant_override("shadow_offset_y",1)
        evolved_label.z_index = 200
        frame.add_child(evolved_label)

    living_glow = Panel.new()
    if _bf and not hidden_card:
        # In portrait mode the rarity glow wraps the circle, not the outer frame
        living_glow.position = art_clip.position
        living_glow.size     = art_clip.size
        var lg_st := _living_glow_style()
        lg_st.set_corner_radius_all(62)
        living_glow.add_theme_stylebox_override("panel", lg_st)
    else:
        living_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        living_glow.add_theme_stylebox_override("panel", _living_glow_style())
    living_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    frame.add_child(living_glow)

    shine_strip = ColorRect.new()
    shine_strip.position = Vector2(-custom_minimum_size.x, 0)
    shine_strip.size = Vector2(34, custom_minimum_size.y)
    shine_strip.color = Color(0.92, 0.98, 1.0, 0.0)
    shine_strip.rotation = -0.20
    shine_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
    shine_strip.visible = str(data.get("rarity", "Bronze")) in ["Legendary", "Platinum"] or bool(data.get("evolved", false))
    frame.add_child(shine_strip)

    foil_glow = ColorRect.new()
    foil_glow.position = art_clip.position
    foil_glow.size = art_clip.size
    foil_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    foil_glow.color = Color(0.75, 0.95, 1.0, 0.0)
    foil_glow.visible = str(data.get("rarity", "Bronze")) == "Platinum" or bool(data.get("evolved", false))
    frame.add_child(foil_glow)

    # Shiny: rainbow foil overlay + 10 sparkle dots for the holographic effect.
    # Visibility is driven entirely by is_shiny in the card data dict, so any
    # CardView receiving a shiny card renders correctly without extra wiring.
    var _is_shiny: bool = bool(data.get("is_shiny", false))
    shiny_rainbow = ColorRect.new()
    shiny_rainbow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shiny_rainbow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    shiny_rainbow.color = Color(0.8, 0.4, 1.0, 0.0)
    shiny_rainbow.visible = _is_shiny
    frame.add_child(shiny_rainbow)
    for _si in 10:
        var _sp := ColorRect.new()
        _sp.size = Vector2(5, 5)
        _sp.color = Color(1.0, 1.0, 0.9, 0.0)
        _sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _sp.visible = _is_shiny
        frame.add_child(_sp)
        shiny_sparks.append(_sp)
        _spark_timers.append(randf_range(0.0, 2.8))

    name_label = Label.new()
    name_label.position = Vector2(8, 4)
    name_label.size = Vector2(custom_minimum_size.x - 16, 24)
    name_label.text = (sleeve_class.to_upper() if sleeve_class != "" else "WALKING FREE") if hidden_card else str(data.get("name", "Card"))
    name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name_label.add_theme_font_size_override("font_size", card_font(13 if not compact else 11))
    name_label.add_theme_color_override("font_color", Color(0.97, 0.95, 0.86))
    name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    name_label.visible = not _bf   # hidden in portrait mode — no room at small scale
    frame.add_child(name_label)

    if not hidden_card:
        var rarity_label := Label.new()
        rarity_label.position = Vector2(custom_minimum_size.x - 55, 25 if not compact else 20)
        rarity_label.size = Vector2(50, 15)
        rarity_label.text = "EVOLVED" if bool(data.get("evolved", false)) else str(data.get("rarity", "Bronze")).to_upper()
        rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        rarity_label.add_theme_font_size_override("font_size", card_font(7 if not compact else 6))
        rarity_label.add_theme_color_override("font_color", Color(0.9,0.95,1.0))
        rarity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        frame.add_child(rarity_label)

        var set_badge := Label.new()
        set_badge.position = Vector2(7, 27 if not compact else 22)
        set_badge.size = Vector2(34, 16)
        set_badge.text = "☀ " + str(data.get("set_code", "JD"))
        set_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
        set_badge.add_theme_font_size_override("font_size", card_font(8 if not compact else 7))
        set_badge.add_theme_color_override("font_color", Color(1.0, 0.82, 0.36))
        set_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
        frame.add_child(set_badge)

    cost_label = _stat_orb(str(data.get("cost", 0)), Color(0.18, 0.58, 0.96))
    cost_label.position = Vector2(-10, -11)
    frame.add_child(cost_label)

    if not hidden_card:
        if _bf and not bool(data.get("is_amulet", false)):
            # ── Battlefield portrait: circle art, stat badges below ───────────
            var stat_y := art_clip.position.y + art_clip.size.y + 4.0

            # Attack badge — bottom left
            var atk_bg := StyleBoxFlat.new()
            atk_bg.bg_color = Color(0.42, 0.13, 0.04, 0.94)
            atk_bg.border_color = Color(1.0, 0.72, 0.30)
            atk_bg.set_border_width_all(2); atk_bg.set_corner_radius_all(8)
            var atk_pan := Panel.new()
            atk_pan.position = Vector2(2, stat_y)
            atk_pan.size = Vector2(58, 30); atk_pan.mouse_filter = Control.MOUSE_FILTER_IGNORE
            atk_pan.add_theme_stylebox_override("panel", atk_bg); frame.add_child(atk_pan)
            stats_label = Label.new()
            stats_label.text = "⚔ %d" % int(data.get("attack", 0))
            stats_label.position = Vector2(0, 3); stats_label.size = Vector2(58, 24)
            stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            stats_label.add_theme_font_size_override("font_size", card_font(14))
            stats_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.60))
            stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
            atk_pan.add_child(stats_label)

            # Health badge — bottom right
            var hp_bg := StyleBoxFlat.new()
            hp_bg.bg_color = Color(0.40, 0.06, 0.08, 0.94)
            hp_bg.border_color = Color(1.0, 0.42, 0.42)
            hp_bg.set_border_width_all(2); hp_bg.set_corner_radius_all(8)
            var hp_pan := Panel.new()
            hp_pan.position = Vector2(custom_minimum_size.x - 60, stat_y)
            hp_pan.size = Vector2(58, 30); hp_pan.mouse_filter = Control.MOUSE_FILTER_IGNORE
            hp_pan.add_theme_stylebox_override("panel", hp_bg); frame.add_child(hp_pan)
            var hp_lbl := Label.new()
            hp_lbl.text = "♥ %d" % int(data.get("health", 0))
            hp_lbl.position = Vector2(0, 3); hp_lbl.size = Vector2(58, 24)
            hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            hp_lbl.add_theme_font_size_override("font_size", card_font(14))
            hp_lbl.add_theme_color_override("font_color", Color(1.0, 0.58, 0.60))
            hp_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
            hp_pan.add_child(hp_lbl)

        else:
            # ── Non-battlefield / amulet: original compact layout ────────────
            stats_label = Label.new()
            stats_label.position = Vector2(7, custom_minimum_size.y - 34)
            stats_label.size = Vector2(custom_minimum_size.x - 14, 28)
            stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            stats_label.add_theme_color_override("font_color", Color.WHITE)
            stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
            if bool(data.get("is_amulet", false)):
                stats_label.text = "AMULET"
                stats_label.add_theme_font_size_override("font_size", card_font(15 if not compact else 13))
                stats_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.34))
            else:
                stats_label.text = "%d     %d" % [int(data.get("attack", 0)), int(data.get("health", 0))]
                stats_label.add_theme_font_size_override("font_size", card_font(19 if not compact else 17))
            frame.add_child(stats_label)

            if not bool(data.get("is_amulet", false)):
                var sword := Label.new()
                sword.text = "⚔"
                sword.position = Vector2(17, custom_minimum_size.y - 35)
                sword.add_theme_font_size_override("font_size", card_font(18))
                sword.mouse_filter = Control.MOUSE_FILTER_IGNORE
                frame.add_child(sword)

                var heart := Label.new()
                heart.text = "♥"
                heart.position = Vector2(custom_minimum_size.x - 39, custom_minimum_size.y - 35)
                heart.add_theme_font_size_override("font_size", card_font(18))
                heart.add_theme_color_override("font_color", Color(1.0, 0.35, 0.38))
                heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
                frame.add_child(heart)

            ability_label = Label.new()
            ability_label.position = Vector2(9, 112 if not compact else 88)
            ability_label.size = Vector2(custom_minimum_size.x - 18, 39 if not compact else 30)
            ability_label.text = str(data.get("display_text", data.get("text", "")))
            ability_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            ability_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
            ability_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
            ability_label.add_theme_font_size_override("font_size", card_font(10 if not compact else 9))
            ability_label.add_theme_color_override("font_color", Color(0.88, 0.88, 0.84))
            ability_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
            frame.add_child(ability_label)

        if bool(data.get("is_sponsor", false)) or bool(data.get("is_sponsee", false)):
            var bond_badge := Label.new()
            bond_badge.text = "SPONSOR" if bool(data.get("is_sponsor", false)) else "SPONSEE"
            bond_badge.position = Vector2(28, 78 if not compact else 59)
            bond_badge.size = Vector2(custom_minimum_size.x - 56, 22)
            bond_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            bond_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
            bond_badge.add_theme_font_size_override("font_size", card_font(10 if not compact else 8))
            bond_badge.add_theme_color_override("font_color", Color(1.0, 0.90, 0.42))
            bond_badge.add_theme_color_override("font_shadow_color", Color.BLACK)
            bond_badge.add_theme_constant_override("shadow_offset_x", 2)
            bond_badge.add_theme_constant_override("shadow_offset_y", 2)
            bond_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
            frame.add_child(bond_badge)
    _init_rarity_vfx(frame)

func set_selected(value: bool) -> void:
    selected = value
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "scale", Vector2(1.08, 1.08) if value else Vector2.ONE, 0.15)
    modulate = Color(1.1, 1.1, 0.8) if value else Color.WHITE

## ── Rarity helper ─────────────────────────────────────────────────────────────
func _rarity_tier_val() -> int:
    if _rarity_tier_cache >= 0:
        return _rarity_tier_cache
    match str(data.get("rarity", "Bronze")):
        "Silver":    _rarity_tier_cache = 1
        "Gold":      _rarity_tier_cache = 2
        "Epic":      _rarity_tier_cache = 3
        "Legendary": _rarity_tier_cache = 4
        "Platinum":  _rarity_tier_cache = 5
        _:           _rarity_tier_cache = 0
    # Evolved cards punch up to at least Epic tier visually
    if bool(data.get("evolved", false)):
        _rarity_tier_cache = maxi(_rarity_tier_cache, 3)
    return _rarity_tier_cache

## Spawn orbiting energy orbs for Legendary / Platinum cards.
## Called at end of _build() so `frame` is available.
func _init_rarity_vfx(frame: Control) -> void:
    var tier := _rarity_tier_val()
    if tier < 4 or hidden_card or graphics_quality == 0 or display_mode == DisplayMode.PREVIEW:
        return
    var orb_count := 4 if tier >= 5 else 3
    for _i in range(orb_count):
        var orb := ColorRect.new()
        orb.size = Vector2(9, 9) if tier >= 5 else Vector2(7, 7)
        orb.color = Color(1.0, 0.82, 0.28, 0.0)  # invisible until _process updates
        orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
        orb.z_index = 96
        frame.add_child(orb)
        _orb_nodes.append(orb)

## ── Attack feel animation ──────────────────────────────────────────────────────
## All three methods are fire-and-forget (no await).
## Caller in main.gd controls sequencing with explicit timers.

## Returns the class-specific combat accent color used for charge/flash tints.
func _class_combat_color() -> Color:
    match str(data.get("class", data.get("faction", ""))):
        "Hope":     return Color(1.35, 0.70, 2.20)   # vivid purple
        "Courage":  return Color(2.40, 0.75, 0.45)   # burning red-orange
        "Purpose":  return Color(2.00, 1.50, 0.40)   # gold
        "Serenity": return Color(0.45, 1.90, 1.90)   # cold teal
        _:          return Color(1.70, 1.60, 1.30)   # warm white

func play_attack_wind_up(lean_dir: Vector2) -> void:
    ## Portrait snaps to attention then leans hard away — "coming to life" charge.
    if display_mode != DisplayMode.BATTLEFIELD:
        return
    _idle_paused = true
    var tier := _rarity_tier_val()

    # More dramatic squash-lean than before
    var sx  := 0.66 if tier >= 4 else (0.72 if tier >= 3 else 0.78)
    var sy  := 1.34 if tier >= 4 else (1.28 if tier >= 3 else 1.20)
    var lean := 15.0 + tier * 3.5

    var tw := create_tween().set_parallel(true)
    tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tw.tween_property(self, "scale",    Vector2(sx, sy),                   0.15)
    tw.tween_property(self, "position", base_position + lean_dir * lean,   0.14)
    tw.tween_property(self, "rotation", lean_dir.x * -0.20,               0.14)

    # Art charges up — portrait zooms in as if the character is rearing back
    if art_rect != null and is_instance_valid(art_rect):
        art_rect.pivot_offset = art_rect.size * 0.5
        var atw := create_tween().set_parallel(true)
        atw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        var charge_z := 1.24 + tier * 0.05
        atw.tween_property(art_rect, "scale",    Vector2(charge_z, charge_z),         0.15)
        atw.tween_property(art_rect, "position", art_home + lean_dir * -(4.0 + tier), 0.14)

    # Class-coloured charge flash — character glows their faction colour
    var ctw := create_tween()
    ctw.tween_property(self, "modulate", _class_combat_color(), 0.09)
    ctw.tween_property(self, "modulate", Color.WHITE,            0.07)

func play_attack_lunge(toward_dir: Vector2) -> void:
    ## Explosive stretch toward the target — the character erupts out of the portrait.
    if display_mode != DisplayMode.BATTLEFIELD:
        return
    var tier := _rarity_tier_val()

    # More aggressive stretch and distance than before
    var sx    := 1.40 if tier >= 4 else (1.32 if tier >= 3 else 1.22)
    var sy    := 0.68 if tier >= 4 else (0.74 if tier >= 3 else 0.82)
    var lunge := 28.0 + tier * 5.0

    var tw := create_tween().set_parallel(true)
    tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tw.tween_property(self, "scale",    Vector2(sx, sy),                      0.06)
    tw.tween_property(self, "position", base_position + toward_dir * lunge,   0.06)
    tw.tween_property(self, "rotation", toward_dir.x * 0.14,                  0.06)

    # Art slams into the strike — character is fully committed
    _art_lunge(toward_dir)

    # Explosive class-coloured flash on release
    var base_flash := _class_combat_color()
    var flash_col  := Color(
        minf(base_flash.r * 2.2, 3.5),
        minf(base_flash.g * 2.2, 3.5),
        minf(base_flash.b * 2.2, 3.5)
    )
    var ftw := create_tween()
    ftw.tween_property(self, "modulate", flash_col,   0.04)
    ftw.tween_property(self, "modulate", Color.WHITE, 0.14)

func play_attack_settle() -> void:
    ## Springy bounce back — character lands satisfied after the strike.
    if display_mode != DisplayMode.BATTLEFIELD:
        return
    _art_settle_to_home()
    var tw := create_tween().set_parallel(true)
    tw.set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
    tw.tween_property(self, "scale",    Vector2.ONE,   0.34)
    tw.tween_property(self, "position", base_position, 0.32)
    tw.tween_property(self, "rotation", 0.0,           0.28)
    # Brief satisfied faction-colour after-glow on landing
    var glow := _class_combat_color()
    glow.a = 0.0
    var stw := create_tween()
    stw.tween_property(self, "modulate", Color(glow.r * 0.6 + 0.4, glow.g * 0.6 + 0.4, glow.b * 0.6 + 0.4), 0.06)
    stw.tween_property(self, "modulate", Color.WHITE, 0.18)
    tw.finished.connect(func():
        if is_instance_valid(self) and not is_queued_for_deletion() and is_inside_tree():
            _idle_paused = false
    )

## Art erupts toward the strike — character commits fully to the attack.
func _art_lunge(toward_dir: Vector2) -> void:
    if art_rect == null or not is_instance_valid(art_rect): return
    var tier := _rarity_tier_val()
    var zoom  := 1.32 + tier * 0.05   # much bigger than before
    var shift := toward_dir * (12.0 + tier * 3.0)   # big slam shift
    art_rect.pivot_offset = art_rect.size * 0.5
    var tw := create_tween().set_parallel(true)
    tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tw.tween_property(art_rect, "scale",    Vector2(zoom, zoom), 0.06)
    tw.tween_property(art_rect, "position", art_home + shift,    0.06)

## Resets art position and scale during the settle phase.
func _art_settle_to_home() -> void:
    if art_rect == null or not is_instance_valid(art_rect): return
    art_rect.pivot_offset = art_rect.size * 0.5
    var tw := create_tween().set_parallel(true)
    tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tw.tween_property(art_rect, "scale", Vector2.ONE, 0.26)
    tw.tween_property(art_rect, "position", art_home, 0.26)

## Brief scale-pop + colored flash for stat buffs. Fire-and-forget.
## Skips if the card is already in a combat animation.
func play_buff_vfx(stat_text: String, color: Color) -> void:
    if _idle_paused or not is_inside_tree():
        return
    pivot_offset = size * 0.5
    var flash := Color(minf(color.r * 1.55, 2.4), minf(color.g * 1.55, 2.4), minf(color.b * 1.55, 2.4))
    var tw := create_tween()
    tw.tween_property(self, "scale", Vector2(1.14, 1.14), 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tw.parallel().tween_property(self, "modulate", flash, 0.09)
    tw.tween_property(self, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tw.parallel().tween_property(self, "modulate", Color.WHITE, 0.22)

func summon_animation() -> void:
    # SV-style slam: drop from above → squash on impact → bounce settle
    pivot_offset = custom_minimum_size * 0.5
    var tier    := _rarity_tier_val()
    var land_y  := position.y
    var drop_h  := 200.0 + tier * 18.0
    var drop_d  := 0.15 if tier >= 4 else 0.20

    # Start: high above, tilted, semi-transparent
    position.y = land_y - drop_h
    scale      = Vector2(0.72, 0.72)
    rotation   = randf_range(-0.12, 0.12)
    modulate   = Color(2.0, 2.0, 2.0, 0.0)

    # Phase 1 — drop fast, squash as it lands
    var slam := create_tween().set_parallel(true)
    slam.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    slam.tween_property(self, "position:y",  land_y,           drop_d)
    slam.tween_property(self, "scale",       Vector2(1.22, 0.78), drop_d)
    slam.tween_property(self, "rotation",    0.0,              drop_d * 0.7)
    slam.tween_property(self, "modulate",    _faction_flash_color(), drop_d * 0.45)

    # Phase 2 — spring back out of squash into normal
    var bounce := create_tween().set_parallel(true)
    bounce.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    bounce.tween_property(self, "scale",    Vector2.ONE,   0.30).set_delay(drop_d)
    bounce.tween_property(self, "modulate", Color.WHITE,   0.24).set_delay(drop_d)
    bounce.tween_property(self, "rotation", 0.0,           0.12).set_delay(drop_d)

func _faction_flash_color() -> Color:
    var faction := str(data.get("faction", str(data.get("class", ""))))
    var tier    := _rarity_tier_val()
    var i       := 1.8 + tier * 0.10
    match faction:
        "Courage":   return Color(i * 1.3, i * 0.55, i * 0.45, 1.0)
        "Hope":      return Color(i * 0.85, i * 0.72, i * 1.25, 1.0)
        "Serenity":  return Color(i * 0.55, i * 1.05, i * 1.20, 1.0)
        "Purpose":   return Color(i * 1.10, i * 0.88, i * 0.42, 1.0)
        _:           return Color(i, i, i, 1.0)

func damage_flash() -> void:
    var start := position
    var tween := create_tween()
    tween.tween_property(self, "modulate", Color(1.8, 0.35, 0.35), 0.06)
    tween.tween_property(self, "position", start + Vector2(8, 0), 0.04)
    tween.tween_property(self, "position", start - Vector2(8, 0), 0.04)
    tween.tween_property(self, "position", start, 0.04)
    tween.tween_property(self, "modulate", Color.WHITE, 0.12)

func death_animation() -> void:
    _idle_paused = true
    var tier := _rarity_tier_val()
    # Legendary / Platinum: brief scale burst + flash before the collapse.
    if tier >= 4:
        var burst := create_tween().set_parallel(true)
        burst.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        var burst_col := Color(0.6, 1.8, 2.0) if tier >= 5 else Color(2.0, 1.6, 0.4)
        burst.tween_property(self, "modulate", burst_col, 0.06)
        burst.tween_property(self, "scale", Vector2(1.36, 1.36), 0.06)
    # Collapse — delay slightly for higher rarities so burst lands first.
    var delay := 0.07 if tier >= 4 else 0.0
    var collapse := create_tween().set_parallel(true)
    collapse.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    collapse.tween_property(self, "scale",        Vector2(0.12, 0.12),            0.26).set_delay(delay)
    collapse.tween_property(self, "rotation",     randf_range(-0.55, 0.55),       0.26).set_delay(delay)
    collapse.tween_property(self, "modulate:a",   0.0,                            0.24).set_delay(delay)
    collapse.tween_property(self, "modulate",     Color.WHITE,                    0.06).set_delay(delay)

func phoenix_death_animation() -> void:
    # Phoenix Rising: dissolves upward into golden light rather than crumpling.
    modulate = Color(1.0, 0.72, 0.30, 1.0)
    var tween := create_tween().set_parallel(true)
    tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "position:y", position.y - 40.0, 0.42)
    tween.tween_property(self, "modulate:a", 0.0, 0.42)
    tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.42)

func _hover_on() -> void:
    if hidden_card or display_mode == DisplayMode.PREVIEW:
        return
    hovering = true
    z_index = 100
    var tween := create_tween().set_parallel(true)
    tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    var target_scale := Vector2(1.12, 1.12) if not compact else Vector2(1.07, 1.07)
    var lift := 24.0 if not compact else 10.0
    tween.tween_property(self, "scale", target_scale, 0.12)
    tween.tween_property(self, "position:y", base_position.y - lift, 0.12)

func _hover_off() -> void:
    hovering = false
    rotation = 0.0
    if hidden_card or selected or display_mode == DisplayMode.PREVIEW:
        return
    z_index = 0
    var tween := create_tween().set_parallel(true)
    tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "scale", Vector2.ONE, 0.12)
    tween.tween_property(self, "position:y", base_position.y, 0.12)


func _process(delta: float) -> void:
    if touch_holding and not touch_hold_fired and not hidden_card:
        touch_hold_time += delta
        if touch_hold_time >= LONG_PRESS_SECONDS:
            touch_hold_fired = true
            touch_holding = false
            suppress_next_press = true
            inspect_requested.emit(data.duplicate(true))
    shimmer_time += delta
    _aura_time += delta
    var life_wave: float = (sin(shimmer_time * 1.8 + idle_phase) + 1.0) * 0.5
    if foil_glow != null and foil_glow.visible:
        var pulse: float = (sin(shimmer_time * 3.2) + 1.0) * 0.5
        foil_glow.color = Color(0.62 + pulse * 0.25, 0.86 + pulse * 0.10, 1.0, 0.08 + pulse * 0.12)
    if shiny_rainbow != null and shiny_rainbow.visible:
        shiny_rainbow.color = Color.from_hsv(fmod(shimmer_time * 0.18, 1.0), 0.60, 1.0, 0.20)
        for _si in shiny_sparks.size():
            var _old_t: float = _spark_timers[_si]
            _spark_timers[_si] = fmod(_old_t + delta, 2.8)
            var _phase: float = _spark_timers[_si]
            var _sp: ColorRect = shiny_sparks[_si]
            if _old_t > _phase:
                _sp.position = Vector2(randf_range(2.0, custom_minimum_size.x - 8.0), randf_range(2.0, custom_minimum_size.y - 8.0))
            var _bright := 0.0
            if _phase < 0.30: _bright = _phase / 0.30
            elif _phase < 0.60: _bright = 1.0 - (_phase - 0.30) / 0.30
            _sp.color = Color.from_hsv(fmod(shimmer_time * 0.4 + float(_si) * 0.1, 1.0), 0.4, 1.0, _bright * 0.92)
    var tier := _rarity_tier_val()
    if living_glow != null:
        var base_alpha := 0.42 + life_wave * 0.35
        # Epic+: deeper aura pulse layered on top
        if tier >= 3:
            var epic_pulse := maxf(0.0, sin(shimmer_time * 0.85 + idle_phase) * sin(shimmer_time * 2.1 + idle_phase * 0.7))
            base_alpha += epic_pulse * 0.28
            if bool(data.get("evolved", false)):
                base_alpha += epic_pulse * 0.15
        living_glow.modulate.a = base_alpha
    if art_rect != null and not hidden_card:
        var drift := Vector2(sin(shimmer_time * 0.72 + idle_phase) * 1.8, cos(shimmer_time * 0.58 + idle_phase) * 1.2)
        # Legendary+: character floats up and down inside the art window
        var float_y := 0.0
        if tier >= 4 and not _idle_paused:
            float_y = sin(shimmer_time * 1.05 + idle_phase) * 3.5
            if bool(data.get("evolved", false)):
                float_y *= 1.5
        if hovering:
            var mouse_ratio := get_local_mouse_position() / Vector2(maxf(size.x, 1.0), maxf(size.y, 1.0)) - Vector2(0.5, 0.5)
            drift += mouse_ratio * 5.0
        art_rect.position = art_home + drift + Vector2(0.0, float_y)
    if shine_strip != null and shine_strip.visible:
        var cycle := fmod(shimmer_time + idle_phase, 3.8)
        shine_strip.position.x = lerpf(-55.0, custom_minimum_size.x + 30.0, cycle / 3.8)
        shine_strip.color = Color(0.92, 0.98, 1.0, 0.16 if cycle > 0.35 and cycle < 3.2 else 0.0)
    # PREVIEW mode: no scale/rotation animation — card size is fixed by the slot.
    if display_mode == DisplayMode.BATTLEFIELD:
        if not _idle_paused:
            if bool(data.get("can_attack", false)) and not hidden_card and not hovering:
                var attack_pulse := 1.0 + sin(shimmer_time * 3.6 + idle_phase) * 0.012
                scale = Vector2(attack_pulse, attack_pulse)
            elif not hovering and not hidden_card and tier >= 1:
                # Rarity-scaled breathing for idle (non-attacking) cards
                var breath_amp := 0.0
                match tier:
                    1: breath_amp = 0.006
                    2: breath_amp = 0.009
                    3: breath_amp = 0.011
                    _: breath_amp = 0.014  # Legendary / Platinum
                if bool(data.get("evolved", false)):
                    breath_amp *= 1.4
                var breath := 1.0 + sin(shimmer_time * 1.55 + idle_phase) * breath_amp
                scale = Vector2(breath, breath)
        if hovering and not hidden_card:
            var local_mouse: Vector2 = get_local_mouse_position()
            var x_ratio: float = clampf((local_mouse.x / maxf(size.x, 1.0)) - 0.5, -0.5, 0.5)
            rotation = x_ratio * 0.10
    # Orbiting energy orbs for Legendary / Platinum
    if _orb_nodes.size() > 0 and not hidden_card and not _idle_paused:
        var orb_count := _orb_nodes.size()
        var orbit_r: float = pivot_offset.x * 0.96
        var orb_speed := 1.5 if tier >= 5 else 1.05
        if bool(data.get("evolved", false)):
            orb_speed *= 1.35
        for _oi in range(orb_count):
            var _orb: ColorRect = _orb_nodes[_oi]
            if not is_instance_valid(_orb):
                continue
            var _angle := _aura_time * orb_speed + float(_oi) * TAU / float(orb_count)
            _orb.position = pivot_offset + Vector2(cos(_angle) * orbit_r, sin(_angle) * orbit_r * 0.42) - _orb.size * 0.5
            var _bright := 0.52 + sin(_aura_time * 2.8 + float(_oi) * 1.3) * 0.22
            if tier >= 5:  # Platinum: rainbow cycle
                _orb.color = Color.from_hsv(fmod(_aura_time * 0.28 + float(_oi) * 0.33, 1.0), 0.76, 1.0, _bright)
            else:          # Legendary: gold-orange
                _orb.color = Color(1.0, 0.72 + sin(_aura_time * 1.8 + float(_oi)) * 0.14, 0.22, _bright)

func _living_glow_style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0, 0, 0, 0)
    var rarity := str(data.get("rarity", "Bronze"))
    var glow := Color(0.38, 0.65, 0.78, 0.28)
    if rarity == "Silver":    glow = Color(0.78, 0.88, 1.0, 0.36)
    elif rarity == "Gold":    glow = Color(1.0, 0.82, 0.28, 0.40)
    elif rarity == "Epic":    glow = Color(0.72, 0.44, 1.0, 0.48)
    elif rarity == "Legendary": glow = Color(1.0, 0.68, 0.13, 0.60)
    elif rarity == "Platinum":  glow = Color(0.50, 0.92, 1.0, 0.75)
    if bool(data.get("evolved", false)):
        glow = Color(0.32, 0.94, 1.0, 0.68)
    if bool(data.get("is_shiny", false)):
        glow = Color(0.88, 0.65, 1.0, 0.74)
    style.border_color = glow
    var border_w := 6 if rarity == "Platinum" else (5 if rarity == "Legendary" else (4 if rarity in ["Epic", "Gold"] else 3))
    if bool(data.get("evolved", false)): border_w = maxi(border_w, 4)
    style.set_border_width_all(border_w)
    style.set_corner_radius_all(9)
    style.shadow_color = glow
    style.shadow_size = 24 if rarity == "Platinum" else (18 if rarity == "Legendary" else (12 if rarity == "Epic" else (9 if bool(data.get("evolved", false)) else 7)))
    return style

func _frame_style() -> StyleBoxFlat:
    # Board portrait mode — the circle carries all visual identity.
    # Return a fully transparent frame so no rectangle shows behind the circle.
    var _ctx: String = str(data.get("_ui_context", ""))
    if (_ctx == "player_board" or _ctx == "enemy_board") and not hidden_card:
        var bf := StyleBoxFlat.new()
        bf.bg_color = Color(0, 0, 0, 0)
        return bf
    var style := StyleBoxFlat.new()
    var faction := str(data.get("faction", "Fellowship"))
    var base := Color(0.15, 0.18, 0.24)
    if faction == "Serenity": base = Color(0.08, 0.25, 0.34)
    elif faction == "Courage": base = Color(0.34, 0.13, 0.12)
    elif faction == "Purpose": base = Color(0.29, 0.20, 0.08)
    elif faction == "Hope": base = Color(0.20, 0.13, 0.31)
    elif faction == "Universal": base = Color(0.16, 0.20, 0.24)
    style.bg_color = base
    var rarity := str(data.get("rarity", "Bronze"))
    var rarity_color := Color(0.72, 0.42, 0.20)
    if rarity == "Silver": rarity_color = Color(0.76, 0.82, 0.88)
    elif rarity == "Legendary": rarity_color = Color(0.96, 0.70, 0.20)
    elif rarity == "Platinum": rarity_color = Color(0.72, 0.92, 1.0)
    if bool(data.get("evolved", false)):
        rarity_color = Color(0.42, 0.95, 1.0)
        style.shadow_color = Color(0.25, 0.8, 1.0, 0.65)
    style.border_color = rarity_color if not hidden_card else Color(0.34, 0.64, 0.72)
    style.set_border_width_all(3)
    style.set_corner_radius_all(9)
    if not bool(data.get("evolved", false)):
        style.shadow_color = Color(0, 0, 0, 0.65)
    style.shadow_size = 12 if bool(data.get("evolved", false)) else 8
    return style

func _stat_orb(value: String, color: Color) -> Label:
    var label := Label.new()
    label.custom_minimum_size = Vector2(46, 46)
    label.size = Vector2(46, 46)
    label.text = value
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", card_font(27))
    label.add_theme_color_override("font_color", Color.WHITE)
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.border_color = Color(0.85, 0.92, 1.0)
    style.set_border_width_all(2)
    style.set_corner_radius_all(23)
    label.add_theme_stylebox_override("normal", style)
    return label

func _svg_texture(svg: String) -> Texture2D:
    var image := Image.new()
    image.load_svg_from_string(svg, 1.2)
    return ImageTexture.create_from_image(image)



func _ensure_catalog_loaded() -> void:
    if _catalog_loaded:
        return
    _catalog_loaded = true
    _catalog_by_name.clear()
    if not FileAccess.file_exists("res://data/cards.json"):
        return
    var file := FileAccess.open("res://data/cards.json", FileAccess.READ)
    if file == null:
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if parsed is Array:
        for entry_variant in parsed:
            if entry_variant is Dictionary:
                var entry: Dictionary = entry_variant
                var key := str(entry.get("name", "")).strip_edges().to_lower()
                if not key.is_empty():
                    _catalog_by_name[key] = entry.duplicate(true)

func _hydrate_card_data(source: Dictionary) -> Dictionary:
    _ensure_catalog_loaded()
    var result: Dictionary = source.duplicate(true)
    var key := str(result.get("name", "")).strip_edges().to_lower()
    if _catalog_by_name.has(key):
        var catalog_entry: Dictionary = _catalog_by_name[key]
        for field in ["id", "class", "rarity", "cost", "attack", "health", "max_health", "effect", "max_copies", "is_amulet"]:
            if (not result.has(field)) or result.get(field) == null or str(result.get(field, "")).is_empty():
                if catalog_entry.has(field):
                    result[field] = catalog_entry[field]
        if not result.has("display_text") and catalog_entry.has("effect"):
            result["display_text"] = catalog_entry["effect"]
        if not result.has("text") and catalog_entry.has("effect"):
            result["text"] = catalog_entry["effect"]
    return result

func _load_card_art_path(path: String) -> Texture2D:
    if _art_cache.has(path):
        return _art_cache[path] as Texture2D
    # Always try reading raw file bytes first.  This bypasses Godot's import
    # cache (.godot/imported/) entirely so the game always shows the latest
    # source image — even if the local .ctex cache is stale from a previous
    # version of the art.  Works in both the editor and when running from the
    # project directory.
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
            _art_cache[path] = texture
            return texture
    # Exported PCK fallback: raw .jpg files are not packed into the APK/PCK —
    # only their compiled .ctex counterparts are.  load() reads from the PCK
    # and is the correct path for shipped Android/desktop exports.
    var imported: Texture2D = load(path) as Texture2D
    if imported != null:
        _art_cache[path] = imported
        return imported
    return null

func _art_texture() -> Texture2D:
    # Shiny variant override: The Sponsor has dedicated premium holographic art
    # with platinum light rays and rainbow iridescence baked into the image.
    var _card_id: String = str(data.get("id", "")).strip_edges().to_lower()
    if bool(data.get("is_shiny", false)) and _card_id == "jd-080":
        var shiny_key := "jd-080-shiny"
        if _art_cache.has(shiny_key):
            return _art_cache[shiny_key] as Texture2D
        var shiny_t := _load_card_art_path("res://assets/cards/full/jd-080-shiny.jpg")
        if shiny_t != null:
            _art_cache[shiny_key] = shiny_t
            return shiny_t

    # All art resolution goes through the shared CardArt autoload so that
    # battle cards use the exact same texture as collection and pack opening.
    # The static _art_cache keeps the autoload from being hit every render frame.
    var cache_key: String = str(data.get("name", "?")).strip_edges()
    if _art_cache.has(cache_key):
        return _art_cache[cache_key] as Texture2D
    var t: Texture2D = CardArt.resolve(data)
    if t != null:
        _art_cache[cache_key] = t
        return t
    # Fallback: procedural SVG so the card is never visually blank in battle.
    return _svg_texture(_art_svg())

func _card_back_svg() -> String:
    return _class_card_back_svg("")

## Per-class sleeve designs. Each class has unique colours and a signature motif.
func _class_card_back_svg(cls: String) -> String:
    match cls:
        "Hope":
            return """<svg xmlns='http://www.w3.org/2000/svg' width='142' height='186'>
<defs>
<radialGradient id='a' cx='50%' cy='100%' r='130%'><stop stop-color='#2a0f4e'/><stop offset='1' stop-color='#050209'/></radialGradient>
<radialGradient id='b' cx='50%' cy='55%' r='45%'><stop stop-color='#7b36d4' stop-opacity='.5'/><stop offset='1' stop-color='#2a0f4e' stop-opacity='0'/></radialGradient>
</defs>
<rect width='142' height='186' rx='9' fill='url(#a)'/><rect width='142' height='186' rx='9' fill='url(#b)'/>
<ellipse cx='71' cy='190' rx='75' ry='40' fill='#8b3cf7' opacity='.25'/>
<rect x='5' y='5' width='132' height='176' rx='7' fill='none' stroke='#e7c96b' stroke-width='1.5' opacity='.65'/>
<rect x='9' y='9' width='124' height='168' rx='5' fill='none' stroke='#9b5de5' stroke-width='.75' opacity='.4'/>
<path d='M71 62 L75.5 74 L88 74 L78 82 L81 95 L71 87 L61 95 L64 82 L54 74 L66.5 74 Z' fill='#e7c96b' opacity='.9'/>
<line x1='71' y1='78' x2='71' y2='32' stroke='#b58af5' stroke-width='.7' opacity='.5'/>
<line x1='71' y1='78' x2='34' y2='42' stroke='#b58af5' stroke-width='.6' opacity='.35'/>
<line x1='71' y1='78' x2='108' y2='42' stroke='#b58af5' stroke-width='.6' opacity='.35'/>
<line x1='71' y1='78' x2='21' y2='78' stroke='#b58af5' stroke-width='.6' opacity='.3'/>
<line x1='71' y1='78' x2='121' y2='78' stroke='#b58af5' stroke-width='.6' opacity='.3'/>
<circle cx='22' cy='25' r='3' fill='#e7c96b' opacity='.4'/><circle cx='120' cy='25' r='3' fill='#e7c96b' opacity='.4'/>
<circle cx='22' cy='164' r='3' fill='#e7c96b' opacity='.4'/><circle cx='120' cy='164' r='3' fill='#e7c96b' opacity='.4'/>
<text x='71' y='128' text-anchor='middle' fill='#c9a0ff' font-size='8' font-family='sans-serif' font-weight='bold' letter-spacing='4'>HOPE</text>
<text x='71' y='170' text-anchor='middle' fill='#e7c96b' font-size='6.5' font-family='sans-serif' letter-spacing='1' opacity='.7'>WALKING FREE CCG</text>
</svg>"""
        "Courage":
            return """<svg xmlns='http://www.w3.org/2000/svg' width='142' height='186'>
<defs>
<radialGradient id='a' cx='50%' cy='100%' r='120%'><stop stop-color='#3d0a08'/><stop offset='1' stop-color='#090202'/></radialGradient>
<radialGradient id='b' cx='50%' cy='60%' r='40%'><stop stop-color='#c42a12' stop-opacity='.45'/><stop offset='1' stop-color='#3d0a08' stop-opacity='0'/></radialGradient>
</defs>
<rect width='142' height='186' rx='9' fill='url(#a)'/><rect width='142' height='186' rx='9' fill='url(#b)'/>
<ellipse cx='71' cy='186' rx='60' ry='30' fill='#e63a14' opacity='.28'/>
<rect x='5' y='5' width='132' height='176' rx='7' fill='none' stroke='#ff8c42' stroke-width='1.5' opacity='.6'/>
<line x1='5' y1='28' x2='28' y2='5' stroke='#ff8c42' stroke-width='1' opacity='.4'/>
<line x1='5' y1='158' x2='28' y2='181' stroke='#ff8c42' stroke-width='1' opacity='.4'/>
<line x1='137' y1='28' x2='114' y2='5' stroke='#ff8c42' stroke-width='1' opacity='.4'/>
<line x1='137' y1='158' x2='114' y2='181' stroke='#ff8c42' stroke-width='1' opacity='.4'/>
<path d='M75 45 C88 62 72 70 84 83 C90 90 90 104 71 114 C54 102 56 87 64 78 C74 68 60 59 75 45 Z' fill='#ff7c3a' opacity='.88'/>
<path d='M71 80 C79 90 76 100 68 112 C60 99 62 87 71 80 Z' fill='#ffe066' opacity='.72'/>
<circle cx='40' cy='145' r='2' fill='#ff9e5a' opacity='.5'/><circle cx='54' cy='155' r='1.5' fill='#ff9e5a' opacity='.4'/>
<circle cx='100' cy='148' r='2' fill='#ff9e5a' opacity='.5'/><circle cx='88' cy='157' r='1.5' fill='#ff9e5a' opacity='.4'/>
<circle cx='70' cy='151' r='1.5' fill='#ffcc44' opacity='.35'/>
<text x='71' y='130' text-anchor='middle' fill='#ffb07a' font-size='7.5' font-family='sans-serif' font-weight='bold' letter-spacing='2'>COURAGE</text>
<text x='71' y='170' text-anchor='middle' fill='#ff8c42' font-size='6.5' font-family='sans-serif' letter-spacing='1' opacity='.7'>WALKING FREE CCG</text>
</svg>"""
        "Serenity":
            return """<svg xmlns='http://www.w3.org/2000/svg' width='142' height='186'>
<defs>
<radialGradient id='a' cx='50%' cy='50%' r='80%'><stop stop-color='#073040'/><stop offset='1' stop-color='#030d14'/></radialGradient>
<radialGradient id='b' cx='50%' cy='55%' r='45%'><stop stop-color='#1ab5cc' stop-opacity='.35'/><stop offset='1' stop-color='#073040' stop-opacity='0'/></radialGradient>
</defs>
<rect width='142' height='186' rx='9' fill='url(#a)'/><rect width='142' height='186' rx='9' fill='url(#b)'/>
<rect x='5' y='5' width='132' height='176' rx='7' fill='none' stroke='#4dd9e8' stroke-width='1.5' opacity='.55'/>
<rect x='9' y='9' width='124' height='168' rx='5' fill='none' stroke='#1ab5cc' stroke-width='.75' opacity='.35'/>
<ellipse cx='71' cy='83' rx='34' ry='30' fill='none' stroke='#4dd9e8' stroke-width='1.2' opacity='.5'/>
<ellipse cx='71' cy='83' rx='22' ry='19' fill='none' stroke='#4dd9e8' stroke-width='.8' opacity='.4'/>
<path d='M28 83 Q52 64 71 83 Q90 102 114 83' fill='none' stroke='#78eef8' stroke-width='1.5' opacity='.7'/>
<path d='M20 96 Q46 77 71 96 Q96 115 122 96' fill='none' stroke='#4dd9e8' stroke-width='.9' opacity='.45'/>
<path d='M36 70 Q56 56 71 70 Q86 56 106 70' fill='none' stroke='#4dd9e8' stroke-width='.9' opacity='.45'/>
<circle cx='71' cy='83' r='6' fill='#78eef8' opacity='.55'/>
<circle cx='22' cy='24' r='3' fill='#4dd9e8' opacity='.35'/><circle cx='120' cy='24' r='3' fill='#4dd9e8' opacity='.35'/>
<circle cx='22' cy='164' r='3' fill='#4dd9e8' opacity='.35'/><circle cx='120' cy='164' r='3' fill='#4dd9e8' opacity='.35'/>
<text x='71' y='128' text-anchor='middle' fill='#78eef8' font-size='7.5' font-family='sans-serif' font-weight='bold' letter-spacing='2'>SERENITY</text>
<text x='71' y='170' text-anchor='middle' fill='#4dd9e8' font-size='6.5' font-family='sans-serif' letter-spacing='1' opacity='.7'>WALKING FREE CCG</text>
</svg>"""
        "Purpose":
            return """<svg xmlns='http://www.w3.org/2000/svg' width='142' height='186'>
<defs>
<radialGradient id='a' cx='50%' cy='50%' r='80%'><stop stop-color='#2e1c04'/><stop offset='1' stop-color='#080500'/></radialGradient>
<radialGradient id='b' cx='50%' cy='55%' r='45%'><stop stop-color='#c47a12' stop-opacity='.35'/><stop offset='1' stop-color='#2e1c04' stop-opacity='0'/></radialGradient>
</defs>
<rect width='142' height='186' rx='9' fill='url(#a)'/><rect width='142' height='186' rx='9' fill='url(#b)'/>
<rect x='5' y='5' width='132' height='176' rx='7' fill='none' stroke='#f0c44a' stroke-width='1.5' opacity='.6'/>
<rect x='10' y='10' width='122' height='166' rx='4' fill='none' stroke='#c47a12' stroke-width='.75' opacity='.35'/>
<polygon points='71,52 85,68 85,84 71,100 57,84 57,68' fill='none' stroke='#f0c44a' stroke-width='1.4' opacity='.75'/>
<polygon points='71,44 91,66 91,86 71,108 51,86 51,66' fill='none' stroke='#c47a12' stroke-width='.75' opacity='.4'/>
<circle cx='71' cy='78' r='10' fill='#f0c44a' opacity='.6'/>
<line x1='71' y1='44' x2='71' y2='52' stroke='#f0c44a' stroke-width='1.2' opacity='.6'/>
<line x1='71' y1='104' x2='71' y2='112' stroke='#f0c44a' stroke-width='1.2' opacity='.6'/>
<line x1='44' y1='66' x2='51' y2='68' stroke='#f0c44a' stroke-width='1.2' opacity='.6'/>
<line x1='98' y1='66' x2='91' y2='68' stroke='#f0c44a' stroke-width='1.2' opacity='.6'/>
<line x1='44' y1='90' x2='51' y2='84' stroke='#f0c44a' stroke-width='1.2' opacity='.6'/>
<line x1='98' y1='90' x2='91' y2='84' stroke='#f0c44a' stroke-width='1.2' opacity='.6'/>
<rect x='15' y='15' width='8' height='8' fill='#f0c44a' opacity='.35'/><rect x='119' y='15' width='8' height='8' fill='#f0c44a' opacity='.35'/>
<rect x='15' y='163' width='8' height='8' fill='#f0c44a' opacity='.35'/><rect x='119' y='163' width='8' height='8' fill='#f0c44a' opacity='.35'/>
<text x='71' y='128' text-anchor='middle' fill='#f0c44a' font-size='7.5' font-family='sans-serif' font-weight='bold' letter-spacing='2'>PURPOSE</text>
<text x='71' y='170' text-anchor='middle' fill='#d4960e' font-size='6.5' font-family='sans-serif' letter-spacing='1' opacity='.7'>WALKING FREE CCG</text>
</svg>"""
        # Aliases: default sleeve IDs map to their class design.
        "hope_dawn":       return _class_card_back_svg("Hope")
        "courage_flame":   return _class_card_back_svg("Courage")
        "serenity_wave":   return _class_card_back_svg("Serenity")
        "purpose_compass": return _class_card_back_svg("Purpose")
        # ── Rare sleeves ──────────────────────────────────────────────────────
        "hope_midnight":
            return """<svg xmlns='http://www.w3.org/2000/svg' width='142' height='186'>
<defs>
<radialGradient id='a' cx='35%' cy='35%' r='100%'><stop stop-color='#070e24'/><stop offset='1' stop-color='#020409'/></radialGradient>
<radialGradient id='b' cx='35%' cy='35%' r='50%'><stop stop-color='#2a4fab' stop-opacity='.4'/><stop offset='1' stop-color='#070e24' stop-opacity='0'/></radialGradient>
</defs>
<rect width='142' height='186' rx='9' fill='url(#a)'/><rect width='142' height='186' rx='9' fill='url(#b)'/>
<rect x='5' y='5' width='132' height='176' rx='7' fill='none' stroke='#8ab4f8' stroke-width='1.5' opacity='.55'/>
<rect x='9' y='9' width='124' height='168' rx='5' fill='none' stroke='#3a5fbd' stroke-width='.75' opacity='.35'/>
<circle cx='71' cy='78' r='26' fill='#7aaeff' opacity='.5'/><circle cx='80' cy='70' r='24' fill='#070e24'/>
<circle cx='71' cy='78' r='26' fill='none' stroke='#8ab4f8' stroke-width='1' opacity='.7'/>
<circle cx='38' cy='42' r='1.5' fill='#c8deff' opacity='.6'/><circle cx='110' cy='48' r='2' fill='#c8deff' opacity='.5'/>
<circle cx='25' cy='92' r='1' fill='#c8deff' opacity='.4'/><circle cx='118' cy='95' r='1.5' fill='#c8deff' opacity='.55'/>
<circle cx='55' cy='130' r='1' fill='#c8deff' opacity='.4'/><circle cx='95' cy='125' r='1.5' fill='#c8deff' opacity='.5'/>
<circle cx='30' cy='115' r='1' fill='#c8deff' opacity='.35'/><circle cx='112' cy='115' r='1' fill='#c8deff' opacity='.35'/>
<circle cx='20' cy='58' r='1.2' fill='#c8deff' opacity='.4'/><circle cx='122' cy='62' r='1' fill='#c8deff' opacity='.4'/>
<circle cx='22' cy='25' r='3' fill='#8ab4f8' opacity='.3'/><circle cx='120' cy='25' r='3' fill='#8ab4f8' opacity='.3'/>
<circle cx='22' cy='164' r='3' fill='#8ab4f8' opacity='.3'/><circle cx='120' cy='164' r='3' fill='#8ab4f8' opacity='.3'/>
<text x='71' y='128' text-anchor='middle' fill='#8ab4f8' font-size='7' font-family='sans-serif' font-weight='bold' letter-spacing='2'>MIDNIGHT STAR</text>
<text x='71' y='170' text-anchor='middle' fill='#5878cc' font-size='6.5' font-family='sans-serif' letter-spacing='1' opacity='.7'>WALKING FREE CCG</text>
</svg>"""
        "courage_storm":
            return """<svg xmlns='http://www.w3.org/2000/svg' width='142' height='186'>
<defs>
<radialGradient id='a' cx='50%' cy='50%' r='80%'><stop stop-color='#0e1520'/><stop offset='1' stop-color='#040608'/></radialGradient>
<radialGradient id='b' cx='50%' cy='40%' r='45%'><stop stop-color='#1e6ed4' stop-opacity='.4'/><stop offset='1' stop-color='#0e1520' stop-opacity='0'/></radialGradient>
</defs>
<rect width='142' height='186' rx='9' fill='url(#a)'/><rect width='142' height='186' rx='9' fill='url(#b)'/>
<rect x='5' y='5' width='132' height='176' rx='7' fill='none' stroke='#60b0ff' stroke-width='1.5' opacity='.6'/>
<path d='M78 28 L52 84 L71 84 L64 148 L90 80 L71 80 L82 28 Z' fill='#60b0ff' opacity='.8'/>
<path d='M78 28 L52 84 L71 84 L64 148 L90 80 L71 80 L82 28 Z' fill='none' stroke='#c0e4ff' stroke-width='1' opacity='.5'/>
<line x1='30' y1='64' x2='48' y2='72' stroke='#60b0ff' stroke-width='1' opacity='.5'/>
<line x1='18' y1='80' x2='40' y2='82' stroke='#60b0ff' stroke-width='1' opacity='.4'/>
<line x1='112' y1='64' x2='94' y2='72' stroke='#60b0ff' stroke-width='1' opacity='.5'/>
<line x1='124' y1='80' x2='102' y2='82' stroke='#60b0ff' stroke-width='1' opacity='.4'/>
<circle cx='22' cy='25' r='3' fill='#60b0ff' opacity='.35'/><circle cx='120' cy='25' r='3' fill='#60b0ff' opacity='.35'/>
<circle cx='22' cy='164' r='3' fill='#60b0ff' opacity='.35'/><circle cx='120' cy='164' r='3' fill='#60b0ff' opacity='.35'/>
<text x='71' y='128' text-anchor='middle' fill='#80c8ff' font-size='7.5' font-family='sans-serif' font-weight='bold' letter-spacing='3'>STORM</text>
<text x='71' y='170' text-anchor='middle' fill='#3880cc' font-size='6.5' font-family='sans-serif' letter-spacing='1' opacity='.7'>WALKING FREE CCG</text>
</svg>"""
        "serenity_jade":
            return """<svg xmlns='http://www.w3.org/2000/svg' width='142' height='186'>
<defs>
<radialGradient id='a' cx='50%' cy='50%' r='80%'><stop stop-color='#04180a'/><stop offset='1' stop-color='#020905'/></radialGradient>
<radialGradient id='b' cx='50%' cy='50%' r='45%'><stop stop-color='#2a9c58' stop-opacity='.35'/><stop offset='1' stop-color='#04180a' stop-opacity='0'/></radialGradient>
</defs>
<rect width='142' height='186' rx='9' fill='url(#a)'/><rect width='142' height='186' rx='9' fill='url(#b)'/>
<rect x='5' y='5' width='132' height='176' rx='7' fill='none' stroke='#5ad490' stroke-width='1.5' opacity='.55'/>
<rect x='9' y='9' width='124' height='168' rx='5' fill='none' stroke='#2a9c58' stroke-width='.75' opacity='.35'/>
<path d='M71 100 C60 85 55 70 71 58 C87 70 82 85 71 100 Z' fill='#5ad490' opacity='.6'/>
<path d='M71 100 C48 95 38 82 44 66 C60 68 65 82 71 100 Z' fill='#5ad490' opacity='.5'/>
<path d='M71 100 C94 95 104 82 98 66 C82 68 77 82 71 100 Z' fill='#5ad490' opacity='.5'/>
<path d='M71 100 C42 105 34 92 38 76 C52 76 60 90 71 100 Z' fill='#5ad490' opacity='.4'/>
<path d='M71 100 C100 105 108 92 104 76 C90 76 82 90 71 100 Z' fill='#5ad490' opacity='.4'/>
<circle cx='71' cy='96' r='6' fill='#8af0b8' opacity='.65'/>
<line x1='71' y1='100' x2='71' y2='58' stroke='#2a9c58' stroke-width='.6' opacity='.3'/>
<circle cx='22' cy='24' r='3' fill='#5ad490' opacity='.3'/><circle cx='120' cy='24' r='3' fill='#5ad490' opacity='.3'/>
<circle cx='22' cy='164' r='3' fill='#5ad490' opacity='.3'/><circle cx='120' cy='164' r='3' fill='#5ad490' opacity='.3'/>
<text x='71' y='130' text-anchor='middle' fill='#5ad490' font-size='7' font-family='sans-serif' font-weight='bold' letter-spacing='2'>JADE TRANQUIL</text>
<text x='71' y='170' text-anchor='middle' fill='#2a9c58' font-size='6.5' font-family='sans-serif' letter-spacing='1' opacity='.7'>WALKING FREE CCG</text>
</svg>"""
        "purpose_sovereign":
            return """<svg xmlns='http://www.w3.org/2000/svg' width='142' height='186'>
<defs>
<radialGradient id='a' cx='50%' cy='50%' r='80%'><stop stop-color='#160e00'/><stop offset='1' stop-color='#060400'/></radialGradient>
<radialGradient id='b' cx='50%' cy='45%' r='50%'><stop stop-color='#c47a12' stop-opacity='.3'/><stop offset='1' stop-color='#160e00' stop-opacity='0'/></radialGradient>
</defs>
<rect width='142' height='186' rx='9' fill='url(#a)'/><rect width='142' height='186' rx='9' fill='url(#b)'/>
<rect x='5' y='5' width='132' height='176' rx='7' fill='none' stroke='#f0c44a' stroke-width='1.5' opacity='.65'/>
<rect x='10' y='10' width='122' height='166' rx='4' fill='none' stroke='#8a5e10' stroke-width='.75' opacity='.35'/>
<path d='M40 96 L40 72 L55 84 L71 62 L87 84 L102 72 L102 96 Z' fill='#f0c44a' opacity='.8'/>
<path d='M36 96 L106 96 L106 102 L36 102 Z' fill='#f0c44a' opacity='.75'/>
<circle cx='71' cy='66' r='4' fill='#fff' opacity='.7'/>
<circle cx='44' cy='76' r='3' fill='#ff8888' opacity='.7'/>
<circle cx='98' cy='76' r='3' fill='#8888ff' opacity='.7'/>
<line x1='36' y1='108' x2='106' y2='108' stroke='#f0c44a' stroke-width='.8' opacity='.5'/>
<rect x='15' y='15' width='8' height='8' fill='#f0c44a' opacity='.4'/><rect x='119' y='15' width='8' height='8' fill='#f0c44a' opacity='.4'/>
<rect x='15' y='163' width='8' height='8' fill='#f0c44a' opacity='.4'/><rect x='119' y='163' width='8' height='8' fill='#f0c44a' opacity='.4'/>
<text x='71' y='128' text-anchor='middle' fill='#f0c44a' font-size='7' font-family='sans-serif' font-weight='bold' letter-spacing='2'>SOVEREIGN SEAL</text>
<text x='71' y='170' text-anchor='middle' fill='#a87a20' font-size='6.5' font-family='sans-serif' letter-spacing='1' opacity='.7'>WALKING FREE CCG</text>
</svg>"""
        # ── Legendary sleeves ─────────────────────────────────────────────────
        "dawn_unity":
            return """<svg xmlns='http://www.w3.org/2000/svg' width='142' height='186'>
<defs>
<radialGradient id='a' cx='50%' cy='50%' r='80%'><stop stop-color='#0e0a1a'/><stop offset='1' stop-color='#020104'/></radialGradient>
<radialGradient id='b' cx='50%' cy='50%' r='45%'><stop stop-color='#fff' stop-opacity='.08'/><stop offset='1' stop-color='#0e0a1a' stop-opacity='0'/></radialGradient>
</defs>
<rect width='142' height='186' rx='9' fill='url(#a)'/><rect width='142' height='186' rx='9' fill='url(#b)'/>
<rect x='5' y='5' width='132' height='176' rx='7' fill='none' stroke='#fff' stroke-width='1.2' opacity='.28'/>
<path d='M71 78 L71 46 A32 32 0 0 1 103 78 Z' fill='#b58af5' opacity='.75'/>
<path d='M71 78 L103 78 A32 32 0 0 1 71 110 Z' fill='#ff7c3a' opacity='.75'/>
<path d='M71 78 L71 110 A32 32 0 0 1 39 78 Z' fill='#f0c44a' opacity='.75'/>
<path d='M71 78 L39 78 A32 32 0 0 1 71 46 Z' fill='#4dd9e8' opacity='.75'/>
<circle cx='71' cy='78' r='12' fill='#0e0a1a'/><circle cx='71' cy='78' r='10' fill='none' stroke='#fff' stroke-width='1.2' opacity='.6'/>
<circle cx='71' cy='78' r='4' fill='#fff' opacity='.7'/>
<circle cx='71' cy='78' r='32' fill='none' stroke='#fff' stroke-width='.8' opacity='.28'/>
<circle cx='22' cy='25' r='3' fill='#b58af5' opacity='.5'/><circle cx='120' cy='25' r='3' fill='#ff7c3a' opacity='.5'/>
<circle cx='22' cy='164' r='3' fill='#4dd9e8' opacity='.5'/><circle cx='120' cy='164' r='3' fill='#f0c44a' opacity='.5'/>
<text x='71' y='128' text-anchor='middle' fill='#fff' font-size='7' font-family='sans-serif' font-weight='bold' letter-spacing='2'>UNITY OF DAWN</text>
<text x='71' y='170' text-anchor='middle' fill='#aaa' font-size='6.5' font-family='sans-serif' letter-spacing='1' opacity='.7'>WALKING FREE CCG</text>
</svg>"""
        "sponsor":
            return """<svg xmlns='http://www.w3.org/2000/svg' width='142' height='186'>
<defs>
<radialGradient id='a' cx='50%' cy='50%' r='80%'><stop stop-color='#0a0a0a'/><stop offset='1' stop-color='#000'/></radialGradient>
<radialGradient id='b' cx='50%' cy='50%' r='45%'><stop stop-color='#888' stop-opacity='.15'/><stop offset='1' stop-color='#0a0a0a' stop-opacity='0'/></radialGradient>
</defs>
<rect width='142' height='186' rx='9' fill='url(#a)'/><rect width='142' height='186' rx='9' fill='url(#b)'/>
<rect x='5' y='5' width='132' height='176' rx='7' fill='none' stroke='#888' stroke-width='1.5' opacity='.5'/>
<rect x='9' y='9' width='124' height='168' rx='5' fill='none' stroke='#555' stroke-width='.75' opacity='.35'/>
<ellipse cx='71' cy='78' rx='28' ry='18' fill='none' stroke='#888' stroke-width='1.2' opacity='.6'/>
<ellipse cx='71' cy='78' rx='12' ry='12' fill='#333' stroke='#666' stroke-width='.8' opacity='.8'/>
<circle cx='71' cy='78' r='5' fill='#888' opacity='.6'/><circle cx='74' cy='75' r='2' fill='#ccc' opacity='.5'/>
<line x1='71' y1='56' x2='71' y2='44' stroke='#888' stroke-width='.8' opacity='.4'/>
<line x1='71' y1='100' x2='71' y2='112' stroke='#888' stroke-width='.8' opacity='.4'/>
<line x1='39' y1='78' x2='27' y2='78' stroke='#888' stroke-width='.8' opacity='.4'/>
<line x1='103' y1='78' x2='115' y2='78' stroke='#888' stroke-width='.8' opacity='.4'/>
<rect x='15' y='15' width='6' height='6' fill='#666' opacity='.4'/><rect x='121' y='15' width='6' height='6' fill='#666' opacity='.4'/>
<rect x='15' y='165' width='6' height='6' fill='#666' opacity='.4'/><rect x='121' y='165' width='6' height='6' fill='#666' opacity='.4'/>
<text x='71' y='128' text-anchor='middle' fill='#888' font-size='7' font-family='sans-serif' font-weight='bold' letter-spacing='2'>THE SPONSOR</text>
<text x='71' y='170' text-anchor='middle' fill='#555' font-size='6.5' font-family='sans-serif' letter-spacing='1' opacity='.7'>WALKING FREE CCG</text>
</svg>"""
        _:  # Universal / no class — original teal star design
            return """<svg xmlns='http://www.w3.org/2000/svg' width='142' height='186'>
<defs><radialGradient id='g' cx='50%' cy='50%' r='80%'><stop stop-color='#2e8496'/><stop offset='1' stop-color='#081b2b'/></radialGradient></defs>
<rect width='142' height='186' rx='9' fill='url(#g)'/>
<rect x='5' y='5' width='132' height='176' rx='7' fill='none' stroke='#e7c96b' stroke-width='1.5' opacity='.6'/>
<circle cx='71' cy='80' r='38' fill='none' stroke='#e7c96b' stroke-width='2' opacity='.5'/>
<path d='M71 48 L77 66 L96 66 L81 78 L86 96 L71 84 L56 96 L61 78 L46 66 L65 66 Z' fill='#e7c96b' opacity='.88'/>
<text x='71' y='136' text-anchor='middle' fill='#a8dce6' font-size='7.5' font-family='sans-serif' font-weight='bold' letter-spacing='2'>UNIVERSAL</text>
<text x='71' y='170' text-anchor='middle' fill='#e7c96b' font-size='6.5' font-family='sans-serif' letter-spacing='1' opacity='.7'>WALKING FREE CCG</text>
</svg>"""

func _art_svg() -> String:
    var seed_value: int = absi(str(data.get("name", "card")).hash())
    var hue1: float = float(seed_value % 360)
    var hue2: float = fmod(hue1 + 75.0, 360.0)
    var c1: String = Color.from_hsv(hue1 / 360.0, 0.72, 0.66).to_html(false)
    var c2: String = Color.from_hsv(hue2 / 360.0, 0.68, 0.32).to_html(false)
    var icon: String = str(data.get("icon", "star"))
    var shape: String = "<path d='M120 26 L137 61 L176 67 L148 95 L155 134 L120 115 L85 134 L92 95 L64 67 L103 61 Z' fill='#f5df91'/>"
    if icon == "shield": shape = "<path d='M120 22 L171 41 V78 C171 109 150 132 120 142 C90 132 69 109 69 78 V41 Z' fill='#bde9ff' stroke='#ffffff' stroke-width='5'/>"
    elif icon == "flame": shape = "<path d='M124 18 C155 51 93 65 137 91 C152 100 154 124 120 142 C74 126 82 87 102 70 C118 56 105 39 124 18 Z' fill='#ffd56a'/><path d='M120 76 C137 94 127 107 115 126 C97 109 102 91 120 76 Z' fill='#ff6b3d'/>"
    elif icon == "hands": shape = "<path d='M46 91 C70 68 88 67 111 88 L129 104 L112 122 L89 103 C78 95 68 102 58 112 Z' fill='#f5d1b5'/><path d='M194 91 C170 68 152 67 129 88 L111 104 L128 122 L151 103 C162 95 172 102 182 112 Z' fill='#e8b992'/><circle cx='120' cy='58' r='29' fill='#ffe3a8'/><path d='M120 37 C108 20 82 37 88 58 C94 76 120 89 120 89 C120 89 146 76 152 58 C158 37 132 20 120 37 Z' fill='#ff7e88'/>"
    elif icon == "road": shape = "<path d='M93 150 L111 66 L129 66 L148 150 Z' fill='#dad6c7'/><path d='M119 138 L121 116 M119 101 L121 82' stroke='#fff7b0' stroke-width='5'/><circle cx='120' cy='48' r='24' fill='#ffe489'/><path d='M30 150 L86 66 L105 150 Z M210 150 L154 66 L135 150 Z' fill='#163b38'/></svg>"
    return """<svg xmlns='http://www.w3.org/2000/svg' width='240' height='150'>
    <defs><linearGradient id='g' x2='1' y2='1'><stop stop-color='#%s'/><stop offset='1' stop-color='#%s'/></linearGradient></defs>
    <rect width='240' height='150' rx='12' fill='url(#g)'/><circle cx='34' cy='28' r='48' fill='#ffffff' opacity='.08'/><circle cx='206' cy='125' r='62' fill='#000000' opacity='.13'/>%s
    </svg>""" % [c1, c2, shape]
