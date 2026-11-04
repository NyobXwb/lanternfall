# The whole rules engine. No nodes, no rendering: the UI, the bot and the
# simulator all drive it through act().
extends RefCounted

const Defs = preload("res://data/defs.gd")
const MapGen = preload("res://core/map_gen.gd")
const Actor = preload("res://core/actor.gd")

const DIRS := [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0),
	Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]

signal changed

var seed_value := 0
var class_id := "guard"
var rng := RandomNumberGenerator.new()     # combat and AI
var w := Defs.MAP_W
var h := Defs.MAP_H
var tiles := PackedByteArray()
var seen := PackedByteArray()
var visible := {}
var rooms: Array[Rect2i] = []
var stairs := Vector2i(-1, -1)
var floor_num := 1
var player: Actor
var monsters: Array = []
var floor_items := {}          # Vector2i -> Array[String]
var inventory: Array[String] = []
var weapon := ""
var body_armor := ""
var oil := Defs.OIL_START
var dark_counter := 0
var turn := 0
var level := 1
var blessings: Array[String] = []
var pending: Array = []        # queue of {type, options}
var state := "playing"         # playing, won, dead
var death_cause := ""
var messages: Array[String] = []
var identified := {}
var unknown_names := {}
var stats := {"kills": 0, "items_used": 0, "max_floor": 1, "oil_deaths": 0, "damage_taken": 0}
var dist_map := PackedInt32Array()

func _init(p_seed: int = 1, p_class: String = "guard") -> void:
	seed_value = p_seed
	class_id = p_class
	rng.seed = hash([p_seed, "combat"])
	_assign_unknown_names()
	var c: Dictionary = Defs.CLASSES[class_id]
	player = Actor.new()
	player.is_player = true
	player.kind = "player"
	player.name = "you"
	player.max_hp = c.hp
	player.hp = c.hp
	player.str_bonus = c.str
	player.acc = c.acc
	player.eva = c.eva
	player.armor = c.armor
	weapon = c.weapon
	for it in c.kit:
		inventory.append(it)
		identified[it] = true   # you know what you packed
	_new_floor()

# ---------------------------------------------------------------- setup

func _assign_unknown_names() -> void:
	var name_rng := RandomNumberGenerator.new()
	name_rng.seed = hash([seed_value, "names"])
	var pn: Array = Defs.UNKNOWN_POTION_NAMES.duplicate()
	var sn: Array = Defs.UNKNOWN_SCROLL_NAMES.duplicate()
	_shuffle(pn, name_rng)
	_shuffle(sn, name_rng)
	for id in Defs.ITEMS:
		var d: Dictionary = Defs.ITEMS[id]
		if d.kind == "potion":
			unknown_names[id] = pn.pop_back() + " potion"
		elif d.kind == "scroll":
			unknown_names[id] = "scroll labelled " + sn.pop_back()

