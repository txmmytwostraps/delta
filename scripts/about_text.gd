class_name AboutText
## About, from the site's README at the pinned commit (bank/about.md): the
## short part up to the "about-more" marker, like the site's About page. A
## small Markdown subset: headings, paragraphs, bullet lists, fenced code.


## The blocks: [{ "kind": h1 | h2 | h3 | p | list | code, "text" | "items" }].
static func blocks(md: String) -> Array:
	var more := md.find("<!-- about-more -->")
	var end := md.find("<!-- about-end -->")
	var short := md.substr(0, more if more >= 0 else (end if end >= 0 else md.length()))
	var out := []
	var para := []
	var list := []
	var code: Variant = null
	var flush := func() -> void:
		if para.size() > 0:
			out.append({"kind": "p", "text": _inline(" ".join(para))})
			para.clear()
		if list.size() > 0:
			out.append({"kind": "list", "items": list.map(_inline)})
			list.clear()
	for raw in short.split("\n"):
		var line: String = raw.strip_edges(false, true)
		if code != null:
			if line.begins_with("```"):
				out.append({"kind": "code", "text": "\n".join(code)})
				code = null
			else:
				code.append(line)
			continue
		if line.begins_with("```"):
			flush.call()
			code = []
			continue
		if line.begins_with("<!--"):
			continue
		if line.begins_with("#"):
			flush.call()
			var level := 0
			while level < line.length() and line[level] == "#":
				level += 1
			out.append({"kind": "h%d" % mini(level, 3), "text": _inline(line.substr(level).strip_edges())})
			continue
		if line.begins_with("- "):
			if para.size() > 0:
				flush.call()
			list.append(line.substr(2))
			continue
		if line == "":
			flush.call()
			continue
		para.append(line)
	flush.call()
	return out


## Links become their text, bold and code lose their marks.
static func _inline(s: String) -> String:
	var re := RegEx.new()
	re.compile("\\[([^\\]]+)\\]\\(([^)]+)\\)")
	var out := re.sub(s, "$1", true)
	return out.replace("**", "").replace("`", "")
