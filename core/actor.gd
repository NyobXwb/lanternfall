# A creature on the map: the player or a monster.
extends RefCounted

var kind := ""
var name := ""
var pos := Vector2i.ZERO
var hp := 1
var max_hp := 1
var str_bonus := 0
var acc := 0
var eva := 0
var armor := 0
var dmg := [1, 2]
var ai := "rush"
var xp := 0
var is_player := false
var aware := false
var stun := 0
var root := 0
var cooldown := 0
var gen := 0          # slime split generation
var timer := 0        # summon / web timer
var phase := 1        # boss phase
var summons := 0

func alive() -> bool:
	return hp > 0
