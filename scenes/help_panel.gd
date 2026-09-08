class_name HelpPanel
extends VBoxContainer
## Help, the same panel as the site's: a nudge as a bordered button with what
## is left today on the right and its reply under it in a panel with an
## accent bar; the hints as a numbered ladder, each rung saying whether it is
## open, opened, or what unlocks it; and the reference solution as the last
## rung, behind its own lock. Uppercase is kept for the section labels.

## A hint was opened, so the page can follow along.
signal hint_opened(index: int)

var problem_id := ""

var _problem: Dictionary = {}
## The code as it stands and the last judge reply, for the nudge.
var _code: Callable = func() -> String: return ""
var _last: Callable = func() -> Dictionary: return {}
var _with_nudge := true
var _with_solution := true
## Which hints are showing their text, by index.
var _shown: Dictionary = {}
var _solution_shown := false
var _nudge_text := ""
var _nudge_note := ""
var _asking := false


func setup(problem: Dictionary, code_source: Callable, last_reply: Callable, with_nudge := true, with_solution := true) -> void:
	_problem = problem
	problem_id = str(problem.get("id", ""))
	_code = code_source
	_last = last_reply
	_with_nudge = with_nudge
	_with_solution = with_solution
	add_theme_constant_override("separation", 8)
	render()
	if _with_nudge:
		_refresh_count()


## The hints this problem has, in order.
func hints() -> Array:
	var list: Array = _problem.get("hints", [])
	if list.is_empty() and _problem.has("hint"):
		list = [_problem.hint]
	return list


## Whether a hint may open at this topic's level, with the misses so far.
func may_open(i: int) -> bool:
	var level := Scaffold.level_for(str(_problem.get("concept", "")))
	return Scaffold.hint_open(level, i, int(Progress.fails().get(problem_id, 0))) or Progress.is_solved(problem_id)


## The hints opened so far, for the nudge.
func opened_texts() -> Array:
	var out := []
	var list := hints()
	for i in list.size():
		if _shown.get(i, false):
			out.append(str(list[i]))
	return out


## Opens the first hint that may open and is still shut (the verdict's Hint
## button, and the "?" in the bottom bar).
func open_next() -> void:
	var list := hints()
	for i in list.size():
		if may_open(i) and not _shown.get(i, false):
			_toggle_hint(i)
			return


func render() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if _with_nudge:
		_add_nudge()
	var list := hints()
	# A milestone step and a drill have neither hints nor a solution to show.
	if list.is_empty() and not _with_solution:
		return
	add_child(UI.section("hints"))
	var lock := Scaffold.hint_lock_text(Scaffold.level_for(str(_problem.get("concept", ""))))
	for i in list.size():
		var open := may_open(i)
		var shown: bool = open and bool(_shown.get(i, false))
		var state := "opened" if shown else ("open" if open else "locked")
		var right := "opened" if shown else ("open ›" if open else lock)
		var row := UI.help_row("✓" if shown else str(i + 1), "Hint %d" % (i + 1), right, state)
		row.pressed.connect(func() -> void: _toggle_hint(i))
		add_child(row)
		if shown:
			add_child(_body(str(list[i]).replace("`", "")))
	if _with_solution:
		_add_solution()
	if not list.is_empty():
		var level := Scaffold.level_for(str(_problem.get("concept", "")))
		var by_hand := " (set by hand)" if Scaffold.override_for(str(_problem.get("concept", ""))) != "" else ""
		var line := Label.new()
		line.theme_type_variation = &"Detail"
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.text = "Hints are %s for this topic%s. Change that on the Route." % [level, by_hand]
		add_child(line)


## The text under a rung of the ladder, indented past its square.
func _body(text: String) -> Control:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 68)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 16)
	var label := Label.new()
	label.theme_type_variation = &"Prose"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	margin.add_child(label)
	return margin


func _toggle_hint(i: int) -> void:
	if not may_open(i):
		return
	var was: bool = bool(_shown.get(i, false))
	_shown[i] = not was
	if not was:
		Week.log_hint(problem_id, i)
		hint_opened.emit(i)
	render()


# ---- the nudge ----

## The bordered button, what is left today on its right, and the reply under
## it in a panel with an accent bar down its left edge.
func _add_nudge() -> void:
	var button := Button.new()
	button.theme_type_variation = &"Bordered"
	button.custom_minimum_size.y = 88
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.disabled = _asking
	var box := HBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 24
	box.offset_right = -24
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(box)
	var text := Label.new()
	text.text = "? Ask for a nudge"
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(text)
	var note := Label.new()
	note.text = _nudge_note
	note.theme_type_variation = &"Detail"
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(note)
	button.pressed.connect(_ask_nudge)
	add_child(button)
	if _nudge_text == "":
		return
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"Quote"
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	var who := Label.new()
	who.theme_type_variation = &"Dim"
	who.text = "Nudge"
	column.add_child(who)
	var reply := Label.new()
	reply.theme_type_variation = &"Prose"
	reply.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reply.text = _nudge_text
	column.add_child(reply)
	panel.add_child(column)
	add_child(panel)


## "29 left today": the cap counted from the account's nudges.
func _refresh_count() -> void:
	if not Auth.is_signed_in():
		_nudge_note = "sign in to use"
		render()
		return
	var left: int = await Nudge.left_today()
	if is_inside_tree() and left >= 0:
		_nudge_note = "%d left today" % maxi(0, left)
		render()


## The built-in nudge: the problem, the code and the failing checks go to the
## site's function; it points, never answers. Counts as a hint opened.
func _ask_nudge() -> void:
	var why := Nudge.blocked_reason(_problem)
	if why != "":
		_nudge_note = why
		render()
		return
	_asking = true
	_nudge_note = "thinking…"
	render()
	var reply: Dictionary = await Nudge.ask(Nudge.payload(_problem, str(_code.call()), _last.call(), opened_texts()))
	if not is_inside_tree():
		return
	_asking = false
	if reply.ok:
		_nudge_text = str(reply.text)
		_nudge_note = "%d left today" % reply.remaining if reply.remaining >= 0 else ""
	else:
		_nudge_note = str(reply.error)
	render()


# ---- the reference solution ----

func _solution_unlocked() -> bool:
	if Progress.is_solved(problem_id):
		return true
	return int(Progress.fails().get(problem_id, 0)) >= Submission.unlock_after(_problem)


func _add_solution() -> void:
	var unlocked := _solution_unlocked()
	var shown: bool = unlocked and _solution_shown
	var left := Submission.unlock_after(_problem) - int(Progress.fails().get(problem_id, 0))
	var state := "opened" if shown else ("open" if unlocked else "locked")
	# The site says "2 more misses"; a phone row has not the width for it.
	var lock := "locked · %d miss%s" % [maxi(left, 0), "" if left == 1 else "es"]
	var right := "hide" if shown else ("show ›" if unlocked else lock)
	var row := UI.help_row("#", "Reference solution", right, state)
	row.pressed.connect(func() -> void:
		if _solution_unlocked():
			_solution_shown = not _solution_shown
			render())
	add_child(row)
	if not shown:
		return
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.add_child(UI.code_view(str(_problem.get("solution", ""))))
	add_child(margin)
