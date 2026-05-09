extends Control

@onready var coal_amount_label: Label = %CoalAmountLabel
@onready var iron_amount_label: Label = %IronAmountLabel
@onready var back_button: Button = %BackButton

func _ready() -> void:
	GameState.coal_changed.connect(_on_coal_changed)
	GameState.iron_changed.connect(_on_iron_changed)
	back_button.pressed.connect(_on_back_pressed)
	_on_coal_changed(GameState.coal)
	_on_iron_changed(GameState.iron)
	back_button.grab_focus()

func _on_coal_changed(amount: float) -> void:
	coal_amount_label.text = _format_resource_amount(amount)

func _on_iron_changed(amount: float) -> void:
	iron_amount_label.text = _format_resource_amount(amount)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/TypingScreen.tscn")

func _format_resource_amount(amount: float) -> String:
	if is_equal_approx(amount, roundf(amount)):
		return str(int(roundf(amount)))
	return "%.1f" % amount
