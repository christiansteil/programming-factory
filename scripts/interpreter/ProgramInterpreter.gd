class_name ProgramInterpreter
extends RefCounted

static func parse(source_code: String) -> Dictionary:
	var result := {
		"is_valid": true,
		"error_message": "",
		"commands": [],
	}

	var lines := source_code.split("\n")
	for line_number in range(lines.size()):
		var line := lines[line_number].strip_edges()

		if line == "" or line.begins_with("#"):
			continue

		if line == "mine(\"coal\")":
			result["commands"].append({
				"type": "mine",
				"resource": "coal",
			})
			continue

		result["is_valid"] = false
		result["error_message"] = "Line %d: unsupported command: %s" % [line_number + 1, line]
		result["commands"] = []
		break

	return result
