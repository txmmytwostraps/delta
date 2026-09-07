extends PanelContainer
## Runs the site's judge self-test cases on this device and compares the
## first three (good, wrong, broken) with the site's own results, recorded
## from the site's judge. Opened from Profile. These cases keep the site's
## self-test name solve(); the bank's problems name their own functions.

const PROBLEM := {"fn": "solve", "tests": [
	{"args": [[1, 2, 3]], "expect": 6},
	{"args": [[]], "expect": 0},
	{"args": [[-5, 5, 10]], "expect": 10},
]}

## name, code, the site's result as JSON ("" when only shown), what to look for
const CASES := [
	["good", "func solve(nums: Array) -> int:\n\tvar s := 0\n\tfor n in nums:\n\t\ts += n\n\tout(\"sum was %d\" % s)\n\treturn s\n",
		'{"passed":3,"results":[{"args":[[1,2,3]],"expect":6,"got":6,"out":["sum was 6"],"pass":true},{"args":[[]],"expect":0,"got":0,"out":["sum was 0"],"pass":true},{"args":[[-5,5,10]],"expect":10,"got":10,"out":["sum was 10"],"pass":true}],"status":"ok","total":3}', ""],
	["wrong", "func solve(nums: Array) -> int:\n\treturn 42\n",
		'{"passed":0,"results":[{"args":[[1,2,3]],"expect":6,"got":42,"out":[],"pass":false},{"args":[[]],"expect":0,"got":42,"out":[],"pass":false},{"args":[[-5,5,10]],"expect":10,"got":42,"out":[],"pass":false}],"status":"ok","total":3}', ""],
	["broken", "func solve(nums: Array) -> int:\n\treturn nums +\n",
		'{"error":"Parse error","status":"compile_error"}', "Expected expression"],
	["infinite while", "func solve(nums: Array) -> int:\n\tvar i := 0\n\twhile true:\n\t\ti += 1\n\treturn i\n", "", "more than"],
	["division by zero", "func solve(nums: Array) -> int:\n\tvar n := nums.size()\n\treturn 10 / n\n", "", "Division by zero"],
	["recursion", "func solve(nums: Array) -> int:\n\treturn solve(nums)\n", "", "Stack overflow"],
]

@onready var back: Button = $Margin/Column/TopBar/Back
@onready var run_button: Button = $Margin/Column/Scroll/Body/Run
@onready var summary: Label = $Margin/Column/Scroll/Body/Summary
@onready var cases: VBoxContainer = $Margin/Column/Scroll/Body/Cases


func _ready() -> void:
	back.pressed.connect(queue_free)
	run_button.pressed.connect(run_all)


func run_all() -> void:
	run_button.disabled = true
	summary.text = "Running…"
	for child in cases.get_children():
		child.queue_free()
	var matched := 0
	for c in CASES:
		var panel := PanelContainer.new()
		cases.add_child(panel)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 8)
		panel.add_child(column)
		var head := Label.new()
		head.theme_type_variation = &"Heading3"
		head.text = "%s · running" % str(c[0]).to_upper()
		column.add_child(head)

		var reply: Dictionary = await Grader.run(c[1], PROBLEM)
		if not is_inside_tree():
			return
		var got := JSON.stringify(reply.result)
		var all_text: String = got + "\n" + "\n".join(reply.errors)
		var ok: bool
		if c[2] != "":
			ok = got == c[2] and (c[3] == "" or all_text.contains(c[3]))
			if ok:
				matched += 1
		else:
			ok = all_text.contains(c[3])
		head.text = "%s · %s · %d ms" % [str(c[0]).to_upper(), "SAME AS THE SITE" if (ok and c[2] != "") else ("AS EXPECTED" if ok else "DIFFERENT"), reply.ms]
		head.theme_type_variation = &"Accent" if ok else &"Error"
		panel.theme_type_variation = &"PanelContainer" if ok else &"PanelActive"

		var body := Label.new()
		body.theme_type_variation = &"Code"
		body.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		body.text = got
		column.add_child(body)
		if reply.errors.size() > 0:
			var errors := Label.new()
			errors.theme_type_variation = &"Error"
			errors.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
			errors.text = "\n".join(reply.errors.slice(0, 6))
			column.add_child(errors)
	summary.text = "%d of 3 site cases match" % matched + (" · %d run%s still stuck" % [Grader.stuck, "" if Grader.stuck == 1 else "s"] if Grader.stuck > 0 else "")
	summary.theme_type_variation = &"Accent" if matched == 3 else &"Error"
	run_button.disabled = false
