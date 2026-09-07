class_name Nudge
## The built-in nudge, the same as the site's: the problem, the code and the
## failing checks go to the site's nudge function with the signed-in token;
## it answers with a pointer and never the answer, and enforces the daily
## cap itself. A nudge counts as a hint opened; at the minimal hint level it
## needs a miss first.

const DAILY_CAP := 30
const PATH := "/functions/v1/nudge"


## What the site sends: the problem, the code as it stands, what failed on
## the last run, the note, the hints opened and the topic's hint level.
static func payload(p: Dictionary, code: String, reply: Dictionary, hints_opened: Array) -> Dictionary:
	var failing := []
	var error := ""
	if not reply.is_empty():
		var result: Dictionary = reply.get("result", {})
		if result.get("status", "") == "ok":
			var rtype := Fmt.return_type(str(p.get("signature", "")))
			for i in result.get("results", []).size():
				var r: Dictionary = result.results[i]
				if r.get("pass", false):
					continue
				var t: Dictionary = p.tests[i] if i < p.get("tests", []).size() else {}
				failing.append("%s | %s | %s" % [str(t.get("name", "")), Fmt.fmt_typed(t.get("expect", null), rtype) if not t.has("out") else Fmt.to_json(t.get("out", [])), Fmt.fmt_typed(r.get("got", null), rtype) if not t.has("out") else Fmt.to_json(r.get("out", []))])
		error = "\n".join(reply.get("errors", []))
		if error == "" and result.get("status", "") != "ok":
			error = str(result.get("error", ""))
	var n := Notes.get_note(str(p.get("id", "")))
	return {
		"problem_id": str(p.get("id", "")), "topic": str(p.get("concept", "")), "title": str(p.get("title", "")),
		"prompt": str(p.get("prompt", "")), "signature": str(p.get("signature", "")), "code": code,
		"failing": failing, "error": error, "note": str(n.get("text", "")),
		"hints_opened": hints_opened, "hint_level": Scaffold.level_for(str(p.get("concept", ""))),
	}


## The site's rule: at the minimal level a nudge needs a miss first.
static func blocked_reason(p: Dictionary) -> String:
	var id := str(p.get("id", ""))
	if not Auth.is_signed_in():
		return "sign in to get a nudge"
	if Scaffold.level_for(str(p.get("concept", ""))) == "minimal" and int(Progress.fails().get(id, 0)) < 1 and not Progress.is_solved(id):
		return "at the minimal hint level a nudge needs a miss first"
	return ""


## Asks the function. Returns { "ok", "text", "remaining", "error" }.
static func ask(body: Dictionary) -> Dictionary:
	var token: String = await Auth.access_token()
	if token == "":
		return {"ok": false, "text": "", "remaining": -1, "error": "sign in to get a nudge"}
	var reply: Dictionary = await Supabase.call_api("POST", PATH, body, token)
	if not reply.ok:
		var message := str(reply.error)
		if reply.data is Dictionary and reply.data.has("error"):
			message = str(reply.data.error)
		elif reply.status == 404:
			message = "the nudge is not set up yet"
		elif reply.status == 0:
			message = "the nudge is not set up yet, or cannot be reached"
		return {"ok": false, "text": "", "remaining": -1, "error": message}
	var data: Dictionary = reply.data if reply.data is Dictionary else {}
	Week.log_hint(str(body.get("problem_id", "")), "nudge")
	return {"ok": true, "text": str(data.get("text", "")), "remaining": int(data.get("remaining", -1)) if data.has("remaining") else -1, "error": ""}


## "29 left today": the cap counted from the account's nudges in 24 hours.
static func left_today() -> int:
	var token: String = await Auth.access_token()
	if token == "":
		return -1
	var reply: Dictionary = await Supabase.call_api("GET", "/rest/v1/nudges?select=at&order=at.desc&limit=500", null, token)
	if not reply.ok or not (reply.data is Array):
		return -1
	return DAILY_CAP - used_in_day(reply.data, Time.get_unix_time_from_system())


static func used_in_day(rows: Array, now: float) -> int:
	var used := 0
	for r in rows:
		var at := Time.get_unix_time_from_datetime_string(str(r.get("at", "")).substr(0, 19))
		if now - at < 86400.0:
			used += 1
	return used
