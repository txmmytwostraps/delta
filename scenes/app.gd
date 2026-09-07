extends VBoxContainer
## The signed-in shell: one screen at a time, chosen from the bottom tabs,
## and problem pages opened on top of them.

const ProblemScene := preload("res://scenes/problem.tscn")
const EditorScene := preload("res://scenes/editor.tscn")
const JudgeCheckScene := preload("res://scenes/judge_check.tscn")
const FlashcardsScene := preload("res://scenes/flashcards.tscn")
const WeekScene := preload("res://scenes/week.tscn")
const MilestoneScene := preload("res://scenes/milestone.tscn")

@onready var screens: MarginContainer = $Screens
@onready var tab_bar: PanelContainer = $TabBar
@onready var tabs: HBoxContainer = $TabBar/Tabs

## Per problem, what one visit remembers across its pages and runs:
## misses so far, and whether a review's verdict was decided.
var _visits: Dictionary = {}


var _clock := 0.0


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
		button.toggled.connect(func(on: bool) -> void:
			if on:
				_show_screen(button.name))
	show_tab("today")


## Opens a problem over the current screen. Its Back button closes it, and
## so does picking a tab. review: opened from the review slot, so the first
## verdict decides the review.
func open_problem(id: String, review: bool = false) -> void:
	close_pages()
	var page := ProblemScene.instantiate()
	page.problem_id = id
	page.review = review
	page.visit = visit_for(id, review)
	screens.add_child(page)


## The typed editor for a problem, in landscape, over everything.
func open_editor(id: String, review: bool = false) -> void:
	close_pages()
	var page := EditorScene.instantiate()
	page.problem_id = id
	page.review = review
	page.visit = visit_for(id, review)
	screens.add_child(page)


func visit_for(id: String, review: bool) -> Dictionary:
	if not _visits.has(id):
		_visits[id] = {"review": review, "review_recorded": false, "attempt_fails": 0}
	return _visits[id]


## Turns the phone sideways for the editor and back for everything else.
## The canvas follows the window (see Main.fit_canvas), so nothing else
## changes size.
func set_landscape(on: bool) -> void:
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE if on else DisplayServer.SCREEN_PORTRAIT)
	elif OS.has_feature("pc"):
		DisplayServer.window_set_size(Vector2i(640, 360) if on else Vector2i(360, 640))
	tab_bar.visible = not on
	var main := get_tree().get_first_node_in_group("main")
	if main:
		main.fit_canvas()


## Flashcards: today's card review, or one lesson's cards to flip through.
func open_flashcards(review: bool, lesson: int) -> void:
	close_pages()
	var page := FlashcardsScene.instantiate()
	page.review = review
	page.lesson = lesson
	screens.add_child(page)


## A milestone page, at a step (0-based) or the first one not done.
func open_milestone(id: String, step_at: int = -1) -> void:
	close_pages()
	var page := MilestoneScene.instantiate()
	page.milestone_id = id
	page.step_at = step_at
	screens.add_child(page)


## The typed editor for a milestone step, with the stage beside the code.
func open_editor_step(milestone_id: String, step_index: int) -> void:
	close_pages()
	var page := EditorScene.instantiate()
	page.step_milestone = milestone_id
	page.step_index = step_index
	screens.add_child(page)


func open_week() -> void:
	close_pages()
	screens.add_child(WeekScene.instantiate())


func open_judge_check() -> void:
	close_pages()
	screens.add_child(JudgeCheckScene.instantiate())


func close_pages() -> void:
	for page in get_tree().get_nodes_in_group("page"):
		if page.get_parent() == screens:
			screens.remove_child(page)
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
		if screen.is_in_group("page"):
			continue
		screen.visible = screen.name == screen_name
