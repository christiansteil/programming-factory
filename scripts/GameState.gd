extends Node

signal coal_changed(amount: float)
signal iron_changed(amount: float)
signal iron_plates_changed(amount: float)
signal program_changed(is_running: bool, error_message: String)
signal files_changed(file_names: PackedStringArray, current_file_name: String)

const ProgramInterpreter = preload("res://scripts/interpreter/ProgramInterpreter.gd")
const MAIN_FILE_NAME: String = "main"
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

var program_files: Dictionary = {MAIN_FILE_NAME: ""}
var current_file_name: String = MAIN_FILE_NAME
var current_source_code: String = ""
var running_program_files: Dictionary = {}
var running_source_code: String = ""
var active_program_commands: Array = []
var program_error: String = ""
var is_program_running: bool = false
var _program_tick_elapsed: float = 0.0
var _next_command_index: int = 0

var has_pending_program_changes: bool:
	get:
		return is_program_running and not _program_files_match(program_files, running_program_files)

var is_mining_coal: bool:
	get:
		return _has_running_command(ProgramInterpreter.COMMAND_MINE, ProgramInterpreter.RESOURCE_COAL)

var is_mining_iron: bool:
	get:
		return _has_running_command(ProgramInterpreter.COMMAND_MINE, ProgramInterpreter.RESOURCE_IRON)

var is_smelting_iron: bool:
	get:
		return _has_running_command(ProgramInterpreter.COMMAND_SMELT, ProgramInterpreter.RESOURCE_IRON)

func _ready() -> void:
	_emit_files_changed()

func _process(delta: float) -> void:
	if not is_program_running or active_program_commands.is_empty():
		_program_tick_elapsed = 0.0
		return

	_program_tick_elapsed += delta
	while _program_tick_elapsed >= PROGRAM_TICK_SECONDS:
		_program_tick_elapsed -= PROGRAM_TICK_SECONDS
		_execute_next_command_tick()

func get_file_names() -> PackedStringArray:
	var file_names: PackedStringArray = PackedStringArray()
	file_names.append(MAIN_FILE_NAME)

	var other_file_names: Array = program_files.keys()
	other_file_names.sort()
	for file_name_value in other_file_names:
		var file_name: String = String(file_name_value)
		if file_name != MAIN_FILE_NAME:
			file_names.append(file_name)

	return file_names

func set_current_file(file_name: String) -> void:
	if not program_files.has(file_name):
		return
	current_file_name = file_name
	current_source_code = String(program_files[current_file_name])
	_emit_files_changed()

func set_current_source_code(source_code: String) -> void:
	program_files[current_file_name] = source_code
	current_source_code = source_code
	if not is_program_running and program_error != "":
		program_error = ""
		program_changed.emit(false, program_error)

func create_file(requested_file_name: String = "") -> String:
	var base_file_name: String = _normalize_file_name(requested_file_name)
	if base_file_name == "" or base_file_name == MAIN_FILE_NAME:
		base_file_name = "file"

	var new_file_name: String = _get_unique_file_name(base_file_name)
	program_files[new_file_name] = ""
	set_current_file(new_file_name)
	return new_file_name

func rename_current_file(requested_file_name: String) -> bool:
	if current_file_name == MAIN_FILE_NAME:
		program_error = "The main file cannot be renamed."
		program_changed.emit(is_program_running, program_error)
		return false

	var new_file_name: String = _normalize_file_name(requested_file_name)
	if new_file_name == "":
		program_error = "File name cannot be blank."
		program_changed.emit(is_program_running, program_error)
		return false
	if new_file_name == MAIN_FILE_NAME:
		program_error = "Only the first file can be named main."
		program_changed.emit(is_program_running, program_error)
		return false
	if program_files.has(new_file_name) and new_file_name != current_file_name:
		program_error = "File '%s' already exists." % new_file_name
		program_changed.emit(is_program_running, program_error)
		return false

	var old_file_name: String = current_file_name
	var source_code: String = String(program_files[old_file_name])
	program_files.erase(old_file_name)
	program_files[new_file_name] = source_code
	current_file_name = new_file_name
	current_source_code = source_code
	program_error = ""
	_emit_files_changed()
	program_changed.emit(is_program_running, program_error)
	return true

func delete_current_file() -> bool:
	if current_file_name == MAIN_FILE_NAME:
		program_error = "The main file cannot be deleted."
		program_changed.emit(is_program_running, program_error)
		return false

	program_files.erase(current_file_name)
	current_file_name = MAIN_FILE_NAME
	current_source_code = String(program_files[MAIN_FILE_NAME])
	program_error = ""
	_emit_files_changed()
	program_changed.emit(is_program_running, program_error)
	return true

func apply_program() -> void:
	var parse_result: Dictionary = ProgramInterpreter.parse_files(program_files, MAIN_FILE_NAME)
	if not parse_result["is_valid"]:
		_stop_active_program()
		program_error = parse_result["error_message"]
		program_changed.emit(false, program_error)
		return

	running_program_files = program_files.duplicate()
	running_source_code = String(program_files[MAIN_FILE_NAME])
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

func validate_program() -> Dictionary:
	return ProgramInterpreter.parse_files(program_files, MAIN_FILE_NAME)

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
	running_program_files.clear()
	running_source_code = ""
	is_program_running = false
	_program_tick_elapsed = 0.0
	_next_command_index = 0

func _normalize_file_name(file_name: String) -> String:
	return file_name.strip_edges()

func _get_unique_file_name(base_file_name: String) -> String:
	if not program_files.has(base_file_name):
		return base_file_name

	var file_index: int = 1
	var candidate_file_name: String = "%s_%d" % [base_file_name, file_index]
	while program_files.has(candidate_file_name):
		file_index += 1
		candidate_file_name = "%s_%d" % [base_file_name, file_index]
	return candidate_file_name

func _program_files_match(first_files: Dictionary, second_files: Dictionary) -> bool:
	if first_files.size() != second_files.size():
		return false
	for file_name_value in first_files.keys():
		var file_name: String = String(file_name_value)
		if not second_files.has(file_name):
			return false
		if String(first_files[file_name]) != String(second_files[file_name]):
			return false
	return true

func _emit_files_changed() -> void:
	files_changed.emit(get_file_names(), current_file_name)
