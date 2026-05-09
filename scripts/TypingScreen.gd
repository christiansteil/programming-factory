extends Control

@onready var code_editor: TextEdit = %CodeEditor
@onready var status_label: Label = %StatusLabel
@onready var clear_button: Button = %ClearButton
@onready var run_button: Button = %RunButton

func _ready() -> void:
	code_editor.text_changed.connect(_on_code_changed)
	clear_button.pressed.connect(_on_clear_pressed)
	run_button.pressed.connect(_on_run_pressed)
	code_editor.grab_focus()
	_update_status()

func _on_code_changed() -> void:
	_update_status()

func _on_clear_pressed() -> void:
	code_editor.clear()
	code_editor.grab_focus()
	_update_status()

func _on_run_pressed() -> void:
	status_label.text = "Run is coming next. For now, keep drafting your factory program."
	code_editor.grab_focus()

func _update_status() -> void:
	var character_count := code_editor.text.length()
	var line_count := max(1, code_editor.get_line_count())
	var run_state := "ready" if character_count > 0 else "waiting for input"
	status_label.text = "%s • %d line(s) • %d character(s)" % [run_state, line_count, character_count]
