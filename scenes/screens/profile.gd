extends MarginContainer
## Who is signed in, the day streak, the state of the account sync, and the
## way out.

@onready var name_label: Label = $Scroll/Body/Account/Column/Name
@onready var email_label: Label = $Scroll/Body/Account/Column/Email
@onready var streak_value: Label = $Scroll/Body/Streak/Column/Value
@onready var streak_note: Label = $Scroll/Body/Streak/Column/Note
@onready var sync_status: Label = $Scroll/Body/Sync/Column/Status
@onready var sync_now_button: Button = $Scroll/Body/Sync/Column/SyncNow
@onready var sign_out_button: Button = $Scroll/Body/SignOut
@onready var version_label: Label = $Scroll/Body/Version


func _ready() -> void:
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	version_label.text = "Delta %s · problems from %s" % [version, Bank.site_commit.substr(0, 7)]
	sign_out_button.pressed.connect(_on_sign_out)
	sync_now_button.pressed.connect(Sync.sync_now)
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
	var solved := Progress.solved().size()
	streak_note.text = "%d problem%s solved · level %d" % [solved, "" if solved == 1 else "s", Progress.level()]
	_refresh_sync()


func _refresh_sync() -> void:
	if not is_inside_tree():
		return
	sync_status.text = Sync.status_text()
	sync_now_button.disabled = Sync.busy


func _on_sign_out() -> void:
	sign_out_button.disabled = true
	await Auth.sign_out()
