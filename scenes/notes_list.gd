extends SimplePage
## Notes: every note, unresolved first, each opening its problem; the
## resolved flag synced as on the site.


func _ready() -> void:
	super()
	Notes.changed.connect(render)
	Sync.pulled.connect(render)
	render()


func render() -> void:
	if not is_inside_tree():
		return
	var list := Notes.list()
	var open: int = list.filter(func(n: Dictionary) -> bool: return not bool(n.get("resolved", false))).size()
	meta.text = "%d UNRESOLVED · %d RESOLVED" % [open, list.size() - open] if list.size() > 0 else ""
	clear_body()
	var title := Label.new()
	title.theme_type_variation = &"Heading"
	title.text = "NOTES"
	body.add_child(title)
	if list.is_empty():
		var none := Label.new()
		none.theme_type_variation = &"ProseMuted"
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.text = "No notes yet. Each problem has a note under Other ways."
		body.add_child(none)
		return
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 0)
	body.add_child(rows)
	for n in list:
		rows.add_child(_note(n))


func _note(n: Dictionary) -> Control:
	var id := str(n.problem_id)
	var p := Bank.problem(id)
	var resolved := bool(n.get("resolved", false))
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color("#0b0d10")
	box.border_color = Color("#232b34")
	box.border_width_bottom = 2
	box.content_margin_top = 16
	box.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var title := Label.new()
	title.theme_type_variation = &"Dim" if resolved else &"RowTitle"
	title.text = str(p.get("title", id))
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var when := Label.new()
	when.theme_type_variation = &"Detail"
	when.text = Streak.day_key(str(n.get("updated_at", "")))
	head.add_child(when)
	column.add_child(head)
	var topic := Label.new()
	topic.theme_type_variation = &"Detail"
	topic.text = Bank.topic_title(str(p.get("concept", ""))) if not p.is_empty() else ""
	column.add_child(topic)
	var text := Label.new()
	text.theme_type_variation = &"ProseMuted" if resolved else &"Prose"
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.text = str(n.get("text", "")).strip_edges()
	column.add_child(text)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 24)
	actions.add_child(UI.link("[x] RESOLVED" if resolved else "[ ] RESOLVED", func() -> void: Notes.save(id, {"resolved": not resolved})))
	if not p.is_empty():
		actions.add_child(UI.link("OPEN ›", func() -> void: app().open_problem(id)))
	column.add_child(actions)
	return panel
