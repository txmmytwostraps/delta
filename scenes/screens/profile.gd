extends VBoxContainer
## Profile: the character beside the name, four tiles (streak, longest,
## level, XP), the week, the settings as rows, the extras, and one line
## with the version, About and Sign out.

const Stage := preload("res://scenes/stage.gd")

@onready var update_button: Button = $Margin/Scroll/Body/Update
@onready var stage_host: VBoxContainer = $Margin/Scroll/Body/Top/Character/CharacterColumn/StageHost
@onready var hp_host: VBoxContainer = $Margin/Scroll/Body/Top/Character/CharacterColumn/HpHost
@onready var gallery_button: Button = $Margin/Scroll/Body/Top/Character/CharacterColumn/Gallery
@onready var name_label: Label = $Margin/Scroll/Body/Top/Who/Name
@onready var email_label: Label = $Margin/Scroll/Body/Top/Who/Email
@onready var tiles: GridContainer = $Margin/Scroll/Body/Tiles
@onready var week_host: VBoxContainer = $Margin/Scroll/Body/WeekHost
@onready var settings: VBoxContainer = $Margin/Scroll/Body/Settings
@onready var more: VBoxContainer = $Margin/Scroll/Body/More
@onready var version_label: Label = $Margin/Scroll/Body/Footer/Version
@onready var about_button: Button = $Margin/Scroll/Body/Footer/About
@onready var sign_out_button: Button = $Margin/Scroll/Body/Footer/SignOut

var _stage: Control
var _sticky: StickyHeader


func _ready() -> void:
	_sticky = StickyHeader.attach($Margin, $Margin/Scroll)
	sign_out_button.pressed.connect(_on_sign_out)
	update_button.pressed.connect(func() -> void: OS.shell_open(Updates.latest_url))
	gallery_button.pressed.connect(func() -> void:
		var app := _app()
		if app and app.has_method("open_gallery"):
			app.open_gallery())
	_stage = Stage.new()
	_stage.kind = "move"
	_stage.portrait = true
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_host.add_child(_stage)
	Settings.changed.connect(_refresh)
	Reminders.changed.connect(_refresh)
	Updates.checked.connect(_refresh)
	Auth.changed.connect(_refresh)
	Progress.changed.connect(_refresh)
	Reviews.changed.connect(_refresh)
	Scaffold.changed.connect(_refresh)
	Sync.pulled.connect(_refresh)
	Sync.state_changed.connect(_refresh)
	visibility_changed.connect(func() -> void:
		if visible:
			_refresh())
	_refresh()


func _refresh() -> void:
	if not is_inside_tree() or not Auth.is_signed_in():
		return
	name_label.text = Auth.display_name()
	email_label.text = Auth.email()
	email_label.visible = Auth.email() != "" and Auth.email() != Auth.display_name()
	update_button.visible = Updates.update_available()
	update_button.text = "UPDATE AVAILABLE · %s" % Updates.latest

	# The character: the milestone robot, standing; its health once
	# milestone 2 gives it some. The gallery arrives with the site's.
	var ms := Progress.milestones()
	var m2_done: bool = ms.size() > 1 and ms[1].done
	_stage.set_state({"x": 300, "speed": 0})
	_clear(hp_host)
	var hp := Label.new()
	hp.theme_type_variation = &"Detail"
	hp.text = "HP 100 / 100" if m2_done else "HP ?"
	hp_host.add_child(hp)
	hp_host.add_child(UI.bar(100 if m2_done else 0, 100, 6))
	gallery_button.disabled = not _app() or not _app().has_method("open_gallery")

	var s := Progress.streak()
	var x := Progress.xp_info()
	_clear(tiles)
	tiles.add_child(UI.tile("Streak", str(s.streak), true))
	tiles.add_child(UI.tile("Longest", str(s.longest)))
	tiles.add_child(UI.tile("Level", str(x.level)))
	tiles.add_child(UI.tile("XP", str(x.xp)))
	_clear(week_host)
	week_host.add_child(UI.week_row(s.week, s.token))

	_clear(settings)
	settings.add_child(UI.stepper_row("New problems a day", str(Progress.new_per_day()),
		func() -> void: Progress.set_new_per_day(Progress.new_per_day() - 1),
		func() -> void: Progress.set_new_per_day(Progress.new_per_day() + 1)))
	settings.add_child(UI.stepper_row("Course through lesson", "L%02d" % Progress.course_lock(),
		func() -> void: Progress.set_course_lock(maxi(1, Progress.course_lock() - 1)),
		func() -> void: Progress.set_course_lock(mini(Bank.lessons.size(), Progress.course_lock() + 1))))
	var on := Reminders.enabled()
	settings.add_child(UI.toggle_row("Review reminder", on, func() -> void: Reminders.set_enabled(not Reminders.enabled())))
	if on:
		settings.add_child(UI.stepper_row("Reminder time", Progress.reminder_time(),
			func() -> void: Progress.set_reminder_time(_shift_time(Progress.reminder_time(), -30)),
			func() -> void: Progress.set_reminder_time(_shift_time(Progress.reminder_time(), 30))))
	settings.add_child(UI.segment_row("Text size", ["S", "M", "L"], _size_name(Settings.text_scale()), func(pick: String) -> void:
		Settings.set_text_scale(Settings.TEXT_SIZES[pick])))
	var hints := UI.list_row("", "Hint levels", "edit ›")
	hints.pressed.connect(func() -> void: _app().open_hint_levels())
	settings.add_child(hints)

	_clear(more)
	var week := UI.list_row("", "This week's summary", "›")
	week.pressed.connect(func() -> void: _app().open_week())
	more.add_child(week)
	var judge := UI.list_row("", "Check the judge", "›")
	judge.pressed.connect(func() -> void: _app().open_judge_check())
	more.add_child(judge)
	var pending := Sync.pending_count()
	var sync_row := UI.list_row("", "Sync now", "%d waiting" % pending if pending > 0 else ("syncing…" if Sync.busy else ""))
	sync_row.pressed.connect(Sync.sync_now)
	more.add_child(sync_row)

	version_label.text = "Delta %s · %s" % [Updates.current(), Bank.site_commit.substr(0, 7)]
	_sticky.set_sections([{"node": $Margin/Scroll/Body/SettingsLabel, "title": "SETTINGS"}, {"node": $Margin/Scroll/Body/MoreLabel, "title": "MORE"}])


static func _size_name(scale: float) -> String:
	for k in Settings.TEXT_SIZES:
		if is_equal_approx(Settings.TEXT_SIZES[k], scale):
			return k
	return "M"


## "19:00" + 30 -> "19:30", wrapping around midnight.
static func _shift_time(hhmm: String, minutes: int) -> String:
	var total := int(hhmm.get_slice(":", 0)) * 60 + int(hhmm.get_slice(":", 1)) + minutes
	total = posmod(total, 24 * 60)
	return "%02d:%02d" % [total / 60, total % 60]


func _on_sign_out() -> void:
	sign_out_button.disabled = true
	await Auth.sign_out()


func _app() -> Node:
	return get_tree().get_first_node_in_group("app")


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
