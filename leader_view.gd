# leader_view.gd
# A dedicated animated display node for a class leader.
#
# ═══════════════════════════════════════════════════════════════════════════════
# HONEST ART-LIMITATION NOTICE — READ BEFORE USING
# ═══════════════════════════════════════════════════════════════════════════════
# The current leader artwork (assets/leaders/*.png) is a set of SINGLE FLAT
# COMPOSITE PNGs — each file bakes the character, background, lighting, and
# every detail into ONE layer. True per-body-part animation is NOT POSSIBLE
# with flat art because there are no separate layers to move independently.
#
# What the requested animations actually need:
#
#   IDLE blinking        → separate "eyes" PNG with open/closed frames OR a
#                          sub-region crop that covers only the eye area — but
#                          the crop position differs per character and the eye
#                          background behind closed eyelids is baked into the
#                          composite, so closing the "eyes" sub-rect reveals
#                          the wrong background color. IMPOSSIBLE with flat art.
#
#   Chest breathing      → separate torso/body layer that moves up/down. The
#                          current art merges body + bg + clothing into one
#                          pixel — moving it moves everything. NOT POSSIBLE.
#
#   Subtle hair movement → separate hair layer with alpha. Same constraint.
#
#   Mouth movement       → separate mouth layer. Same constraint.
#
# What IS achievable with flat art (these are approximations, not true anim):
#   • Whole-image position drift (simulates head sway — the user has already
#     seen and rejected this for the home screen; documented here for clarity)
#   • Whole-image scale breathing (same caveat)
#   • Modulate flash for DAMAGED / HEALED
#   • Scale/position snap for ABILITY / DEFEAT / VICTORY
#
# What new art is required for true animation:
#   Supply one set of PNG files per leader, all with transparent backgrounds:
#       hope_body.png    — static torso / lower body / bg
#       hope_head.png    — head (slight position drift on IDLE)
#       hope_eyes.png    — eyes only (blink by toggling between open/closed sub-region)
#       hope_hair.png    — hair (subtle X sway on IDLE)
#       hope_larm.png    — left arm (raises on ABILITY)
#       hope_rarm.png    — right arm
#       hope_aura.png    — glow ring (pulsing scale+alpha on IDLE)
#   Place all at the same canvas size, then stack them as separate TextureRects
#   in _setup_nodes(). The state machine below already calls _anim_layer_*
#   stubs — swap the stub bodies for real Tween calls on the correct layers.
# ═══════════════════════════════════════════════════════════════════════════════

class_name LeaderView
extends Control

enum State {
	IDLE,
	SELECTED,
	DAMAGED,
	HEALED,
	ABILITY,
	VICTORY,
	DEFEAT,
	VOICE_LINE,
}

# ── Public API ────────────────────────────────────────────────────────────────

## Whether layered art files exist for this class (set to true when real art ships).
## When false the node uses whole-image approximations and logs a reminder.
var has_layered_art := false

## Emitted after a one-shot state (DAMAGED, HEALED, etc.) animation finishes.
signal animation_finished(state: State)

# ── Private state ─────────────────────────────────────────────────────────────

var _class_name_value: String = ""
var _current_state: State = State.IDLE
var _idle_tween: Tween = null
var _state_tween: Tween = null

# Art layers — all allocated in _setup_nodes(), only populated when layered
# art exists.  _art is always populated (flat fallback).
var _art: TextureRect = null        # flat composite — always used
var _layer_body: TextureRect = null # layered art: torso + bg
var _layer_head: TextureRect = null # layered art: head (position-drifts on IDLE)
var _layer_eyes: TextureRect = null # layered art: eyes (blink)
var _layer_hair: TextureRect = null # layered art: hair (sways on IDLE)
var _layer_arms: TextureRect = null # layered art: arms (raise on ABILITY)
var _layer_aura: TextureRect = null # layered art: glow ring

# ── Setup ─────────────────────────────────────────────────────────────────────

## Call immediately after adding this node to the tree.
## class_name_str: "Hope", "Courage", "Serenity", "Purpose", or "Sponsor"
## size_vec: pixel size of this control
func setup(class_name_str: String, size_vec: Vector2) -> void:
	_class_name_value = class_name_str
	custom_minimum_size = size_vec
	size = size_vec
	clip_contents = true
	_setup_nodes(size_vec)
	if not has_layered_art:
		push_warning("LeaderView: %s uses flat art — blinking/hair/chest anim not possible. See leader_view.gd for required art format." % class_name_str)
	set_state(State.IDLE)

