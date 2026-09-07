class_name Streak
## The day streak, with rest days. The rule is written out once, in
## sync.gd under "The streak rule", and the site follows the same text; the
## streak is computed from the same account rows on both, so they agree.


## active: { "YYYY-MM-DD": true } days with a solve or a review.
## full_runs: { "YYYY-MM-DD": true } days with a completed run.
## today: "YYYY-MM-DD" in local time.
## Returns { "streak", "longest", "token", "week": [7 x { "day", "active", "covered", "today" }] }.
static func compute(active: Dictionary, full_runs: Dictionary, today: String) -> Dictionary:
	var days := active.keys()
	days.sort()
	var streak := 0
	var longest := 0
	var token := false
	var token_week := ""
	var covered := {}
	if days.size() > 0:
		var day: String = days[0]
		var last_active: String = days[0]
		while day <= today:
			var is_active: bool = active.has(day)
			if is_active:
				streak += 1
				last_active = day
			elif token and day != today:
				# A missed day with a rest day held: the streak survives.
				token = false
				covered[day] = true
				streak += 1
			elif day != today:
				streak = 0
			if is_active and full_runs.has(day) and not token and _week_of(day) != token_week:
				token = true
				token_week = _week_of(day)
			longest = maxi(longest, streak)
			day = _next_day(day)
		# Nothing yet today does not break the streak; a day not covered ends it.
		var yesterday := _next_day(today, -1)
		if not active.has(today) and not active.has(yesterday) and not covered.has(yesterday):
			streak = 0
	var week := []
	var monday := _week_start(today)
	for i in 7:
		var d := _next_day(monday, i)
		week.append({"day": d, "active": active.has(d), "covered": covered.has(d), "today": d == today})
	return {"streak": streak, "longest": longest, "token": token, "week": week}


## "YYYY-MM-DD" in local time for an ISO timestamp, or "" when unreadable.
static func day_key(iso: String) -> String:
	if iso.length() < 19:
		return ""
	var utc := Time.get_unix_time_from_datetime_string(iso.substr(0, 19))
	return key_for_unix(float(utc))


static func key_for_unix(unix_utc: float) -> String:
	var bias_seconds: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	return Time.get_date_string_from_unix_time(int(unix_utc) + bias_seconds)


## The Monday of the week a day is in.
static func _week_start(day: String) -> String:
	var noon := Time.get_unix_time_from_datetime_string(day + "T12:00:00")
	var weekday: int = Time.get_datetime_dict_from_unix_time(noon).weekday   # 0 = Sunday
	return _next_day(day, -((weekday + 6) % 7))


static func _week_of(day: String) -> String:
	return _week_start(day)


static func _next_day(day: String, n: int = 1) -> String:
	var noon := Time.get_unix_time_from_datetime_string(day + "T12:00:00")
	return Time.get_date_string_from_unix_time(noon + n * 86400)
