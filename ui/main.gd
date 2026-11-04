# Screens, HUD and input. All game rules live in core/game.gd.
extends Control

const Game = preload("res://core/game.gd")
const Bot = preload("res://bot/bot.gd")
const Defs = preload("res://data/defs.gd")
const Profile = preload("res://core/profile.gd")
const MapView = preload("res://ui/map_view.gd")
const Sprites = preload("res://ui/sprites.gd")
const Sfx = preload("res://ui/sfx.gd")

const COL_BG := Color(0.07, 0.06, 0.08)
const COL_PANEL := Color(0.12, 0.10, 0.12)
const COL_ACCENT := Color(1.0, 0.75, 0.35)
const COL_TEXT := Color(0.92, 0.88, 0.80)
const COL_DIM := Color(0.6, 0.56, 0.52)

const KEY_DIRS := {
	KEY_UP: Vector2i(0, -1), KEY_DOWN: Vector2i(0, 1), KEY_LEFT: Vector2i(-1, 0), KEY_RIGHT: Vector2i(1, 0),
	KEY_W: Vector2i(0, -1), KEY_S: Vector2i(0, 1), KEY_A: Vector2i(-1, 0), KEY_D: Vector2i(1, 0),
	KEY_Q: Vector2i(-1, -1), KEY_E: Vector2i(1, -1), KEY_Z: Vector2i(-1, 1), KEY_C: Vector2i(1, 1),
	KEY_KP_8: Vector2i(0, -1), KEY_KP_2: Vector2i(0, 1), KEY_KP_4: Vector2i(-1, 0), KEY_KP_6: Vector2i(1, 0),
	KEY_KP_7: Vector2i(-1, -1), KEY_KP_9: Vector2i(1, -1), KEY_KP_1: Vector2i(-1, 1), KEY_KP_3: Vector2i(1, 1),
	KEY_HOME: Vector2i(-1, -1), KEY_PAGEUP: Vector2i(1, -1), KEY_END: Vector2i(-1, 1), KEY_PAGEDOWN: Vector2i(1, 1),
}

var game
var daily_key := ""
var screen := "title"
var map_view
var side: VBoxContainer
var log_label: RichTextLabel
var overlay: Control
var travel_path_target := Vector2i(-1, -1)
var travel_timer := 0.0
var travel_bot
var sfx

func _ready() -> void:
	theme = _make_theme()
	sfx = Sfx.new()
	add_child(sfx)
	get_tree().set_auto_accept_quit(false)
	show_title()
	_dev_capture()

# Dev only: `-- --shot out.png --screen game --steps 300 --seed 5 --class guard`
# plays the bot for N actions, saves a screenshot and quits.
func _dev_capture() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--shot")
	if i < 0:
		return
	var opt := func(name: String, dflt: String) -> String:
		var j := args.find("--" + name)
		return args[j + 1] if j >= 0 and j + 1 < args.size() else dflt
	var which: String = opt.call("screen", "game")
	if which == "class":
		show_class_select(false)
	elif which == "game":
		game = Game.new(int(opt.call("seed", "5")), opt.call("class", "guard"))
		show_game()
		var bot := Bot.new("careful", game.seed_value)
		for n in int(opt.call("steps", "0")):
			if game.state != "playing":
				break
			if overlay != null:
				overlay.queue_free()
				overlay = null
			_do(bot.choose(game))
		_refresh()
	for f in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(args[i + 1])
	get_tree().quit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if screen == "game" and game != null and game.state == "playing":
			Profile.write_save(game, daily_key)
		get_tree().quit()

# ---------------------------------------------------------------- theme

