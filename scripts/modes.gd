class_name Modes
## The puzzles made from a problem: the lines of its solution to put in
## order, and a solution with one bug planted in it. The same maths as the
## site's parsons.js and mutate.js, so a problem gives the same puzzle on
## both.


# ---- a fixed random order from the problem id ----

## The same shuffle for the same seed, everywhere. (FNV-1a hash, then a
## linear congruential generator, all in 32-bit arithmetic like the site.)
static func seeded_order(seed: String, n: int) -> Array:
	var h := 2166136261
	for i in seed.length():
		h = (h ^ seed.unicode_at(i)) & 0xFFFFFFFF
		h = (h * 16777619) & 0xFFFFFFFF
	var order := []
	for i in n:
		order.append(i)
	var i := n - 1
	while i > 0:
		h = (((h * 1664525) & 0xFFFFFFFF) + 1013904223) & 0xFFFFFFFF
		var j := h % (i + 1)
		var tmp = order[i]
		order[i] = order[j]
		order[j] = tmp
		i -= 1
	return order


# ---- put the lines in order ----

## The solution's non-empty lines, shuffled. Indentation stays on each line.
static func parsons_lines(solution: String, seed: String) -> Array:
	var lines := []
	for line in solution.split("\n"):
		if line.strip_edges() != "":
			lines.append(line)
	var order := seeded_order(seed, lines.size())
	var solved := true
	for i in order.size():
		if order[i] != i:
			solved = false
			break
	if solved and order.size() > 1:   # never start solved
		order = order.slice(1) + [order[0]]
	var out := []
	for i in order:
		out.append(lines[i])
	return out


# ---- fix the bug ----

const OPERATOR_SWAPS := [[" + ", " - "], [" - ", " + "], [" * ", " + "], [" < ", " <= "], [" > ", " >= "], [" <= ", " < "], [" >= ", " > "], [" == ", " != "], [" != ", " == "], [" and ", " or "], [" or ", " and "], ["+=", "-="], ["-=", "+="]]
const KINDS := ["operator", "off_by_one", "variable", "missing_return", "swap_args"]


## Every candidate mutation of a solution, best first for this problem id:
## [{ "code": String, "kind": String }]. The caller runs them through the
## judge and keeps the first that compiles and fails a test.
static func candidates(solution: String, seed: String) -> Array:
	var lines := Array(solution.split("\n"))
	var out := []
	var order := seeded_order(seed, KINDS.size())
	for round in 3:
		for k in order:
			var pick: int = round + seeded_order(seed + str(k), 7)[0]
			var m := _mutate(KINDS[k], lines, pick)
			if m.is_empty():
				continue
			var code: String = "\n".join(m.lines)
			if code == solution:
				continue
			var seen := false
			for o in out:
				if o.code == code:
					seen = true
					break
			if not seen:
				out.append({"code": code, "kind": m.kind})
	return out


const OPERATOR_GROUPS := [
	[" + ", " - ", " * ", " / ", " % "],
	[" < ", " <= ", " > ", " >= ", " == ", " != "],
	[" and ", " or "],
	["+=", "-=", "*="],
]
const STATEMENT_WORDS := ["return", "var", "const", "if", "elif", "else", "while", "for", "func", "pass", "break", "continue", "match", "print", "out"]


