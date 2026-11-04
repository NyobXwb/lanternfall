extends SceneTree
const Game = preload("res://core/game.gd")
const Bot = preload("res://bot/bot.gd")
func _init():
	var seed_ := int(OS.get_cmdline_user_args()[0])
	var g = Game.new(seed_, "guard"); var b = Bot.new("careful", seed_)
	var counts := {}; var per_floor := {}
	var n := 0
	while g.state == "playing" and n < 20000:
		var a = b.choose(g)
		var k: String = a.type
		if k == "wait":
			var vm = g.visible_monsters()
			k = "wait(" + ",".join(vm.map(func(m): return m.kind)) + ")"
		counts[k] = counts.get(k, 0) + 1
		per_floor[g.floor_num] = per_floor.get(g.floor_num, 0) + 1
		g.act(a); n += 1
	print(g.state, " ", g.death_cause, " floor ", g.floor_num)
	print(per_floor)
	var ks = counts.keys(); ks.sort_custom(func(x,y): return counts[x] > counts[y])
	for k in ks.slice(0, 10): print(k, " ", counts[k])
	quit()
