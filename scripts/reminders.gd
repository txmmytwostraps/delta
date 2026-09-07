extends Node
## The daily reminder: one notification at the chosen time, when reviews
## are due or the run is not done. Never more than one a day. On Android it
## goes through the DeltaNotify plugin (android/plugin); elsewhere there is
## nothing to schedule.

signal changed

const ID := 1
const PERMISSION := "android.permission.POST_NOTIFICATIONS"


func available() -> bool:
	return Engine.has_singleton("DeltaNotify")


func enabled() -> bool:
	return bool(Store.get_value("reminders_on", false))


func set_enabled(on: bool) -> void:
	Store.set_value("reminders_on", on)
	if on and OS.get_name() == "Android":
		OS.request_permission(PERMISSION)
	reschedule()
	changed.emit()


func _ready() -> void:
	Sync.pulled.connect(reschedule)
	Progress.changed.connect(reschedule)
	Reviews.changed.connect(reschedule)
	Auth.changed.connect(reschedule)
	reschedule()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_PAUSED:
		reschedule()


## The next reminder: today at the chosen time if that is still ahead,
## else tomorrow. Scheduled only when there will be something to say.
func reschedule() -> void:
	if not available():
		return
	var plugin: Object = Engine.get_singleton("DeltaNotify")
	if not enabled() or not Auth.is_signed_in():
		plugin.cancel(ID)
		return
	var at := next_time()
	var day := Streak.key_for_unix(at)
	var text := reason_for(day)
	if text == "":
		plugin.cancel(ID)
		return
	plugin.schedule(ID, int(at), "Delta", text)


## Unix seconds of the next occurrence of the reminder time, in local time.
func next_time() -> float:
	var now := Time.get_unix_time_from_system()
	var today := Progress.today_key()
	var at := local_to_unix(today, Progress.reminder_time())
	if at <= now + 60.0:
		at = local_to_unix(Reviews.add_days(today, 1), Progress.reminder_time())
	return at


## What the reminder for a day would say, or "" when there is nothing to
## remind about (the run is done and no review is due).
func reason_for(day: String) -> String:
	var due := 0
	if day == Progress.today_key():
		var status := Progress.run_status()
		var q := Reviews.due_today(day)
		var cq := Reviews.cards_due_today(day)
		due = q.pending.size() + cq.pending.size()
		if status.all_done and due == 0:
			return ""
	else:
		due = Reviews.due(day).size() + Reviews.cards_due(day).size()
	if due > 0:
		return "%d review%s waiting for you." % [due, " is" if due == 1 else "s are"]
	return "Today's run is waiting."


static func local_to_unix(day: String, hhmm: String) -> float:
	var as_utc := Time.get_unix_time_from_datetime_string("%sT%s:00" % [day, hhmm])
	var bias_seconds: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	return float(as_utc - bias_seconds)
