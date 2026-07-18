class_name CardView
extends Button

signal card_chosen(card_index: int)
signal inspect_requested(card_data: Dictionary)

static var _catalog_by_name: Dictionary = {}
static var _catalog_loaded: bool = false
static var _art_cache: Dictionary = {}
signal drag_action_requested(card_index: int, context: String, global_release_position: Vector2)

var card_index := -1
var data: Dictionary = {}
var compact := false
var hidden_card := false
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
var art_home := Vector2.ZERO
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

func setup(card_data: Dictionary, index: int, is_compact: bool = false, is_hidden: bool = false) -> void:
    data = _hydrate_card_data(card_data.duplicate(true))
    card_index = index
    compact = is_compact
    hidden_card = is_hidden
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
            _gesture_release(context, event.position)
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
    var badge_row := HBoxContainer.new()
    badge_row.position = Vector2(8, 88 if not compact else 67)
    badge_row.size = Vector2(custom_minimum_size.x - 16, 24)
    badge_row.alignment = BoxContainer.ALIGNMENT_CENTER
    badge_row.add_theme_constant_override("separation", 3)
    badge_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    badge_row.z_index = 90
    frame.add_child(badge_row)
    var max_badges := mini(2 if not compact else 4, keywords.size())
    for i in range(max_badges):
        var definition: Dictionary = keywords[i]
        var badge := Label.new()
        badge.text = str(definition.get("icon", "•")) if compact else str(definition.get("label", "ABILITY"))
        badge.tooltip_text = str(definition.get("label", "ABILITY"))
        badge.custom_minimum_size = Vector2(24, 22) if compact else Vector2(92, 24)
        badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        badge.add_theme_font_size_override("font_size", card_font(13 if not compact else 11))
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

    art_rect = TextureRect.new()
    art_rect.position = Vector2(8, 27 if not compact else 22)
    art_rect.size = Vector2(custom_minimum_size.x - 16, 82 if not compact else 64)
    art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    art_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    if hidden_card:
        art_rect.texture = _svg_texture(_card_back_svg())
    else:
        art_rect.texture = _art_texture()
    frame.add_child(art_rect)
    art_home = art_rect.position

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
    living_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    living_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    living_glow.add_theme_stylebox_override("panel", _living_glow_style())
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
    foil_glow.position = art_rect.position
    foil_glow.size = art_rect.size
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
    name_label.text = "WALKING FREE" if hidden_card else str(data.get("name", "Card"))
    name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name_label.add_theme_font_size_override("font_size", card_font(13 if not compact else 11))
    name_label.add_theme_color_override("font_color", Color(0.97, 0.95, 0.86))
    name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
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

func set_selected(value: bool) -> void:
    selected = value
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "scale", Vector2(1.08, 1.08) if value else Vector2.ONE, 0.15)
    modulate = Color(1.1, 1.1, 0.8) if value else Color.WHITE

func summon_animation() -> void:
    scale = Vector2(0.18, 0.18)
    modulate.a = 0.0
    var tween := create_tween().set_parallel(true)
    tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "scale", Vector2.ONE, 0.34)
    tween.tween_property(self, "modulate:a", 1.0, 0.2)

func damage_flash() -> void:
    var start := position
    var tween := create_tween()
    tween.tween_property(self, "modulate", Color(1.8, 0.35, 0.35), 0.06)
    tween.tween_property(self, "position", start + Vector2(8, 0), 0.04)
    tween.tween_property(self, "position", start - Vector2(8, 0), 0.04)
    tween.tween_property(self, "position", start, 0.04)
    tween.tween_property(self, "modulate", Color.WHITE, 0.12)

func death_animation() -> void:
    var tween := create_tween().set_parallel(true)
    tween.tween_property(self, "scale", Vector2(0.2, 0.2), 0.25)
    tween.tween_property(self, "rotation", 0.35, 0.25)
    tween.tween_property(self, "modulate:a", 0.0, 0.22)

func phoenix_death_animation() -> void:
    # Phoenix Rising: dissolves upward into golden light rather than crumpling.
    modulate = Color(1.0, 0.72, 0.30, 1.0)
    var tween := create_tween().set_parallel(true)
    tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "position:y", position.y - 40.0, 0.42)
    tween.tween_property(self, "modulate:a", 0.0, 0.42)
    tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.42)

