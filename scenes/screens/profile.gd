extends MarginContainer
## Who is signed in, the day streak, and the way out.

@onready var name_label: Label = $Scroll/Body/Account/Column/Name
@onready var email_label: Label = $Scroll/Body/Account/Column/Email
@onready var streak_value: Label = $Scroll/Body/Streak/Column/Value
@onready var streak_note: Label = $Scroll/Body/Streak/Column/Note
@onready var sign_out_button: Button = $Scroll/Body/SignOut
@onready var version_label: Label = $Scroll/Body/Version


func _ready() -> void:
	version_label.text = "Delta %s" % ProjectSettings.get_setting("application/config/version", "")
	sign_out_button.pressed.connect(_on_sign_out)
	Auth.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	if not Auth.is_signed_in():
		return
	name_label.text = Auth.display_name()
	email_label.text = Auth.email()
	email_label.visible = Auth.email() != "" and Auth.email() != Auth.display_name()
	_load_streak()


## The streak comes from the account: every solve date and every review date
## marks its day as active.
func _load_streak() -> void:
	streak_value.text = "…"
	streak_note.text = "Loading…"
	var token: String = await Auth.access_token()
	var solves: Dictionary = await Supabase.call_api("GET", "/rest/v1/progress?select=solved_at&solved_at=not.is.null", null, token)
	var reviews: Dictionary = await Supabase.call_api("GET", "/rest/v1/reviews?select=reviewed_at&reviewed_at=not.is.null", null, token)
	if not is_inside_tree():
		return
	if not solves.ok or not reviews.ok:
		streak_value.text = "?"
		streak_note.text = solves.error if not solves.ok else reviews.error
		return
	var when: Array = []
	for row in solves.data:
		when.append(row.solved_at)
	for row in reviews.data:
		when.append(row.reviewed_at)
	streak_value.text = str(Streak.count(when))
	var solved: int = solves.data.size()
	streak_note.text = "%d problem%s solved so far" % [solved, "" if solved == 1 else "s"]


func _on_sign_out() -> void:
	sign_out_button.disabled = true
	await Auth.sign_out()
