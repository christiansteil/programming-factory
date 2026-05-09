extends RefCounted

const COMMAND_MINE: String = "mine"
const COMMAND_SMELT: String = "smelt"
const COMMAND_CALL: String = "call"
const RESOURCE_COAL: String = "coal"
const RESOURCE_IRON: String = "iron"
const MAIN_FILE_NAME: String = "main"
const FUNCTION_DECLARATION_PREFIX: String = "func "
const FUNCTION_DECLARATION_ALT_PREFIX: String = "function "
const FUNCTION_END: String = "end"
const MAX_CALL_DEPTH: int = 32

static func parse(source_code: String) -> Dictionary:
	return parse_files({MAIN_FILE_NAME: source_code}, MAIN_FILE_NAME)

static func parse_files(program_files: Dictionary, main_file_name: String) -> Dictionary:
	var parse_result: Dictionary = _parse_all_files(program_files, main_file_name)
	if not parse_result["is_valid"]:
		return _error_result(parse_result["error"])

	var compile_result: Dictionary = _compile_main_commands(parse_result["main_commands"], parse_result["functions"])
	if not compile_result["is_valid"]:
		return _error_result(compile_result["error"])

	return {
		"is_valid": true,
		"error": {},
		"error_message": "",
		"commands": compile_result["commands"],
		"functions": parse_result["functions"],
	}

static func _parse_all_files(program_files: Dictionary, main_file_name: String) -> Dictionary:
	var functions: Dictionary = {}
	var main_commands: Array = []
	var file_names: Array = program_files.keys()
	file_names.sort()

	for file_name_value in file_names:
		var file_name: String = String(file_name_value)
		var file_result: Dictionary = _parse_file(file_name, String(program_files[file_name]), functions)
		if not file_result["is_valid"]:
			return file_result
		if file_name == main_file_name:
			main_commands = file_result["top_level_commands"] as Array

	return {
		"is_valid": true,
		"error": {},
		"main_commands": main_commands,
		"functions": functions,
	}

static func _parse_file(file_name: String, source_code: String, functions: Dictionary) -> Dictionary:
	var top_level_commands: Array[Dictionary] = []
	var current_function_name: String = ""
	var current_function_commands: Array[Dictionary] = []
	var current_function_line: int = 0
	var lines: PackedStringArray = source_code.split("\n")

	for line_index in range(lines.size()):
		var line_number: int = line_index + 1
		var source_line: String = String(lines[line_index])
		var trimmed_line: String = source_line.strip_edges()
		if trimmed_line == "" or trimmed_line.begins_with("#"):
			continue

		if current_function_name != "" and trimmed_line == FUNCTION_END:
			functions[current_function_name] = {
				"name": current_function_name,
				"file": file_name,
				"line": current_function_line,
				"commands": current_function_commands,
			}
			current_function_name = ""
			current_function_commands = []
			current_function_line = 0
			continue

		var declaration_name: String = _get_function_declaration_name(trimmed_line)
		if declaration_name != "":
			if current_function_name != "":
				return _invalid_result(_error(file_name, line_number, 1, "Cannot declare a function inside another function"))
			if functions.has(declaration_name):
				return _invalid_result(_error(file_name, line_number, 1, "Function '%s' is already declared" % declaration_name))
			current_function_name = declaration_name
			current_function_commands = []
			current_function_line = line_number
			continue

		var statement_result: Dictionary = _parse_statement(trimmed_line, file_name, line_number)
		if not statement_result["is_valid"]:
			return statement_result

		if current_function_name != "":
			current_function_commands.append(statement_result["command"])
		elif file_name == MAIN_FILE_NAME:
			top_level_commands.append(statement_result["command"])

	if current_function_name != "":
		return _invalid_result(_error(file_name, current_function_line, 1, "Function '%s' is missing end" % current_function_name))

	return {
		"is_valid": true,
		"error": {},
		"top_level_commands": top_level_commands,
	}

static func _parse_statement(trimmed_line: String, file_name: String, line_number: int) -> Dictionary:
	var builtin_result: Dictionary = _parse_builtin_command(trimmed_line, file_name, line_number)
	if builtin_result["is_valid"] or not builtin_result["try_call"]:
		return builtin_result

	return _parse_function_call(trimmed_line, file_name, line_number)

static func _parse_builtin_command(trimmed_line: String, file_name: String, line_number: int) -> Dictionary:
	var open_paren_index: int = trimmed_line.find("(")
	var close_paren_index: int = trimmed_line.rfind(")")
	if open_paren_index == -1 or close_paren_index != trimmed_line.length() - 1:
		return {
			"is_valid": false,
			"try_call": true,
			"error": {},
		}

	var command_name: String = trimmed_line.substr(0, open_paren_index).strip_edges()
	if command_name != COMMAND_MINE and command_name != COMMAND_SMELT:
		return {
			"is_valid": false,
			"try_call": true,
			"error": {},
		}

	var argument_text: String = trimmed_line.substr(open_paren_index + 1, close_paren_index - open_paren_index - 1).strip_edges()
	if not argument_text.begins_with("\"") or not argument_text.ends_with("\""):
		return _invalid_statement_result(_error(file_name, line_number, open_paren_index + 2, "Expected string resource name"))

	var resource_name: String = argument_text.substr(1, argument_text.length() - 2)
	if not _is_supported_resource(command_name, resource_name):
		return _invalid_statement_result(_error(file_name, line_number, open_paren_index + 2, "Unsupported resource '%s' for %s" % [resource_name, command_name]))

	return {
		"is_valid": true,
		"try_call": false,
		"command": {
			"name": command_name,
			"resource": resource_name,
			"file": file_name,
			"line": line_number,
		},
		"error": {},
	}

