extends Node
## Everything the app remembers between launches, in one JSON file.
##
## This is the working copy, like the browser's local storage is for the
## site. Other modules keep their rows here (solved, fails, drafts, reviews,
## notes, runs, the outbox of writes waiting to reach the account) and call
## save() after changing them. Sync keeps the account in step.

const FILE := "user://data.json"

var data: Dictionary = {}
var _write_queued := false


func _ready() -> void:
	_load()


## A named part of the data, e.g. section("solved"). Dictionaries are shared
## by reference, so changes made to the result are changes to the store;
## call save() afterwards.
func section(name: String) -> Dictionary:
	if not (data.get(name) is Dictionary):
		data[name] = {}
	return data[name]


func get_value(key: String, fallback: Variant = null) -> Variant:
	return data.get(key, fallback)


func set_value(key: String, value: Variant) -> void:
	data[key] = value
	save()


## Writes once at the end of the frame, however many changes were made.
func save() -> void:
	if _write_queued:
		return
	_write_queued = true
	_write.call_deferred()


## Forget everything (a different account signed in, or "clear progress").
func clear() -> void:
	data = {}
	_write()


func _write() -> void:
	_write_queued = false
	var file := FileAccess.open(FILE, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s (error %d)." % [FILE, FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify(data))


func _load() -> void:
	if not FileAccess.file_exists(FILE):
		return
	var file := FileAccess.open(FILE, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		data = parsed
