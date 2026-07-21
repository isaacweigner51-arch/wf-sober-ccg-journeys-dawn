# leader_view.gd
# Animated leader portrait node.  Stacks transparent PNG layers for real animation
# when the layered art files are present; falls back to the flat composite otherwise.
#
# Layer stack (bottom → top):
#   aura_bg      — class-color pulse glow (ColorRect, always)
#   _layer_body  — torso / clothing (breathing scale)
#   _layer_head  — face + neck (lateral drift; texture-swapped for blink)
#   _layer_hair  — hair (sways wider than head, offset phase)
#   _layer_aura  — optional glow overlay
#   _art         — flat composite fallback (only when !has_layered_art)
#
# Layered art file convention  (1024×1024 PNG, transparent bg):
#   assets/leaders/<class>_body.png
#   assets/leaders/<class>_head.png
#   assets/leaders/<class>_head_blink.png
#   assets/leaders/<class>_hair.png
#   assets/leaders/<class>_aura.png   (optional)

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

## Emitted after a one-shot state animation finishes.
signal animation_finished(state: State)

# ── Focal-point offsets (match menu.gd LEADER_FOCAL_PX) ─────────────────────
# Each value is the X shift (px) to apply to the flat-art TextureRect so the
# character's face is centred in the portrait frame.  Negative = shift left
# (show more right side of the painting).
const _FOCAL_X := {
	"hope":     -20.0,
	"courage":  -55.0,
	"serenity": -40.0,
	"purpose":  -50.0,
}

# ── Private state ─────────────────────────────────────────────────────────────

var _class_name_value: String = ""
var _sz: Vector2 = Vector2(392, 408)   # frame size stored from setup()
var _current_state: State = State.IDLE
var _idle_tween: Tween = null
var _state_tween: Tween = null
var has_layered_art := false   # auto-set in setup()

# Art layers
var _art: TextureRect = null         # flat composite fallback
var _layer_body: TextureRect = null  # torso + clothing (breathing)
var _layer_head: TextureRect = null  # face (drifts + blinks)
var _layer_hair: TextureRect = null  # hair (sways)
var _layer_aura: TextureRect = null  # optional aura overlay

# Blink textures swapped onto _layer_head
var _head_open_tex: Texture2D = null
var _head_blink_tex: Texture2D = null

# ── File helpers (bypass .import requirement on desktop) ─────────────────────

func _file_exists_res(path: String) -> bool:
	if ResourceLoader.exists(path):
		return true
	var abs := ProjectSettings.globalize_path(path)
	return FileAccess.file_exists(abs)

func _load_texture_res(path: String) -> Texture2D:
	# Prefer ResourceLoader (works in any environment including Android export).
	if ResourceLoader.exists(path):
		return ResourceLoader.load(path) as Texture2D
	# Fallback: load raw PNG from disk — works on desktop without .import sidecars.
	var abs := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(abs):
		return null
	var img := Image.new()
	if img.load(abs) != OK:
		return null
	return ImageTexture.create_from_image(img)

# ── Setup ─────────────────────────────────────────────────────────────────────

## Call immediately after adding this node to the tree (or just before —
## animations are deferred so get_tree() is never called while detached).
## class_name_str: "Hope", "Courage", "Serenity", "Purpose", or "Sponsor"
## size_vec: pixel size of this Control
func setup(class_name_str: String, size_vec: Vector2) -> void:
	_class_name_value = class_name_str
	_sz = size_vec
	custom_minimum_size = size_vec
	size = size_vec
	clip_contents = true

	# Auto-detect layered art (handles missing .import sidecars on desktop)
	var body_path := "res://assets/leaders/%s_body.png" % class_name_str.to_lower()
	has_layered_art = _file_exists_res(body_path)

	_setup_nodes(size_vec)

	# Defer so get_tree() / create_timer() are never called while detached.
	call_deferred("set_state", State.IDLE)

