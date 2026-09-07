extends SimplePage
## The Gallery, like the site's: your character so far with what it can do,
## then one card per milestone: finished ones run here with the script they
## were finished with; the others say where they stand.

const Stage := preload("res://scenes/stage.gd")
const StagePanel := preload("res://scenes/stage_panel.gd")

## What each milestone adds to the character, in the site's words.
const GAINS := {
	"m1": {"key": "move", "text": "moves along the stage", "fns": "move_right, move_left, speed_up, slow_down"},
	"m2": {"key": "health", "text": "has health that never goes below zero", "fns": "take_damage, heal, report"},
	"m3": {"key": "walk", "text": "walks the floor between two walls", "fns": "move, go_left, go_right, stop"},
	"m4": {"key": "bag", "text": "carries a bag of four items", "fns": "pick_up, has, count, use"},
	"m5": {"key": "fight", "text": "fights an enemy to the end", "fns": "attack, enemy_turn, is_alive, fight"},
}

var _panels: Array = []


## The abilities earned: { move, health, walk, bag, fight } from the milestones done.
static func has_now(list: Array) -> Dictionary:
	var has := {}
	for m in list:
		if m.done and GAINS.has(str(m.id)):
			has[GAINS[str(m.id)].key] = true
	return has


func _ready() -> void:
	super()
	Progress.changed.connect(render)
	Sync.pulled.connect(render)
	render()


func render() -> void:
	if not is_inside_tree():
		return
	clear_body()
	_panels = []
	var list := Progress.milestones()
	var done_count: int = list.filter(func(m: Dictionary) -> bool: return m.done).size()
	var title := Label.new()
	title.theme_type_variation = &"Heading"
	title.text = "GALLERY"
	body.add_child(title)
	var intro := Label.new()
	intro.theme_type_variation = &"ProseMuted"
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.text = "What you have built so far. Each milestone runs here with the script you finished it with, and its badge shows on the Route and in Stats."
	body.add_child(intro)

	# Your character so far.
	var sofar := PanelContainer.new()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	sofar.add_child(column)
	var label := Label.new()
	label.theme_type_variation = &"Detail"
	label.text = "Your character so far · %d of %d milestones" % [done_count, list.size()]
	column.add_child(label)
	var stage := Stage.new()
	stage.kind = "character"
	column.add_child(stage)
	var has := has_now(list)
	stage.set_state({"has": has, "x": 300, "facing": "right"})
	if has.get("move", false) or has.get("walk", false):
		stage.demo(150.0 if has.get("walk", false) else 120.0)
	var readout := Label.new()
	readout.theme_type_variation = &"Detail"
	readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stage.draw.connect(func() -> void: readout.text = stage.readout)
	column.add_child(readout)
	var can := Label.new()
	can.theme_type_variation = &"Detail"
	can.text = "What it can do"
	column.add_child(can)
	for m in list:
		var g: Dictionary = GAINS.get(str(m.id), {})
		if g.is_empty():
			continue
		var line := Label.new()
		line.theme_type_variation = &"Prose" if m.done else &"ProseMuted"
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var state: String = "" if m.done else (" · planned" if bool(m.get("planned", false)) else (" · in progress" if m.unlocked else " · locked"))
		line.text = "%s %s%s" % ["✓" if m.done else "[ ]", g.text, (" · " + str(g.fns)) if m.done else state]
		column.add_child(line)
	body.add_child(sofar)

	for m in list:
		body.add_child(_card(m))


func _card(m: Dictionary) -> Control:
	var card := PanelContainer.new()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	card.add_child(column)
	var k := Label.new()
	k.theme_type_variation = &"Detail"
	k.text = "Milestone %02d" % int(m.number)
	column.add_child(k)
	var t := Label.new()
	t.theme_type_variation = &"RowTitle" if m.done else &"Dim"
	t.text = str(m.title)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(t)
	if not m.done:
		var when := Label.new()
		when.theme_type_variation = &"Detail"
		when.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if bool(m.get("planned", false)):
			when.text = "planned"
		elif m.unlocked:
			when.text = "%d / %d steps done" % [m.steps_done, int(m.steps)]
		else:
			when.text = "unlocks in %d topic%s" % [m.topics_to_go, "" if m.topics_to_go == 1 else "s"]
		column.add_child(when)
		if m.unlocked and not bool(m.get("planned", false)):
			var mid := str(m.id)
			column.add_child(UI.link("CONTINUE ›", func() -> void: app().open_milestone_typed(mid)))
		return card
	var badge := Label.new()
	badge.theme_type_variation = &"Accent"
	badge.text = "%s · finished %s%s" % [str(m.get("badge", "done")), Streak.day_key(str(m.done_at)), " · built in Godot too" if m.godot_done else ""]
	badge.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(badge)

	# Your script: the last step's draft, else its reference solution.
	var data := Bank.milestone_data(str(m.id))
	var steps: Array = data.get("steps", [])
	var last: Dictionary = steps[-1] if steps.size() > 0 else {}
	var draft := Progress.draft(str(last.get("id", "")))
	var code: String = str(draft.get("code", last.get("solution", "")))
	var your := Label.new()
	your.theme_type_variation = &"Detail"
	your.text = "Your script"
	column.add_child(your)
	column.add_child(UI.code_view(code))
	var mid := str(m.id)
	column.add_child(UI.link("OPEN THE MILESTONE ›", func() -> void: app().open_milestone(mid, steps.size() - 1)))

	# Run it: the stage with the last step's buttons, on that script.
	var run := Label.new()
	run.theme_type_variation = &"Detail"
	run.text = "Run it"
	column.add_child(run)
	var scene: Dictionary = data.get("scene", {})
	var panel := StagePanel.new()
	panel.setup(str(scene.get("kind", "move")), scene.get("watch", []), func() -> String: return code)
	column.add_child(panel)
	panel.set_buttons(last.get("scene", {}).get("buttons", []))
	panel.reset()
	_panels.append(panel)
	return card
