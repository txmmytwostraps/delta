extends VBoxContainer
## The signed-in shell: four tabs, one screen at a time, and pages opened
## over them (a problem, the editor, a milestone, the cards …). Also the
## run as one sitting: Start run goes through the reviews, the new problems
## and the extra in sequence, with a bar across the top of each problem.

const ProblemScene := preload("res://scenes/problem.tscn")
const BugMode := preload("res://scenes/modes/bug_mode.gd")
const EditorScene := preload("res://scenes/editor.tscn")
const JudgeCheckScene := preload("res://scenes/judge_check.tscn")
const FlashcardsScene := preload("res://scenes/flashcards.tscn")
const WeekScene := preload("res://scenes/week.tscn")
const MilestoneScene := preload("res://scenes/milestone.tscn")
const TopicClearedScene := preload("res://scenes/topic_cleared.tscn")
const TopicProblemsScene := preload("res://scenes/topic_problems.tscn")
const HintLevelsScene := preload("res://scenes/hint_levels.tscn")
const RunDoneScene := preload("res://scenes/run_done.tscn")
const FirstRunScene := preload("res://scenes/first_run.tscn")
const GalleryScene := preload("res://scenes/gallery.tscn")
const NotesScene := preload("res://scenes/notes_list.tscn")
const StatsScene := preload("res://scenes/stats.tscn")
const AboutScene := preload("res://scenes/about.tscn")

const TAB_ICONS := {"Today": "today", "Route": "route", "Concepts": "concepts", "Profile": "profile"}
const SLIDE := 0.22

@onready var screens: MarginContainer = $Screens
@onready var pages: Control = $Screens/Pages
@onready var tab_bar: PanelContainer = $TabBar
@onready var tabs: HBoxContainer = $TabBar/Tabs

## Per problem, what one visit remembers across its pages and runs:
## misses so far, and whether a review's verdict was decided.
var _visits: Dictionary = {}

## The planted bug per problem or step id, once found: {} when there is
## none. Finding one takes a few judge runs, so it is kept for the session.
var bug_cache: Dictionary = {}

## The run in progress: items in order, and when it started.
var run_active := false
var run_items: Array = []      # [{ "kind": review | cards | new | extra, "id": String }]
var run_started := 0.0
var run_xp_start := 0
var run_minutes_before := 0

## Drill: the topic being drilled and the problems served lately.
var drill_topic := ""
var _drill_served: Array = []

var _clock := 0.0


## The bug for an item, found once. {} when the item has no bug version.
func find_bug(item: Dictionary) -> Dictionary:
	var id := str(item.get("id", ""))
	if not bug_cache.has(id):
		var found: Dictionary = await BugMode.find(item)
		bug_cache[id] = found
	return bug_cache[id]


func _ready() -> void:
	add_to_group("app")
	var ticker := Timer.new()
	ticker.wait_time = 30.0
	ticker.timeout.connect(func() -> void:
		# Only time with the app in front counts, at most a minute per tick.
		if DisplayServer.window_is_focused():
			Progress.add_time(minf(60.0, Time.get_unix_time_from_system() - _clock))
		_clock = Time.get_unix_time_from_system())
	add_child(ticker)
	ticker.start()
	_clock = Time.get_unix_time_from_system()
	for button: Button in tabs.get_children():
		_dress_tab(button)
		button.toggled.connect(func(on: bool) -> void:
			if on:
				_show_screen(button.name))
	show_tab("today")
	if not bool(Store.get_value("first_run_seen", false)):
		open_first_run()


## A tab: its icon above the label; the icon follows the label's colour.
func _dress_tab(button: Button) -> void:
	var icon := Icon.new(TAB_ICONS.get(button.name, "today"), Color("#a3adb8"), 40)
	icon.set_anchors_preset(Control.PRESET_CENTER_TOP)
	icon.position = Vector2(-20, 18)
	button.add_child(icon)
	button.resized.connect(func() -> void: icon.position = Vector2(button.size.x / 2.0 - 20, 18))
	button.add_theme_constant_override("align_to_largest_stylebox", 0)
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Text sits under the icon: push it down with a margin on the stylebox.
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box: StyleBox = button.get_theme_stylebox(state, "Tab").duplicate()
		box.content_margin_top = 64
		box.content_margin_bottom = 14
		button.add_theme_stylebox_override(state, box)
	var recolor := func() -> void:
		icon.set_color(Color("#7ef0c2") if button.button_pressed else Color("#a3adb8"))
	button.toggled.connect(func(_on: bool) -> void: recolor.call())
	recolor.call()


# ---- pages ----

## Puts a page over the current screen. slide: it comes in from the right.
func _open_page(page: Control, slide: bool = false) -> void:
	close_pages()
	pages.add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if slide:
		page.position.x = pages.size.x
		var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(page, "position:x", 0.0, SLIDE)


## Opens a problem over the current screen. Its Back button closes it, and
## so does picking a tab. review: opened from the review slot, so the first
## verdict decides the review.
func open_problem(id: String, review: bool = false, slide: bool = false) -> void:
	var page := ProblemScene.instantiate()
	page.problem_id = id
	page.review = review
	page.visit = visit_for(id, review)
	_open_page(page, slide)


