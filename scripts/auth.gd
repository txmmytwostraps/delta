extends Node
## The signed-in account.
##
## Holds the Supabase session (access token, refresh token, user), keeps it on
## disk between launches, and offers the two ways to sign in: GitHub through
## the phone's browser, or email and password.

## The signed-in user changed: signed in, signed out, or restored at launch.
signal changed
## Fired once at launch, after the saved session has been checked.
signal restored
## GitHub sign-in ended without a session.
signal github_failed(message: String)

const SESSION_FILE := "user://session.dat"
## Refresh the access token when it has less than this long left (seconds).
const REFRESH_MARGIN := 120.0

## access_token, refresh_token, expires_at (unix seconds), user (Dictionary)
var session: Dictionary = {}
var is_restored := false

var _server: TCPServer
var _code_verifier := ""


func _ready() -> void:
	set_process(false)
	_load_session()
	if session.has("refresh_token"):
		await refresh()
	is_restored = true
	restored.emit()
	changed.emit()


func is_signed_in() -> bool:
	return session.get("user", null) is Dictionary and not session.user.is_empty()


func user() -> Dictionary:
	return session.get("user", {})


func user_id() -> String:
	return str(user().get("id", ""))


func email() -> String:
	return str(user().get("email", ""))


## Same rule as the site: GitHub handle, then a full name, then the email.
func display_name() -> String:
	var meta: Dictionary = user().get("user_metadata", {})
	for key in ["user_name", "preferred_username", "full_name"]:
		if str(meta.get(key, "")) != "":
			return str(meta[key])
	if email() != "":
		return email()
	return "signed in"


## A token that is good for a request. Refreshes first when the current one is
## about to expire; when offline, hands back the old one anyway.
func access_token() -> String:
	if session.is_empty():
		return ""
	if float(session.get("expires_at", 0)) - Time.get_unix_time_from_system() < REFRESH_MARGIN:
		await refresh()
	return str(session.get("access_token", ""))


## Returns an error message, or "" when signed in.
func sign_in_with_email(address: String, password: String) -> String:
	var reply: Dictionary = await Supabase.call_api("POST", "/auth/v1/token?grant_type=password", {"email": address, "password": password})
	if not reply.ok:
		return reply.error
	_set_session(reply.data)
	return ""


## Opens GitHub in the browser. Returns an error message, or "" when the
## browser was opened; the result arrives later through `changed` or
## `github_failed`.
func sign_in_with_github() -> String:
	_stop_server()
	_server = TCPServer.new()
	var err := _server.listen(AppConfig.OAUTH_PORT, "127.0.0.1")
	if err != OK:
		_server = null
		return "Could not open the sign-in port (error %d). Try again." % err

	# PKCE: the browser gets a one-time code, and only the app that made the
	# matching secret can turn it into a session.
	_code_verifier = _random_token(48)
	var hasher := HashingContext.new()
	hasher.start(HashingContext.HASH_SHA256)
	hasher.update(_code_verifier.to_utf8_buffer())
	var challenge := _base64url(hasher.finish())

	var url := "%s/auth/v1/authorize?provider=github&redirect_to=%s&code_challenge=%s&code_challenge_method=s256" % [
		AppConfig.SUPABASE_URL, AppConfig.OAUTH_REDIRECT.uri_encode(), challenge]
	set_process(true)
	OS.shell_open(url)
	return ""


func cancel_github() -> void:
	_stop_server()


## Trades the refresh token for a new session. Returns true when it worked.
## A rejected token clears the session; a network problem keeps it.
func refresh() -> bool:
	var token := str(session.get("refresh_token", ""))
	if token == "":
		return false
	var reply: Dictionary = await Supabase.call_api("POST", "/auth/v1/token?grant_type=refresh_token", {"refresh_token": token})
	if reply.ok:
		_set_session(reply.data)
		return true
	if reply.status == 400 or reply.status == 401 or reply.status == 403:
		_clear_session()
	return false


func sign_out() -> void:
	var token := str(session.get("access_token", ""))
	_clear_session()
	if token != "":
		await Supabase.call_api("POST", "/auth/v1/logout", null, token)


# ---- the browser callback for GitHub sign-in ----

func _process(_delta: float) -> void:
	if _server == null:
		set_process(false)
		return
	if _server.is_connection_available():
		_handle_peer(_server.take_connection())


