class_name Highlight
## GDScript colouring as BBCode, for code shown in a block: the same
## colours the site's editor uses.

const KEYWORDS := ["func", "return", "var", "const", "if", "elif", "else", "while", "for", "in", "not", "and", "or", "pass", "break", "continue", "true", "false", "null", "extends", "class_name", "match", "is", "self"]
const TYPES := ["int", "float", "String", "bool", "Array", "Dictionary", "Variant", "Vector2", "Vector2i", "Rect2", "Rect2i", "void"]
const KEYWORD_COLOR := "#ff7085"
const TYPE_COLOR := "#57b3ff"
const FUNCTION_COLOR := "#57b3ff"
const STRING_COLOR := "#ffeda1"
const NUMBER_COLOR := "#a1ffe0"
const COMMENT_COLOR := "#8a8f9d"


static func line(code: String) -> String:
	var out := ""
	var i := 0
	while i < code.length():
		var c := code[i]
		if c == "#":
			out += "[color=%s]%s[/color]" % [COMMENT_COLOR, _esc(code.substr(i))]
			break
		if c == "\"" or c == "'":
			var j := i + 1
			while j < code.length() and code[j] != c:
				if code[j] == "\\":
					j += 1
				j += 1
			out += "[color=%s]%s[/color]" % [STRING_COLOR, _esc(code.substr(i, j - i + 1))]
			i = j + 1
			continue
		if _is_digit(c) and (i == 0 or not _is_word(code[i - 1])):
			var j := i
			while j < code.length() and (_is_digit(code[j]) or (code[j] == "." and j + 1 < code.length() and _is_digit(code[j + 1]))):
				j += 1
			out += "[color=%s]%s[/color]" % [NUMBER_COLOR, code.substr(i, j - i)]
			i = j
			continue
		if _is_word(c) and not _is_digit(c):
			var j := i
			while j < code.length() and _is_word(code[j]):
				j += 1
			var word := code.substr(i, j - i)
			var next := code[j] if j < code.length() else ""
			if KEYWORDS.has(word):
				out += "[color=%s]%s[/color]" % [KEYWORD_COLOR, word]
			elif TYPES.has(word):
				out += "[color=%s]%s[/color]" % [TYPE_COLOR, word]
			elif next == "(":
				out += "[color=%s]%s[/color]" % [FUNCTION_COLOR, word]
			else:
				out += word
			i = j
			continue
		out += _esc(c)
		i += 1
	return out


static func _esc(s: String) -> String:
	return s.replace("[", "[lb]")


static func _is_digit(c: String) -> bool:
	return c >= "0" and c <= "9"


static func _is_word(c: String) -> bool:
	return c == "_" or (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or _is_digit(c)
