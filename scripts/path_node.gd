extends Control
## One stop on the route's vertical path: the line running through, and a
## node whose look says what the stop is.

## todo | current | done | locked | milestone | milestone_done | planned
var kind := "todo"
var first := false
var last := false

const LINE := Color("#2a323b")
const ACCENT := Color("#7ef0c2")
const DIM := Color("#4e5a66")
const AMBER := Color("#e2b153")
const BG := Color("#0b0d10")


func _init() -> void:
	custom_minimum_size = Vector2(56, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var x := size.x / 2.0
	var y := size.y / 2.0
	var top := y if first else 0.0
	var bottom := y if last else size.y
	draw_line(Vector2(x, top), Vector2(x, bottom), LINE, 2.0)
	var r := 12.0
	match kind:
		"done":
			draw_rect(Rect2(x - r, y - r, 2 * r, 2 * r), ACCENT)
		"current":
			draw_rect(Rect2(x - r, y - r, 2 * r, 2 * r), BG)
			draw_rect(Rect2(x - r, y - r, 2 * r, 2 * r), ACCENT, false, 3.0)
			draw_rect(Rect2(x - 5, y - 5, 10, 10), ACCENT)
		"locked":
			draw_rect(Rect2(x - r, y - r, 2 * r, 2 * r), BG)
			draw_rect(Rect2(x - r, y - r, 2 * r, 2 * r), DIM, false, 2.0)
		"milestone", "milestone_done", "planned":
			var d := r + 4
			var points := PackedVector2Array([Vector2(x, y - d), Vector2(x + d, y), Vector2(x, y + d), Vector2(x - d, y)])
			if kind == "milestone_done":
				draw_colored_polygon(points, ACCENT)
			elif kind == "milestone":
				draw_colored_polygon(points, AMBER)
			else:
				draw_colored_polygon(points, BG)
				draw_polyline(points + PackedVector2Array([points[0]]), AMBER, 2.0)
		_:
			draw_rect(Rect2(x - r, y - r, 2 * r, 2 * r), BG)
			draw_rect(Rect2(x - r, y - r, 2 * r, 2 * r), LINE, false, 2.0)
