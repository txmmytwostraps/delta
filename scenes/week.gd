extends PanelContainer
## This week: the summary text, and a button that copies it for the weekly
## review. Same text as the site's This week page.

@onready var back: Button = $Column/TopMargin/TopBar/Back
@onready var summary: Label = $Column/Scroll/Margin/Body/SummaryPanel/Summary
@onready var copy_button: Button = $Column/Bar/BarMargin/Actions/Copy
@onready var copied: Label = $Column/Bar/BarMargin/Actions/Copied


func _ready() -> void:
	back.pressed.connect(queue_free)
	copy_button.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(summary.text)
		copied.text = "copied"
		get_tree().create_timer(3.0).timeout.connect(func() -> void:
			if is_inside_tree():
				copied.text = ""))
	Sync.pulled.connect(render)
	render()


func render() -> void:
	if not is_inside_tree():
		return
	summary.text = Week.build()
