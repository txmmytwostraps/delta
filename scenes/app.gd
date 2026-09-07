extends VBoxContainer
## The signed-in shell: one screen at a time, chosen from the bottom tabs.

@onready var screens: MarginContainer = $Screens
@onready var tabs: HBoxContainer = $TabBar/Tabs


func _ready() -> void:
	for button: Button in tabs.get_children():
		button.toggled.connect(func(on: bool) -> void:
			if on:
				_show_screen(button.name))
	show_tab("today")


## tab_name is the screen's name in any case: "today", "Profile", ...
func show_tab(tab_name: String) -> void:
	for button: Button in tabs.get_children():
		if button.name.to_lower() == tab_name.to_lower():
			button.button_pressed = true
			_show_screen(button.name)
			return


func _show_screen(screen_name: String) -> void:
	for screen: Control in screens.get_children():
		screen.visible = screen.name == screen_name
