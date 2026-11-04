# Which cell of the tile sheet each sprite uses, plus an optional tint.
# Art: Kenney "Tiny Dungeon" (CC0), 12 columns of 16x16 tiles.
# The old generated sheet is kept at assets/placeholder_tiles.png.
extends RefCounted

const SHEET := "res://assets/kenney/tiny_dungeon.png"
const TILE := 16
const COLS := 12
const W := Color.WHITE

const CELLS := {
	"floor": [48, W], "floor_alt": [49, W], "wall": [57, Color(0.8, 0.8, 0.9)], "wall_top": [40, W],
	"stairs": [9, W], "shrine": [32, W], "door": [45, W], "bones": [24, W],
	"guard": [97, W], "cutpurse": [112, W], "adept": [84, W],
	"rat": [123, W], "bat": [120, W], "slime": [108, W], "goblin": [109, W], "archer": [100, W],
	"spider": [122, W], "orc": [110, W], "wraith": [121, Color(0.75, 0.8, 1.0)], "cultist": [111, W],
	"golem": [124, W], "shade": [121, Color(0.35, 0.25, 0.5)], "mimic": [92, W], "warden": [87, Color(1.0, 0.85, 0.5)],
	"chest": [89, W],
	"potion": [115, W], "scroll": [101, Color(1.0, 0.95, 0.8)], "weapon": [104, W], "armor": [102, W],
	"food": [66, W], "oil": [113, Color(1.0, 0.75, 0.3)], "bomb": [102, Color(0.3, 0.3, 0.35)], "smoke": [113, W],
}

static var _tex: Texture2D

static func texture() -> Texture2D:
	if _tex == null:
		_tex = load(SHEET)
	return _tex

static func region(sprite: String) -> Rect2:
	var i: int = CELLS.get(sprite, CELLS.floor)[0]
	return Rect2((i % COLS) * TILE, (i / COLS) * TILE, TILE, TILE)

static func tint(sprite: String) -> Color:
	return CELLS.get(sprite, CELLS.floor)[1]
