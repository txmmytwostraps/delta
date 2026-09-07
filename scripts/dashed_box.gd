class_name DashedBox
extends Control
## A dashed border around whatever it is laid over: a milestone tile on the
## route until the milestone is done.

var color := Color("#e2b153")
var dashed := true


func _init(color_: Color = Color("#e2b153"), dashed_: bool = true) -> void:
	color = color_
	dashed = dashed_
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var r := Rect2(Vector2(1, 1), size - Vector2(2, 2))
	if not dashed:
		draw_rect(r, color, false, 2.0)
		return
	var corners := [r.position, r.position + Vector2(r.size.x, 0), r.end, r.position + Vector2(0, r.size.y)]
	for i in 4:
		draw_dashed_line(corners[i], corners[(i + 1) % 4], color, 2.0, 10.0)
