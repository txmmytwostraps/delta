class_name Streak
## The day streak: the run of days, ending today or yesterday, on which
## something was done. A day counts when it has at least one solve or one
## review. Same rule as the site.

## Timestamps are ISO strings from the account, e.g.
## "2026-09-06T14:03:11.123456+00:00". They are always in UTC; days are
## counted in the phone's local time.
static func count(timestamps: Array, now_unix: float = Time.get_unix_time_from_system()) -> int:
	var active_days := {}
	for iso in timestamps:
		var key := day_key(str(iso))
		if key != "":
			active_days[key] = true

	var t := now_unix
	if not active_days.has(key_for_unix(t)):
		t -= 86400.0
	var days := 0
	while active_days.has(key_for_unix(t)):
		days += 1
		t -= 86400.0
	return days


## "YYYY-MM-DD" in local time for an ISO timestamp, or "" when unreadable.
static func day_key(iso: String) -> String:
	if iso.length() < 19:
		return ""
	var utc := Time.get_unix_time_from_datetime_string(iso.substr(0, 19))
	return key_for_unix(float(utc))


static func key_for_unix(unix_utc: float) -> String:
	var bias_seconds: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	return Time.get_date_string_from_unix_time(int(unix_utc) + bias_seconds)
