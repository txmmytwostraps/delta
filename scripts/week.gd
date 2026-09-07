class_name Week
## The weekly summary: the last seven days as plain text, ending with the
## adjustments the numbers suggest. Word for word the site's This week page.


static func build() -> String:
	var days := []
	var now := Time.get_unix_time_from_system()
	if Progress.today_override != "":
		now = float(Time.get_unix_time_from_datetime_string(Progress.today_override + "T12:00:00"))
	for i in range(6, -1, -1):
		days.append(Streak.key_for_unix(now - i * 86400.0))
	var from: String = days[0]
	var to: String = days[6]
	var in_week := func(iso: Variant) -> bool:
		if iso == null or str(iso) == "":
			return false
		var k := Streak.day_key(str(iso))
		return k >= from and k <= to
	var week: Array = Scaffold.attempts().filter(func(a: Dictionary) -> bool: return in_week.call(a.get("at", null)))
	var active := Progress.active_days()
	var solved := Progress.solved()
	var solved_week: Array = solved.keys().filter(func(id: String) -> bool: return Bank.has_problem(id) and in_week.call(solved[id]))
	var solved_all: int = solved.keys().filter(func(id: String) -> bool: return Bank.has_problem(id)).size()
	var hintlog: Array = _hintlog().filter(func(h: Dictionary) -> bool: return in_week.call(h.get("at", null)))
	var rows: Array = Reviews.rows().values()
	var out := []
	out.append("GDScript practice — week %s to %s" % [from, to])
	var active_week: int = days.filter(func(k: String) -> bool: return active.has(k)).size()
	var full_runs: int = days.filter(func(k: String) -> bool: return Progress.day_done(k)).size()
	out.append("Streak %d · active days this week %d of 7 · full runs this week %d (all time %d) · daily set %d" % [Progress.streak_days(), active_week, full_runs, Progress.runs_completed(), Progress.new_per_day()])
	out.append("Solved this week: %d problems (%d of %d overall)" % [solved_week.size(), solved_all, Bank.problems.size()])
	out.append("")

	# per topic
	out.append("Per topic (topics with activity this week)")
	var topics: Array = Progress.route_topics().filter(func(t: Dictionary) -> bool: return t.total > 0)
	var topic_lines := []
	for t in topics:
		var ids := {}
		for p in t.list:
			ids[p.id] = true
		var a: Array = week.filter(func(x: Dictionary) -> bool: return ids.has(str(x.get("problem_id", ""))))
		var solves: int = solved_week.filter(func(id: String) -> bool: return ids.has(id)).size()
		var hints: int = hintlog.filter(func(h: Dictionary) -> bool: return ids.has(str(h.get("id", "")))).size()
		if a.is_empty() and solves == 0 and hints == 0:
			continue
		var misses: int = a.filter(func(x: Dictionary) -> bool: return str(x.get("result", "")) == "miss").size()
		var st := Scaffold.stats_for(t.concept)
		var line := "- %s (%s): attempts %d, solves %d, misses %d, pass rate %s, hints opened %d, hint level %s%s" % [
			t.title, _lesson_tag(t), a.size(), solves, misses, _pct(a.size() - misses, a.size()), hints, Scaffold.level_for(t.concept),
			" (set by hand)" if Scaffold.override_for(t.concept) != "" else " (auto)"]
		if st.rate != null:
			line += ", rolling %d%% over last %d" % [roundi(float(st.rate) * 100.0), mini(20, int(st.attempts))]
		topic_lines.append(line)
	out.append_array(topic_lines if topic_lines.size() > 0 else ["- no activity this week"])
	out.append("")

	# reviews
	var done: Array = rows.filter(func(r: Dictionary) -> bool: return in_week.call(r.get("reviewed_at", null)))
	var pr: Array = done.filter(func(r: Dictionary) -> bool: return not Bank.is_card_id(str(r.problem_id)))
	var cr: Array = done.filter(func(r: Dictionary) -> bool: return Bank.is_card_id(str(r.problem_id)))
	out.append("Reviews")
	out.append("- problems: %d done, %d passed, %d missed" % [pr.size(), _count(pr, "pass"), _count(pr, "miss")])
	out.append("- concept cards: %d done, %d got it, %d not yet" % [cr.size(), _count(cr, "pass"), _count(cr, "miss")])
	out.append("")

	# notes
	var week_notes: Array = Notes.list().filter(func(n: Dictionary) -> bool: return in_week.call(n.get("updated_at", null)))
	out.append("Notes written this week (unresolved first)")
	if week_notes.is_empty():
		out.append("- none")
	for n in week_notes:
		var p := Bank.problem(str(n.problem_id))
		var text := str(n.get("text", "")).strip_edges()
		var re := RegEx.new()
		re.compile("\\s+")
		out.append("- [%s] %s: %s" % ["resolved" if bool(n.get("resolved", false)) else "open", p.get("title", n.problem_id), re.sub(text, " ", true)])
	out.append("")

	# missed more than once
	var miss_count := {}
	for a in week:
		if str(a.get("result", "")) == "miss":
			var id := str(a.get("problem_id", ""))
			miss_count[id] = int(miss_count.get(id, 0)) + 1
	var repeat: Array = miss_count.keys().filter(func(id: String) -> bool: return int(miss_count[id]) > 1)
	repeat.sort_custom(func(x: String, y: String) -> bool: return int(miss_count[x]) > int(miss_count[y]))
	out.append("Problems missed more than once this week")
	if repeat.is_empty():
		out.append("- none")
	for id in repeat:
		var p := Bank.problem(id)
		var t := Bank.topic(str(p.get("concept", "")))
		out.append("- %s%s: %d misses" % [p.get("title", id), " (%s, %s)" % [t.title, _lesson_tag(t)] if not t.is_empty() else "", int(miss_count[id])])
	out.append("")

	# due next week
	out.append("Due next week")
	var next_days := []
	for i in range(1, 8):
		next_days.append(Streak.key_for_unix(now + i * 86400.0))
	var overdue: Array = rows.filter(func(r: Dictionary) -> bool:
		return str(r.due_on) <= to and not (r.get("reviewed_at", null) != null and Streak.day_key(str(r.reviewed_at)) == str(r.due_on)))
	var due_lines := []
	for k in next_days:
		var p: int = rows.filter(func(r: Dictionary) -> bool: return str(r.due_on) == k and not Bank.is_card_id(str(r.problem_id))).size()
		var c: int = rows.filter(func(r: Dictionary) -> bool: return str(r.due_on) == k and Bank.is_card_id(str(r.problem_id))).size()
		if p > 0 or c > 0:
			due_lines.append("- %s: %d problem%s, %d card%s" % [k, p, "" if p == 1 else "s", c, "" if c == 1 else "s"])
	if overdue.size() > 0:
		var op: int = overdue.filter(func(r: Dictionary) -> bool: return not Bank.is_card_id(str(r.problem_id))).size()
		due_lines.insert(0, "- already due: %d problems, %d cards" % [op, overdue.size() - op])
	out.append_array(due_lines if due_lines.size() > 0 else ["- nothing scheduled"])
	out.append("")

	# proposed adjustments
	out.append("Proposed adjustments")
	var props := []
	for t in topics:
		var st := Scaffold.stats_for(t.concept)
		if st.rate == null or Scaffold.override_for(t.concept) != "":
			continue
		var lv := Scaffold.level_for(t.concept)
		var n := mini(20, int(st.attempts))
		var rate := float(st.rate)
		if n >= 15 and rate > 0.85 and lv != "minimal":
			props.append("- Raise the hint level on %s from %s: %d%% over the last %d attempts." % [t.title, lv, roundi(rate * 100.0), n])
		if n >= 10 and rate < 0.65 and lv != "full":
			props.append("- Lower the hint level on %s from %s: %d%% over the last %d attempts." % [t.title, lv, roundi(rate * 100.0), n])
	var per_day := Progress.new_per_day()
	if full_runs >= 5 and per_day < 8:
		props.append("- Daily set: %d → %d new problems. Full runs on %d of 7 days." % [per_day, per_day + 1, full_runs])
	elif active_week >= 3 and full_runs <= 1 and per_day > 3:
		props.append("- Daily set: %d → %d new problems. Active %d days but only %d full run." % [per_day, per_day - 1, active_week, full_runs])
	var drillable: Array = topics.filter(func(t: Dictionary) -> bool:
		var st := Scaffold.stats_for(t.concept)
		return t.list.any(func(p: Dictionary) -> bool: return p.has("generator")) and st.rate != null and mini(20, int(st.attempts)) >= 5)
	drillable.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(Scaffold.stats_for(x.concept).rate) < float(Scaffold.stats_for(y.concept).rate))
	if drillable.size() > 0 and float(Scaffold.stats_for(drillable[0].concept).rate) < 0.8:
		out.append_array([])
		props.append("- Drill %s: the lowest pass rate with variants available, %d%%." % [drillable[0].title, roundi(float(Scaffold.stats_for(drillable[0].concept).rate) * 100.0)])
	out.append_array(props if props.size() > 0 else ["- No changes proposed: keep going as you are."])
	return "\n".join(out)


## Hints opened, kept for the summary: [{ "id", "hint", "at" }], the last 500.
static func _hintlog() -> Array:
	if not (Store.data.get("hintlog") is Array):
		Store.data["hintlog"] = []
	return Store.data["hintlog"]


static func log_hint(problem_id: String, hint: int) -> void:
	var log := _hintlog()
	log.append({"id": problem_id, "hint": hint, "at": Progress.now_iso()})
	if log.size() > 500:
		Store.data["hintlog"] = log.slice(log.size() - 500)
	Store.save()


static func _pct(n: int, d: int) -> String:
	return "%d%%" % roundi(100.0 * n / d) if d > 0 else "–"


static func _lesson_tag(t: Dictionary) -> String:
	return "L%02d" % int(t.get("lesson", 0))


static func _count(rows: Array, result: String) -> int:
	return rows.filter(func(r: Dictionary) -> bool: return str(r.get("last_result", "")) == result).size()