func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 18
	var panel := StyleBoxFlat.new()
	panel.bg_color = COL_PANEL
	panel.set_corner_radius_all(4)
	panel.set_content_margin_all(12)
	t.set_stylebox("panel", "PanelContainer", panel)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var b := StyleBoxFlat.new()
		b.set_corner_radius_all(4)
		b.set_content_margin_all(10)
		match state:
			"normal": b.bg_color = Color(0.2, 0.16, 0.14)
			"hover": b.bg_color = Color(0.32, 0.24, 0.16)
			"pressed": b.bg_color = Color(0.45, 0.32, 0.18)
			"focus":
				b.bg_color = Color(0, 0, 0, 0)
				b.border_color = COL_ACCENT
				b.set_border_width_all(2)
			"disabled": b.bg_color = Color(0.12, 0.11, 0.11)
		t.set_stylebox(state, "Button", b)
	t.set_color("font_color", "Button", COL_TEXT)
	t.set_color("font_hover_color", "Button", COL_ACCENT)
	t.set_color("font_disabled_color", "Button", COL_DIM)
	t.set_color("font_color", "Label", COL_TEXT)
	t.set_color("default_color", "RichTextLabel", COL_TEXT)
	return t

func _clear() -> void:
	for c in get_children():
		if c != sfx:
			c.queue_free()
	overlay = null
	travel_path_target = Vector2i(-1, -1)

func _bg() -> void:
	var bg := ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

func _label(text: String, size_px: int = 18, color: Color = COL_TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	return l

func _button(text: String, cb: Callable, disabled := false) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = disabled
	b.pressed.connect(cb)
	b.custom_minimum_size = Vector2(320, 0)
	return b

func _centered_box() -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)
	return box

# ---------------------------------------------------------------- title

