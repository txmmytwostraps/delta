extends Control
## The milestone stage, drawn natively: a strip 600 units wide with a
## placeholder robot. It shows states that came out of the judge running
## the user's own script. Two kinds, like the site: "move" watches x and
## speed and slides the robot along; "health" watches health and
## max_health and shows a bar and the last printed line.

const STAGE_WIDTH := 600.0
const STAGE_HEIGHT := 160.0
const GROUND := 128.0
const KINDS := {"move": ["x", "speed"], "health": ["health", "max_health"]}

const BG := Color("#0b0d10")
const LINE := Color("#1c2229")
const LINE_STRONG := Color("#2a323b")
const DIM := Color("#4e5a66")
const TEXT := Color("#e8ecef")
const ACCENT := Color("#7ef0c2")
const ERROR := Color("#ff7085")

var kind := "move"
var state: Dictionary = {}
## Text under the stage, e.g. "x = 40 · speed = 120".
var readout := ""

var _frames: Array = []
var _frame_clock := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The strip keeps its 600 by 160 shape at whatever width it is given.
	resized.connect(func() -> void:
		custom_minimum_size.y = size.x * STAGE_HEIGHT / STAGE_WIDTH
		queue_redraw())
	state = {"health": 100, "max_health": 100, "out": []} if kind == "health" else {"x": 0, "speed": 0}
	set_process(false)


func watch_names() -> Array:
	return KINDS.get(kind, KINDS.move)


## Show one state at once.
func set_state(s: Dictionary) -> void:
	_frames = []
	set_process(false)
	state.merge(s, true)
	queue_redraw()


## Play a list of states, one per frame at 60 a second, then stay on the last.
func play(frames: Array) -> void:
	if frames.is_empty():
		return
	_frames = frames.duplicate()
	_frame_clock = 0.0
	set_process(true)


func _process(delta: float) -> void:
	_frame_clock += delta
	while _frame_clock >= 1.0 / 60.0 and _frames.size() > 0:
		_frame_clock -= 1.0 / 60.0
		state.merge(_frames.pop_front(), true)
	queue_redraw()
	if _frames.is_empty():
		set_process(false)


func _draw() -> void:
	var scale := size.x / STAGE_WIDTH
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(scale, scale))
	draw_rect(Rect2(0, 0, STAGE_WIDTH, STAGE_HEIGHT), BG)
	draw_rect(Rect2(0, 0, STAGE_WIDTH, STAGE_HEIGHT), LINE, false, 1.0)
	draw_line(Vector2(0, GROUND + 0.5), Vector2(STAGE_WIDTH, GROUND + 0.5), LINE_STRONG, 1.0)
	if kind == "health":
		_draw_health()
	else:
		_draw_move()


func _num(v: Variant) -> String:
	if v is float or v is int:
		return Fmt.num(v) if (v is int or (v is float and v == floor(v))) else str(snappedf(v, 0.1))
	return "?"


func _draw_move() -> void:
	var font := get_theme_default_font()
	for t in range(0, int(STAGE_WIDTH) + 1, 100):
		draw_rect(Rect2(t, GROUND, 1, 6), DIM)
		draw_string(font, Vector2(t + 3, GROUND + 16), str(t), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, DIM)
	var x: float = float(state.x) if (state.get("x", null) is float or state.get("x", null) is int) else 0.0
	var on_stage := x >= -20.0 and x <= STAGE_WIDTH + 20.0
	_robot(clampf(x, -20.0, STAGE_WIDTH + 20.0), ACCENT if on_stage else DIM)
	var speed: Variant = state.get("speed", null)
	readout = "x = %s%s%s" % [_num(x), " · speed = %s" % _num(speed) if speed != null else "", "" if on_stage else " · off the stage"]


func _draw_health() -> void:
	var font := get_theme_default_font()
	var hp: Variant = state.get("health", null)
	var max_hp: Variant = state.get("max_health", null)
	var has_hp := hp is float or hp is int
	var has_max := (max_hp is float or max_hp is int) and float(max_hp) > 0.0
	var down := has_hp and float(hp) <= 0.0
	_robot(STAGE_WIDTH / 2.0, DIM if down else ACCENT)
	var bx := STAGE_WIDTH / 2.0 - 100.0
	var by := 24.0
	draw_rect(Rect2(bx + 0.5, by + 0.5, 200, 12), LINE_STRONG, false, 1.0)
	if has_hp and has_max:
		draw_rect(Rect2(bx + 1, by + 1, clampf(float(hp) / float(max_hp), 0.0, 1.0) * 199.0, 11), ERROR if down else ACCENT)
	var label := "HP ?" if not (has_hp and has_max) else "HP %s / %s" % [_num(hp), _num(max_hp)]
	draw_string(font, Vector2(0, by + 12 + 16), label, HORIZONTAL_ALIGNMENT_CENTER, STAGE_WIDTH, 12, TEXT)
	var out: Array = state.get("out", []) if state.get("out", null) is Array else []
	var last: String = str(out[-1]) if out.size() > 0 else ""
	if last != "":
		draw_string(font, Vector2(0, GROUND - 62), last, HORIZONTAL_ALIGNMENT_CENTER, STAGE_WIDTH, 14, ERROR if down else ACCENT)
	readout = "%s%s%s" % ["health = %s" % _num(hp) if has_hp else "no health yet", " · max_health = %s" % _num(max_hp) if has_max else "", " · printed: %s" % last if last != "" else ""]


func _robot(px: float, color: Color) -> void:
	var o := Vector2(px, GROUND)
	draw_arc(o + Vector2(0, -46), 9.0, 0.0, TAU, 24, color, 2.0)
	draw_rect(Rect2(o.x - 10, o.y - 34, 20, 22), color, false, 2.0)
	draw_line(o + Vector2(-10, -26), o + Vector2(-20, -14), color, 2.0)
	draw_line(o + Vector2(10, -26), o + Vector2(20, -14), color, 2.0)
	draw_line(o + Vector2(-6, -12), o + Vector2(-6, 0), color, 2.0)
	draw_line(o + Vector2(6, -12), o + Vector2(6, 0), color, 2.0)
	draw_rect(Rect2(o.x - 4, o.y - 49, 3, 3), color)
	draw_rect(Rect2(o.x + 1, o.y - 49, 3, 3), color)
