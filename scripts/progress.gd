extends Node
## What is solved, failed and drafted, the day's run, the streak and the
## position on the route. The rules are the site's; the rows live in Store.

signal changed

## Set to "YYYY-MM-DD" to pretend it is another day (testing only).
var today_override := ""


# ---- rows ----

func solved() -> Dictionary:      # { id: ISO date }
	return Store.section("solved")


func fails() -> Dictionary:       # { id: count }
	return Store.section("fails")


func drafts() -> Dictionary:      # { id: { code, at } }
	return Store.section("drafts")


func runs() -> Dictionary:        # { day: run }
	return Store.section("runs")


func is_solved(id: String) -> bool:
	return solved().has(id)


func mark_solved(id: String) -> void:
	if solved().has(id):
		return
	solved()[id] = now_iso()
	Store.save()
	Sync.push_progress(id)
	changed.emit()


func add_fail(id: String) -> void:
	fails()[id] = int(fails().get(id, 0)) + 1
	Store.save()
	Sync.push_progress(id)
	changed.emit()


func draft(id: String) -> Dictionary:
	return drafts().get(id, {})


func set_draft(id: String, code: String) -> void:
	drafts()[id] = {"code": code, "at": now_iso()}
	Store.save()
	Sync.push_progress(id)


func clear_draft(id: String) -> void:
	drafts().erase(id)
	Store.save()
	Sync.push_progress(id)


# ---- dates ----

## The current moment as the site writes it: UTC, e.g. "2026-09-06T14:03:11Z".
static func now_iso() -> String:
	return Time.get_datetime_string_from_system(true) + "Z"


func today_key() -> String:
	if today_override != "":
		return today_override
	return Streak.key_for_unix(Time.get_unix_time_from_system())


## Problem ids solved on a day ("YYYY-MM-DD", local time).
func solves_on(key: String) -> Array:
	var out := []
	for id in solved():
		if Streak.day_key(str(solved()[id])) == key:
			out.append(id)
	return out


# ---- the course lock ("finished through lesson N") ----

func course_lock() -> int:
	return int(Store.get_value("course_lock", Bank.default_course_lock))


func set_course_lock(n: int) -> void:
	Store.set_value("course_lock", n)
	changed.emit()


# ---- topics on the route ----

## solved_map lets the caller ask about another state than the current one;
## null means the current one.
func topic_stats(t: Dictionary, solved_map: Variant = null) -> Dictionary:
	var map: Dictionary = solved() if solved_map == null else solved_map
	var list := Bank.problems_in(t.concept)
	var done: Array = list.filter(func(p: Dictionary) -> bool: return map.has(p.id))
	var cleared_at: Variant = null
	if done.size() > 0 and done.size() == list.size():
		var dates: Array = done.map(func(p: Dictionary) -> String: return str(map[p.id]))
		dates.sort()
		cleared_at = dates[-1]
	return {"total": list.size(), "done": done.size(), "cleared_at": cleared_at, "locked": int(t.lesson) > course_lock(), "list": list}


func route_topics(solved_map: Variant = null) -> Array:
	var out := []
	for t in Bank.topics:
		var full: Dictionary = t.duplicate()
		full.merge(topic_stats(t, solved_map), true)
		out.append(full)
	return out


## The first unlocked topic with something left to solve, else the last topic.
func current_topic(solved_map: Variant = null) -> Dictionary:
	var all := route_topics(solved_map)
	for t in all:
		if not t.locked and t.total > 0 and t.done < t.total:
			return t
	var with_problems: Array = all.filter(func(t: Dictionary) -> bool: return t.total > 0)
	return with_problems[-1] if with_problems.size() > 0 else {}


func next_milestone() -> Dictionary:
	var all := route_topics()
	for m in Bank.milestones:
		var idx := -1
		for i in all.size():
			if all[i].concept == m.after:
				idx = i
				break
		var before := all.slice(0, idx + 1)
		var unlocked: bool = before.all(func(t: Dictionary) -> bool: return t.total == 0 or t.done == t.total)
		var to_go: int = before.filter(func(t: Dictionary) -> bool: return t.total > 0 and t.done < t.total).size()
		var out: Dictionary = m.duplicate()
		out["unlocked"] = unlocked
		out["topics_to_go"] = to_go
		return out
	return {}


func marker_for(t: Dictionary) -> String:
	if t.locked:
		return "[#]"
	if t.done == t.total and t.total > 0:
		return "[x]"
	return "[>]" if t.done > 0 else "[ ]"


# ---- the daily run ----

## Assigned once per day and kept, so the numbers do not shift while you
## work: N new problems from the current topic (the next unsolved ones in
## order) plus one extra. The site does the same. When the phone assigns it,
## it looks at the state as it was at the start of the day, with today's
## solves not counted, so it lands on the set the site chose earlier in the
## day rather than the problems after them.
func today_run() -> Dictionary:
	var key := today_key()
	if runs().has(key):
		return runs()[key]
	var at_start: Dictionary = solved().duplicate()
	for id in solves_on(key):
		at_start.erase(id)
	var t := current_topic(at_start)
	var unsolved: Array = []
	if not t.is_empty():
		unsolved = t.list.filter(func(p: Dictionary) -> bool: return not at_start.has(p.id))
	var n := Bank.new_per_day
	var run := {
		"day": key,
		"topic": t.get("concept", null),
		"topic_title": str(t.get("title", "")),
		"new_ids": unsolved.slice(0, n).map(func(p: Dictionary) -> String: return p.id),
		"extra_id": unsolved[n].id if unsolved.size() > n else null,
		"reviews": [],
	}
	runs()[key] = run
	Store.save()
	return run


