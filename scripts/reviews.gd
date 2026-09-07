extends Node
## Spaced review, with the site's rules:
##  - when a topic is completed (every problem solved) it enters a fresh week:
##    two of its problems are due each day, rotating through the topic;
##  - after its fresh review a problem moves to standard spacing: due again
##    after 3, 7, 14, then 30 days, extended on each clean solve;
##  - a miss on any review pulls the problem back to daily until it is
##    solved cleanly twice;
##  - at most 6 reviews a day; oldest due first, the rest roll over.
## The queue lives in the account; the copy here is what the app works from.

signal changed

const REVIEW_CAP := 6
const SPACING := [3, 7, 14, 30]


func rows() -> Dictionary:        # { problem_id: row }
	return Store.section("reviews")


func is_in_review(id: String) -> bool:
	return rows().has(id)


## Replace the local copy with the account's rows (after a pull).
func replace_all(remote: Array) -> void:
	var local := rows()
	local.clear()
	for r in remote:
		local[r.problem_id] = r
	Store.save()
	changed.emit()


## Everything due on or before the day, oldest first (uncapped).
func due(day: String) -> Array:
	var out: Array = rows().values().filter(func(r: Dictionary) -> bool: return str(r.due_on) <= day)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.due_on != b.due_on:
			return str(a.due_on) < str(b.due_on)
		return str(a.problem_id) < str(b.problem_id))
	return out


## The day's list: at most REVIEW_CAP pending, plus the ones already reviewed
## that day, plus how many roll over.
func due_today(day: String) -> Dictionary:
	var done_today: Array = rows().values().filter(func(r: Dictionary) -> bool:
		return r.get("reviewed_at", null) != null and Streak.day_key(str(r.reviewed_at)) == day)
	var all_due := due(day)
	var pending := all_due.slice(0, maxi(0, REVIEW_CAP - done_today.size()))
	return {"pending": pending, "done_today": done_today, "rolled": maxi(0, all_due.size() - pending.size())}


## If every problem of the topic is solved and it is not scheduled yet, start
## its fresh week. Returns true when it did.
func schedule_topic_if_cleared(concept: String) -> bool:
	if not Auth.is_signed_in():
		return false
	var list := Bank.problems_in(concept)
	if list.is_empty():
		return false
	for p in list:
		if not Progress.is_solved(p.id):
			return false
	for r in rows().values():
		if r.topic == concept:
			return false
	var start := Progress.today_key()
	var new_rows := []
	for i in list.size():
		new_rows.append({
			"user_id": Auth.user_id(), "problem_id": list[i].id, "topic": concept, "stage": "fresh",
			"due_on": add_days(start, i / 2 + 1), "step": 0, "clean_streak": 0,
		})
	Sync.queue_upsert("reviews", new_rows, "user_id,problem_id")
	for r in new_rows:
		rows()[r.problem_id] = r
	Store.save()
	changed.emit()
	return true


## Record the outcome of a review. clean = passed on the first run.
func record_result(problem_id: String, passed: bool, clean: bool) -> void:
	var r: Variant = rows().get(problem_id)
	if not Auth.is_signed_in() or r == null:
		return
	var day := Progress.today_key()
	var next: Dictionary = r.duplicate()
	next["reviewed_at"] = Progress.now_iso()
	next["last_result"] = "pass" if passed else "miss"
	if not passed or not clean:
		next.stage = "relearn"
		next.clean_streak = 0
		next.due_on = add_days(day, 1)
	elif r.stage == "relearn":
		next.clean_streak = int(r.get("clean_streak", 0)) + 1
		if next.clean_streak >= 2:
			next.stage = "spaced"
			next.step = 0
			next.clean_streak = 0
			next.due_on = add_days(day, SPACING[0])
		else:
			next.due_on = add_days(day, 1)
	elif r.stage == "fresh":
		next.stage = "spaced"
		next.step = 0
		next.due_on = add_days(day, SPACING[0])
	else:
		next.step = int(r.get("step", 0)) + 1
		var base: int = SPACING[mini(next.step, SPACING.size() - 1)]
		var interval: int = base
		if next.step >= SPACING.size():
			interval = base * int(pow(2, next.step - SPACING.size() + 1))
		next.due_on = add_days(day, mini(90, interval))
	Sync.queue_upsert("reviews", [{
		"user_id": Auth.user_id(), "problem_id": problem_id, "topic": next.topic, "stage": next.stage,
		"due_on": next.due_on, "step": int(next.get("step", 0)), "clean_streak": int(next.get("clean_streak", 0)),
		"last_result": next.last_result, "reviewed_at": next.reviewed_at,
	}], "user_id,problem_id")
	rows()[problem_id] = next
	Store.save()
	changed.emit()


func topic_title(concept: String) -> String:
	return Bank.topic_title(concept)


## "2026-09-06" + 3 -> "2026-09-09". Counted from noon so clock changes
## cannot shift the day.
static func add_days(key: String, n: int) -> String:
	var noon := Time.get_unix_time_from_datetime_string(key + "T12:00:00")
	return Time.get_date_string_from_unix_time(noon + n * 86400)
