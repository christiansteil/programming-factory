extends Control

@onready var code_editor: CodeEdit = %CodeEditor
@onready var editor_status: Label = %EditorStatus

func _ready() -> void:
	_on_code_changed()

func _on_code_changed() -> void:
	var line_count := code_editor.get_line_count()
	var character_count := code_editor.text.length()
	var line_label := "line" if line_count == 1 else "lines"
	var character_label := "character" if character_count == 1 else "characters"
	editor_status.text = "%d %s, %d %s" % [line_count, line_label, character_count, character_label]

func _on_run_pressed() -> void:
	GameState.apply_program(code_editor.text)