func show_title() -> void:
	screen = "title"
	_clear()
	_bg()
	var box := _centered_box()
	var title := _label("LANTERNFALL", 64, COL_ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := _label("Ten floors down. One lantern. Don't let it go out.", 20, COL_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	box.add_child(Control.new())
	var first: Button
	if Profile.has_save():
		first = _button("Continue run", _continue_run)
		box.add_child(first)
	var nb := _button("New run", func(): show_class_select(false))
	box.add_child(nb)
	var d := Profile.daily_seed()
	var prof := Profile.load_profile()
	var done_today: bool = prof.daily.has(d[0])
	box.add_child(_button("Daily run (%s)%s" % [d[0], " - done" if done_today else ""], func(): show_class_select(true), done_today))
	box.add_child(_button("Records", show_records))
	if OS.get_name() != "Web":
		box.add_child(_button("Quit", func(): get_tree().quit()))
	var stats := _label("Runs %d   Wins %d   Deepest floor %d" % [prof.runs, prof.wins, prof.best_floor], 16, COL_DIM)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(stats)
	(first if first else nb).grab_focus.call_deferred()

func show_records() -> void:
	screen = "records"
	_clear()
	_bg()
	var box := _centered_box()
	box.add_child(_label("Recent runs", 32, COL_ACCENT))
	var prof := Profile.load_profile()
	if prof.history.is_empty():
		box.add_child(_label("No runs yet.", 18, COL_DIM))
	for r in prof.history.slice(0, 12):
		var what: String = "Escaped!" if r.result == "won" else "Killed by %s" % r.cause
		box.add_child(_label("%s  %-15s floor %2d  %4d turns  %s" % [r.date, Defs.CLASSES[r["class"]].name, r.floor, r.turns, what], 16))
	var back := _button("Back", show_title)
	box.add_child(back)
	back.grab_focus.call_deferred()

func show_class_select(daily: bool) -> void:
	screen = "class"
	_clear()
	_bg()
	var box := _centered_box()
	box.add_child(_label("Choose your delver" + (" (daily run)" if daily else ""), 32, COL_ACCENT))
	var prof := Profile.load_profile()
	var first: Button
	for c in ["guard", "cutpurse", "adept"]:
		var d: Dictionary = Defs.CLASSES[c]
		var locked: bool = not c in prof.unlocked
		var desc: String = {
			"guard": "Sturdy. Shield Bash stuns a foe for 2 turns.",
			"cutpurse": "Quick. Triple damage on foes that haven't seen you.",
			"adept": "Fragile. Firebolt hits from range but burns lantern oil.",
		}[c]
		var text := "%s  (%d HP)\n%s" % [d.name, d.hp, desc]
		if locked:
			text = "%s  (locked)\nReach floor %d to unlock." % [d.name, Profile.UNLOCK_FLOOR[c]]
		var b := _button(text, func(): start_run(c, daily), locked)
		b.custom_minimum_size = Vector2(560, 0)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.icon = _sprite_icon(c)
		b.expand_icon = false
		box.add_child(b)
		if first == null and not locked:
			first = b
	box.add_child(_button("Back", show_title))
	first.grab_focus.call_deferred()

func _sprite_icon(sprite: String) -> Texture2D:
	var at := AtlasTexture.new()
	at.atlas = Sprites.texture()
	at.region = Sprites.region(sprite)
	var img := at.get_image()
	img.resize(48, 48, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)

# ---------------------------------------------------------------- run

func start_run(c: String, daily: bool) -> void:
	var s := randi() % 1000000000
	daily_key = ""
	if daily:
		var d := Profile.daily_seed()
		daily_key = d[0]
		s = d[1]
	Profile.delete_save()
	game = Game.new(s, c)
	show_game()

func _continue_run() -> void:
	var d = Profile.read_save()
	if d == null:
		show_title()
		return
	daily_key = d.get("daily_key", "")
	game = Game.from_dict(d)
	show_game()

func show_game() -> void:
	screen = "game"
	_clear()
	_bg()
	travel_bot = Bot.new("careful", game.seed_value)
	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 0)
	root.add_child(left)
	map_view = MapView.new()
	map_view.game = game
	map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_view.gui_input.connect(_on_map_input)
	map_view.mouse_exited.connect(func(): map_view.hover = Vector2i(-1, -1); map_view.queue_redraw())
	left.add_child(map_view)
	var log_panel := PanelContainer.new()
	log_panel.custom_minimum_size = Vector2(0, 150)
	left.add_child(log_panel)
	log_label = RichTextLabel.new()
	log_label.scroll_following = true
	log_label.add_theme_font_size_override("normal_font_size", 16)
	log_panel.add_child(log_label)
	var side_panel := PanelContainer.new()
	side_panel.custom_minimum_size = Vector2(330, 0)
	root.add_child(side_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side_panel.add_child(scroll)
	side = VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 6)
	scroll.add_child(side)
	game.changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	if screen != "game":
		return
	map_view.queue_redraw()
	_build_side()
	var lines: Array = game.messages.slice(-40)
	log_label.text = "\n".join(lines)
	if not game.pending.is_empty() and overlay == null:
		_show_choice()
	if game.state != "playing" and overlay == null:
		_end_run()

func _bar(label: String, value: int, max_value: int, color: Color) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.add_child(_label("%s  %d / %d" % [label, value, max_value], 16))
	var bar := ProgressBar.new()
	bar.max_value = max_value
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	var bgs := StyleBoxFlat.new()
	bgs.bg_color = Color(0.05, 0.04, 0.05)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", bgs)
	box.add_child(bar)
	return box

func _build_side() -> void:
	for c in side.get_children():
		c.queue_free()
	var g = game
	var cls: Dictionary = Defs.CLASSES[g.class_id]
	side.add_child(_label("%s   Lv %d" % [cls.name, g.level], 20, COL_ACCENT))
	side.add_child(_label("Floor %d of %d   Turn %d" % [g.floor_num, Defs.LAST_FLOOR, g.turn], 16, COL_DIM))
	side.add_child(_bar("Health", maxi(0, g.player.hp), g.player.max_hp, Color(0.8, 0.2, 0.2)))
	side.add_child(_bar("Lantern oil", g.oil, Defs.OIL_MAX, Color(0.95, 0.7, 0.2)))
	var next_xp := Defs.xp_for_level(g.level + 1)
	side.add_child(_label("XP %d / %d" % [g.player.xp, next_xp] if g.level < Defs.MAX_LEVEL else "XP max", 16, COL_DIM))
	var wd: Dictionary = g.weapon_stats()
	side.add_child(_label("Str +%d  Acc %d  Eva %d  Armor %d" % [g.player.str_bonus, g.total_acc(), g.total_eva(), g.total_armor()], 16))
	side.add_child(_label("Weapon: %s (%d-%d)" % [wd.name, wd.dmg[0], wd.dmg[1]], 16))
	side.add_child(_label("Armor: %s" % (Defs.ITEMS[g.body_armor].name if g.body_armor != "" else "none"), 16))
	var ab: String = cls.ability
	if ab != "backstab":
		var ready_text := "ready (F)" if g.player.cooldown == 0 else "%d turns" % g.player.cooldown
		side.add_child(_label("%s: %s" % [{"bash": "Shield Bash", "firebolt": "Firebolt"}[ab], ready_text], 16, COL_ACCENT if g.player.cooldown == 0 else COL_DIM))
	else:
		side.add_child(_label("Backstab: x3 on unaware foes", 16, COL_DIM))
	if not g.blessings.is_empty():
		side.add_child(_label("Blessings: " + ", ".join(g.blessings), 14, Color(0.6, 0.8, 1)))
	side.add_child(HSeparator.new())
	side.add_child(_label("Pack (%d/%d) - click or press 1-9, 0" % [g.inventory.size(), Defs.INV_CAP], 14, COL_DIM))
	for i in g.inventory.size():
		var id: String = g.inventory[i]
		var key := str((i + 1) % 10) if i < 10 else " "
		var b := Button.new()
		b.text = "%s  %s" % [key, g.item_name(id)]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 15)
		b.icon = _sprite_icon_small(Defs.ITEMS[id].kind)
		b.pressed.connect(func(): _use_item(i))
		side.add_child(b)
	side.add_child(HSeparator.new())
	side.add_child(_label("Move: arrows / WASD + QEZC / numpad\nSpace wait   Enter descend   F ability\nClick a tile to walk there   Esc save & quit", 13, COL_DIM))

