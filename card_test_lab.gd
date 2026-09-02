extends Control


@onready var status_label: Label = $TestMenu/StatusLabel
@onready var load_card_button: Button = $TestMenu/LoadCardButton
@onready var card_selector: OptionButton = $TestMenu/CardSelector
@onready var card_search: LineEdit = $TestMenu/CardSearch


func _ready() -> void:
	status_label.text = "Ready"

	_populate_card_selector()

	if not card_search.text_changed.is_connected(_on_card_search_changed):
		card_search.text_changed.connect(_on_card_search_changed)

	if not card_selector.item_selected.is_connected(_on_card_selected):
		card_selector.item_selected.connect(_on_card_selected)

	if not load_card_button.pressed.is_connected(_on_load_card_button_pressed):
		load_card_button.pressed.connect(_on_load_card_button_pressed)


func _populate_card_selector(search_text: String = "") -> void:
	card_selector.clear()

	var file := FileAccess.open("res://data/cards.json", FileAccess.READ)

	if file == null:
		status_label.text = "Could not load card list."
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())

	if not (parsed is Array):
		status_label.text = "Card list is invalid."
		return

	var cards: Array = parsed.duplicate()

	cards.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var a_id := str(a.get("id", "JD-000")).to_upper()
			var b_id := str(b.get("id", "JD-000")).to_upper()

			var a_num := int(a_id.trim_prefix("JD-"))
			var b_num := int(b_id.trim_prefix("JD-"))

			return a_num < b_num
	)

	var search := search_text.strip_edges().to_lower()

	for entry in cards:
		if entry is Dictionary:
			var card_id := str(entry.get("id", "")).strip_edges()
			var card_name := str(entry.get("name", "Unknown Card")).strip_edges()
			var card_class := str(entry.get("class", "")).strip_edges()

			if not search.is_empty():
				var name_matches := card_name.to_lower().contains(search)
				var id_matches := card_id.to_lower().contains(search)

				if not name_matches and not id_matches:
					continue

			card_selector.add_item(
				"%s — %s (%s)" % [
					card_id,
					card_name,
					card_class
				]
			)

			card_selector.set_item_metadata(
				card_selector.item_count - 1,
				card_id.to_lower()
			)

	if card_selector.item_count > 0:
		card_selector.select(0)
		_update_selected_card_status()
	else:
		status_label.text = "No cards found."


func _on_card_search_changed(new_text: String) -> void:
	_populate_card_selector(new_text)


func _on_card_selected(_index: int) -> void:
	_update_selected_card_status()


func _update_selected_card_status() -> void:
	if card_selector.item_count <= 0:
		return

	var index := card_selector.selected

	if index < 0:
		return

	status_label.text = card_selector.get_item_text(index)


func _on_load_card_button_pressed() -> void:
	if card_selector.item_count <= 0:
		status_label.text = "No card selected."
		return

	var selected_index := card_selector.selected

	if selected_index < 0:
		status_label.text = "No card selected."
		return

	var card_id := str(
		card_selector.get_item_metadata(selected_index)
	).strip_edges().to_lower()

	if card_id.is_empty():
		status_label.text = "Selected card has no ID."
		return

	var cfg := ConfigFile.new()

	cfg.set_value("battle", "mode", "card_test")
	cfg.set_value("battle", "your_class", "Hope")
	cfg.set_value("battle", "opponent_class", "Courage")
	cfg.set_value("battle", "your_deck_mode", "prebuilt")
	cfg.set_value("battle", "opponent_deck_mode", "prebuilt")
	cfg.set_value("battle", "test_card_id", card_id)

	var err := cfg.save("user://battle_setup.cfg")

	if err != OK:
		status_label.text = "Could not start card test."
		return

	status_label.text = "Loading test: " + card_id

	get_tree().change_scene_to_file("res://battle.tscn")
