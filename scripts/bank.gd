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
var cards: Array = []             # concept cards, in file order

var _card_by_id: Dictionary = {}
var _milestone_data: Dictionary = {}   # id -> the milestone file (intro, steps, godot)
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

	var milestone_list: Variant = _read_json("res://bank/milestones.json")
	if milestone_list is Array:
		for m in milestone_list:
			_milestone_data[m.id] = m

	var card_list: Variant = _read_json("res://bank/cards.json")
	if card_list is Array:
		cards = card_list
	for c in cards:
		_card_by_id[c.id] = c

	var stamp := FileAccess.open("res://bank/COMMIT", FileAccess.READ)
	if stamp:
		site_commit = stamp.get_as_text().strip_edges()


# ---- milestones ----

## The route's entry for a milestone (number, title, after, steps, badge).
func milestone(id: String) -> Dictionary:
	for m in milestones:
		if m.id == id:
			return m
	return {}


## The milestone file: intro, the steps with their checks, the Godot list.
## {} for a milestone the site has only planned.
func milestone_data(id: String) -> Dictionary:
	return _milestone_data.get(id, {})


# ---- concept cards ----
# One per core concept, grouped by the lesson they belong to. In the review
# queue a card's id is "card:<id>", so it never collides with a problem.

func card(id: String) -> Dictionary:
	return _card_by_id.get(id.trim_prefix("card:"), {})


static func card_id(c: Dictionary) -> String:
	return "card:" + str(c.id)


static func is_card_id(id: String) -> bool:
	return id.begins_with("card:")


func lesson_of(concept: String) -> int:
	return int(topic(concept).get("lesson", -1))


## Cards for a topic: every card whose own topic is in the same lesson.
func cards_for_concept(concept: String) -> Array:
	var lesson := lesson_of(concept)
	if lesson < 0:
		return []
	var concepts := {}
	for t in topics:
		if int(t.lesson) == lesson:
			concepts[t.concept] = true
	return cards.filter(func(c: Dictionary) -> bool: return concepts.has(c.concept))


## Cards grouped by lesson number, in course order:
## [{ "lesson": int, "titles": [topic titles], "cards": [...] }]
func cards_by_lesson() -> Array:
	var groups := {}
	var order := []
	for t in topics:
		var here: Array = cards.filter(func(c: Dictionary) -> bool: return c.concept == t.concept)
		if here.is_empty():
			continue
		var lesson := int(t.lesson)
		if not groups.has(lesson):
			groups[lesson] = {"lesson": lesson, "titles": [], "cards": []}
			order.append(lesson)
		groups[lesson].titles.append(t.title)
		groups[lesson].cards.append_array(here)
	var out := []
	for lesson in order:
		out.append(groups[lesson])
	return out


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
