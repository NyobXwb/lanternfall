# Headless balance simulator.
#   godot --headless --path . -s tools/sim.gd -- --runs 200 --class guard --style careful --seed 1
extends SceneTree

const Game = preload("res://core/game.gd")
const Bot = preload("res://bot/bot.gd")
const MAX_ACTIONS := 20000

func _init() -> void:
	var args := _parse(OS.get_cmdline_user_args())
	var runs := int(args.get("runs", "200"))
	var first_seed := int(args.get("seed", "1"))
	var style: String = args.get("style", "careful")
	var classes: Array = [args["class"]] if args.has("class") else ["guard", "cutpurse", "adept"]
	var verbose := args.has("verbose")
	var t0 := Time.get_ticks_msec()
	for c in classes:
		var wins := 0
		var floors: Array[int] = []
		var turns: Array[int] = []
		var causes := {}
		var stuck := 0
		for i in runs:
			var s := first_seed + i
			var g := Game.new(s, c)
			var bot := Bot.new(style, s)
			var actions := 0
			var illegal := 0
			while g.state == "playing" and actions < MAX_ACTIONS:
				var a := bot.choose(g)
				if not g.act(a):
					illegal += 1
					g.act({"type": "wait"})
				actions += 1
			if g.state == "won":
				wins += 1
			elif g.state == "dead":
				causes[g.death_cause] = causes.get(g.death_cause, 0) + 1
			else:
				stuck += 1
			floors.append(g.floor_num)
			turns.append(g.turn)
			if verbose:
				print("%s seed=%d %s floor=%d turn=%d lvl=%d kills=%d cause=%s illegal=%d" % [c, s, g.state, g.floor_num, g.turn, g.level, g.stats.kills, g.death_cause, illegal])
		floors.sort()
		turns.sort()
		var hist := []
		for f in range(1, 11):
			hist.append(floors.count(f))
		var top := causes.keys()
		top.sort_custom(func(a, b): return causes[a] > causes[b])
		var top_s := []
		for k in top.slice(0, 5):
			top_s.append("%s %d" % [k, causes[k]])
		print("%-9s %s win %5.1f%%  median floor %d  median turns %d  stuck %d  floors %s  killers: %s" % [
			c, style, 100.0 * wins / runs, floors[runs / 2], turns[runs / 2], stuck, str(hist), ", ".join(top_s)])
	print("(%d ms)" % (Time.get_ticks_msec() - t0))
	quit()

func _parse(a: PackedStringArray) -> Dictionary:
	var out := {}
	var i := 0
	while i < a.size():
		if a[i].begins_with("--"):
			var k := a[i].substr(2)
			if i + 1 < a.size() and not a[i + 1].begins_with("--"):
				out[k] = a[i + 1]
				i += 1
			else:
				out[k] = "1"
		i += 1
	return out
