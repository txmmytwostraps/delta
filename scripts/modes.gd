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


# ---- what does this print: how the options are shown ----

## The printed lines of an option value, as strings.
static func as_lines(value: Variant) -> Array:
	var arr: Array = value if value is Array else [value]
	var out := []
	for line in arr:
		out.append(str(line))
	return out


## The lines that tell one option from the others: for each of the others,
## the first line where the two part company. Sorted, without repeats.
static func distinguishing_lines(options: Array, index: int) -> Array:
	var lines := as_lines(options[index])
	var marks := []
	for j in options.size():
		if j == index:
			continue
		var other := as_lines(options[j])
		var d := 0
		while d < lines.size() and d < other.size() and str(lines[d]) == str(other[d]):
			d += 1
		if d < lines.size() and not marks.has(d):
			marks.append(d)
	marks.sort()
	return marks


## The rows to show for one option: its lines, stacked, never joined onto
## one line. More than max_rows and it is cut short around the line that
## tells it from the option it is most like, so two options are never shown
## the same rows: "…" stands for lines skipped in the middle, "…+N more" for
## the rest.
static func print_rows(options: Array, index: int, max_rows: int = 4) -> Array:
	var lines := as_lines(options[index])
	if lines.size() <= max_rows:
		return lines
	var marks := distinguishing_lines(options, index)
	var shown: Array = lines.slice(0, max_rows - 1)
	if not marks.is_empty() and int(marks[-1]) >= max_rows - 1:
		shown = [lines[0], "…", lines[int(marks[-1])]]
	var real := 0
	for row in shown:
		if row != "…":
			real += 1
	shown.append("…+%d more" % (lines.size() - real))
	return shown


## Whether the options can be told apart in the rows there is room for. When
## they cannot, and no shorter question works either, the problem has no
## print version at all.
static func print_rows_distinct(options: Array, max_rows: int = 4) -> bool:
	var seen := []
	for i in options.size():
		var rows := print_rows(options, i, max_rows)
		if seen.has(rows):
			return false
		seen.append(rows)
	return true


## A shorter question for long output. "last" whenever the outputs end
## differently: the answer has to be worked out, not counted off the page.
## "count" only when they end the same way, and only when the lines cannot
## be counted straight off the code (one print call, one line). "" keeps the
## four stacked outputs.
static func short_form(options: Array, solution: String = "") -> String:
	if options.is_empty() or not (options[0] is Array) or as_lines(options[0]).size() <= 4:
		return ""
	if options.size() < 2:
		return ""
	var right := as_lines(options[0])
	var last: String = right[-1] if right.size() > 0 else ""
	var ends_apart := true
	for i in range(1, options.size()):
		var lines := as_lines(options[i])
		if (lines[-1] if lines.size() > 0 else "") == last:
			ends_apart = false
	if ends_apart:
		return "last"
	if solution != "" and output_calls(solution) == right.size():
		return ""
	return "count"


## How many lines a reader counts off the page: the calls the code makes,
## one line each. That is the real count only when nothing repeats and
## every call prints exactly once.
static func output_calls(solution: String) -> int:
	var re := RegEx.new()
	re.compile("^\\s*[\\w.]+\\s*\\(.*\\)\\s*$")
	var n := 0
	for line in solution.split("\n"):
		if re.search(str(line)) != null:
			n += 1
	return n


## Plausible wrong answers to "what is the last line": what the buggy
## versions ended with, then the lines the reader might stop on — the one
## before the last, and the rest from the end backwards.
static func last_distractors(options: Array, want: int) -> Array:
	var right := as_lines(options[0])
	var last: String = right[-1] if right.size() > 0 else ""
	var out := []
	for i in range(1, options.size()):
		var lines := as_lines(options[i])
		var s: String = lines[-1] if lines.size() > 0 else ""
		if s != last and not out.has(s):
			out.append(s)
	for i in range(right.size() - 2, -1, -1):
		if out.size() >= want:
			break
		var s := str(right[i])
		if s != last and not out.has(s):
			out.append(s)
	return out.slice(0, want)


## Plausible wrong answers to "how many lines": what the buggy versions
## printed, then the misreadings — one line per print call (a loop's repeat
## missed), the lines counted without their repeats, and the lines that are
## not blank (a print() taken for printing nothing).
static func count_distractors(options: Array, solution: String, want: int) -> Array:
	var right := as_lines(options[0])
	var n := right.size()
	var out := []
	var add := func(v: int) -> void:
		if v > 0 and v != n and not out.has(v):
			out.append(v)
	for i in range(1, options.size()):
		add.call(as_lines(options[i]).size())
	if solution != "":
		add.call(output_calls(solution))
	var seen := []
	var blank := 0
	for line in right:
		if not seen.has(str(line)):
			seen.append(str(line))
		if str(line).strip_edges() == "":
			blank += 1
	add.call(seen.size())
	add.call(n - blank)
	return out.slice(0, want)