## Replacement lines for one line of code: every single change of an
## operator, a number, a variable name, a return, or two arguments, in both
## directions, so the fix for a planted bug is always among them. The
## original line itself is left out.
static func line_variants(line: String, all_lines: Array) -> Array:
	var out := []
	var parts := _code_part(line)
	var code: String = parts[0]
	var comment: String = parts[1]
	var indent := code.substr(0, code.length() - code.strip_edges(true, false).length())
	var body := code.strip_edges(true, false)
	var add := func(new_code: String) -> void:
		var candidate := new_code + comment
		if candidate != line and not out.has(candidate):
			out.append(candidate)

	# Operators: each occurrence, each alternative in its group.
	for group in OPERATOR_GROUPS:
		for op in group:
			var pos := _find_outside_strings(code, op, 0)
			while pos >= 0:
				for alt in group:
					if alt != op:
						add.call(code.substr(0, pos) + alt + code.substr(pos + op.length()))
				pos = _find_outside_strings(code, op, pos + op.length())

	# Numbers: one up, one down.
	var number := RegEx.new()
	number.compile("(?<![\\w.])(\\d+)(?![\\w.])")
	for m in number.search_all(_blank_strings(code)):
		var n := int(m.get_string(1))
		for alt in [n + 1, n - 1]:
			if alt >= 0:
				add.call(code.substr(0, m.get_start()) + str(alt) + code.substr(m.get_end()))

	# A missing or an extra return.
	if body.begins_with("return "):
		add.call(indent + body.substr(7))
	elif body != "" and not _starts_with_word(body, STATEMENT_WORDS) and not _is_assignment(body):
		add.call(indent + "return " + body)

	# Variable and parameter names: each occurrence, each other name.
	var names := _declared_names(all_lines)
	var blanked := _blank_strings(code)
	for a in names:
		var re := RegEx.new()
		re.compile("(?<![\\w.\"'])" + a + "(?![\\w\"'])")
		for m in re.search_all(blanked):
			for b in names:
				if b != a:
					add.call(code.substr(0, m.get_start()) + b + code.substr(m.get_end()))

	# Two arguments the other way round.
	var call := RegEx.new()
	call.compile("(\\w+)\\(([^(),]+),\\s*([^(),]+)\\)")
	for m in call.search_all(blanked):
		if m.get_string(2).strip_edges() != m.get_string(3).strip_edges():
			add.call(code.substr(0, m.get_start()) + "%s(%s, %s)" % [m.get_string(1), m.get_string(3).strip_edges(), m.get_string(2).strip_edges()] + code.substr(m.get_end()))
	return out


## The code with the inside of every string replaced by spaces, so searches
## keep their positions but never match inside quotes.
static func _blank_strings(code: String) -> String:
	return _mask(code)


static func _mask(code: String) -> String:
	var re := RegEx.new()
	re.compile("\"(?:[^\"\\\\]|\\\\.)*\"|'(?:[^'\\\\]|\\\\.)*'")
	var out := code
	for m in re.search_all(code):
		out = out.substr(0, m.get_start()) + " ".repeat(m.get_end() - m.get_start()) + out.substr(m.get_end())
	return out


static func _find_outside_strings(code: String, needle: String, from: int) -> int:
	return _mask(code).find(needle, from)


static func _starts_with_word(body: String, words: Array) -> bool:
	for w in words:
		if body == w or body.begins_with(w + " ") or body.begins_with(w + "(") or body.begins_with(w + ":") or body.begins_with(w + "\t"):
			return true
	return false


static func _is_assignment(body: String) -> bool:
	var masked := _mask(body)
	for op in [" = ", "+=", "-=", "*=", "/="]:
		if masked.find(op) >= 0:
			return true
	return false


static func _mutate(kind: String, lines: Array, pick: int, name_source: Array = []) -> Dictionary:
	match kind:
		"operator":
			return _mutate_operator(lines, pick)
		"off_by_one":
			return _mutate_off_by_one(lines, pick)
		"variable":
			return _mutate_variable(lines, pick, name_source if name_source.size() > 0 else lines)
		"missing_return":
			return _mutate_missing_return(lines, pick)
		"swap_args":
			return _mutate_swap_args(lines, pick)
	return {}


## A line split into code and its trailing comment.
static func _code_part(line: String) -> Array:
	var idx := line.find("#")
	if idx < 0:
		return [line, ""]
	var code := line.substr(0, idx).rstrip(" \t")
	return [code, line.substr(code.length())]


## The pieces of a line that are not inside quotes get fn applied.
static func _outside_strings(code: String, fn: Callable) -> String:
	var re := RegEx.new()
	re.compile("\"(?:[^\"\\\\]|\\\\.)*\"|'(?:[^'\\\\]|\\\\.)*'")
	var out := ""
	var pos := 0
	for m in re.search_all(code):
		out += fn.call(code.substr(pos, m.get_start() - pos))
		out += m.get_string()
		pos = m.get_end()
	out += fn.call(code.substr(pos))
	return out


