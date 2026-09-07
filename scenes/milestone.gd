extends PanelContainer
## A milestone: a script built in steps. The stage on top runs the script as
## it stands; the step's code is below, as lines to order, a bug to fix, or
## typed in the editor. Checks per step; a passing step is stored like a
## solved problem, so the site shows it too.

const OrderMode := preload("res://scenes/modes/order_mode.gd")
const BugMode := preload("res://scenes/modes/bug_mode.gd")
const StagePanel := preload("res://scenes/stage_panel.gd")
const MODES := ["order", "bug"]

var milestone_id := "m1"
## The step to show, 0-based; -1 for the first one not done yet.
var step_at := -1

@onready var back: Button = $Column/TopMargin/TopBar/Back
@onready var meta_label: Label = $Column/TopMargin/TopBar/Meta
@onready var scroll: ScrollContainer = $Column/Scroll
@onready var steps_row: HBoxContainer = $Column/Scroll/Margin/Body/Steps
@onready var banner: Label = $Column/Scroll/Margin/Body/Banner
@onready var lock: Label = $Column/Scroll/Margin/Body/Lock
@onready var stage_host: VBoxContainer = $Column/Scroll/Margin/Body/StageHost
@onready var head: VBoxContainer = $Column/Scroll/Margin/Body/Head
@onready var title: Label = $Column/Scroll/Margin/Body/Head/Title
@onready var prompt: Label = $Column/Scroll/Margin/Body/Head/Prompt
@onready var segments: HBoxContainer = $Column/Scroll/Margin/Body/Modes
@onready var work: VBoxContainer = $Column/Scroll/Margin/Body/Work
@onready var instruction_column: VBoxContainer = $Column/Scroll/Margin/Body/Work/InstructionColumn
@onready var instruction_text: Label = $Column/Scroll/Margin/Body/Work/InstructionColumn/InstructionText
@onready var mode_host: VBoxContainer = $Column/Scroll/Margin/Body/Work/ModeHost
@onready var checks: VBoxContainer = $Column/Scroll/Margin/Body/Checks
@onready var hints: VBoxContainer = $Column/Scroll/Margin/Body/Hints
@onready var docs: VBoxContainer = $Column/Scroll/Margin/Body/Docs
@onready var godot_body: VBoxContainer = $Column/Scroll/Margin/Body/Godot
@onready var bar: PanelContainer = $Column/Bar
@onready var run_button: Button = $Column/Bar/BarMargin/Actions/Run
@onready var reset_button: Button = $Column/Bar/BarMargin/Actions/Reset
@onready var next_button: Button = $Column/Bar/BarMargin/Actions/Next

var meta: Dictionary = {}
var data: Dictionary = {}
var step: Dictionary = {}
var mode := ""
var results := ResultsPanel.new()
var stage: VBoxContainer
var _widget: Control
var _godot := false
var _switching := 0


func _ready() -> void:
	meta = Bank.milestone(milestone_id)
	data = Bank.milestone_data(milestone_id)
	instruction_column.add_child(results)
	results.clear()
	back.pressed.connect(queue_free)
	run_button.pressed.connect(_on_run)
	reset_button.pressed.connect(_on_reset)
	next_button.pressed.connect(func() -> void: show_step(step_at + 1))
	Progress.changed.connect(_render_steps)
	if meta.is_empty() or data.is_empty():
		title.text = str(meta.get("title", "MILESTONE")).to_upper()
		meta_label.text = "MILESTONE %02d · PLANNED" % int(meta.get("number", 0))
		lock.visible = true
		lock.text = "This milestone is planned on the site and not written yet."
		_hide_work()
		return
	meta_label.text = "MILESTONE %02d" % int(meta.number)
	var st := Progress.milestone_status(meta)
	if not st.unlocked:
		title.text = str(meta.title).to_upper()
		meta_label.text = "MILESTONE %02d · LOCKED" % int(meta.number)
		lock.visible = true
		lock.text = "This milestone unlocks when every topic up to %s on the route is cleared: %d topic%s to go." % [Bank.topic_title(str(meta.after)), st.topics_to_go, "" if st.topics_to_go == 1 else "s"]
		_hide_work()
		return
	var scene: Dictionary = data.get("scene", {})
	stage = StagePanel.new()
	stage.setup(str(scene.get("kind", "move")), scene.get("watch", []), current_code)
	stage_host.add_child(stage)
	for m in MODES:
		var b := Button.new()
		b.theme_type_variation = &"Segment"
		b.custom_minimum_size.y = 80
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		b.toggle_mode = true
		b.text = m.to_upper()
		b.pressed.connect(func() -> void:
			if mode != m:
				set_mode(m))
		segments.add_child(b)
	var typed := Button.new()
	typed.theme_type_variation = &"Segment"
	typed.custom_minimum_size.y = 80
	typed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	typed.mouse_filter = Control.MOUSE_FILTER_PASS
	typed.text = "TYPE"
	typed.pressed.connect(func() -> void:
		var app := get_tree().get_first_node_in_group("app")
		if app:
			app.open_editor_step(milestone_id, step_at))
	segments.add_child(typed)
	if step_at < 0:
		step_at = data.steps.size() - 1
		for i in data.steps.size():
			if not Progress.is_solved(data.steps[i].id):
				step_at = i
				break
	show_step(step_at)


