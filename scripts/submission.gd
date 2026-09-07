class_name Submission
## Turns a judge reply into progress, with the site's rules: a failed run
## adds a miss, a passing run marks the problem solved, every verdict is an
## attempt, and a review's first verdict decides its schedule.

## Misses before the reference solution is unlocked.
const UNLOCK_AFTER := 2


## page keeps state across the runs of one visit to a problem:
##   review: bool          opened from the review slot
##   review_recorded: bool the review's verdict has been decided
##   attempt_fails: int    misses during this visit
## Returns { "pass": bool, "verdict": String, "note": String }.
static func record(problem: Dictionary, reply: Dictionary, page: Dictionary) -> Dictionary:
	var id: String = problem.id
	var result: Dictionary = reply.result
	if reply.timed_out:
		return {"pass": false, "verdict": "[x] Could not run", "note": str(result.get("error", ""))}
	if result.status == "compile_error":
		var v := _fail(id, page)
		return v if not v.is_empty() else {"pass": false, "verdict": "[x] Did not compile · " + miss_text(id), "note": ""}
	if result.status == "error":
		var v := _fail(id, page)
		return v if not v.is_empty() else {"pass": false, "verdict": "[x] " + miss_text(id), "note": str(result.get("error", ""))}
	if result.status != "ok":
		return {"pass": false, "verdict": "[x] Could not run", "note": str(result.get("error", ""))}
	if int(result.passed) < int(result.total):
		var v := _fail(id, page)
		return v if not v.is_empty() else {"pass": false, "verdict": "[x] Not yet · " + miss_text(id), "note": ""}
	var v := _solve(id, problem, page)
	return v if not v.is_empty() else {"pass": true, "verdict": "[x] All tests pass · solved", "note": ""}


static func miss_text(id: String) -> String:
	return "miss %d of %d" % [mini(int(Progress.fails().get(id, 0)), UNLOCK_AFTER), UNLOCK_AFTER]


## Returns a review verdict when this run decided a review, else {}.
static func _fail(id: String, page: Dictionary) -> Dictionary:
	var was_new := not Progress.is_solved(id)
	Progress.add_fail(id)
	page["attempt_fails"] = int(page.get("attempt_fails", 0)) + 1
	return _log(id, false, was_new, page)


static func _solve(id: String, problem: Dictionary, page: Dictionary) -> Dictionary:
	var first := not Progress.is_solved(id)
	if first:
		Progress.mark_solved(id)
	var verdict := _log(id, true, first, page)
	# The first solve in a topic puts its concept cards into the review queue;
	# completing the topic starts its review week.
	if first:
		Reviews.schedule_cards_if_started(str(problem.concept))
	if first and Reviews.schedule_topic_if_cleared(str(problem.concept)) and verdict.is_empty():
		return {"pass": true, "verdict": "[x] Topic cleared", "note": "Reviews for this topic start tomorrow: two a day for a week."}
	return verdict


static func _log(id: String, passed: bool, was_new: bool, page: Dictionary) -> Dictionary:
	var in_review: bool = bool(page.get("review", false))
	var kind := "review" if in_review else ("new" if was_new else "practice")
	Sync.insert_attempt(id, kind, "pass" if passed else "miss")
	if not in_review or bool(page.get("review_recorded", false)):
		return {}
	page["review_recorded"] = true
	var clean := passed and int(page.get("attempt_fails", 0)) == 0
	Reviews.record_result(id, passed, clean)
	if passed:
		if clean:
			return {"pass": true, "verdict": "[x] Review passed cleanly", "note": "Next review in a few days."}
		return {"pass": true, "verdict": "[x] Passed after a miss", "note": "This one comes back tomorrow until it is solved cleanly twice."}
	return {"pass": false, "verdict": "[x] Review missed · " + miss_text(id), "note": "It comes back tomorrow. You can keep working on it now; that will not change the schedule."}
