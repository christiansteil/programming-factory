extends Node
class_name GameState

var inventory := {
	"coal": 0,
}

func apply_program(source_code: String) -> Dictionary:
	var parse_result := ProgramInterpreter.parse(source_code)
	if not parse_result["is_valid"]:
		return parse_result

	for command in parse_result["commands"]:
		if command.get("type") == "mine":
			var resource: String = command.get("resource", "")
			inventory[resource] = inventory.get(resource, 0) + 1

	return parse_result