func _setup_nodes(sz: Vector2) -> void:
	for ch in get_children():
		ch.queue_free()
	_art = null; _layer_body = null; _layer_head = null
	_layer_hair = null; _layer_aura = null
	_head_open_tex = null; _head_blink_tex = null

	# Aura glow — behind everything
	var aura_bg := ColorRect.new()
	aura_bg.color = Color(_class_color(), 0.0)
	aura_bg.position = Vector2.ZERO
	aura_bg.size = sz
	aura_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aura_bg.name = "AuraBg"
	add_child(aura_bg)

	if has_layered_art:
		# Stack: body → head → hair → (aura)
		_layer_body = _make_layer("body", sz)
		_layer_head = _make_layer("head", sz)
		_layer_hair = _make_layer("hair", sz)

		# Cache both head textures for blink swap
		_head_open_tex = _layer_head.texture
		var blink_path := "res://assets/leaders/%s_head_blink.png" % _class_name_value.to_lower()
		if _file_exists_res(blink_path):
			_head_blink_tex = _load_texture_res(blink_path)

		# Optional aura overlay
		var aura_path := "res://assets/leaders/%s_aura.png" % _class_name_value.to_lower()
		if _file_exists_res(aura_path):
			_layer_aura = _make_layer("aura", sz)
			_layer_aura.modulate.a = 0.0  # fades in during IDLE
	else:
		# ── Flat composite fallback ────────────────────────────────────────────
		# The source art is a full-scene square painting; the character occupies
		# only the top portion.  We crop to the top 72% (head → torso) and apply
		# a per-class focal-point X-shift so the face stays centred regardless of
		# where the artist placed it within the composition.
		_art = TextureRect.new()
		_art.texture = _resolve_flat_texture()

		# Focal shift: make the rect wider by |focal_x| and offset it so the
		# parent's clip (clip_contents=true) exposes the centred face region.
		var foc_x: float = _FOCAL_X.get(_class_name_value.to_lower(), 0.0)
		_art.position = Vector2(foc_x, 0.0)
		_art.size = Vector2(sz.x + absf(foc_x), sz.y)

		_art.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
		_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_art.clip_contents = false
		_art.mouse_filter  = Control.MOUSE_FILTER_IGNORE
		_art.pivot_offset  = Vector2(_art.size.x * 0.5, _art.size.y * 0.5)
		add_child(_art)

func _make_layer(part: String, sz: Vector2) -> TextureRect:
	var path := "res://assets/leaders/%s_%s.png" % [_class_name_value.to_lower(), part]
	var t := TextureRect.new()
	t.texture = _load_texture_res(path)  # null-safe if file missing
	# Transparent 1024×1024 layers must FIT — COVERED would crop the canvas and
	# misalign layers relative to each other.
	t.position = Vector2.ZERO
	t.size = sz
	t.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.clip_contents = false
	t.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	t.pivot_offset  = sz * 0.5
	add_child(t)
	return t

# ── Texture resolution ────────────────────────────────────────────────────────

func _resolve_flat_texture() -> Texture2D:
	if _class_name_value.to_lower() == "sponsor":
		return _load_texture_res("res://assets/cards/full/jd-080.jpg")
	var base: Texture2D = _load_texture_res("res://assets/leaders/%s.png" % _class_name_value.to_lower())
	if base == null:
		return null
	var margin := base.get_width() * 0.045
	var iw := base.get_width()  - margin * 2.0
	var ih := base.get_height() - margin * 2.0
	var atlas := AtlasTexture.new()
	atlas.atlas = base
	atlas.region = Rect2(margin, margin, iw, ih * 0.72)   # top 72% = head + shoulders + torso
	return atlas

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
	if _idle_tween:  _idle_tween.kill();  _idle_tween = null
	if _state_tween: _state_tween.kill(); _state_tween = null

	# Reset all layers to neutral transform / colour
	for node in [_art, _layer_head, _layer_hair, _layer_body, _layer_aura]:
		if node == null: continue
		node.position = Vector2.ZERO
		node.modulate  = Color.WHITE
		node.scale     = Vector2.ONE

	# Re-apply focal shift on flat art after a reset
	if _art:
		var foc_x: float = _FOCAL_X.get(_class_name_value.to_lower(), 0.0)
		_art.position = Vector2(foc_x, 0.0)

	# Restore open-eye texture after any blink-swap
	if _layer_head and _head_open_tex:
		_layer_head.texture = _head_open_tex

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