static func _parse_function_call(trimmed_line: String, file_name: String, line_number: int) -> Dictionary:
	if not trimmed_line.ends_with("()"):
		return _invalid_statement_result(_error(file_name, line_number, 1, "Expected command or function call"))

	var function_name: String = trimmed_line.substr(0, trimmed_line.length() - 2).strip_edges()
	if function_name == "":
		return _invalid_statement_result(_error(file_name, line_number, 1, "Expected function name"))

	return {
		"is_valid": true,
		"try_call": false,
		"command": {
			"name": COMMAND_CALL,
			"function": function_name,
			"file": file_name,
			"line": line_number,
		},
		"error": {},
	}

static func _compile_main_commands(main_commands: Array, functions: Dictionary) -> Dictionary:
	var compiled_commands: Array[Dictionary] = []
	for command_value in main_commands:
		var command: Dictionary = command_value as Dictionary
		var expand_result: Dictionary = _expand_command(command, functions, [], 0)
		if not expand_result["is_valid"]:
			return expand_result
		compiled_commands.append_array(expand_result["commands"])

	return {
		"is_valid": true,
		"error": {},
		"commands": compiled_commands,
	}

static func _expand_command(command: Dictionary, functions: Dictionary, call_stack: Array, call_depth: int) -> Dictionary:
	if command["name"] != COMMAND_CALL:
		return {
			"is_valid": true,
			"error": {},
			"commands": [command],
		}

	if call_depth >= MAX_CALL_DEPTH:
		return _invalid_result(_error(command["file"], command["line"], 1, "Function call depth limit reached"))

	var function_name: String = String(command["function"])
	if not functions.has(function_name):
		return _invalid_result(_error(command["file"], command["line"], 1, "Unknown function '%s'" % function_name))
	if call_stack.has(function_name):
		return _invalid_result(_error(command["file"], command["line"], 1, "Recursive function call '%s' is not supported yet" % function_name))

	var next_call_stack: Array = call_stack.duplicate()
	next_call_stack.append(function_name)

	var function_definition: Dictionary = functions[function_name] as Dictionary
	var function_commands: Array = function_definition["commands"] as Array
	var expanded_commands: Array[Dictionary] = []
	for function_command_value in function_commands:
		var function_command: Dictionary = function_command_value as Dictionary
		var expand_result: Dictionary = _expand_command(function_command, functions, next_call_stack, call_depth + 1)
		if not expand_result["is_valid"]:
			return expand_result
		expanded_commands.append_array(expand_result["commands"])

	return {
		"is_valid": true,
		"error": {},
		"commands": expanded_commands,
	}

static func _get_function_declaration_name(trimmed_line: String) -> String:
	var prefix: String = ""
	if trimmed_line.begins_with(FUNCTION_DECLARATION_PREFIX):
		prefix = FUNCTION_DECLARATION_PREFIX
	elif trimmed_line.begins_with(FUNCTION_DECLARATION_ALT_PREFIX):
		prefix = FUNCTION_DECLARATION_ALT_PREFIX
	else:
		return ""

	if not trimmed_line.ends_with("()"):
		return ""
	return trimmed_line.substr(prefix.length(), trimmed_line.length() - prefix.length() - 2).strip_edges()

static func _is_supported_resource(command_name: String, resource_name: String) -> bool:
	if command_name == COMMAND_MINE:
		return resource_name == RESOURCE_COAL or resource_name == RESOURCE_IRON
	if command_name == COMMAND_SMELT:
		return resource_name == RESOURCE_IRON
	return false

static func _invalid_statement_result(error: Dictionary) -> Dictionary:
	return {
		"is_valid": false,
		"try_call": false,
		"command": {},
		"error": error,
	}

static func _invalid_result(error: Dictionary) -> Dictionary:
	return {
		"is_valid": false,
		"error": error,
	}

static func _error_result(error: Dictionary) -> Dictionary:
	return {
		"is_valid": false,
		"error": error,
		"error_message": "%s line %d, column %d: %s" % [error["file"], error["line"], error["column"], error["message"]],
		"commands": [],
		"functions": {},
	}

static func _error(file_name: String, line_number: int, column_number: int, message: String) -> Dictionary:
	return {
		"file": file_name,
		"line": line_number,
		"column": column_number,
		"message": message,
	}
