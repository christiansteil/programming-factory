extends Node

signal coal_changed(amount: int)
signal program_changed(is_running: bool, error_message: String)

const COAL_RESOURCE_NAME := "coal"

var coal := 0:
	set(value):
		if coal == value:
			return
		coal = value
		coal_changed.emit(coal)

var current_source_code := ""
var is_mining_coal := false
var program_error := ""
var _mine_tick_elapsed := 0.0

func _process(delta: float) -> void:
	if not is_mining_coal:
		_mine_tick_elapsed = 0.0
		return

	_mine_tick_elapsed += delta
	while _mine_tick_elapsed >= 1.0:
		_mine_tick_elapsed -= 1.0
		coal += 1

func apply_program(source_code: String) -> void:
	current_source_code = source_code

	var parse_result := _parse_program(source_code)
	if parse_result["error_message"] != "":
		is_mining_coal = false
		program_error = parse_result["error_message"]
		_mine_tick_elapsed = 0.0
		program_changed.emit(false, program_error)
		return

	is_mining_coal = parse_result["should_mine_coal"]
	program_error = ""
	program_changed.emit(is_mining_coal, program_error)

func _parse_program(source_code: String) -> Dictionary:
	var should_mine_coal := false
	var lines := source_code.split("\n")

	for index in range(lines.size()):
		var line := lines[index].strip_edges()
		if line == "" or line.begins_with("#"):
			continue

		if line == "mine(\"%s\")" % COAL_RESOURCE_NAME:
			should_mine_coal = true
			continue

		return {
			"should_mine_coal": false,
			"error_message": "Line %d: expected mine(\"coal\")" % [index + 1],
		}

	return {
		"should_mine_coal": should_mine_coal,
		"error_message": "",
	}
