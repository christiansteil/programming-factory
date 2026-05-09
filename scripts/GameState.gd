extends Node

signal coal_changed(amount: float)
signal iron_changed(amount: float)
signal program_changed(is_running: bool, error_message: String)

const ProgramInterpreter = preload("res://scripts/interpreter/ProgramInterpreter.gd")
const MINE_COAL_JOB: String = "mine:coal"
const MINE_IRON_JOB: String = "mine:iron"
const COAL_PER_SECOND: float = 1.0
const IRON_PER_SECOND: float = 0.5

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

var current_source_code: String = ""
var running_source_code: String = ""
var active_jobs: Dictionary = {}
var program_error: String = ""
var is_program_running: bool = false
var _mine_tick_elapsed: Dictionary = {}

var is_mining_coal: bool:
	get:
		return active_jobs.has(MINE_COAL_JOB)

var is_mining_iron: bool:
	get:
		return active_jobs.has(MINE_IRON_JOB)

func _process(delta: float) -> void:
	_process_mine_job(MINE_COAL_JOB, delta)
	_process_mine_job(MINE_IRON_JOB, delta)

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
		if command["name"] != ProgramInterpreter.COMMAND_MINE:
			continue

		if command["resource"] == ProgramInterpreter.RESOURCE_COAL:
			next_active_jobs[MINE_COAL_JOB] = true
		elif command["resource"] == ProgramInterpreter.RESOURCE_IRON:
			next_active_jobs[MINE_IRON_JOB] = true

	return next_active_jobs

func _process_mine_job(job_name: String, delta: float) -> void:
	if not active_jobs.has(job_name):
		_mine_tick_elapsed.erase(job_name)
		return

	_mine_tick_elapsed[job_name] = float(_mine_tick_elapsed.get(job_name, 0.0)) + delta
	while _mine_tick_elapsed[job_name] >= 1.0:
		_mine_tick_elapsed[job_name] = float(_mine_tick_elapsed[job_name]) - 1.0
		_apply_mine_tick(job_name)

func _apply_mine_tick(job_name: String) -> void:
	if job_name == MINE_COAL_JOB:
		coal += COAL_PER_SECOND
	elif job_name == MINE_IRON_JOB:
		iron += IRON_PER_SECOND

func _stop_active_jobs() -> void:
	active_jobs.clear()
	running_source_code = ""
	is_program_running = false
	_mine_tick_elapsed.clear()
