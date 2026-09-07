extends VBoxContainer
## The signed-in shell: one screen at a time, chosen from the bottom tabs,
## and problem pages opened on top of them.

const ProblemScene := preload("res://scenes/problem.tscn")

@onready var screens: MarginContainer = $Screens
@onready var tabs: HBoxContainer = $TabBar/Tabs


func _ready() -> void:
	add_to_group("app")
	for button: Button in tabs.get_children():
		button.toggled.connect(func(on: bool) -> void:
			if on:
				_show_screen(button.name))
	show_tab("today")


## Opens a problem over the current screen. Its Back button closes it, and
## so does picking a tab.
func open_problem(id: String) -> void:
	close_pages()
	var page := ProblemScene.instantiate()
	page.problem_id = id
	screens.add_child(page)


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
		screen.visible = screen.name == screen_name
