extends Control
## The faint grid behind every screen, the same as the site's.

const BACKGROUND := Color("#0b0d10")
const STEP := 80.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	var line := Color("#7ef0c2", 0.025)
	var x := 0.0
	while x <= size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), line, 2.0)
		x += STEP
	var y := 0.0
	while y <= size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), line, 2.0)
		y += STEP
