extends Node
## Runs a submission against a problem's tests, using the site's own judge
## scripts (pulled into bank/judge/ at build time), so a verdict here is the
## verdict the site would give.
##
## The run happens on a worker thread with a time limit. The site gets its
## time limit from the browser, which can kill a frozen judge; a phone
## cannot kill a thread, so a run that never comes back is left running and
## counted in `stuck`. The loop budget in the judge ends most runaway code
## long before that.

const TIMEOUT_MS := 5000
const MAX_ERROR_LINES := 20
const LOG_PATH := "user://logs/delta.log"

var runner: Node
var busy := false
## Runs that never came back. Each burns a core until the app restarts.
var stuck := 0

var _zombies: Array = []


func _ready() -> void:
	var script: GDScript = load("res://bank/judge/runner.gd")
	if script == null:
		push_error("bank/judge/runner.gd is missing. Run tools/fetch-site.sh first.")
		return
	runner = script.new()
	add_child(runner)


## Same shape as the site's judge client gives its page:
## { "result": Dictionary, "errors": Array of String, "ms": int, "timed_out": bool }
## result is the judge's own reply: status ok | compile_error | error, and
## for ok: passed, total, results. A run that did not finish in time has
## status "timeout".
func run(code: String, problem: Dictionary) -> Dictionary:
	if runner == null:
		return _reply({"status": "error", "error": "the judge is not installed"}, [], 0, false)
	if busy:
		return _reply({"status": "error", "error": "a run is already in progress"}, [], 0, false)
	busy = true
	_reap()
	var log_from := _log_size()
	var box := {}
	var thread := Thread.new()
	var started := Time.get_ticks_msec()
	var err := thread.start(func() -> void:
		box["result"] = runner.run_submission(code, problem))
	if err != OK:
		busy = false
		return _reply({"status": "error", "error": "could not start the judge (error %d)" % err}, [], 0, false)
	while thread.is_alive() and Time.get_ticks_msec() - started < TIMEOUT_MS:
		await get_tree().process_frame
	var ms := Time.get_ticks_msec() - started
	var errors := _errors_since(log_from)
	busy = false
	if thread.is_alive():
		_zombies.append(thread)
		stuck = _zombies.size()
		return _reply({"status": "timeout", "error": "timed out after %d s — check for an infinite loop" % (TIMEOUT_MS / 1000)}, errors, ms, true)
	thread.wait_to_finish()
	return _reply(box.get("result", {"status": "error", "error": "the judge returned nothing"}), errors, ms, false)


func _reply(result: Dictionary, errors: Array, ms: int, timed_out: bool) -> Dictionary:
	return {"result": result, "errors": errors, "ms": ms, "timed_out": timed_out}


## Joins any stuck thread that has finished since.
func _reap() -> void:
	var still := []
	for thread in _zombies:
		if thread.is_alive():
			still.append(thread)
		else:
			thread.wait_to_finish()
	_zombies = still
	stuck = _zombies.size()


# ---- error lines ----
# Godot writes script errors to the log file (see [debug] in project.godot).
# The lines added during a run are the ones to show, tidied the way the site
# tidies them: the hidden "extends Judge" line makes every line number one
# too high, and backtraces are noise to a learner.

func _log_size() -> int:
	var file := FileAccess.open(LOG_PATH, FileAccess.READ)
	if file == null:
		return 0
	return file.get_length()


func _errors_since(from: int) -> Array:
	var file := FileAccess.open(LOG_PATH, FileAccess.READ)
	if file == null:
		return []
	if from > file.get_length():
		from = 0
	file.seek(from)
	var text := file.get_buffer(file.get_length() - from).get_string_from_utf8()
	var lines := []
	for raw in text.split("\n"):
		var line: String = raw.strip_edges(false, true)
		if line == "" or _is_noise(line):
			continue
		lines.append(tidy_error(line))
	if lines.size() > MAX_ERROR_LINES:
		var extra := lines.size() - MAX_ERROR_LINES
		lines = lines.slice(0, MAX_ERROR_LINES)
		lines.append("… %d more lines hidden" % extra)
	return lines


static func _is_noise(line: String) -> bool:
	var s := line.strip_edges()
	if s.begins_with("GDScript backtrace") or s.begins_with("["):
		return true
	if s.contains("(Engine Bug)") or s.contains("exit_function (modules/"):
		return true
	return false


## "SCRIPT ERROR: Parse Error: x\n   at: GDScript::reload (gdscript://-92.gd:3)"
## becomes "Parse Error: x" and "   at: GDScript::reload (line 2)".
static func tidy_error(line: String) -> String:
	var re := RegEx.new()
	re.compile("gdscript://[^:)]+\\.gd:(\\d+)")
	var out := line
	var m := re.search(out)
	while m != null:
		out = out.substr(0, m.get_start()) + "line %d" % (int(m.get_string(1)) - 1) + out.substr(m.get_end())
		m = re.search(out)
	if out.begins_with("SCRIPT ERROR: "):
		out = out.substr(14)
	return out
