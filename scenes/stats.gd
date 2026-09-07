extends SimplePage
## Stats, like the site's: plain numbers and lists from account data. Solves
## from the progress rows, attempts from the attempt log, the queue from the
## reviews. The numbers, the badges, the weak spots, the sixteen-week
## activity grid, and the per-topic table.


func _ready() -> void:
	super()
	Progress.changed.connect(render)
	Scaffold.changed.connect(render)
	Reviews.changed.connect(render)
	Sync.pulled.connect(render)
	render()


## Per-topic tallies from the attempt log: all time and the last 30 days.
static func tallies(topics: Array, attempts: Array, cutoff: String) -> Dictionary:
	var by_topic := {}
	for t in topics:
		by_topic[t.concept] = {"attempts": 0, "misses": 0, "recent_attempts": 0, "recent_misses": 0, "last": ""}
	for a in attempts:
		var p := Bank.problem(str(a.get("problem_id", "")))
		if p.is_empty() or not by_topic.has(p.concept):
			continue
		var b: Dictionary = by_topic[p.concept]
		b.attempts += 1
		var miss: bool = str(a.get("result", "")) == "miss"
		if miss:
			b.misses += 1
		var at := str(a.get("at", ""))
		if Streak.day_key(at) >= cutoff:
			b.recent_attempts += 1
			if miss:
				b.recent_misses += 1
		if at > str(b.last):
			b.last = at
	for id in Progress.solved():
		var p := Bank.problem(str(id))
		if not p.is_empty() and by_topic.has(p.concept) and str(Progress.solved()[id]) > str(by_topic[p.concept].last):
			by_topic[p.concept].last = str(Progress.solved()[id])
	return by_topic


## Weak spots: recent miss rate, at least 3 recent attempts, the worst five.
static func weak_spots(topics: Array, by_topic: Dictionary) -> Array:
	var out := []
	for t in topics:
		var b: Dictionary = by_topic.get(t.concept, {})
		if b.is_empty() or int(b.recent_attempts) < 3:
			continue
		var rate := float(b.recent_misses) / float(b.recent_attempts)
		if rate > 0.0:
			out.append({"topic": t, "rate": rate, "recent_misses": int(b.recent_misses), "recent_attempts": int(b.recent_attempts)})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.rate != b.rate:
			return a.rate > b.rate
		return a.recent_misses > b.recent_misses)
	return out.slice(0, 5)


static func pct(n: int, d: int) -> String:
	return "%d%%" % roundi(100.0 * n / d) if d > 0 else "–"


