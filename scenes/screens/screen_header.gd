extends HBoxContainer
## The title at the top of a tab: the tab's icon beside the screen title.
## Under it, screens put what they need (Today puts the date).

@export var title := "SCREEN"
@export var icon := "today"


func _ready() -> void:
	add_theme_constant_override("separation", 16)
	var mark := Icon.new(icon, Color("#7ef0c2"), 40)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(mark)
	move_child(mark, 0)
	$Title.text = title.to_upper()
