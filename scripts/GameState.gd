extends Node

signal coal_changed(amount: int)
signal program_changed(is_running: bool, error_message: String)

const ProgramInterpreter = preload("res://scripts/interpreter/ProgramInterpreter.gd")
const MINE_COAL_JOB: String = "mine:coal"

var coal: int = 0:
	set(value):
		if coal == value:
			return
		coal = value
		coal_changed.emit(coal)

var current_source_code: String = ""
var running_source_code: String = ""
var active_jobs: Dictionary = {}
var program_error: String = ""
var is_program_running: bool = false
var _mine_tick_elapsed: float = 0.0

var is_mining_coal: bool:
	get:
		return active_jobs.has(MINE_COAL_JOB)

func _process(delta: float) -> void:
	if not active_jobs.has(MINE_COAL_JOB):
		_mine_tick_elapsed = 0.0
		return

	_mine_tick_elapsed += delta
	while _mine_tick_elapsed >= 1.0:
		_mine_tick_elapsed -= 1.0
		coal += 1

func set_current_source_code(source_code: String) -> void:
	current_source_code = source_code
	if not is_program_running and program_error != "":
		program_error = ""
		program_changed.emit(false, program_error)

func apply_program(source_code: String) -> void:
	current_source_code = source_code

	var parse_result: Dictionary = ProgramInterpreter.parse(source_code)
	if not parse_result["is_valid"]:
		_stop_active_jobs()
		program_error = parse_result["error_message"]
		program_changed.emit(false, program_error)
		return

	running_source_code = source_code
	active_jobs = _commands_to_active_jobs(parse_result["commands"])
	program_error = ""
	is_program_running = true
	program_changed.emit(true, program_error)

func stop_program() -> void:
	_stop_active_jobs()
	program_error = ""
	program_changed.emit(false, program_error)

func validate_program(source_code: String) -> Dictionary:
	return ProgramInterpreter.parse(source_code)

func _commands_to_active_jobs(commands: Array) -> Dictionary:
	var next_active_jobs: Dictionary = {}

	for command in commands:
		if command["name"] == ProgramInterpreter.COMMAND_MINE and command["resource"] == ProgramInterpreter.RESOURCE_COAL:
			next_active_jobs[MINE_COAL_JOB] = true

	return next_active_jobs

func _stop_active_jobs() -> void:
	active_jobs.clear()
	running_source_code = ""
	is_program_running = false
	_mine_tick_elapsed = 0.0
