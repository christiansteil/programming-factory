extends RefCounted
class_name ProgramInterpreter

const SUPPORTED_COMMANDS := ["mine"]
const SUPPORTED_RESOURCES := ["stone", "wood"]

func interpret(source: String) -> Dictionary:
	var parse_result := parse(source)
	if parse_result.has("error"):
		return parse_result

	var validation_error := validate(parse_result["commands"])
	if not validation_error.is_empty():
		return {
			"commands": parse_result["commands"],
			"error": validation_error,
		}

	return parse_result


func parse(source: String) -> Dictionary:
	var commands: Array[Dictionary] = []
	var lines := source.split("\n", true)

	for line_index in lines.size():
		var line := lines[line_index]
		var line_number := line_index + 1
		var cursor := _skip_whitespace(line, 0)

		if cursor >= line.length():
			continue

		var command_start := cursor
		while cursor < line.length() and _is_identifier_character(_character_at(line, cursor)):
			cursor += 1

		if cursor == command_start:
			return _failure(line_number, cursor + 1, "Expected command name")

		var command_name := line.substr(command_start, cursor - command_start)
		cursor = _skip_whitespace(line, cursor)

		if cursor >= line.length() or _character_at(line, cursor) != "(":
			return _failure(line_number, cursor + 1, "Expected \"(\" after command name")

		cursor += 1
		cursor = _skip_whitespace(line, cursor)

		if cursor >= line.length() or _character_at(line, cursor) != "\"":
			return _failure(line_number, cursor + 1, "Expected string resource name")

		cursor += 1
		var resource_start := cursor
		while cursor < line.length() and _character_at(line, cursor) != "\"":
			cursor += 1

		if cursor >= line.length():
			return _failure(line_number, resource_start, "Expected string resource name")

		var resource_name := line.substr(resource_start, cursor - resource_start)
		cursor += 1
		cursor = _skip_whitespace(line, cursor)

		if cursor >= line.length() or _character_at(line, cursor) != ")":
			return _failure(line_number, cursor + 1, "Expected \")\" after argument")

		commands.append({
			"name": command_name,
			"resource": resource_name,
			"line": line_number,
			"column": command_start + 1,
			"resource_column": resource_start + 1,
		})

	return {
		"commands": commands,
	}


func validate(commands: Array[Dictionary]) -> Dictionary:
	for command in commands:
		if not SUPPORTED_COMMANDS.has(command["name"]):
			return _error(command["line"], command["column"], "Unknown command \"%s\"" % command["name"])

		if not SUPPORTED_RESOURCES.has(command["resource"]):
			return _error(command["line"], command["resource_column"], "Unsupported resource \"%s\"" % command["resource"])

	return {}


func _failure(line: int, column: int, message: String) -> Dictionary:
	return {
		"error": _error(line, column, message),
	}


func _error(line: int, column: int, message: String) -> Dictionary:
	return {
		"line": line,
		"column": column,
		"message": message,
	}


func _skip_whitespace(line: String, cursor: int) -> int:
	while cursor < line.length() and _character_at(line, cursor).strip_edges().is_empty():
		cursor += 1
	return cursor


func _character_at(line: String, cursor: int) -> String:
	return line.substr(cursor, 1)


func _is_identifier_character(character: String) -> bool:
	return character.to_lower() != character.to_upper() or character == "_"
