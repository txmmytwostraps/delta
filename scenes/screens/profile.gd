extends MarginContainer
## Who is signed in, the day streak, the state of the account sync, and the
## way out.

@onready var name_label: Label = $Scroll/Body/Account/Column/Name
@onready var email_label: Label = $Scroll/Body/Account/Column/Email
@onready var streak_value: Label = $Scroll/Body/Streak/Column/Numbers/Value
@onready var streak_longest: Label = $Scroll/Body/Streak/Column/Numbers/Longest
@onready var week_host: VBoxContainer = $Scroll/Body/Streak/Column/WeekHost
@onready var streak_note: Label = $Scroll/Body/Streak/Column/Note
@onready var set_size_value: Label = $Scroll/Body/Settings/Column/SetSize/SetSizeColumn/SetSizeValue
@onready var size_less: Button = $Scroll/Body/Settings/Column/SetSize/SizeLess
@onready var size_more: Button = $Scroll/Body/Settings/Column/SetSize/SizeMore
@onready var reminder_value: Label = $Scroll/Body/Settings/Column/Reminder/ReminderColumn/ReminderValue
@onready var reminder_toggle: Button = $Scroll/Body/Settings/Column/Reminder/ReminderColumn/ReminderToggle
@onready var update_button: Button = $Scroll/Body/Update
@onready var time_less: Button = $Scroll/Body/Settings/Column/Reminder/TimeLess
@onready var time_more: Button = $Scroll/Body/Settings/Column/Reminder/TimeMore
@onready var sync_status: Label = $Scroll/Body/Sync/Column/Status
@onready var sync_now_button: Button = $Scroll/Body/Sync/Column/SyncNow
@onready var week_button: Button = $Scroll/Body/Week
@onready var judge_check_button: Button = $Scroll/Body/JudgeCheck
@onready var sign_out_button: Button = $Scroll/Body/SignOut
@onready var version_label: Label = $Scroll/Body/Version


func _ready() -> void:
	sign_out_button.pressed.connect(_on_sign_out)
	week_button.pressed.connect(func() -> void:
		var app := get_tree().get_first_node_in_group("app")
		if app:
			app.open_week())
	Settings.changed.connect(_refresh)
	judge_check_button.pressed.connect(func() -> void:
		var app := get_tree().get_first_node_in_group("app")
		if app:
			app.open_judge_check())
	sync_now_button.pressed.connect(Sync.sync_now)
	size_less.pressed.connect(func() -> void: Progress.set_new_per_day(Progress.new_per_day() - 1))
	size_more.pressed.connect(func() -> void: Progress.set_new_per_day(Progress.new_per_day() + 1))
	time_less.pressed.connect(func() -> void: Progress.set_reminder_time(_shift_time(Progress.reminder_time(), -30)))
	time_more.pressed.connect(func() -> void: Progress.set_reminder_time(_shift_time(Progress.reminder_time(), 30)))
	reminder_toggle.pressed.connect(func() -> void: Reminders.set_enabled(not Reminders.enabled()))
	update_button.pressed.connect(func() -> void: OS.shell_open(Updates.latest_url))
	Reminders.changed.connect(_refresh)
	Updates.checked.connect(_refresh)
	Auth.changed.connect(_refresh)
	Progress.changed.connect(_refresh)
	Reviews.changed.connect(_refresh)
	Sync.pulled.connect(_refresh)
	Sync.state_changed.connect(_refresh_sync)
	_refresh()


func _refresh() -> void:
	if not is_inside_tree() or not Auth.is_signed_in():
		return
	name_label.text = Auth.display_name()
	email_label.text = Auth.email()
	email_label.visible = Auth.email() != "" and Auth.email() != Auth.display_name()
	var s := Progress.streak()
	streak_value.text = str(s.streak)
	streak_longest.text = "longest %d" % int(s.longest)
	for child in week_host.get_children():
		week_host.remove_child(child)
		child.queue_free()
	week_host.add_child(UI.week_row(s.week, s.token))
	var solved: int = Progress.solved().keys().filter(func(id: String) -> bool: return Bank.has_problem(id)).size()
	var runs := Progress.runs_completed()
	streak_note.text = "%d problem%s solved · level %d · %d full run%s" % [solved, "" if solved == 1 else "s", Progress.level(), runs, "" if runs == 1 else "s"]
	set_size_value.text = str(Progress.new_per_day())
	var on := Reminders.enabled()
	reminder_value.text = "%s · %s" % [Progress.reminder_time(), "on" if on else "off"]
	reminder_toggle.text = "TURN OFF" if on else "TURN ON"
	reminder_toggle.visible = Reminders.available() or OS.has_feature("pc")
	update_button.visible = Updates.update_available()
	update_button.text = "UPDATE AVAILABLE · %s" % Updates.latest
	version_label.text = "Delta %s · problems from %s%s" % [Updates.current(), Bank.site_commit.substr(0, 7), "" if Updates.latest == "" else " · latest release %s" % Updates.latest]
	_refresh_sync()


## "19:00" + 30 -> "19:30", wrapping around midnight.
static func _shift_time(hhmm: String, minutes: int) -> String:
	var total := int(hhmm.get_slice(":", 0)) * 60 + int(hhmm.get_slice(":", 1)) + minutes
	total = posmod(total, 24 * 60)
	return "%02d:%02d" % [total / 60, total % 60]


func _refresh_sync() -> void:
	if not is_inside_tree():
		return
	sync_status.text = Sync.status_text()
	sync_now_button.disabled = Sync.busy


func _on_sign_out() -> void:
	sign_out_button.disabled = true
	await Auth.sign_out()
