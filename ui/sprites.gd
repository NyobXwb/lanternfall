# Which cell of the tile sheet each sprite uses. To switch to Kenney's
# Tiny Dungeon sheet, point SHEET at it and update CELLS; nothing else changes.
extends RefCounted

const SHEET := "res://assets/placeholder_tiles.png"
const TILE := 16
const COLS := 8
const ORDER := [
	"floor", "wall", "stairs", "shrine", "floor_alt", "wall_top", "door", "bones",
	"guard", "cutpurse", "adept", "rat", "bat", "slime", "goblin", "archer",
	"spider", "orc", "wraith", "cultist", "golem", "shade", "mimic", "warden",
	"potion", "scroll", "weapon", "armor", "food", "oil", "bomb", "smoke",
]

static var _tex: Texture2D

static func texture() -> Texture2D:
	if _tex == null:
		_tex = load(SHEET)
	return _tex

static func region(sprite: String) -> Rect2:
	var i := ORDER.find(sprite)
	if i < 0:
		i = 0
	return Rect2((i % COLS) * TILE, (i / COLS) * TILE, TILE, TILE)

static func for_item(id: String) -> String:
	var Defs = load("res://data/defs.gd")
	var kind: String = Defs.ITEMS[id].kind
	return kind
