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


# ---- settings kept on the phone ----

## "finished through lesson N". Lives in the account settings, like the
## daily set size, so the site and the phone agree.
func course_lock() -> int:
	return Settings.course_lock()


func set_course_lock(n: int) -> void:
	Settings.set_course_lock(n)
	changed.emit()


## New problems in the day's run.
func new_per_day() -> int:
	return Settings.new_per_day()


func set_new_per_day(n: int) -> void:
	Settings.set_new_per_day(n)
	changed.emit()


## "HH:MM" for the review reminder; "" for none.
func reminder_time() -> String:
	return str(Store.get_value("reminder_time", "19:00"))


func set_reminder_time(hhmm: String) -> void:
	Store.set_value("reminder_time", hhmm)
	changed.emit()


# ---- time spent today (while the app is in front) ----

func minutes_today() -> int:
	return int(float(Store.section("time").get(today_key(), 0)) / 60.0)


## Called by the app once a while with the seconds since the last call.
func add_time(seconds: float) -> void:
	var t := Store.section("time")
	t[today_key()] = float(t.get(today_key(), 0)) + seconds
	Store.save()


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


## Milestones: unlocked once every topic up to `after` is cleared; built in
## steps whose ids (m1-s1 …) live in the solved map like problems do, so
## they sync with the account for free.
func milestone_status(m: Dictionary) -> Dictionary:
	var all := route_topics()
	var idx := -1
	for i in all.size():
		if all[i].concept == m.after:
			idx = i
			break
	var before: Array = all.slice(0, idx + 1).filter(func(t: Dictionary) -> bool: return t.total > 0)
	var to_go: int = before.filter(func(t: Dictionary) -> bool: return t.done < t.total).size()
	var step_ids := []
	for i in int(m.get("steps", 0)):
		step_ids.append("%s-s%d" % [m.id, i + 1])
	var steps_done: int = step_ids.filter(func(id: String) -> bool: return is_solved(id)).size()
	var done: bool = not bool(m.get("planned", false)) and steps_done == int(m.get("steps", 0))
	var done_at: Variant = null
	if done:
		var dates: Array = step_ids.map(func(id: String) -> String: return str(solved()[id]))
		dates.sort()
		done_at = dates[-1]
	var out: Dictionary = m.duplicate()
	out["unlocked"] = to_go == 0
	out["topics_to_go"] = to_go
	out["step_ids"] = step_ids
	out["steps_done"] = steps_done
	out["done"] = done
	out["done_at"] = done_at
	out["godot_done"] = is_solved("%s-godot" % m.id)
	return out


func milestones() -> Array:
	return Bank.milestones.map(milestone_status)


func next_milestone() -> Dictionary:
	for m in milestones():
		if not m.done:
			return m
	return {}


func marker_for(t: Dictionary) -> String:
	if t.locked:
		return "[#]"
	if t.done == t.total and t.total > 0:
		return "✓"
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
	var n := new_per_day()
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

	# Slot 01: the review queue, problems and concept cards together, as the
	# site shows it.
	var q := Reviews.due_today(key)
	var cq := Reviews.cards_due_today(key)
	var pending: Array = q.pending
	var card_pending: int = cq.pending.size()
	var total: int = pending.size() + q.done_today.size() + card_pending + cq.done_today.size()
	var pending_all: int = pending.size() + card_pending
	var review_slot: Dictionary
	if total == 0:
		var any_rows := Reviews.rows().size() > 0
		review_slot = {"n": "01", "title": "REVIEW", "detail": "nothing due today" if any_rows else "no reviews yet — solve a problem to start its concept cards, clear a topic to start its problems", "done": true, "kind": "review", "first_id": null}
	else:
		var titles := []
		for r in pending:
			var title := Reviews.topic_title(r.topic)
			if not titles.has(title):
				titles.append(title)
		var parts := []
		if titles.size() > 0:
			parts.append(", ".join(titles))
		if card_pending > 0:
			parts.append("%d concept card%s" % [card_pending, "" if card_pending == 1 else "s"])
		var detail := "%d done today" % (q.done_today.size() + cq.done_today.size())
		if pending_all > 0:
			detail = " · ".join(parts) + (" · %d more roll to tomorrow" % q.rolled if q.rolled > 0 else "")
		# first_id: the first problem due, or "cards" when only cards are left.
		var first: Variant = pending[0].problem_id if pending.size() > 0 else ("cards" if card_pending > 0 else null)
		review_slot = {"n": "01", "title": "REVIEW · %d DUE" % pending_all, "detail": detail, "done": pending_all == 0, "kind": "review", "first_id": first}

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
	return solves_on(key).size() >= new_per_day() + 1


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


## Days with a full run, by the site's dayDone rule: a day with a run record
## counts when that run was completed (every review due that day done, the
## day's new problems solved, and the extra topic problem when there was
## one); a day with no run record counts when it has new_per_day + 1 or
## more solves.
func full_run_days() -> Dictionary:
	var out := {}
	var counts := {}
	for id in solved():
		var key := Streak.day_key(str(solved()[id]))
		if key != "":
			counts[key] = int(counts.get(key, 0)) + 1
	for key in counts:
		if not runs().has(key) and int(counts[key]) >= new_per_day() + 1:
			out[key] = true
	for key in runs():
		if day_done(key):
			out[key] = true
	return out


## The streak with rest days: see "The streak rule" in sync.gd.
func streak() -> Dictionary:
	return Streak.compute(active_days(), full_run_days(), today_key())


func streak_days() -> int:
	return int(streak().streak)


## Full daily runs finished, all time.
func runs_completed() -> int:
	var count := 0
	for key in runs():
		if day_done(key):
			count += 1
	return count


func level() -> int:
	return route_topics().filter(func(t: Dictionary) -> bool: return not t.get("extra", false) and t.total > 0 and t.done == t.total).size() + 1