static func _is_func_line(code: String) -> bool:
	return code.strip_edges(true, false).begins_with("func ") or code.strip_edges(true, false).begins_with("func\t")


static func _replace_first(s: String, from: String, to: String) -> String:
	var idx := s.find(from)
	if idx < 0:
		return s
	return s.substr(0, idx) + to + s.substr(idx + from.length())


static func _mutate_operator(lines: Array, pick: int) -> Dictionary:
	var cands := []
	for li in lines.size():
		var code: String = _code_part(lines[li])[0]
		if _is_func_line(code):
			continue
		for swap in OPERATOR_SWAPS:
			if code.find(swap[0]) >= 0:
				cands.append({"li": li, "from": swap[0], "to": swap[1]})
	if cands.is_empty():
		return {}
	var c: Dictionary = cands[pick % cands.size()]
	var parts := _code_part(lines[c.li])
	var out := lines.duplicate()
	out[c.li] = _outside_strings(parts[0], func(s: String) -> String: return _replace_first(s, c.from, c.to)) + parts[1]
	if "\n".join(out) == "\n".join(lines):
		return {}
	return {"lines": out, "kind": "an operator"}


static func _mutate_off_by_one(lines: Array, pick: int) -> Dictionary:
	var number := RegEx.new()
	number.compile("(?<![\\w.])(\\d+)(?![\\w.])")
	var cands := []
	for li in lines.size():
		var code: String = _code_part(lines[li])[0]
		if _is_func_line(code):
			continue
		for m in number.search_all(code):
			cands.append({"li": li, "n": m.get_string(1)})
	if cands.is_empty():
		return {}
	var c: Dictionary = cands[pick % cands.size()]
	var parts := _code_part(lines[c.li])
	var exact := RegEx.new()
	exact.compile("(?<![\\w.])" + c.n + "(?![\\w.])")
	var done := [false]
	var out := lines.duplicate()
	out[c.li] = _outside_strings(parts[0], func(s: String) -> String:
		if done[0]:
			return s
		var m := exact.search(s)
		if m == null:
			return s
		done[0] = true
		return s.substr(0, m.get_start()) + str(int(m.get_string()) + 1) + s.substr(m.get_end())) + parts[1]
	return {"lines": out, "kind": "a number that is off by one"}


static func _declared_names(lines: Array) -> Array:
	var names := []
	var decl := RegEx.new()
	decl.compile("^\\s*(?:var|const)\\s+(\\w+)")
	var fn := RegEx.new()
	fn.compile("^\\s*func\\s+\\w+\\(([^)]*)\\)")
	for line in lines:
		var code: String = _code_part(line)[0]
		var m := decl.search(code)
		if m and not names.has(m.get_string(1)):
			names.append(m.get_string(1))
		var f := fn.search(code)
		if f:
			for p in f.get_string(1).split(","):
				var n := p.strip_edges().get_slice(":", 0).get_slice("=", 0).strip_edges()
				if n != "" and not names.has(n):
					names.append(n)
	return names


static func _mutate_variable(lines: Array, pick: int, name_source: Array) -> Dictionary:
	var names := _declared_names(name_source)
	if names.size() < 2:
		return {}
	var cands := []
	for li in lines.size():
		var code: String = _code_part(lines[li])[0]
		var head := code.strip_edges(true, false)
		if head.begins_with("func ") or head.begins_with("var ") or head.begins_with("const "):
			continue
		for a in names:
			var re := RegEx.new()
			re.compile("(?<![\\w.\"'])" + a + "(?![\\w\"'])")
			if re.search(code):
				for b in names:
					if b != a:
						cands.append({"li": li, "a": a, "b": b})
	if cands.is_empty():
		return {}
	var c: Dictionary = cands[pick % cands.size()]
	var parts := _code_part(lines[c.li])
	var re := RegEx.new()
	re.compile("(?<![\\w.\"'])" + c.a + "(?![\\w\"'])")
	var out := lines.duplicate()
	out[c.li] = _outside_strings(parts[0], func(s: String) -> String:
		var m := re.search(s)
		if m == null:
			return s
		return s.substr(0, m.get_start()) + c.b + s.substr(m.get_end())) + parts[1]
	return {"lines": out, "kind": "a variable name"}


