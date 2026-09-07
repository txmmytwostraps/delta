extends VBoxContainer
## The stage with its buttons. Every press is added to a history of actions;
## the whole history is replayed through the judge on the current code, and
## the frames the last action produced are animated. So the stage always
## shows what the script, as written now, would do.

const Stage := preload("res://scenes/stage.gd")

var stage: Control
var readout := Label.new()
var buttons := HFlowContainer.new()
var note := Label.new()

var _get_code: Callable
var _watch: Array = []
var _specs: Array = []
var _history: Array = []
var _busy := false
var _again := false


func _init() -> void:
	add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.theme_type_variation = &"Small"
	label.text = "THE STAGE · RUNS YOUR SCRIPT AS IT IS NOW"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(label)
	stage = Stage.new()
	add_child(stage)
	readout.theme_type_variation = &"Detail"
	readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(readout)
	buttons.add_theme_constant_override("h_separation", 12)
	buttons.add_theme_constant_override("v_separation", 12)
	add_child(buttons)
	note.theme_type_variation = &"Error"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.visible = false
	add_child(note)


## kind: "move" | "health". watch: the members to trace (the kind's by
## default). get_code: the script as it stands.
func setup(kind: String, watch: Array, get_code: Callable) -> void:
	stage.kind = kind
	if stage.is_inside_tree():
		stage.state = {"health": 100, "max_health": 100, "out": []} if kind == "health" else {"x": 0, "speed": 0}
	_watch = watch if watch.size() > 0 else stage.watch_names()
	_get_code = get_code


func _process(_delta: float) -> void:
	if readout.text != stage.readout:
		readout.text = stage.readout


## The step's buttons: [{ "label", "call", "args" }] or [{ "label", "frames" }].
func set_buttons(specs: Array) -> void:
	_specs = specs
	for child in buttons.get_children():
		buttons.remove_child(child)
		child.queue_free()
	for i in specs.size():
		var b := Button.new()
		b.custom_minimum_size.y = 88
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		b.text = str(specs[i].label)
		b.pressed.connect(func() -> void: press(i))
		buttons.add_child(b)
	var reset_button := Button.new()
	reset_button.theme_type_variation = &"Link"
	reset_button.custom_minimum_size.y = 88
	reset_button.mouse_filter = Control.MOUSE_FILTER_PASS
	reset_button.text = "RESET STAGE"
	reset_button.pressed.connect(reset)
	buttons.add_child(reset_button)


func press(i: int) -> void:
	if i < 0 or i >= _specs.size():
		return
	var spec: Dictionary = _specs[i]
	if _history.size() >= 60:
		_history.pop_front()
	_history.append({"frames": spec.frames} if spec.has("frames") else {"call": spec.call, "args": spec.get("args", [])})
	replay(true)


func reset() -> void:
	_history = []
	replay(false)


## After the code changed: same history, new script.
func refresh() -> void:
	replay(false)


func replay(animate_last: bool) -> void:
	if _get_code.is_null():
		return
	if _busy:
		# A tap or an edit while the judge is still on the last one: replayed
		# once more when that comes back, so nothing is lost.
		_again = true
		return
	_busy = true
	var reply: Dictionary = await Grader.run(_get_code.call(), {"tests": [{"script": _history.duplicate(true), "trace": _watch, "expect": null}]})
	_busy = false
	if not is_inside_tree():
		return
	if _again:
		_again = false
		replay(animate_last)
		return
	var result: Dictionary = reply.result
	if result.status != "ok":
		_note("the script does not compile yet" if result.status == "compile_error" else str(result.get("error", "could not run")))
		return
	var r: Dictionary = result.results[0]
	var frames: Array = []
	for vals in r.get("trace", []):
		var s := {}
		for i in _watch.size():
			s[_watch[i]] = vals[i] if i < vals.size() else null
		frames.append(s)
	if r.has("error"):
		_note(str(r.error))
		_history.pop_back()
	else:
		_note("")
	if frames.is_empty():
		return
	frames[-1]["out"] = r.get("out", [])
	var count := 0
	if animate_last and _history.size() > 0:
		var last: Dictionary = _history[-1]
		count = int(last.frames) if last.has("frames") else 1
	if count > 0 and frames.size() > count:
		stage.play(frames.slice(frames.size() - count))
	else:
		stage.set_state(frames[-1])


func _note(text: String) -> void:
	note.text = text
	note.visible = text != ""
