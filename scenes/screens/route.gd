extends VBoxContainer
## The Route, like the site's: the course's lessons in stages along one
## path. "You are here" on top; then each stage with a header (a bar and a
## count), open only when it holds the current lesson unless toggled, and
## remembered. Inside, one node per lesson on a left line: the current
## lesson is the only card (its line, a segment bar, the hints line, Any
## problem · Drill · Request more, Continue); other lessons are rows;
## milestones are amber tiles across the path, dashed until done.

const PathNode := preload("res://scripts/path_node.gd")

@onready var pos_title: Label = $Margin/Scroll/Body/Here/HereRow/PosTitle
@onready var pos_count: Label = $Margin/Scroll/Body/Here/HereRow/PosCount
@onready var bar_host: VBoxContainer = $Margin/Scroll/Body/Here/BarHost
@onready var pos_detail: Label = $Margin/Scroll/Body/Here/DetailRow/PosDetail
@onready var change: Button = $Margin/Scroll/Body/Here/DetailRow/Change
@onready var stages_box: VBoxContainer = $Margin/Scroll/Body/Stages

var _expanded := ""   # a tapped topic other than the current one
var _copied := ""


func _ready() -> void:
	change.pressed.connect(func() -> void: _app().show_tab("profile"))
	Progress.changed.connect(render)
	Settings.changed.connect(render)
	Scaffold.changed.connect(render)
	Sync.pulled.connect(render)
	visibility_changed.connect(func() -> void:
		if visible:
			render())
	render()


func render() -> void:
	if not is_inside_tree():
		return
	var topics := Progress.route_topics()
	var current := Progress.current_topic()
	var total := Bank.problems.size()
	var done: int = Progress.solved().keys().filter(func(id: String) -> bool: return Bank.has_problem(id)).size()
	var milestones := Progress.milestones()
	var ms_done: int = milestones.filter(func(m: Dictionary) -> bool: return m.done).size()

	# You are here: one line with a bar.
	pos_title.text = "L%02d · %s" % [int(current.lesson), current.title] if not current.is_empty() else "—"
	pos_count.text = "%d / %d" % [current.done, current.total] if not current.is_empty() else ""
	_clear(bar_host)
	if not current.is_empty():
		bar_host.add_child(_segbar(current.done, current.total))
	pos_detail.text = "%d / %d problems · %d/%d milestones · course through L%02d" % [done, total, ms_done, milestones.size(), Progress.course_lock()]

	_clear(stages_box)
	var stages: Array = Bank.stages
	if stages.is_empty():
		stages = [{"title": "The course", "from": 1, "to": 99}]
	var cur_stage := 0
	for i in stages.size():
		if not current.is_empty() and int(current.lesson) >= int(stages[i].from) and int(current.lesson) <= int(stages[i].to):
			cur_stage = i
	for i in stages.size():
		stages_box.add_child(_stage(stages[i], i, i == cur_stage, topics, current))


## One stage: its header, and the path when it is open.
func _stage(stage: Dictionary, index: int, is_current: bool, topics: Array, current: Dictionary) -> Control:
	var from := int(stage.from)
	var to := int(stage.to)
	var mine: Array = topics.filter(func(t: Dictionary) -> bool: return int(t.lesson) >= from and int(t.lesson) <= to)
	var total := 0
	var done := 0
	for t in mine:
		total += int(t.total)
		done += int(t.done)
	var locked: bool = from > Progress.course_lock()
	var key := "route.stage-%d" % (index + 1)
	var remembered: Variant = Store.get_value(key, null)
	var open: bool = is_current if remembered == null else bool(remembered)

	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 0)
	# The header: name, range, a bar and the count; tap toggles the stage.
	var head := Button.new()
	head.theme_type_variation = &"Row"
	head.custom_minimum_size.y = 120
	head.mouse_filter = Control.MOUSE_FILTER_PASS
	head.focus_mode = Control.FOCUS_NONE
	var inner := VBoxContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 24
	inner.offset_right = -24
	inner.offset_top = 14
	inner.offset_bottom = -14
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_constant_override("separation", 8)
	head.add_child(inner)
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := Label.new()
	name_label.theme_type_variation = &"RowTitle"
	name_label.text = str(stage.title)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(name_label)
	var range_label := Label.new()
	range_label.theme_type_variation = &"Dim" if locked else &"Muted"
	range_label.text = "L%02d–L%02d · %s" % [from, to, "hide" if open else "show"]
	range_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(range_label)
	inner.add_child(line)
	var count_line := HBoxContainer.new()
	count_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_line.add_theme_constant_override("separation", 12)
	if locked:
		var lock := Label.new()
		lock.theme_type_variation = &"Detail"
		lock.text = "finish L%02d in the course to open" % from
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count_line.add_child(lock)
	else:
		var bar := UI.bar(done, maxi(1, total), 6)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count_line.add_child(bar)
		var count := Label.new()
		count.theme_type_variation = &"Detail"
		count.text = "%d/%d" % [done, total]
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count_line.add_child(count)
	inner.add_child(count_line)
	head.pressed.connect(func() -> void:
		Store.set_value(key, not open)
		render())
	block.add_child(head)
	if not open:
		return block

	# The path: one node per lesson, rows or the card, tiles for milestones.
	var path := VBoxContainer.new()
	path.add_theme_constant_override("separation", 0)
	block.add_child(path)
	var rows := _rows(from, to, topics, current)
	for i in rows.size():
		path.add_child(_row(rows[i], i == 0, i == rows.size() - 1))
	return block


