extends Node
# CardArt — single shared art resolver for every screen in the game.
#
# Uses ResourceLoader.exists() + load() so the path works identically in the
# editor, exported PCK, and Android APK (where raw FileAccess on res:// paths
# is unreliable because images are remapped to their imported .ctex forms).

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

# ── loader ────────────────────────────────────────────────────────────────────

func _load_path(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path] as Texture2D
	var exists: bool = ResourceLoader.exists(path, "Texture2D")
	print("[CardArt] path=%s  ResourceLoader.exists=%s" % [path, exists])
	if not exists:
		return null
	var t := load(path) as Texture2D
	if t != null:
		_cache[path] = t
	return t

# ── public API ────────────────────────────────────────────────────────────────

# resolve(cd) is the only function callers should use.
# Pass any card Dictionary — collection, hand, pack pull, deck preview.
func resolve(cd: Dictionary) -> Texture2D:
	# Step 1 — "id" field is already a JD-### catalog string.
	var card_id: String = str(cd.get("id", "")).strip_edges().to_lower()
	if card_id.begins_with("jd-"):
		var path := "res://assets/cards/full/%s.jpg" % card_id
		var t := _load_path(path)
		if t != null:
			return t

	# Step 2 — name → catalog id lookup (deck/hand cards sometimes carry
	# numeric story chapter ids instead of the catalog string).
	_ensure_catalog()
	var card_name: String = str(cd.get("name", "")).strip_edges().to_lower()
	if not card_name.is_empty() and _name_to_id.has(card_name):
		var catalog_id: String = _name_to_id[card_name]
		var path := "res://assets/cards/full/%s.jpg" % catalog_id
		var t := _load_path(path)
		if t != null:
			return t

	# Step 3 — genuinely missing. Log and return placeholder.
	var missing_id: String = card_id if card_id.begins_with("jd-") else \
		str(_name_to_id.get(card_name, "?") if not card_name.is_empty() else "?")
	push_error("[CardArt] MISSING  id=%s" % missing_id)
	print("[CardArt] MISSING  id=%s" % missing_id)
	var seed_value: int = absi(str(cd.get("name", "card")).hash())
	return load("res://assets/cards/art_%02d.png" % (seed_value % 16)) as Texture2D
