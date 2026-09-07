extends VBoxContainer
## Today: the date, the streak, the day's run as three rows (one row once
## it is done), the level bar, and ways to keep going. One button: Start
## run, Continue run, or Keep going once the day is done. Same numbers as
## the site's Today page.

const DAYS := ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
const MONTHS := ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

@onready var dateline: Label = $Margin/Scroll/Body/Dateline
@onready var streak_value: Label = $Margin/Scroll/Body/StreakRow/StreakValue
@onready var streak_label: Label = $Margin/Scroll/Body/StreakRow/StreakColumn/StreakLabel
@onready var week_host: VBoxContainer = $Margin/Scroll/Body/StreakRow/StreakColumn/WeekHost
@onready var slots: VBoxContainer = $Margin/Scroll/Body/RunCard/Slots
@onready var xp_host: VBoxContainer = $Margin/Scroll/Body/XpHost
@onready var keep: VBoxContainer = $Margin/Scroll/Body/Keep
@onready var go: Button = $Bar/BarMargin/Go

var _show_done := false
var _sticky: StickyHeader


func _ready() -> void:
	_sticky = StickyHeader.attach($Margin, $Margin/Scroll)
	go.pressed.connect(_on_go)
	Progress.changed.connect(render)
	Reviews.changed.connect(render)
	Scaffold.changed.connect(render)
	Sync.pulled.connect(render)
	visibility_changed.connect(func() -> void:
		if visible:
			render())
	render()


func render() -> void:
	if not is_inside_tree():
		return
	var now := Time.get_datetime_dict_from_system()
	dateline.text = "%s %d %s" % [DAYS[now.weekday], now.day, MONTHS[now.month - 1]]

	var s := Progress.streak()
	streak_value.text = str(s.streak)
	streak_label.text = "DAY STREAK · BEST %d" % int(s.longest)
	_clear(week_host)
	week_host.add_child(UI.week_row(s.week, s.token))

	var status := Progress.run_status()
	var run: Dictionary = status.run
	_clear(slots)
	if status.all_done:
		var done_row := UI.list_row("✓", "Day done · %d/%d" % [status.done_count, status.slots.size()], "HIDE" if _show_done else "SHOW")
		done_row.pressed.connect(func() -> void:
			_show_done = not _show_done
			render())
		slots.add_child(done_row)
	if not status.all_done or _show_done:
		var active_index := -1
		for i in status.slots.size():
			if not status.slots[i].done:
				active_index = i
				break
		for i in status.slots.size():
			slots.add_child(_slot(status.slots[i], i == active_index))

	_clear(xp_host)
	var x := Progress.xp_info()
	xp_host.add_child(UI.xp_block(x, true))

	_clear(keep)
	var topic := Progress.current_topic()
	if not topic.is_empty():
		var row := UI.list_row("›", "L%02d · %s" % [int(topic.lesson), topic.title], "%d/%d" % [topic.done, topic.total])
		row.pressed.connect(func() -> void: _app().open_topic_problems(topic.concept))
		keep.add_child(row)
		if topic.list.any(Variants.can_drill):
			var drill := UI.list_row("~", "Drill · %s" % topic.title, "fresh numbers")
			drill.pressed.connect(func() -> void: _app().open_drill(topic.concept))
			keep.add_child(drill)
	var cq := Reviews.cards_due_today(run.day)
	var cards_due: int = cq.pending.size()
	if cards_due > 0:
		var cards := UI.list_row("▭", "Concept cards", "%d due" % cards_due)
		cards.pressed.connect(func() -> void: _app().open_flashcards(true, -1))
		keep.add_child(cards)
	elif not topic.is_empty():
		var lesson := int(topic.lesson)
		var n: int = Bank.cards_for_concept(topic.concept).size()
		if n > 0:
			var flip := UI.list_row("▭", "Cards · L%02d" % lesson, "%d to flip" % n)
			flip.pressed.connect(func() -> void: _app().open_flashcards(false, lesson))
			keep.add_child(flip)

	_sticky.set_sections([{"node": $Margin/Scroll/Body/KeepLabel, "title": "KEEP GOING"}])

	var app := _app()
	if status.all_done:
		go.text = "KEEP GOING · L%02d" % int(topic.lesson) if not topic.is_empty() else "KEEP GOING"
	elif status.done_count > 0 or (app and app.run_items.size() > 0 and not app.run_active):
		go.text = "CONTINUE RUN"
	else:
		go.text = "START RUN"


## One stop of the run as a row: its state on the right.
func _slot(slot: Dictionary, active: bool) -> Control:
	var title: String
	var trailing: String
	match slot.kind:
		"review":
			title = "Review"
			trailing = "done" if slot.done else str(slot.title).get_slice(" · ", 1).to_lower()
		"new":
			title = "New · " + str(slot.title).get_slice(" · ", 0).capitalize()
			trailing = "done" if slot.done else "%d / %d" % [slot.progress[0], slot.progress[1]]
		_:
			title = "One more"
			trailing = "done" if slot.done else ""
	var row := UI.list_row("✓" if slot.done else slot.n, title, trailing, active)
	if not slot.done and slot.get("first_id", null) != null:
		row.pressed.connect(func() -> void:
			if slot.first_id == "cards":
				_app().open_flashcards(true, -1)
			else:
				_app().open_problem(slot.first_id, slot.kind == "review"))
	return row


func _on_go() -> void:
	var app := _app()
	if app == null:
		return
	if not app.start_run():
		# The day is done: keep going in the current topic.
		var topic := Progress.current_topic()
		if not topic.is_empty():
			app.open_topic_problems(topic.concept)


func _app() -> Node:
	return get_tree().get_first_node_in_group("app")


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