func _handle_peer(peer: StreamPeerTCP) -> void:
	# The browser's request may arrive over a few frames.
	var request := ""
	for _i in 120:
		peer.poll()
		var n := peer.get_available_bytes()
		if n > 0:
			request += peer.get_utf8_string(n)
		if request.find("\r\n\r\n") != -1 or request.find("\n\n") != -1:
			break
		await get_tree().process_frame

	# The first line looks like: GET /callback?code=abc HTTP/1.1
	var target := request.get_slice("\n", 0).strip_edges().get_slice(" ", 1)
	var params := _parse_query(target.get_slice("?", 1) if target.contains("?") else "")

	if params.has("code"):
		await _respond(peer, "Signed in", "You can close this tab and go back to Delta.")
		_stop_server()
		var reply: Dictionary = await Supabase.call_api("POST", "/auth/v1/token?grant_type=pkce", {"auth_code": params.code, "code_verifier": _code_verifier})
		if reply.ok:
			_set_session(reply.data)
		else:
			github_failed.emit(reply.error)
	elif params.has("error"):
		var why := str(params.get("error_description", params.error))
		await _respond(peer, "Sign-in failed", why)
		_stop_server()
		github_failed.emit(why)
	else:
		await _respond(peer, "Delta", "Nothing to see here.")


## A small dark page for the browser tab, in the app's colours.
func _respond(peer: StreamPeerTCP, title: String, message: String) -> void:
	var html := "<!doctype html><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"><title>%s</title>" % title.xml_escape()
	html += "<body style=\"margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;background:#0b0d10;color:#e8ecef;font:16px/1.5 Consolas,monospace;text-align:center;padding:24px\">"
	html += "<div><div style=\"width:12px;height:12px;background:#7ef0c2;margin:0 auto 16px\"></div>"
	html += "<h1 style=\"margin:0 0 8px;font-size:28px;text-transform:uppercase\">%s</h1>" % title.xml_escape()
	html += "<p style=\"margin:0;color:#8a95a0\">%s</p></div></body>" % message.xml_escape()
	var body := html.to_utf8_buffer()
	var head := "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % body.size()
	peer.put_data(head.to_utf8_buffer() + body)
	await get_tree().process_frame
	peer.disconnect_from_host()


func _stop_server() -> void:
	if _server != null:
		_server.stop()
		_server = null
	set_process(false)


func _parse_query(query: String) -> Dictionary:
	var out := {}
	for pair in query.split("&", false):
		var key := pair.get_slice("=", 0).uri_decode()
		var value := pair.get_slice("=", 1).uri_decode() if pair.contains("=") else ""
		out[key] = value
	return out


func _random_token(bytes: int) -> String:
	return _base64url(Crypto.new().generate_random_bytes(bytes))


func _base64url(data: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(data).replace("+", "-").replace("/", "_").replace("=", "")


# ---- the session on disk ----

func _set_session(data: Dictionary) -> void:
	var expires_at: float = float(data.get("expires_at", 0))
	if expires_at == 0.0:
		expires_at = Time.get_unix_time_from_system() + float(data.get("expires_in", 3600))
	session = {
		"access_token": str(data.get("access_token", "")),
		"refresh_token": str(data.get("refresh_token", "")),
		"expires_at": expires_at,
		"user": data.get("user", {}),
	}
	_save_session()
	changed.emit()


func _clear_session() -> void:
	session = {}
	if FileAccess.file_exists(SESSION_FILE):
		DirAccess.remove_absolute(SESSION_FILE)
	changed.emit()


## The file is encrypted with a key tied to this device, so a copied file is
## useless elsewhere.
func _storage_key() -> String:
	var device := OS.get_unique_id()
	if device == "":
		device = "delta-local"
	return device + ":delta-session"


func _save_session() -> void:
	var file := FileAccess.open_encrypted_with_pass(SESSION_FILE, FileAccess.WRITE, _storage_key())
	if file:
		file.store_string(JSON.stringify(session))


func _load_session() -> void:
	if not FileAccess.file_exists(SESSION_FILE):
		return
	var file := FileAccess.open_encrypted_with_pass(SESSION_FILE, FileAccess.READ, _storage_key())
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary and parsed.has("refresh_token"):
		session = parsed
