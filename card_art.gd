extends Node
# CardArt — single shared art resolver for every screen in the game.
#
# Battle (main.gd), Collection, Pack Opening, Deck Builder, and CardView
# all call CardArt.resolve(cd).  Nothing else loads card art.  This is
# the exact same algorithm as the working resolve_card_full_art() that
# was previously local to battle, lifted into a persistent autoload so
# the result is identical regardless of which scene is asking.

var _cache: Dictionary = {}       # resolved path -> Texture2D
var _name_to_id: Dictionary = {}  # lowercase card name -> lowercase jd-### id
var _catalog_loaded: bool = false

# ── catalog ──────────────────────────────────────────────────────────────────

func _ensure_catalog() -> void:
	if _catalog_loaded:
		return
	_catalog_loaded = true
	var file := FileAccess.open("res://data/cards.json", FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Array:
		for entry in parsed:
			if entry is Dictionary:
				var key: String = str(entry.get("name", "")).strip_edges().to_lower()
				var val: String = str(entry.get("id",   "")).strip_edges().to_lower()
				if not key.is_empty() and not val.is_empty():
					_name_to_id[key] = val

# ── internal loader (caches by path) ─────────────────────────────────────────

func _load_path(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path] as Texture2D
	if not ResourceLoader.exists(path):
		return null
	var t := load(path) as Texture2D
	if t != null:
		_cache[path] = t
	return t

# ── public API ────────────────────────────────────────────────────────────────

# resolve(cd) is the only function callers should use.
# cd must be a card Dictionary (any context: hand, collection, pack pull, deck).
func resolve(cd: Dictionary) -> Texture2D:
	# Step 1 — id field is already a JD-### string (cards.json entries).
	var card_id: String = str(cd.get("id", "")).strip_edges().to_lower()
	if card_id.begins_with("jd-"):
		var path := "res://assets/cards/full/%s.jpg" % card_id
		var t := _load_path(path)
		if t != null:
			return t
		# File has a valid catalog id but the texture failed — always visible.
		push_error("[CardArt] MISSING  id=%s  path=%s" % [card_id, path])
		print("[CardArt] MISSING  id=%s  path=%s" % [card_id, path])

	# Step 2 — name lookup (deck/hand cards sometimes carry numeric story ids).
	_ensure_catalog()
	var card_name: String = str(cd.get("name", "")).strip_edges().to_lower()
	if not card_name.is_empty() and _name_to_id.has(card_name):
		var catalog_id: String = _name_to_id[card_name]
		var path := "res://assets/cards/full/%s.jpg" % catalog_id
		var t := _load_path(path)
		if t != null:
			return t
		push_error("[CardArt] MISSING  name='%s'  id=%s  path=%s" % [card_name, catalog_id, path])
		print("[CardArt] MISSING  name='%s'  id=%s  path=%s" % [card_name, catalog_id, path])

	# Step 3 — no JD-### id found anywhere.  Only real placeholder case.
	if card_id.begins_with("jd-") or (not card_name.is_empty() and _name_to_id.has(card_name)):
		# We already printed an error above; return null so callers know.
		return null
	var seed_value: int = absi(str(cd.get("name", "card")).hash())
	return load("res://assets/cards/art_%02d.png" % (seed_value % 16)) as Texture2D