func _hover_on() -> void:
    if hidden_card:
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
    if hidden_card or selected:
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
    var life_wave: float = (sin(shimmer_time * 1.8 + idle_phase) + 1.0) * 0.5
    if foil_glow != null and foil_glow.visible:
        var pulse: float = (sin(shimmer_time * 3.2) + 1.0) * 0.5
        foil_glow.color = Color(0.62 + pulse * 0.25, 0.86 + pulse * 0.10, 1.0, 0.08 + pulse * 0.12)
    if shiny_rainbow != null and shiny_rainbow.visible:
        # Rainbow foil: slow hue cycle across the full card surface
        shiny_rainbow.color = Color.from_hsv(fmod(shimmer_time * 0.18, 1.0), 0.60, 1.0, 0.20)
        # Sparkle dots: each flashes on its own timer at a random card position
        for _si in shiny_sparks.size():
            var _old_t: float = _spark_timers[_si]
            _spark_timers[_si] = fmod(_old_t + delta, 2.8)
            var _phase: float = _spark_timers[_si]
            var _sp: ColorRect = shiny_sparks[_si]
            if _old_t > _phase:  # timer just wrapped — pick a new random position
                _sp.position = Vector2(randf_range(2.0, custom_minimum_size.x - 8.0), randf_range(2.0, custom_minimum_size.y - 8.0))
            var _bright := 0.0
            if _phase < 0.30: _bright = _phase / 0.30
            elif _phase < 0.60: _bright = 1.0 - (_phase - 0.30) / 0.30
            _sp.color = Color.from_hsv(fmod(shimmer_time * 0.4 + float(_si) * 0.1, 1.0), 0.4, 1.0, _bright * 0.92)
    if living_glow != null:
        living_glow.modulate.a = 0.42 + life_wave * 0.35
    if art_rect != null and not hidden_card:
        var drift := Vector2(sin(shimmer_time * 0.72 + idle_phase) * 1.8, cos(shimmer_time * 0.58 + idle_phase) * 1.2)
        if hovering:
            var mouse_ratio := get_local_mouse_position() / Vector2(maxf(size.x, 1.0), maxf(size.y, 1.0)) - Vector2(0.5, 0.5)
            drift += mouse_ratio * 5.0
        art_rect.position = art_home + drift
    if shine_strip != null and shine_strip.visible:
        var cycle := fmod(shimmer_time + idle_phase, 3.8)
        shine_strip.position.x = lerpf(-55.0, custom_minimum_size.x + 30.0, cycle / 3.8)
        shine_strip.color = Color(0.92, 0.98, 1.0, 0.16 if cycle > 0.35 and cycle < 3.2 else 0.0)
    if bool(data.get("can_attack", false)) and not hidden_card and not hovering:
        var attack_pulse := 1.0 + sin(shimmer_time * 3.6 + idle_phase) * 0.012
        scale = Vector2(attack_pulse, attack_pulse)
    if hovering and not hidden_card:
        var local_mouse: Vector2 = get_local_mouse_position()
        var x_ratio: float = clampf((local_mouse.x / maxf(size.x, 1.0)) - 0.5, -0.5, 0.5)
        rotation = x_ratio * 0.10

func _living_glow_style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0, 0, 0, 0)
    var rarity := str(data.get("rarity", "Bronze"))
    var glow := Color(0.38, 0.65, 0.78, 0.26)
    if rarity == "Silver": glow = Color(0.78, 0.88, 1.0, 0.30)
    elif rarity == "Legendary": glow = Color(1.0, 0.66, 0.16, 0.40)
    elif rarity == "Platinum": glow = Color(0.62, 0.88, 1.0, 0.48)
    if bool(data.get("evolved", false)):
        glow = Color(0.34, 0.92, 1.0, 0.58)
    if bool(data.get("is_shiny", false)):
        glow = Color(0.88, 0.65, 1.0, 0.62)
    style.border_color = glow
    style.set_border_width_all(3)
    style.set_corner_radius_all(9)
    style.shadow_color = glow
    style.shadow_size = 7
    return style

func _frame_style() -> StyleBoxFlat:
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
    return """<svg xmlns='http://www.w3.org/2000/svg' width='240' height='150'>
    <defs><radialGradient id='g'><stop stop-color='#2e8496'/><stop offset='1' stop-color='#081b2b'/></radialGradient></defs>
    <rect width='240' height='150' rx='12' fill='url(#g)'/><circle cx='120' cy='75' r='49' fill='none' stroke='#e7c96b' stroke-width='5'/>
    <path d='M120 30 L139 62 L176 69 L149 96 L155 132 L120 114 L85 132 L91 96 L64 69 L101 62 Z' fill='#e7c96b' opacity='.86'/>
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
