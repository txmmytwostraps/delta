extends PanelContainer
## Flashcards: the question, the answer on request, and in review "got it"
## or "not yet", recorded on the card's review schedule like the site does.
## Flipping through a lesson's cards records nothing.

## review: today's due cards, recorded. Otherwise lesson picks the cards.
var review := false
var lesson := -1

@onready var back_button: Button = $Column/TopBand/TopMargin/TopBar/Back
@onready var meta: Label = $Column/TopBand/TopMargin/TopBar/Meta
@onready var scroll: ScrollContainer = $Column/Scroll
@onready var progress_label: Label = $Column/Scroll/Margin/Body/Progress
@onready var front: Label = $Column/Scroll/Margin/Body/Front
@onready var back_side: VBoxContainer = $Column/Scroll/Margin/Body/Back
@onready var name_label: Label = $Column/Scroll/Margin/Body/Back/Name
@onready var what: Label = $Column/Scroll/Margin/Body/Back/What
@onready var how: Label = $Column/Scroll/Margin/Body/Back/HowPanel/How
@onready var example: Label = $Column/Scroll/Margin/Body/Back/Example
@onready var mistake: Label = $Column/Scroll/Margin/Body/Back/Mistake
@onready var summary: Label = $Column/Scroll/Margin/Body/Summary
@onready var reveal: Button = $Column/Bar/BarMargin/Actions/Reveal
@onready var got: Button = $Column/Bar/BarMargin/Actions/Got
@onready var not_yet: Button = $Column/Bar/BarMargin/Actions/NotYet
@onready var next_button: Button = $Column/Bar/BarMargin/Actions/Next
@onready var done_button: Button = $Column/Bar/BarMargin/Actions/Done

var queue: Array = []
var at := 0
var revealed := false
var results := {"pass": 0, "miss": 0}


func _ready() -> void:
	back_button.pressed.connect(queue_free)
	reveal.pressed.connect(func() -> void:
		revealed = true
		render())
	got.pressed.connect(func() -> void: answer(true))
	not_yet.pressed.connect(func() -> void: answer(false))
	next_button.pressed.connect(func() -> void: answer(true))
	done_button.pressed.connect(func() -> void:
		var app := get_tree().get_first_node_in_group("app")
		if app and review and app.run_active and app.run_has("cards"):
			app.run_next("cards")
			return
		queue_free()
		if app:
			app.show_tab("today"))
	back_button.pressed.connect(func() -> void:
		var app := get_tree().get_first_node_in_group("app")
		if app and app.run_active:
			app.leave_run())
	if review:
		for r in Reviews.cards_due_today(Progress.today_key()).pending:
			var c := Bank.card(str(r.problem_id))
			if not c.is_empty():
				queue.append(c)
	else:
		for g in Bank.cards_by_lesson():
			if int(g.lesson) == lesson:
				queue = g.cards
	render()


func render() -> void:
	var finished := at >= queue.size()
	front.visible = not finished
	back_side.visible = not finished and revealed
	summary.visible = finished
	reveal.visible = not finished and not revealed
	got.visible = not finished and revealed and review
	not_yet.visible = not finished and revealed and review
	next_button.visible = not finished and revealed and not review
	done_button.visible = finished
	if finished:
		var nothing := review and queue.is_empty()
		progress_label.text = "NOTHING DUE" if nothing else ("CARDS DONE FOR TODAY" if review else "END OF THE LESSON'S CARDS")
		summary.text = "No concept cards are scheduled for today." if nothing else ("%d got it · %d not yet" % [results.pass, results.miss] if review else "%d cards" % queue.size())
		done_button.text = "BACK TO TODAY" if review else "DONE"
		meta.text = "CONCEPTS · REVIEW" if review else "CONCEPTS · LESSON %02d" % lesson
		return
	var c: Dictionary = queue[at]
	meta.text = ("CONCEPTS · REVIEW · %d OF %d" if review else "CONCEPTS · LESSON " + ("%02d" % lesson) + " · %d OF %d") % [at + 1, queue.size()]
	progress_label.text = "CARD %d OF %d" % [at + 1, queue.size()]
	front.text = str(c.front)
	name_label.text = str(c.name).to_upper()
	what.text = _plain(c.what)
	how.text = str(c.how).replace("\t", "    ")
	example.text = _plain(c.example)
	mistake.text = _plain(c.mistake)
	scroll.scroll_vertical = 0


func answer(passed: bool) -> void:
	if at >= queue.size():
		return
	if review:
		results["pass" if passed else "miss"] += 1
		var card_id := Bank.card_id(queue[at])
		# Logged as an attempt like the site does: "review" on the due day,
		# "review-late" otherwise; decided before the review moves its date.
		var row: Dictionary = Reviews.rows().get(card_id, {})
		var kind := "review" if str(row.get("due_on", "")) == Progress.today_key() else "review-late"
		Sync.insert_attempt(card_id, kind, "pass" if passed else "miss")
		Scaffold.note_attempt(card_id, kind, passed)
		Reviews.record_result(card_id, passed, passed)
	at += 1
	revealed = false
	render()


func _plain(s: Variant) -> String:
	return str(s).replace("`", "")