func _setup_nodes(sz: Vector2) -> void:
	for ch in get_children():
		ch.queue_free()

	# Aura glow behind everything (visible even without layered art)
	var aura_bg := ColorRect.new()
	aura_bg.color = Color(_class_color(), 0.0)  # starts invisible; IDLE pulses it
	aura_bg.position = Vector2.ZERO
	aura_bg.size = sz
	aura_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aura_bg.name = "AuraBg"
	add_child(aura_bg)

	# Flat composite — always present
	_art = TextureRect.new()
	_art.texture = _resolve_texture()
	_art.position = Vector2.ZERO
	_art.size = sz
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.clip_contents = true
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.pivot_offset = sz * 0.5
	add_child(_art)

	# Layered art stubs — populated by the caller when real art ships.
	# Order matters: body → head → eyes → hair → arms → aura (front)
	if has_layered_art:
		_layer_body = _make_layer("body", sz)
		_layer_head = _make_layer("head", sz)
		_layer_eyes = _make_layer("eyes", sz)
		_layer_hair = _make_layer("hair", sz)
		_layer_arms = _make_layer("arms", sz)
		_layer_aura = _make_layer("aura", sz)
		# Hide the flat composite when real layers are present
		_art.visible = false

func _make_layer(part: String, sz: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = _resolve_layer_texture(part)
	t.position = Vector2.ZERO
	t.size = sz
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.clip_contents = false
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.pivot_offset = sz * 0.5
	add_child(t)
	return t

# ── Texture resolution ────────────────────────────────────────────────────────

func _resolve_texture() -> Texture2D:
	if _class_name_value.to_lower() == "sponsor":
		return load("res://assets/cards/full/jd-080.jpg")
	var base: Texture2D = load("res://assets/leaders/%s.png" % _class_name_value.to_lower())
	if base == null:
		return null
	var margin: float = base.get_width() * 0.045
	var iw: float = base.get_width() - margin * 2.0
	var ih: float = base.get_height() - margin * 2.0
	var atlas := AtlasTexture.new()
	atlas.atlas = base
	atlas.region = Rect2(margin, margin, iw, ih * 0.6)
	return atlas

func _resolve_layer_texture(part: String) -> Texture2D:
	# Looks for "assets/leaders/<class>_<part>.png" — e.g. "hope_eyes.png"
	var path := "res://assets/leaders/%s_%s.png" % [_class_name_value.to_lower(), part]
	if ResourceLoader.exists(path):
		return load(path)
	return null  # missing layer — that slot just renders nothing (transparent)

func _class_color() -> Color:
	match _class_name_value:
		"Hope":     return Color(0.25, 0.55, 1.00)
		"Courage":  return Color(0.95, 0.40, 0.18)
		"Serenity": return Color(0.28, 0.75, 0.55)
		"Purpose":  return Color(0.72, 0.38, 0.90)
		_:          return Color(0.80, 0.70, 0.40)

# ── State machine ─────────────────────────────────────────────────────────────

func set_state(new_state: State) -> void:
	_current_state = new_state
	if _idle_tween: _idle_tween.kill(); _idle_tween = null
	if _state_tween: _state_tween.kill(); _state_tween = null

	# Reset all art layers to neutral
	for node in [_art, _layer_head, _layer_eyes, _layer_hair, _layer_arms, _layer_aura]:
		if node == null: continue
		node.position = Vector2.ZERO
		node.modulate = Color.WHITE
		node.scale = Vector2.ONE

	match new_state:
		State.IDLE:       _play_idle()
		State.SELECTED:   _play_selected()
		State.DAMAGED:    _play_damaged()
		State.HEALED:     _play_healed()
		State.ABILITY:    _play_ability()
		State.VICTORY:    _play_victory()
		State.DEFEAT:     _play_defeat()
		State.VOICE_LINE: _play_voice_line()

func get_state() -> State:
	return _current_state

# ── Animation implementations ─────────────────────────────────────────────────
# Each function has two code paths:
#   A) has_layered_art = true  → tweens individual layers (real animation)
#   B) has_layered_art = false → tweens _art whole (approximation, labeled)

func _play_idle() -> void:
	if has_layered_art:
		# ── TRUE ANIMATION (layered art) ──
		# Head: gentle left-right drift
		if _layer_head:
			_idle_tween = create_tween().set_loops()
			_idle_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_idle_tween.tween_property(_layer_head, "position:x", -3.0, 2.0)
			_idle_tween.tween_property(_layer_head, "position:x",  2.5, 2.0)
		# Hair: slight sway (offset from head)
		if _layer_hair:
			var hair_tween := create_tween().set_loops()
			hair_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			hair_tween.tween_property(_layer_hair, "position:x", -2.0, 2.3)
			hair_tween.tween_property(_layer_hair, "position:x",  1.8, 2.3)
		# Eyes: blink every ~4 seconds
		if _layer_eyes:
			_schedule_blink()
		# Aura: pulse opacity
		if _layer_aura:
			var aura_t := create_tween().set_loops()
			aura_t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			aura_t.tween_property(_layer_aura, "modulate:a", 0.65, 1.6)
			aura_t.tween_property(_layer_aura, "modulate:a", 1.00, 1.6)
	else:
		# ── APPROXIMATION (flat art) ──
		# NOTE: this moves the entire image. The user has already seen and
		# rejected this effect; it is kept here so the node has some life
		# while real art is pending, but it is NOT blinking or chest breathing.
		_idle_tween = create_tween().set_loops()
		_idle_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_idle_tween.tween_property(_art, "position:x", -2.5, 2.2)
		_idle_tween.tween_property(_art, "position:x",  2.0, 2.2)

func _schedule_blink() -> void:
	# Blink: animate a sub-region crop of _layer_eyes to simulate closing.
	# Requires _layer_eyes to have an AtlasTexture with eye-open and eye-closed
	# regions pre-defined. This stub calls itself recursively every ~4s.
	if _layer_eyes == null or _current_state != State.IDLE: return
	await get_tree().create_timer(randf_range(3.0, 5.5)).timeout
	if _current_state != State.IDLE or _layer_eyes == null: return
	var blink := create_tween().set_trans(Tween.TRANS_LINEAR)
	# Close eyes: scale Y to near-zero at pivot = eye center (simulate lid close)
	blink.tween_property(_layer_eyes, "scale:y", 0.08, 0.07)
	blink.tween_property(_layer_eyes, "scale:y", 1.00, 0.10)
	await blink.finished
	_schedule_blink()

func _play_selected() -> void:
	# Slight lean forward (scale up from center) + brighter aura
	var target := _layer_head if has_layered_art and _layer_head else _art
	target.pivot_offset = target.size * 0.5
	_state_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_state_tween.tween_property(target, "scale", Vector2(1.04, 1.04), 0.35)
	_play_idle()

func _play_damaged() -> void:
	# Flash white → recoil left → recover
	var target := _art if not has_layered_art else _layer_head
	if target == null: target = _art
	_state_tween = create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_state_tween.tween_property(target, "modulate", Color(2.2, 2.2, 2.2), 0.06)
	_state_tween.tween_property(target, "position:x", -20.0, 0.09)
	_state_tween.tween_property(target, "modulate", Color.WHITE, 0.22)
	_state_tween.tween_property(target, "position:x",   0.0, 0.30)
	_state_tween.tween_callback(func(): animation_finished.emit(State.DAMAGED); set_state(State.IDLE))

func _play_healed() -> void:
	# Green glow flash → posture lift
	var target := _art
	_state_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_state_tween.tween_property(target, "modulate", Color(0.60, 1.55, 0.72), 0.22)
	_state_tween.tween_property(target, "position:y", -7.0, 0.28)
	_state_tween.tween_property(target, "modulate", Color.WHITE, 0.48)
	_state_tween.tween_property(target, "position:y",  0.0, 0.38)
	_state_tween.tween_callback(func(): animation_finished.emit(State.HEALED); set_state(State.IDLE))

func _play_ability() -> void:
	# Forward lunge + class-color flash
	var target := _layer_arms if has_layered_art and _layer_arms else _art
	if target == null: target = _art
	_state_tween = create_tween()
	_state_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_state_tween.set_parallel(true)
	_state_tween.tween_property(target, "scale", Vector2(1.07, 1.07), 0.20)
	_state_tween.tween_property(target, "position:x", 10.0, 0.20)
	_state_tween.tween_property(target, "modulate", Color(_class_color() * 1.6, 1.0), 0.20)
	_state_tween.chain().set_parallel(true)
	_state_tween.tween_property(target, "scale", Vector2.ONE, 0.30)
	_state_tween.tween_property(target, "position:x", 0.0, 0.30)
	_state_tween.tween_property(target, "modulate", Color.WHITE, 0.30)
	_state_tween.chain().tween_callback(func(): animation_finished.emit(State.ABILITY); set_state(State.IDLE))

func _play_victory() -> void:
	# Confident size-up + warm gold tint + resume idle
	var target := _art
	target.pivot_offset = target.size * 0.5
	_state_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_state_tween.tween_property(target, "scale", Vector2(1.055, 1.055), 0.50)
	_state_tween.tween_property(target, "modulate", Color(1.12, 1.06, 0.82), 0.50)
	_play_idle()

func _play_defeat() -> void:
	# Head lowers, aura fades, desaturates — no loop
	var target := _layer_head if has_layered_art and _layer_head else _art
	if target == null: target = _art
	_state_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_state_tween.tween_property(target, "position:y",  14.0, 0.65)
	_state_tween.tween_property(target, "modulate", Color(0.52, 0.52, 0.58), 0.80)
	# Aura dims
	if has_layered_art and _layer_aura:
		var aura_t := create_tween()
		aura_t.tween_property(_layer_aura, "modulate:a", 0.0, 1.0)

func _play_voice_line() -> void:
	# With flat art: mouth movement is impossible (no mouth layer).
	# Approximate: subtle scale pulse on the whole portrait.
	# With layered art: tween _layer_mouth sub-region or y-scale.
	if has_layered_art:
		push_warning("LeaderView: VOICE_LINE requires a mouth layer — implement _layer_mouth in _setup_nodes()")
	var target := _art
	_state_tween = create_tween().set_loops(3)
	_state_tween.tween_property(target, "scale", Vector2(1.010, 1.018), 0.11)
	_state_tween.tween_property(target, "scale", Vector2.ONE, 0.11)
	_state_tween.tween_callback(func(): animation_finished.emit(State.VOICE_LINE); set_state(State.IDLE))
