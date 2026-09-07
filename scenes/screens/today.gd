extends MarginContainer
## The day's run: three slots, the problems assigned for today, and ways to
## keep going. Same numbers as the site's Today page.

const DAYS := ["SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"]

@onready var dateline: Label = $Scroll/Body/Dateline
@onready var count: Label = $Scroll/Body/Count
@onready var slots: VBoxContainer = $Scroll/Body/Slots
@onready var done_day: Label = $Scroll/Body/DoneDay
@onready var new_label: Label = $Scroll/Body/NewLabel
@onready var new_list: VBoxContainer = $Scroll/Body/NewList
@onready var keep: VBoxContainer = $Scroll/Body/Keep


func _ready() -> void:
	Progress.changed.connect(render)
	Reviews.changed.connect(render)
	Sync.pulled.connect(render)
	visibility_changed.connect(func() -> void:
		if visible:
			render())
	render()


func render() -> void:
	if not is_inside_tree():
		return
	var now := Time.get_datetime_dict_from_system()
	dateline.text = "// %s %02d.%02d — DAILY RUN" % [DAYS[now.weekday], now.month, now.day]

	var status := Progress.run_status()
	var run: Dictionary = status.run
	count.text = "%d / 3 today" % status.done_count
	done_day.visible = status.all_done

	_clear(slots)
	var active_index := -1
	for i in status.slots.size():
		if not status.slots[i].done:
			active_index = i
			break
	for i in status.slots.size():
		slots.add_child(_slot(status.slots[i], i == active_index))

	_clear(new_list)
	new_label.visible = run.new_ids.size() > 0
	for id in run.new_ids:
		new_list.add_child(_problem_row(id))
	if run.extra_id != null:
		new_list.add_child(_problem_row(run.extra_id, "extra · "))

	_clear(keep)
	var topic := Progress.current_topic()
	var more_id: Variant = null
	if not topic.is_empty() and topic.concept == run.topic:
		for p in topic.list:
			if not Progress.is_solved(p.id) and not run.new_ids.has(p.id) and p.id != run.extra_id:
				more_id = p.id
				break
	if more_id != null:
		keep.add_child(_action("+ MORE %s" % str(run.topic_title).to_upper(), more_id))
	var unsolved: Array = Bank.problems.filter(func(p: Dictionary) -> bool: return not Progress.is_solved(p.id))
	if unsolved.size() > 0:
		keep.add_child(_action("+ RANDOM", unsolved[randi() % unsolved.size()].id))
	if status.keep_going > 0:
		var extra := Label.new()
		extra.theme_type_variation = &"Small"
		extra.text = "%d EXTRA SOLVED TODAY" % status.keep_going
		keep.add_child(extra)


func _slot(slot: Dictionary, active: bool) -> Control:
	var panel := PanelContainer.new()
	if active:
		panel.theme_type_variation = &"PanelActive"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	panel.add_child(row)

	var n := Label.new()
	n.theme_type_variation = &"Small"
	n.text = slot.n
	n.custom_minimum_size.x = 48
	row.add_child(n)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 6)
	row.add_child(column)
	var title := Label.new()
	title.theme_type_variation = &"Heading3"
	title.text = slot.title
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)
	var detail := Label.new()
	detail.theme_type_variation = &"Muted"
	detail.text = slot.detail
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(detail)

	var state := Label.new()
	state.theme_type_variation = &"Accent" if (slot.done or active) else &"Dim"
	if slot.done:
		state.text = "CLEAR"
	elif active:
		state.text = "GO"
	elif slot.has("progress"):
		state.text = "%d / %d" % [slot.progress[0], slot.progress[1]]
	row.add_child(state)

	# A tap on the slot opens its first problem; a drag still scrolls.
	if not slot.done and slot.get("first_id", null) != null:
		var tap := Button.new()
		tap.flat = true
		tap.mouse_filter = Control.MOUSE_FILTER_PASS
		tap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for box_name in ["normal", "hover", "pressed", "focus"]:
			tap.add_theme_stylebox_override(box_name, StyleBoxEmpty.new())
		tap.pressed.connect(func() -> void: _open(slot.first_id, slot.kind == "review"))
		panel.add_child(tap)
	return panel


func _problem_row(id: String, prefix := "") -> Button:
	var p := Bank.problem(id)
	var button := UI.row("%s %s%s" % ["[x]" if Progress.is_solved(id) else "[ ]", prefix, p.get("title", id)])
	button.pressed.connect(func() -> void: _open(id))
	return button


func _action(text: String, id: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size.y = 88
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.text = text
	button.pressed.connect(func() -> void: _open(id))
	return button


func _open(id: String, review: bool = false) -> void:
	var app := get_tree().get_first_node_in_group("app")
	if app:
		app.open_problem(id, review)


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