func _shuffle(a: Array, r: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := r.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t

func _new_floor() -> void:
	var frng := RandomNumberGenerator.new()
	frng.seed = hash([seed_value, "floor", floor_num])
	var m := MapGen.generate(frng, floor_num)
	tiles = m.tiles
	rooms = m.rooms
	stairs = m.stairs if floor_num < Defs.LAST_FLOOR else Vector2i(-1, -1)
	seen = PackedByteArray()
	seen.resize(w * h)
	seen.fill(0)
	monsters.clear()
	floor_items.clear()
	player.pos = m.start
	player.root = 0
	_populate(frng, m)
	stats.max_floor = maxi(stats.max_floor, floor_num)
	_refresh()
	msg("You reach floor %d." % floor_num if floor_num > 1 else "You light your lantern and descend.")

func _populate(frng: RandomNumberGenerator, m: Dictionary) -> void:
	var pool: Array[String] = []
	for id in Defs.MONSTERS:
		var f: Array = Defs.MONSTERS[id].floors
		if floor_num >= f[0] and floor_num <= f[1]:
			pool.append(id)
	var count := 4 + floor_num * 2 / 3 + frng.randi_range(0, 3)
	if floor_num == Defs.LAST_FLOOR:
		count = 5
		var boss_room: Rect2i = rooms[m.stairs_room]
		spawn_monster("warden", MapGen._center(boss_room))
	var placed := 0
	var guard := 0
	while placed < count and guard < 200:
		guard += 1
		var id: String = pool[frng.randi_range(0, pool.size() - 1)]
		var room_i := frng.randi_range(1, rooms.size() - 1)
		var group: int = Defs.MONSTERS[id].get("pack", 1)
		for g in group:
			var p := _random_free_tile_in(rooms[room_i], frng)
			if p.x >= 0:
				spawn_monster(id, p)
				placed += 1
	# Items
	var item_pool: Array[String] = []
	var weights: Array[int] = []
	var max_tier := 1 + floor_num / 3
	for id in Defs.ITEMS:
		var d: Dictionary = Defs.ITEMS[id]
		if d.weight <= 0:
			continue
		if d.has("tier") and d.tier > max_tier:
			continue
		item_pool.append(id)
		weights.append(d.weight)
	var n_items := frng.randi_range(3, 6)
	for i in n_items:
		var id := _weighted(item_pool, weights, frng)
		_drop_random(id, frng)
	for i in frng.randi_range(1, 2):
		_drop_random("oil", frng)

func _weighted(pool: Array[String], weights: Array[int], r: RandomNumberGenerator) -> String:
	var total := 0
	for x in weights:
		total += x
	var roll := r.randi_range(1, total)
	for i in pool.size():
		roll -= weights[i]
		if roll <= 0:
			return pool[i]
	return pool[0]

func _drop_random(id: String, r: RandomNumberGenerator) -> void:
	var room: Rect2i = rooms[r.randi_range(0, rooms.size() - 1)]
	var p := _random_free_tile_in(room, r)
	if p.x >= 0 and tile(p) == MapGen.FLOOR:
		add_floor_item(p, id)

func _random_free_tile_in(room: Rect2i, r: RandomNumberGenerator) -> Vector2i:
	for i in 20:
		var p := Vector2i(r.randi_range(room.position.x, room.end.x - 1), r.randi_range(room.position.y, room.end.y - 1))
		if tile(p) == MapGen.FLOOR and monster_at(p) == null and p != player.pos:
			return p
	return Vector2i(-1, -1)

func spawn_monster(id: String, p: Vector2i) -> Actor:
	var d: Dictionary = Defs.MONSTERS[id]
	var a := Actor.new()
	a.kind = id
	a.name = d.name
	a.pos = p
	# Deeper floors make every monster a little tougher and sharper.
	var depth := floor_num - 1 if d.ai != "boss" else 0
	a.max_hp = d.hp + d.hp * depth / 30
	a.hp = a.max_hp
	a.acc = d.acc + depth / 5
	a.eva = d.eva
	a.armor = d.armor
	a.dmg = d.dmg
	a.ai = d.ai
	a.xp = d.xp
	monsters.append(a)
	return a

func add_floor_item(p: Vector2i, id: String) -> void:
	if not floor_items.has(p):
		floor_items[p] = []
	floor_items[p].append(id)

# ---------------------------------------------------------------- queries

func tile(p: Vector2i) -> int:
	if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h:
		return MapGen.WALL
	return tiles[p.y * w + p.x]

func passable(p: Vector2i) -> bool:
	return tile(p) != MapGen.WALL

func monster_at(p: Vector2i) -> Actor:
	for m in monsters:
		if m.alive() and m.pos == p:
			return m
	return null

func light_radius() -> int:
	if oil <= 0:
		return 1
	return mini(7, 2 + oil / 50)

func is_seen(p: Vector2i) -> bool:
	return seen[p.y * w + p.x] == 1

func item_name(id: String) -> String:
	if unknown_names.has(id) and not identified.has(id):
		return unknown_names[id]
	return Defs.ITEMS[id].name

func weapon_stats() -> Dictionary:
	return Defs.ITEMS[weapon]

func total_armor() -> int:
	var a := player.armor
	if body_armor != "":
		a += Defs.ITEMS[body_armor].armor
	return a

func total_eva() -> int:
	var e := player.eva
	if body_armor != "":
		e += Defs.ITEMS[body_armor].eva
	return e

func total_acc() -> int:
	return player.acc + weapon_stats().get("acc", 0)

func ability_ready() -> bool:
	return Defs.CLASSES[class_id].ability != "backstab" and player.cooldown == 0

static func cheb(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))