var _icon_cache := {}
func _sprite_icon_small(sprite: String) -> Texture2D:
	if not _icon_cache.has(sprite):
		var at := AtlasTexture.new()
		at.atlas = Sprites.texture()
		at.region = Sprites.region(sprite)
		var img := at.get_image()
		img.resize(32, 32, Image.INTERPOLATE_NEAREST)
		_icon_cache[sprite] = ImageTexture.create_from_image(img)
	return _icon_cache[sprite]

# ---------------------------------------------------------------- actions

func _do(a: Dictionary) -> bool:
	var before_hp: int = game.player.hp
	var before_floor: int = game.floor_num
	var mons := {}
	for m in game.monsters:
		mons[m] = m.hp
	var ok: bool = game.act(a)
	if not ok:
		return false
	for m in mons:
		if m.hp < mons[m]:
			map_view.flash(m.pos)
			sfx.play("hit")
	if game.player.hp < before_hp:
		map_view.flash(game.player.pos)
		sfx.play("hurt")
	if game.floor_num != before_floor:
		sfx.play("stairs")
	elif a.type == "move" and mons.is_empty():
		sfx.play("step")
	return true

func _use_item(i: int) -> void:
	if screen != "game" or overlay != null or i >= game.inventory.size():
		return
	var id: String = game.inventory[i]
	var a := {"type": "use", "index": i}
	if Defs.ITEMS[id].kind == "bomb":
		var t = _nearest_target(2, 5)
		if t == null:
			game.msg("No target in range for the bomb.")
			_refresh()
			return
		a["target"] = t.pos
	sfx.play("item")
	_do(a)

func _nearest_target(min_d: int, max_d: int):
	var best = null
	for m in game.visible_monsters():
		var d: int = game.cheb(m.pos, game.player.pos)
		if d >= min_d and d <= max_d and game.line_of_sight(game.player.pos, m.pos):
			if best == null or d < game.cheb(best.pos, game.player.pos):
				best = m
	return best

func _ability() -> void:
	var ab: String = Defs.CLASSES[game.class_id].ability
	if ab == "backstab":
		game.msg("Backstab works on its own: strike foes that haven't noticed you.")
		_refresh()
		return
	if not game.ability_ready():
		game.msg("Not ready yet.")
		_refresh()
		return
	var t = _nearest_target(1, 1 if ab == "bash" else 5)
	if t == null:
		game.msg("No target in range.")
		_refresh()
		return
	sfx.play("ability")
	_do({"type": "ability", "target": t.pos})

