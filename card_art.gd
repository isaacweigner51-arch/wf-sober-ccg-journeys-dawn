extends Node
# CardArt — single shared art resolver for every screen in the game.
#
# Uses FileAccess raw-byte decoding (the same path that already works in
# CardView._load_card_art_path).  This bypasses Godot's import cache entirely
# so the game always shows the actual source image whether running in the
# editor, from an APK, or a desktop export.

var _cache: Dictionary = {}       # lowercase res:// path -> Texture2D
var _name_to_id: Dictionary = {}  # lowercase card name -> lowercase "jd-###"
var _catalog_loaded: bool = false

# ── catalog ───────────────────────────────────────────────────────────────────

func _ensure_catalog() -> void:
	if _catalog_loaded:
		return
	_catalog_loaded = true
	var file := FileAccess.open("res://data/cards.json", FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Array):
		return
	for entry in parsed:
		if entry is Dictionary:
			var key: String = str(entry.get("name", "")).strip_edges().to_lower()
			var val: String = str(entry.get("id",   "")).strip_edges().to_lower()
			if not key.is_empty() and not val.is_empty():
				_name_to_id[key] = val

# ── loader (byte-read first, PCK fallback) ────────────────────────────────────

func _load_path(path: String) -> Texture2D:
	var key := path.to_lower()
	if _cache.has(key):
		return _cache[key] as Texture2D

	# Primary: read raw bytes so the game shows the source file directly,
	# identical to CardView._load_card_art_path which is the proven working path.
	if FileAccess.file_exists(path):
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
		var image := Image.new()
		var err: Error = ERR_FILE_UNRECOGNIZED
		var lp := path.to_lower()
		if lp.ends_with(".jpg") or lp.ends_with(".jpeg"):
			err = image.load_jpg_from_buffer(bytes)
		elif lp.ends_with(".png"):
			err = image.load_png_from_buffer(bytes)
		if err == OK and not image.is_empty():
			var t := ImageTexture.create_from_image(image)
			_cache[key] = t
			return t

	# Fallback: compiled .ctex from a shipped PCK / exported APK.
	var t := load(path) as Texture2D
	if t != null:
		_cache[key] = t
	return t

# ── public API ────────────────────────────────────────────────────────────────

# resolve(cd) is the only function callers should use.
# Pass any card Dictionary — collection, hand, pack pull, deck preview.
func resolve(cd: Dictionary) -> Texture2D:
	# Step 1 — "id" field is already a JD-### catalog string.
	var card_id: String = str(cd.get("id", "")).strip_edges().to_lower()
	if card_id.begins_with("jd-"):
		var t := _load_path("res://assets/cards/full/%s.jpg" % card_id)
		if t != null:
			return t

	# Step 2 — name → catalog id lookup (deck/hand cards sometimes carry
	# numeric story chapter ids instead of the catalog string).
	_ensure_catalog()
	var card_name: String = str(cd.get("name", "")).strip_edges().to_lower()
	if not card_name.is_empty() and _name_to_id.has(card_name):
		var catalog_id: String = _name_to_id[card_name]
		var t := _load_path("res://assets/cards/full/%s.jpg" % catalog_id)
		if t != null:
			return t

	# Step 3 — file genuinely missing or card has no JD-### id at all.
	# Log clearly so a missing art file is immediately visible in Output.
	if card_id.begins_with("jd-") or (not card_name.is_empty() and _name_to_id.has(card_name)):
		var missing_id := card_id if card_id.begins_with("jd-") else _name_to_id.get(card_name, "?")
		push_error("[CardArt] file not found  id=%s  path=res://assets/cards/full/%s.jpg" % [missing_id, missing_id])
		print("[CardArt] file not found  id=%s  path=res://assets/cards/full/%s.jpg" % [missing_id, missing_id])

	# Deterministic placeholder — only reached when no JD-### id exists anywhere.
	var seed_value: int = absi(str(cd.get("name", "card")).hash())
	return _load_path("res://assets/cards/art_%02d.png" % (seed_value % 16))
