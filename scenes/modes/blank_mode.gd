extends VBoxContainer
## Fill in the blank: the reference solution with one token taken out and
## four chips below it, one right. The token is the one the topic is about
## (the comparison for Conditions, the name for Variables, the operator for
## arithmetic, the function name for calls), and the wrong chips come from
## the same rules fix-the-bug uses. Tap a chip to fill the gap, tap it again
## to clear it; Run sends the assembled code through the judge, like Order.

signal changed
signal instruction_changed

const GAP := "__BLANK__"

var _problem: Dictionary = {}
var _spot: Dictionary = {}
var _chips: Array = []
var _correct := -1
var selected := -1


## pool: function names from the same lesson, for the wrong chips.
## Returns false when this problem has no blank worth offering.
func setup(problem: Dictionary, pool: Array = []) -> bool:
	_problem = problem
	var blank := Modes.blank_for(problem, pool)
	if blank.is_empty():
		return false
	_spot = blank.spot
	var choices: Array = blank.chips
	var order := Modes.seeded_order(str(problem.id) + ":blank", choices.size())
	_chips = []
	for k in order:
		_chips.append(choices[k])
	_correct = _chips.find(choices[0])
	render()
	return true


func instruction() -> String:
	if selected < 0:
		return "One piece is missing. Tap the chip that belongs in the gap, then Run."
	return "Tap another chip to change it, or tap the same one to clear it. Then Run."


## The solution with the gap filled by the chosen chip.
func code() -> String:
	var token: String = str(_chips[selected]) if selected >= 0 else ""
	return Modes.blank_code(str(_problem.get("solution", "")), _spot, token)


func reset() -> void:
	selected = -1
	render()
	changed.emit()


func pick(i: int) -> void:
	selected = -1 if i == selected else i
	render()
	changed.emit()


## What the chips say, for the verdict line.
func right_text() -> String:
	return str(_chips[_correct]) if _correct >= 0 else ""


func picked_text() -> String:
	return str(_chips[selected]) if selected >= 0 else ""


func render() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	add_theme_constant_override("separation", 16)
	add_child(_code_block())
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 12)
	chips.add_theme_constant_override("v_separation", 12)
	for i in _chips.size():
		var chip := Button.new()
		chip.theme_type_variation = &"Segment"
		chip.custom_minimum_size = Vector2(120, 88)
		chip.mouse_filter = Control.MOUSE_FILTER_PASS
		chip.toggle_mode = true
		chip.button_pressed = i == selected
		chip.text = str(_chips[i])
		chip.pressed.connect(func() -> void: pick(i))
		chips.add_child(chip)
	add_child(chips)
	instruction_changed.emit()


## The solution in a code block, the blanked token drawn as a chip-shaped
## gap: an empty slot until one is picked, then the chip's text filled in.
func _code_block() -> Control:
	var parts := UI.code_block()
	var lines := Array(str(_problem.get("solution", "")).split("\n"))
	while lines.size() > 1 and str(lines[-1]).strip_edges() == "":
		lines.remove_at(lines.size() - 1)
	for i in lines.size():
		if i != int(_spot.line):
			parts.rows.add_child(UI.code_line(i + 1, str(lines[i])).row)
			continue
		# The line is coloured with a placeholder in the token's place, then
		# the placeholder is swapped for the gap, so the rest keeps its colours.
		var line: String = str(lines[i])
		var with_gap: String = line.substr(0, int(_spot.start)) + GAP + line.substr(int(_spot.end))
		var row := UI.code_line(i + 1, with_gap)
		var filled: String = str(_chips[selected]) if selected >= 0 else ""
		var chip: String = "[bgcolor=#7ef0c2][color=#0b0d10] %s [/color][/bgcolor]" % filled if filled != "" else "[bgcolor=#344050]        [/bgcolor]"
		row.text.text = str(row.text.text).replace(GAP, chip)
		parts.rows.add_child(row.row)
	return parts.block