func _hide_work() -> void:
	for node in [stage_host, head, segments, work, checks, hints, docs, bar]:
		node.visible = false


func show_step(i: int) -> void:
	_godot = false
	step_at = clampi(i, 0, data.steps.size() - 1)
	step = data.steps[step_at]
	godot_body.visible = false
	for node in [stage_host, head, segments, work, checks]:
		node.visible = true
	meta_label.text = "MILESTONE %02d · STEP %d OF %d" % [int(meta.number), step_at + 1, data.steps.size()]
	title.text = str(step.title).to_upper()
	prompt.text = str(step.prompt).replace("`", "")
	_render_checks()
	_render_hints()
	_render_docs()
	stage.set_buttons(step.get("scene", {}).get("buttons", []))
	_render_steps()
	scroll.scroll_vertical = 0
	segments.get_child(1).disabled = false
	_probe_bug()
	set_mode(mode if mode != "" else default_mode())


## The bug segment goes dim when the judge cannot plant one in this step.
func _probe_bug() -> void:
	var app := get_tree().get_first_node_in_group("app")
	if app == null:
		return
	var current := step
	var found: Dictionary = await app.find_bug(current)
	if is_inside_tree() and step == current and found.is_empty():
		segments.get_child(1).disabled = true


func show_godot() -> void:
	_godot = true
	for node in [stage_host, head, segments, work, checks, hints, docs]:
		node.visible = false
	godot_body.visible = true
	meta_label.text = "MILESTONE %02d · THE SAME BUILD IN GODOT" % int(meta.number)
	for child in godot_body.get_children():
		godot_body.remove_child(child)
		child.queue_free()
	var t := Label.new()
	t.theme_type_variation = &"Heading2"
	t.text = "BUILD IT IN GODOT"
	godot_body.add_child(t)
	var intro := Label.new()
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.text = "Now make the same robot in a real Godot project on your machine. Tick each line as you do it. The list is the whole build: nothing here needs anything you have not written above."
	godot_body.add_child(intro)
	var ticks := MilestoneStep.godot_ticks(milestone_id)
	var lines: Array = data.get("godot", [])
	for i in lines.size():
		var on: bool = i < ticks.size() and bool(ticks[i])
		var row := UI.row("%s %s" % ["✓" if on else "[ ]", str(lines[i]).replace("`", "")], "", on, true)
		row.pressed.connect(func() -> void:
			MilestoneStep.set_godot_tick(meta, data, i, not on)
			show_godot())
		godot_body.add_child(row)
	_render_steps()
	scroll.scroll_vertical = 0


func _render_steps() -> void:
	if not is_inside_tree() or data.is_empty():
		return
	for child in steps_row.get_children():
		steps_row.remove_child(child)
		child.queue_free()
	var st := Progress.milestone_status(meta)
	for i in data.steps.size():
		var done := Progress.is_solved(data.steps[i].id)
		var b := Button.new()
		b.theme_type_variation = &"Segment"
		b.custom_minimum_size.y = 80
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		b.toggle_mode = true
		b.button_pressed = not _godot and i == step_at
		b.text = "%s%d" % ["✓ " if done else "", i + 1]
		b.pressed.connect(func() -> void: show_step(i))
		steps_row.add_child(b)
	var g := Button.new()
	g.theme_type_variation = &"Segment"
	g.custom_minimum_size.y = 80
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.mouse_filter = Control.MOUSE_FILTER_PASS
	g.toggle_mode = true
	g.button_pressed = _godot
	g.text = "%sGODOT" % ("✓ " if st.godot_done else "")
	g.pressed.connect(show_godot)
	steps_row.add_child(g)
	banner.visible = st.done
	if st.done:
		banner.text = "[!] Milestone %d complete · %s" % [int(meta.number), str(meta.get("badge", "done"))]
	next_button.visible = not _godot and not step.is_empty() and Progress.is_solved(step.id) and step_at < data.steps.size() - 1
	bar.visible = not _godot