## The run with its three slots filled in, as the Today page shows them.
func run_status() -> Dictionary:
	var run := today_run()
	var key: String = run.day
	var solved_today := solves_on(key)
	var new_ids: Array = run.new_ids
	var new_done: int = new_ids.filter(func(id: String) -> bool: return is_solved(id)).size()
	var extra_done: bool = is_solved(run.extra_id) if run.extra_id != null else new_ids.size() > 0

	var q := Reviews.due_today(key)
	var pending: Array = q.pending
	var total: int = pending.size() + q.done_today.size()
	var review_slot: Dictionary
	if total == 0:
		var any_rows := Reviews.rows().size() > 0
		review_slot = {"n": "01", "title": "REVIEW", "detail": "nothing due today" if any_rows else "no reviews yet — clear a topic to start them", "done": true, "kind": "review", "first_id": null}
	else:
		var titles := []
		for r in pending:
			var title := Reviews.topic_title(r.topic)
			if not titles.has(title):
				titles.append(title)
		var detail := "%d done today" % q.done_today.size()
		if pending.size() > 0:
			detail = ", ".join(titles) + (" · %d more roll to tomorrow" % q.rolled if q.rolled > 0 else "")
		review_slot = {"n": "01", "title": "REVIEW · %d DUE" % pending.size(), "detail": detail, "done": pending.is_empty(), "kind": "review", "first_id": pending[0].problem_id if pending.size() > 0 else null}

	var first_new: Variant = null
	for id in new_ids:
		if not is_solved(id):
			first_new = id
			break
	var new_slot := {"n": "02", "title": "%s · %d NEW" % [str(run.topic_title).to_upper(), new_ids.size()], "detail": _position_text(run), "done": new_ids.size() > 0 and new_done == new_ids.size(), "kind": "new", "progress": [new_done, new_ids.size()], "first_id": first_new}
	var has_extra: bool = run.extra_id != null
	var extra_slot := {"n": "03", "title": "ONE MORE TOPIC PROBLEM" if has_extra else "ALL TOPIC PROBLEMS DONE", "detail": "milestones come later; one extra for today" if has_extra else "pick the next topic on the route", "done": extra_done, "kind": "extra", "first_id": run.extra_id}

	var slots := [review_slot, new_slot, extra_slot]
	var done_count: int = slots.filter(func(s: Dictionary) -> bool: return s.done).size()
	var all_done := done_count == slots.size()
	if run.get("done", null) != all_done:
		run["done"] = all_done
		Store.save()
	var keep_going: int = solved_today.filter(func(id: String) -> bool: return not new_ids.has(id) and id != run.extra_id).size()
	return {"run": run, "slots": slots, "done_count": done_count, "all_done": all_done, "new_done": new_done, "keep_going": keep_going}


func _position_text(run: Dictionary) -> String:
	var new_ids: Array = run.new_ids
	if run.topic == null or new_ids.is_empty():
		return "nothing left in this topic"
	var list := Bank.problems_in(run.topic)
	var ids: Array = list.map(func(p: Dictionary) -> String: return p.id)
	var first := ids.find(new_ids[0]) + 1
	var last := ids.find(new_ids[-1]) + 1
	return "problems %02d–%02d of %d" % [first, last, list.size()]


func day_done(key: String) -> bool:
	var run: Variant = runs().get(key)
	if run is Dictionary:
		if run.has("done"):
			return bool(run.done)
		var new_ids: Array = run.new_ids
		return new_ids.size() > 0 and new_ids.all(func(id: String) -> bool: return is_solved(id)) and (run.extra_id == null or is_solved(run.extra_id))
	return solves_on(key).size() >= Bank.new_per_day + 1


# ---- streak, level, runs ----

## Days with at least one solve or one review.
func active_days() -> Dictionary:
	var days := {}
	for id in solved():
		days[Streak.day_key(str(solved()[id]))] = true
	for r in Reviews.rows().values():
		if r.get("reviewed_at", null) != null:
			days[Streak.day_key(str(r.reviewed_at))] = true
	days.erase("")
	return days


func streak_days() -> int:
	var days := active_days()
	var t := Time.get_unix_time_from_system()
	if today_override != "":
		t = float(Time.get_unix_time_from_datetime_string(today_override + "T12:00:00"))
	if not days.has(Streak.key_for_unix(t)):
		t -= 86400.0
	var count := 0
	while days.has(Streak.key_for_unix(t)):
		count += 1
		t -= 86400.0
	return count


## Full daily runs finished, all time.
func runs_completed() -> int:
	var count := 0
	for key in runs():
		if day_done(key):
			count += 1
	return count


func level() -> int:
	return route_topics().filter(func(t: Dictionary) -> bool: return not t.get("extra", false) and t.total > 0 and t.done == t.total).size() + 1
