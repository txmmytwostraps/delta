extends Control
## The milestone stage, drawn natively: a strip 600 units wide with a
## placeholder robot. It shows states that came out of the judge running
## the user's own script. Two kinds, like the site: "move" watches x and
## speed and slides the robot along; "health" watches health and
## max_health and shows a bar and the last printed line.

const STAGE_WIDTH := 600.0
const STAGE_HEIGHT := 160.0
const GROUND := 128.0
const KINDS := {
	"move": ["x", "speed"],
	"health": ["health", "max_health"],
	"walk": ["position", "speed", "facing"],
	"bag": ["items", "capacity", "health", "max_health"],
	"fight": ["health", "max_health", "attack_power", "enemy_health", "enemy_max_health", "enemy_attack"],
	"character": [],
}
const MILESTONE := Color("#e2b153")
const MUTED := Color("#a3adb8")

const BG := Color("#0b0d10")
const LINE := Color("#232b34")
const LINE_STRONG := Color("#344050")
const DIM := Color("#6b7885")
const TEXT := Color("#eef1f4")
const ACCENT := Color("#7ef0c2")
const ERROR := Color("#ff7085")

var kind := "move"
## A portrait: only the robot, drawn large to fit the height (Profile).
var portrait := false
var state: Dictionary = {}
## Text under the stage, e.g. "x = 40 · speed = 120".
var readout := ""

var _frames: Array = []
var _frame_clock := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The strip keeps its 600 by 160 shape at whatever width it is given.
	resized.connect(func() -> void:
		if not portrait:
			custom_minimum_size.y = size.x * STAGE_HEIGHT / STAGE_WIDTH
		queue_redraw())
	# A state set before the stage joined the tree (the Gallery, the Profile) stays.
	if state.is_empty():
		state = initial_state(kind)
	set_process(false)


## What a stage of a kind shows before the script says anything.
static func initial_state(k: String) -> Dictionary:
	match k:
		"health":
			return {"health": 100, "max_health": 100, "out": []}
		"walk":
			return {"position": null, "speed": null, "facing": null}
		"bag":
			return {"items": null, "capacity": null, "health": null, "max_health": null}
		"fight":
			return {"health": null, "max_health": null, "enemy_health": null, "enemy_max_health": null, "returned": null}
		"character":
			return {"has": {}, "x": 300, "facing": "right"}
	return {"x": 0, "speed": 0}


## A patrol for pages without the judge (the Gallery, the Profile): the
## robot walks back and forth. speed in units a second.
var _patrol := 0.0
var _patrol_dir := 1.0


func demo(speed: float = 120.0) -> void:
	_frames = []
	_patrol = speed
	set_process(true)


func stop() -> void:
	_patrol = 0.0
	_frames = []
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
	if _patrol > 0.0:
		var x: float = float(state.get("x", 300))
		x += _patrol_dir * _patrol * minf(0.05, delta)
		if x > STAGE_WIDTH - 30.0:
			_patrol_dir = -1.0
		if x < 30.0:
			_patrol_dir = 1.0
		state["x"] = x
		state["speed"] = _patrol * _patrol_dir
		state["facing"] = "left" if _patrol_dir < 0.0 else "right"
		queue_redraw()
		return
	_frame_clock += delta
	while _frame_clock >= 1.0 / 60.0 and _frames.size() > 0:
		_frame_clock -= 1.0 / 60.0
		state.merge(_frames.pop_front(), true)
	queue_redraw()
	if _frames.is_empty():
		set_process(false)


func _draw() -> void:
	if portrait:
		# The robot alone, 56 units tall on its grid, scaled to the height.
		var s := size.y / 64.0
		draw_set_transform(Vector2(size.x / 2.0, size.y - (4.0 + GROUND) * s), 0.0, Vector2(s, s))
		var hp: Variant = state.get("health", null)
		_robot(0.0, DIM if (hp is float or hp is int) and float(hp) <= 0.0 else ACCENT)
		return
	var scale := size.x / STAGE_WIDTH
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(scale, scale))
	draw_rect(Rect2(0, 0, STAGE_WIDTH, STAGE_HEIGHT), BG)
	# The stage's own grid: 32 points, full strength.
	var g := 64.0
	var gx := 0.0
	while gx <= STAGE_WIDTH:
		draw_line(Vector2(gx, 0), Vector2(gx, STAGE_HEIGHT), LINE, 1.0)
		gx += g
	var gy := 0.0
	while gy <= STAGE_HEIGHT:
		draw_line(Vector2(0, gy), Vector2(STAGE_WIDTH, gy), LINE, 1.0)
		gy += g
	draw_rect(Rect2(0, 0, STAGE_WIDTH, STAGE_HEIGHT), LINE_STRONG, false, 1.0)
	draw_line(Vector2(0, GROUND + 0.5), Vector2(STAGE_WIDTH, GROUND + 0.5), LINE_STRONG, 1.0)
	match kind:
		"health":
			_draw_health()
		"walk":
			_draw_walk()
		"bag":
			_draw_bag()
		"fight":
			_draw_fight()
		"character":
			_draw_character()
		_:
			_draw_move()


