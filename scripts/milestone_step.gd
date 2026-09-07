class_name MilestoneStep
## A milestone is a script built in steps. Step ids (m1-s1 …) are stored in
## the solved map like problems, so they sync with the account. Same rules
## as the site's milestone page.


## A check, in words: what is done, then what should be true afterwards.
static func describe(t: Dictionary) -> String:
	var acts := []
	for a in t.get("script", []):
		if a.has("frames"):
			var n := int(a.frames)
			acts.append("%d frame%s%s" % [n, "" if n == 1 else "s", " of %.3f s" % float(a.delta) if a.has("delta") else ""])
		else:
			var args: Array = a.get("args", [])
			acts.append("%s(%s)" % [a.call, ", ".join(args.map(func(v: Variant) -> String: return Fmt.num(v) if (v is float or v is int) else str(v)))])
	var after: String = "after %s: " % ", then ".join(acts) if acts.size() > 0 else "at the start: "
	if t.has("read"):
		return "%s%s is %s" % [after, t.read, Fmt.to_json(t.get("expect", null))]
	return "%sit prints %s" % [after, Fmt.to_json(t.get("out", []))]


## Turns the judge's reply into progress: a passing step is marked solved
## (once) and logged as a milestone attempt; a miss records nothing, like
## the site. Returns { "pass", "verdict", "note" } for the results panel.
static func record(meta: Dictionary, data: Dictionary, step_index: int, reply: Dictionary) -> Dictionary:
	var step: Dictionary = data.steps[step_index]
	var result: Dictionary = reply.result
	if reply.timed_out:
		return {"pass": false, "verdict": "Could not run", "note": str(result.get("error", ""))}
	if result.status == "compile_error":
		return {"pass": false, "verdict": "Did not compile", "note": ""}
	if result.status == "error":
		return {"pass": false, "verdict": "Not yet", "note": str(result.get("error", ""))}
	if result.status != "ok":
		return {"pass": false, "verdict": "Could not run", "note": str(result.get("error", ""))}
	if int(result.passed) < int(result.total):
		return {"pass": false, "verdict": "Not yet", "note": "Fix what the failing check says, then run again."}
	var first := not Progress.is_solved(step.id)
	if first:
		Progress.mark_solved(step.id)
		Sync.insert_attempt(step.id, "milestone", "pass")
		Scaffold.note_attempt(step.id, "milestone", true)
	var st := Progress.milestone_status(meta)
	var last: bool = step_index >= data.steps.size() - 1
	var verdict := "Step %d done · milestone complete" % (step_index + 1) if st.done else "Step %d done" % (step_index + 1)
	var note := "The next step starts from this script." if not last else ("" if st.godot_done else "Now build the same robot in Godot: the last tab above.")
	# What the pass earns, in the site's words; a step counts once.
	var xp := "+%d XP · step %d done" % [Progress.XP_STEP, step_index + 1] if first else "+0 XP · again · step %d done" % (step_index + 1)
	return {"pass": true, "verdict": verdict, "note": note, "xp": xp}


## The "In Godot" checklist: ticks kept on the phone; all ticked marks
## <id>-godot solved, like the site.
static func godot_ticks(meta_id: String) -> Array:
	var all := Store.section("godot_ticks")
	if not (all.get(meta_id) is Array):
		all[meta_id] = []
	return all[meta_id]


static func set_godot_tick(meta: Dictionary, data: Dictionary, index: int, on: bool) -> void:
	var ticks := godot_ticks(str(meta.id))
	while ticks.size() <= index:
		ticks.append(false)
	ticks[index] = on
	Store.save()
	var lines: Array = data.get("godot", [])
	var all_on := lines.size() > 0
	for i in lines.size():
		if i >= ticks.size() or not bool(ticks[i]):
			all_on = false
	var id := "%s-godot" % meta.id
	if all_on and not Progress.is_solved(id):
		Progress.mark_solved(id)
	elif not all_on and Progress.is_solved(id):
		Progress.solved().erase(id)
		Store.save()
		Sync.push_progress(id)
		Progress.changed.emit()
