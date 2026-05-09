extends Control

@onready var file_selector: OptionButton = %FileSelector
@onready var file_name_edit: LineEdit = %FileNameEdit
@onready var new_file_button: Button = %NewFileButton
@onready var rename_file_button: Button = %RenameFileButton
@onready var delete_file_button: Button = %DeleteFileButton
@onready var code_editor: TextEdit = %CodeEditor
@onready var status_label: Label = %StatusLabel
@onready var error_label: Label = %ErrorLabel
@onready var resources_button: Button = %ResourcesButton
@onready var clear_button: Button = %ClearButton
@onready var run_button: Button = %RunButton

func _ready() -> void:
	GameState.files_changed.connect(_on_files_changed)
	GameState.program_changed.connect(_on_program_changed)
	file_selector.item_selected.connect(_on_file_selected)
	file_name_edit.text_submitted.connect(_on_file_name_submitted)
	new_file_button.pressed.connect(_on_new_file_pressed)
	rename_file_button.pressed.connect(_on_rename_file_pressed)
	delete_file_button.pressed.connect(_on_delete_file_pressed)
	code_editor.text_changed.connect(_on_code_changed)
	resources_button.pressed.connect(_on_resources_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	run_button.pressed.connect(_on_run_pressed)
	_refresh_file_ui(GameState.get_file_names(), GameState.current_file_name)
	_load_current_file()
	code_editor.grab_focus()
	_update_status()

func _on_code_changed() -> void:
	GameState.set_current_source_code(code_editor.text)
	_update_status()

func _on_program_changed(_is_running: bool, _error_message: String) -> void:
	_update_status()

func _on_files_changed(file_names: PackedStringArray, current_file_name: String) -> void:
	_refresh_file_ui(file_names, current_file_name)
	_load_current_file()
	_update_status()

func _on_file_selected(index: int) -> void:
	GameState.set_current_file(file_selector.get_item_text(index))

func _on_file_name_submitted(_new_text: String) -> void:
	_on_rename_file_pressed()

func _on_new_file_pressed() -> void:
	GameState.create_file(file_name_edit.text)
	code_editor.grab_focus()

func _on_rename_file_pressed() -> void:
	GameState.rename_current_file(file_name_edit.text)
	code_editor.grab_focus()

func _on_delete_file_pressed() -> void:
	GameState.delete_current_file()
	code_editor.grab_focus()

func _on_resources_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ResourcesScreen.tscn")

func _on_clear_pressed() -> void:
	code_editor.clear()
	GameState.set_current_source_code(code_editor.text)
	code_editor.grab_focus()
	_update_status()

func _on_run_pressed() -> void:
	if GameState.is_program_running:
		GameState.stop_program()
	else:
		GameState.apply_program()
	code_editor.grab_focus()
	_update_status()

func _refresh_file_ui(file_names: PackedStringArray, current_file_name: String) -> void:
	file_selector.clear()
	var selected_index: int = 0
	for file_index in range(file_names.size()):
		var file_name: String = file_names[file_index]
		file_selector.add_item(file_name)
		if file_name == current_file_name:
			selected_index = file_index
	file_selector.select(selected_index)
	file_name_edit.text = current_file_name
	rename_file_button.disabled = current_file_name == GameState.MAIN_FILE_NAME
	delete_file_button.disabled = current_file_name == GameState.MAIN_FILE_NAME

func _load_current_file() -> void:
	if code_editor.text == GameState.current_source_code:
		return
	code_editor.set_block_signals(true)
	code_editor.text = GameState.current_source_code
	code_editor.set_block_signals(false)

func _update_status() -> void:
	var character_count: int = code_editor.text.length()
	var line_count: int = max(1, code_editor.get_line_count())
	var run_state: String = _get_run_state()
	status_label.text = "%s • %s • %d line(s) • %d character(s)" % [GameState.current_file_name, run_state, line_count, character_count]
	error_label.text = GameState.program_error
	error_label.visible = GameState.program_error != ""
	run_button.text = "Stop Code" if GameState.is_program_running else "Apply Code"

func _get_running_program_state() -> String:
	var actions: PackedStringArray = PackedStringArray()
	if GameState.is_mining_coal:
		actions.append("mine coal")
	if GameState.is_mining_iron:
		actions.append("mine iron")
	if GameState.is_smelting_iron:
		actions.append("smelt iron")
	if actions.is_empty():
		return "running main, no commands"
	return "running main loop: %s" % ", ".join(actions)

func _get_run_state() -> String:
	if GameState.program_error != "":
		return "error"
	if GameState.has_pending_program_changes:
		return "running applied files; edits pending"
	if GameState.is_program_running:
		return _get_running_program_state()
	if code_editor.text.strip_edges() == "":
		return "waiting for input"
	return "ready to apply"
