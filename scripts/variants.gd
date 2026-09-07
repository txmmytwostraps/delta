class_name Variants
## Drills: a problem with a `generator` can be served with fresh arguments,
## like the site's variants.js. The expected answers are never hand-written:
## the reference solution is run through the judge on the rolled arguments
## and its results become the tests. Spec per argument: {int:[lo,hi]}
## {float:[lo,hi,decimals]} {bool:true} {pick:[...]} {array:{len:[lo,hi],
## of:spec}} {v2:[[..],[..],decimals]} {rect:[[..],[..],[..],[..]]}.


## The site's xorshift generator, so a seed rolls the same numbers.
class Rng:
	var s: int

	func _init(seed: int) -> void:
		s = seed & 0xFFFFFFFF
		if s == 0:
			s = 1

	func next() -> float:
		s ^= (s << 13) & 0xFFFFFFFF
		s &= 0xFFFFFFFF
		s ^= s >> 17
		s ^= (s << 5) & 0xFFFFFFFF
		s &= 0xFFFFFFFF
		return float(s) / 4294967296.0


static func between(r: Rng, lo: int, hi: int) -> int:
	return lo + int(floor(r.next() * float(hi - lo + 1)))


static func between_f(r: Rng, lo: float, hi: float, d: int) -> float:
	return float(("%." + str(d) + "f") % (lo + r.next() * (hi - lo)))


static func roll(spec: Dictionary, r: Rng) -> Variant:
	if spec.has("int"):
		return between(r, int(spec.int[0]), int(spec.int[1]))
	if spec.has("float"):
		var f: Array = spec.float
		return between_f(r, float(f[0]), float(f[1]), 1 if f.size() < 3 or f[2] == null else int(f[2]))
	if spec.has("bool"):
		return r.next() < 0.5
	if spec.has("pick"):
		var options: Array = spec.pick
		var v: Variant = options[between(r, 0, options.size() - 1)]
		return v.duplicate(true) if (v is Array or v is Dictionary) else v
	if spec.has("array"):
		var n := between(r, int(spec.array.len[0]), int(spec.array.len[1]))
		var out := []
		for i in n:
			out.append(roll(spec.array.of, r))
		return out
	if spec.has("v2"):
		var v: Array = spec.v2
		var d := int(v[2]) if v.size() > 2 and v[2] != null else 0
		return {"$v2": [between_f(r, float(v[0][0]), float(v[0][1]), d), between_f(r, float(v[1][0]), float(v[1][1]), d)]}
	if spec.has("rect"):
		var out := []
		for pair in spec.rect:
			out.append(between(r, int(pair[0]), int(pair[1])))
		return {"$rect": out}
	return null


static func roll_args(generator: Array, r: Rng) -> Array:
	var out := []
	for spec in generator:
		out.append(roll(spec, r))
	return out


static func can_drill(p: Dictionary) -> bool:
	return p.get("generator", null) is Array and not (p.generator as Array).is_empty()


## A variant of problem p: three fresh argument sets with the reference
## solution's answers as the expected results. {} when the solution cannot
## run on the rolled arguments (a range that does not fit the problem).
static func make(p: Dictionary, seed: int) -> Dictionary:
	if not can_drill(p):
		return {}
	var r := Rng.new(seed)
	var want_out := false
	for t in p.get("tests", []):
		if t.has("out"):
			want_out = true
	var arg_sets := []
	var seen := {}
	for t in p.get("tests", []):
		seen[JSON.stringify(t.get("args", []))] = true
	var tries := 0
	while arg_sets.size() < 3 and tries < 30:
		tries += 1
		var args := roll_args(p.generator, r)
		var key := JSON.stringify(args)
		if seen.has(key):
			continue
		seen[key] = true
		arg_sets.append(args)
	if arg_sets.size() < 2:
		return {}
	var probe: Dictionary = p.duplicate(true)
	probe["tests"] = arg_sets.map(func(args: Array) -> Dictionary: return {"args": args, "expect": null})
	var reply: Dictionary = await Grader.run(str(p.solution), probe)
	var result: Dictionary = reply.result
	if result.status != "ok":
		return {}
	var tests := []
	for i in result.results.size():
		var res: Dictionary = result.results[i]
		if res.has("error"):
			continue
		var t := {"name": "Fresh numbers %d" % (i + 1), "args": arg_sets[i], "expect": res.get("got", null)}
		var out: Array = res.get("out", [])
		if want_out or (t.expect == null and out.size() > 0):
			t["out"] = out
		if t.expect == null and not t.has("out"):
			continue
		tests.append(t)
	if tests.size() < 2:
		return {}
	var v: Dictionary = p.duplicate(true)
	v["tests"] = tests
	v["variant"] = true
	v["seed"] = seed
	return v
