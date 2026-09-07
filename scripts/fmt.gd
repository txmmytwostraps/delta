class_name Fmt
## How values, calls and errors are written on screen. Same choices as the
## site's practice page, so a result reads the same on both.


## 6 -> "6", 6.0 -> "6", 2.5 -> "2.5", 1.23456 -> "1.2346"
static func num(v: Variant) -> String:
	if v is float:
		if v == floor(v) and absf(v) < 9.0e15:
			return str(int(v))
		return str(snappedf(v, 0.0001))
	return str(v)


## Vectors and rectangles travel as {"$v2": [x, y]} and {"$rect": [x, y, w, h]};
## show them the way Godot writes them. "" for anything else.
static func godot_value(v: Variant) -> String:
	if v is Dictionary:
		if v.has("$v2") and v["$v2"] is Array:
			return "Vector2(%s)" % ", ".join(v["$v2"].map(num))
		if v.has("$rect") and v["$rect"] is Array:
			return "Rect2(%s)" % ", ".join(v["$rect"].map(num))
	if v is Array:
		for x in v:
			if x is Dictionary and (x.has("$v2") or x.has("$rect")):
				return "[%s]" % ", ".join(v.map(fmt_typed_any))
	return ""


static func fmt_typed_any(v: Variant) -> String:
	return fmt_typed(v, "")


## A value as the learner should read it: whole floats without ".0" unless
## the function is declared to return a float, strings in quotes, arrays and
## dictionaries as JSON.
static func fmt_typed(v: Variant, type: String) -> String:
	var gv := godot_value(v)
	if gv != "":
		return gv
	if (v is float or v is int) and type == "float" and float(v) == floor(float(v)):
		return "%d.0" % int(v)
	return to_json(v)


static func to_json(v: Variant) -> String:
	return JSON.stringify(_plain(v))


## Whole floats become ints so JSON shows 6, not 6.0 (the site's JSON has no
## int/float difference, so it shows 6 too).
static func _plain(v: Variant) -> Variant:
	if v is float and v == floor(v) and absf(v) < 9.0e15:
		return int(v)
	if v is Array:
		return v.map(_plain)
	if v is Dictionary:
		var d := {}
		for k in v:
			d[k] = _plain(v[k])
		return d
	return v


## The parameter types written in the signature, "" where there is none.
static func param_types(signature: String) -> Array:
	var re := RegEx.new()
	re.compile("\\((.*)\\)")
	var m := re.search(signature)
	var inside := m.get_string(1) if m else ""
	var types := []
	for part in inside.split(",", false):
		var after := part.get_slice(":", 1) if part.contains(":") else ""
		types.append(after.get_slice("=", 0).strip_edges())
	return types


static func return_type(signature: String) -> String:
	var re := RegEx.new()
	re.compile("->\\s*(\\w+)")
	var m := re.search(signature)
	return m.get_string(1) if m else ""


static func function_name(signature: String) -> String:
	var re := RegEx.new()
	re.compile("func\\s+(\\w+)")
	var m := re.search(signature)
	return m.get_string(1) if m else "solve"


## "solve(3, 4)" for a test's arguments.
static func call_str(problem: Dictionary, args: Array) -> String:
	var types := param_types(str(problem.get("signature", "")))
	var parts := []
	for i in args.size():
		parts.append(fmt_typed(args[i], types[i] if i < types.size() else ""))
	return "%s(%s)" % [function_name(str(problem.get("signature", ""))), ", ".join(parts)]


## True when the problem checks printed lines only, with no return value.
static func print_only(problem: Dictionary) -> bool:
	for t in problem.get("tests", []):
		if t.get("expect", 0) == null and t.has("out"):
			return true
	return false