func _play_idle() -> void:
	var aura_bg := get_node_or_null("AuraBg") as ColorRect

	if has_layered_art:
		# ── BODY: subtle chest breathing (1.8% scale, 3.5 s) ──────────────────
		# Values are in the portrait's display space (e.g. 392 px wide),
		# so a 10 px offset is clearly visible without looking jittery.
		if _layer_body:
			var body_t := create_tween().set_loops()
			body_t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			body_t.tween_property(_layer_body, "scale", Vector2(1.018, 1.022), 3.5)
			body_t.tween_property(_layer_body, "scale", Vector2.ONE,            3.5)

		# ── HEAD: lateral idle drift (±10 px, 2.4 s) ─────────────────────────
		if _layer_head:
			_idle_tween = create_tween().set_loops()
			_idle_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_idle_tween.tween_property(_layer_head, "position:x", -10.0, 2.4)
			_idle_tween.tween_property(_layer_head, "position:x",   8.0, 2.4)

		# ── HAIR: wider sway, offset phase (±16 px, 2.7 s) ───────────────────
		if _layer_hair:
			var ht := create_tween().set_loops()
			ht.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			ht.tween_property(_layer_hair, "position:x", -16.0, 2.7)
			ht.tween_property(_layer_hair, "position:x",  14.0, 2.7)

		# ── BLINK: texture-swap every 3–5.5 s ────────────────────────────────
		if _layer_head and _head_blink_tex:
			_schedule_blink()

		# ── AURA OVERLAY: fade in then pulse ──────────────────────────────────
		if _layer_aura:
			var at := create_tween().set_loops()
			at.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			at.tween_property(_layer_aura, "modulate:a", 0.60, 1.8)
			at.tween_property(_layer_aura, "modulate:a", 0.18, 1.8)

		# ── AURA BG: class-colour pulse ───────────────────────────────────────
		if aura_bg:
			var bt := create_tween().set_loops()
			bt.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			bt.tween_property(aura_bg, "color:a", 0.20, 2.2)
			bt.tween_property(aura_bg, "color:a", 0.04, 2.2)
	else:
		# ── Flat art: visible breathing + slight vertical drift ───────────────
		if aura_bg:
			var bt := create_tween().set_loops()
			bt.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			bt.tween_property(aura_bg, "color:a", 0.22, 2.2)
			bt.tween_property(aura_bg, "color:a", 0.04, 2.2)
		if _art:
			# Scale breathing — 2.8% so it's clearly visible at portrait size
			_idle_tween = create_tween().set_loops()
			_idle_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_idle_tween.tween_property(_art, "scale",      Vector2(1.028, 1.028), 3.2)
			_idle_tween.tween_property(_art, "scale",      Vector2.ONE,            3.2)
			# Slight upward drift on the breathing inhale
			var dt := create_tween().set_loops()
			dt.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			dt.tween_property(_art, "position:y",  -5.0, 3.2)
			dt.tween_property(_art, "position:y",   0.0, 3.2)

func _schedule_blink() -> void:
	if _layer_head == null or _head_blink_tex == null or _current_state != State.IDLE:
		return
	# Node may not yet be in the tree (setup() → call_deferred is a guard,
	# but belt-and-suspenders: wait for tree_entered if still detached).
	if not is_inside_tree():
		await tree_entered
	if _layer_head == null or _current_state != State.IDLE:
		return
	await get_tree().create_timer(randf_range(3.0, 5.5)).timeout
	if _current_state != State.IDLE or _layer_head == null:
		return
	# Snap to blink frame, hold, snap back
	_layer_head.texture = _head_blink_tex
	await get_tree().create_timer(0.14).timeout
	if _layer_head and _head_open_tex:
		_layer_head.texture = _head_open_tex
	_schedule_blink()

