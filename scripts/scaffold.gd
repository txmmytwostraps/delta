extends Node
## Adaptive hints, with the site's rules. Each topic has a hint level worked
## out from the rolling pass rate of its last 20 attempts:
##   full     every hint opens on request; the reference solution after 2 misses
##   reduced  hint 1 opens on request, the rest after a miss on the problem
##   minimal  hints stay closed until 2 misses; the solution needs 3
## The level rises one step when the rate passes 85% over at least 15
## attempts, and drops one step when it falls under 65% (at least 10). A
## change needs 15 new attempts before the next one. A hand-set override,
## kept in the account settings, wins until it is cleared.

signal changed

const LEVELS := ["full", "reduced", "minimal"]
const WINDOW := 20
const RISE := 0.85
const DROP := 0.65
const MIN_RISE := 15
const MIN_DROP := 10


func _data() -> Dictionary:
	var d := Store.section("scaffold")
	for key in ["auto", "counts"]:
		if not (d.get(key) is Dictionary):
			d[key] = {}
	return d


## The attempt log as last pulled from the account, plus this session's.
func attempts() -> Array:
	if not (Store.data.get("attempts") is Array):
		Store.data["attempts"] = []
	return Store.data["attempts"]


func level_for(concept: String) -> String:
	var o := override_for(concept)
	return o if o != "" else auto_level(concept)


func auto_level(concept: String) -> String:
	var a: Dictionary = _data().auto.get(concept, {})
	return str(a.get("level", "full"))


func override_for(concept: String) -> String:
	var o := str(Settings.hint_overrides().get(concept, ""))
	return o if LEVELS.has(o) else ""


func set_override(concept: String, level: String) -> void:
	Settings.set_hint_override(concept, level if LEVELS.has(level) else "")
	changed.emit()


## { "attempts": int, "rate": float or null }
func stats_for(concept: String) -> Dictionary:
	return _data().counts.get(concept, {"attempts": 0, "rate": null})


## Misses needed before the reference solution unlocks, by level.
static func solution_after(level: String) -> int:
	return 3 if level == "minimal" else 2


## Whether hint number i (0-based) may open, given the level and the misses.
static func hint_open(level: String, i: int, misses: int) -> bool:
	if level == "full":
		return true
	if level == "reduced":
		return i == 0 or misses >= 1
	return misses >= 2


static func hint_lock_text(level: String) -> String:
	return "after a miss" if level == "reduced" else "after 2 misses"


## The account's attempt log replaces the local one; levels are recomputed.
func replace_attempts(rows: Array) -> void:
	Store.data["attempts"] = rows
	recompute()


## A verdict just happened: fold it in.
func note_attempt(problem_id: String, passed: bool) -> void:
	attempts().append({"problem_id": problem_id, "kind": "session", "result": "pass" if passed else "miss", "at": Progress.now_iso()})
	recompute()


## Recompute every topic's automatic level from the attempt log.
func recompute() -> void:
	var by_topic := {}
	for a in attempts():
		var p := Bank.problem(str(a.get("problem_id", "")))
		if p.is_empty():
			continue
		if not by_topic.has(p.concept):
			by_topic[p.concept] = []
		by_topic[p.concept].append(str(a.get("result", "")) == "pass")
	var d := _data()
	for concept in by_topic:
		var results: Array = by_topic[concept]
		var total := results.size()
		var recent: Array = results.slice(maxi(0, total - WINDOW))
		var rate := float(recent.filter(func(ok: bool) -> bool: return ok).size()) / float(recent.size())
		d.counts[concept] = {"attempts": total, "rate": rate}
		var cur: Dictionary = d.auto.get(concept, {"level": "full", "since": 0})
		var idx := LEVELS.find(str(cur.level))
		var fresh: int = total - int(cur.since)
		if fresh >= MIN_RISE and recent.size() >= MIN_RISE and rate > RISE and idx < LEVELS.size() - 1:
			d.auto[concept] = {"level": LEVELS[idx + 1], "since": total}
		elif fresh >= MIN_DROP and recent.size() >= MIN_DROP and rate < DROP and idx > 0:
			d.auto[concept] = {"level": LEVELS[idx - 1], "since": total}
		elif not d.auto.has(concept):
			d.auto[concept] = cur
	Store.save()
	changed.emit()
