extends SimplePage
## About: the short version of the site's About, from its README at the
## pinned commit, and what this app is.


func _ready() -> void:
	super()
	var md := FileAccess.get_file_as_string("res://bank/about.md") if FileAccess.file_exists("res://bank/about.md") else ""
	var first := true
	for b in AboutText.blocks(md):
		match b.kind:
			"h1":
				var h := Label.new()
				h.theme_type_variation = &"Heading"
				h.text = "ABOUT" if first else str(b.text).to_upper()
				h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				body.add_child(h)
			"h2", "h3":
				var h := Label.new()
				h.theme_type_variation = &"RowTitle"
				h.text = str(b.text)
				h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				body.add_child(h)
			"list":
				var column := VBoxContainer.new()
				column.add_theme_constant_override("separation", 8)
				for item in b.items:
					var row := HBoxContainer.new()
					row.add_theme_constant_override("separation", 12)
					var dot := Label.new()
					dot.theme_type_variation = &"ProseMuted"
					dot.text = "·"
					row.add_child(dot)
					var text := Label.new()
					text.theme_type_variation = &"Prose"
					text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
					text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					text.text = str(item)
					row.add_child(text)
					column.add_child(row)
				body.add_child(column)
			"code":
				body.add_child(UI.code_view(str(b.text)))
			_:
				var p := Label.new()
				p.theme_type_variation = &"Prose"
				p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				p.text = str(b.text)
				body.add_child(p)
		first = false
	if md == "":
		var none := Label.new()
		none.theme_type_variation = &"ProseMuted"
		none.text = "The site's About text is not in this build."
		body.add_child(none)
	var app_note := Label.new()
	app_note.theme_type_variation = &"ProseMuted"
	app_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	app_note.text = "Delta %s is the Android companion: the same account, the same problems (from the site at %s), the same rules, with the judge running on the phone so it works offline." % [Updates.current(), Bank.site_commit.substr(0, 7)]
	body.add_child(app_note)
	set_action("OPEN THE SITE", func() -> void: OS.shell_open("https://txmmytwostraps.github.io/gdscript-practice/site/"))
