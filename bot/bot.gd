# A bot that plays through the same act() API as a human, using only what
# the player could see. Two styles: "careful" (tries to win) and "random".
extends RefCounted

const Defs = preload("res://data/defs.gd")
const MapGen = preload("res://core/map_gen.gd")

var style := "careful"
var rng := RandomNumberGenerator.new()

func _init(p_style: String = "careful", p_seed: int = 1) -> void:
	style = p_style
	rng.seed = hash([p_seed, "bot"])

func choose(g) -> Dictionary:
	if not g.pending.is_empty():
		return _choose_pending(g)
	if style == "random":
		return {"type": "move", "dir": g.DIRS[rng.randi_range(0, 7)]}
	var a := _careful(g)
	return a if not a.is_empty() else {"type": "wait"}

func _choose_pending(g) -> Dictionary:
	var p: Dictionary = g.pending[0]
	if p.type == "levelup":
		# Strength early, accuracy once it falls behind.
		if g.player.acc < g.player.str_bonus:
			return {"type": "choose", "index": 1}
		return {"type": "choose", "index": 0}
	var prefs := ["toughness", "might", "ironskin", "vampiric", "precision", "thrift"]
	var best := 0
	var best_rank := 99
	for i in p.options.size():
		var r := prefs.find(p.options[i])
		if r < best_rank:
			best_rank = r
			best = i
	return {"type": "choose", "index": best}

func _find(g, id: String) -> int:
	for i in g.inventory.size():
		if g.inventory[i] == id and (g.identified.has(id) or not g.unknown_names.has(id)):
			return i
	return -1

func _find_unknown(g, kind: String) -> int:
	for i in g.inventory.size():
		var id: String = g.inventory[i]
		if Defs.ITEMS[id].kind == kind and not g.identified.has(id):
			return i
	return -1

func _careful(g) -> Dictionary:
	var p = g.player
	var foes: Array = g.visible_monsters().filter(func(m): return m.aware or m.ai != "boss" or true)
	var adjacent: Array = foes.filter(func(m): return g.cheb(m.pos, p.pos) == 1)
	var hp_frac: float = float(p.hp) / p.max_hp
	var in_danger := not adjacent.is_empty()

	# Equipment upgrades (free of risk when nothing is adjacent).
	if not in_danger:
		for i in g.inventory.size():
			var d: Dictionary = Defs.ITEMS[g.inventory[i]]
			if d.kind == "weapon" and _weapon_score(d) > _weapon_score(Defs.ITEMS[g.weapon]):
				return {"type": "use", "index": i}
			if d.kind == "armor":
				var cur: int = Defs.ITEMS[g.body_armor].tier if g.body_armor != "" else 0
				if d.tier > cur:
					return {"type": "use", "index": i}

	# Healing.
	if hp_frac < 0.4:
		var i := _find(g, "potion_heal")
		if i < 0:
			i = _find(g, "potion_vigor")
		if i < 0 and in_danger:
			i = _find_unknown(g, "potion")
		if i >= 0:
			return {"type": "use", "index": i}
		if in_danger:
			var esc := _find(g, "scroll_teleport")
			if esc < 0:
				esc = _find(g, "smoke_bomb")
			if esc >= 0:
				return {"type": "use", "index": esc}
	if not in_danger and p.hp <= p.max_hp - 5:
		var f := _find(g, "food")
		if f >= 0:
			return {"type": "use", "index": f}

	# Lantern.
	if g.oil < 60:
		var o := _find(g, "scroll_light")
		if o >= 0:
			return {"type": "use", "index": o}

	# Identify unknowns safely: full-ish HP and nothing in view.
	if foes.is_empty() and hp_frac > 0.7:
		var u := _find_unknown(g, "potion")
		if u < 0:
			u = _find_unknown(g, "scroll")
		if u >= 0:
			return {"type": "use", "index": u}

	# Area attacks when crowded.
	if adjacent.size() >= 2 or (foes.size() >= 3 and hp_frac < 0.6):
		var fs := _find(g, "scroll_fire")
		if fs >= 0:
			return {"type": "use", "index": fs}
		var b := _find(g, "bomb")
		if b >= 0:
			for m in foes:
				if g.cheb(m.pos, p.pos) >= 2 and g.cheb(m.pos, p.pos) <= 5:
					return {"type": "use", "index": b, "target": m.pos}

	# Class ability.
	if g.ability_ready() and not foes.is_empty():
		var ab: String = Defs.CLASSES[g.class_id].ability
		if ab == "bash" and not adjacent.is_empty():
			return {"type": "ability", "target": _weakest(adjacent).pos}
		if ab == "firebolt" and g.oil > 40:
			for m in _by_distance(g, foes):
				if g.cheb(m.pos, p.pos) <= 5 and g.line_of_sight(p.pos, m.pos):
					return {"type": "ability", "target": m.pos}

	if not adjacent.is_empty():
		return {"type": "move", "dir": _weakest(adjacent).pos - p.pos}

	# Aware foes closing in: wait for them in place rather than walking into packs.
	var aware_near: Array = foes.filter(func(m): return m.aware and g.cheb(m.pos, p.pos) <= 3 and m.ai != "ranged")
	if not aware_near.is_empty():
		return {"type": "wait"}
	var shooters: Array = foes.filter(func(m): return m.aware and m.ai == "ranged")
	if not shooters.is_empty():
		var sh: Dictionary = _path_to(g, shooters[0].pos)
		if not sh.is_empty():
			return sh

	# Oil flasks and items we know about.
	var targets: Array = []
	var full: bool = g.inventory.size() >= Defs.INV_CAP
	for pos in g.floor_items:
		var wanted := false
		for id in g.floor_items[pos]:
			if id == "oil" or (not full and not g._is_worse_gear(id)):
				wanted = true
		if g.is_seen(pos) and pos != p.pos and wanted:
			targets.append(pos)
	if g.tile(p.pos) == MapGen.STAIRS and _should_descend(g):
		return {"type": "descend"}
	if not targets.is_empty():
		var step: Dictionary = _path_to_nearest(g, targets)
		if not step.is_empty():
			return step
	if _should_descend(g) and g.stairs.x >= 0 and g.is_seen(g.stairs):
		var s: Dictionary = _path_to(g, g.stairs)
		if not s.is_empty():
			return s
	var ex := _explore(g)
	if not ex.is_empty():
		return ex
	if g.stairs.x >= 0 and g.is_seen(g.stairs):
		if g.tile(p.pos) == MapGen.STAIRS:
			return {"type": "descend"}
		return _path_to(g, g.stairs)
	return {"type": "wait"}