# ---- fill in the blank ----

const COMPARISONS := [" == ", " != ", " < ", " <= ", " > ", " >= "]
const ARITHMETIC := [" + ", " - ", " * ", " / ", " % "]
const CONTROL_WORDS := ["if", "elif", "while", "for", "func", "return", "and", "or", "not", "in", "range"]
## Which token a topic's problems blank, best first.
const BLANK_ORDER := {
	"comparison": ["comparison", "operator", "name", "call"],
	"name": ["name", "call", "operator", "comparison"],
	"operator": ["operator", "name", "comparison", "call"],
	"call": ["call", "name", "operator", "comparison"],
}


## The kind of token a concept's problems are about, from its id.
static func blank_kind_for(concept: String) -> String:
	var c := concept.to_lower()
	for pair in [["cond", "comparison"], ["compar", "comparison"], ["ifelse", "comparison"], ["arith", "operator"], ["multiply", "operator"], ["delta", "operator"], ["variable", "name"], ["member", "name"], ["readable", "name"], ["func", "call"], ["param", "call"], ["return", "call"], ["giant", "call"], ["turtle", "call"]]:
		if c.contains(pair[0]):
			return pair[1]
	return "operator"


## The words the other problems of a topic use: the names they call and the
## names they declare. A wrong chip for a name or a call comes from here, so
## it is a word from the same lesson rather than one out of nowhere.
static func lesson_words(problems: Array, exclude_id: String) -> Array:
	var out := []
	var call := RegEx.new()
	call.compile("(?<![\\w.])(\\w+)\\s*\\(")
	for q in problems:
		if str(q.get("id", "")) == exclude_id:
			continue
		var solution := str(q.get("solution", ""))
		for m in call.search_all(solution):
			var n := m.get_string(1)
			if not CONTROL_WORDS.has(n) and not out.has(n):
				out.append(n)
		for n in _declared_names(Array(solution.split("\n"))):
			if not out.has(n):
				out.append(n)
	return out


## One kind of token, from the whole solution.
static func _spot_of(kind: String, lines: Array, seed: String) -> Dictionary:
	match kind:
		"comparison":
			return _find_op_token(lines, COMPARISONS, seed + ":cmp")
		"operator":
			return _find_op_token(lines, ARITHMETIC, seed + ":op")
		"name":
			return _find_name_token(lines, seed + ":name")
		"call":
			return _find_call_token(lines, seed + ":call")
	return _find_last_token(lines)


## The blank for a problem: the spot and its chips, the right one first.
## The kinds are tried in the order its topic wants, and a kind that cannot
## offer four chips gives way to the next. {} when none can.
static func blank_for(problem: Dictionary, pool: Array = []) -> Dictionary:
	var lines := Array(str(problem.get("solution", "")).split("\n"))
	var seed := str(problem.get("id", ""))
	var kinds: Array = BLANK_ORDER.get(blank_kind_for(str(problem.get("concept", ""))), BLANK_ORDER.operator).duplicate()
	kinds.append("last")
	for kind in kinds:
		var spot := _spot_of(kind, lines, seed)
		if spot.is_empty():
			continue
		var chips := blank_choices(spot, lines, pool, seed)
		if chips.size() >= 4:
			return {"spot": spot, "chips": chips}
	return {}


## The token a problem's topic is about, whether or not it has chips to go
## with it: the one its lesson teaches, else the last token that is not
## boilerplate. { "line", "start", "end", "token", "kind" }, or {}.
static func blank_spot(problem: Dictionary) -> Dictionary:
	var lines := Array(str(problem.get("solution", "")).split("\n"))
	var seed := str(problem.get("id", ""))
	for kind in BLANK_ORDER.get(blank_kind_for(str(problem.get("concept", ""))), BLANK_ORDER.operator):
		var spot := _spot_of(kind, lines, seed)
		if not spot.is_empty():
			return spot
	return _find_last_token(lines)


## An operator, spaced as this course writes them; the blank covers the
## operator itself, not the spaces around it.
static func _find_op_token(lines: Array, group: Array, seed: String) -> Dictionary:
	var cands := []
	for li in lines.size():
		var code: String = _code_part(lines[li])[0]
		if _is_func_line(code):
			continue
		var masked := _mask(code)
		for op in group:
			var pos := masked.find(op)
			while pos >= 0:
				cands.append({"line": li, "start": pos + 1, "end": pos + op.length() - 1, "token": str(op).strip_edges(), "kind": "operator", "group": group})
				pos = masked.find(op, pos + op.length())
	if cands.is_empty():
		return {}
	return cands[seeded_order(seed, cands.size())[0]]