func line_of_sight(a: Vector2i, b: Vector2i) -> bool:
	# Bresenham walk; endpoints never block.
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx + dy
	var x := a.x
	var y := a.y
	while true:
		if x == b.x and y == b.y:
			return true
		if (x != a.x or y != a.y) and tiles[y * w + x] == MapGen.WALL:
			return false
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy
	return true

func visible_monsters() -> Array:
	var out := []
	for m in monsters:
		if m.alive() and visible.has(m.pos) and not (m.ai == "mimic" and not m.aware):
			out.append(m)
	return out

func msg(s: String) -> void:
	messages.append(s)
	if messages.size() > 200:
		messages.remove_at(0)

# ---------------------------------------------------------------- actions
# Actions are dictionaries:
#   {type:"move", dir:Vector2i}  (bumping a monster attacks it)
#   {type:"wait"}
#   {type:"use", index:int, target:Vector2i (bombs only)}
#   {type:"ability", target:Vector2i}
#   {type:"descend"}
#   {type:"choose", index:int}
# Returns true if the action was legal (and so a turn may have passed).

func act(a: Dictionary) -> bool:
	if state != "playing":
		return false
	if not pending.is_empty():
		if a.type != "choose":
			return false
		return _choose(a.index)
	var ok := false
	match a.type:
		"move":
			ok = _move(a.dir)
		"wait":
			ok = true
		"use":
			ok = _use(a.index, a.get("target", Vector2i(-1, -1)))
		"ability":
			ok = _ability(a.get("target", Vector2i(-1, -1)))
		"descend":
			ok = _descend()
			if ok:
				changed.emit()
				return true
	if ok:
		_end_turn()
	changed.emit()
	return ok

func _move(d: Vector2i) -> bool:
	if d == Vector2i.ZERO or absi(d.x) > 1 or absi(d.y) > 1:
		return false
	var t := player.pos + d
	var m := monster_at(t)
	if m != null:
		_player_attack(m, 0)
		return true
	if not passable(t):
		return false
	if player.root > 0:
		msg("You are stuck in a web.")
		return true
	player.pos = t
	_on_enter(t)
	return true

func _on_enter(p: Vector2i) -> void:
	if floor_items.has(p):
		var left: Array = []
		for id in floor_items[p]:
			if id == "oil":
				oil = mini(Defs.OIL_MAX, oil + Defs.OIL_FLASK)
				msg("You refill your lantern.")
			elif inventory.size() < Defs.INV_CAP:
				inventory.append(id)
				msg("You pick up %s." % item_name(id))
			else:
				left.append(id)
		if left.is_empty():
			floor_items.erase(p)
		else:
			floor_items[p] = left
	if tile(p) == MapGen.SHRINE:
		tiles[p.y * w + p.x] = MapGen.FLOOR
		var opts: Array = Defs.BLESSINGS.keys().filter(func(b): return not b in blessings)
		_shuffle(opts, rng)
		pending.append({"type": "blessing", "options": opts.slice(0, 3)})
		msg("A shrine hums. Choose a blessing.")
	if tile(p) == MapGen.STAIRS:
		msg("Stairs lead down.")

func _descend() -> bool:
	if tile(player.pos) != MapGen.STAIRS:
		return false
	floor_num += 1
	_new_floor()
	return true

func _choose(i: int) -> bool:
	var p: Dictionary = pending[0]
	if i < 0 or i >= p.options.size():
		return false
	var o: String = p.options[i]
	pending.pop_front()
	if p.type == "levelup":
		match o:
			"str": player.str_bonus += 1
			"acc": player.acc += 1
			"eva": player.eva += 1
	elif p.type == "blessing":
		blessings.append(o)
		match o:
			"toughness":
				player.max_hp += 8
				player.hp += 8
			"precision": player.acc += 2
			"might": player.str_bonus += 1
			"ironskin": player.armor += 1
		msg("You feel blessed: %s." % Defs.BLESSINGS[o])
	changed.emit()
	return true

