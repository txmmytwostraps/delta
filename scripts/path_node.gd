extends Control
## One stop on the route's vertical path: the line running through, and a
## node whose shape says what the stop is, like the site's: a filled square
## done, a ring for the current one, a hollow square ahead, a dim dot locked.

## todo | current | done | locked | empty
var kind := "todo"
var first := false
var last := false

const LINE := Color("#344050")
const ACCENT := Color("#7ef0c2")
const DIM := Color("#6b7885")
const BG := Color("#0b0d10")


func _init() -> void:
	custom_minimum_size = Vector2(56, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var x := size.x / 2.0
	var y := minf(size.y / 2.0, 52.0)   # on the row's first line, even under a card
	var top := y if first else 0.0
	var bottom := y if last else size.y
	draw_line(Vector2(x, top), Vector2(x, bottom), LINE, 2.0)
	var r := 11.0
	match kind:
		"done":
			draw_rect(Rect2(x - r, y - r, 2 * r, 2 * r), ACCENT)
		"current":
			draw_circle(Vector2(x, y), r + 3, BG)
			draw_arc(Vector2(x, y), r + 1, 0.0, TAU, 32, ACCENT, 3.0)
			draw_circle(Vector2(x, y), 4.0, ACCENT)
		"locked":
			draw_circle(Vector2(x, y), 5.0, DIM)
		"empty":
			draw_circle(Vector2(x, y), 4.0, LINE)
		_:
			draw_rect(Rect2(x - r, y - r, 2 * r, 2 * r), BG)
			draw_rect(Rect2(x - r, y - r, 2 * r, 2 * r), LINE, false, 2.0)