func _should_descend(g) -> bool:
	# Leave once oil is getting tight, or the floor is well explored.
	if g.oil < 120:
		return true
	return _explored_fraction(g) > 0.85

func _explored_fraction(g) -> float:
	var total := 0
	var seen := 0
	for i in g.w * g.h:
		if g.tiles[i] != MapGen.WALL:
			total += 1
			if g.seen[i] == 1:
				seen += 1
	return float(seen) / maxi(1, total)

func _weapon_score(d: Dictionary) -> float:
	return (d.dmg[0] + d.dmg[1]) / 2.0 + d.get("acc", 0) * 0.5

func _weakest(arr: Array):
	var best = arr[0]
	for m in arr:
		if m.hp < best.hp:
			best = m
	return best

func _by_distance(g, arr: Array) -> Array:
	var a := arr.duplicate()
	a.sort_custom(func(x, y): return g.cheb(x.pos, g.player.pos) < g.cheb(y.pos, g.player.pos))
	return a

func _path_to(g, goal: Vector2i) -> Dictionary:
	return _path_to_nearest(g, [goal])

func _path_to_nearest(g, goals: Array) -> Dictionary:
	# BFS from the player over seen, passable tiles not blocked by monsters.
	var w: int = g.w
	var n: int = w * g.h
	var is_goal := PackedByteArray()
	is_goal.resize(n)
	for x in goals:
		is_goal[x.y * w + x.x] = 1
	var blocked := PackedByteArray()
	blocked.resize(n)
	for m in g.monsters:
		if m.alive():
			blocked[m.pos.y * w + m.pos.x] = 1
	var start: int = g.player.pos.y * w + g.player.pos.x
	var prev := PackedInt32Array()
	prev.resize(n)
	prev.fill(-1)
	prev[start] = start
	var queue := PackedInt32Array()
	queue.resize(n)
	queue[0] = start
	var head := 0
	var tail := 1
	var offs := PackedInt32Array([-w - 1, -w, -w + 1, -1, 1, w - 1, w, w + 1])
	var tiles: PackedByteArray = g.tiles
	var seen: PackedByteArray = g.seen
	while head < tail:
		var c := queue[head]
		head += 1
		if is_goal[c] == 1 and c != start:
			var s := c
			while prev[s] != start:
				s = prev[s]
			return {"type": "move", "dir": Vector2i(s % w, s / w) - g.player.pos}
		for o in offs:
			var j := c + o
			if prev[j] != -1 or tiles[j] == MapGen.WALL or seen[j] == 0:
				continue
			if blocked[j] == 1 and is_goal[j] == 0:
				continue
			prev[j] = c
			queue[tail] = j
			tail += 1
	return {}

func _explore(g) -> Dictionary:
	# Frontier: seen passable tiles next to unseen passable tiles.
	var w: int = g.w
	var tiles: PackedByteArray = g.tiles
	var seen: PackedByteArray = g.seen
	var offs := PackedInt32Array([-w - 1, -w, -w + 1, -1, 1, w - 1, w, w + 1])
	var frontier: Array = []
	for i in range(w + 1, w * (g.h - 1) - 1):
		if seen[i] == 0 or tiles[i] == MapGen.WALL:
			continue
		for o in offs:
			var j := i + o
			if seen[j] == 0 and tiles[j] != MapGen.WALL:
				frontier.append(Vector2i(i % w, i / w))
				break
	if frontier.is_empty():
		return {}
	return _path_to_nearest(g, frontier)