func _use(i: int, target: Vector2i) -> bool:
	if i < 0 or i >= inventory.size():
		return false
	var id := inventory[i]
	var d: Dictionary = Defs.ITEMS[id]
	match d.kind:
		"weapon":
			inventory.remove_at(i)
			inventory.append(weapon)
			weapon = id
			msg("You wield the %s." % d.name)
			return true
		"armor":
			inventory.remove_at(i)
			if body_armor != "":
				inventory.append(body_armor)
			body_armor = id
			msg("You put on the %s." % d.name)
			return true
		"bomb":
			if target.x < 0 or not visible.has(target) or cheb(target, player.pos) > 5:
				return false
			inventory.remove_at(i)
			msg("The bomb explodes!")
			for m in monsters.duplicate():
				if m.alive() and cheb(m.pos, target) <= 1:
					_damage_monster(m, 10)
			if cheb(player.pos, target) <= 1:
				_damage_player(5, "your own bomb")
			stats.items_used += 1
			return true
	inventory.remove_at(i)
	stats.items_used += 1
	var was_known := identified.has(id) or not unknown_names.has(id)
	identified[id] = true
	match id:
		"potion_heal":
			var amt := maxi(15, player.max_hp / 2)
			player.hp = mini(player.max_hp, player.hp + amt)
			msg("You feel much better.")
		"potion_strength":
			player.str_bonus += 1
			msg("You feel stronger.")
		"potion_vigor":
			player.max_hp += 4
			player.hp = player.max_hp
			msg("Vigor floods through you.")
		"potion_poison":
			player.hp = maxi(1, player.hp - 6)
			stats.damage_taken += 6
			msg("Ugh, poison!")
		"scroll_fire":
			msg("Flames burst around you!")
			for m in monsters.duplicate():
				if m.alive() and cheb(m.pos, player.pos) <= 3 and visible.has(m.pos):
					_damage_monster(m, 8)
		"scroll_teleport":
			_teleport()
			msg("The world twists around you.")
		"scroll_map":
			for k in w * h:
				if tiles[k] != MapGen.WALL:
					seen[k] = 1
			msg("The floor's layout fills your mind.")
		"scroll_light":
			oil = mini(Defs.OIL_MAX, oil + 120)
			msg("Your lantern flares brightly.")
		"food":
			player.hp = mini(player.max_hp, player.hp + 5)
			msg("You eat a ration.")
		"smoke_bomb":
			msg("Smoke fills the air.")
			for m in monsters:
				if m.alive() and cheb(m.pos, player.pos) <= 6 and m.ai != "boss":
					m.aware = false
					m.stun = maxi(m.stun, 1)
	if not was_known:
		msg("(It was a %s.)" % d.name)
	return true

func _teleport() -> void:
	for i in 100:
		var room: Rect2i = rooms[rng.randi_range(0, rooms.size() - 1)]
		var p := Vector2i(rng.randi_range(room.position.x, room.end.x - 1), rng.randi_range(room.position.y, room.end.y - 1))
		if tile(p) == MapGen.FLOOR and monster_at(p) == null and cheb(p, player.pos) > 8:
			player.pos = p
			return

func _ability(target: Vector2i) -> bool:
	if not ability_ready():
		return false
	var m := monster_at(target)
	if m == null:
		return false
	match Defs.CLASSES[class_id].ability:
		"bash":
			if cheb(m.pos, player.pos) != 1:
				return false
			player.cooldown = Defs.CLASSES[class_id].cooldown
			msg("You bash the %s!" % m.name)
			m.stun = maxi(m.stun, 2)
			_player_attack(m, 0)
			return true
		"firebolt":
			if not visible.has(m.pos) or cheb(m.pos, player.pos) > 5 or not line_of_sight(player.pos, m.pos):
				return false
			player.cooldown = Defs.CLASSES[class_id].cooldown
			oil = maxi(0, oil - 5)
			msg("A firebolt strikes the %s!" % m.name)
			m.aware = true
			_damage_monster(m, 7 + level / 2)
			return true
	return false

