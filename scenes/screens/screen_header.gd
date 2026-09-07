extends VBoxContainer
## The small accent line and big title at the top of every screen.

@export var eyebrow := "DELTA"
@export var title := "SCREEN"


func _ready() -> void:
	$Eyebrow.text = eyebrow.to_upper()
	$Title.text = title.to_upper()
