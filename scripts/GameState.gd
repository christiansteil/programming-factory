extends Node

signal coal_changed(amount: float)
signal iron_changed(amount: float)
signal iron_plates_changed(amount: float)
signal program_changed(is_running: bool, error_message: String)

const ProgramInterpreter = preload("res://scripts/interpreter/ProgramInterpreter.gd")
const COAL_PER_MINE_TICK: float = 1.0
const IRON_PER_MINE_TICK: float = 0.5
const COAL_PER_IRON_SMELT: float = 2.0
const IRON_PER_IRON_SMELT: float = 1.0
const IRON_PLATES_PER_SMELT: float = 1.0
const PROGRAM_TICK_SECONDS: float = 1.0

var coal: float = 0.0:
	set(value):
		if is_equal_approx(coal, value):
			return
		coal = value
		coal_changed.emit(coal)

var iron: float = 0.0:
	set(value):
		if is_equal_approx(iron, value):
			return
		iron = value
		iron_changed.emit(iron)

var iron_plates: float = 0.0:
	set(value):
		if is_equal_approx(iron_plates, value):
			return
		iron_plates = value
		iron_plates_changed.emit(iron_plates)

var current_source_code: String = ""
var running_source_code: String = ""
var active_program_commands: Array = []
var program_error: String = ""
var is_program_running: bool = false
var _program_tick_elapsed: float = 0.0
var _next_command_index: int = 0

var is_mining_coal: bool:
	get:
		return _has_running_command(ProgramInterpreter.COMMAND_MINE, ProgramInterpreter.RESOURCE_COAL)

var is_mining_iron: bool:
	get:
		return _has_running_command(ProgramInterpreter.COMMAND_MINE, ProgramInterpreter.RESOURCE_IRON)

var is_smelting_iron: bool:
	get:
		return _has_running_command(ProgramInterpreter.COMMAND_SMELT, ProgramInterpreter.RESOURCE_IRON)

func _process(delta: float) -> void:
	if not is_program_running or active_program_commands.is_empty():
		_program_tick_elapsed = 0.0
		return

	_program_tick_elapsed += delta
	while _program_tick_elapsed >= PROGRAM_TICK_SECONDS:
		_program_tick_elapsed -= PROGRAM_TICK_SECONDS
		_execute_next_command_tick()

func set_current_source_code(source_code: String) -> void:
	current_source_code = source_code
	if not is_program_running and program_error != "":
		program_error = ""
		program_changed.emit(false, program_error)

func apply_program(source_code: String) -> void:
	current_source_code = source_code

	var parse_result: Dictionary = ProgramInterpreter.parse(source_code)
	if not parse_result["is_valid"]:
		_stop_active_program()
		program_error = parse_result["error_message"]
		program_changed.emit(false, program_error)
		return

	running_source_code = source_code
	active_program_commands = parse_result["commands"] as Array
	program_error = ""
	is_program_running = true
	_program_tick_elapsed = 0.0
	_next_command_index = 0
	program_changed.emit(true, program_error)

func stop_program() -> void:
	_stop_active_program()
	program_error = ""
	program_changed.emit(false, program_error)

func validate_program(source_code: String) -> Dictionary:
	return ProgramInterpreter.parse(source_code)

func _execute_next_command_tick() -> void:
	var command: Dictionary = active_program_commands[_next_command_index] as Dictionary
	_next_command_index = (_next_command_index + 1) % active_program_commands.size()

	if command["name"] == ProgramInterpreter.COMMAND_MINE:
		_execute_mine_command(command)
	elif command["name"] == ProgramInterpreter.COMMAND_SMELT:
		_execute_smelt_command(command)

func _execute_mine_command(command: Dictionary) -> void:
	if command["resource"] == ProgramInterpreter.RESOURCE_COAL:
		coal += COAL_PER_MINE_TICK
	elif command["resource"] == ProgramInterpreter.RESOURCE_IRON:
		iron += IRON_PER_MINE_TICK

func _execute_smelt_command(command: Dictionary) -> void:
	if command["resource"] != ProgramInterpreter.RESOURCE_IRON:
		return
	if coal < COAL_PER_IRON_SMELT or iron < IRON_PER_IRON_SMELT:
		return

	coal -= COAL_PER_IRON_SMELT
	iron -= IRON_PER_IRON_SMELT
	iron_plates += IRON_PLATES_PER_SMELT

func _has_running_command(command_name: String, resource_name: String) -> bool:
	for command_value in active_program_commands:
		var command: Dictionary = command_value as Dictionary
		if command["name"] == command_name and command["resource"] == resource_name:
			return true
	return false

func _stop_active_program() -> void:
	active_program_commands.clear()
	running_source_code = ""
	is_program_running = false
	_program_tick_elapsed = 0.0
	_next_command_index = 0
