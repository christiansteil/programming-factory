extends Control

@onready var coal_amount_label: Label = %CoalAmountLabel
@onready var back_button: Button = %BackButton

func _ready() -> void:
	GameState.coal_changed.connect(_on_coal_changed)
	back_button.pressed.connect(_on_back_pressed)
	_on_coal_changed(GameState.coal)
	back_button.grab_focus()

func _on_coal_changed(amount: int) -> void:
	coal_amount_label.text = str(amount)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/TypingScreen.tscn")
