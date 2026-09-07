extends SimplePage
## Hint levels per topic: the automatic level from the pass rate, or one
## set by hand. A tap cycles auto → full → reduced → minimal → auto, like
## the site's selector. Kept in the account settings.


func _ready() -> void:
	super()
	meta.text = "HINT LEVELS"
	Scaffold.changed.connect(render)
	Sync.pulled.connect(render)
	render()


func render() -> void:
	if not is_inside_tree():
		return
	clear_body()
	var intro := Label.new()
	intro.theme_type_variation = &"ProseMuted"
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.text = "Full: every hint opens on request, the solution after 2 misses. Reduced: hint 1 on request, the rest after a miss. Minimal: hints after 2 misses, the solution after 3. Auto follows your pass rate. Tap a topic to change it."
	body.add_child(intro)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 0)
	body.add_child(list)
	for t in Progress.route_topics():
		if t.total == 0 or t.locked:
			continue
		var concept: String = t.concept
		var setting := Scaffold.override_for(concept)
		var st := Scaffold.stats_for(concept)
		var trailing: String = ("auto · %s" % Scaffold.auto_level(concept)) if setting == "" else setting
		if st.rate != null:
			trailing += " · %d%%" % roundi(float(st.rate) * 100.0)
		var row := UI.list_row("", "L%02d · %s" % [int(t.lesson), t.title], trailing, setting != "")
		row.pressed.connect(func() -> void:
			var cycle := ["", "full", "reduced", "minimal"]
			Scaffold.set_override(concept, cycle[(cycle.find(setting) + 1) % cycle.size()]))
		list.add_child(row)
