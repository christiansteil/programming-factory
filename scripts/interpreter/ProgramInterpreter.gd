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
const FUNCTION_RETURN: String = "return"
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
		var file_result: Dictionary = _parse_file(file_name, String(program_files[file_name]), main_file_name, functions)
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

static func _parse_file(file_name: String, source_code: String, main_file_name: String, functions: Dictionary) -> Dictionary:
	var top_level_commands: Array[Dictionary] = []
	var current_function: Dictionary = {}
	var lines: PackedStringArray = source_code.split("\n")

	for line_index in range(lines.size()):
		var line_number: int = line_index + 1
		var source_line: String = String(lines[line_index])
		var trimmed_line: String = source_line.strip_edges()
		if trimmed_line == "" or trimmed_line.begins_with("#"):
			continue

		if not current_function.is_empty():
			var function_result: Dictionary = _parse_function_body_line(source_line, trimmed_line, file_name, line_number, current_function, functions)
			if not function_result["is_valid"]:
				return function_result
			if function_result["closed"]:
				current_function = {}
			continue

		var declaration_result: Dictionary = _parse_function_declaration(trimmed_line, file_name, line_number)
		if declaration_result["is_valid"]:
			var declaration: Dictionary = declaration_result["function"]
			if functions.has(declaration["name"]):
				return _invalid_result(_error(file_name, line_number, 1, "Function '%s' is already declared" % declaration["name"]))
			current_function = declaration
			continue
		if not declaration_result["try_statement"]:
			return declaration_result

		var statement_result: Dictionary = _parse_statement(trimmed_line, file_name, line_number)
		if not statement_result["is_valid"]:
			return statement_result
		if file_name == main_file_name:
			top_level_commands.append(statement_result["command"])

	if not current_function.is_empty():
		return _invalid_result(_error(file_name, current_function["line"], 1, "Function '%s' is missing return" % current_function["name"]))

	return {
		"is_valid": true,
		"error": {},
		"top_level_commands": top_level_commands,
	}

static func _parse_function_body_line(source_line: String, trimmed_line: String, file_name: String, line_number: int, current_function: Dictionary, functions: Dictionary) -> Dictionary:
	if current_function["uses_colon"]:
		if not source_line.begins_with("\t"):
			return _invalid_result(_error(file_name, line_number, 1, "Function body lines must be indented with one tab"))
		if trimmed_line == FUNCTION_RETURN:
			functions[current_function["name"]] = current_function
			return _closed_function_result()
	else:
		if trimmed_line == FUNCTION_END or trimmed_line == FUNCTION_RETURN:
			functions[current_function["name"]] = current_function
			return _closed_function_result()

	var statement_result: Dictionary = _parse_statement(trimmed_line, file_name, line_number)
	if not statement_result["is_valid"]:
		return statement_result
	current_function["commands"].append(statement_result["command"])
	return {
		"is_valid": true,
		"closed": false,
		"error": {},
	}

static func _parse_function_declaration(trimmed_line: String, file_name: String, line_number: int) -> Dictionary:
	var prefix: String = _get_function_declaration_prefix(trimmed_line)
	if prefix == "":
		return _try_statement_result()

	var uses_colon: bool = trimmed_line.ends_with(":")
	var signature: String = trimmed_line.substr(prefix.length()).strip_edges()
	if uses_colon:
		signature = signature.substr(0, signature.length() - 1).strip_edges()
	elif not signature.ends_with(")"):
		return _invalid_result(_error(file_name, line_number, 1, "Function declaration must end with ':'"))

	var open_paren_index: int = signature.find("(")
	var close_paren_index: int = signature.rfind(")")
	if open_paren_index == -1 or close_paren_index != signature.length() - 1:
		return _invalid_result(_error(file_name, line_number, prefix.length() + 1, "Expected function_name(parameters)"))

	var function_name: String = signature.substr(0, open_paren_index).strip_edges()
	if function_name == "":
		return _invalid_result(_error(file_name, line_number, prefix.length() + 1, "Expected function name"))

	var parameter_text: String = signature.substr(open_paren_index + 1, close_paren_index - open_paren_index - 1)
	var parameters_result: Dictionary = _parse_parameter_names(parameter_text, file_name, line_number, prefix.length() + open_paren_index + 2)
	if not parameters_result["is_valid"]:
		return parameters_result

	return {
		"is_valid": true,
		"try_statement": false,
		"function": {
			"name": function_name,
			"file": file_name,
			"line": line_number,
			"parameters": parameters_result["parameters"],
			"commands": [],
			"uses_colon": uses_colon,
		},
		"error": {},
	}

static func _parse_statement(trimmed_line: String, file_name: String, line_number: int) -> Dictionary:
	var builtin_result: Dictionary = _parse_builtin_command(trimmed_line, file_name, line_number)
	if builtin_result["is_valid"] or not builtin_result["try_call"]:
		return builtin_result

	return _parse_function_call(trimmed_line, file_name, line_number)