## The stops of one stage, in course order.
func _rows(from: int, to: int, topics: Array, current: Dictionary) -> Array:
	var rows := []
	var lock := Progress.course_lock()
	for lesson in Bank.lessons:
		var n := int(lesson.number)
		if n < from or n > to:
			continue
		var here: Array = topics.filter(func(t: Dictionary) -> bool: return int(t.lesson) == n)
		if here.is_empty():
			rows.append({"kind": "locked" if n > lock else "empty", "title": "L%02d · %s" % [n, lesson.title], "trailing": "no problems yet", "lesson": n})
			continue
		for t in here:
			var marker := Progress.marker_for(t)
			var is_current: bool = not current.is_empty() and t.concept == current.concept
			var kind := "locked" if t.locked else ("current" if is_current else ("done" if marker == "✓" else "todo"))
			var trailing: String = "locked" if t.locked else ("%d/%d ✓" % [t.done, t.total] if marker == "✓" else "%d/%d" % [t.done, t.total])
			rows.append({"kind": kind, "title": "L%02d · %s" % [int(t.lesson), t.title], "trailing": trailing, "concept": t.concept, "topic": t, "current": is_current, "lesson": int(t.lesson)})
			for m in Bank.milestones:
				if m.after == t.concept:
					rows.append({"kind": "tile", "milestone": m, "status": Progress.milestone_status(m), "lesson": int(t.lesson)})
	return rows


func _row(r: Dictionary, first: bool, last: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	var node := PathNode.new()
	node.kind = "empty" if r.kind == "tile" else r.kind
	node.first = first
	node.last = last
	node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(node)
	if r.kind == "tile":
		row.add_child(_tile(r))
		return row

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 0)
	row.add_child(column)
	if r.get("current", false):
		column.add_child(_card(r))
		return row

	var open: bool = r.has("concept") and r.concept == _expanded
	var title_row := UI.list_row("", r.title, r.trailing, false, r.kind == "locked" or r.kind == "empty")
	column.add_child(title_row)
	if r.has("concept") and r.kind != "locked":
		title_row.pressed.connect(func() -> void:
			_expanded = "" if _expanded == r.concept else r.concept
			render())
	if open:
		column.add_child(_topic_actions(r))
	return row


## The current lesson's card: title, its line, a segment bar, the hints
## line, the actions, and Continue.
func _card(r: Dictionary) -> Control:
	var t: Dictionary = r.topic
	var concept: String = r.concept
	var card := PanelContainer.new()
	card.theme_type_variation = &"PanelActive"
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	card.add_child(column)
	var title := Label.new()
	title.theme_type_variation = &"RowTitle"
	title.text = str(t.title)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)
	var line := Label.new()
	line.theme_type_variation = &"Detail"
	line.text = "L%02d · %d/%d · %d to go" % [int(t.lesson), t.done, t.total, t.total - t.done] + (" · " + str(t.note) if t.has("note") else "")
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(line)
	column.add_child(_segbar(t.done, t.total, t.total))
	column.add_child(_hints_line(concept))
	column.add_child(_actions(r))
	var next_id := ""
	for p in t.list:
		if not Progress.is_solved(p.id):
			next_id = p.id
			break
	var go := Button.new()
	go.theme_type_variation = &"Primary"
	go.custom_minimum_size.y = 88
	go.mouse_filter = Control.MOUSE_FILTER_PASS
	go.text = "CONTINUE" if next_id != "" else "CLEARED ›"
	go.pressed.connect(func() -> void:
		if next_id != "":
			_app().open_problem(next_id)
		else:
			_app().open_topic_cleared(concept))
	column.add_child(go)
	var wrap := MarginContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_theme_constant_override("margin_top", 8)
	wrap.add_theme_constant_override("margin_bottom", 8)
	wrap.add_child(card)
	return wrap


