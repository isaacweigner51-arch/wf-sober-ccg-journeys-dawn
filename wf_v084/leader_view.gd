# leader_view.gd
# Animated leader portrait node.  Stacks transparent PNG layers for real animation
# when the layered art files are present; falls back to the flat composite otherwise.
#
# Layer stack (bottom → top):
#   aura_bg      — class-color pulse glow (ColorRect, always)
#   _layer_body  — torso / clothing (breathing scale)
#   _layer_head  — face + neck (lateral drift; texture-swapped for blink)
#   _layer_hair  — hair (sways wider than head, offset phase)
#   _layer_aura  — optional glow, drawn BEHIND body/head/hair (halo)
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

# ── Breathing shader ─────────────────────────────────────────────────────────
# Applied to _layer_body during IDLE.  Deforms UV coordinates so the chest
# pixels push outward and upward on the inhale rather than scaling the whole
# rectangle — the same technique used in 2D fighting games.
const _BREATH_SHADER_CODE := """
shader_type canvas_item;
uniform float breath : hint_range(0.0, 1.0) = 0.0;
uniform float sway   : hint_range(-1.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = UV;

	// ── Weight-shift lean: whole figure leans as one piece, anchored at the
	// bottom of the canvas.  Because every layer shares this material, the
	// body, head, and hair lean together — they can never separate.
	uv.x -= sway * (1.0 - uv.y) * 0.012;

	// ── Breathing: continuous vertical falloff — strongest in the chest,
	// fading smoothly to zero at the very top and bottom of the figure so
	// there is NO seam anywhere.
	float lift = smoothstep(0.95, 0.55, uv.y) * smoothstep(0.02, 0.30, uv.y);
	uv.y += lift * breath * 0.014;

	// Shoulder spread — upper torso expands outward from center on inhale
	float shoulder = smoothstep(0.15, 0.35, uv.y) * smoothstep(0.60, 0.40, uv.y);
	uv.x += (uv.x - 0.5) * 2.0 * shoulder * breath * 0.010;

	COLOR = texture(TEXTURE, clamp(uv, vec2(0.001), vec2(0.999)));
}
"""

# ── Private state ─────────────────────────────────────────────────────────────

var _class_name_value: String = ""
var _sz: Vector2 = Vector2(392, 408)   # frame size stored from setup()
var _current_state: State = State.IDLE
var _idle_tween: Tween = null
var _state_tween: Tween = null
var has_layered_art := false   # auto-set in setup()
var _aux_idle_tweens: Array = []   # hair / head / aura tweens killed alongside _idle_tween

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
	# Only trust ResourceLoader — it requires a proper .import sidecar.
	# Raw FileAccess would find unimported PNGs whose layers have no shared
	# canvas alignment (AI-generated independently), causing misaligned compositing.
	return ResourceLoader.exists(path)

