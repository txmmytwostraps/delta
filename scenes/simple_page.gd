class_name SimplePage
extends PanelContainer
## The shape every small page shares (page.tscn): a Back button and a
## label on top, a scrolling body, and a bottom bar with one button that
## shows only when it has something to do.

@onready var back: Button = $Column/TopBand/TopMargin/TopBar/Back
@onready var meta: Label = $Column/TopBand/TopMargin/TopBar/Meta
@onready var scroll: ScrollContainer = $Column/Scroll
@onready var body: VBoxContainer = $Column/Scroll/Margin/Body
@onready var bar: PanelContainer = $Column/Bar
@onready var go: Button = $Column/Bar/BarMargin/Go


func _ready() -> void:
	back.pressed.connect(close)


func close() -> void:
	queue_free()


func app() -> Node:
	return get_tree().get_first_node_in_group("app")


func clear_body() -> void:
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()


## The one button: shown with text and an action, or hidden.
func set_action(text: String, on_press: Callable) -> void:
	for c in go.pressed.get_connections():
		go.pressed.disconnect(c.callable)
	bar.visible = text != ""
	go.text = text
	if text != "":
		go.pressed.connect(on_press)
