# Rooms-and-corridors floor generator. Pure data, seeded.
extends RefCounted

const Defs = preload("res://data/defs.gd")

const WALL := 0
const FLOOR := 1
const STAIRS := 2
const SHRINE := 3

# Returns {tiles: PackedByteArray, rooms: Array[Rect2i], start: Vector2i, stairs: Vector2i}
static func generate(rng: RandomNumberGenerator, floor_num: int) -> Dictionary:
	var w := Defs.MAP_W
	var h := Defs.MAP_H
	var tiles := PackedByteArray()
	tiles.resize(w * h)
	tiles.fill(WALL)
	var rooms: Array[Rect2i] = []
	var want := rng.randi_range(6, 10)
	var tries := 0
	while rooms.size() < want and tries < 400:
		tries += 1
		var rw := rng.randi_range(4, 10)
		var rh := rng.randi_range(4, 7)
		var rx := rng.randi_range(1, w - rw - 2)
		var ry := rng.randi_range(1, h - rh - 2)
		var r := Rect2i(rx, ry, rw, rh)
		var ok := true
		for o in rooms:
			if r.grow(2).intersects(o):
				ok = false
				break
		if ok:
			rooms.append(r)
	# Sort rooms left to right so corridors don't criss-cross too much.
	rooms.sort_custom(func(a, b): return a.position.x < b.position.x)
	for r in rooms:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				tiles[y * w + x] = FLOOR
	for i in range(1, rooms.size()):
		_corridor(tiles, w, _center(rooms[i - 1]), _center(rooms[i]), rng)
	# A couple of extra loops make the map less linear.
	for i in rng.randi_range(1, 2):
		var a := rooms[rng.randi_range(0, rooms.size() - 1)]
		var b := rooms[rng.randi_range(0, rooms.size() - 1)]
		if a != b:
			_corridor(tiles, w, _center(a), _center(b), rng)
	var start := _center(rooms[0])
	# Stairs go in the room farthest (by walk) from the start.
	var dist := bfs(tiles, w, h, start)
	var best := 0
	var best_d := -1
	for i in rooms.size():
		var c := _center(rooms[i])
		var d: int = dist[c.y * w + c.x]
		if d > best_d:
			best_d = d
			best = i
	var stairs := _center(rooms[best])
	if floor_num < Defs.LAST_FLOOR:
		tiles[stairs.y * w + stairs.x] = STAIRS
	var shrine := Vector2i(-1, -1)
	if floor_num in Defs.SHRINE_FLOORS and rooms.size() > 2:
		var mid := rooms[rng.randi_range(1, rooms.size() - 1)]
		if mid == rooms[best]:
			mid = rooms[1] if best != 1 else rooms[2]
		shrine = Vector2i(mid.position.x + 1, mid.position.y + 1)
		tiles[shrine.y * w + shrine.x] = SHRINE
	return {"tiles": tiles, "rooms": rooms, "start": start, "stairs": stairs, "stairs_room": best, "shrine": shrine}

static func _center(r: Rect2i) -> Vector2i:
	return Vector2i(r.position.x + r.size.x / 2, r.position.y + r.size.y / 2)

static func _corridor(tiles: PackedByteArray, w: int, a: Vector2i, b: Vector2i, rng: RandomNumberGenerator) -> void:
	var p := a
	var horizontal_first := rng.randf() < 0.5
	if horizontal_first:
		while p.x != b.x:
			p.x += signi(b.x - p.x)
			if tiles[p.y * w + p.x] == WALL:
				tiles[p.y * w + p.x] = FLOOR
	while p.y != b.y:
		p.y += signi(b.y - p.y)
		if tiles[p.y * w + p.x] == WALL:
			tiles[p.y * w + p.x] = FLOOR
	while p.x != b.x:
		p.x += signi(b.x - p.x)
		if tiles[p.y * w + p.x] == WALL:
			tiles[p.y * w + p.x] = FLOOR

# 8-way BFS distance map over passable tiles. Unreachable = -1.
# The map border is always wall, so neighbours never leave the grid.
static func bfs(tiles: PackedByteArray, w: int, h: int, from: Vector2i) -> PackedInt32Array:
	var n := w * h
	var dist := PackedInt32Array()
	dist.resize(n)
	dist.fill(-1)
	var queue := PackedInt32Array()
	queue.resize(n)
	var start := from.y * w + from.x
	dist[start] = 0
	queue[0] = start
	var head := 0
	var tail := 1
	var offs := PackedInt32Array([-w - 1, -w, -w + 1, -1, 1, w - 1, w, w + 1])
	while head < tail:
		var i := queue[head]
		head += 1
		var d := dist[i] + 1
		for o in offs:
			var j := i + o
			if dist[j] == -1 and tiles[j] != WALL:
				dist[j] = d
				queue[tail] = j
				tail += 1
	return dist