## The typed editor for a problem, in landscape, over everything.
func open_editor(id: String, review: bool = false) -> void:
	var page := EditorScene.instantiate()
	page.problem_id = id
	page.review = review
	page.visit = visit_for(id, review)
	_open_page(page)


## Next › after a solve: the next review in a review run, else the next
## unsolved problem in the topic, or the topic-cleared screen on the last
## one (shown once per topic). With nothing left the page closes: a review
## run ends on Today. Returns whether something was opened.
func open_next(id: String, review: bool) -> bool:
	var next := Submission.next_problem(id, review)
	if next != "":
		open_problem(next, review, true)
		return true
	if not review and topic_cleared_pending(id):
		open_topic_cleared(str(Bank.problem(id).get("concept", "")))
		return true
	close_pages()
	if review:
		show_tab("today")
	return false


## What the Next › button says, decided after the solve is recorded, like
## the site's.
func next_label(id: String, review: bool) -> String:
	if run_active and run_has(id):
		return "NEXT ›" if _run_next_item(id) >= 0 else "RUN DONE ›"
	if review:
		return "NEXT REVIEW ›" if Submission.next_problem(id, true) != "" else "BACK TO TODAY ›"
	if Submission.next_problem(id, false) == "" and topic_cleared_pending(id):
		return "TOPIC CLEARED ›"
	return "NEXT ›"


## The problem's topic is cleared and its screen has not been shown yet.
func topic_cleared_pending(id: String) -> bool:
	var p := Bank.problem(id)
	if p.is_empty():
		return false
	var t := Progress.topic_stats(Bank.topic(str(p.concept)))
	return t.total > 0 and t.done == t.total and not bool(Store.get_value("cleared." + str(p.concept), false))


## The topic-cleared screen: once when the last problem passes, and again
## from the Route.
func open_topic_cleared(concept: String) -> void:
	var page := TopicClearedScene.instantiate()
	page.concept = concept
	_open_page(page, true)


## Any problem: a topic's problems as rows.
func open_topic_problems(concept: String) -> void:
	var page := TopicProblemsScene.instantiate()
	page.concept = concept
	_open_page(page)


func open_hint_levels() -> void:
	_open_page(HintLevelsScene.instantiate())


func open_first_run() -> void:
	_open_page(FirstRunScene.instantiate())


func open_gallery() -> void:
	_open_page(GalleryScene.instantiate())


func open_notes() -> void:
	_open_page(NotesScene.instantiate())


func open_stats() -> void:
	_open_page(StatsScene.instantiate())


func open_about() -> void:
	_open_page(AboutScene.instantiate())


func visit_for(id: String, review: bool) -> Dictionary:
	if not _visits.has(id):
		_visits[id] = {"review": review, "review_recorded": false, "attempt_fails": 0}
	return _visits[id]


## While the editor is open the phone may turn either way; everywhere else
## it stays upright. Nothing is forced: the editor lays itself out for the
## orientation it finds. The canvas follows the window (Main.fit_canvas).
func set_editor_open(on: bool) -> void:
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR if on else DisplayServer.SCREEN_PORTRAIT)
	elif OS.has_feature("pc") and not editor_portrait_on_desktop:
		DisplayServer.window_set_size(Vector2i(640, 360) if on else Vector2i(360, 640))
	tab_bar.visible = not on
	var main := get_tree().get_first_node_in_group("main")
	if main:
		main.fit_canvas()


## Testing aid: keep the desktop window upright for the editor.
var editor_portrait_on_desktop := false


## Flashcards: today's card review, or one lesson's cards to flip through.
func open_flashcards(review: bool, lesson: int) -> void:
	var page := FlashcardsScene.instantiate()
	page.review = review
	page.lesson = lesson
	_open_page(page, run_active)


## A milestone page, at a step (0-based) or the first one not done.
func open_milestone(id: String, step_at: int = -1) -> void:
	var page := MilestoneScene.instantiate()
	page.milestone_id = id
	page.step_at = step_at
	_open_page(page)


## A milestone from the Route: its first step not done, typed (the default
## way into a step), with the stage beside the code.
func open_milestone_typed(id: String) -> void:
	var data := Bank.milestone_data(id)
	var steps: Array = data.get("steps", [])
	for i in steps.size():
		if not Progress.is_solved(str(steps[i].id)):
			open_editor_step(id, i)
			return
	open_milestone(id)


## The typed editor for a milestone step, with the stage beside the code.
func open_editor_step(milestone_id: String, step_index: int) -> void:
	var page := EditorScene.instantiate()
	page.step_milestone = milestone_id
	page.step_index = step_index
	_open_page(page)


func open_week() -> void:
	_open_page(WeekScene.instantiate())


func open_judge_check() -> void:
	_open_page(JudgeCheckScene.instantiate())


func close_pages() -> void:
	for page in get_tree().get_nodes_in_group("page"):
		if page.get_parent() == pages:
			pages.remove_child(page)
			page.queue_free()