# ---------------------------------------------------------------- combat

func hit_chance(acc: int, eva: int) -> int:
	return clampi(70 + 5 * (acc - eva), 10, 95)

func _player_attack(m: Actor, _bonus: int) -> void:
	var wd: Dictionary = weapon_stats()
	var dmg := rng.randi_range(wd.dmg[0], wd.dmg[1]) + player.str_bonus
	if class_id == "cutpurse" and (not m.aware or m.stun > 0):
		dmg *= 3
		msg("You backstab the %s!" % m.name)
		m.aware = true
		_damage_monster(m, maxi(1, dmg - _soak(m.armor)))
		return
	m.aware = true
	if m.ai == "mimic":
		pass
	if rng.randi_range(1, 100) > hit_chance(total_acc(), m.eva):
		msg("You miss the %s." % m.name)
		return
	_damage_monster(m, maxi(1, dmg - _soak(m.armor)))

# Armor soaks a random 0..armor points, so heavy armor helps but never makes you immune.
func _soak(armor_value: int) -> int:
	return rng.randi_range(0, armor_value) if armor_value > 0 else 0

func _damage_monster(m: Actor, amount: int) -> void:
	m.hp -= amount
	m.aware = true
	if m.hp <= 0:
		_kill(m)
		return
	msg("You hit the %s (%d)." % [m.name, amount])
	if m.ai == "split" and m.gen < 2 and m.hp >= 3:
		for d in DIRS:
			var p: Vector2i = m.pos + d
			if passable(p) and monster_at(p) == null and p != player.pos:
				var half := m.hp / 2
				m.hp -= half
				var s := spawn_monster("slime", p)
				s.hp = half
				s.max_hp = m.max_hp
				s.gen = m.gen + 1
				m.gen += 1
				s.aware = true
				s.xp = 1
				msg("The slime splits!")
				break
	if m.ai == "boss":
		if m.phase == 1 and m.hp <= m.max_hp * 6 / 10:
			m.phase = 2
			msg("The Warden roars and calls its guards!")
			for i in 2:
				for d in DIRS:
					var p: Vector2i = m.pos + d * 2
					if passable(p) and monster_at(p) == null and p != player.pos:
						var g := spawn_monster("archer", p)
						g.aware = true
						break
		elif m.phase == 2 and m.hp <= m.max_hp * 3 / 10:
			m.phase = 3
			oil = maxi(0, oil - 60)
			m.dmg = [m.dmg[0] + 2, m.dmg[1] + 2]
			msg("The Warden snuffs the light around you!")

func _kill(m: Actor) -> void:
	msg("The %s dies." % m.name)
	stats.kills += 1
	if "vampiric" in blessings:
		player.hp = mini(player.max_hp, player.hp + 2)
	_gain_xp(m.xp)
	if m.ai == "boss":
		state = "won"
		msg("The Warden falls. The way out is open. You win!")

func _gain_xp(x: int) -> void:
	player.xp += x
	while level < Defs.MAX_LEVEL and player.xp >= Defs.xp_for_level(level + 1):
		level += 1
		player.max_hp += Defs.LEVEL_HP
		player.hp = player.max_hp
		pending.append({"type": "levelup", "options": ["str", "acc", "eva"]})
		msg("You reach level %d!" % level)

func _monster_attack(m: Actor) -> void:
	if rng.randi_range(1, 100) > hit_chance(m.acc, total_eva()):
		msg("The %s misses." % m.name)
		return
	var dmg := maxi(1, rng.randi_range(m.dmg[0], m.dmg[1]) - _soak(total_armor()))
	msg("The %s hits you (%d)." % [m.name, dmg])
	_damage_player(dmg, m.name)
	if m.ai == "drain":
		oil = maxi(0, oil - 15)
		msg("Your lantern gutters.")

func _damage_player(amount: int, cause: String) -> void:
	player.hp -= amount
	stats.damage_taken += amount
	if player.hp <= 0 and state == "playing":
		state = "dead"
		death_cause = cause
		msg("You die. Killed by %s on floor %d." % [cause, floor_num])

