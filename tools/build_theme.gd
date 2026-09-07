extends SceneTree
## Builds res://theme/delta.tres from the design tokens.
##
## The theme is a saved file so scenes look right in the editor too. After a
## change here, rebuild it from the project folder:
##   godot --headless --import --quit
##   godot --headless -s tools/build_theme.gd
##
## Sizes are in canvas pixels. The canvas is 720 wide, which is a 360-point
## phone at 2x, so every number here is twice its size on the site.

const BG := Color("#0b0d10")
const PANEL := Color("#10141a")
const LINE := Color("#1c2229")
const LINE_STRONG := Color("#2a323b")
const MUTED := Color("#8a95a0")
const DIM := Color("#4e5a66")
const TEXT := Color("#e8ecef")
const ACCENT := Color("#7ef0c2")
const ACCENT_HOVER := Color("#b3f7dc")
const MILESTONE := Color("#e2b153")
const ERROR := Color("#ff7085")
const CLEAR := Color(0, 0, 0, 0)

const OUT := "res://theme/delta.tres"
const FONT_DIR := "res://assets/fonts/"
## The OpenType axis tag "wght", as the number Godot wants it in.
const WGHT := 2003265652


func _init() -> void:
	var theme := Theme.new()

	var mono := _font("IBMPlexMono-Regular.ttf")
	var mono_medium := _font("IBMPlexMono-Medium.ttf")
	var mono_semibold := _font("IBMPlexMono-SemiBold.ttf")
	var head := _weight(_font("SpaceGrotesk-Variable.ttf"), 700)
	var head_medium := _weight(_font("SpaceGrotesk-Variable.ttf"), 500)
	var spaced := _spaced(mono_medium, 3)

	if mono:
		theme.default_font = mono
	theme.default_font_size = 28

	# ---- labels ----
	theme.set_color("font_color", "Label", TEXT)
	_label(theme, "Heading", head, 52, TEXT)
	_label(theme, "Heading2", head, 48, TEXT)
	_label(theme, "Heading3", head_medium, 36, TEXT)
	_label(theme, "RowTitle", head_medium, 30, TEXT)
	_label(theme, "Big", head, 128, ACCENT)
	_label(theme, "Eyebrow", spaced, 22, ACCENT)
	_label(theme, "Small", spaced, 22, MUTED)
	_label(theme, "Muted", mono, 28, MUTED)
	_label(theme, "Dim", mono, 28, DIM)
	_label(theme, "Accent", mono, 28, ACCENT)
	_label(theme, "Amber", mono, 28, MILESTONE)
	_label(theme, "Error", mono, 26, ERROR)

	# ---- buttons: outlined by default, filled for the main action ----
	_font_of(theme, "Button", mono_medium, 26)
	theme.set_stylebox("normal", "Button", _box(CLEAR, LINE_STRONG, 2, 32, 26))
	theme.set_stylebox("hover", "Button", _box(CLEAR, ACCENT, 2, 32, 26))
	theme.set_stylebox("pressed", "Button", _box(PANEL, ACCENT, 2, 32, 26))
	theme.set_stylebox("disabled", "Button", _box(CLEAR, LINE, 2, 32, 26))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", TEXT)
	theme.set_color("font_pressed_color", "Button", ACCENT)
	theme.set_color("font_hover_pressed_color", "Button", ACCENT)
	theme.set_color("font_focus_color", "Button", TEXT)
	theme.set_color("font_disabled_color", "Button", DIM)

	theme.set_type_variation("Primary", "Button")
	_font_of(theme, "Primary", mono_semibold, 26)
	theme.set_stylebox("normal", "Primary", _box(ACCENT, ACCENT, 2, 40, 26))
	theme.set_stylebox("hover", "Primary", _box(ACCENT_HOVER, ACCENT_HOVER, 2, 40, 26))
	theme.set_stylebox("pressed", "Primary", _box(ACCENT_HOVER, ACCENT_HOVER, 2, 40, 26))
	theme.set_stylebox("disabled", "Primary", _box(Color(ACCENT, 0.45), Color(ACCENT, 0.0), 2, 40, 26))
	theme.set_color("font_color", "Primary", BG)
	theme.set_color("font_hover_color", "Primary", BG)
	theme.set_color("font_pressed_color", "Primary", BG)
	theme.set_color("font_hover_pressed_color", "Primary", BG)
	theme.set_color("font_focus_color", "Primary", BG)
	theme.set_color("font_disabled_color", "Primary", BG)

	# A text-only button that reads as a link.
	theme.set_type_variation("Link", "Button")
	_font_of(theme, "Link", mono_medium, 26)
	for state in ["normal", "hover", "pressed", "disabled"]:
		theme.set_stylebox(state, "Link", _box(CLEAR, CLEAR, 0, 8, 20))
	theme.set_color("font_color", "Link", ACCENT)
	theme.set_color("font_hover_color", "Link", ACCENT_HOVER)
	theme.set_color("font_pressed_color", "Link", ACCENT_HOVER)
	theme.set_color("font_hover_pressed_color", "Link", ACCENT_HOVER)
	theme.set_color("font_focus_color", "Link", ACCENT)
	theme.set_color("font_disabled_color", "Link", DIM)

	# Bottom tabs: a bar of accent along the top marks the active one.
	theme.set_type_variation("Tab", "Button")
	_font_of(theme, "Tab", _spaced(mono_medium, 2), 22)
	theme.set_stylebox("normal", "Tab", _tab_box(CLEAR))
	theme.set_stylebox("hover", "Tab", _tab_box(CLEAR))
	theme.set_stylebox("pressed", "Tab", _tab_box(ACCENT))
	theme.set_stylebox("disabled", "Tab", _tab_box(CLEAR))
	theme.set_color("font_color", "Tab", MUTED)
	theme.set_color("font_hover_color", "Tab", TEXT)
	theme.set_color("font_pressed_color", "Tab", ACCENT)
	theme.set_color("font_hover_pressed_color", "Tab", ACCENT)
	theme.set_color("font_focus_color", "Tab", MUTED)

	# A full-width row in a list (topics, problems).
	theme.set_type_variation("Row", "Button")
	_font_of(theme, "Row", mono, 26)
	theme.set_stylebox("normal", "Row", _box(PANEL, LINE, 2, 28, 26))
	theme.set_stylebox("hover", "Row", _box(PANEL, LINE_STRONG, 2, 28, 26))
	theme.set_stylebox("pressed", "Row", _box(PANEL, ACCENT, 2, 28, 26))
	theme.set_stylebox("disabled", "Row", _box(PANEL, LINE, 2, 28, 26))
	theme.set_color("font_color", "Row", TEXT)
	theme.set_color("font_hover_color", "Row", TEXT)
	theme.set_color("font_pressed_color", "Row", ACCENT)
	theme.set_color("font_hover_pressed_color", "Row", ACCENT)
	theme.set_color("font_focus_color", "Row", TEXT)
	theme.set_color("font_disabled_color", "Row", DIM)

	_label(theme, "Code", mono, 28, TEXT)
	theme.set_stylebox("normal", "TextEdit", _box(BG, LINE_STRONG, 2, 20, 20))
	theme.set_stylebox("focus", "TextEdit", _box(BG, ACCENT, 2, 20, 20))
	theme.set_stylebox("read_only", "TextEdit", _box(PANEL, LINE, 2, 20, 20))
	_font_of(theme, "TextEdit", mono, 26)
	theme.set_color("font_color", "TextEdit", TEXT)
	theme.set_color("font_placeholder_color", "TextEdit", DIM)
	theme.set_color("caret_color", "TextEdit", ACCENT)
	theme.set_color("selection_color", "TextEdit", Color(ACCENT, 0.3))
	theme.set_color("background_color", "TextEdit", BG)

	# Segmented control: equal boxes, the active one filled.
	theme.set_type_variation("Segment", "Button")
	_font_of(theme, "Segment", _spaced(mono_medium, 2), 22)
	theme.set_stylebox("normal", "Segment", _box(CLEAR, LINE_STRONG, 2, 16, 18))
	theme.set_stylebox("hover", "Segment", _box(CLEAR, LINE_STRONG, 2, 16, 18))
	theme.set_stylebox("pressed", "Segment", _box(ACCENT, ACCENT, 2, 16, 18))
	theme.set_stylebox("disabled", "Segment", _box(CLEAR, LINE, 2, 16, 18))
	theme.set_stylebox("focus", "Segment", StyleBoxEmpty.new())
	theme.set_color("font_color", "Segment", MUTED)
	theme.set_color("font_hover_color", "Segment", TEXT)
	theme.set_color("font_pressed_color", "Segment", BG)
	theme.set_color("font_hover_pressed_color", "Segment", BG)
	theme.set_color("font_focus_color", "Segment", MUTED)
	theme.set_color("font_disabled_color", "Segment", DIM)

	# Detail lines under a check: body font, one step smaller.
	_label(theme, "Detail", mono, 26, MUTED)
	_label(theme, "DetailCode", mono, 26, TEXT)

	# ---- text fields ----
	_font_of(theme, "LineEdit", mono, 28)
	theme.set_stylebox("normal", "LineEdit", _box(BG, LINE_STRONG, 2, 24, 24))
	theme.set_stylebox("focus", "LineEdit", _box(BG, ACCENT, 2, 24, 24))
	theme.set_stylebox("read_only", "LineEdit", _box(PANEL, LINE, 2, 24, 24))
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_color("font_placeholder_color", "LineEdit", DIM)
	theme.set_color("caret_color", "LineEdit", ACCENT)
	theme.set_color("selection_color", "LineEdit", Color(ACCENT, 0.3))
	theme.set_constant("minimum_character_width", "LineEdit", 4)

	# ---- the code editor ----
	_font_of(theme, "CodeEdit", mono, 26)
	theme.set_stylebox("normal", "CodeEdit", _box(BG, LINE_STRONG, 2, 16, 16))
	theme.set_stylebox("focus", "CodeEdit", _box(BG, ACCENT, 2, 16, 16))
	theme.set_stylebox("read_only", "CodeEdit", _box(PANEL, LINE, 2, 16, 16))
	theme.set_color("font_color", "CodeEdit", TEXT)
	theme.set_color("font_placeholder_color", "CodeEdit", DIM)
	theme.set_color("caret_color", "CodeEdit", ACCENT)
	theme.set_color("selection_color", "CodeEdit", Color(ACCENT, 0.3))
	theme.set_color("background_color", "CodeEdit", BG)
	theme.set_color("current_line_color", "CodeEdit", Color(TEXT, 0.04))
	theme.set_color("line_number_color", "CodeEdit", DIM)
	theme.set_color("brace_mismatch_color", "CodeEdit", ERROR)
	theme.set_color("word_highlighted_color", "CodeEdit", Color(ACCENT, 0.15))
	theme.set_constant("line_spacing", "CodeEdit", 8)

	# ---- panels ----
	theme.set_stylebox("panel", "PanelContainer", _box(PANEL, LINE, 2, 24, 24))
	theme.set_stylebox("panel", "Panel", _box(PANEL, LINE, 2, 0, 0))
	theme.set_type_variation("PanelActive", "PanelContainer")
	theme.set_stylebox("panel", "PanelActive", _box(PANEL, ACCENT, 2, 24, 24))
	theme.set_type_variation("BottomBar", "PanelContainer")
	var bar := _box(PANEL, LINE, 0, 0, 0)
	bar.border_width_top = 2
	theme.set_stylebox("panel", "BottomBar", bar)
	# A page that sits over a screen and hides it.
	theme.set_type_variation("Backdrop", "PanelContainer")
	theme.set_stylebox("panel", "Backdrop", _box(BG, BG, 0, 0, 0))

	theme.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())

	var rule := StyleBoxLine.new()
	rule.color = LINE
	rule.thickness = 2
	theme.set_stylebox("separator", "HSeparator", rule)
	theme.set_constant("separation", "HSeparator", 2)

	theme.set_constant("separation", "VBoxContainer", 16)
	theme.set_constant("separation", "HBoxContainer", 16)

	var err := ResourceSaver.save(theme, OUT)
	if err != OK:
		push_error("Could not save the theme (error %d)." % err)
	else:
		print("Saved ", OUT)
	quit(0 if err == OK else 1)