func _unhandled_input(event: InputEvent) -> void:
	if screen == "end" and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		show_title()
		return
	if screen != "game" or not (event is InputEventKey) or not event.pressed:
		return
	if overlay != null:
		if event.keycode >= KEY_1 and event.keycode <= KEY_3 and not game.pending.is_empty():
			_pick(event.keycode - KEY_1)
		return
	travel_path_target = Vector2i(-1, -1)
	var k: int = event.keycode
	if k == KEY_ESCAPE:
		Profile.write_save(game, daily_key)
		show_title()
	elif KEY_DIRS.has(k):
		_do({"type": "move", "dir": KEY_DIRS[k]})
	elif k == KEY_SPACE or k == KEY_PERIOD or k == KEY_KP_5:
		_do({"type": "wait"})
	elif k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_GREATER:
		if not _do({"type": "descend"}):
			game.msg("There are no stairs here.")
			_refresh()
	elif k == KEY_F:
		_ability()
	elif k >= KEY_0 and k <= KEY_9:
		var idx := 9 if k == KEY_0 else k - KEY_1
		_use_item(idx)
	get_viewport().set_input_as_handled()

func _on_map_input(event: InputEvent) -> void:
	if game == null or overlay != null:
		return
	if event is InputEventMouseMotion:
		var c: Vector2i = map_view.cell_at(event.position)
		if c != map_view.hover:
			map_view.hover = c
			map_view.queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var c: Vector2i = map_view.cell_at(event.position)
		var d: Vector2i = c - game.player.pos
		if c == game.player.pos:
			if not _do({"type": "descend"}):
				_do({"type": "wait"})
		elif absi(d.x) <= 1 and absi(d.y) <= 1:
			_do({"type": "move", "dir": d})
		elif game.is_seen(c) and game.passable(c):
			travel_path_target = c
			travel_timer = 0.0

func _process(delta: float) -> void:
	if screen != "game" or travel_path_target.x < 0 or overlay != null:
		return
	travel_timer -= delta
	if travel_timer > 0:
		return
	travel_timer = 0.06
	# Stop walking as soon as anything hostile is in view.
	for m in game.visible_monsters():
		if m.aware or game.cheb(m.pos, game.player.pos) <= 4:
			travel_path_target = Vector2i(-1, -1)
			return
	var step: Dictionary = travel_bot._path_to(game, travel_path_target)
	if step.is_empty() or not _do(step) or game.player.pos == travel_path_target:
		travel_path_target = Vector2i(-1, -1)

# ---------------------------------------------------------------- overlays

func _modal(title: String) -> VBoxContainer:
	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(_label(title, 28, COL_ACCENT))
	return box

func _show_choice() -> void:
	var p: Dictionary = game.pending[0]
	var box := _modal("Level up! Choose a boost." if p.type == "levelup" else "The shrine offers a blessing.")
	sfx.play("level")
	var first: Button
	for i in p.options.size():
		var o: String = p.options[i]
		var text: String
		if p.type == "levelup":
			text = {"str": "+1 Strength (more damage)", "acc": "+1 Accuracy (hit more often)", "eva": "+1 Evasion (get hit less)"}[o]
		else:
			text = "%s: %s" % [o.capitalize(), Defs.BLESSINGS[o]]
		var b := _button("%d  %s" % [i + 1, text], func(): _pick(i))
		box.add_child(b)
		if first == null:
			first = b
	first.grab_focus.call_deferred()

func _pick(i: int) -> void:
	if overlay:
		overlay.queue_free()
		overlay = null
	game.act({"type": "choose", "index": i})

func _end_run() -> void:
	var won: bool = game.state == "won"
	sfx.play("win" if won else "death")
	var unlocked := Profile.record_run(game, daily_key)
	var box := _modal("You escaped the depths!" if won else "Your light goes out.")
	screen = "end"
	if not won:
		box.add_child(_label("Killed by %s on floor %d." % [game.death_cause, game.floor_num]))
	box.add_child(_label("%s, level %d.  %d turns, %d kills." % [Defs.CLASSES[game.class_id].name, game.level, game.turn, game.stats.kills]))
	box.add_child(_label("Seed %d" % game.seed_value, 14, COL_DIM))
	for c in unlocked:
		box.add_child(_label("Unlocked: %s!" % Defs.CLASSES[c].name, 20, Color(0.6, 1, 0.6)))
	var again := _button("New run", func(): show_class_select(false))
	box.add_child(again)
	box.add_child(_button("Title screen", show_title))
	again.grab_focus.call_deferred()