static func _mutate_missing_return(lines: Array, pick: int) -> Dictionary:
	var ret := RegEx.new()
	ret.compile("^\\s*return\\s+\\S")
	var cands := []
	for li in lines.size():
		if ret.search(_code_part(lines[li])[0]):
			cands.append(li)
	if cands.is_empty():
		return {}
	var li: int = cands[pick % cands.size()]
	var word := RegEx.new()
	word.compile("return\\s+")
	var out := lines.duplicate()
	var m := word.search(lines[li])
	out[li] = lines[li].substr(0, m.get_start()) + lines[li].substr(m.get_end())
	return {"lines": out, "kind": "a missing return"}


static func _mutate_swap_args(lines: Array, pick: int) -> Dictionary:
	var call := RegEx.new()
	call.compile("(\\w+)\\(([^(),]+),\\s*([^(),]+)\\)")
	var cands := []
	for li in lines.size():
		var code: String = _code_part(lines[li])[0]
		if _is_func_line(code):
			continue
		for m in call.search_all(code):
			if m.get_string(2).strip_edges() != m.get_string(3).strip_edges():
				cands.append({"li": li, "whole": m.get_string(), "swapped": "%s(%s, %s)" % [m.get_string(1), m.get_string(3).strip_edges(), m.get_string(2).strip_edges()]})
	if cands.is_empty():
		return {}
	var c: Dictionary = cands[pick % cands.size()]
	var parts := _code_part(lines[c.li])
	var out := lines.duplicate()
	out[c.li] = _outside_strings(parts[0], func(s: String) -> String: return _replace_first(s, c.whole, c.swapped)) + parts[1]
	return {"lines": out, "kind": "two swapped arguments"}


# ---- what does this print ----

## Wrong answers that look plausible next to the right one. value is the
## judge's value for the test (a return value, or the printed lines as an
## Array when print_only). Returns up to `want` values, none equal to it.
static func fallback_distractors(value: Variant, want: int) -> Array:
	if want <= 0:
		return []
	var ideas := []
	if value is Array:
		var arr: Array = value
		var rev := arr.duplicate()
		rev.reverse()
		ideas.append(rev)
		ideas.append(arr.slice(0, maxi(0, arr.size() - 1)))
		if arr.size() > 0 and (arr[0] is int or arr[0] is float):
			var bumped := arr.duplicate()
			bumped[0] = arr[0] + 1
			ideas.append(bumped)
		if arr.size() > 0 and arr[0] is String:
			# Printed lines: vary the first line the way a typo would.
			for alt in fallback_distractors(arr[0], 3):
				var changed := arr.duplicate()
				changed[0] = alt
				ideas.append(changed)
		ideas.append(arr + arr.slice(0, 1))
		ideas.append([])
	elif value is float or value is int:
		ideas.append(value + 1)
		ideas.append(value - 1)
		ideas.append(value * 2)
		ideas.append(0)
		ideas.append(-value)
	elif value is String:
		var s: String = value
		ideas.append(s.to_upper() if s.to_upper() != s else s.to_lower())
		ideas.append(s.substr(0, maxi(1, s.length() - 1)))
		ideas.append(s.reverse())
		ideas.append("")
	elif value is bool:
		ideas.append(not value)
		ideas.append(1 if value else 0)
		ideas.append(null)
	elif value == null:
		ideas.append(0)
		ideas.append("")
		ideas.append(false)
	else:
		ideas.append(null)
		ideas.append(0)
	var out := []
	for idea in ideas:
		if idea != value and not out.has(idea):
			out.append(idea)
		if out.size() >= want:
			break
	return out