func _label(theme: Theme, variation: String, font: Font, size: int, color: Color) -> void:
	theme.set_type_variation(variation, "Label")
	_font_of(theme, variation, font, size)
	theme.set_color("font_color", variation, color)


func _font_of(theme: Theme, type: String, font: Font, size: int) -> void:
	if font:
		theme.set_font("font", type, font)
	theme.set_font_size("font_size", type, size)


func _box(bg: Color, border: Color, border_width: int, pad_x: int, pad_y: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(0)
	box.content_margin_left = pad_x
	box.content_margin_right = pad_x
	box.content_margin_top = pad_y
	box.content_margin_bottom = pad_y
	return box


func _tab_box(marker: Color) -> StyleBoxFlat:
	var box := _box(CLEAR, marker, 0, 8, 24)
	box.border_width_top = 4
	return box


## A font file from assets/fonts, or null when it is not there yet (the
## default font is used then).
func _font(file_name: String) -> FontFile:
	var path := FONT_DIR + file_name
	if not ResourceLoader.exists(path):
		push_warning("Font missing, using the default: " + path)
		return null
	return load(path)


func _weight(base: Font, weight: int) -> Font:
	if base == null:
		return null
	var v := FontVariation.new()
	v.base_font = base
	v.variation_opentype = {WGHT: weight}
	return v


func _spaced(base: Font, extra: int) -> Font:
	if base == null:
		return null
	var v := FontVariation.new()
	v.base_font = base
	v.spacing_glyph = extra
	return v
