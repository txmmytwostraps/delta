extends Node
## "Update available": asks GitHub for the latest release once a day and
## compares it with this build's version.

signal checked

const RELEASES_API := "https://api.github.com/repos/txmmytwostraps/delta/releases/latest"
const RELEASES_PAGE := "https://github.com/txmmytwostraps/delta/releases/latest"
const CHECK_EVERY := 6.0 * 3600.0

var latest := ""          # e.g. "0.8.1"; "" until checked
var latest_url := RELEASES_PAGE
var _checked_at := 0.0


func current() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0"))


func update_available() -> bool:
	return latest != "" and _newer(latest, current())


func _ready() -> void:
	check()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED:
		check()


func check() -> void:
	if Time.get_unix_time_from_system() - _checked_at < CHECK_EVERY:
		return
	_checked_at = Time.get_unix_time_from_system()
	var http := HTTPRequest.new()
	http.timeout = 15.0
	add_child(http)
	if http.request(RELEASES_API, PackedStringArray(["Accept: application/vnd.github+json"])) != OK:
		http.queue_free()
		return
	var result: Array = await http.request_completed
	http.queue_free()
	if result[0] != HTTPRequest.RESULT_SUCCESS or result[1] != 200:
		return
	var data: Variant = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
	if data is Dictionary and data.has("tag_name"):
		latest = str(data.tag_name).trim_prefix("v")
		latest_url = str(data.get("html_url", RELEASES_PAGE))
		checked.emit()


## "0.9.0" is newer than "0.8.12"; compared part by part as numbers.
static func _newer(a: String, b: String) -> bool:
	var pa := a.split(".")
	var pb := b.split(".")
	for i in maxi(pa.size(), pb.size()):
		var x := int(pa[i]) if i < pa.size() else 0
		var y := int(pb[i]) if i < pb.size() else 0
		if x != y:
			return x > y
	return false
