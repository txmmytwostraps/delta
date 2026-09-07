extends SimplePage
## Three screens after the first sign-in on this phone: what a day is, the
## Route, and your character. Shown once.

const PANES := [
	{"icon": "today", "title": "A DAY", "text": "Every day has one run: the reviews that are due, a few new problems from where you are on the course, and one extra. Finish all three and the day is full; a full run earns a rest day that covers one missed day later. Anything more is extra and never counts against you."},
	{"icon": "route", "title": "THE ROUTE", "text": "The problems follow the GDQuest course lesson by lesson. Clear a topic and its reviews start the next day, two a day for a week, then further apart. Milestones sit between the topics: a small script built in steps that does something on a stage."},
	{"icon": "profile", "title": "YOUR CHARACTER", "text": "The milestones build one character: the first makes it move, the second gives it health, the later ones take it further. It lives on your Profile, and the same account works on the site, so the phone and the browser always agree."},
]

var _at := 0


func _ready() -> void:
	super()
	back.text = "SKIP"
	back.pressed.connect(_finish)
	render()


func render() -> void:
	var pane: Dictionary = PANES[_at]
	meta.text = "%d OF %d" % [_at + 1, PANES.size()]
	clear_body()
	var mark := Icon.new(pane.icon, Color("#7ef0c2"), 96)
	body.add_child(mark)
	var title := Label.new()
	title.theme_type_variation = &"Heading"
	title.text = pane.title
	body.add_child(title)
	var text := Label.new()
	text.theme_type_variation = &"Prose"
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.text = pane.text
	body.add_child(text)
	var dots := HBoxContainer.new()
	dots.add_theme_constant_override("separation", 12)
	for i in PANES.size():
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(24, 8)
		dot.color = Color("#7ef0c2") if i == _at else Color("#344050")
		dots.add_child(dot)
	body.add_child(dots)
	var last := _at == PANES.size() - 1
	set_action("START" if last else "NEXT ›", func() -> void:
		if last:
			_finish()
		else:
			_at += 1
			render())


func _finish() -> void:
	Store.set_value("first_run_seen", true)
	queue_free()
