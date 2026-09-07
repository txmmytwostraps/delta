extends MarginContainer
## The concept cards, by lesson: a reference with a search box, a way to
## flip through a lesson's cards, and the day's card review.

@onready var search: LineEdit = $Scroll/Body/Search
@onready var due_button: Button = $Scroll/Body/Due
@onready var due_note: Label = $Scroll/Body/DueNote
@onready var lessons: VBoxContainer = $Scroll/Body/Lessons

var _open: Dictionary = {}   # card id -> expanded


func _ready() -> void:
	search.text_changed.connect(func(_t: String) -> void: render())
	due_button.pressed.connect(func() -> void:
		var app := get_tree().get_first_node_in_group("app")
		if app:
			app.open_flashcards(true, -1))
	Reviews.changed.connect(render)
	Progress.changed.connect(render)
	Sync.pulled.connect(render)
	visibility_changed.connect(func() -> void:
		if visible:
			render())
	render()


func render() -> void:
	if not is_inside_tree():
		return
	var day := Progress.today_key()
	var due := Reviews.cards_due_today(day)
	var n: int = due.pending.size()
	due_button.visible = n > 0
	due_button.text = "REVIEW %d CARD%s DUE TODAY" % [n, "" if n == 1 else "S"]
	due_note.visible = n == 0
	due_note.text = "No cards due today. Cards join the review queue when you solve the first problem of their topic."

	var query := search.text.strip_edges().to_lower()
	var lock := Progress.course_lock()
	_clear(lessons)
	for g in Bank.cards_by_lesson():
		var cards: Array = g.cards.filter(func(c: Dictionary) -> bool: return query == "" or _matches(c, query))
		if cards.is_empty():
			continue
		var section := VBoxContainer.new()
		section.add_theme_constant_override("separation", 12)
		var head := Label.new()
		head.theme_type_variation = &"Small"
		head.text = "LESSON %02d · %s%s" % [int(g.lesson), str(g.titles[0]).to_upper(), " · AHEAD OF YOUR COURSE POSITION" if int(g.lesson) > lock else ""]
		head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		section.add_child(head)
		if query == "":
			var flip := Button.new()
			flip.theme_type_variation = &"Link"
			flip.custom_minimum_size.y = 88
			flip.mouse_filter = Control.MOUSE_FILTER_PASS
			flip.alignment = HORIZONTAL_ALIGNMENT_LEFT
			flip.text = "[~] FLIP THROUGH THESE %d CARDS" % g.cards.size()
			var lesson: int = int(g.lesson)
			flip.pressed.connect(func() -> void:
				var app := get_tree().get_first_node_in_group("app")
				if app:
					app.open_flashcards(false, lesson))
			section.add_child(flip)
		for c in cards:
			section.add_child(_card(c, day))
		lessons.add_child(section)


func _matches(c: Dictionary, query: String) -> bool:
	for key in ["name", "front", "what", "how", "example", "mistake"]:
		if str(c.get(key, "")).to_lower().contains(query):
			return true
	return false


func _state_of(c: Dictionary, day: String) -> String:
	var r: Variant = Reviews.rows().get(Bank.card_id(c), null)
	if r == null:
		return ""
	var reviewed_today: bool = r.get("reviewed_at", null) != null and Streak.day_key(str(r.reviewed_at)) == day
	if str(r.due_on) <= day and not reviewed_today:
		return "due"
	return "relearning" if r.stage == "relearn" else "next " + str(r.due_on)


func _card(c: Dictionary, day: String) -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	var row := UI.row(str(c.name), _state_of(c, day))
	var id: String = str(c.id)
	row.pressed.connect(func() -> void:
		_open[id] = not _open.get(id, false)
		render())
	column.add_child(row)
	if _open.get(id, false):
		var body := PanelContainer.new()
		var inner := VBoxContainer.new()
		inner.add_theme_constant_override("separation", 12)
		body.add_child(inner)
		for pair in [["WHAT IT IS", "what", "Label"], ["HOW YOU WRITE IT", "how", "Code"], ["EXAMPLE", "example", "Muted"], ["THE MISTAKE BEGINNERS MAKE", "mistake", "Muted"]]:
			var k := Label.new()
			k.theme_type_variation = &"Small"
			k.text = pair[0]
			inner.add_child(k)
			var v := Label.new()
			if pair[2] != "Label":
				v.theme_type_variation = StringName(pair[2])
			v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.text = str(c.get(pair[1], "")).replace("`", "").replace("\t", "    ")
			inner.add_child(v)
		column.add_child(body)
	return column


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
