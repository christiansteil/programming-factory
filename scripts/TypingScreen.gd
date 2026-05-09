extends Control

@onready var status_label: Label = $StatusLabel

func _update_status() -> void:
	var program_error = GameState.program_error
	if typeof(program_error) == TYPE_DICTIONARY and program_error.has("message"):
		status_label.text = program_error["message"]
	elif typeof(program_error) == TYPE_STRING and not program_error.is_empty():
		status_label.text = program_error
	else:
		status_label.text = ""
