# Game data tables. Balance changes go here, not in code.
extends RefCounted

const MAP_W := 48
const MAP_H := 32
const LAST_FLOOR := 10
const SHRINE_FLOORS := [3, 6, 9]

const OIL_START := 300
const OIL_MAX := 400
const OIL_FLASK := 100
const DARK_DAMAGE_EVERY := 10

const INV_CAP := 16

# Player classes. dmg = weapon damage range without a weapon item.
const CLASSES := {
	"guard": {
		"name": "Warden's Guard", "hp": 24, "str": 1, "acc": 1, "eva": 0, "armor": 1,
		"weapon": "iron_blade", "kit": ["potion_heal"], "ability": "bash", "cooldown": 8,
	},
	"cutpurse": {
		"name": "Cutpurse", "hp": 26, "str": 0, "acc": 2, "eva": 3, "armor": 0,
		"weapon": "daggers", "kit": ["smoke_bomb", "smoke_bomb"], "ability": "backstab", "cooldown": 0,
	},
	"adept": {
		"name": "Ember Adept", "hp": 18, "str": 0, "acc": 0, "eva": 1, "armor": 0,
		"weapon": "staff", "kit": ["scroll_fire", "scroll_fire", "scroll_fire"], "ability": "firebolt", "cooldown": 4,
	},
}

# Monsters. ai: rush, erratic, split, ranged, web, drain, summon, slow, shade, mimic, boss
const MONSTERS := {
	"rat":      {"name": "rat", "hp": 5, "dmg": [1, 2], "acc": 0, "eva": 1, "armor": 0, "xp": 1, "floors": [1, 3], "ai": "rush"},
	"bat":      {"name": "bat", "hp": 4, "dmg": [1, 2], "acc": 0, "eva": 3, "armor": 0, "xp": 1, "floors": [1, 3], "ai": "erratic"},
	"slime":    {"name": "slime", "hp": 8, "dmg": [1, 3], "acc": -1, "eva": 0, "armor": 0, "xp": 2, "floors": [1, 3], "ai": "split"},
	"goblin":   {"name": "goblin", "hp": 9, "dmg": [2, 3], "acc": 1, "eva": 1, "armor": 0, "xp": 3, "floors": [3, 6], "ai": "rush", "pack": 3},
	"archer":   {"name": "skeleton archer", "hp": 7, "dmg": [2, 4], "acc": 0, "eva": 1, "armor": 1, "xp": 4, "floors": [3, 6], "ai": "ranged"},
	"spider":   {"name": "spider", "hp": 10, "dmg": [2, 4], "acc": 1, "eva": 2, "armor": 0, "xp": 4, "floors": [3, 6], "ai": "web"},
	"orc":      {"name": "orc brute", "hp": 18, "dmg": [3, 6], "acc": 1, "eva": 0, "armor": 1, "xp": 7, "floors": [5, 8], "ai": "rush"},
	"wraith":   {"name": "wraith", "hp": 14, "dmg": [2, 4], "acc": 2, "eva": 3, "armor": 0, "xp": 7, "floors": [5, 8], "ai": "drain"},
	"cultist":  {"name": "cultist", "hp": 12, "dmg": [2, 3], "acc": 1, "eva": 1, "armor": 0, "xp": 7, "floors": [5, 8], "ai": "summon"},
	"golem":    {"name": "golem", "hp": 34, "dmg": [5, 8], "acc": 1, "eva": -2, "armor": 3, "xp": 12, "floors": [7, 10], "ai": "slow"},
	"shade":    {"name": "shade", "hp": 16, "dmg": [3, 6], "acc": 3, "eva": 5, "armor": 0, "xp": 11, "floors": [7, 10], "ai": "shade"},
	"mimic":    {"name": "mimic", "hp": 22, "dmg": [4, 7], "acc": 2, "eva": 0, "armor": 1, "xp": 10, "floors": [7, 10], "ai": "mimic"},
	"warden":   {"name": "the Warden", "hp": 100, "dmg": [5, 9], "acc": 3, "eva": 2, "armor": 2, "xp": 0, "floors": [99, 99], "ai": "boss"},
}

# Items. kind: potion, scroll, weapon, armor, food, oil, bomb, smoke
# Potions and scrolls have hidden names per seed until identified.
const ITEMS := {
	"potion_heal":     {"name": "potion of healing", "kind": "potion", "weight": 10},
	"potion_strength": {"name": "potion of strength", "kind": "potion", "weight": 3},
	"potion_vigor":    {"name": "potion of vigor", "kind": "potion", "weight": 3},
	"potion_poison":   {"name": "potion of poison", "kind": "potion", "weight": 4},
	"scroll_fire":     {"name": "scroll of fire", "kind": "scroll", "weight": 5},
	"scroll_teleport": {"name": "scroll of teleport", "kind": "scroll", "weight": 4},
	"scroll_map":      {"name": "scroll of mapping", "kind": "scroll", "weight": 4},
	"scroll_light":    {"name": "scroll of light", "kind": "scroll", "weight": 4},
	"daggers":         {"name": "daggers", "kind": "weapon", "dmg": [2, 3], "acc": 1, "tier": 0, "weight": 0},
	"staff":           {"name": "staff", "kind": "weapon", "dmg": [1, 3], "acc": 0, "tier": 0, "weight": 0},
	"iron_blade":      {"name": "iron blade", "kind": "weapon", "dmg": [2, 4], "acc": 0, "tier": 1, "weight": 4},
	"steel_blade":     {"name": "steel blade", "kind": "weapon", "dmg": [3, 6], "acc": 0, "tier": 2, "weight": 3},
	"runed_blade":     {"name": "runed blade", "kind": "weapon", "dmg": [4, 8], "acc": 1, "tier": 3, "weight": 1},
	"leather":         {"name": "leather armor", "kind": "armor", "armor": 1, "eva": 0, "tier": 1, "weight": 4},
	"chainmail":       {"name": "chainmail", "kind": "armor", "armor": 2, "eva": 0, "tier": 2, "weight": 3},
	"plate":           {"name": "plate armor", "kind": "armor", "armor": 3, "eva": -1, "tier": 3, "weight": 1},
	"food":            {"name": "ration", "kind": "food", "weight": 8},
	"oil":             {"name": "oil flask", "kind": "oil", "weight": 0},
	"bomb":            {"name": "bomb", "kind": "bomb", "weight": 3},
	"smoke_bomb":      {"name": "smoke bomb", "kind": "smoke", "weight": 2},
}

const UNKNOWN_POTION_NAMES := ["murky", "violet", "amber", "glowing", "bubbling", "pale", "crimson", "inky"]
const UNKNOWN_SCROLL_NAMES := ["ZOT KEL", "AMU VAR", "IXIS", "HOLO MEN", "RA THUL", "VEX ORA", "NIM BU"]

const BLESSINGS := {
	"toughness": "+8 max HP",
	"precision": "+2 accuracy",
	"might": "+1 strength",
	"ironskin": "+1 armor",
	"thrift": "lantern burns 25% slower",
	"vampiric": "heal 2 HP on each kill",
}

const LEVEL_HP := 4
const MAX_LEVEL := 10

static func xp_for_level(level: int) -> int:
	# XP needed to reach `level` from level 1.
	return 5 * level * (level - 1)
