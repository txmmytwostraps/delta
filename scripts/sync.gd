extends Node
## Keeps the account in step with the local store.
##
## Writes never wait for the network: they go into an outbox in the store and
## are sent in order when there is a connection (right away, on a retry timer,
## or when the app comes back to the front). A pull fetches the account's
## rows and merges them with the site's rules: solves are a union with the
## earliest date kept, fail counts take the larger, the newer draft wins, the
## review queue comes from the account, and notes take the newer version.

## The streak rule (shared with the site; both compute it from the account
## rows, so both must follow this text exactly):
##
##   1. A day is active when it has at least one solve (progress.solved_at)
##      or one review (reviews.reviewed_at), in the user's local time.
##   2. A full-run day is a day whose run was completed, as progress.js's
##      dayDone has it: every review due that day done, the day's new
##      problems solved, and the extra topic problem when there was one (a
##      milestone step, once the run offers one). A day with no run record
##      on this device counts when it has new_per_day + 1 or more solves.
##   3. Walk the days from the first active day to today. The streak grows
##      by one on each active day. A missed day breaks it, unless a rest day
##      is held: then the rest day is consumed, the missed day counts as
##      covered, and the streak grows by one.
##   4. A rest day is earned on an active full-run day when none is held, at
##      most one per calendar week (Monday to Sunday). Never more than one
##      is held. It cannot be bought or set by hand.
##   5. Today counts once it is active; an inactive today does not break
##      the streak yet. Yesterday inactive and not covered ends it at zero.
##   6. The longest streak is the highest value the walk reaches.
##
## Streak.compute() is the implementation.

signal state_changed
## A pull finished; screens should redraw.
signal pulled

const RETRY_SECONDS := 30.0
const FLUSH_DELAY := 0.8

var busy := false
var offline := false
var message := ""
var last_synced := ""     # ISO time of the last successful pull

var _flush_timer: Timer
var _retry_timer: Timer


func _ready() -> void:
	last_synced = str(Store.get_value("last_synced", ""))
	_flush_timer = Timer.new()
	_flush_timer.one_shot = true
	_flush_timer.wait_time = FLUSH_DELAY
	_flush_timer.timeout.connect(flush)
	add_child(_flush_timer)
	_retry_timer = Timer.new()
	_retry_timer.wait_time = RETRY_SECONDS
	_retry_timer.timeout.connect(func() -> void:
		if pending_count() > 0:
			flush())
	add_child(_retry_timer)
	_retry_timer.start()
	Auth.changed.connect(_on_auth_changed)
	if Auth.is_restored:
		_on_auth_changed()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED:
		sync_now()


# ---- the outbox ----

func outbox() -> Array:
	if not (Store.data.get("outbox") is Array):
		Store.data["outbox"] = []
	return Store.data["outbox"]


func pending_count() -> int:
	return outbox().size()


## rows: Dictionaries including user_id. on_conflict: the key columns, e.g.
## "user_id,problem_id". Existing rows with the same key are replaced.
func queue_upsert(table: String, rows: Array, on_conflict: String) -> void:
	outbox().append({"table": table, "op": "upsert", "rows": rows, "on_conflict": on_conflict})
	_queued()


func queue_insert(table: String, row: Dictionary) -> void:
	outbox().append({"table": table, "op": "insert", "rows": [row]})
	_queued()


## One run that reached a verdict. kind: new | review | practice; result: pass | miss.
func insert_attempt(problem_id: String, kind: String, result: String) -> void:
	queue_insert("attempts", {"user_id": Auth.user_id(), "problem_id": problem_id, "kind": kind, "result": result})


## The progress row for one problem, as the site writes it.
func push_progress(id: String) -> void:
	queue_upsert("progress", [progress_row(id)], "user_id,problem_id")


func progress_row(id: String) -> Dictionary:
	var d := Progress.draft(id)
	return {
		"user_id": Auth.user_id(),
		"problem_id": id,
		"solved_at": Progress.solved().get(id, null),
		"fails": int(Progress.fails().get(id, 0)),
		"draft": d.get("code", null) if not d.is_empty() else null,
		"draft_updated_at": d.get("at", null) if not d.is_empty() else null,
	}


func _queued() -> void:
	Store.save()
	_flush_timer.start()
	state_changed.emit()


## Sends the outbox in order. Returns true when it is empty afterwards.
func flush() -> bool:
	if busy or not Auth.is_signed_in():
		return false
	busy = true
	state_changed.emit()
	var emptied := true
	var retried_auth := false
	while outbox().size() > 0:
		var item: Dictionary = outbox()[0]
		var reply := await _send(item)
		if reply.ok:
			outbox().remove_at(0)
			Store.save()
			continue
		if reply.status == 0:
			# No connection: keep everything, try again later.
			offline = true
			emptied = false
			break
		if reply.status == 401 and not retried_auth:
			retried_auth = true
			await Auth.refresh()
			continue
		if reply.status == 401:
			emptied = false
			break
		# The server refused the data itself; dropping it is the only way on.
		message = "Could not save to the account: " + reply.error
		outbox().remove_at(0)
		Store.save()
	if emptied:
		offline = false
	busy = false
	state_changed.emit()
	return emptied


func _send(item: Dictionary) -> Dictionary:
	var token: String = await Auth.access_token()
	var path: String = "/rest/v1/" + item.table
	var prefer: String = "Prefer: return=minimal"
	if item.op == "upsert":
		path += "?on_conflict=" + item.on_conflict
		prefer = "Prefer: resolution=merge-duplicates,return=minimal"
	return await Supabase.call_api("POST", path, item.rows, token, PackedStringArray([prefer]))


# ---- pulling and merging ----

