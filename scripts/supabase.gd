extends Node
## Sends one request to Supabase and hands back the reply.
##
## Every call returns a Dictionary shaped the same way:
##   { "ok": bool, "status": int, "data": Variant, "error": String }
## "data" is the parsed JSON body (a Dictionary or Array), or null.
## "error" is a short message meant for the screen, empty when ok.

const METHODS := {
	"GET": HTTPClient.METHOD_GET,
	"POST": HTTPClient.METHOD_POST,
	"PATCH": HTTPClient.METHOD_PATCH,
	"DELETE": HTTPClient.METHOD_DELETE,
}

## Where requests go. Only tests change it (to an address that does not
## answer, to act out being offline).
var base_url: String = AppConfig.SUPABASE_URL


## method: "GET" | "POST" | "PATCH" | "DELETE"
## path: starts with "/", e.g. "/rest/v1/progress?select=problem_id"
## body: a Dictionary or Array to send as JSON, or null
## access_token: the signed-in user's token; without it Supabase treats the
## request as anonymous.
func call_api(method: String, path: String, body: Variant = null, access_token: String = "", extra_headers: PackedStringArray = PackedStringArray()) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 20.0
	add_child(http)

	var headers := PackedStringArray([
		"apikey: " + AppConfig.SUPABASE_ANON_KEY,
		"Authorization: Bearer " + (access_token if access_token != "" else AppConfig.SUPABASE_ANON_KEY),
		"Content-Type: application/json",
		"Accept: application/json",
	])
	headers.append_array(extra_headers)

	var payload := "" if body == null else JSON.stringify(body)
	var err := http.request(base_url + path, headers, METHODS[method], payload)
	if err != OK:
		http.queue_free()
		return _reply(false, 0, null, "Could not start the request (error %d)." % err)

	# request_completed carries four values: result, status, headers, body.
	var result: Array = await http.request_completed
	http.queue_free()
	var outcome: int = result[0]
	var status: int = result[1]
	var raw: PackedByteArray = result[3]

	if outcome != HTTPRequest.RESULT_SUCCESS:
		return _reply(false, status, null, _network_message(outcome))

	var data: Variant = null
	var text := raw.get_string_from_utf8()
	if text.strip_edges() != "":
		var json := JSON.new()
		data = json.data if json.parse(text) == OK else text

	var ok := status >= 200 and status < 300
	return _reply(ok, status, data, "" if ok else _error_message(data, status))


func _reply(ok: bool, status: int, data: Variant, error: String) -> Dictionary:
	return {"ok": ok, "status": status, "data": data, "error": error}


func _network_message(outcome: int) -> String:
	match outcome:
		HTTPRequest.RESULT_CANT_RESOLVE, HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CONNECTION_ERROR:
			return "No connection. Check the network and try again."
		HTTPRequest.RESULT_TIMEOUT:
			return "The server took too long to answer."
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "Secure connection failed."
		_:
			return "Request failed (%d)." % outcome


## Supabase describes errors in a few different shapes; take the first one found.
func _error_message(data: Variant, status: int) -> String:
	if data is Dictionary:
		for key in ["error_description", "msg", "message", "hint", "error"]:
			if data.has(key) and data[key] is String and data[key] != "":
				return data[key]
	return "Request failed (HTTP %d)." % status