func _load_texture_res(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path) as Texture2D

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

	# Auto-detect: all layer PNGs are 1024×1024 full-canvas RGBA overlays that
	# share the same coordinate space, so stacking them inside a clipped frame
	# composites correctly.  Fall back to the flat portrait for non-class nodes
	# (enemy placeholder, Sponsor) that have no layer files.
	var cn := _class_name_value.to_lower()
	has_layered_art = (
		_file_exists_res("res://assets/leaders/%s_body.png" % cn) and
		_file_exists_res("res://assets/leaders/%s_head.png"  % cn) and
		_file_exists_res("res://assets/leaders/%s_hair.png"  % cn)
	)

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
		# Stack: (aura) → body → head → hair
		# The aura MUST sit BEHIND the character.  The aura art is a centered
		# orb/ring on the canvas — drawn on top it covers the face entirely
		# (the "glowing blob over the portrait" bug).  Behind the body it
		# reads as a halo glowing around the silhouette instead.
		var aura_path := "res://assets/leaders/%s_aura.png" % _class_name_value.to_lower()
		if _file_exists_res(aura_path):
			_layer_aura = _make_layer("aura", sz)
			_layer_aura.modulate.a = 0.0  # fades in during IDLE

		_layer_body = _make_layer("body", sz)
		_layer_head = _make_layer("head", sz)
		_layer_hair = _make_layer("hair", sz)

		# Cache both head textures for blink swap
		_head_open_tex = _layer_head.texture
		var blink_path := "res://assets/leaders/%s_head_blink.png" % _class_name_value.to_lower()
		if _file_exists_res(blink_path):
			_head_blink_tex = _load_texture_res(blink_path)
	else:
		# ── Flat composite fallback ────────────────────────────────────────────
		# The source art is a full-scene square painting; the character occupies
		# only the top portion.  We crop to the top 72% (head → torso) and apply
		# a per-class focal-point X-shift so the face stays centred regardless of
		# where the artist placed it within the composition.
		_art = TextureRect.new()
		# expand_mode + stretch_mode set BEFORE texture — avoids Godot 4 relayout
		# bug where setting expand_mode after size resets size to tex dimensions.
		_art.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
		_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_art.clip_contents = false
		_art.mouse_filter  = Control.MOUSE_FILTER_IGNORE
		_art.texture          = _resolve_flat_texture()
		# Add 12px extra height so the ±5px breathing tween never reveals a
		# blank strip at the bottom of the clipped frame.  Position starts at
		# y=-6 (vertically centred in the extra buffer) so the art stays flush
		# against the top of the viewport at rest.
		_art.position         = Vector2(0.0, -6.0)
		_art.custom_minimum_size = Vector2(sz.x, sz.y + 12)
		_art.size             = Vector2(sz.x, sz.y + 12)
		_art.pivot_offset     = sz * 0.5
		add_child(_art)

func _make_layer(part: String, sz: Vector2) -> TextureRect:
	var path := "res://assets/leaders/%s_%s.png" % [_class_name_value.to_lower(), part]
	var t := TextureRect.new()
	# IMPORTANT: expand_mode + stretch_mode must be set BEFORE texture.
	# Setting expand_mode after the texture is assigned triggers a Godot 4
	# layout bug that resets the node's size to the texture's native dimensions
	# (1024×1024), so a clipped 200×200 or 392×352 parent only sees the center
	# slice of the canvas — the same "zoomed in" / blue-square issue the flat-
	# art path already guards against with this exact ordering.
	t.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.clip_contents = false
	t.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	# Transparent 1024×1024 layers must FIT — COVERED would crop the canvas and
	# misalign layers relative to each other.
	t.texture = _load_texture_res(path)  # null-safe if file missing
	t.position = Vector2.ZERO
	t.size = sz
	t.pivot_offset  = sz * 0.5
	add_child(t)
	return t

# ── Texture resolution ────────────────────────────────────────────────────────

