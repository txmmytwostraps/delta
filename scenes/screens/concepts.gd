extends VBoxContainer
## The concept cards: a search box, one row per lesson with its card count
## (tap to open the lesson's cards as chips and flip through them), the
## lessons past the course position as one locked row, and the day's card
## review as the button.

@onready var search: LineEdit = $Margin/Scroll/Body/Search
@onready var lessons: VBoxContainer = $Margin/Scroll/Body/Lessons
@onready var bar: PanelContainer = $Bar
@onready var go: Button = $Bar/BarMargin/Go

var _open_lesson := -1
var _open_card := ""


func _ready() -> void:
	search.text_changed.connect(func(_t: String) -> void: render())
	go.pressed.connect(func() -> void: _app().open_flashcards(true, -1))
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
	bar.visible = n > 0
	go.text = "REVIEW %d CARD%s DUE" % [n, "" if n == 1 else "S"]

	var query := search.text.strip_edges().to_lower()
	var lock := Progress.course_lock()
	_clear(lessons)
	if query != "":
		var hits := 0
		for g in Bank.cards_by_lesson():
			for c in g.cards:
				if _matches(c, query):
					hits += 1
					lessons.add_child(_card_row(c, day, "L%02d" % int(g.lesson)))
		if hits == 0:
			var none := Label.new()
			none.theme_type_variation = &"Muted"
			none.text = "No card matches."
			lessons.add_child(none)
		return
	var locked := 0
	for g in Bank.cards_by_lesson():
		var lesson := int(g.lesson)
		if lesson > lock:
			locked += 1
			continue
		var open := lesson == _open_lesson
		var row := UI.list_row("✓" if _all_reviewed(g.cards, day) else "", "L%02d · %s" % [lesson, str(g.titles[0])], "%d card%s" % [g.cards.size(), "" if g.cards.size() == 1 else "s"], open)
		row.pressed.connect(func() -> void:
			_open_lesson = -1 if open else lesson
			_open_card = ""
			render())
		lessons.add_child(row)
		if open:
			lessons.add_child(_lesson_body(g, day))
	if locked > 0:
		lessons.add_child(UI.list_row("#", "%d lesson%s past your course position" % [locked, "" if locked == 1 else "s"], "L%02d+" % (lock + 1), false, true))


## The open lesson: its cards as chips, the chosen card's detail, and the
## button to flip through them.
func _lesson_body(g: Dictionary, day: String) -> Control:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color("#12181f")
	box.border_color = Color("#232b34")
	box.border_width_bottom = 2
	box.content_margin_left = 24
	box.content_margin_right = 24
	box.content_margin_top = 16
	box.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 8)
	chips.add_theme_constant_override("v_separation", 8)
	for c in g.cards:
		var id := str(c.id)
		var chip := Button.new()
		chip.theme_type_variation = &"Segment"
		chip.custom_minimum_size.y = 64
		chip.mouse_filter = Control.MOUSE_FILTER_PASS
		chip.toggle_mode = true
		chip.button_pressed = id == _open_card
		var state := _state_of(c, day)
		chip.text = str(c.name).to_upper() + (" · DUE" if state == "due" else "")
		chip.pressed.connect(func() -> void:
			_open_card = "" if _open_card == id else id
			render())
		chips.add_child(chip)
	column.add_child(chips)
	for c in g.cards:
		if str(c.id) == _open_card:
			column.add_child(_card_detail(c))
	var flip := Button.new()
	flip.custom_minimum_size.y = 88
	flip.mouse_filter = Control.MOUSE_FILTER_PASS
	flip.text = "FLIP THROUGH %d" % g.cards.size()
	var lesson := int(g.lesson)
	flip.pressed.connect(func() -> void: _app().open_flashcards(false, lesson))
	column.add_child(flip)
	return panel


## A search hit: the card as a row that opens its detail.
func _card_row(c: Dictionary, day: String, lesson: String) -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	var id := str(c.id)
	var row := UI.list_row("", "%s · %s" % [lesson, str(c.name)], _state_of(c, day), id == _open_card)
	row.pressed.connect(func() -> void:
		_open_card = "" if _open_card == id else id
		render())
	column.add_child(row)
	if id == _open_card:
		var body := PanelContainer.new()
		body.add_child(_card_detail(c))
		column.add_child(body)
	return column


func _card_detail(c: Dictionary) -> Control:
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	for pair in [["What it is", "what", "Prose"], ["How you write it", "how", "Code"], ["Example", "example", "ProseMuted"], ["The mistake beginners make", "mistake", "ProseMuted"]]:
		var k := Label.new()
		k.theme_type_variation = &"Detail"
		k.text = pair[0]
		inner.add_child(k)
		var v := Label.new()
		v.theme_type_variation = StringName(pair[2])
		v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.text = str(c.get(pair[1], "")).replace("`", "").replace("\t", "    ")
		inner.add_child(v)
	return inner


func _all_reviewed(cards: Array, day: String) -> bool:
	if cards.is_empty():
		return false
	for c in cards:
		var r: Variant = Reviews.rows().get(Bank.card_id(c), null)
		if r == null or r.get("reviewed_at", null) == null:
			return false
	return true


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


func _app() -> Node:
	return get_tree().get_first_node_in_group("app")


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