static func _parse_builtin_command(trimmed_line: String, file_name: String, line_number: int) -> Dictionary:
	var call_parts_result: Dictionary = _parse_call_parts(trimmed_line, file_name, line_number)
	if not call_parts_result["is_valid"]:
		return call_parts_result

	var command_name: String = call_parts_result["name"]
	if command_name != COMMAND_MINE and command_name != COMMAND_SMELT:
		return _try_call_result()

	var arguments: Array = call_parts_result["arguments"] as Array
	if arguments.size() != 1:
		return _invalid_statement_result(_error(file_name, line_number, 1, "%s expects exactly 1 argument" % command_name))

	var resource_expression: Dictionary = arguments[0] as Dictionary
	if resource_expression["type"] == "literal" and not _is_supported_resource(command_name, resource_expression["value"]):
		return _invalid_statement_result(_error(file_name, line_number, 1, "Unsupported resource '%s' for %s" % [resource_expression["value"], command_name]))

	return {
		"is_valid": true,
		"try_call": false,
		"command": {
			"name": command_name,
			"resource_expression": resource_expression,
			"file": file_name,
			"line": line_number,
		},
		"error": {},
	}

static func _parse_function_call(trimmed_line: String, file_name: String, line_number: int) -> Dictionary:
	var call_parts_result: Dictionary = _parse_call_parts(trimmed_line, file_name, line_number)
	if not call_parts_result["is_valid"]:
		return call_parts_result

	return {
		"is_valid": true,
		"try_call": false,
		"command": {
			"name": COMMAND_CALL,
			"function": call_parts_result["name"],
			"arguments": call_parts_result["arguments"],
			"file": file_name,
			"line": line_number,
		},
		"error": {},
	}

static func _parse_call_parts(trimmed_line: String, file_name: String, line_number: int) -> Dictionary:
	var open_paren_index: int = trimmed_line.find("(")
	var close_paren_index: int = trimmed_line.rfind(")")
	if open_paren_index == -1 or close_paren_index != trimmed_line.length() - 1:
		return _invalid_statement_result(_error(file_name, line_number, 1, "Expected command or function call"))

	var call_name: String = trimmed_line.substr(0, open_paren_index).strip_edges()
	if call_name == "":
		return _invalid_statement_result(_error(file_name, line_number, 1, "Expected function name"))

	var argument_text: String = trimmed_line.substr(open_paren_index + 1, close_paren_index - open_paren_index - 1).strip_edges()
	var arguments_result: Dictionary = _parse_argument_expressions(argument_text, file_name, line_number, open_paren_index + 2)
	if not arguments_result["is_valid"]:
		return arguments_result

	return {
		"is_valid": true,
		"try_call": false,
		"name": call_name,
		"arguments": arguments_result["arguments"],
		"error": {},
	}

static func _compile_main_commands(main_commands: Array, functions: Dictionary) -> Dictionary:
	var compiled_commands: Array[Dictionary] = []
	for command_value in main_commands:
		var command: Dictionary = command_value as Dictionary
		var expand_result: Dictionary = _expand_command(command, functions, [], {}, 0)
		if not expand_result["is_valid"]:
			return expand_result
		compiled_commands.append_array(expand_result["commands"])

	return {
		"is_valid": true,
		"error": {},
		"commands": compiled_commands,
	}

static func _expand_command(command: Dictionary, functions: Dictionary, call_stack: Array, variables: Dictionary, call_depth: int) -> Dictionary:
	if command["name"] != COMMAND_CALL:
		return _expand_builtin_command(command, variables)

	if call_depth >= MAX_CALL_DEPTH:
		return _invalid_result(_error(String(command["file"]), int(command["line"]), 1, "Function call depth limit reached"))

	var function_name: String = String(command["function"])
	if not functions.has(function_name):
		return _invalid_result(_error(String(command["file"]), int(command["line"]), 1, "Unknown function '%s'" % function_name))
	if call_stack.has(function_name):
		return _invalid_result(_error(String(command["file"]), int(command["line"]), 1, "Recursive function call '%s' is not supported yet" % function_name))

	var function_definition: Dictionary = functions[function_name] as Dictionary
	var parameters: Array = function_definition["parameters"] as Array
	var call_arguments: Array = command["arguments"] as Array
	if call_arguments.size() != parameters.size():
		return _invalid_result(_error(String(command["file"]), int(command["line"]), 1, "Function '%s' expects %d argument(s)" % [function_name, parameters.size()]))

	var function_variables: Dictionary = {}
	for argument_index in range(parameters.size()):
		var argument_expression: Dictionary = call_arguments[argument_index] as Dictionary
		var resolved_argument: Dictionary = _resolve_expression(argument_expression, variables, String(command["file"]), int(command["line"]))
		if not resolved_argument["is_valid"]:
			return resolved_argument
		function_variables[parameters[argument_index]] = resolved_argument["value"]

	var next_call_stack: Array = call_stack.duplicate()
	next_call_stack.append(function_name)

	var function_commands: Array = function_definition["commands"] as Array
	var expanded_commands: Array[Dictionary] = []
	for function_command_value in function_commands:
		var function_command: Dictionary = function_command_value as Dictionary
		var expand_result: Dictionary = _expand_command(function_command, functions, next_call_stack, function_variables, call_depth + 1)
		if not expand_result["is_valid"]:
			return expand_result
		expanded_commands.append_array(expand_result["commands"])

	return {
		"is_valid": true,
		"error": {},
		"commands": expanded_commands,
	}