func _render_checks() -> void:
	for child in checks.get_children():
		checks.remove_child(child)
		child.queue_free()
	var label := Label.new()
	label.theme_type_variation = &"Small"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = "CHECKS · PASS ALL OF THEM TO FINISH THE STEP"
	checks.add_child(label)
	for t in step.get("tests", []):
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 2)
		var n := Label.new()
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		n.text = str(t.get("name", ""))
		column.add_child(n)
		var how := Label.new()
		how.theme_type_variation = &"Detail"
		how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		how.text = MilestoneStep.describe(t)
		column.add_child(how)
		checks.add_child(column)


func _render_hints() -> void:
	for child in hints.get_children():
		hints.remove_child(child)
		child.queue_free()
	var list: Array = step.get("hints", [])
	hints.visible = list.size() > 0
	for i in list.size():
		var button := Button.new()
		button.theme_type_variation = &"Link"
		button.custom_minimum_size.y = 72
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = "[+] HINT %d OF %d" % [i + 1, list.size()]
		var text := Label.new()
		text.theme_type_variation = &"Muted"
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.text = str(list[i]).replace("`", "")
		text.visible = false
		button.pressed.connect(func() -> void:
			text.visible = not text.visible
			button.text = ("[-] " if text.visible else "[+] ") + button.text.substr(4))
		hints.add_child(button)
		hints.add_child(text)


func _render_docs() -> void:
	for child in docs.get_children():
		docs.remove_child(child)
		child.queue_free()
	var list: Array = step.get("docs", [])
	docs.visible = list.size() > 0
	if list.is_empty():
		return
	var label := Label.new()
	label.theme_type_variation = &"Small"
	label.text = "DOCUMENTATION · WHAT THIS STEP USES"
	docs.add_child(label)
	for d in list:
		var row := Label.new()
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.text = "%s — %s" % [str(d.get("name", "")), str(d.get("what", ""))]
		docs.add_child(row)


# ---- modes ----

func default_mode() -> String:
	return MODES[Modes.seeded_order(str(step.id) + ":mode", MODES.size())[0]]


func set_mode(name: String) -> void:
	mode = name
	_switching += 1
	var token := _switching
	for i in MODES.size():
		segments.get_child(i).button_pressed = MODES[i] == name
	results.clear()
	instruction_text.visible = true
	instruction_text.text = "Preparing…"
	for child in mode_host.get_children():
		mode_host.remove_child(child)
		child.queue_free()
	_widget = null
	run_button.disabled = true
	var widget: Control = OrderMode.new() if name == "order" else BugMode.new()
	widget.visible = false
	mode_host.add_child(widget)
	widget.instruction_changed.connect(func() -> void:
		if _widget == widget and not results.visible:
			instruction_text.text = widget.instruction())
	var ok := true
	if name == "order":
		widget.setup(step)
	else:
		var app := get_tree().get_first_node_in_group("app")
		var found: Dictionary = await app.find_bug(step) if app else {}
		if token != _switching or not is_instance_valid(widget):
			return
		ok = not found.is_empty() and await widget.setup(step, found)
	if not is_inside_tree() or token != _switching:
		if is_instance_valid(widget):
			widget.queue_free()
		return
	if not ok:
		# No bug version of this step: the segment goes dim, order it is.
		widget.queue_free()
		segments.get_child(MODES.find(name)).disabled = true
		if name != "order":
			set_mode("order")
		return
	_widget = widget
	widget.visible = true
	widget.changed.connect(func() -> void: stage.refresh())
	instruction_text.text = widget.instruction()
	run_button.disabled = false
	stage.reset()


## The code the current mode has assembled.
func current_code() -> String:
	if _widget and _widget.has_method("code"):
		return _widget.code()
	return str(step.get("starter", ""))


func _on_reset() -> void:
	if _widget and _widget.has_method("reset"):
		_widget.reset()
	results.clear()
	instruction_text.visible = true
	if _widget:
		instruction_text.text = _widget.instruction()
	stage.reset()


func _on_run() -> void:
	if step.is_empty():
		return
	run_button.disabled = true
	instruction_text.visible = false
	results.show_running()
	scroll.scroll_vertical = 0
	var reply: Dictionary = await Grader.run(current_code(), step)
	if not is_inside_tree():
		return
	var outcome := MilestoneStep.record(meta, data, step_at, reply)
	results.show_result(step, reply, outcome, true)
	stage.refresh()
	_render_steps()
	run_button.disabled = false
