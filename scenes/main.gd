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
	Auth.changed.connect(_refresh)
	if not Auth.is_restored:
		await Auth.restored
	_refresh()
	_maybe_screenshot()


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
