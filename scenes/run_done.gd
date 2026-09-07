extends SimplePage
## After the last problem of the run: the time it took, the XP it earned,
## the streak, and one button back to Today.

var minutes := 0
var xp := 0


func _ready() -> void:
	super()
	back.text = "‹ TODAY"
	back.pressed.connect(func() -> void: app().show_tab("today"))
	var eyebrow := Label.new()
	eyebrow.theme_type_variation = &"Eyebrow"
	eyebrow.text = "// RUN DONE"
	body.add_child(eyebrow)
	var title := Label.new()
	title.theme_type_variation = &"Heading"
	title.text = "DAY DONE"
	body.add_child(title)
	var tick := Label.new()
	tick.theme_type_variation = &"Big"
	tick.text = "✓"
	body.add_child(tick)
	var s := Progress.streak()
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.add_child(UI.tile("Minutes", str(minutes)))
	grid.add_child(UI.tile("XP", "+%d" % xp, true))
	grid.add_child(UI.tile("Streak", str(s.streak)))
	body.add_child(grid)
	var note := Label.new()
	note.theme_type_variation = &"ProseMuted"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.text = "Anything more today is extra: it counts, and it never counts against the day." + (" A full run earns a rest day, held until a missed day needs it." if s.token else "")
	body.add_child(note)
	set_action("BACK TO TODAY", func() -> void: app().show_tab("today"))