func render() -> void:
	if not is_inside_tree():
		return
	clear_body()
	var topics: Array = Progress.route_topics().filter(func(t: Dictionary) -> bool: return t.total > 0)
	var total := Bank.problems.size()
	var solved: int = Progress.solved().keys().filter(func(id: String) -> bool: return Bank.has_problem(id)).size()
	var days := Progress.active_days()
	var today := Progress.today_key()
	var cutoff := Reviews.add_days(today, -30)
	var attempts := Scaffold.attempts()
	var misses: int = attempts.filter(func(a: Dictionary) -> bool: return str(a.get("result", "")) == "miss").size()
	var q := Reviews.due_today(today)
	var x := Progress.xp_info()
	var s := Progress.streak()

	var title := Label.new()
	title.theme_type_variation = &"Heading"
	title.text = "STATS"
	body.add_child(title)
	var intro := Label.new()
	intro.theme_type_variation = &"ProseMuted"
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.text = "Attempts are counted from the day the attempt log started; solves and streak go back to your first day."
	body.add_child(intro)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for pair in [["Solved", "%d / %d" % [solved, total], true], ["Streak", "%d day%s" % [int(s.streak), "" if int(s.streak) == 1 else "s"], true], ["Level", "%d · %d XP" % [int(x.level), int(x.xp)], true], ["Active days", str(days.size()), false], ["Full runs", str(Progress.runs_completed()), false], ["Attempts", str(attempts.size()), false], ["Miss rate", pct(misses, attempts.size()), false], ["Reviews in queue", str(Reviews.rows().size()), false], ["Due today", str(q.pending.size()), false]]:
		var tile := UI.tile(pair[0], pair[1], pair[2])
		for child in tile.get_child(0).get_children():
			if child is Label and child.text == str(pair[1]):
				child.theme_type_variation = &"Heading3"
		grid.add_child(tile)
	body.add_child(grid)

	body.add_child(UI.section("Badges, one per milestone"))
	var badges := VBoxContainer.new()
	badges.add_theme_constant_override("separation", 0)
	for m in Progress.milestones():
		var trailing: String
		if m.done:
			trailing = "%s%s" % [Streak.day_key(str(m.done_at)), " · built in Godot" if m.godot_done else ""]
		elif bool(m.get("planned", false)):
			trailing = "planned"
		elif m.unlocked:
			trailing = "%d / %d steps" % [m.steps_done, int(m.steps)]
		else:
			trailing = "%d topic%s to go" % [m.topics_to_go, "" if m.topics_to_go == 1 else "s"]
		var row := UI.list_row("✓" if m.done else "", "Milestone %d · %s%s" % [int(m.number), m.title, (" · " + str(m.badge)) if m.done and m.has("badge") else ""], trailing, false, not m.done)
		var mid := str(m.id)
		row.pressed.connect(func() -> void:
			if m.done:
				app().open_gallery()
			else:
				app().show_tab("route"))
		badges.add_child(row)
	body.add_child(badges)

	body.add_child(UI.section("Weak spots · most misses in the last 30 days"))
	var by_topic := tallies(topics, attempts, cutoff)
	var weak := weak_spots(topics, by_topic)
	if weak.is_empty():
		var none := Label.new()
		none.theme_type_variation = &"ProseMuted"
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.text = "No topic has enough recent misses to stand out." if attempts.size() > 0 else "Nothing yet: weak spots appear after a few runs are logged."
		body.add_child(none)
	else:
		var list := VBoxContainer.new()
		list.add_theme_constant_override("separation", 0)
		for w in weak:
			var t: Dictionary = w.topic
			var row := UI.list_row("", "%s · L%02d" % [t.title, int(t.lesson)], "%s missed · %d of %d" % [pct(w.recent_misses, w.recent_attempts), w.recent_misses, w.recent_attempts])
			row.pressed.connect(func() -> void: app().open_topic_problems(t.concept))
			list.add_child(row)
		body.add_child(list)

	body.add_child(UI.section("Streak history · active days, 16 weeks"))
	body.add_child(_weeks(days, today))
	var legend := Label.new()
	legend.theme_type_variation = &"Detail"
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var start := _grid_start(today)
	var recent: int = days.keys().filter(func(k: String) -> bool: return k >= start).size()
	legend.text = "%d active days in the last 16 weeks · a day counts when it has at least one solve or review" % recent
	body.add_child(legend)

	body.add_child(UI.section("Per topic"))
	var table := VBoxContainer.new()
	table.add_theme_constant_override("separation", 0)
	for t in topics:
		var b: Dictionary = by_topic[t.concept]
		var line := "%d/%d solved · %d attempt%s · %d miss%s · %s" % [t.done, t.total, b.attempts, "" if b.attempts == 1 else "s", b.misses, "" if b.misses == 1 else "es", pct(b.misses, b.attempts)]
		if b.recent_attempts > 0:
			line += " · last 30 days %s of %d" % [pct(b.recent_misses, b.recent_attempts), b.recent_attempts]
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 0)
		var row := UI.list_row("", "L%02d · %s" % [int(t.lesson), t.title], Streak.day_key(str(b.last)) if str(b.last) != "" else "", false, t.locked)
		row.pressed.connect(func() -> void: app().open_topic_problems(t.concept))
		column.add_child(row)
		var detail := Label.new()
		detail.theme_type_variation = &"Detail"
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.text = line
		var pad := MarginContainer.new()
		pad.add_theme_constant_override("margin_left", 24)
		pad.add_theme_constant_override("margin_bottom", 12)
		pad.add_child(detail)
		column.add_child(pad)
		table.add_child(column)
	body.add_child(table)


## The Sunday that starts the grid: 16 weeks back from this week's Sunday.
static func _grid_start(today: String) -> String:
	var noon := Time.get_unix_time_from_datetime_string(today + "T12:00:00")
	var weekday: int = Time.get_datetime_dict_from_unix_time(noon).weekday   # 0 Sunday
	return Reviews.add_days(today, -weekday - 7 * 15)


## Columns are weeks, rows Sunday to Saturday, like the site's grid.
func _weeks(days: Dictionary, today: String) -> Control:
	var start := _grid_start(today)
	var grid := GridContainer.new()
	grid.columns = 16
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for row in 7:
		for col in 16:
			var key := Reviews.add_days(start, col * 7 + row)
			var cell := ColorRect.new()
			cell.custom_minimum_size = Vector2(32, 32)
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var future := key > today
			cell.color = Color("#0b0d10") if future else (Color("#7ef0c2") if days.has(key) else Color("#232b34"))
			if key == today and not days.has(key):
				cell.color = Color("#344050")
			grid.add_child(cell)
	return grid
