extends MarginContainer
## The route: where you are, the course lock, and the vertical path through
## every lesson with the milestones between the topics. Same rules as the
## site's Route page.

const PathNode := preload("res://scripts/path_node.gd")

@onready var pos_title: Label = $Scroll/Body/Position/PositionColumn/PosTitle
@onready var bar_done: ColorRect = $Scroll/Body/Position/PositionColumn/Bar/Done
@onready var bar_left: ColorRect = $Scroll/Body/Position/PositionColumn/Bar/Left
@onready var pos_detail: Label = $Scroll/Body/Position/PositionColumn/PosDetail
@onready var lock_value: Label = $Scroll/Body/Lock/LockRow/LockColumn/LockValue
@onready var less: Button = $Scroll/Body/Lock/LockRow/Less
@onready var more: Button = $Scroll/Body/Lock/LockRow/More
@onready var path: VBoxContainer = $Scroll/Body/Path


func _ready() -> void:
	less.pressed.connect(func() -> void: Progress.set_course_lock(maxi(1, Progress.course_lock() - 1)))
	more.pressed.connect(func() -> void: Progress.set_course_lock(mini(Bank.lessons.size(), Progress.course_lock() + 1)))
	Progress.changed.connect(render)
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
	var next := Progress.next_milestone()

	pos_title.text = "%s · %d/%d" % [str(current.title).to_upper(), current.done, current.total] if not current.is_empty() else "—"
	bar_done.size_flags_stretch_ratio = done
	bar_left.size_flags_stretch_ratio = maxi(1, total - done)
	var detail := "%d / %d problems · %d / %d milestones" % [done, total, ms_done, milestones.size()]
	if not next.is_empty():
		detail += " · next milestone " + ("unlocked" if next.unlocked else "in %d topic%s" % [next.topics_to_go, "" if next.topics_to_go == 1 else "s"])
	pos_detail.text = detail
	lock_value.text = "%d" % Progress.course_lock()

	_clear(path)
	var rows := _rows(topics, current)
	for i in rows.size():
		var r: Dictionary = rows[i]
		path.add_child(_row(r, i == 0, i == rows.size() - 1))


## The stops in course order: every lesson, with its topics, and the
## milestone after a topic when there is one.
func _rows(topics: Array, current: Dictionary) -> Array:
	var rows := []
	var lock := Progress.course_lock()
	for lesson in Bank.lessons:
		var n := int(lesson.number)
		var here: Array = topics.filter(func(t: Dictionary) -> bool: return int(t.lesson) == n)
		if here.is_empty():
			rows.append({"kind": "locked" if n > lock else "todo", "title": str(lesson.title), "sub": "L%02d · no problems yet" % n, "empty": true})
			continue
		for t in here:
			var marker := Progress.marker_for(t)
			var is_current: bool = not current.is_empty() and t.concept == current.concept
			var kind := "locked" if t.locked else ("current" if is_current else ("done" if marker == "[x]" else "todo"))
			var sub: String
			if t.locked:
				sub = "L%02d · locked until you reach it in the course" % int(t.lesson)
			elif marker == "[x]":
				sub = "L%02d · %d/%d · cleared %s" % [int(t.lesson), t.done, t.total, _short(str(t.cleared_at))]
			elif is_current:
				sub = "L%02d · %d/%d · %d to go" % [int(t.lesson), t.done, t.total, t.total - t.done]
			else:
				sub = "L%02d · %d/%d" % [int(t.lesson), t.done, t.total]
			if t.has("note"):
				sub += " · " + str(t.note)
			var next_id: Variant = null
			for p in t.list:
				if not Progress.is_solved(p.id):
					next_id = p.id
					break
			rows.append({"kind": kind, "title": str(t.title), "sub": sub, "concept": t.concept, "next": next_id, "current": is_current})
			for m in Bank.milestones:
				if m.after == t.concept:
					var st := Progress.milestone_status(m)
					var planned := bool(m.get("planned", false))
					var when: String
					if planned:
						when = "unlocks after %s" % t.title
					elif st.done:
						when = "done %s%s" % [_short(str(st.done_at)), " · built in Godot" if st.godot_done else ""]
					elif st.unlocked:
						when = "%d of %d steps done · milestones come to the phone later" % [st.steps_done, int(m.steps)] if st.steps_done > 0 else "unlocked · milestones come to the phone later"
					else:
						when = "unlocks after %s · %d topic%s to go" % [t.title, st.topics_to_go, "" if st.topics_to_go == 1 else "s"]
					rows.append({"kind": "planned" if planned else ("milestone_done" if st.done else "milestone"), "title": "Milestone %02d · %s" % [int(m.number), m.title], "sub": str(m.uses), "when": when, "badge": str(m.get("badge", "")) if st.done else ""})
	return rows


func _row(r: Dictionary, first: bool, last: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var node := PathNode.new()
	node.kind = r.kind
	node.first = first
	node.last = last
	node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(node)

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if r.kind == "current":
		card.theme_type_variation = &"PanelActive"
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	card.add_child(column)

	var title := Label.new()
	title.text = str(r.title).to_upper()
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	match r.kind:
		"locked":
			title.theme_type_variation = &"Dim"
		"milestone", "planned":
			title.theme_type_variation = &"Amber"
		"milestone_done":
			title.theme_type_variation = &"Accent"
		_:
			title.theme_type_variation = &"RowTitle"
	column.add_child(title)
	var sub := Label.new()
	sub.theme_type_variation = &"Detail"
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.text = str(r.sub)
	column.add_child(sub)
	if r.has("when"):
		var when := Label.new()
		when.theme_type_variation = &"Detail"
		when.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		when.text = str(r.when) + (" · " + str(r.badge) if r.get("badge", "") != "" else "")
		column.add_child(when)
	if r.get("current", false) and r.get("next", null) != null:
		var go := Button.new()
		go.theme_type_variation = &"Primary"
		go.custom_minimum_size.y = 88
		go.mouse_filter = Control.MOUSE_FILTER_PASS
		go.text = "CONTINUE"
		go.pressed.connect(func() -> void:
			var app := get_tree().get_first_node_in_group("app")
			if app:
				app.open_problem(r.next))
		column.add_child(go)
	if r.has("concept") and r.kind != "locked":
		card.add_child(UI.tap_area(func() -> void:
			var app := get_tree().get_first_node_in_group("app")
			if app:
				app.show_tab("practice")
				app.screens.get_node("Practice").show_topic(r.concept), 0))

	var spacer := MarginContainer.new()
	spacer.add_theme_constant_override("margin_bottom", 16)
	spacer.add_child(card)
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	return row


func _short(iso: String) -> String:
	var key := Streak.day_key(iso)
	if key.length() < 10:
		return iso
	return "%s.%s" % [key.substr(5, 2), key.substr(8, 2)]


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
