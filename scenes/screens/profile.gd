extends MarginContainer
## Who is signed in, the day streak, the state of the account sync, and the
## way out.

@onready var name_label: Label = $Scroll/Body/Account/Column/Name
@onready var email_label: Label = $Scroll/Body/Account/Column/Email
@onready var streak_value: Label = $Scroll/Body/Streak/Column/Value
@onready var streak_note: Label = $Scroll/Body/Streak/Column/Note
@onready var set_size_value: Label = $Scroll/Body/Settings/Column/SetSize/SetSizeColumn/SetSizeValue
@onready var size_less: Button = $Scroll/Body/Settings/Column/SetSize/SizeLess
@onready var size_more: Button = $Scroll/Body/Settings/Column/SetSize/SizeMore
@onready var reminder_value: Label = $Scroll/Body/Settings/Column/Reminder/ReminderColumn/ReminderValue
@onready var time_less: Button = $Scroll/Body/Settings/Column/Reminder/TimeLess
@onready var time_more: Button = $Scroll/Body/Settings/Column/Reminder/TimeMore
@onready var sync_status: Label = $Scroll/Body/Sync/Column/Status
@onready var sync_now_button: Button = $Scroll/Body/Sync/Column/SyncNow
@onready var judge_check_button: Button = $Scroll/Body/JudgeCheck
@onready var sign_out_button: Button = $Scroll/Body/SignOut
@onready var version_label: Label = $Scroll/Body/Version


func _ready() -> void:
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	version_label.text = "Delta %s · problems from %s" % [version, Bank.site_commit.substr(0, 7)]
	sign_out_button.pressed.connect(_on_sign_out)
	judge_check_button.pressed.connect(func() -> void:
		var app := get_tree().get_first_node_in_group("app")
		if app:
			app.open_judge_check())
	sync_now_button.pressed.connect(Sync.sync_now)
	size_less.pressed.connect(func() -> void: Progress.set_new_per_day(Progress.new_per_day() - 1))
	size_more.pressed.connect(func() -> void: Progress.set_new_per_day(Progress.new_per_day() + 1))
	time_less.pressed.connect(func() -> void: Progress.set_reminder_time(_shift_time(Progress.reminder_time(), -30)))
	time_more.pressed.connect(func() -> void: Progress.set_reminder_time(_shift_time(Progress.reminder_time(), 30)))
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
	streak_value.text = str(Progress.streak_days())
	var solved: int = Progress.solved().keys().filter(func(id: String) -> bool: return Bank.has_problem(id)).size()
	var runs := Progress.runs_completed()
	streak_note.text = "%d problem%s solved · level %d · %d full run%s" % [solved, "" if solved == 1 else "s", Progress.level(), runs, "" if runs == 1 else "s"]
	set_size_value.text = str(Progress.new_per_day())
	reminder_value.text = Progress.reminder_time()
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
