class_name ResultsPanel
extends VBoxContainer
## The judge's verdict as the site shows it: the verdict line, the test
## count and time, each test with what was called, what was expected and
## what the code gave, printed output, and error lines. Shared by the
## problem page and the editor.

var verdict := Label.new()
var detail := Label.new()
var count := Label.new()
var note := Label.new()
var tests := VBoxContainer.new()
var output_label := Label.new()
var output := Label.new()
var errors_label := Label.new()
var errors := Label.new()

## The first line an error names (0-based), or -1.
var error_line := -1


func _init() -> void:
	add_theme_constant_override("separation", 12)
	tests.add_theme_constant_override("separation", 12)
	verdict.theme_type_variation = &"Heading3"
	verdict.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	count.theme_type_variation = &"Small"
	note.theme_type_variation = &"Muted"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tests.add_theme_constant_override("separation", 12)
	output_label.theme_type_variation = &"Small"
	output_label.text = "OUTPUT"
	output.theme_type_variation = &"DetailCode"
	output.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	errors_label.theme_type_variation = &"Small"
	errors_label.text = "ERRORS"
	errors.theme_type_variation = &"Error"
	errors.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for child in [verdict, detail, count, note, tests, output_label, output, errors_label, errors]:
		add_child(child)
	clear()


func clear() -> void:
	visible = false
	verdict.text = ""
	detail.text = ""
	detail.visible = false
	count.text = ""
	note.text = ""
	note.visible = false
	for child in tests.get_children():
		tests.remove_child(child)
		child.queue_free()
	output_label.visible = false
	output.visible = false
	errors_label.visible = false
	errors.visible = false
	error_line = -1


func show_running() -> void:
	clear()
	visible = true
	verdict.theme_type_variation = &"Muted"
	verdict.text = "Running…"


## An amber notice instead of a verdict.
func show_note(text: String, detail: String) -> void:
	clear()
	visible = true
	verdict.theme_type_variation = &"Amber"
	verdict.text = text
	note.visible = detail != ""
	note.text = detail


## outcome comes from Submission.record. with_rows: one row per test.
func show_result(p: Dictionary, reply: Dictionary, outcome: Dictionary, with_rows: bool) -> void:
	clear()
	visible = true
	var result: Dictionary = reply.result
	# A pass or a miss gets the large heading; the detail goes on the line under it.
	verdict.theme_type_variation = &"Accent" if outcome.pass else &"Error"
	verdict.text = "✓ Correct" if outcome.pass else "✗ Not yet"
	detail.text = outcome.verdict
	detail.visible = outcome.verdict != ""
	note.text = outcome.note
	note.visible = outcome.note != ""
	var total: int = p.get("tests", []).size()

	if result.status != "ok":
		count.text = "0 / %d TESTS · %d MS" % [total, reply.ms]
		_show_errors(reply.errors, "Parse error" if result.status == "compile_error" else "")
		return

	var checks := not p.has("signature")   # a milestone step: checks that read a member
	count.text = "%d / %d %s · %d MS" % [int(result.passed), int(result.total), "CHECKS" if checks else "TESTS", reply.ms]
	if not with_rows:
		return
	if checks:
		for i in result.results.size():
			var r: Dictionary = result.results[i]
			var t: Dictionary = p.tests[i] if i < p.tests.size() else {}
			tests.add_child(_check_row(t, r))
		_show_errors(reply.errors, "")
		return
	var rtype := Fmt.return_type(str(p.get("signature", "")))
	var print_only := Fmt.print_only(p)
	var printed := []
	for i in result.results.size():
		var r: Dictionary = result.results[i]
		var t: Dictionary = p.tests[i] if i < p.tests.size() else {}
		tests.add_child(_test_row(p, t, r, rtype, print_only))
		for line in r.get("out", []):
			printed.append("[test %d] %s" % [i + 1, line])
	if printed.size() > 0 and not print_only:
		output_label.visible = true
		output.visible = true
		output.text = "\n".join(printed)
	_show_errors(reply.errors, "")


