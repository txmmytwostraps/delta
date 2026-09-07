class_name VerdictPanel
extends PanelContainer
## One verdict for every mode. After Run, this slides up over the bottom bar
## and stays until one of its buttons is tapped. Pass: "✓ Correct", one line,
## Next › and Review. Fail: "✗ Not yet", the reason, Try again and Hint.
## Nothing else on the screen changes while it is up; the page acts on the
## signals once the panel has gone.

signal next_pressed
signal review_pressed
signal retry_pressed
signal hint_pressed

const ACCENT := Color("#7ef0c2")
const ERROR := Color("#ff7085")
const PANEL := Color("#10141a")
const SLIDE := 0.22

var heading := Label.new()
var line := Label.new()
var primary := Button.new()
var secondary := Button.new()
var passed := false

var _overlay: Control
var _tween: Tween


## Puts a panel over a page (any Control that fills the screen) and returns
## it. It stays hidden until show_pass or show_fail.
static func attach(page: Control) -> VerdictPanel:
	var overlay := Control.new()
	overlay.name = "VerdictOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.add_child(overlay)
	var panel := VerdictPanel.new()
	panel._overlay = overlay
	overlay.add_child(panel)
	return panel


func _init() -> void:
	name = "Verdict"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	add_child(column)
	heading.theme_type_variation = &"Heading"
	heading.clip_text = true
	heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(heading)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.max_lines_visible = 3
	line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(line)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	column.add_child(spacer)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	column.add_child(buttons)
	for button in [primary, secondary]:
		button.custom_minimum_size.y = 88
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		buttons.add_child(button)
	primary.theme_type_variation = &"Primary"
	primary.pressed.connect(func() -> void:
		dismiss()
		if passed:
			next_pressed.emit()
		else:
			retry_pressed.emit())
	secondary.pressed.connect(func() -> void:
		dismiss()
		if passed:
			review_pressed.emit()
		else:
			hint_pressed.emit())


func _ready() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	_overlay.resized.connect(func() -> void:
		if visible and (_tween == null or not _tween.is_running()):
			_place(0.0))


func show_pass(text: String, next_label: String = "NEXT ›") -> void:
	passed = true
	heading.text = "✓ Correct"
	heading.add_theme_color_override("font_color", ACCENT)
	line.text = text
	primary.text = next_label
	secondary.text = "REVIEW"
	_present(ACCENT)


func show_fail(text: String) -> void:
	passed = false
	heading.text = "✗ Not yet"
	heading.add_theme_color_override("font_color", ERROR)
	line.text = text
	primary.text = "TRY AGAIN"
	secondary.text = "HINT"
	_present(ERROR)


func dismiss() -> void:
	if _tween:
		_tween.kill()
	visible = false


func _present(edge: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = PANEL
	box.border_color = edge
	box.border_width_top = 4
	box.content_margin_left = 32
	box.content_margin_right = 32
	box.content_margin_top = 28
	box.content_margin_bottom = 24
	add_theme_stylebox_override("panel", box)
	if _tween:
		_tween.kill()
	# Laid out at full width first (unseen), so the wrapped line has its
	# height; then slid up from below the screen's edge.
	visible = true
	modulate.a = 0.0
	_place(0.0)
	await get_tree().process_frame
	await get_tree().process_frame
	if not visible:
		return
	modulate.a = 1.0
	var h := size.y
	_place(h)
	_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_method(_place, h, 0.0, SLIDE)


## below: how far under the bottom edge the panel sits; 0 is in place.
func _place(below: float) -> void:
	var h := get_combined_minimum_size().y
	offset_left = 0
	offset_right = 0
	offset_top = -h + below
	offset_bottom = below
