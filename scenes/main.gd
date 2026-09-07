extends Control
## The root of the app: shows the sign-in screen until there is an account,
## then the tabs.
##
## For checking the look without a phone, the app can save a picture of
## itself and quit:
##   godot --path . -- --screenshot=shot.png --tab=profile
##   godot --path . -- --screenshot=shot.png --problem=arith-001

const SignInScene := preload("res://scenes/sign_in.tscn")
const AppScene := preload("res://scenes/app.tscn")

@onready var stage: MarginContainer = $Stage

var _shown: Node


func _ready() -> void:
	add_to_group("main")
	# A panel box swallows touches by default, so a drag that starts on a
	# card would never reach the list behind it. Every panel lets touches
	# through instead; buttons inside still get theirs first.
	get_tree().node_added.connect(func(node: Node) -> void:
		if node is PanelContainer:
			node.mouse_filter = Control.MOUSE_FILTER_PASS)
	fit_canvas()
	get_window().size_changed.connect(fit_canvas)
	Settings.changed.connect(apply_text_scale)
	Sync.pulled.connect(apply_text_scale)
	apply_text_scale()
	Auth.changed.connect(_refresh)
	if not Auth.is_restored:
		await Auth.restored
	_refresh()
	_maybe_screenshot()


## The canvas is measured in half-points: two units per point (dp), the
## same on every phone. On a device the canvas size follows the screen's
## pixel density, so a 14-point line of text is 14 points everywhere and a
## wider phone simply gets more room. On a desktop the canvas is a fixed
## 720 units across, a 360-point phone, whatever the window size.
func fit_canvas() -> void:
	var window := get_window()
	if OS.has_feature("mobile"):
		var dpi := maxi(DisplayServer.screen_get_dpi(), 120)
		var px_per_unit := (dpi / 160.0) / 2.0
		var px := DisplayServer.window_get_size()
		window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
		window.content_scale_size = Vector2i(roundi(px.x / px_per_unit), roundi(px.y / px_per_unit))
	else:
		var px := DisplayServer.window_get_size()
		var landscape := px.x > px.y
		window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		window.content_scale_size = Vector2i(1280, 720) if landscape else Vector2i(720, 1280)


## Text size S / M / L: the prose styles scale; code, labels and rows stay.
const PROSE_BASE := 28


func apply_text_scale() -> void:
	var theme := ThemeDB.get_project_theme()
	if theme == null:
		return
	var size := roundi(PROSE_BASE * Settings.text_scale())
	for variation in ["Prose", "ProseMuted"]:
		theme.set_font_size("font_size", variation, size)


func _refresh() -> void:
	var wanted: PackedScene = AppScene if Auth.is_signed_in() else SignInScene
	if _shown != null and _shown.scene_file_path == wanted.resource_path:
		return
	if _shown != null:
		_shown.queue_free()
	_shown = wanted.instantiate()
	stage.add_child(_shown)


func _maybe_screenshot() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			args[arg.substr(2).get_slice("=", 0)] = arg.get_slice("=", 1)
	if not args.has("screenshot"):
		return
	if args.has("tab") and _shown.has_method("show_tab"):
		_shown.show_tab(args.tab)
	if args.has("problem") and _shown.has_method("open_problem"):
		_shown.open_problem(args.problem)
	await get_tree().create_timer(1.0).timeout
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(args.screenshot)
	print("screenshot ", args.screenshot, " ", "saved" if err == OK else "failed (%d)" % err)
	get_tree().quit()
