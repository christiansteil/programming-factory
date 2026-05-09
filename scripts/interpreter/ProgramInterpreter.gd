extends RefCounted

const COMMAND_MINE: String = "mine"
const COMMAND_SMELT: String = "smelt"
const RESOURCE_COAL: String = "coal"
const RESOURCE_IRON: String = "iron"

const TOKEN_IDENTIFIER: String = "identifier"
const TOKEN_STRING: String = "string"
const TOKEN_LEFT_PAREN: String = "left_paren"
const TOKEN_RIGHT_PAREN: String = "right_paren"
const TOKEN_COMMA: String = "comma"

static func parse(source_code: String) -> Dictionary:
	var commands: Array[Dictionary] = []
	var lines: PackedStringArray = source_code.split("\n")

	for line_index in range(lines.size()):
		var source_line: String = String(lines[line_index])
		var trimmed_line: String = source_line.strip_edges()
		if trimmed_line == "" or trimmed_line.begins_with("#"):
			continue

		var token_result: Dictionary = _tokenize_line(source_line, line_index + 1)
		if not token_result["is_valid"]:
			return _error_result(token_result["error"])

		var parse_result: Dictionary = _parse_command(token_result["tokens"], line_index + 1)
		if not parse_result["is_valid"]:
			return _error_result(parse_result["error"])

		commands.append(parse_result["command"])

	return {
		"is_valid": true,
		"error": {},
		"error_message": "",
		"commands": commands,
	}

static func _tokenize_line(source_line: String, line_number: int) -> Dictionary:
	var tokens: Array[Dictionary] = []
	var column: int = 0

	while column < source_line.length():
		var character: String = source_line.substr(column, 1)

		if character == " " or character == "\t":
			column += 1
			continue

		if character == "#":
			break

		if character == "(":
			tokens.append(_token(TOKEN_LEFT_PAREN, character, line_number, column + 1))
			column += 1
			continue

		if character == ")":
			tokens.append(_token(TOKEN_RIGHT_PAREN, character, line_number, column + 1))
			column += 1
			continue

		if character == ",":
			tokens.append(_token(TOKEN_COMMA, character, line_number, column + 1))
			column += 1
			continue

		if character == "\"":
			var string_result: Dictionary = _read_string(source_line, line_number, column)
			if not string_result["is_valid"]:
				return _invalid_result(string_result["error"])
			tokens.append(string_result["token"])
			column = string_result["next_column"]
			continue

		if _is_identifier_start(character):
			var identifier_result: Dictionary = _read_identifier(source_line, line_number, column)
			tokens.append(identifier_result["token"])
			column = identifier_result["next_column"]
			continue

		return _invalid_result(_error(line_number, column + 1, "Unexpected character '%s'" % character))

	return {
		"is_valid": true,
		"tokens": tokens,
		"error": {},
	}

static func _read_string(source_line: String, line_number: int, start_column: int) -> Dictionary:
	var value: String = ""
	var column: int = start_column + 1

	while column < source_line.length():
		var character: String = source_line.substr(column, 1)
		if character == "\"":
			return {
				"is_valid": true,
				"token": _token(TOKEN_STRING, value, line_number, start_column + 1),
				"next_column": column + 1,
				"error": {},
			}
		value += character
		column += 1

	return {
		"is_valid": false,
		"token": {},
		"next_column": column,
		"error": _error(line_number, start_column + 1, "Unterminated string literal"),
	}

static func _read_identifier(source_line: String, line_number: int, start_column: int) -> Dictionary:
	var value: String = ""
	var column: int = start_column

	while column < source_line.length() and _is_identifier_part(source_line.substr(column, 1)):
		value += source_line.substr(column, 1)
		column += 1

	return {
		"token": _token(TOKEN_IDENTIFIER, value, line_number, start_column + 1),
		"next_column": column,
	}

static func _parse_command(tokens: Array[Dictionary], line_number: int) -> Dictionary:
	if tokens.is_empty():
		return {
			"is_valid": true,
			"command": {},
			"error": {},
		}

	var position: int = 0
	if tokens[position]["type"] != TOKEN_IDENTIFIER:
		return _invalid_result(_error_from_token(tokens[position], "Expected command name"))

	var command_name: String = String(tokens[position]["value"])
	position += 1

	if position >= tokens.size() or tokens[position]["type"] != TOKEN_LEFT_PAREN:
		return _invalid_result(_error_after_token(tokens[position - 1], "Expected '(' after command name"))
	position += 1

	if position >= tokens.size() or tokens[position]["type"] != TOKEN_STRING:
		return _invalid_result(_error_at_position(line_number, tokens, position, "Expected string resource name"))

	var resource_name: String = String(tokens[position]["value"])
	position += 1

	if position >= tokens.size() or tokens[position]["type"] != TOKEN_RIGHT_PAREN:
		return _invalid_result(_error_at_position(line_number, tokens, position, "Expected ')' after argument"))
	position += 1

	if position < tokens.size():
		return _invalid_result(_error_from_token(tokens[position], "Unexpected token after command"))

	if not _is_supported_command(command_name):
		return _invalid_result(_error_from_token(tokens[0], "Unknown command '%s'" % command_name))

	if not _is_supported_resource(command_name, resource_name):
		return _invalid_result(_error_from_token(tokens[2], "Unsupported resource '%s' for %s" % [resource_name, command_name]))

	return {
		"is_valid": true,
		"command": {
			"name": command_name,
			"resource": resource_name,
			"line": line_number,
		},
		"error": {},
	}

static func _is_supported_command(command_name: String) -> bool:
	return command_name == COMMAND_MINE or command_name == COMMAND_SMELT

static func _is_supported_resource(command_name: String, resource_name: String) -> bool:
	if command_name == COMMAND_MINE:
		return resource_name == RESOURCE_COAL or resource_name == RESOURCE_IRON
	if command_name == COMMAND_SMELT:
		return resource_name == RESOURCE_IRON
	return false

static func _is_identifier_start(character: String) -> bool:
	return character.to_lower() != character.to_upper() or character == "_"

static func _is_identifier_part(character: String) -> bool:
	return _is_identifier_start(character) or character.is_valid_int()

static func _token(type: String, value: String, line_number: int, column_number: int) -> Dictionary:
	return {
		"type": type,
		"value": value,
		"line": line_number,
		"column": column_number,
	}

static func _invalid_result(error: Dictionary) -> Dictionary:
	return {
		"is_valid": false,
		"tokens": [],
		"command": {},
		"error": error,
	}

static func _error_result(error: Dictionary) -> Dictionary:
	return {
		"is_valid": false,
		"error": error,
		"error_message": "Line %d, column %d: %s" % [error["line"], error["column"], error["message"]],
		"commands": [],
	}

static func _error(line_number: int, column_number: int, message: String) -> Dictionary:
	return {
		"line": line_number,
		"column": column_number,
		"message": message,
	}

static func _error_from_token(token: Dictionary, message: String) -> Dictionary:
	return _error(token["line"], token["column"], message)

static func _error_after_token(token: Dictionary, message: String) -> Dictionary:
	return _error(token["line"], token["column"] + String(token["value"]).length(), message)

static func _error_at_position(line_number: int, tokens: Array[Dictionary], position: int, message: String) -> Dictionary:
	if position < tokens.size():
		return _error_from_token(tokens[position], message)
	if not tokens.is_empty():
		return _error_after_token(tokens[tokens.size() - 1], message)
	return _error(line_number, 1, message)