## A use of a declared name, or its declaration when there is no use.
static func _find_name_token(lines: Array, seed: String) -> Dictionary:
	var names := _declared_names(lines)
	if names.size() < 2:
		return {}
	var uses := []
	var decls := []
	for li in lines.size():
		var code: String = _code_part(lines[li])[0]
		var head := code.strip_edges(true, false)
		var masked := _mask(code)
		var is_decl: bool = head.begins_with("var ") or head.begins_with("const ") or _is_func_line(code)
		for a in names:
			var re := RegEx.new()
			re.compile("(?<![\\w.\"'])" + a + "(?![\\w\"'])")
			for m in re.search_all(masked):
				var spot := {"line": li, "start": m.get_start(), "end": m.get_end(), "token": a, "kind": "name", "names": names}
				if is_decl:
					decls.append(spot)
				else:
					uses.append(spot)
	var pool: Array = uses if uses.size() > 0 else decls
	if pool.is_empty():
		return {}
	return pool[seeded_order(seed, pool.size())[0]]


## The name of a function being called, never a keyword or a declaration.
static func _find_call_token(lines: Array, seed: String) -> Dictionary:
	var call := RegEx.new()
	call.compile("(?<![\\w.])(\\w+)\\s*\\(")
	var cands := []
	for li in lines.size():
		var code: String = _code_part(lines[li])[0]
		if _is_func_line(code):
			continue
		for m in call.search_all(_mask(code)):
			if CONTROL_WORDS.has(m.get_string(1)):
				continue
			cands.append({"line": li, "start": m.get_start(1), "end": m.get_end(1), "token": m.get_string(1), "kind": "call"})
	if cands.is_empty():
		return {}
	return cands[seeded_order(seed, cands.size())[0]]


## The fallback: the last word or number on the last line that is not a
## declaration, a blank line, or "pass".
static func _find_last_token(lines: Array) -> Dictionary:
	var word := RegEx.new()
	word.compile("[A-Za-z_][\\w.]*|\\d+")
	for i in lines.size():
		var li := lines.size() - 1 - i
		var code: String = _code_part(lines[li])[0]
		var head := code.strip_edges(true, false)
		if head == "" or head == "pass" or _is_func_line(code):
			continue
		var ms := word.search_all(_mask(code))
		if ms.is_empty():
			continue
		var m: RegExMatch = ms[-1]
		return {"line": li, "start": m.get_start(), "end": m.get_end(), "token": m.get_string(), "kind": "token", "names": _declared_names(lines)}
	return {}


## The chips for a blank: the right token first, then wrong ones by the same
## rules fix-the-bug uses (a wrong operator, off by one, a name in scope, a
## similar function from the same lesson). An empty list means the problem
## has no blank worth offering.
static func blank_choices(spot: Dictionary, lines: Array, pool: Array, seed: String, want: int = 4) -> Array:
	if spot.is_empty():
		return []
	var right: String = str(spot.token)
	var wrong := []
	var add := func(s: String) -> void:
		if s != "" and s != right and not wrong.has(s):
			wrong.append(s)
	match str(spot.kind):
		"operator":
			for op in spot.get("group", ARITHMETIC):
				add.call(str(op).strip_edges())
		"name":
			for n in spot.get("names", _declared_names(lines)):
				add.call(str(n))
			for n in pool:
				add.call(str(n))
		"call":
			for n in pool:
				add.call(str(n))
			for n in _declared_names(lines):
				add.call(str(n))
		_:
			if right.is_valid_int():
				for alt in [int(right) + 1, int(right) - 1, int(right) * 2]:
					if alt >= 0:
						add.call(str(alt))
			for n in spot.get("names", _declared_names(lines)):
				add.call(str(n))
			for n in pool:
				add.call(str(n))
	if wrong.size() < want - 1:
		return []
	var order := seeded_order(seed + ":chips", wrong.size())
	var picked := []
	for k in order:
		if picked.size() < want - 1:
			picked.append(wrong[k])
	return [right] + picked


## The solution with the blank filled by `token`; "" leaves the gap.
static func blank_code(solution: String, spot: Dictionary, token: String) -> String:
	if spot.is_empty():
		return solution
	var lines := Array(solution.split("\n"))
	var line: String = lines[spot.line]
	lines[spot.line] = line.substr(0, spot.start) + token + line.substr(spot.end)
	return "\n".join(lines)
