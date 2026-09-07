extends MarginContainer
## Every problem in the bank: the topics in route order, then the problems
## of the chosen topic.

@onready var topic_list: VBoxContainer = $Scroll/Body/TopicList
@onready var topic_view: VBoxContainer = $Scroll/Body/TopicView
@onready var back: Button = $Scroll/Body/TopicView/Back
@onready var topic_title: Label = $Scroll/Body/TopicView/TopicTitle
@onready var topic_note: Label = $Scroll/Body/TopicView/TopicNote
@onready var problems: VBoxContainer = $Scroll/Body/TopicView/Problems

var _concept := ""


func _ready() -> void:
	back.pressed.connect(show_topics)
	Progress.changed.connect(render)
	Sync.pulled.connect(render)
	render()


func show_topics() -> void:
	_concept = ""
	render()


func show_topic(concept: String) -> void:
	_concept = concept
	render()


func render() -> void:
	if not is_inside_tree():
		return
	topic_list.visible = _concept == ""
	topic_view.visible = _concept != ""
	if _concept == "":
		_render_topics()
	else:
		_render_topic()


func _render_topics() -> void:
	_clear(topic_list)
	for t in Progress.route_topics():
		if t.total == 0:
			continue
		var button := Button.new()
		button.theme_type_variation = &"Row"
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 88
		var right: String = "locked · L%d" % int(t.lesson) if t.locked else "%d/%d" % [t.done, t.total]
		button.text = "%s L%02d %s   %s" % [Progress.marker_for(t), int(t.lesson), t.title, right]
		if t.locked:
			button.disabled = true
		button.pressed.connect(func() -> void: show_topic(t.concept))
		topic_list.add_child(button)


func _render_topic() -> void:
	var t := Progress.topic_stats(Bank.topic(_concept))
	topic_title.text = Bank.topic_title(_concept).to_upper()
	topic_note.text = "%d of %d solved · lesson %d" % [t.done, t.total, int(Bank.topic(_concept).get("lesson", 0))]
	_clear(problems)
	var i := 0
	for p in t.list:
		i += 1
		var button := Button.new()
		button.theme_type_variation = &"Row"
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 88
		button.text = "%s %02d %s" % ["[x]" if Progress.is_solved(p.id) else "[ ]", i, p.title]
		button.pressed.connect(func() -> void:
			var app := get_tree().get_first_node_in_group("app")
			if app:
				app.open_problem(p.id))
		problems.add_child(button)


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
