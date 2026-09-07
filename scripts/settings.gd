extends Node
## Settings that live in the account: the course lock, the daily set size
## and the hint level overrides, one row per user in the settings table, so
## the site and the phone agree. The store holds a copy for offline use; on
## a pull the newer copy wins and the other side is updated.

signal changed

const LEVELS := ["full", "reduced", "minimal"]


func _data() -> Dictionary:
	var d := Store.section("settings")
	if not d.has("hint_overrides"):
		d["hint_overrides"] = {}
	return d


func course_lock() -> int:
	var v: Variant = _data().get("course_lock", null)
	return Bank.default_course_lock if v == null else int(v)


func new_per_day() -> int:
	var v: Variant = _data().get("new_per_day", null)
	return Bank.new_per_day if v == null else int(v)


func hint_overrides() -> Dictionary:
	return _data().get("hint_overrides", {})


func set_course_lock(n: int) -> void:
	_save({"course_lock": n})


func set_new_per_day(n: int) -> void:
	_save({"new_per_day": clampi(n, 1, 10)})


## level: "full" | "reduced" | "minimal", or "" to clear the override.
func set_hint_override(concept: String, level: String) -> void:
	var o: Dictionary = hint_overrides().duplicate()
	if LEVELS.has(level):
		o[concept] = level
	else:
		o.erase(concept)
	_save({"hint_overrides": o})


func _save(patch: Dictionary) -> void:
	var d := _data()
	d.merge(patch, true)
	d["updated_at"] = Progress.now_iso()
	Store.save()
	changed.emit()
	_push()


func _push() -> void:
	if not Auth.is_signed_in():
		return
	var d := _data()
	Sync.queue_upsert("settings", [{
		"user_id": Auth.user_id(), "course_lock": d.get("course_lock", null), "new_per_day": d.get("new_per_day", null),
		"hint_overrides": d.get("hint_overrides", {}), "updated_at": d.get("updated_at", Progress.now_iso()),
	}], "user_id")


## remote: the account's row, or {} when there is none yet.
func merge(remote: Dictionary) -> void:
	var d := _data()
	var local_at := str(d.get("updated_at", ""))
	var remote_at := str(remote.get("updated_at", "")) if not remote.is_empty() else ""
	if not remote.is_empty() and (local_at == "" or remote_at > local_at):
		d["course_lock"] = remote.get("course_lock", null)
		d["new_per_day"] = remote.get("new_per_day", null)
		d["hint_overrides"] = remote.get("hint_overrides", {}) if remote.get("hint_overrides", null) is Dictionary else {}
		d["updated_at"] = remote_at
		Store.save()
		changed.emit()
	elif local_at != "" and (remote.is_empty() or remote_at < local_at):
		_push()
