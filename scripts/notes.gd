extends Node
## Notes: one per problem, "what I don't get / what I missed". The local copy
## is the working copy; every save also goes to the account, and on a pull
## the newer version of each note wins.

signal changed


func rows() -> Dictionary:        # { problem_id: { text, resolved, updated_at } }
	return Store.section("notes")


func get_note(id: String) -> Dictionary:
	return rows().get(id, {})


## Notes with text, unresolved first, newest first within each group.
func list() -> Array:
	var out := []
	for id in rows():
		var n: Dictionary = rows()[id]
		if str(n.get("text", "")).strip_edges() != "":
			var row: Dictionary = n.duplicate()
			row["problem_id"] = id
			out.append(row)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a.get("resolved", false)) != bool(b.get("resolved", false)):
			return not bool(a.get("resolved", false))
		return str(a.get("updated_at", "")) > str(b.get("updated_at", "")))
	return out


## Change the text and/or the resolved flag; saves locally and to the account.
func save(id: String, patch: Dictionary) -> void:
	var current: Dictionary = rows().get(id, {})
	var next := {"text": str(current.get("text", "")), "resolved": bool(current.get("resolved", false))}
	next.merge(patch, true)
	next["updated_at"] = Progress.now_iso()
	rows()[id] = next
	Store.save()
	changed.emit()
	Sync.queue_upsert("notes", [{"user_id": Auth.user_id(), "problem_id": id, "text": next.text, "resolved": next.resolved, "updated_at": next.updated_at}], "user_id,problem_id")


## Reconcile with the account's rows: the newer version of each wins, and
## local notes that are newer are sent up.
func merge(remote_rows: Array) -> void:
	var remote := {}
	for r in remote_rows:
		remote[r.problem_id] = r
	var ids := {}
	for id in rows():
		ids[id] = true
	for id in remote:
		ids[id] = true
	var to_upload := []
	for id in ids:
		var l: Dictionary = rows().get(id, {})
		var r: Dictionary = remote.get(id, {})
		var l_at := str(l.get("updated_at", ""))
		var r_at := str(r.get("updated_at", ""))
		if not r.is_empty() and (l.is_empty() or r_at > l_at):
			rows()[id] = {"text": str(r.get("text", "")), "resolved": bool(r.get("resolved", false)), "updated_at": r_at}
		elif not l.is_empty() and (r.is_empty() or l_at > r_at):
			to_upload.append({"user_id": Auth.user_id(), "problem_id": id, "text": str(l.get("text", "")), "resolved": bool(l.get("resolved", false)), "updated_at": l_at})
	Store.save()
	if to_upload.size() > 0:
		Sync.queue_upsert("notes", to_upload, "user_id,problem_id")
	changed.emit()