## A tapped lesson: its actions under the row.
func _topic_actions(r: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color("#12181f")
	box.border_color = Color("#232b34")
	box.border_width_bottom = 2
	box.content_margin_left = 24
	box.content_margin_right = 24
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	panel.add_child(column)
	column.add_child(_hints_line(r.concept))
	column.add_child(_actions(r))
	return panel


## Hints for this topic: the automatic level, or one set by hand. A tap
## cycles auto → full → reduced → minimal → auto, like the site's selector.
func _hints_line(concept: String) -> Control:
	var st := Scaffold.stats_for(concept)
	var setting := Scaffold.override_for(concept)
	var rate: String = " · %d%% of last %d" % [roundi(float(st.rate) * 100.0), mini(20, int(st.attempts))] if st.rate != null else ""
	var button := UI.link("hints · %s%s" % ["auto (%s)" % Scaffold.auto_level(concept) if setting == "" else setting + " · set by hand", rate], func() -> void:
		var cycle := ["", "full", "reduced", "minimal"]
		Scaffold.set_override(concept, cycle[(cycle.find(setting) + 1) % cycle.size()])
		render())
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return button


func _actions(r: Dictionary) -> Control:
	var t: Dictionary = r.topic
	var concept: String = r.concept
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 24)
	actions.add_theme_constant_override("v_separation", 0)
	actions.add_child(UI.link("ANY PROBLEM", func() -> void: _app().open_topic_problems(concept)))
	if t.list.any(Variants.can_drill):
		actions.add_child(UI.link("DRILL", func() -> void: _app().open_drill(concept)))
	if r.kind == "done":
		actions.add_child(UI.link("CLEARED ›", func() -> void: _app().open_topic_cleared(concept)))
	actions.add_child(UI.link("COPIED" if _copied == concept else "REQUEST MORE", func() -> void:
		DisplayServer.clipboard_set(Requests.prompt_for(t))
		_copied = concept
		render()
		get_tree().create_timer(4.0).timeout.connect(func() -> void:
			if _copied == concept:
				_copied = ""
				render())))
	return actions


## A milestone: an amber tile across the path, dashed until it is done.
func _tile(r: Dictionary) -> Control:
	var m: Dictionary = r.milestone
	var st: Dictionary = r.status
	var planned := bool(m.get("planned", false))
	var tile := PanelContainer.new()
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := StyleBoxFlat.new()
	box.bg_color = Color("#12181f") if planned else Color("#3d3220")
	box.content_margin_left = 24
	box.content_margin_right = 24
	box.content_margin_top = 16
	box.content_margin_bottom = 16
	tile.add_theme_stylebox_override("panel", box)
	var edge := Color("#7ef0c2") if st.done else (Color("#6b7885") if planned else Color("#e2b153"))
	tile.add_child(DashedBox.new(edge, not st.done))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	tile.add_child(column)
	var head := Label.new()
	head.theme_type_variation = &"Accent" if st.done else (&"Dim" if planned else &"Amber")
	head.text = "%sMilestone %d · %s%s" % ["✓ " if st.done else "◆ ", int(m.number), m.title, (" · " + str(m.badge)) if st.done and m.has("badge") else ""]
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(head)
	var uses := Label.new()
	uses.theme_type_variation = &"ProseMuted"
	uses.text = str(m.get("uses", ""))
	uses.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(uses)
	var trail := Label.new()
	trail.theme_type_variation = &"Detail"
	if planned:
		trail.text = "planned"
	elif st.done:
		trail.text = "done %s" % _short(str(st.done_at))
	elif st.unlocked:
		trail.text = "continue · %d/%d steps ›" % [st.steps_done, int(m.steps)] if st.steps_done > 0 else "start ›"
	else:
		trail.text = "after L%02d" % int(r.lesson)
	column.add_child(trail)
	if not planned and st.unlocked and not Bank.milestone_data(str(m.id)).is_empty():
		tile.add_child(UI.tap_area(func() -> void: _app().open_milestone_typed(str(m.id)), 0))
	var wrap := MarginContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_theme_constant_override("margin_top", 8)
	wrap.add_theme_constant_override("margin_bottom", 8)
	wrap.add_child(tile)
	return wrap


## A segment bar: n segments, the done share filled, like the site's.
func _segbar(done: int, total: int, max_segments: int = 12) -> Control:
	var n := mini(maxi(1, total), max_segments)
	var on := roundi(float(done) / float(maxi(1, total)) * n)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.custom_minimum_size.y = 8
	for i in n:
		var seg := ColorRect.new()
		seg.color = Color("#7ef0c2") if i < on else Color("#344050")
		seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(seg)
	return row


func _short(iso: String) -> String:
	var key := Streak.day_key(iso)
	if key.length() < 10:
		return iso
	return "%s.%s" % [key.substr(5, 2), key.substr(8, 2)]


func _app() -> Node:
	return get_tree().get_first_node_in_group("app")


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
