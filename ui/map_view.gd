# Draws the dungeon around the player, lit by the lantern.
extends Control

const Sprites = preload("res://ui/sprites.gd")
const MapGen = preload("res://core/map_gen.gd")
const Defs = preload("res://data/defs.gd")

const SCALE := 3
const CELL := 16 * SCALE

var game
var hover := Vector2i(-1, -1)
var flashes := {}      # Vector2i -> remaining seconds (hit flashes)

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP

func _process(delta: float) -> void:
	if flashes.is_empty():
		return
	for k in flashes.keys():
		flashes[k] -= delta
		if flashes[k] <= 0:
			flashes.erase(k)
	queue_redraw()

func flash(p: Vector2i) -> void:
	flashes[p] = 0.18
	queue_redraw()

# Top-left map cell shown, keeping the player centred but not scrolling past the edges.
func origin() -> Vector2i:
	var vw := int(size.x) / CELL
	var vh := int(size.y) / CELL
	var o: Vector2i = game.player.pos - Vector2i(vw / 2, vh / 2)
	o.x = clampi(o.x, 0, maxi(0, game.w - vw))
	o.y = clampi(o.y, 0, maxi(0, game.h - vh))
	return o

func cell_at(local: Vector2) -> Vector2i:
	return origin() + Vector2i(int(local.x) / CELL, int(local.y) / CELL)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.03))
	if game == null:
		return
	var tex := Sprites.texture()
	var o := origin()
	var vw := int(size.x) / CELL + 1
	var vh := int(size.y) / CELL + 1
	var r: int = game.light_radius()
	for y in range(o.y, mini(game.h, o.y + vh)):
		for x in range(o.x, mini(game.w, o.x + vw)):
			var p := Vector2i(x, y)
			if not game.is_seen(p):
				continue
			var lit: bool = game.visible.has(p)
			var tint: Color = _tint(p, r) if lit else Color(0.36, 0.36, 0.48)
			var dest := Rect2(Vector2(x - o.x, y - o.y) * CELL, Vector2(CELL, CELL))
			var t: int = game.tile(p)
			var spr := "floor"
			match t:
				MapGen.WALL: spr = "wall_top" if game.tile(p + Vector2i(0, 1)) != MapGen.WALL else "wall"
				MapGen.STAIRS: spr = "stairs"
				MapGen.SHRINE: spr = "shrine"
				_: spr = "floor_alt" if (x * 7 + y * 13) % 5 == 0 else "floor"
			draw_texture_rect_region(tex, dest, Sprites.region(spr), tint * Sprites.tint(spr))
			if game.floor_items.has(p):
				var id: String = game.floor_items[p][-1]
				var ispr: String = Defs.ITEMS[id].kind
				draw_texture_rect_region(tex, dest, Sprites.region(ispr), tint * Sprites.tint(ispr))
	# Monsters (only in light).
	for m in game.monsters:
		if not m.alive() or not game.visible.has(m.pos):
			continue
		var dest := Rect2(Vector2(m.pos - o) * CELL, Vector2(CELL, CELL))
		var spr: String = m.kind
		if m.ai == "mimic" and not m.aware:
			spr = "chest"
		draw_texture_rect_region(tex, dest, Sprites.region(spr), _tint(m.pos, r) * Sprites.tint(spr))
		if m.hp < m.max_hp:
			var frac: float = float(m.hp) / m.max_hp
			draw_rect(Rect2(dest.position + Vector2(4, -4), Vector2(CELL - 8, 4)), Color(0.2, 0, 0))
			draw_rect(Rect2(dest.position + Vector2(4, -4), Vector2((CELL - 8) * frac, 4)), Color(0.9, 0.2, 0.2))
		if m.stun > 0:
			draw_string(get_theme_default_font(), dest.position + Vector2(CELL - 14, 14), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.LIGHT_BLUE)
	# Player.
	var pd := Rect2(Vector2(game.player.pos - o) * CELL, Vector2(CELL, CELL))
	draw_texture_rect_region(tex, pd, Sprites.region(game.class_id), Color.WHITE)
	if game.player.root > 0:
		draw_rect(pd, Color(1, 1, 1, 0.25))
	for p in flashes:
		draw_rect(Rect2(Vector2(p - o) * CELL, Vector2(CELL, CELL)), Color(1, 0.3, 0.2, 0.45))
	if hover.x >= 0 and game.is_seen(hover):
		draw_rect(Rect2(Vector2(hover - o) * CELL, Vector2(CELL, CELL)), Color(1, 0.9, 0.5, 0.6), false, 2.0)

func _tint(p: Vector2i, r: int) -> Color:
	var d: float = Vector2(p - game.player.pos).length() / maxf(1.0, r + 0.5)
	var b := clampf(1.0 - 0.65 * d * d, 0.3, 1.0)
	return Color(1.0 * b, 0.88 * b, 0.68 * b)
