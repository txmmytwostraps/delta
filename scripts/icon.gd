class_name Icon
extends Control
## A 20-point stroke icon, drawn natively so it is crisp at every density.
## kind: today | route | concepts | profile | gallery | check | lock.

var kind := "today"
var color := Color("#a3adb8")
## The icon's box in canvas units (20 points = 40 units).
var box := 40.0
const STROKE := 3.0


func _init(kind_: String = "today", color_: Color = Color("#a3adb8"), box_: float = 40.0) -> void:
	kind = kind_
	color = color_
	box = box_
	custom_minimum_size = Vector2(box, box)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_color(c: Color) -> void:
	color = c
	queue_redraw()


func _draw() -> void:
	var s := box / 20.0   # the shapes below are drawn on a 20-unit grid
	draw_set_transform(Vector2((size.x - box) / 2.0, (size.y - box) / 2.0), 0.0, Vector2(s, s))
	var w := STROKE / s
	match kind:
		"today":
			# A calendar: a frame with a bar across the top and a tick inside.
			draw_rect(Rect2(2, 3, 16, 15), color, false, w)
			draw_line(Vector2(2, 7), Vector2(18, 7), color, w)
			draw_line(Vector2(6, 1), Vector2(6, 5), color, w)
			draw_line(Vector2(14, 1), Vector2(14, 5), color, w)
			draw_polyline(PackedVector2Array([Vector2(6.5, 12.5), Vector2(9, 15), Vector2(13.5, 10.5)]), color, w)
		"route":
			# A path: two stops joined by a line that bends.
			draw_arc(Vector2(5, 5), 3, 0, TAU, 24, color, w)
			draw_arc(Vector2(15, 15), 3, 0, TAU, 24, color, w)
			draw_polyline(PackedVector2Array([Vector2(5, 8), Vector2(5, 12), Vector2(15, 12), Vector2(15, 12)]), color, w)
		"concepts":
			# Two cards, one behind the other.
			draw_rect(Rect2(2, 6, 12, 12), color, false, w)
			draw_polyline(PackedVector2Array([Vector2(6, 6), Vector2(6, 2), Vector2(18, 2), Vector2(18, 14), Vector2(14, 14)]), color, w)
		"profile":
			# A person: head and shoulders.
			draw_arc(Vector2(10, 6.5), 4, 0, TAU, 24, color, w)
			draw_arc(Vector2(10, 21), 8, PI + 0.35, TAU - 0.35, 24, color, w)
		"gallery":
			draw_rect(Rect2(2, 3, 16, 14), color, false, w)
			draw_polyline(PackedVector2Array([Vector2(3, 15), Vector2(8, 9), Vector2(11, 12), Vector2(13.5, 9.5), Vector2(17, 14)]), color, w)
			draw_arc(Vector2(13.5, 7), 1.6, 0, TAU, 16, color, w)
		"check":
			draw_polyline(PackedVector2Array([Vector2(4, 10.5), Vector2(8.5, 15), Vector2(16.5, 6)]), color, w)
		"lock":
			draw_rect(Rect2(4, 9, 12, 9), color, false, w)
			draw_arc(Vector2(10, 9), 4, PI, TAU, 16, color, w)
		_:
			draw_rect(Rect2(3, 3, 14, 14), color, false, w)