static func _is_num(v: Variant) -> bool:
	return v is float or v is int


func _ticks(font: Font) -> void:
	for t in range(0, int(STAGE_WIDTH) + 1, 100):
		draw_rect(Rect2(t, GROUND, 1, 6), DIM)
		draw_string(font, Vector2(minf(t + 3, STAGE_WIDTH - 22), GROUND + 16), str(t), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, DIM)


func _walls() -> void:
	draw_rect(Rect2(0, GROUND - 70, 3, 70), LINE_STRONG)
	draw_rect(Rect2(STAGE_WIDTH - 3, GROUND - 70, 3, 70), LINE_STRONG)


func _arrow(px: float, facing: String) -> void:
	var d := -1.0 if facing == "left" else 1.0
	draw_colored_polygon(PackedVector2Array([Vector2(px + d * 26, GROUND - 40), Vector2(px + d * 16, GROUND - 46), Vector2(px + d * 16, GROUND - 34)]), ACCENT)


## The enemy: a spikier shape.
func _enemy(ex: float, color: Color) -> void:
	var o := Vector2(ex, GROUND)
	var pts := PackedVector2Array([o + Vector2(-14, 0), o + Vector2(-14, -30), o + Vector2(-22, -46), o + Vector2(-6, -38), o + Vector2(0, -54), o + Vector2(6, -38), o + Vector2(22, -46), o + Vector2(14, -30), o + Vector2(14, 0)])
	draw_polyline(pts + PackedVector2Array([pts[0]]), color, 2.0)
	draw_rect(Rect2(o.x - 7, o.y - 32, 4, 4), color)
	draw_rect(Rect2(o.x + 3, o.y - 32, 4, 4), color)


func _hp_bar(font: Font, x: float, y: float, w: float, hp: Variant, max_hp: Variant, label: String, color: Color) -> void:
	draw_rect(Rect2(x + 0.5, y + 0.5, w, 10), LINE_STRONG, false, 1.0)
	var has := _is_num(hp) and _is_num(max_hp) and float(max_hp) > 0.0
	if has:
		draw_rect(Rect2(x + 1, y + 1, clampf(float(hp) / float(max_hp), 0.0, 1.0) * (w - 1), 9), ERROR if float(hp) <= 0.0 else color)
	draw_string(font, Vector2(x, y + 24), "%s %s%s" % [label, _num(hp) if _is_num(hp) else "?", (" / " + _num(max_hp)) if _is_num(max_hp) else ""], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, TEXT)


## A floor with a wall at each end; position is a Vector2 and facing a word.
func _draw_walk() -> void:
	var font := get_theme_default_font()
	_walls()
	_ticks(font)
	var pos: Variant = state.get("position", null)
	var v: Variant = pos["$v2"] if (pos is Dictionary and pos.has("$v2") and pos["$v2"] is Array) else null
	if v == null:
		readout = "no position yet"
		return
	var x: float = float(v[0])
	var inside := x >= 0.0 and x <= STAGE_WIDTH
	var px := clampf(x, -20.0, STAGE_WIDTH + 20.0)
	_robot(px, ACCENT if inside else ERROR)
	var facing := str(state.get("facing", ""))
	if facing == "left" or facing == "right":
		_arrow(px, facing)
	var speed: Variant = state.get("speed", null)
	readout = "position = (%s, %s)%s%s%s" % [_num(v[0]), _num(v[1]), " · speed = %s" % _num(speed) if speed != null else "", " · facing " + facing if (facing == "left" or facing == "right") else "", "" if inside else " · past the wall"]