static func _expand_builtin_command(command: Dictionary, variables: Dictionary) -> Dictionary:
	var resource_expression: Dictionary = command["resource_expression"] as Dictionary
	var resolved_resource: Dictionary = _resolve_expression(resource_expression, variables, String(command["file"]), int(command["line"]))
	if not resolved_resource["is_valid"]:
		return resolved_resource

	var resource_name: String = String(resolved_resource["value"])
	if not _is_supported_resource(String(command["name"]), resource_name):
		return _invalid_result(_error(String(command["file"]), int(command["line"]), 1, "Unsupported resource '%s' for %s" % [resource_name, String(command["name"])]))

	return {
		"is_valid": true,
		"error": {},
		"commands": [{
			"name": command["name"],
			"resource": resource_name,
			"file": command["file"],
			"line": command["line"],
		}],
	}

static func _resolve_expression(expression: Dictionary, variables: Dictionary, file_name: String, line_number: int) -> Dictionary:
	if expression["type"] == "literal":
		return {
			"is_valid": true,
			"value": expression["value"],
			"error": {},
		}

	var variable_name: String = String(expression["value"])
	if not variables.has(variable_name):
		return _invalid_result(_error(file_name, line_number, 1, "Unknown variable '%s'" % variable_name))
	return {
		"is_valid": true,
		"value": variables[variable_name],
		"error": {},
	}

static func _parse_parameter_names(parameter_text: String, file_name: String, line_number: int, column_number: int) -> Dictionary:
	var parameters: Array[String] = []
	if parameter_text.strip_edges() == "":
		return {
			"is_valid": true,
			"parameters": parameters,
			"error": {},
		}

	var parts: PackedStringArray = parameter_text.split(",")
	for part in parts:
		var parameter_name: String = String(part).strip_edges()
		if parameter_name == "":
			return _invalid_result(_error(file_name, line_number, column_number, "Parameter name cannot be blank"))
		if parameters.has(parameter_name):
			return _invalid_result(_error(file_name, line_number, column_number, "Parameter '%s' is already declared" % parameter_name))
		parameters.append(parameter_name)

	return {
		"is_valid": true,
		"parameters": parameters,
		"error": {},
	}

static func _parse_argument_expressions(argument_text: String, file_name: String, line_number: int, column_number: int) -> Dictionary:
	var arguments: Array[Dictionary] = []
	if argument_text.strip_edges() == "":
		return {
			"is_valid": true,
			"arguments": arguments,
			"error": {},
		}

	var parts: PackedStringArray = argument_text.split(",")
	for part in parts:
		var argument_value: String = String(part).strip_edges()
		if argument_value == "":
			return _invalid_result(_error(file_name, line_number, column_number, "Argument cannot be blank"))
		arguments.append(_expression(argument_value))

	return {
		"is_valid": true,
		"arguments": arguments,
		"error": {},
	}

static func _expression(argument_value: String) -> Dictionary:
	if argument_value.begins_with("\"") and argument_value.ends_with("\"") and argument_value.length() >= 2:
		return {
			"type": "literal",
			"value": argument_value.substr(1, argument_value.length() - 2),
		}
	return {
		"type": "variable",
		"value": argument_value,
	}

static func _get_function_declaration_prefix(trimmed_line: String) -> String:
	if trimmed_line.begins_with(FUNCTION_DECLARATION_PREFIX):
		return FUNCTION_DECLARATION_PREFIX
	if trimmed_line.begins_with(FUNCTION_DECLARATION_ALT_PREFIX):
		return FUNCTION_DECLARATION_ALT_PREFIX
	return ""

static func _is_supported_resource(command_name: String, resource_name: String) -> bool:
	if command_name == COMMAND_MINE:
		return resource_name == RESOURCE_COAL or resource_name == RESOURCE_IRON
	if command_name == COMMAND_SMELT:
		return resource_name == RESOURCE_IRON
	return false

static func _try_statement_result() -> Dictionary:
	return {
		"is_valid": false,
		"try_statement": true,
		"error": {},
	}

static func _try_call_result() -> Dictionary:
	return {
		"is_valid": false,
		"try_call": true,
		"error": {},
	}

static func _closed_function_result() -> Dictionary:
	return {
		"is_valid": true,
		"closed": true,
		"error": {},
	}

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
