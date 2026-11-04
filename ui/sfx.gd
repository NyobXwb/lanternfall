# Sound effects. Placeholder blips are synthesised at startup; when Kenney's
# audio packs are added, drop .ogg files at res://assets/sfx/<name>.ogg and
# they are used instead.
extends Node

const RATE := 22050
const SOUNDS := {
	# name: [start Hz, end Hz, seconds, wave, volume]
	"step": [180.0, 140.0, 0.04, "noise", 0.15],
	"hit": [300.0, 90.0, 0.10, "square", 0.35],
	"hurt": [160.0, 60.0, 0.18, "square", 0.45],
	"item": [600.0, 900.0, 0.08, "sine", 0.35],
	"ability": [200.0, 800.0, 0.20, "square", 0.3],
	"stairs": [400.0, 120.0, 0.35, "sine", 0.4],
	"level": [500.0, 1000.0, 0.30, "sine", 0.4],
	"death": [220.0, 40.0, 0.9, "square", 0.4],
	"win": [400.0, 1200.0, 0.8, "sine", 0.4],
	"scroll": [600.0, 900.0, 0.08, "sine", 0.35],
}
const MUSIC := {"title": "res://assets/music/title.ogg", "descent": "res://assets/music/descent.ogg", "deep": "res://assets/music/deep.ogg"}
const SETTINGS_PATH := "user://settings.json"

var music_player: AudioStreamPlayer
var current_track := ""
var music_on := true
var sfx_on := true

var streams := {}
var players: Array[AudioStreamPlayer] = []
var next := 0

func _ready() -> void:
	for n in SOUNDS:
		var path := "res://assets/sfx/%s.ogg" % n
		streams[n] = load(path) if ResourceLoader.exists(path) else _synth(SOUNDS[n])
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.volume_db = -4.0
		add_child(p)
		players.append(p)
	music_player = AudioStreamPlayer.new()
	music_player.volume_db = -12.0
	add_child(music_player)
	if FileAccess.file_exists(SETTINGS_PATH):
		var d = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
		if d is Dictionary:
			music_on = d.get("music", true)
			sfx_on = d.get("sfx", true)

func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"music": music_on, "sfx": sfx_on}))

func play_music(track: String) -> void:
	if track == current_track and music_player.playing:
		return
	current_track = track
	music_player.stop()
	if not music_on or not MUSIC.has(track) or not ResourceLoader.exists(MUSIC[track]):
		return
	var st = load(MUSIC[track])
	if st is AudioStreamOggVorbis:
		st.loop = true
	music_player.stream = st
	music_player.play()

func toggle_music() -> void:
	music_on = not music_on
	var t := current_track
	current_track = ""
	if music_on:
		play_music(t)
	else:
		music_player.stop()
		current_track = t
	save_settings()

func toggle_sfx() -> void:
	sfx_on = not sfx_on
	save_settings()

func play(n: String) -> void:
	if not sfx_on or not streams.has(n):
		return
	var p := players[next]
	next = (next + 1) % players.size()
	p.stream = streams[n]
	p.play()

func _synth(spec: Array) -> AudioStreamWAV:
	var f0: float = spec[0]
	var f1: float = spec[1]
	var dur: float = spec[2]
	var wave: String = spec[3]
	var vol: float = spec[4]
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var r := RandomNumberGenerator.new()
	r.seed = 7
	for i in n:
		var t := float(i) / n
		var f := lerpf(f0, f1, t)
		phase += f / RATE
		var s := 0.0
		match wave:
			"sine": s = sin(TAU * phase)
			"square": s = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
			"noise": s = r.randf_range(-1, 1)
		var env := minf(1.0, t * 20.0) * (1.0 - t)
		data.encode_s16(i * 2, int(clampf(s * env * vol, -1, 1) * 32767))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	return w
