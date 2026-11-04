# Between-run progress: unlocks, records, run history. Stored in user://.
extends RefCounted

const PATH := "user://profile.json"
const SAVE_PATH := "user://run.json"
const UNLOCK_FLOOR := {"cutpurse": 4, "adept": 7}

static func load_profile() -> Dictionary:
	var p := {"runs": 0, "wins": 0, "best_floor": 0, "unlocked": ["guard"], "history": [], "daily": {}}
	if FileAccess.file_exists(PATH):
		var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if d is Dictionary:
			p.merge(d, true)
	return p

static func save_profile(p: Dictionary) -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(p))

# Records a finished run; returns the names of any classes it unlocked.
static func record_run(g, daily_key: String = "") -> Array:
	var p := load_profile()
	p.runs += 1
	if g.state == "won":
		p.wins += 1
	p.best_floor = maxi(int(p.best_floor), g.floor_num)
	var unlocked: Array = []
	for c in UNLOCK_FLOOR:
		if not c in p.unlocked and g.floor_num >= UNLOCK_FLOOR[c]:
			p.unlocked.append(c)
			unlocked.append(c)
	p.history.push_front({"class": g.class_id, "result": g.state, "floor": g.floor_num, "turns": g.turn,
		"kills": g.stats.kills, "cause": g.death_cause, "seed": g.seed_value,
		"date": Time.get_date_string_from_system()})
	p.history = p.history.slice(0, 50)
	if daily_key != "":
		p.daily[daily_key] = {"result": g.state, "floor": g.floor_num}
	save_profile(p)
	delete_save()
	return unlocked

static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

static func write_save(g, daily_key: String) -> void:
	var d: Dictionary = g.to_dict()
	d["daily_key"] = daily_key
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))

static func read_save():
	if not has_save():
		return null
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	return d if d is Dictionary else null

static func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

static func daily_seed() -> Array:
	var date := Time.get_date_string_from_system(true)
	return [date, absi(hash("lanternfall-daily-" + date)) % 1000000000]
