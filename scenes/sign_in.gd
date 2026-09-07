extends MarginContainer
## The sign-in screen. Both ways in end with Auth emitting `changed`, which
## makes Main swap this screen for the tabs.

@onready var github_button: Button = $Column/GitHubButton
@onready var email: LineEdit = $Column/Email
@onready var password: LineEdit = $Column/Password
@onready var email_button: Button = $Column/EmailButton
@onready var note: Label = $Column/Note


func _ready() -> void:
	github_button.pressed.connect(_on_github)
	email_button.pressed.connect(_on_email)
	email.text_submitted.connect(func(_text: String) -> void: password.grab_focus())
	password.text_submitted.connect(func(_text: String) -> void: _on_email())
	Auth.github_failed.connect(_show_error)
	_show_error("")


func _on_github() -> void:
	_busy(true, "Finish signing in with GitHub in the browser, then come back here.")
	var error := Auth.sign_in_with_github()
	if error != "":
		_busy(false, error)


func _on_email() -> void:
	var address := email.text.strip_edges()
	if address == "" or password.text == "":
		_show_error("Enter your email and password.")
		return
	_busy(true, "Signing in…")
	var error: String = await Auth.sign_in_with_email(address, password.text)
	if not is_inside_tree():
		return
	_busy(false, error)


func _busy(on: bool, message: String) -> void:
	github_button.disabled = on
	email_button.disabled = on
	email.editable = not on
	password.editable = not on
	note.theme_type_variation = &"Muted" if on else &"Error"
	note.text = message
	note.visible = message != ""


func _show_error(message: String) -> void:
	_busy(false, message)