# ---------------------------------------------------------------- turn

func _end_turn() -> void:
	turn += 1
	if not ("thrift" in blessings and turn % 4 == 0):
		oil = maxi(0, oil - 1)
	if oil == 0:
		dark_counter += 1
		if dark_counter >= Defs.DARK_DAMAGE_EVERY:
			dark_counter = 0
			_damage_player(1, "the dark")
			if state == "dead":
				stats.oil_deaths += 1
	if player.cooldown > 0:
		player.cooldown -= 1
	if player.root > 0:
		player.root -= 1
	var any_aware := false
	for m in monsters:
		if m.aware:
			any_aware = true
			break
	if any_aware:
		dist_map = MapGen.bfs(tiles, w, h, player.pos)
	for m in monsters.duplicate():
		if state != "playing":
			break
		if m.alive():
			_monster_turn(m)
	monsters = monsters.filter(func(m): return m.alive())
	_refresh()

func _refresh() -> void:
	visible.clear()
	var r := light_radius()
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy > r * r + r:
				continue
			var p := player.pos + Vector2i(dx, dy)
			if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h:
				continue
			if line_of_sight(player.pos, p):
				visible[p] = true
				seen[p.y * w + p.x] = 1
	var notice := r + (0 if class_id == "cutpurse" else 2)
	for m in monsters:
		if m.aware or m.ai == "mimic":
			continue
		if cheb(m.pos, player.pos) <= notice and line_of_sight(m.pos, player.pos):
			m.aware = true

func _monster_turn(m: Actor) -> void:
	if m.stun > 0:
		m.stun -= 1
		return
	if m.ai == "mimic" and not m.aware:
		if cheb(m.pos, player.pos) <= 1:
			m.aware = true
			msg("The treasure was a mimic!")
		return
	if not m.aware:
		return
	if m.ai == "slow" and turn % 2 == 0:
		return
	var d := cheb(m.pos, player.pos)
	match m.ai:
		"erratic":
			if rng.randf() < 0.4:
				_step(m, DIRS[rng.randi_range(0, 7)])
				return
		"ranged":
			if d == 1:
				# Archers try to back off, but only when their bow is still loaded.
				if m.timer == 0 or not _step_away(m):
					_monster_attack(m)
				return
			if d <= 5 and line_of_sight(m.pos, player.pos):
				m.timer = 1 - m.timer
				if m.timer == 0:
					msg("The %s nocks an arrow." % m.name)
					return
				msg("The %s shoots an arrow." % m.name)
				_monster_attack(m)
				return
		"web":
			if m.timer > 0:
				m.timer -= 1
			if d >= 2 and d <= 4 and m.timer == 0 and line_of_sight(m.pos, player.pos):
				m.timer = 6
				player.root = 2
				msg("The spider spins a web over you!")
				return
		"summon":
			m.timer += 1
			if m.timer >= 7 and m.summons < 3:
				m.timer = 0
				for dd in DIRS:
					var p: Vector2i = m.pos + dd
					if passable(p) and monster_at(p) == null and p != player.pos:
						var s := spawn_monster("rat", p)
						s.aware = true
						s.xp = 0
						m.summons += 1
						msg("The cultist summons a rat.")
						return
		"boss":
			if m.phase == 3 and turn % 3 == 0 and d == 1:
				_monster_attack(m)
				if state != "playing":
					return
	if d == 1:
		_monster_attack(m)
		return
	_approach(m)

func _approach(m: Actor) -> void:
	var best := m.pos
	var best_d: int = dist_map[m.pos.y * w + m.pos.x]
	if best_d < 0:
		best_d = 9999
	for dd in DIRS:
		var p: Vector2i = m.pos + dd
		if not passable(p) or monster_at(p) != null or p == player.pos:
			continue
		var pd: int = dist_map[p.y * w + p.x]
		if pd >= 0 and pd < best_d:
			best_d = pd
			best = p
	m.pos = best

func _step(m: Actor, dd: Vector2i) -> void:
	var p := m.pos + dd
	if p == player.pos:
		_monster_attack(m)
	elif passable(p) and monster_at(p) == null:
		m.pos = p