## The robot with a bag panel listing its items, and the health bar once
## the script has health.
func _draw_bag() -> void:
	var font := get_theme_default_font()
	_robot(120.0, ACCENT)
	var items: Variant = state.get("items", null)
	var list: Array = items if items is Array else []
	var cap: Variant = state.get("capacity", null)
	var bx := 220.0
	var by := 18.0
	draw_rect(Rect2(bx + 0.5, by + 0.5, 360, 104), LINE_STRONG, false, 1.0)
	var head := "BAG" if not (items is Array) else "BAG %d%s" % [list.size(), (" / " + _num(cap)) if _is_num(cap) else ""]
	draw_string(font, Vector2(bx + 10, by + 16), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, MUTED)
	if not (items is Array):
		draw_string(font, Vector2(bx + 10, by + 40), "no bag yet", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, DIM)
	elif list.is_empty():
		draw_string(font, Vector2(bx + 10, by + 40), "empty", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, DIM)
	else:
		var slots: int = maxi(int(cap) if _is_num(cap) else 0, list.size())
		for i in slots:
			var sx := bx + 10 + (i % 4) * 86
			var sy := by + 26 + (i / 4) * 36
			draw_rect(Rect2(sx + 0.5, sy + 0.5, 78, 28), ACCENT if i < list.size() else LINE_STRONG, false, 1.0)
			if i < list.size():
				draw_string(font, Vector2(sx + 8, sy + 19), str(list[i]).substr(0, 9), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, TEXT)
	var hp: Variant = state.get("health", null)
	var max_hp: Variant = state.get("max_health", null)
	if _is_num(hp) and _is_num(max_hp) and float(max_hp) > 0.0:
		_hp_bar(font, 70.0, 24.0, 100.0, hp, max_hp, "HP", ACCENT)
	var names := []
	for it in list:
		names.append(str(it))
	readout = "%s%s%s" % ["no bag yet" if not (items is Array) else "items = [%s]" % ", ".join(names), " · capacity = %s" % _num(cap) if _is_num(cap) else "", " · health = %s" % _num(hp) if _is_num(hp) else ""]


## Two fighters facing each other with a health bar each; the last returned
## value shows as the verdict.
func _draw_fight() -> void:
	var font := get_theme_default_font()
	var hp: Variant = state.get("health", null)
	var max_hp: Variant = state.get("max_health", null)
	var ehp: Variant = state.get("enemy_health", null)
	var emax: Variant = state.get("enemy_max_health", null)
	_robot(150.0, DIM if _is_num(hp) and float(hp) <= 0.0 else ACCENT)
	var down := _is_num(ehp) and float(ehp) <= 0.0
	_enemy(450.0, DIM if down else MILESTONE)
	_hp_bar(font, 90.0, 18.0, 120.0, hp, max_hp, "ROBOT", ACCENT)
	_hp_bar(font, 390.0, 18.0, 120.0, ehp, emax, "ENEMY", MILESTONE)
	var returned: Variant = state.get("returned", null)
	if returned is String:
		draw_string(font, Vector2(0, 74), str(returned).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, STAGE_WIDTH, 16, ACCENT if returned == "won" else ERROR)
	readout = "%s%s%s" % ["no fighters yet" if not _is_num(hp) else "health = %s" % _num(hp), " · enemy_health = %s" % _num(ehp) if _is_num(ehp) else "", " · returned %s" % Fmt.to_json(returned) if returned != null else ""]


## Everything earned so far in one picture: the robot, and what each
## finished milestone added. state.has: { move, health, walk, bag, fight }.
func _draw_character() -> void:
	var font := get_theme_default_font()
	var has: Dictionary = state.get("has", {}) if state.get("has", null) is Dictionary else {}
	if has.get("walk", false):
		_walls()
	var x: Variant = state.get("x", 300)
	var px := clampf(float(x) if _is_num(x) else 300.0, 30.0, STAGE_WIDTH - 30.0)
	_robot(px, ACCENT)
	var facing := str(state.get("facing", ""))
	if has.get("walk", false) and (facing == "left" or facing == "right"):
		_arrow(px, facing)
	if has.get("health", false):
		var bx := px - 40.0
		var by := GROUND - 78.0
		draw_rect(Rect2(bx + 0.5, by + 0.5, 80, 8), LINE_STRONG, false, 1.0)
		draw_rect(Rect2(bx + 1, by + 1, 79, 7), ACCENT)
		draw_string(font, Vector2(px - 60, by - 4), "HP 100 / 100", HORIZONTAL_ALIGNMENT_CENTER, 120, 10, MUTED)
	if has.get("bag", false):
		draw_rect(Rect2(px + 12.5, GROUND - 32.5, 12, 14), MILESTONE, false, 2.0)
	if has.get("fight", false):
		_enemy(STAGE_WIDTH - 60.0 if px < 300.0 else 60.0, MILESTONE)
	var labels := []
	for pair in [["move", "moves"], ["health", "has health"], ["walk", "walks the floor"], ["bag", "carries a bag"], ["fight", "fights"]]:
		if has.get(pair[0], false):
			labels.append(pair[1])
	readout = " · ".join(labels) if labels.size() > 0 else "nothing built yet"


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
