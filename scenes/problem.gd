extends PanelContainer
## One problem: prompt, the code as it stands (starter or draft), and the
## note. Opened by App.open_problem(); Back closes it.

var problem_id := ""

@onready var back: Button = $Margin/Column/TopBar/Back
@onready var meta: Label = $Margin/Column/TopBar/Meta
@onready var title: Label = $Margin/Column/Scroll/Body/Title
@onready var status: Label = $Margin/Column/Scroll/Body/Status
@onready var prompt: Label = $Margin/Column/Scroll/Body/Prompt
@onready var code: Label = $Margin/Column/Scroll/Body/CodePanel/CodeScroll/Code
@onready var note: TextEdit = $Margin/Column/Scroll/Body/Note
@onready var resolved: Button = $Margin/Column/Scroll/Body/NoteRow/Resolved
@onready var saved: Label = $Margin/Column/Scroll/Body/NoteRow/Saved

var _save_timer: Timer
var _loading := true


func _ready() -> void:
	back.pressed.connect(close)
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 1.0
	_save_timer.timeout.connect(_save_note)
	add_child(_save_timer)
	note.text_changed.connect(func() -> void:
		if not _loading:
			saved.text = "typing…"
			_save_timer.start())
	resolved.toggled.connect(func(on: bool) -> void:
		resolved.text = "[x] RESOLVED" if on else "[ ] RESOLVED"
		if not _loading:
			_save_note())
	Sync.state_changed.connect(_update_saved)
	render()


func render() -> void:
	var p := Bank.problem(problem_id)
	if p.is_empty():
		title.text = "UNKNOWN PROBLEM"
		return
	_loading = true
	meta.text = "%s · D%d" % [Bank.topic_title(p.concept).to_upper(), int(p.get("difficulty", 0))]
	title.text = str(p.title).to_upper()
	prompt.text = str(p.prompt)
	var when: Variant = Progress.solved().get(problem_id, null)
	status.visible = when != null
	if when != null:
		status.text = "SOLVED · %s" % Streak.day_key(str(when))
	var draft := Progress.draft(problem_id)
	# Labels swallow tabs, so show each as four spaces.
	code.text = str(draft.get("code", p.starter)).replace("\t", "    ")
	var n := Notes.get_note(problem_id)
	note.text = str(n.get("text", ""))
	resolved.button_pressed = bool(n.get("resolved", false))
	resolved.text = "[x] RESOLVED" if resolved.button_pressed else "[ ] RESOLVED"
	_update_saved()
	_loading = false


func _save_note() -> void:
	_save_timer.stop()
	var n := Notes.get_note(problem_id)
	var text := note.text
	var is_resolved := resolved.button_pressed
	if text == str(n.get("text", "")) and is_resolved == bool(n.get("resolved", false)):
		_update_saved()
		return
	if text.strip_edges() == "" and n.is_empty():
		_update_saved()
		return
	Notes.save(problem_id, {"text": text, "resolved": is_resolved})
	_update_saved()


func _update_saved() -> void:
	if not is_inside_tree() or _save_timer.time_left > 0:
		return
	var n := Notes.get_note(problem_id)
	if n.is_empty():
		saved.text = ""
	elif Sync.pending_count() > 0:
		saved.text = "saved here · waiting to sync"
	else:
		saved.text = "saved to your account"


func close() -> void:
	if _save_timer.time_left > 0:
		_save_note()
	queue_free()