func _step_away(m: Actor) -> bool:
	var best := m.pos
	var best_d: int = dist_map[m.pos.y * w + m.pos.x]
	for dd in DIRS:
		var p: Vector2i = m.pos + dd
		if not passable(p) or monster_at(p) != null or p == player.pos:
			continue
		var pd: int = dist_map[p.y * w + p.x]
		if pd > best_d:
			best_d = pd
			best = p
	if best == m.pos:
		return false
	m.pos = best
	return true

# ---------------------------------------------------------------- save / load

const ACTOR_FIELDS := ["kind", "name", "hp", "max_hp", "str_bonus", "acc", "eva", "armor", "dmg", "ai",
	"xp", "is_player", "aware", "stun", "root", "cooldown", "gen", "timer", "phase", "summons"]

func _actor_to_dict(a: Actor) -> Dictionary:
	var d := {"pos": [a.pos.x, a.pos.y]}
	for f in ACTOR_FIELDS:
		d[f] = a.get(f)
	return d

func _actor_from_dict(d: Dictionary) -> Actor:
	var a := Actor.new()
	for f in ACTOR_FIELDS:
		var v = d[f]
		if v is float:
			v = int(v)
		if f == "dmg":
			v = [int(v[0]), int(v[1])]
		a.set(f, v)
	a.pos = Vector2i(int(d.pos[0]), int(d.pos[1]))
	return a

func to_dict() -> Dictionary:
	var items := []
	for p in floor_items:
		items.append([p.x, p.y, floor_items[p]])
	var mons := []
	for m in monsters:
		mons.append(_actor_to_dict(m))
	var rms := []
	for r in rooms:
		rms.append([r.position.x, r.position.y, r.size.x, r.size.y])
	return {
		"version": 1, "seed": seed_value, "class": class_id, "rng_state": str(rng.state),
		"tiles": Marshalls.raw_to_base64(tiles), "seen": Marshalls.raw_to_base64(seen),
		"rooms": rms, "stairs": [stairs.x, stairs.y], "floor": floor_num,
		"player": _actor_to_dict(player), "monsters": mons, "items": items,
		"inventory": inventory, "weapon": weapon, "body_armor": body_armor, "oil": oil,
		"dark_counter": dark_counter, "turn": turn, "level": level, "blessings": blessings,
		"pending": pending, "messages": messages.slice(-30), "identified": identified.keys(),
		"stats": stats,
	}

static func from_dict(d: Dictionary):
	var g = load("res://core/game.gd").new(int(d.seed), d["class"])
	g.rng.state = int(d.rng_state)
	g.tiles = Marshalls.base64_to_raw(d.tiles)
	g.seen = Marshalls.base64_to_raw(d.seen)
	g.rooms.clear()
	for r in d.rooms:
		g.rooms.append(Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])))
	g.stairs = Vector2i(int(d.stairs[0]), int(d.stairs[1]))
	g.floor_num = int(d.floor)
	g.player = g._actor_from_dict(d.player)
	g.monsters.clear()
	for m in d.monsters:
		g.monsters.append(g._actor_from_dict(m))
	g.floor_items.clear()
	for it in d.items:
		var arr: Array = []
		for id in it[2]:
			arr.append(str(id))
		g.floor_items[Vector2i(int(it[0]), int(it[1]))] = arr
	g.inventory.clear()
	for id in d.inventory:
		g.inventory.append(str(id))
	g.weapon = d.weapon
	g.body_armor = d.body_armor
	g.oil = int(d.oil)
	g.dark_counter = int(d.dark_counter)
	g.turn = int(d.turn)
	g.level = int(d.level)
	g.blessings.clear()
	for b in d.blessings:
		g.blessings.append(str(b))
	g.pending = d.pending
	g.messages.clear()
	for s in d.messages:
		g.messages.append(str(s))
	g.identified.clear()
	for id in d.identified:
		g.identified[str(id)] = true
	for k in d.stats:
		g.stats[k] = int(d.stats[k])
	g.state = "playing"
	g._refresh()
	return g
