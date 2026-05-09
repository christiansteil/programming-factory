extends Control

@onready var code_editor: TextEdit = %CodeEditor
@onready var status_label: Label = %StatusLabel
@onready var error_label: Label = %ErrorLabel
@onready var resources_button: Button = %ResourcesButton
@onready var clear_button: Button = %ClearButton
@onready var run_button: Button = %RunButton

func _ready() -> void:
	code_editor.text = GameState.current_source_code
	code_editor.text_changed.connect(_on_code_changed)
	GameState.program_changed.connect(_on_program_changed)
	resources_button.pressed.connect(_on_resources_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	run_button.pressed.connect(_on_run_pressed)
	code_editor.grab_focus()
	_update_status()

func _on_code_changed() -> void:
	GameState.set_current_source_code(code_editor.text)
	_update_status()

func _on_program_changed(_is_running: bool, _error_message: String) -> void:
	_update_status()

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
		GameState.apply_program(code_editor.text)
	code_editor.grab_focus()
	_update_status()

func _update_status() -> void:
	var character_count := code_editor.text.length()
	var line_count := max(1, code_editor.get_line_count())
	var run_state := _get_run_state()
	status_label.text = "%s • %d line(s) • %d character(s)" % [run_state, line_count, character_count]
	error_label.text = GameState.program_error
	error_label.visible = GameState.program_error != ""
	run_button.text = "Stop Code" if GameState.is_program_running else "Apply Code"

func _get_run_state() -> String:
	if GameState.program_error != "":
		return "error"
	if GameState.is_program_running and GameState.current_source_code != GameState.running_source_code:
		return "running applied code; edits pending"
	if GameState.is_mining_coal:
		return "mining coal (+1/sec)"
	if GameState.is_program_running:
		return "running, no active jobs"
	if code_editor.text.strip_edges() == "":
		return "waiting for input"
	return "ready to apply"
