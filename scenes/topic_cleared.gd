extends PanelContainer
## The topic-cleared screen, like the site's: shown once when the last
## problem of a topic passes (Next › brings you here), and again from the
## Route. The topic, ✓ N/N, the XP it earned, what it unlocked, when its
## reviews start, and one button to the next thing.

var concept := ""

@onready var back: Button = $Column/TopBand/TopMargin/TopBar/Back
@onready var meta: Label = $Column/TopBand/TopMargin/TopBar/Meta
@onready var eyebrow: Label = $Column/Scroll/Margin/Body/Eyebrow
@onready var title: Label = $Column/Scroll/Margin/Body/Title
@onready var tick: Label = $Column/Scroll/Margin/Body/Tick
@onready var facts: VBoxContainer = $Column/Scroll/Margin/Body/Facts
@onready var reviews_note: Label = $Column/Scroll/Margin/Body/Reviews
@onready var go: Button = $Column/Bar/BarMargin/Go


func _ready() -> void:
	back.pressed.connect(func() -> void:
		var app := get_tree().get_first_node_in_group("app")
		queue_free()
		if app:
			app.show_tab("route"))
	Sync.pulled.connect(render)
	render()


func render() -> void:
	if not is_inside_tree():
		return
	var topics := Progress.route_topics()
	var t: Dictionary = {}
	var idx := -1
	for i in topics.size():
		if topics[i].concept == concept:
			t = topics[i]
			idx = i
	for child in facts.get_children():
		facts.remove_child(child)
		child.queue_free()
	for c in go.pressed.get_connections():
		go.pressed.disconnect(c.callable)
	if t.is_empty():
		title.text = "NO SUCH TOPIC"
		tick.text = ""
		go.text = "ROUTE"
		go.pressed.connect(back.pressed.emit)
		return
	var cleared: bool = t.total > 0 and t.done == t.total
	var lesson := "L%02d" % int(t.lesson)
	eyebrow.text = ("// TOPIC CLEARED · %s" if cleared else "// %s · NOT CLEARED YET") % lesson
	title.text = str(t.title).to_upper()
	tick.text = "%s%d/%d" % ["✓ " if cleared else "", t.done, t.total]

	# What this topic unlocked: a milestone waiting behind it, or the next
	# topic on the route.
	var m: Dictionary = {}
	for x in Bank.milestones:
		if x.after == concept and not bool(x.get("planned", false)):
			m = x
			break
	var ms: Dictionary = Progress.milestone_status(m) if not m.is_empty() else {}
	var next_topic: Dictionary = {}
	for x in topics.slice(idx + 1):
		if x.total > 0:
			next_topic = x
			break
	var unlocked: String
	if not ms.is_empty() and ms.unlocked:
		unlocked = "Milestone %d · %s" % [int(m.number), m.title]
	elif not ms.is_empty():
		unlocked = "Milestone %d after %d more topic%s" % [int(m.number), ms.topics_to_go, "" if ms.topics_to_go == 1 else "s"]
	elif not next_topic.is_empty():
		unlocked = "L%02d · %s%s" % [int(next_topic.lesson), next_topic.title, " (locked in the course)" if next_topic.locked else ""]
	else:
		unlocked = "the end of the route"
	facts.add_child(_fact("PROBLEMS", "%d / %d" % [t.done, t.total], false))
	facts.add_child(_fact("XP IN THIS TOPIC", "+%d" % (int(t.done) * Progress.XP_PROBLEM), true))
	facts.add_child(_fact("UNLOCKED", unlocked, false))
	reviews_note.visible = cleared

	if not cleared:
		var next_id := ""
		for p in t.list:
			if not Progress.is_solved(p.id):
				next_id = p.id
				break
		go.text = "CONTINUE · %d TO GO" % (int(t.total) - int(t.done))
		go.pressed.connect(func() -> void: _open_problem(next_id))
		return
	Store.set_value("cleared." + concept, true)   # shown once from Next ›; after that the Route links back
	if not ms.is_empty() and ms.unlocked and not ms.done:
		go.text = "OPEN MILESTONE %d ›" % int(m.number)
		go.pressed.connect(func() -> void:
			var app := get_tree().get_first_node_in_group("app")
			if app:
				app.open_milestone(str(m.id)))
	elif not next_topic.is_empty() and not next_topic.locked:
		var first := ""
		for p in next_topic.list:
			if not Progress.is_solved(p.id):
				first = p.id
				break
		if first == "":
			first = next_topic.list[0].id
		go.text = "START L%02d · %s ›" % [int(next_topic.lesson), str(next_topic.title).to_upper()]
		go.pressed.connect(func() -> void: _open_problem(first))
	else:
		go.text = "BACK TO THE ROUTE"
		go.pressed.connect(back.pressed.emit)


func _fact(label: String, value: String, accent: bool) -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	var k := Label.new()
	k.theme_type_variation = &"Small"
	k.text = label
	column.add_child(k)
	var v := Label.new()
	v.theme_type_variation = &"Accent" if accent else &"Heading3"
	v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.text = value
	column.add_child(v)
	return column


func _open_problem(id: String) -> void:
	var app := get_tree().get_first_node_in_group("app")
	if app and id != "":
		app.open_problem(id)
