extends SimplePage
## Any problem: one topic's problems as rows, in site order, a tick on the
## solved ones. Drill at the bottom when the topic can roll fresh numbers.

var concept := ""


func _ready() -> void:
	super()
	Progress.changed.connect(render)
	Sync.pulled.connect(render)
	render()


func render() -> void:
	if not is_inside_tree():
		return
	var t := Progress.topic_stats(Bank.topic(concept))
	meta.text = "L%02d · %d / %d" % [int(Bank.topic(concept).get("lesson", 0)), t.done, t.total]
	clear_body()
	var title := Label.new()
	title.theme_type_variation = &"Heading2"
	title.text = Bank.topic_title(concept).to_upper()
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(title)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 0)
	body.add_child(list)
	var i := 0
	for p in t.list:
		i += 1
		var solved := Progress.is_solved(p.id)
		var row := UI.list_row("✓" if solved else "%02d" % i, str(p.title), "" if solved else ("%d miss%s" % [int(Progress.fails().get(p.id, 0)), "" if int(Progress.fails().get(p.id, 0)) == 1 else "es"] if Progress.fails().get(p.id, 0) else ""))
		row.pressed.connect(func() -> void: app().open_problem(p.id))
		list.add_child(row)
	if t.list.any(Variants.can_drill):
		set_action("DRILL · FRESH NUMBERS", func() -> void: app().open_drill(concept))
	else:
		set_action("", Callable())