## A milestone check: its name, what it does in words, should be, and yours.
func _check_row(t: Dictionary, r: Dictionary) -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	var head := Label.new()
	head.theme_type_variation = &"Accent" if r.pass else &"Error"
	head.clip_text = true
	head.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.text = "%s %s" % ["✓" if r.pass else "✗", str(t.get("name", ""))]
	column.add_child(head)
	var indent := MarginContainer.new()
	indent.add_theme_constant_override("margin_left", 36)
	column.add_child(indent)
	var details := VBoxContainer.new()
	details.add_theme_constant_override("separation", 2)
	indent.add_child(details)
	var why := Label.new()
	why.theme_type_variation = &"Detail"
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	why.text = MilestoneStep.describe(t)
	details.add_child(why)
	var got := Label.new()
	got.theme_type_variation = &"DetailCode"
	got.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	var should: String = Fmt.to_json(r.get("expect", null)) if t.has("read") else Fmt.to_json(t.get("out", []))
	var gave: String = str(r.error) if r.has("error") else (Fmt.to_json(r.get("got", null)) if t.has("read") else Fmt.to_json(r.get("out", [])))
	got.text = "should be %s · your script gave %s" % [should, gave]
	details.add_child(got)
	return column


## One check: its name on one line, expected and yours indented below it.
func _test_row(p: Dictionary, t: Dictionary, r: Dictionary, rtype: String, print_only: bool) -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)

	var head := Label.new()
	head.theme_type_variation = &"Accent" if r.pass else &"Error"
	head.clip_text = true
	head.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var frames: String = "after %d frame%s · " % [int(t.frames), "" if int(t.frames) == 1 else "s"] if t.has("frames") else ""
	head.text = "%s %s%s%s" % ["✓" if r.pass else "✗", (str(t.name) + " · ") if t.has("name") else "", frames, Fmt.call_str(p, r.get("args", []))]
	column.add_child(head)

	var indent := MarginContainer.new()
	indent.add_theme_constant_override("margin_left", 36)
	column.add_child(indent)
	var details := VBoxContainer.new()
	details.add_theme_constant_override("separation", 2)
	indent.add_child(details)

	var expected := Label.new()
	expected.theme_type_variation = &"Detail"
	expected.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	expected.text = ("expected output: " if print_only else "expected: ") + _expected_text(t, rtype, print_only)
	details.add_child(expected)

	var got := Label.new()
	got.theme_type_variation = &"DetailCode"
	got.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	got.text = ("your output: " if print_only else "yours: ") + _got_text(t, r, rtype, print_only)
	if r.has("error"):
		got.text += "\n" + str(r.error)
	details.add_child(got)
	return column


func _expected_text(t: Dictionary, rtype: String, print_only: bool) -> String:
	if print_only:
		return _lines(t.get("out", []), "(nothing printed)")
	var text := Fmt.fmt_typed(t.get("expect", null), rtype)
	if t.has("out"):
		text += "\nprints " + _lines(t.out, "nothing")
	return text


func _got_text(t: Dictionary, r: Dictionary, rtype: String, print_only: bool) -> String:
	var out: Array = r.get("out", [])
	if print_only:
		return _lines(out, "(nothing printed)")
	var text := Fmt.fmt_typed(r.get("got", null), rtype)
	if t.has("out"):
		text += "\nprints " + _lines(out, "nothing")
	return text


func _lines(lines: Array, when_empty: String) -> String:
	if lines.is_empty():
		return when_empty
	var strings := []
	for line in lines:
		strings.append(str(line))
	return "\n".join(strings)


func _show_errors(lines: Array, fallback: String) -> void:
	var text := "\n".join(lines)
	if text == "":
		text = fallback
	errors_label.visible = text != ""
	errors.visible = text != ""
	errors.text = text
	error_line = -1
	var re := RegEx.new()
	re.compile("line (\\d+)")
	var m := re.search(text)
	if m:
		error_line = int(m.get_string(1)) - 1