## tab_name is the screen's name in any case: "today", "Profile", ...
func show_tab(tab_name: String) -> void:
	for button: Button in tabs.get_children():
		if button.name.to_lower() == tab_name.to_lower():
			button.button_pressed = true
			_show_screen(button.name)
			return


func _show_screen(screen_name: String) -> void:
	close_pages()
	for screen: Control in screens.get_children():
		if screen == pages:
			continue
		screen.visible = screen.name == screen_name


# ---- the run as one sitting ----

## The day's items in order: the reviews (problems, then the cards as one
## stop), the new problems, the extra. Done ones stay in the list so the
## numbering holds ("Run · 2 of 8").
func run_sequence() -> Array:
	var status := Progress.run_status()
	var run: Dictionary = status.run
	var day: String = run.day
	var q := Reviews.due_today(day)
	var items := []
	for r in q.done_today:
		if Bank.has_problem(str(r.problem_id)):
			items.append({"kind": "review", "id": str(r.problem_id), "done": true})
	for r in q.pending:
		if Bank.has_problem(str(r.problem_id)):
			items.append({"kind": "review", "id": str(r.problem_id), "done": false})
	var cq := Reviews.cards_due_today(day)
	if cq.pending.size() + cq.done_today.size() > 0:
		items.append({"kind": "cards", "id": "cards", "done": cq.pending.is_empty()})
	for id in run.new_ids:
		items.append({"kind": "new", "id": str(id), "done": Progress.is_solved(str(id))})
	if run.extra_id != null:
		items.append({"kind": "extra", "id": str(run.extra_id), "done": Progress.is_solved(str(run.extra_id))})
	return items


## "Start run" / "Continue run": opens the first item not done. Returns
## false when the day is done already.
func start_run() -> bool:
	run_items = run_sequence()
	var first := -1
	for i in run_items.size():
		if not run_items[i].done:
			first = i
			break
	if first < 0:
		return false
	run_active = true
	run_started = Time.get_unix_time_from_system()
	run_xp_start = int(Progress.xp_info().xp)
	run_minutes_before = Progress.minutes_today()
	_open_run_item(run_items[first], false)
	return true


func run_has(id: String) -> bool:
	for it in run_items:
		if it.id == id:
			return true
	return false


## "Run · n of N" for the bar across the top of a problem in the run.
func run_position(id: String) -> Dictionary:
	for i in run_items.size():
		if run_items[i].id == id:
			return {"at": i + 1, "total": run_items.size()}
	return {"at": 0, "total": run_items.size()}


## The index of the next item after id that is not done, else -1.
func _run_next_item(id: String) -> int:
	var fresh := run_sequence()
	var from := 0
	for i in run_items.size():
		if run_items[i].id == id:
			from = i + 1
	for i in range(from, fresh.size()):
		if not fresh[i].done:
			return i
	for i in range(0, mini(from, fresh.size())):
		if not fresh[i].done:
			return i
	return -1


## Next › inside the run: the next item, or the Run done screen.
func run_next(id: String) -> void:
	var fresh := run_sequence()
	var i := _run_next_item(id)
	run_items = fresh
	if i < 0:
		run_active = false
		var page := RunDoneScene.instantiate()
		page.minutes = maxi(int((Time.get_unix_time_from_system() - run_started) / 60.0), Progress.minutes_today() - run_minutes_before)
		page.xp = int(Progress.xp_info().xp) - run_xp_start
		_open_page(page, true)
		return
	_open_run_item(run_items[i], true)


func _open_run_item(item: Dictionary, slide: bool) -> void:
	if item.kind == "cards":
		open_flashcards(true, -1)
	else:
		open_problem(item.id, item.kind == "review", slide)


## Back from a problem in the run: the run stops; Today offers Continue run.
func leave_run() -> void:
	run_active = false


# ---- drills ----

## A variant of a problem in the topic, with fresh numbers, in the editor.
## Rolls until the judge accepts one; each Next › rolls another.
func open_drill(concept: String) -> void:
	drill_topic = concept
	var pool: Array = Bank.problems_in(concept).filter(Variants.can_drill)
	if pool.is_empty():
		return
	var recent: Array = _drill_served.slice(maxi(0, _drill_served.size() - mini(3, pool.size() - 1)))
	var fresh: Array = pool.filter(func(p: Dictionary) -> bool: return not recent.has(p.id))
	if fresh.is_empty():
		fresh = pool
	for tries in 6:
		var p: Dictionary = fresh[randi() % fresh.size()]
		var v: Dictionary = await Variants.make(p, int(Time.get_unix_time_from_system()) + tries)
		if not is_inside_tree():
			return
		if not v.is_empty():
			_drill_served.append(p.id)
			var page := EditorScene.instantiate()
			page.problem_id = p.id
			page.variant = v
			_open_page(page, true)
			return


# ---- feel ----

## A short buzz on a pass, two on a miss.
func buzz(passed: bool) -> void:
	if not OS.has_feature("mobile"):
		return
	if passed:
		Input.vibrate_handheld(30)
	else:
		Input.vibrate_handheld(70)
		await get_tree().create_timer(0.16).timeout
		Input.vibrate_handheld(70)