## Send what is waiting, then pull. Safe to call often.
func sync_now() -> void:
	if busy or not Auth.is_signed_in():
		return
	if await flush():
		await pull()


func pull() -> void:
	if busy or not Auth.is_signed_in():
		return
	busy = true
	message = "Syncing…"
	state_changed.emit()
	var token: String = await Auth.access_token()
	var progress: Dictionary = await Supabase.call_api("GET", "/rest/v1/progress?select=problem_id,solved_at,fails,draft,draft_updated_at", null, token)
	var reviews: Dictionary = await Supabase.call_api("GET", "/rest/v1/reviews?select=problem_id,topic,stage,due_on,step,clean_streak,last_result,reviewed_at", null, token)
	var notes: Dictionary = await Supabase.call_api("GET", "/rest/v1/notes?select=problem_id,text,resolved,updated_at", null, token)
	var settings: Dictionary = await Supabase.call_api("GET", "/rest/v1/settings?select=course_lock,new_per_day,hint_overrides,updated_at", null, token)
	var attempts: Dictionary = await Supabase.call_api("GET", "/rest/v1/attempts?select=problem_id,kind,result,at&order=at.asc&limit=5000", null, token)
	for reply in [progress, reviews, notes, settings, attempts]:
		if not reply.ok:
			offline = reply.status == 0
			message = reply.error
			busy = false
			state_changed.emit()
			return

	_merge_progress(progress.data)
	Reviews.replace_all(reviews.data)
	Notes.merge(notes.data)
	Settings.merge(settings.data[0] if settings.data is Array and settings.data.size() > 0 else {})
	Scaffold.replace_attempts(attempts.data if attempts.data is Array else [])
	# A topic finished on the other machine starts its review week here, and
	# a topic started there puts its concept cards in the queue.
	for concept in Bank.concepts:
		Reviews.schedule_topic_if_cleared(concept)
		Reviews.schedule_cards_if_started(concept)

	offline = false
	message = ""
	last_synced = Progress.now_iso()
	Store.set_value("last_synced", last_synced)
	busy = false
	state_changed.emit()
	pulled.emit()
	if pending_count() > 0:
		flush()


func _merge_progress(remote_rows: Array) -> void:
	var uid := Auth.user_id()
	var remote := {}
	for r in remote_rows:
		remote[r.problem_id] = r
	var solved := Progress.solved()
	var fails := Progress.fails()
	var drafts := Progress.drafts()
	var ids := {}
	for source in [remote, solved, fails, drafts]:
		for id in source:
			ids[id] = true

	var to_upload := []
	var changed_local := false
	for id in ids:
		var r: Dictionary = remote.get(id, {})
		var local_draft: Dictionary = drafts.get(id, {})

		var dates := []
		if solved.has(id):
			dates.append(str(solved[id]))
		if r.get("solved_at", null) != null:
			dates.append(str(r.solved_at))
		dates.sort()
		var solved_at: Variant = dates[0] if dates.size() > 0 else null
		var fail_count := maxi(int(fails.get(id, 0)), int(r.get("fails", 0)))
		var draft := local_draft
		if r.get("draft", null) != null and (local_draft.is_empty() or str(r.get("draft_updated_at", "")) > str(local_draft.get("at", ""))):
			draft = {"code": r.draft, "at": r.get("draft_updated_at", null)}

		if solved_at != null and solved.get(id, null) != solved_at:
			solved[id] = solved_at
			changed_local = true
		if fail_count != int(fails.get(id, 0)):
			fails[id] = fail_count
			changed_local = true
		if not draft.is_empty() and (local_draft.is_empty() or draft.code != local_draft.get("code", null)):
			drafts[id] = draft
			changed_local = true

		var draft_code: Variant = draft.get("code", null) if not draft.is_empty() else null
		var draft_at: Variant = draft.get("at", null) if not draft.is_empty() else null
		if r.get("solved_at", null) != solved_at or int(r.get("fails", 0)) != fail_count or r.get("draft", null) != draft_code or (not draft.is_empty() and r.get("draft_updated_at", null) != draft_at):
			to_upload.append({"user_id": uid, "problem_id": id, "solved_at": solved_at, "fails": fail_count, "draft": draft_code, "draft_updated_at": draft_at})
	Store.save()
	if to_upload.size() > 0:
		queue_upsert("progress", to_upload, "user_id,problem_id")
	if changed_local:
		Progress.changed.emit()


# ---- whose data this is ----

## The store belongs to one account. When another one signs in, it starts
## from an empty store and pulls; the previous account's unsent writes go
## with it.
func _on_auth_changed() -> void:
	if not Auth.is_signed_in():
		return
	var owner := str(Store.get_value("owner", ""))
	if owner != Auth.user_id():
		Store.clear()
		Store.set_value("owner", Auth.user_id())
		last_synced = ""
	sync_now()


## A short line for the Profile screen.
func status_text() -> String:
	var waiting := pending_count()
	if busy:
		return message if message != "" else "Syncing…"
	if offline:
		return "Offline · %d change%s waiting" % [waiting, "" if waiting == 1 else "s"] if waiting > 0 else "Offline · nothing waiting"
	if message != "":
		return message
	if waiting > 0:
		return "%d change%s waiting" % [waiting, "" if waiting == 1 else "s"]
	if last_synced == "":
		return "Not synced yet"
	return "Up to date · synced " + _local_time(last_synced)


func _local_time(iso: String) -> String:
	if iso.length() < 19:
		return iso
	var unix := Time.get_unix_time_from_datetime_string(iso.substr(0, 19))
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var local := Time.get_datetime_dict_from_unix_time(unix + bias)
	return "%02d:%02d" % [local.hour, local.minute]