func _resolve_flat_texture() -> Texture2D:
	if _class_name_value.to_lower() == "sponsor":
		return _load_texture_res("res://assets/cards/full/jd-080.jpg")
	# Return the raw texture — no atlas crop, no focal offset.
	# The paintings are shown full-frame with CENTERED so the character is
	# always visible regardless of where in the canvas they sit.
	return _load_texture_res("res://assets/leaders/%s.png" % _class_name_value.to_lower())

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
	for t in _aux_idle_tweens:
		if t: t.kill()
	_aux_idle_tweens.clear()

	# Reset all layers to neutral transform / colour
	for node in [_art, _layer_head, _layer_hair, _layer_body, _layer_aura]:
		if node == null: continue
		node.position = Vector2.ZERO
		node.modulate  = Color.WHITE
		node.scale     = Vector2.ONE

	# Re-apply focal shift on flat art — only for larger frames.
	# In the 200×200 in-battle frame the negative shift clips the portrait
	# against the Button's clip_contents boundary; show it centred instead.
	if _art and _sz.x > 250:
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
	if not is_inside_tree():
		await tree_entered
	if _idle_tween: _idle_tween.kill()
	for t in _aux_idle_tweens:
		if t: t.kill()
	_aux_idle_tweens.clear()

	# Reset any leftover transforms from state animations before starting idle.
	position = Vector2.ZERO          # clear whole-character sway from previous idle
	for node in [_art, _layer_body, _layer_head, _layer_hair]:
		if node:
			node.scale         = Vector2.ONE
			node.position      = Vector2.ZERO
			node.modulate      = Color.WHITE
			node.rotation      = 0.0
			node.material      = null   # clear any breath shader from a previous idle

	if has_layered_art:
		# ── ONE shader material shared by body + head + hair ─────────────────
		# CRITICAL: every character layer must deform through the SAME material
		# instance.  When layers were tweened independently (head drifting while
		# the body deformed) the neck seam showed and the character read as two
		# pieces of paper sliding past each other.  A shared material means all
		# pixels of the character move as one continuous surface — the layers
		# can never separate, exactly like Shadowverse's Live2D-style leaders.
		var sm := ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = _BREATH_SHADER_CODE
		sm.shader = sh
		_layer_body.material = sm
		if _layer_head != null: _layer_head.material = sm
		if _layer_hair != null: _layer_hair.material = sm

		# Breath: 0→1→0, 4.6 s full cycle
		_idle_tween = create_tween().set_loops()
		_idle_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_idle_tween.tween_method(func(v: float): sm.set_shader_parameter("breath", v),
			0.0, 1.0, 2.3)
		_idle_tween.tween_method(func(v: float): sm.set_shader_parameter("breath", v),
			1.0, 0.0, 2.3)

		# Sway: -1→1→-1 inside the same shader (top of the figure leans, feet
		# anchored) on a longer period so it never syncs with the breath.
		var sw := create_tween().set_loops()
		sw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		sw.tween_method(func(v: float): sm.set_shader_parameter("sway", v),
			-1.0, 1.0, 3.4)
		sw.tween_method(func(v: float): sm.set_shader_parameter("sway", v),
			1.0, -1.0, 3.4)
		_aux_idle_tweens.append(sw)

		# ── Aura: slow pulse ─────────────────────────────────────────────────
		if _layer_aura != null:
			var at := create_tween().set_loops()
			at.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			at.tween_property(_layer_aura, "modulate:a", 0.90, 2.2)
			at.tween_property(_layer_aura, "modulate:a", 0.42, 2.2)
			_aux_idle_tweens.append(at)

		# Blink loop
		if _layer_head != null and _head_blink_tex != null:
			_schedule_blink()
	else:
		# ── Flat composite: shader breath on the whole portrait ───────────────
		var target := _art
		if target == null: return
		var sm2 := ShaderMaterial.new()
		var sh2 := Shader.new()
		sh2.code = _BREATH_SHADER_CODE
		sm2.shader = sh2
		target.material = sm2
		_idle_tween = create_tween().set_loops()
		_idle_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_idle_tween.tween_method(func(v: float): sm2.set_shader_parameter("breath", v),
			0.0, 1.0, 2.4)
		_idle_tween.tween_method(func(v: float): sm2.set_shader_parameter("breath", v),
			1.0, 0.0, 2.4)

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
	# Head layer is most expressive (it moves independently during idle);
	# fall back to the flat composite when layered art isn't loaded.
	var head   := _layer_head if (has_layered_art and _layer_head) else null
	var body   := _layer_body if (has_layered_art and _layer_body) else null
	var target := head if head else _art
	if target == null: return

	# ── Flash ─────────────────────────────────────────────────────────────────
	# Red-orange overbright — unmistakably "took a hit", not a white shimmer
	_state_tween = create_tween()
	_state_tween.tween_property(target, "modulate", Color(2.8, 0.38, 0.20), 0.05)

	# ── Recoil ────────────────────────────────────────────────────────────────
	# Snap back-and-up hard (the character flinches), overshoot forward
	# (stagger), then spring-settle to rest.
	_state_tween.tween_property(target, "position", Vector2(-30.0, -8.0), 0.07)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_state_tween.tween_property(target, "position", Vector2(10.0,   0.0), 0.12)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_state_tween.tween_property(target, "position", Vector2.ZERO,         0.24)\
		.set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)

	# Colour recovers in parallel with the spring-back
	var col := create_tween()
	col.tween_property(target, "modulate", Color.WHITE, 0.42)

	# Body silhouette also flushes red so the whole portrait reacts, not just
	# the head floating above a calm torso.
	if body:
		var bt := create_tween()
		bt.tween_property(body, "modulate", Color(2.0, 0.35, 0.18), 0.05)
		bt.tween_property(body, "modulate", Color.WHITE, 0.44)

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
