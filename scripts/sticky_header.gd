class_name StickyHeader
extends PanelContainer
## A section header that stays at the top of a scrolling list: as the list
## scrolls, the label shows the title of the section the top edge is in.
## Sits over the scroll area; sections are given after each render.

var label := Label.new()
var _scroll: ScrollContainer
var _sections: Array = []   # [{ "node": Control, "title": String }]


func _init() -> void:
	name = "Sticky"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color("#0b0d10")
	box.border_color = Color("#232b34")
	box.border_width_bottom = 2
	box.content_margin_left = 0
	box.content_margin_right = 0
	box.content_margin_top = 8
	box.content_margin_bottom = 10
	add_theme_stylebox_override("panel", box)
	label.theme_type_variation = &"Small"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)


## Pins a header over the top of scroll: an overlay the size of scroll's
## parent, the header along its top edge. Returns the header.
static func attach(host: Control, scroll: ScrollContainer) -> StickyHeader:
	var overlay := Control.new()
	overlay.name = "StickyOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(overlay)
	var header := StickyHeader.new()
	overlay.add_child(header)
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.grow_vertical = Control.GROW_DIRECTION_END
	header.watch(scroll)
	return header


func watch(scroll: ScrollContainer) -> void:
	_scroll = scroll
	scroll.get_v_scroll_bar().value_changed.connect(func(_v: float) -> void: _update())


func set_sections(sections: Array) -> void:
	_sections = sections
	# The list is laid out after this frame; measure it then.
	_update.call_deferred()


func _update() -> void:
	if _scroll == null:
		return
	var y := float(_scroll.scroll_vertical)
	var current := ""
	for s in _sections:
		var node: Control = s.node
		if not is_instance_valid(node) or not node.visible or node.size.y == 0.0:
			continue
		# The section's top, measured inside the scrolled content.
		var top := node.global_position.y - _scroll.global_position.y + y
		if top <= y + 4.0:
			current = str(s.title)
	visible = current != ""
	label.text = current
