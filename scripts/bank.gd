extends Node
## The problem bank and the route, read from the files tools/fetch-site.sh
## puts under bank/. Read-only: problems are changed in the site's repo.

var concepts: Array = []          # concept ids in site order
var problems: Array = []          # full problem Dictionaries in site order
var topics: Array = []            # route topics, in lesson order
var milestones: Array = []
var lessons: Array = []
var default_course_lock := 20
var new_per_day := 5
var site_commit := ""

var _by_id: Dictionary = {}
var _by_concept: Dictionary = {}   # concept -> Array of problems
var _topic_by_concept: Dictionary = {}


func _ready() -> void:
	var bank: Variant = _read_json("res://bank/problems.json")
	if bank is Dictionary:
		concepts = bank.get("concepts", [])
		problems = bank.get("problems", [])
	else:
		push_error("bank/problems.json is missing. Run tools/fetch-site.sh first.")
	for p in problems:
		_by_id[p.id] = p
		if not _by_concept.has(p.concept):
			_by_concept[p.concept] = []
		_by_concept[p.concept].append(p)

	var route: Variant = _read_json("res://bank/route.json")
	if route is Dictionary:
		topics = route.get("topics", [])
		milestones = route.get("milestones", [])
		lessons = route.get("lessons", [])
		default_course_lock = int(route.get("default_course_lock", 20))
		new_per_day = int(route.get("new_per_day", 5))
	for t in topics:
		_topic_by_concept[t.concept] = t

	var stamp := FileAccess.open("res://bank/COMMIT", FileAccess.READ)
	if stamp:
		site_commit = stamp.get_as_text().strip_edges()


func problem(id: String) -> Dictionary:
	return _by_id.get(id, {})


func has_problem(id: String) -> bool:
	return _by_id.has(id)


## The problems of one concept, in site order.
func problems_in(concept: String) -> Array:
	return _by_concept.get(concept, [])


func topic(concept: String) -> Dictionary:
	return _topic_by_concept.get(concept, {})


func topic_title(concept: String) -> String:
	return str(topic(concept).get("title", concept))


func _read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	return JSON.parse_string(file.get_as_text())
