# Headless tests: godot --headless --path . -s tools/test.gd
extends SceneTree

const Game = preload("res://core/game.gd")
const Bot = preload("res://bot/bot.gd")
const MapGen = preload("res://core/map_gen.gd")
const Defs = preload("res://data/defs.gd")

var failures := 0
var checks := 0

func check(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		print("FAIL: ", what)

func _init() -> void:
	test_maps_connected()
	test_determinism()
	test_save_round_trip()
	test_illegal_actions()
	test_lantern()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

func _play(g, bot, n: int) -> void:
	var i := 0
	while g.state == "playing" and i < n:
		if not g.act(bot.choose(g)):
			g.act({"type": "wait"})
		i += 1

func test_maps_connected() -> void:
	for s in 300:
		for f in [1, 5, 10]:
			var r := RandomNumberGenerator.new()
			r.seed = s * 31 + f
			var m := MapGen.generate(r, f)
			var dist := MapGen.bfs(m.tiles, Defs.MAP_W, Defs.MAP_H, m.start)
			var all := true
			for i in m.tiles.size():
				if m.tiles[i] != MapGen.WALL and dist[i] < 0:
					all = false
			check(all, "every floor tile reachable (seed %d floor %d)" % [s, f])
			check(m.rooms.size() >= 4, "at least 4 rooms (seed %d)" % s)

func test_determinism() -> void:
	for s in [1, 7, 42]:
		var a := Game.new(s, "guard")
		var b := Game.new(s, "guard")
		_play(a, Bot.new("careful", s), 3000)
		_play(b, Bot.new("careful", s), 3000)
		check(a.turn == b.turn and a.floor_num == b.floor_num and a.player.hp == b.player.hp,
			"same seed plays the same (seed %d)" % s)

func test_save_round_trip() -> void:
	for s in [3, 11]:
		var a := Game.new(s, "adept")
		var bot_a := Bot.new("careful", s)
		_play(a, bot_a, 400)
		var json := JSON.stringify(a.to_dict())
		var b = Game.from_dict(JSON.parse_string(json))
		check(JSON.stringify(b.to_dict()) == json, "save survives a round trip (seed %d)" % s)
		# Both copies keep playing identically afterwards.
		var bot_b := Bot.new("careful", s)
		bot_b.rng.state = bot_a.rng.state
		_play(a, bot_a, 500)
		_play(b, bot_b, 500)
		check(a.turn == b.turn and a.player.hp == b.player.hp and a.floor_num == b.floor_num,
			"loaded game continues identically (seed %d)" % s)

func test_illegal_actions() -> void:
	var g := Game.new(5, "guard")
	check(not g.act({"type": "descend"}), "cannot descend off the stairs")
	check(not g.act({"type": "use", "index": 99}), "cannot use a missing item")
	check(not g.act({"type": "move", "dir": Vector2i(2, 0)}), "cannot move two tiles")
	check(not g.act({"type": "ability", "target": Vector2i(0, 0)}), "ability needs a target")
	check(g.turn == 0, "illegal actions take no time")

func test_lantern() -> void:
	var g := Game.new(9, "guard")
	g.monsters.clear()
	var start_oil: int = g.oil
	for i in 10:
		g.act({"type": "wait"})
	check(g.oil == start_oil - 10, "oil burns one per turn")
	g.oil = 0
	var hp: int = g.player.hp
	for i in 10:
		g.act({"type": "wait"})
	check(g.player.hp == hp - 1, "darkness hurts every 10 turns")
	check(g.light_radius() == 1, "no oil means radius 1")
