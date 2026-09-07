class_name Submission
## Turns a judge reply into progress, with the site's rules: a failed run
## adds a miss, a passing run marks the problem solved, every verdict is an
## attempt, and a review's first verdict decides its schedule.


## page keeps state across the runs of one visit to a problem:
##   review: bool          opened from the review slot
##   review_recorded: bool the review's verdict has been decided
##   attempt_fails: int    misses during this visit
## Returns { "pass": bool, "verdict": String, "note": String }. The verdict
## is the detail line; the results panel puts "Correct" or "Not yet" above.
static func record(problem: Dictionary, reply: Dictionary, page: Dictionary) -> Dictionary:
	var id: String = problem.id
	var result: Dictionary = reply.result
	if reply.timed_out:
		return {"pass": false, "verdict": "Could not run", "note": str(result.get("error", ""))}
	if result.status == "compile_error":
		var v := _fail(id, page)
		return v if not v.is_empty() else {"pass": false, "verdict": "Did not compile · " + miss_text(problem), "note": ""}
	if result.status == "error":
		var v := _fail(id, page)
		return v if not v.is_empty() else {"pass": false, "verdict": miss_text(problem), "note": str(result.get("error", ""))}
	if result.status != "ok":
		return {"pass": false, "verdict": "Could not run", "note": str(result.get("error", ""))}
	if int(result.passed) < int(result.total):
		var v := _fail(id, page)
		return v if not v.is_empty() else {"pass": false, "verdict": "Not yet · " + miss_text(problem), "note": ""}
	var v := _solve(id, problem, page)
	return v if not v.is_empty() else {"pass": true, "verdict": "All tests pass · solved", "note": ""}


## Next › after a solve: in a review run, the next review still pending
## today; otherwise the next unsolved problem in the topic. "" when there is
## none (the run is done, or the topic is cleared).
static func next_problem(id: String, review: bool) -> String:
	if review:
		for r in Reviews.due_today(Progress.today_key()).pending:
			var rid := str(r.problem_id)
			if rid != id and Bank.has_problem(rid):
				return rid
		return ""
	var p := Bank.problem(id)
	for q in Bank.problems_in(str(p.get("concept", ""))):
		if q.id != id and not Progress.is_solved(q.id):
			return q.id
	return ""


## Misses before the reference solution unlocks: 2, or 3 on a topic at the
## minimal hint level.
static func unlock_after(problem: Dictionary) -> int:
	return Scaffold.solution_after(Scaffold.level_for(str(problem.get("concept", ""))))


static func miss_text(problem: Dictionary) -> String:
	var after := unlock_after(problem)
	return "miss %d of %d" % [mini(int(Progress.fails().get(problem.id, 0)), after), after]


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
		return {"pass": true, "verdict": "Topic cleared", "note": "Reviews for this topic start tomorrow: two a day for a week."}
	return verdict


static func _log(id: String, passed: bool, was_new: bool, page: Dictionary) -> Dictionary:
	var in_review: bool = bool(page.get("review", false))
	var kind := "review" if in_review else ("new" if was_new else "practice")
	Sync.insert_attempt(id, kind, "pass" if passed else "miss")
	Scaffold.note_attempt(id, passed)
	if not in_review or bool(page.get("review_recorded", false)):
		return {}
	page["review_recorded"] = true
	var clean := passed and int(page.get("attempt_fails", 0)) == 0
	Reviews.record_result(id, passed, clean)
	if passed:
		if clean:
			return {"pass": true, "verdict": "Review passed cleanly", "note": "Next review in a few days."}
		return {"pass": true, "verdict": "Passed after a miss", "note": "This one comes back tomorrow until it is solved cleanly twice."}
	return {"pass": false, "verdict": "Review missed · " + miss_text(Bank.problem(id)), "note": "It comes back tomorrow. You can keep working on it now; that will not change the schedule."}