func _play_selected() -> void:
	var target := _layer_head if has_layered_art and _layer_head else _art
	if target == null: return
	target.pivot_offset = target.size * 0.5
	_state_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_state_tween.tween_property(target, "scale", Vector2(1.04, 1.04), 0.35)
	_play_idle()

func _play_damaged() -> void:
	var target := (_layer_head if has_layered_art and _layer_head else _art)
	if target == null: target = _art
	if target == null: return
	_state_tween = create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_state_tween.tween_property(target, "modulate",   Color(2.2, 2.2, 2.2), 0.06)
	_state_tween.tween_property(target, "position:x", -20.0, 0.09)
	_state_tween.tween_property(target, "modulate",   Color.WHITE, 0.22)
	_state_tween.tween_property(target, "position:x",   0.0, 0.30)
	_state_tween.tween_callback(func(): animation_finished.emit(State.DAMAGED); set_state(State.IDLE))

func _play_healed() -> void:
	var target := _art if _art else _layer_body
	if target == null: return
	_state_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_state_tween.tween_property(target, "modulate",   Color(0.60, 1.55, 0.72), 0.22)
	_state_tween.tween_property(target, "position:y", -7.0, 0.28)
	_state_tween.tween_property(target, "modulate",   Color.WHITE, 0.48)
	_state_tween.tween_property(target, "position:y",  0.0, 0.38)
	_state_tween.tween_callback(func(): animation_finished.emit(State.HEALED); set_state(State.IDLE))

func _play_ability() -> void:
	var target := (_layer_head if has_layered_art and _layer_head else _art)
	if target == null: target = _art
	if target == null: return
	_state_tween = create_tween()
	_state_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_state_tween.set_parallel(true)
	_state_tween.tween_property(target, "scale",      Vector2(1.07, 1.07), 0.20)
	_state_tween.tween_property(target, "position:x", 10.0, 0.20)
	_state_tween.tween_property(target, "modulate",   Color(_class_color() * 1.6, 1.0), 0.20)
	_state_tween.chain().set_parallel(true)
	_state_tween.tween_property(target, "scale",      Vector2.ONE, 0.30)
	_state_tween.tween_property(target, "position:x", 0.0, 0.30)
	_state_tween.tween_property(target, "modulate",   Color.WHITE, 0.30)
	_state_tween.chain().tween_callback(func(): animation_finished.emit(State.ABILITY); set_state(State.IDLE))

func _play_victory() -> void:
	var target := (_art if _art else _layer_body)
	if target == null: return
	target.pivot_offset = target.size * 0.5
	_state_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_state_tween.tween_property(target, "scale",    Vector2(1.055, 1.055), 0.50)
	_state_tween.tween_property(target, "modulate", Color(1.12, 1.06, 0.82), 0.50)
	_play_idle()

func _play_defeat() -> void:
	var target := (_layer_head if has_layered_art and _layer_head else _art)
	if target == null: target = _art
	if target == null: return
	_state_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_state_tween.tween_property(target, "position:y",  14.0, 0.65)
	_state_tween.tween_property(target, "modulate", Color(0.52, 0.52, 0.58), 0.80)
	if _layer_aura:
		var at := create_tween()
		at.tween_property(_layer_aura, "modulate:a", 0.0, 1.0)

func _play_voice_line() -> void:
	var target := (_layer_head if has_layered_art and _layer_head else _art)
	if target == null: return
	_state_tween = create_tween().set_loops(3)
	_state_tween.tween_property(target, "scale", Vector2(1.010, 1.018), 0.11)
	_state_tween.tween_property(target, "scale", Vector2.ONE, 0.11)
	_state_tween.tween_callback(func(): animation_finished.emit(State.VOICE_LINE); set_state(State.IDLE))
