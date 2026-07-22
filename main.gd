extends Node2D

const W := 1000.0
const H := 800.0
const HUD := 72.0
var CELL := 70.0
var COLS := 11
var ROWS := 7
var OX := 115.0
var OY := 129.0
const TANK_R := 12.0
const TANK_WIDTH := 20.0
const TANK_LENGTH := 28.0
const MUZZLE_OFFSET := TANK_LENGTH / 2.0 + 2.0
const WALL_T := 6.0
const BULLET_R := 2.5
const PORTRAIT_YUZU: Texture2D = preload("res://assets/characters/yuzu.png")
const PORTRAIT_MIDORI: Texture2D = preload("res://assets/characters/midori.png")
const PORTRAIT_MOMOI: Texture2D = preload("res://assets/characters/momoi.png")
const PORTRAIT_ALICE: Texture2D = preload("res://assets/characters/alice.png")
const PORTRAIT_KEI: Texture2D = preload("res://assets/characters/kei.png")
const PORTRAIT_YUUKA: Texture2D = preload("res://assets/characters/yuuka.png")
const SOUND_MOMOI_DEFEAT: AudioStream = preload("res://assets/sfx/momoi_defeat.ogg")
const IMPORTED_MUSIC_PATHS := [
	"res://assets/music/constant_moderato.ogg", "res://assets/music/midnight_trip.ogg",
	"res://assets/music/midsummer_cat.ogg", "res://assets/music/lovely_picnic.ogg",
	"res://assets/music/colorful_mess.ogg", "res://assets/music/shooting_stars.ogg",
	"res://assets/music/morose_dreamer.ogg", "res://assets/music/aira.ogg",
	"res://assets/music/sugar_story.ogg", "res://assets/music/hifumi_daisuki.ogg",
	"res://assets/music/coffee_cats.ogg", "res://assets/music/step_by_step.ogg",
	"res://assets/music/lemonade_diary.ogg", "res://assets/music/vibes.ogg",
	"res://assets/music/future_bossa.ogg", "res://assets/music/walkthrough.ogg",
	"res://assets/music/irasshaimase.ogg", "res://assets/music/daily_routine_247.ogg",
	"res://assets/music/pixel_time.ogg", "res://assets/music/black_suit.ogg",
	"res://assets/music/moment.ogg"
]
const SAVE_PATH := "user://progress.cfg"

var walls: Array[Rect2] = []
var prediction_mask := PackedByteArray()
const MASK_SCALE := 3.0
var mask_width := 334
var mask_height := 267
var mask_origin := Vector2.ZERO
var tanks: Array[Dictionary] = []
var bullets: Array[Dictionary] = []
var laser_beams: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var pickup_timer := 0.0
var scores := [0, 0]
var mode := 0 # 0 menu, 1 department challenge, 2 local two-player, 3 boss
var round_over := false
var paused := false
var round_message := ""
var mobile := false
var touch_move := Vector2.ZERO
var move_touch_id := -1
var fire_touch_id := -1
var mouse_joystick_active := false
var next_round_timer := 0.0
var countdown := 0.0
var particles: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var ai_count := 1
var squad_clock := 0.0
var squad_phase := 0
var sound_shoot: AudioStreamWAV
var sound_bounce: AudioStreamWAV
var sound_explode: AudioStreamWAV
var sound_pickup: AudioStreamWAV
var sound_click: AudioStreamWAV
var music_player: AudioStreamPlayer
var intro_player: VideoStreamPlayer
var intro_backdrop: ColorRect
var intro_playing := true
var energy_saver_enabled := false
var ai_danger_interval := 0.09
var ai_evade_directions := 16
var ai_evade_steps := 60
var ai_danger_budget := 1
var ai_bank_budget := 1
var p1_character := 0
var p2_character := 1
var boss_character_unlocked := false
var local_setup_open := false
var settings_open := false
var pause_settings_open := false
var dark_mode := false
var master_volume := 0.8
var sfx_volume := 0.85
var music_volume := 0.35
var music_index := 17
const MUSIC_NAMES := ["晨间出击", "纸箱潜行", "开发部进行曲", "紫电决战", "夏日追逐", "胜利返航",
	"Constant Moderato", "Midnight Trip", "Midsummer Cat", "Lovely Picnic", "Colorful Mess",
	"Shooting Stars", "Morose Dreamer", "Aira", "Sugar Story", "Hifumi Daisuki", "Coffee Cats",
	"Step by Step", "Lemonade Diary", "Vibes", "Future Bossa", "Walkthrough", "Irasshaimase",
	"Daily Routine 247", "Pixel Time", "Black Suit", "Moment"]
var music_picker_open := false
var music_scroll := 0.0
var music_picker_touch_id := -1
var music_picker_touch_start := Vector2.ZERO
var music_picker_touch_moved := false
var touch_height_index := 1
var touch_spacing_index := 1
var p2_touch_move := Vector2.ZERO
var p2_move_touch_id := -1
var p2_fire_touch_id := -1
var settings_slider_drag := -1
var settings_slider_touch_id := -1
var suppress_space_fire := false

func _ready() -> void:
	rng.randomize()
	mobile = OS.has_feature("mobile")
	load_progress()
	refresh_power_profile()
	sound_shoot = make_sound(155.0, 0.12, 0.30, true)
	sound_bounce = make_sound(620.0, 0.075, 0.13, false)
	sound_explode = make_sound(68.0, 0.34, 0.38, true)
	sound_pickup = make_sound(680.0, 0.16, 0.20, false)
	sound_click = make_sound(420.0, 0.080, 0.14, false)
	music_player = AudioStreamPlayer.new()
	music_player.stream = get_music_track(music_index)
	add_child(music_player)
	apply_audio_levels()
	set_process(true)
	start_intro()
	queue_redraw()

func start_intro() -> void:
	intro_backdrop = ColorRect.new()
	intro_backdrop.color = Color.BLACK
	intro_backdrop.position = Vector2.ZERO
	intro_backdrop.size = get_viewport_rect().size
	intro_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_backdrop.z_index = 999
	add_child(intro_backdrop)
	intro_player = VideoStreamPlayer.new()
	intro_player.stream = load("res://assets/intro/startup.ogv")
	if intro_player.stream == null:
		finish_intro()
		return
	intro_player.position = view_offset()
	intro_player.size = Vector2(W, H)
	intro_player.expand = true
	intro_player.volume_db = -80.0
	intro_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_player.z_index = 1000
	add_child(intro_player)
	intro_player.finished.connect(finish_intro)
	intro_player.play()

func finish_intro() -> void:
	intro_playing = false
	if intro_player != null and is_instance_valid(intro_player): intro_player.queue_free()
	if intro_backdrop != null and is_instance_valid(intro_backdrop): intro_backdrop.queue_free()
	if music_player != null and not music_player.playing: music_player.play()
	queue_redraw()

func load_progress() -> void:
	var save := ConfigFile.new()
	if save.load(SAVE_PATH) == OK:
		var legacy_boss_unlock := bool(save.get_value("unlocks", "alice_terror", false))
		boss_character_unlocked = bool(save.get_value("unlocks", "yuuka", legacy_boss_unlock))
		dark_mode = bool(save.get_value("appearance", "dark_mode", false))
		master_volume = clampf(float(save.get_value("audio", "master", 0.8)), 0.0, 1.0)
		sfx_volume = clampf(float(save.get_value("audio", "sfx", 0.85)), 0.0, 1.0)
		music_volume = clampf(float(save.get_value("audio", "music", 0.35)), 0.0, 1.0)
		music_index = clampi(int(save.get_value("audio", "track", 17)), 0, MUSIC_NAMES.size() - 1)
		touch_height_index = clampi(int(save.get_value("touch", "height", 1)), 0, 2)
		touch_spacing_index = clampi(int(save.get_value("touch", "spacing", 1)), 0, 2)

func save_progress() -> void:
	var save := ConfigFile.new()
	save.set_value("unlocks", "yuuka", boss_character_unlocked)
	save.set_value("appearance", "dark_mode", dark_mode)
	save.set_value("audio", "master", master_volume)
	save.set_value("audio", "sfx", sfx_volume)
	save.set_value("audio", "music", music_volume)
	save.set_value("audio", "track", music_index)
	save.set_value("touch", "height", touch_height_index)
	save.set_value("touch", "spacing", touch_spacing_index)
	var _save_error := save.save(SAVE_PATH)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Keep Android Back inside the game and open the in-game settings panel.
		if intro_playing:
			finish_intro()
		elif music_picker_open:
			music_picker_open = false
			queue_redraw()
		elif settings_open:
			settings_open = false
			queue_redraw()
		elif mode > 0:
			paused = true
			pause_settings_open = true
			queue_redraw()
		return
	# Recheck after the player returns from Windows Settings. Avoid polling and
	# process spawning during a match.
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and is_node_ready():
		refresh_power_profile()

func refresh_power_profile() -> void:
	var saver := false
	if OS.get_name() == "Windows":
		var output: Array = []
		var script := "Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public static class PowerStatus { [StructLayout(LayoutKind.Sequential)] public struct Status { public byte AC; public byte BatteryFlag; public byte BatteryPercent; public byte Saver; public uint Life; public uint Full; } [DllImport(\"kernel32.dll\")] public static extern bool GetSystemPowerStatus(out Status s); }'; $s=New-Object PowerStatus+Status; [PowerStatus]::GetSystemPowerStatus([ref]$s)|Out-Null; Write-Output $s.Saver"
		var exit_code := OS.execute("powershell.exe", PackedStringArray(["-NoProfile", "-NonInteractive", "-Command", script]), output, true, false)
		if exit_code == 0 and not output.is_empty(): saver = str(output[0]).strip_edges().begins_with("1")
	else:
		# Mobile builds always use the efficient profile; Godot 4.7 does not expose
		# a portable battery-saver flag for every phone platform.
		saver = OS.has_feature("mobile")
	energy_saver_enabled = saver
	ai_danger_interval = 0.15 if saver else 0.12
	ai_evade_directions = 8 if saver else 10
	ai_evade_steps = 24 if saver else 32

func make_sound(frequency: float, duration: float, volume: float, noisy: bool) -> AudioStreamWAV:
	var rate := 22050
	var count := int(duration * rate)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in count:
		var time := float(i) / float(rate)
		var progress := float(i) / float(count)
		var envelope := minf(1.0, progress * 45.0) * pow(1.0 - progress, 1.15)
		var wave := sin(TAU * frequency * time) * 0.78 + sin(TAU * frequency * 2.0 * time) * 0.14 + sin(TAU * frequency * 0.5 * time) * 0.08
		if noisy: wave = wave * 0.90 + rng.randf_range(-1.0, 1.0) * 0.10
		bytes.encode_s16(i * 2, int(clampf(wave * envelope * volume, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = bytes
	return stream

func make_music(track := 0) -> AudioStreamWAV:
	var rate := 22050
	var melodies := [
		[261.63, 329.63, 392.0, 523.25, 440.0, 392.0, 329.63, 293.66, 349.23, 440.0, 523.25, 659.25, 523.25, 440.0, 392.0, 329.63],
		[220.0, 0.0, 261.63, 293.66, 329.63, 0.0, 293.66, 246.94, 196.0, 0.0, 220.0, 261.63, 246.94, 220.0, 196.0, 0.0],
		[329.63, 392.0, 493.88, 392.0, 587.33, 493.88, 392.0, 329.63, 349.23, 440.0, 523.25, 440.0, 659.25, 523.25, 440.0, 392.0],
		[146.83, 174.61, 146.83, 220.0, 138.59, 164.81, 207.65, 174.61, 130.81, 155.56, 130.81, 196.0, 123.47, 146.83, 185.0, 155.56],
		[392.0, 440.0, 523.25, 659.25, 587.33, 523.25, 440.0, 392.0, 493.88, 587.33, 698.46, 783.99, 698.46, 587.33, 523.25, 440.0],
		[261.63, 392.0, 329.63, 523.25, 440.0, 659.25, 523.25, 783.99, 659.25, 523.25, 440.0, 392.0, 349.23, 329.63, 293.66, 261.63]
	]
	var steps := [0.42, 0.58, 0.30, 0.48, 0.34, 0.40]
	var safe_track := clampi(track, 0, melodies.size() - 1)
	var notes: Array = melodies[safe_track]
	var step_duration: float = steps[safe_track]
	var duration := float(notes.size()) * step_duration
	var count := int(duration * rate)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in count:
		var time := float(i) / float(rate)
		var note_index := mini(notes.size() - 1, int(time / step_duration))
		var note_time := fmod(time, step_duration)
		var envelope := minf(1.0, note_time * 15.0) * clampf((step_duration - note_time) * 4.5, 0.0, 1.0)
		var frequency := float(notes[note_index])
		var base_wave := sin(TAU * frequency * time)
		if safe_track == 1: base_wave = sin(TAU * frequency * time) * 0.78 + sin(TAU * frequency * 2.0 * time) * 0.12
		elif safe_track == 2: base_wave = signf(sin(TAU * frequency * time)) * 0.46 + sin(TAU * frequency * 2.0 * time) * 0.22
		elif safe_track == 3: base_wave = sin(TAU * frequency * time) * 0.68 + signf(sin(TAU * frequency * 0.5 * time)) * 0.18
		elif safe_track == 4: base_wave = sin(TAU * frequency * time) * 0.70 + sin(TAU * frequency * 1.5 * time) * 0.20
		elif safe_track == 5: base_wave = sin(TAU * frequency * time) * 0.74 + sin(TAU * frequency * 3.0 * time) * 0.12
		var melody := base_wave * (0.082 if safe_track == 3 else 0.095)
		var bass_root := frequency * (0.25 if safe_track == 3 else 0.5)
		var bass := sin(TAU * bass_root * time) * (0.07 if safe_track == 3 else 0.045)
		var beat_interval := 0.24 if safe_track in [2, 4] else 0.48
		var beat_time := fmod(time, beat_interval)
		var beat := sin(TAU * (62.0 - beat_time * 65.0) * beat_time) * exp(-beat_time * 20.0) * (0.030 if safe_track != 1 else 0.012)
		bytes.encode_s16(i * 2, int(clampf((melody + bass) * envelope + beat, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = bytes
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = count
	return stream

func select_music(direction: int) -> void:
	music_index = posmod(music_index + direction, MUSIC_NAMES.size())
	if music_player != null:
		music_player.stop()
		music_player.stream = get_music_track(music_index)
		music_player.play()
	apply_audio_levels()
	save_progress()

func get_music_track(index: int) -> AudioStream:
	if index < 6: return make_music(index)
	var path_index := clampi(index - 6, 0, IMPORTED_MUSIC_PATHS.size() - 1)
	var stream := load(IMPORTED_MUSIC_PATHS[path_index]) as AudioStream
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	return stream

func choose_music(index: int) -> void:
	music_index = clampi(index, 0, MUSIC_NAMES.size() - 1)
	if music_player != null:
		music_player.stop()
		music_player.stream = get_music_track(music_index)
		music_player.play()
	apply_audio_levels()
	save_progress()

func apply_audio_levels() -> void:
	if music_player != null:
		music_player.volume_db = linear_to_db(maxf(0.0001, master_volume * music_volume))

func play_sound(stream: AudioStream, pitch := 1.0, gain_multiplier := 1.0) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.pitch_scale = pitch
	player.volume_db = linear_to_db(maxf(0.0001, master_volume * sfx_volume * gain_multiplier)) - 3.0
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func tank(pos: Vector2, angle: float, color: Color, name: String, portrait: Texture2D = null) -> Dictionary:
	return {"pos": pos, "angle": angle, "color": color, "name": name,
		"alive": true, "cooldown": 0.0, "ai_path": [], "ai_timer": 0.0,
		"danger_timer": 0.0, "danger_velocity": Vector2.ZERO,
		"attack_angle": NAN, "role": 0, "weapon": "normal", "ammo": 0,
		"burst_remaining": 0, "burst_timer": 0.0,
		"portrait": portrait, "boss": false, "hp": 1, "max_hp": 1}

func character_data(index: int) -> Dictionary:
	var names := ["才羽绿", "柚子", "才羽桃井", "爱丽丝", "凯伊", "优香"]
	var colors := [Color("46e6a7"), Color("ef476f"), Color("f78c2b"), Color("3979f6"), Color("f4f4f4"), Color("8e44d6")]
	var portraits := [PORTRAIT_MIDORI, PORTRAIT_YUZU, PORTRAIT_MOMOI, PORTRAIT_ALICE, PORTRAIT_KEI, PORTRAIT_YUUKA]
	var safe_index := posmod(index, names.size())
	return {"name": names[safe_index], "color": colors[safe_index], "portrait": portraits[safe_index]}

func selectable_character_count() -> int:
	return 6 if boss_character_unlocked else 5

func start_game(new_mode: int) -> void:
	mode = new_mode
	scores = [0, 0]
	apply_map_size()
	new_round()

func apply_map_size() -> void:
	# Stretch mode expands the logical viewport on wide screens. Use that extra
	# width for the maze instead of leaving the old fixed 900 px playfield centered.
	var visible_size := get_viewport_rect().size
	var available_width := maxf(900.0, visible_size.x - 70.0)
	CELL = minf(70.0, minf(available_width / float(COLS), (H - HUD - 78.0) / float(ROWS)))
	OX = (W - COLS * CELL) / 2.0
	OY = HUD + (H - HUD - ROWS * CELL) / 2.0

func new_round() -> void:
	generate_maze()
	var needed: int = ai_count + 1 if mode == 1 else 2
	var spawn_cells: Array[Vector2i] = []
	while spawn_cells.size() < needed:
		var candidate := Vector2i(rng.randi_range(0, COLS - 1), rng.randi_range(0, ROWS - 1))
		if not spawn_cells.has(candidate): spawn_cells.append(candidate)
	var player_character := p1_character if mode == 2 else (5 if mode == 1 and ai_count == 5 and boss_character_unlocked else 0)
	var player_data: Dictionary = character_data(player_character)
	tanks = [tank(cell_center(spawn_cells[0]), rng.randf_range(0.0, TAU), player_data.color, player_data.name, player_data.portrait)]
	# 前四名保持原编制；隐藏模式第五名补上才羽绿，组成游戏开发部全员。
	var enemy_colors := [Color("f78c2b"), Color("ef476f"), Color("3979f6"), Color("f4f4f4"), Color("46e6a7")]
	var enemy_portraits := [PORTRAIT_MOMOI, PORTRAIT_YUZU, PORTRAIT_ALICE, PORTRAIT_KEI, PORTRAIT_MIDORI]
	var character_names := ["才羽桃井", "柚子", "爱丽丝", "凯伊", "才羽绿"]
	for i in range(1, needed):
		var enemy_color: Color
		var enemy_name: String
		var enemy_portrait: Texture2D
		if mode == 2:
			var second_player: Dictionary = character_data(p2_character)
			enemy_color = second_player.color
			enemy_name = second_player.name
			enemy_portrait = second_player.portrait
		elif mode == 3:
			enemy_color = Color("8e44d6")
			enemy_name = "优香"
			enemy_portrait = PORTRAIT_YUUKA
		else:
			enemy_color = enemy_colors[(i - 1) % enemy_colors.size()]
			enemy_name = character_names[i - 1]
			enemy_portrait = enemy_portraits[i - 1]
		var enemy := tank(cell_center(spawn_cells[i]), rng.randf_range(0.0, TAU), enemy_color, enemy_name, enemy_portrait)
		enemy.boss = mode == 3
		if mode == 3:
			enemy.hp = 3
			enemy.max_hp = 3
		enemy.ai_timer = rng.randf_range(0.0, 0.5)
		# Evenly stagger expensive predictions instead of letting every AI spike on
		# the same frame.
		enemy.danger_timer = float(i - 1) * ai_danger_interval / float(maxi(1, needed - 1))
		enemy.role = (i - 1) % 5
		tanks.append(enemy)
	bullets.clear()
	laser_beams.clear()
	pickups.clear()
	pickup_timer = 3.0
	round_over = false
	paused = false
	round_message = ""
	next_round_timer = 0.0
	countdown = 2.8
	particles.clear()
	touch_move = Vector2.ZERO
	p2_touch_move = Vector2.ZERO
	p2_move_touch_id = -1
	p2_fire_touch_id = -1
	queue_redraw()

func generate_maze() -> void:
	var visited := {Vector2i.ZERO: true}
	var stack: Array[Vector2i] = [Vector2i.ZERO]
	var passages := {}
	while not stack.is_empty():
		var p: Vector2i = stack.back()
		var choices: Array[Vector2i] = []
		for d: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var q: Vector2i = p + d
			if q.x >= 0 and q.x < COLS and q.y >= 0 and q.y < ROWS and not visited.has(q):
				choices.append(q)
		if choices.is_empty():
			stack.pop_back()
		else:
			var q: Vector2i = choices[rng.randi_range(0, choices.size() - 1)]
			passages[edge_key(p, q)] = true
			visited[q] = true
			stack.append(q)
	for i in 18:
		var p: Vector2i = Vector2i(rng.randi_range(0, COLS - 1), rng.randi_range(0, ROWS - 1))
		var extra_dirs: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN]
		var q: Vector2i = p + extra_dirs[rng.randi_range(0, 1)]
		if q.x < COLS and q.y < ROWS:
			passages[edge_key(p, q)] = true
	walls = [
		Rect2(OX, OY, COLS * CELL, WALL_T), Rect2(OX, OY + ROWS * CELL - WALL_T, COLS * CELL, WALL_T),
		Rect2(OX, OY, WALL_T, ROWS * CELL), Rect2(OX + COLS * CELL - WALL_T, OY, WALL_T, ROWS * CELL)
	]
	for y in ROWS:
		for x in COLS:
			var p := Vector2i(x, y)
			if x < COLS - 1 and not passages.has(edge_key(p, p + Vector2i.RIGHT)):
				walls.append(Rect2(OX + (x + 1) * CELL - WALL_T / 2.0, OY + y * CELL, WALL_T, CELL + WALL_T / 2.0))
			if y < ROWS - 1 and not passages.has(edge_key(p, p + Vector2i.DOWN)):
				walls.append(Rect2(OX + x * CELL, OY + (y + 1) * CELL - WALL_T / 2.0, CELL + WALL_T / 2.0, WALL_T))
	build_prediction_mask()

func build_prediction_mask() -> void:
	mask_origin = -view_offset()
	var visible_size := get_viewport_rect().size
	mask_width = maxi(1, ceili(visible_size.x / MASK_SCALE))
	mask_height = maxi(1, ceili(visible_size.y / MASK_SCALE))
	prediction_mask.resize(mask_width * mask_height)
	prediction_mask.fill(0)
	for wall in walls:
		var x1 := clampi(floori((wall.position.x - BULLET_R - mask_origin.x) / MASK_SCALE), 0, mask_width - 1)
		var y1 := clampi(floori((wall.position.y - BULLET_R - mask_origin.y) / MASK_SCALE), 0, mask_height - 1)
		var x2 := clampi(ceili((wall.end.x + BULLET_R - mask_origin.x) / MASK_SCALE), 0, mask_width - 1)
		var y2 := clampi(ceili((wall.end.y + BULLET_R - mask_origin.y) / MASK_SCALE), 0, mask_height - 1)
		for my in range(y1, y2 + 1):
			for mx in range(x1, x2 + 1): prediction_mask[my * mask_width + mx] = 1

func fast_wall(p: Vector2) -> bool:
	var mx := floori((p.x - mask_origin.x) / MASK_SCALE)
	var my := floori((p.y - mask_origin.y) / MASK_SCALE)
	if mx < 0 or mx >= mask_width or my < 0 or my >= mask_height: return true
	return prediction_mask[my * mask_width + mx] != 0

func edge_key(a: Vector2i, b: Vector2i) -> String:
	if a.x > b.x or (a.x == b.x and a.y > b.y):
		var t := a; a = b; b = t
	return "%d,%d-%d,%d" % [a.x, a.y, b.x, b.y]

func cell_center(c: Vector2i) -> Vector2:
	return Vector2(OX + (c.x + 0.5) * CELL, OY + (c.y + 0.5) * CELL)

func point_cell(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int((p.x - OX) / CELL), 0, COLS - 1), clampi(int((p.y - OY) / CELL), 0, ROWS - 1))

func _process(delta: float) -> void:
	if mode > 0 and not paused and not round_over and countdown <= 0.0:
		if mode == 1 or mode == 3:
			squad_clock -= delta
			if squad_clock <= 0.0:
				squad_clock = 3.5
				squad_phase = (squad_phase + 1) % 4
		update_human(0, delta)
		if mode == 1 or mode == 3:
			# GDScript gameplay runs mainly on the main thread. Limiting each kind of
			# expensive calculation to one AI per frame removes single-core spikes.
			ai_danger_budget = 1
			ai_bank_budget = 1
			for ai_index in range(1, tanks.size()): update_ai(ai_index, delta)
		else:
			update_human(1, delta)
		update_weapon_bursts(delta)
		update_bullets(delta)
		update_pickups(delta)
	if countdown > 0.0 and not paused:
		countdown -= delta
	update_particles(delta)
	if round_over and next_round_timer > 0.0:
		next_round_timer -= delta
	queue_redraw()

func update_human(index: int, delta: float) -> void:
	var prefix := "p1_" if index == 0 else "p2_"
	var drive := Input.get_action_strength(prefix + "forward") - Input.get_action_strength(prefix + "back")
	var turn := Input.get_action_strength(prefix + "right") - Input.get_action_strength(prefix + "left")
	var direct_control := false
	if index == 0 and (mobile or mouse_joystick_active):
		direct_control = true
		move_tank_direct(index, touch_move, delta)
	elif index == 1 and mobile and mode == 2:
		direct_control = true
		move_tank_direct(index, p2_touch_move, delta)
	elif index == 0:
		var keyboard_direction := Vector2(
			Input.get_action_strength("p1_right") - Input.get_action_strength("p1_left"),
			Input.get_action_strength("p1_back") - Input.get_action_strength("p1_forward")
		).limit_length(1.0)
		if keyboard_direction.length_squared() > 0.0:
			direct_control = true
			move_tank_direct(index, keyboard_direction, delta)
	if not direct_control:
		move_tank(index, drive, turn, delta)
	tanks[index].cooldown = maxf(0.0, tanks[index].cooldown - delta)
	if Input.is_action_just_pressed(prefix + "fire") and not (index == 0 and suppress_space_fire):
		fire(index)

func move_tank_direct(index: int, stick: Vector2, delta: float, max_speed := 120.0) -> void:
	if not tanks[index].alive or stick.length() < 0.08: return
	var t := tanks[index]
	var strength := minf(stick.length(), 1.0)
	var direction := stick.normalized()
	var desired_angle := direction.angle()
	var old_angle: float = float(t.angle)
	t.angle = lerp_angle(float(t.angle), desired_angle, minf(1.0, delta * 13.0))
	if tank_hits_wall(t.pos, float(t.angle)) or tank_hits_other_tank(index, t.pos, float(t.angle)): t.angle = old_angle
	var motion := direction * strength * max_speed * delta
	var p: Vector2 = t.pos
	var candidate_x := Vector2(p.x + motion.x, p.y)
	if not tank_hits_wall(candidate_x, float(t.angle)) and not tank_hits_other_tank(index, candidate_x, float(t.angle)): p.x += motion.x
	var candidate_y := Vector2(p.x, p.y + motion.y)
	if not tank_hits_wall(candidate_y, float(t.angle)) and not tank_hits_other_tank(index, candidate_y, float(t.angle)): p.y += motion.y
	t.pos = p
	tanks[index] = t

func move_tank(index: int, drive: float, turn: float, delta: float, max_speed := 120.0) -> void:
	if not tanks[index].alive: return
	var t := tanks[index]
	var direction: float = 1.0 if absf(drive) < 0.05 or drive > 0.0 else -1.0
	var old_angle: float = float(t.angle)
	t.angle += turn * 2.7 * delta * direction
	if tank_hits_wall(t.pos, float(t.angle)) or tank_hits_other_tank(index, t.pos, float(t.angle)): t.angle = old_angle
	var motion := Vector2.from_angle(t.angle) * drive * max_speed * delta
	var p: Vector2 = t.pos
	var candidate_x := Vector2(p.x + motion.x, p.y)
	if not tank_hits_wall(candidate_x, float(t.angle)) and not tank_hits_other_tank(index, candidate_x, float(t.angle)): p.x += motion.x
	var candidate_y := Vector2(p.x, p.y + motion.y)
	if not tank_hits_wall(candidate_y, float(t.angle)) and not tank_hits_other_tank(index, candidate_y, float(t.angle)): p.y += motion.y
	t.pos = p
	tanks[index] = t

func update_ai(index: int, delta: float) -> void:
	if not tanks[index].alive: return
	var ai := tanks[index]
	var is_boss := bool(ai.boss)
	ai.cooldown = maxf(0.0, ai.cooldown - delta)
	ai.danger_timer -= delta
	if ai.danger_timer <= 0.0 and ai_danger_budget > 0:
		# Staggered, cached prediction keeps ten-unit matches responsive.
		# BOSS 缓存躲避结果数帧，避免子弹临近时每秒重复几十次完整搜索。
		var squad_delay := 0.05 if mode == 1 and tanks.size() >= 6 else (0.025 if mode == 1 and tanks.size() >= 5 else 0.0)
		ai.danger_timer = ((0.11 if energy_saver_enabled else 0.075) if is_boss else ai_danger_interval) + squad_delay
		ai.danger_velocity = find_ai_evasion(ai.pos, float(ai.angle), index)
		ai_danger_budget -= 1
	var evade_direction: Vector2 = ai.danger_velocity
	if evade_direction.length_squared() > 0.0:
		tanks[index] = ai
		move_tank_direct(index, evade_direction, delta, 142.0 if is_boss else 126.0)
		return
	ai.ai_timer -= delta
	var has_sight: bool = clear_line(ai.pos, tanks[0].pos)
	var pickup_target := Vector2.ZERO
	var wants_pickup := false
	if str(ai.weapon) == "normal" and int(ai.burst_remaining) <= 0:
		var nearest_pickup_distance := INF
		for pickup in pickups:
			var pickup_position: Vector2 = pickup.pos
			var distance: float = (ai.pos as Vector2).distance_squared_to(pickup_position)
			if distance < nearest_pickup_distance:
				nearest_pickup_distance = distance
				pickup_target = pickup_position
				wants_pickup = true
	if ai.ai_timer <= 0.0 and (has_sight or ai_bank_budget > 0):
		ai.ai_timer = (0.24 if energy_saver_enabled else 0.16) if is_boss else 0.32
		var objective_cell := point_cell(pickup_target) if wants_pickup else tactical_cell(index)
		ai.ai_path = find_path(point_cell(ai.pos), objective_cell)
		var uses_bank_shots := true
		if wants_pickup or has_sight or not uses_bank_shots:
			ai.attack_angle = NAN
		else:
			ai_bank_budget -= 1
			ai.attack_angle = find_bank_angle(ai.pos, tanks[0].pos)
	var target: Vector2 = pickup_target if wants_pickup else (tanks[0].pos if has_sight else cell_center(tactical_cell(index)))
	if ai.ai_path.size() > 1:
		if wants_pickup or not has_sight: target = cell_center(ai.ai_path[1])
		if ai.pos.distance_to(target) < 13.0 and ai.ai_path.size() > 2:
			target = cell_center(ai.ai_path[2])
	var desired: float = (ai.pos as Vector2).angle_to_point(target)
	if not wants_pickup and not has_sight and not is_nan(float(ai.attack_angle)): desired = float(ai.attack_angle)
	var diff: float = wrapf(desired - float(ai.angle), -PI, PI)
	var turn: float = clampf(diff * 3.2, -1.0, 1.0)
	var distance_to_player: float = ai.pos.distance_to(tanks[0].pos)
	var drive: float = 1.0 if absf(diff) < 0.9 else 0.15
	if not wants_pickup and not has_sight and not is_nan(float(ai.attack_angle)): drive = 0.0
	if has_sight and not wants_pickup:
		# Suppressors hold ground, bait units reverse, assault units close in.
		if int(ai.role) == 3: drive = 0.0
		elif int(ai.role) == 4 and distance_to_player < 230.0: drive = -0.75
		elif distance_to_player < 115.0: drive = 0.0
	tanks[index] = ai
	if (wants_pickup or not has_sight) and is_nan(float(ai.attack_angle)):
		# Omnidirectional path following prevents rectangular tanks wedging at corners.
		move_tank_direct(index, (target - ai.pos).normalized(), delta, 124.0 if is_boss else 108.0)
	else:
		move_tank(index, drive, turn, delta, 136.0 if is_boss else 120.0)
	ai = tanks[index]
	var player_angle: float = (ai.pos as Vector2).angle_to_point(tanks[0].pos as Vector2)
	var firing_angle: float = player_angle if has_sight else float(ai.attack_angle)
	var aim_error: float = INF if is_nan(firing_angle) else absf(wrapf(firing_angle - float(ai.angle), -PI, PI))
	var fire_tolerance := 0.022 if is_boss else 0.035
	var safe_to_fire := false
	# The full ricochet safety trace is intentionally run only when the barrel is
	# ready to fire, otherwise it would waste CPU every frame.
	if aim_error < fire_tolerance:
		safe_to_fire = ai_shot_safe(ai.pos, ai.angle, tanks[0].pos, float(tanks[0].angle))
	var firing_lane_clear: bool = not has_sight or not friendly_in_line(index, ai.pos, tanks[0].pos)
	# Ballistic solutions are narrow: wait until the barrel is within about two degrees.
	if aim_error < fire_tolerance and safe_to_fire and firing_lane_clear:
		fire(index)

func tactical_cell(index: int) -> Vector2i:
	var player_cell := point_cell(tanks[0].pos)
	var ring: Array[Vector2i] = [Vector2i(-2, 0), Vector2i(2, 0), Vector2i(0, -2), Vector2i(0, 2), Vector2i(-2, -2), Vector2i(2, 2), Vector2i(2, -2), Vector2i(-2, 2)]
	var offset: Vector2i = ring[(index - 1 + squad_phase * 2) % ring.size()]
	if int(tanks[index].role) == 0: offset /= 2
	return Vector2i(clampi(player_cell.x + offset.x, 0, COLS - 1), clampi(player_cell.y + offset.y, 0, ROWS - 1))

func find_bank_angle(origin: Vector2, target: Vector2) -> float:
	var direct := origin.angle_to_point(target)
	if trajectory_miss_distance(origin, direct, target) <= 0.0 and trajectory_hits_target_real(origin, direct, target): return direct
	var best_angle := direct
	var best_miss := INF
	for degrees in range(0, 360, 6):
		var candidate := deg_to_rad(float(degrees))
		var miss := trajectory_miss_distance(origin, candidate, target)
		if miss < best_miss: best_miss = miss; best_angle = candidate
	for refinement in range(-12, 13):
		var candidate := best_angle + deg_to_rad(float(refinement) * 0.5)
		if trajectory_miss_distance(origin, candidate, target) <= 0.0 and trajectory_hits_target_real(origin, candidate, target): return candidate
	return NAN

func trajectory_hits_target_real(origin: Vector2, angle: float, target: Vector2) -> bool:
	var p := origin + Vector2.from_angle(angle) * MUZZLE_OFFSET
	var v := Vector2.from_angle(angle) * 2.5
	var bounce_count := 0
	for step_index in 1680:
		var bounced := false
		if circle_hits_wall(Vector2(p.x + v.x, p.y), BULLET_R): v.x *= -1.0; bounced = true
		if circle_hits_wall(Vector2(p.x, p.y + v.y), BULLET_R): v.y *= -1.0; bounced = true
		if bounced:
			bounce_count += 1
			if bounce_count >= 10: return false
		p += v
		if bullet_hits_tank_at(p, target, float(tanks[0].angle), BULLET_R): return true
		if step_index > 20 and bullet_hits_tank_at(p, origin, angle, BULLET_R): return false
	return false

func trajectory_miss_distance(origin: Vector2, angle: float, target: Vector2) -> float:
	var p := origin + Vector2.from_angle(angle) * MUZZLE_OFFSET
	var v := Vector2.from_angle(angle) * MASK_SCALE
	var closest := distance_to_tank_rect(p, target, float(tanks[0].angle)) - BULLET_R
	var bounce_count := 0
	for _step in 1400:
		var bounced := false
		if fast_wall(Vector2(p.x + v.x, p.y)): v.x *= -1.0; bounced = true
		if fast_wall(Vector2(p.x, p.y + v.y)): v.y *= -1.0; bounced = true
		if bounced:
			bounce_count += 1
			if bounce_count >= 10: break
		p += v
		var target_distance := distance_to_tank_rect(p, target, float(tanks[0].angle)) - BULLET_R
		closest = minf(closest, target_distance)
		if closest <= 0.0: return closest
		# Reject a solution that returns to the shooter before reaching the target.
		if _step > 18 and bullet_hits_tank_at(p, origin, angle, BULLET_R): return INF
	return closest

func friendly_in_line(owner: int, origin: Vector2, end: Vector2) -> bool:
	for i in range(1, tanks.size()):
		if i == owner or not tanks[i].alive: continue
		var segment := end - origin
		var length_squared := segment.length_squared()
		if length_squared <= 0.0: continue
		var t: float = (tanks[i].pos - origin).dot(segment) / length_squared
		if t <= 0.05 or t >= 0.95: continue
		if tanks[i].pos.distance_to(origin + segment * t) < TANK_R * 2.2: return true
	return false

func find_ai_evasion(ai_pos: Vector2, ai_angle: float, ai_index: int) -> Vector2:
	# Predict bullet and tank positions at the same moments. This prevents reacting
	# to harmless near misses and catches ricochets which arrive much later.
	const PREDICT_DT := 0.10
	var evade_directions := ai_evade_directions
	var evade_step_count := ai_evade_steps
	# BOSS 只需覆盖约 3.6 秒的实际逃生窗口。更多方向和更远未来不会
	# 改变眼前的躲避选择，却会在子弹接近时造成明显的单帧计算尖峰。
	if bool(tanks[ai_index].boss):
		evade_directions = mini(evade_directions, 12)
		evade_step_count = mini(evade_step_count, 36)
	elif mode == 1 and tanks.size() >= 6:
		# 隐藏五人战把远期采样让给下一帧，避免五台 AI 同时制造尖峰。
		evade_directions = mini(evade_directions, 8)
		evade_step_count = mini(evade_step_count, 26)
	var predict_steps := evade_step_count
	var trajectories: Array[Dictionary] = []
	for bullet in bullets:
		var owner := int(bullet.owner)
		# Friendly fire is enabled, so every projectile can be dangerous.
		var segments_by_step: Array = []
		var future: Vector2 = bullet.pos
		var velocity: Vector2 = bullet.vel
		var remaining_life: float = float(bullet.life)
		var bounce_count: int = int(bullet.bounces)
		for step_index in predict_steps:
			if remaining_life <= 0.0 or bounce_count >= 10: break
			var step_segments := PackedVector2Array()
			var travel := velocity.length() * PREDICT_DT
			var substeps := maxi(1, ceili(travel / MASK_SCALE))
			var sub_delta := PREDICT_DT / float(substeps)
			for _substep in substeps:
				var segment_start := future
				var motion := velocity * sub_delta
				var bounced := false
				if fast_wall(Vector2(future.x + motion.x, future.y)):
					velocity.x *= -1.0
					bounced = true
				if fast_wall(Vector2(future.x, future.y + motion.y)):
					velocity.y *= -1.0
					bounced = true
				if bounced: bounce_count += 1
				future += velocity * sub_delta
				step_segments.append(segment_start)
				step_segments.append(future)
			segments_by_step.append(step_segments)
			remaining_life -= PREDICT_DT
		trajectories.append({"segments": segments_by_step, "owner": owner, "grace": float(bullet.grace)})
	if trajectories.is_empty(): return Vector2.ZERO

	# First test standing still. Dodge only an actual predicted collision.
	var standing_safe := true
	for trajectory in trajectories:
		var steps: Array = trajectory.segments
		for step_index in steps.size():
			if int(trajectory.owner) == ai_index and (step_index + 1) * PREDICT_DT < float(trajectory.grace): continue
			var segments: PackedVector2Array = steps[step_index]
			for segment_index in range(0, segments.size(), 2):
				if segment_hits_tank_rect(segments[segment_index], segments[segment_index + 1], ai_pos, ai_angle, BULLET_R + 1.5):
					standing_safe = false
					break
			if not standing_safe: break
		if not standing_safe: break
	if standing_safe: return Vector2.ZERO

	# Score a full circle of escape routes. The winner maximizes the smallest
	# time-aligned clearance and is rejected if a wall blocks its movement.
	var best_direction := Vector2.ZERO
	var best_score := -INF
	for direction_index in evade_directions:
		var direction := Vector2.from_angle(TAU * float(direction_index) / float(evade_directions))
		var candidate_pos := ai_pos
		var candidate_angle := ai_angle
		var score := INF
		var blocked_steps := 0
		for step_index in evade_step_count:
			candidate_angle = lerp_angle(candidate_angle, direction.angle(), minf(1.0, PREDICT_DT * 13.0))
			var motion := direction * 126.0 * PREDICT_DT
			var old_pos := candidate_pos
			if not tank_hits_wall(Vector2(candidate_pos.x + motion.x, candidate_pos.y), candidate_angle): candidate_pos.x += motion.x
			if not tank_hits_wall(Vector2(candidate_pos.x, candidate_pos.y + motion.y), candidate_angle): candidate_pos.y += motion.y
			if candidate_pos.distance_squared_to(old_pos) < motion.length_squared() * 0.12: blocked_steps += 1
			for trajectory in trajectories:
				var steps: Array = trajectory.segments
				if step_index >= steps.size(): continue
				if int(trajectory.owner) == ai_index and (step_index + 1) * PREDICT_DT < float(trajectory.grace): continue
				var segments: PackedVector2Array = steps[step_index]
				for segment_index in range(0, segments.size(), 2):
					var segment_start: Vector2 = segments[segment_index]
					var segment_end: Vector2 = segments[segment_index + 1]
					var clearance := minf(
						distance_to_tank_rect(segment_start, candidate_pos, candidate_angle),
						distance_to_tank_rect(segment_end, candidate_pos, candidate_angle)
					) - BULLET_R
					if segment_hits_tank_rect(segment_start, segment_end, candidate_pos, candidate_angle, BULLET_R):
						clearance = -float(predict_steps - step_index) * 2.0
					score = minf(score, clearance)
		score -= float(blocked_steps) * 3.0
		# A tiny continuity bonus avoids switching between equally safe directions.
		var previous: Vector2 = tanks[ai_index].danger_velocity
		if previous.length_squared() > 0.0: score += direction.dot(previous.normalized()) * 1.5
		if score > best_score:
			best_score = score
			best_direction = direction
	return best_direction

func segment_hits_tank_rect(segment_start: Vector2, segment_end: Vector2, tank_pos: Vector2, tank_angle: float, radius: float) -> bool:
	# Transform the swept bullet segment into the tank's local coordinates, then
	# use a slab test against the rectangle expanded by the bullet radius.
	var forward := Vector2.from_angle(tank_angle)
	var side := forward.rotated(PI / 2.0)
	var start_relative := segment_start - tank_pos
	var end_relative := segment_end - tank_pos
	var local_start := Vector2(start_relative.dot(forward), start_relative.dot(side))
	var local_end := Vector2(end_relative.dot(forward), end_relative.dot(side))
	var segment_delta := local_end - local_start
	var half_size := Vector2(TANK_LENGTH / 2.0 + radius, TANK_WIDTH / 2.0 + radius)
	var enter_time := 0.0
	var exit_time := 1.0
	for axis in 2:
		var start_value: float = local_start[axis]
		var delta_value: float = segment_delta[axis]
		var half_extent: float = half_size[axis]
		if absf(delta_value) < 0.00001:
			if absf(start_value) > half_extent: return false
			continue
		var first_time := (-half_extent - start_value) / delta_value
		var second_time := (half_extent - start_value) / delta_value
		if first_time > second_time:
			var swap_time := first_time
			first_time = second_time
			second_time = swap_time
		enter_time = maxf(enter_time, first_time)
		exit_time = minf(exit_time, second_time)
		if enter_time > exit_time: return false
	return true

func ai_shot_safe(origin: Vector2, angle: float, target_pos: Vector2, target_angle: float) -> bool:
	# Fire only when the real ten-bounce path reaches the player before returning
	# to the shooter. Direct shots no longer bypass this check near a wall.
	var p := origin + Vector2.from_angle(angle) * MUZZLE_OFFSET
	var v := Vector2.from_angle(angle) * 3.0
	var bounce_count := 0
	for step_index in 1800:
		var bounced := false
		if circle_hits_wall(Vector2(p.x + v.x, p.y), BULLET_R): v.x *= -1.0; bounced = true
		if circle_hits_wall(Vector2(p.x, p.y + v.y), BULLET_R): v.y *= -1.0; bounced = true
		if bounced:
			bounce_count += 1
			if bounce_count >= 10: return false
		p += v
		if bullet_hits_tank_at(p, target_pos, target_angle, BULLET_R): return true
		if step_index > 18 and bullet_hits_tank_at(p, origin, angle, BULLET_R): return false
	return false

func find_path(start: Vector2i, goal: Vector2i) -> Array:
	var queue: Array[Vector2i] = [start]
	var came := {start: start}
	while not queue.is_empty():
		var p: Vector2i = queue.pop_front()
		if p == goal: break
		for d: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var q: Vector2i = p + d
			if q.x < 0 or q.x >= COLS or q.y < 0 or q.y >= ROWS or came.has(q): continue
			if not cells_connected(p, q): continue
			came[q] = p; queue.append(q)
	var path: Array = []
	if not came.has(goal): return [start]
	var cur := goal
	while cur != start:
		path.push_front(cur); cur = came[cur]
	path.push_front(start)
	return path

func cells_connected(a: Vector2i, b: Vector2i) -> bool:
	var mid := (cell_center(a) + cell_center(b)) * 0.5
	return not circle_hits_wall(mid, 9.0)

func clear_line(a: Vector2, b: Vector2) -> bool:
	var dist := a.distance_to(b)
	for i in range(1, int(dist / 3.0)):
		if circle_hits_wall(a.lerp(b, float(i) * 3.0 / dist), 5.0): return false
	return true

func ricochet_shot_available(origin: Vector2, angle: float, target: Vector2) -> bool:
	# Use a step smaller than the wall so tactical prediction cannot tunnel through it.
	var p := origin + Vector2.from_angle(angle) * MUZZLE_OFFSET
	var v := Vector2.from_angle(angle) * 3.0
	var bounced := false
	for _step_index in 280:
		if circle_hits_wall(Vector2(p.x + v.x, p.y), 5.0): v.x *= -1.0; bounced = true
		if circle_hits_wall(Vector2(p.x, p.y + v.y), 5.0): v.y *= -1.0; bounced = true
		p += v
		if bounced and p.distance_to(target) < TANK_R + 7.0: return true
	return false

func fire(index: int) -> void:
	if mode == 0 or round_over or paused or not tanks[index].alive: return
	var t := tanks[index]
	var weapon: String = t.weapon
	var owned := 0
	for b in bullets:
		# 散弹与机关枪弹幕不占普通子弹上限。
		if b.owner == index and str(b.weapon) != "shotgun" and str(b.weapon) != "minigun": owned += 1
	var projectile_limit := 8 if bool(t.boss) else 5
	if t.cooldown > 0.0 or (owned >= projectile_limit and weapon != "laser" and weapon != "shotgun" and weapon != "minigun"): return
	if weapon == "laser":
		fire_laser(index)
		play_sound(sound_shoot, 1.35)
		t.cooldown = 0.55
		t.ammo -= 1
		if t.ammo <= 0: t.weapon = "normal"
		tanks[index] = t
		return
	if weapon == "minigun":
		# 一次道具触发一小段自动弹幕，后续子弹由计时器依次发射。
		t.burst_remaining = 5
		t.burst_timer = 0.0
		t.weapon = "normal"
		t.ammo = 0
		t.cooldown = 0.78
		tanks[index] = t
		return
	var shots := [0.0]
	var speed := 200.0
	var life := 60.0
	var homing := false
	if weapon == "shotgun": shots = [-0.24, -0.12, 0.0, 0.12, 0.24]; speed = 185.0; life = 3.2
	elif weapon == "minigun": speed = 250.0; life = 6.0
	elif weapon == "homing": speed = 165.0; life = 9.0; homing = true
	for spread in shots:
		var a: float = t.angle + float(spread)
		bullets.append({"pos": t.pos + Vector2.from_angle(a) * MUZZLE_OFFSET,
			"vel": Vector2.from_angle(a) * speed, "owner": index, "life": life, "grace": 0.24,
			"homing": homing, "weapon": weapon, "bounces": 0})
	play_sound(sound_shoot, rng.randf_range(0.92, 1.08))
	if bool(t.boss):
		t.cooldown = 0.08 if weapon == "minigun" else 0.20
	else:
		t.cooldown = 0.10 if weapon == "minigun" else 0.34
	if weapon != "normal":
		t.ammo -= 1
		if t.ammo <= 0: t.weapon = "normal"
	tanks[index] = t

func update_weapon_bursts(delta: float) -> void:
	for index in tanks.size():
		if not tanks[index].alive or int(tanks[index].burst_remaining) <= 0: continue
		var t := tanks[index]
		t.burst_timer -= delta
		if float(t.burst_timer) <= 0.0:
			var spread := rng.randf_range(-0.035, 0.035)
			var angle: float = float(t.angle) + spread
			bullets.append({"pos": t.pos + Vector2.from_angle(angle) * MUZZLE_OFFSET,
				"vel": Vector2.from_angle(angle) * 250.0, "owner": index, "life": 6.0,
				"grace": 0.24, "homing": false, "weapon": "minigun", "bounces": 0})
			t.burst_remaining -= 1
			t.burst_timer = 0.085
			# 每隔一发播放音效，避免同时创建过多音频节点。
			if int(t.burst_remaining) % 2 == 0: play_sound(sound_shoot, rng.randf_range(1.15, 1.28))
		tanks[index] = t

func fire_laser(owner: int) -> void:
	var shooter := tanks[owner]
	var position: Vector2 = shooter.pos + Vector2.from_angle(float(shooter.angle)) * (TANK_LENGTH / 2.0 + 2.0)
	var velocity := Vector2.from_angle(float(shooter.angle)) * 2.0
	var points := PackedVector2Array([position])
	var bounce_count := 0
	for step_index in 2600:
		var bounced := false
		if circle_hits_wall(Vector2(position.x + velocity.x, position.y), 1.0): velocity.x *= -1.0; bounced = true
		if circle_hits_wall(Vector2(position.x, position.y + velocity.y), 1.0): velocity.y *= -1.0; bounced = true
		if bounced:
			points.append(position)
			bounce_count += 1
			if bounce_count >= 10: break
		position += velocity
		for tank_index in tanks.size():
			if not tanks[tank_index].alive: continue
			if tank_index == owner and step_index < 12: continue
			if bullet_hits_tank_at(position, tanks[tank_index].pos, float(tanks[tank_index].angle), 1.25):
				points.append(position)
				tank_was_hit(tank_index)
				laser_beams.append({"points": points, "life": 0.14, "max_life": 0.14})
				return
	points.append(position)
	laser_beams.append({"points": points, "life": 0.14, "max_life": 0.14})

func update_bullets(delta: float) -> void:
	for i in range(bullets.size() - 1, -1, -1):
		var b := bullets[i]
		if b.homing:
			var target_index: int = homing_target(int(b.owner), b.pos)
			if target_index >= 0 and tanks[target_index].alive:
				var wanted: Vector2 = b.pos.direction_to(tanks[target_index].pos) * b.vel.length()
				b.vel = b.vel.lerp(wanted, minf(1.0, delta * 2.4))
		b.life -= delta; b.grace -= delta
		var hit := false
		# Sub-step fast projectiles so lasers and close-range shots cannot tunnel through walls.
		var travel: float = b.vel.length() * delta
		var substeps: int = maxi(1, ceili(travel / 3.0))
		var sub_delta: float = delta / float(substeps)
		for substep in substeps:
			var step: Vector2 = b.vel * sub_delta
			var p: Vector2 = b.pos
			var bounced := false
			if circle_hits_wall(Vector2(p.x + step.x, p.y), BULLET_R):
				b.vel.x *= -1.0; bounced = true
			if circle_hits_wall(Vector2(p.x, p.y + step.y), BULLET_R):
				b.vel.y *= -1.0; bounced = true
			if bounced:
				b.bounces += 1
				play_sound(sound_bounce, rng.randf_range(0.9, 1.15))
			b.pos += b.vel * sub_delta
			for ti in tanks.size():
				if not tanks[ti].alive: continue
				if ti == b.owner and b.grace > 0.0: continue
				# Full friendly fire: department projectiles can hit any teammate.
				if bullet_hits_tank_at(b.pos, tanks[ti].pos, float(tanks[ti].angle), BULLET_R):
					tank_was_hit(ti); hit = true; break
			if hit: break
		if hit or b.life <= 0.0 or int(b.bounces) >= 10: bullets.remove_at(i)
		else: bullets[i] = b

func homing_target(owner: int, bullet_pos: Vector2) -> int:
	if owner > 0: return 0 if tanks[0].alive else -1
	var result := -1
	var closest := INF
	for i in range(1, tanks.size()):
		if tanks[i].alive and bullet_pos.distance_squared_to(tanks[i].pos) < closest:
			closest = bullet_pos.distance_squared_to(tanks[i].pos); result = i
	return result

func update_pickups(delta: float) -> void:
	pickup_timer -= delta
	if pickup_timer <= 0.0 and pickups.size() < 2:
		pickup_timer = rng.randf_range(5.0, 8.0)
		var c := Vector2i(rng.randi_range(1, COLS - 2), rng.randi_range(1, ROWS - 2))
		var kinds := ["shotgun", "laser", "minigun", "homing"]
		pickups.append({"pos": cell_center(c), "kind": kinds[rng.randi_range(0, kinds.size() - 1)]})
	for pi in range(pickups.size() - 1, -1, -1):
		for ti in tanks.size():
			if tanks[ti].alive and tanks[ti].pos.distance_to(pickups[pi].pos) < TANK_R + 16.0:
				var t := tanks[ti]
				t.weapon = pickups[pi].kind
				# 每个道具只提供一次特殊攻击，发射后自动恢复普通攻击。
				t.ammo = 1
				tanks[ti] = t
				play_sound(sound_pickup, rng.randf_range(0.96, 1.08))
				pickups.remove_at(pi)
				break

func tank_was_hit(index: int) -> void:
	if not tanks[index].alive: return
	if int(tanks[index].hp) > 1:
		tanks[index].hp -= 1
		spawn_armor_hit(tanks[index].pos, tanks[index].color)
		return
	tanks[index].alive = false
	var defeat_sound: AudioStream = SOUND_MOMOI_DEFEAT if str(tanks[index].name) == "才羽桃井" else null
	spawn_explosion(tanks[index].pos, tanks[index].color, defeat_sound)
	if index == 0:
		scores[1] += 1
		if mode == 1:
			round_message = "游戏开发部胜利" if ai_count == 5 else "偷跑失败"
		else:
			round_message = "%s获胜！" % tanks[1].name
		round_over = true
	else:
		var enemies_alive := false
		for i in range(1, tanks.size()):
			if tanks[i].alive: enemies_alive = true; break
		if not enemies_alive:
			scores[0] += 1
			if mode == 1:
				round_message = "优香胜利" if ai_count == 5 else "偷跑成功"
			elif mode == 3 and not boss_character_unlocked:
				boss_character_unlocked = true
				save_progress()
				round_message = "击败 Boss！已解锁优香"
			else:
				round_message = "%s获胜！" % tanks[0].name
			round_over = true
	if round_over: next_round_timer = 0.45

func spawn_armor_hit(pos: Vector2, color: Color) -> void:
	play_sound(sound_bounce, 0.65)
	for i in 14:
		var angle := rng.randf_range(0.0, TAU)
		particles.append({"pos": pos, "vel": Vector2.from_angle(angle) * rng.randf_range(45.0, 150.0),
			"life": rng.randf_range(0.18, 0.45), "max_life": 0.45,
			"color": color if i % 2 else Color("ffffff")})

func spawn_explosion(pos: Vector2, color: Color, defeat_sound: AudioStream = null) -> void:
	if defeat_sound != null: play_sound(defeat_sound, 1.0, 3.0)
	else: play_sound(sound_explode, rng.randf_range(0.88, 1.05))
	for i in 26:
		var a := rng.randf_range(0.0, TAU)
		var speed := rng.randf_range(55.0, 230.0)
		particles.append({"pos": pos, "vel": Vector2.from_angle(a) * speed,
			"life": rng.randf_range(0.35, 0.9), "max_life": 0.9,
			"color": color if i % 3 else Color("ffad33")})

func update_particles(delta: float) -> void:
	for beam_index in range(laser_beams.size() - 1, -1, -1):
		laser_beams[beam_index].life -= delta
		if laser_beams[beam_index].life <= 0.0: laser_beams.remove_at(beam_index)
	for i in range(particles.size() - 1, -1, -1):
		particles[i].pos += particles[i].vel * delta
		particles[i].vel *= pow(0.04, delta)
		particles[i].life -= delta
		if particles[i].life <= 0.0: particles.remove_at(i)

func distance_to_tank_rect(point: Vector2, tank_pos: Vector2, tank_angle: float) -> float:
	var forward := Vector2.from_angle(tank_angle)
	var side := forward.rotated(PI / 2.0)
	var relative := point - tank_pos
	var local := Vector2(relative.dot(forward), relative.dot(side))
	var nearest := Vector2(
		clampf(local.x, -TANK_LENGTH / 2.0, TANK_LENGTH / 2.0),
		clampf(local.y, -TANK_WIDTH / 2.0, TANK_WIDTH / 2.0)
	)
	return local.distance_to(nearest)

func bullet_hits_tank_at(bullet_pos: Vector2, tank_pos: Vector2, tank_angle: float, radius: float) -> bool:
	return distance_to_tank_rect(bullet_pos, tank_pos, tank_angle) <= radius

func tank_hits_wall(pos: Vector2, angle: float) -> bool:
	var forward := Vector2.from_angle(angle)
	var side := forward.rotated(PI / 2.0)
	for wall in walls:
		var wall_center := wall.get_center()
		var wall_half := wall.size / 2.0
		var center_delta := wall_center - pos
		var overlaps := true
		for axis in [Vector2.RIGHT, Vector2.DOWN, forward, side]:
			var tank_radius := absf(axis.dot(forward)) * TANK_LENGTH / 2.0 + absf(axis.dot(side)) * TANK_WIDTH / 2.0
			var wall_radius := absf(axis.x) * wall_half.x + absf(axis.y) * wall_half.y
			if absf(center_delta.dot(axis)) > tank_radius + wall_radius:
				overlaps = false
				break
		if overlaps: return true
	return false

func tank_hits_other_tank(tank_index: int, candidate_pos: Vector2, candidate_angle: float) -> bool:
	for other_index in tanks.size():
		if other_index == tank_index or not tanks[other_index].alive: continue
		if oriented_tanks_overlap(candidate_pos, candidate_angle, tanks[other_index].pos, float(tanks[other_index].angle)):
			return true
	return false

func oriented_tanks_overlap(pos_a: Vector2, angle_a: float, pos_b: Vector2, angle_b: float) -> bool:
	var forward_a := Vector2.from_angle(angle_a)
	var side_a := forward_a.rotated(PI / 2.0)
	var forward_b := Vector2.from_angle(angle_b)
	var side_b := forward_b.rotated(PI / 2.0)
	var center_delta := pos_b - pos_a
	for axis in [forward_a, side_a, forward_b, side_b]:
		var radius_a := absf(axis.dot(forward_a)) * TANK_LENGTH / 2.0 + absf(axis.dot(side_a)) * TANK_WIDTH / 2.0
		var radius_b := absf(axis.dot(forward_b)) * TANK_LENGTH / 2.0 + absf(axis.dot(side_b)) * TANK_WIDTH / 2.0
		if absf(center_delta.dot(axis)) >= radius_a + radius_b: return false
	return true

func circle_hits_wall(p: Vector2, radius: float) -> bool:
	for r in walls:
		var nearest := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
		if p.distance_squared_to(nearest) < radius * radius: return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	if intro_playing:
		# Permit a tap/click/Space to skip the startup video on touch devices too.
		var skip_intro: bool = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_SPACE or event.keycode == KEY_ESCAPE))
		if skip_intro:
			finish_intro()
		return
	if event is InputEventKey and event.keycode == KEY_SPACE and not event.pressed:
		suppress_space_fire = false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and music_picker_open:
			music_picker_open = false
			queue_redraw()
		elif event.keycode == KEY_ESCAPE and pause_settings_open:
			pause_settings_open = false
			queue_redraw()
		elif event.keycode == KEY_SPACE and countdown > 0.0:
			suppress_space_fire = true
			countdown = 0.0
			queue_redraw()
		elif event.keycode == KEY_SPACE and round_over and next_round_timer <= 0.0: new_round()
		elif event.keycode == KEY_1: start_game(1)
		elif event.keycode == KEY_2: start_game(2)
		elif event.keycode == KEY_ESCAPE and mode > 0: paused = not paused
		elif event.keycode == KEY_M and paused: return_to_menu()
		elif event.keycode == KEY_R and mode > 0: scores = [0, 0]; new_round()
	if event is InputEventScreenTouch:
		handle_touch(event.index, event.position - view_offset(), event.pressed)
	elif event is InputEventScreenDrag:
		var drag_pos: Vector2 = event.position - view_offset()
		if music_picker_open and event.index == music_picker_touch_id:
			music_scroll = clampf(music_scroll - event.relative.y, 0.0, music_scroll_limit())
			if drag_pos.distance_to(music_picker_touch_start) > 8.0: music_picker_touch_moved = true
			queue_redraw()
		elif settings_active() and event.index == settings_slider_touch_id and settings_slider_drag >= 0:
			update_audio_slider(settings_slider_drag, drag_pos.x)
		elif event.index == move_touch_id:
			touch_move = ((drag_pos - p1_move_center()) / 70.0).limit_length(1.0)
		elif event.index == p2_move_touch_id:
			p2_touch_move = ((drag_pos - p2_move_center()) / 70.0).limit_length(1.0)
	elif event is InputEventMouseMotion and not mobile:
		var mouse_pos: Vector2 = event.position - view_offset()
		if settings_active() and settings_slider_drag >= 0:
			update_audio_slider(settings_slider_drag, mouse_pos.x)
		elif mouse_joystick_active:
			touch_move = ((mouse_pos - p1_move_center()) / 70.0).limit_length(1.0)
	elif event is InputEventMouseButton and not mobile:
		var mouse_pos: Vector2 = event.position - view_offset()
		if music_picker_open:
			if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
				music_scroll = maxf(0.0, music_scroll - 108.0); queue_redraw()
			elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				music_scroll = minf(music_scroll_limit(), music_scroll + 108.0); queue_redraw()
			elif event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				handle_music_picker_press(mouse_pos)
			return
		if event.button_index == MOUSE_BUTTON_LEFT and settings_active():
			if event.pressed:
				handle_settings_press(mouse_pos)
			elif settings_slider_drag >= 0:
				settings_slider_drag = -1
				save_progress()
			return
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and mode > 0:
			fire(0)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var joystick_area := Rect2(p1_move_center() - Vector2(95, 95), Vector2(190, 190))
			var fire_area := Rect2(single_fire_center() - Vector2(70, 70), Vector2(140, 140))
			if event.pressed and paused:
				handle_pause_press(mouse_pos)
			elif not event.pressed and mouse_joystick_active:
				mouse_joystick_active = false
				touch_move = Vector2.ZERO
			elif mode > 0 and joystick_area.has_point(mouse_pos):
				mouse_joystick_active = event.pressed
				if event.pressed: touch_move = ((mouse_pos - p1_move_center()) / 70.0).limit_length(1.0)
				else: touch_move = Vector2.ZERO
			elif event.pressed and mode > 0 and fire_area.has_point(mouse_pos):
				fire(0)
			elif event.pressed:
				if mode == 0:
					handle_menu_press(mouse_pos)
				elif round_over and Rect2(190, 300, 620, 170).has_point(mouse_pos) and next_round_timer <= 0.0:
					new_round()

func handle_touch(id: int, pos: Vector2, pressed: bool) -> void:
	if music_picker_open:
		if pressed:
			music_picker_touch_id = id
			music_picker_touch_start = pos
			music_picker_touch_moved = false
		elif id == music_picker_touch_id:
			if not music_picker_touch_moved: handle_music_picker_press(pos)
			music_picker_touch_id = -1
		return
	if settings_active():
		if pressed:
			var slider_index := audio_slider_at(pos)
			if slider_index >= 0:
				settings_slider_drag = slider_index
				settings_slider_touch_id = id
				update_audio_slider(slider_index, pos.x)
			else:
				handle_settings_press(pos)
		elif id == settings_slider_touch_id:
			settings_slider_drag = -1
			settings_slider_touch_id = -1
			save_progress()
		return
	if mode == 0:
		if pressed: handle_menu_press(pos)
		return
	if paused:
		if pressed: handle_pause_press(pos)
		return
	if round_over and pressed and Rect2(190, 300, 620, 170).has_point(pos) and next_round_timer <= 0.0:
		new_round(); return
	if countdown > 0.0 and pressed:
		countdown = 0.0
		queue_redraw()
		return
	if not pressed:
		if id == move_touch_id: move_touch_id = -1; touch_move = Vector2.ZERO
		elif id == fire_touch_id: fire_touch_id = -1
		elif id == p2_move_touch_id: p2_move_touch_id = -1; p2_touch_move = Vector2.ZERO
		elif id == p2_fire_touch_id: p2_fire_touch_id = -1
		return
	if mode == 2:
		if pos.x < W / 2.0:
			if pos.distance_to(p1_move_center()) <= 96.0 and move_touch_id < 0:
				move_touch_id = id; touch_move = ((pos - p1_move_center()) / 70.0).limit_length(1.0)
			elif pos.distance_to(p1_fire_center()) <= 78.0 and fire_touch_id < 0:
				fire_touch_id = id; fire(0)
		else:
			if pos.distance_to(p2_move_center()) <= 96.0 and p2_move_touch_id < 0:
				p2_move_touch_id = id; p2_touch_move = ((pos - p2_move_center()) / 70.0).limit_length(1.0)
			elif pos.distance_to(p2_fire_center()) <= 78.0 and p2_fire_touch_id < 0:
				p2_fire_touch_id = id; fire(1)
	else:
		if pos.distance_to(p1_move_center()) <= 100.0 and move_touch_id < 0:
			move_touch_id = id; touch_move = ((pos - p1_move_center()) / 70.0).limit_length(1.0)
		elif pos.distance_to(single_fire_center()) <= 84.0 and fire_touch_id < 0:
			fire_touch_id = id; fire(0)

func touch_control_y() -> float:
	return [H - 190.0, H - 130.0, H - 85.0][touch_height_index]

func touch_outer_x() -> float:
	return [140.0, 110.0, 85.0][touch_spacing_index]

func touch_inner_x() -> float:
	return [350.0, 390.0, 430.0][touch_spacing_index]

func p1_move_center() -> Vector2:
	return Vector2(-view_offset().x + touch_outer_x(), touch_control_y())

func p1_fire_center() -> Vector2:
	return Vector2(-view_offset().x + touch_inner_x(), touch_control_y())

func p2_move_center() -> Vector2:
	return Vector2(W + view_offset().x - touch_outer_x(), touch_control_y())

func p2_fire_center() -> Vector2:
	return Vector2(W + view_offset().x - touch_inner_x(), touch_control_y())

func single_fire_center() -> Vector2:
	return Vector2(W + view_offset().x - touch_outer_x(), touch_control_y())

func handle_pause_press(pos: Vector2) -> void:
	if pause_settings_open:
		handle_settings_press(pos)
		return
	if Rect2(330, 290, 340, 52).has_point(pos):
		play_sound(sound_click)
		paused = false
	elif Rect2(330, 355, 340, 52).has_point(pos):
		play_sound(sound_click)
		pause_settings_open = true
	elif Rect2(330, 420, 340, 52).has_point(pos):
		play_sound(sound_click, 0.88)
		return_to_menu()
	queue_redraw()

func settings_active() -> bool:
	return settings_open or pause_settings_open

func return_to_menu() -> void:
	mode = 0
	local_setup_open = false
	settings_open = false
	pause_settings_open = false
	music_picker_open = false
	paused = false
	round_over = false
	mouse_joystick_active = false
	move_touch_id = -1
	fire_touch_id = -1
	touch_move = Vector2.ZERO
	p2_touch_move = Vector2.ZERO
	p2_move_touch_id = -1
	p2_fire_touch_id = -1
	bullets.clear()
	laser_beams.clear()
	pickups.clear()
	particles.clear()
	queue_redraw()

func handle_menu_press(pos: Vector2) -> void:
	if music_picker_open:
		handle_music_picker_press(pos)
		return
	if settings_active():
		handle_settings_press(pos)
		return
	if local_setup_open:
		handle_local_setup_press(pos)
		return
	if Rect2(370, 155, 52, 38).has_point(pos): play_sound(sound_click); COLS = maxi(7, COLS - 1)
	elif Rect2(578, 155, 52, 38).has_point(pos): play_sound(sound_click); COLS = mini(21, COLS + 1)
	elif Rect2(370, 201, 52, 38).has_point(pos): play_sound(sound_click); ROWS = maxi(5, ROWS - 1)
	elif Rect2(578, 201, 52, 38).has_point(pos): play_sound(sound_click); ROWS = mini(9, ROWS + 1)
	elif Rect2(370, 247, 52, 38).has_point(pos): play_sound(sound_click); ai_count = maxi(1, ai_count - 1)
	elif Rect2(578, 247, 52, 38).has_point(pos):
		play_sound(sound_click)
		ai_count = mini(5 if boss_character_unlocked else 4, ai_count + 1)
	elif Rect2(270, 315, 460, 54).has_point(pos): play_sound(sound_click, 1.12); start_game(1)
	elif Rect2(270, 381, 460, 54).has_point(pos): play_sound(sound_click, 0.82); start_game(3)
	elif Rect2(270, 447, 460, 54).has_point(pos):
		play_sound(sound_click, 1.12)
		local_setup_open = true
		if p1_character == p2_character: p2_character = posmod(p1_character + 1, selectable_character_count())
	elif Rect2(270, 513, 460, 54).has_point(pos):
		play_sound(sound_click)
		settings_open = true
	queue_redraw()

func handle_settings_press(pos: Vector2) -> void:
	var changed := false
	var slider_index := audio_slider_at(pos)
	if slider_index >= 0:
		settings_slider_drag = slider_index
		update_audio_slider(slider_index, pos.x)
	elif Rect2(370, 360, 260, 42).has_point(pos):
		play_sound(sound_click)
		music_picker_open = true
		music_scroll = clampf(float(music_index) * 54.0 - 205.0, 0.0, music_scroll_limit())
	elif mobile and Rect2(370, 420, 52, 42).has_point(pos): touch_height_index = maxi(0, touch_height_index - 1); changed = true
	elif mobile and Rect2(578, 420, 52, 42).has_point(pos): touch_height_index = mini(2, touch_height_index + 1); changed = true
	elif mobile and Rect2(370, 480, 52, 42).has_point(pos): touch_spacing_index = maxi(0, touch_spacing_index - 1); changed = true
	elif mobile and Rect2(578, 480, 52, 42).has_point(pos): touch_spacing_index = mini(2, touch_spacing_index + 1); changed = true
	elif Rect2(370, 540 if mobile else 420, 52, 42).has_point(pos) or Rect2(578, 540 if mobile else 420, 52, 42).has_point(pos): dark_mode = not dark_mode; changed = true
	elif Rect2(270, 625 if mobile else 505, 460, 54).has_point(pos):
		play_sound(sound_click)
		if pause_settings_open: pause_settings_open = false
		else: settings_open = false
	if changed:
		apply_audio_levels()
		play_sound(sound_click)
		save_progress()
	queue_redraw()

func audio_slider_at(pos: Vector2) -> int:
	for slider_index in 3:
		if Rect2(380, 180.0 + slider_index * 60.0, 300, 42).has_point(pos): return slider_index
	return -1

func update_audio_slider(slider_index: int, pointer_x: float) -> void:
	var value := clampf((pointer_x - 400.0) / 240.0, 0.0, 1.0)
	if slider_index == 0: master_volume = value
	elif slider_index == 1: sfx_volume = value
	else: music_volume = value
	apply_audio_levels()
	queue_redraw()

func music_scroll_limit() -> float:
	return maxf(0.0, float(MUSIC_NAMES.size()) * 54.0 - 470.0)

func handle_music_picker_press(pos: Vector2) -> void:
	if Rect2(270, 665, 460, 50).has_point(pos):
		play_sound(sound_click)
		music_picker_open = false
		queue_redraw()
		return
	if not Rect2(270, 150, 460, 470).has_point(pos): return
	var selected := int(floor((pos.y - 150.0 + music_scroll) / 54.0))
	if selected >= 0 and selected < MUSIC_NAMES.size():
		play_sound(sound_click)
		choose_music(selected)
		queue_redraw()

func handle_local_setup_press(pos: Vector2) -> void:
	if Rect2(300, 220, 52, 42).has_point(pos): play_sound(sound_click); cycle_local_character(1, -1)
	elif Rect2(648, 220, 52, 42).has_point(pos): play_sound(sound_click); cycle_local_character(1, 1)
	elif Rect2(300, 282, 52, 42).has_point(pos): play_sound(sound_click); cycle_local_character(2, -1)
	elif Rect2(648, 282, 52, 42).has_point(pos): play_sound(sound_click); cycle_local_character(2, 1)
	elif Rect2(270, 365, 460, 60).has_point(pos): play_sound(sound_click, 1.12); start_game(2)
	elif Rect2(270, 445, 460, 54).has_point(pos): play_sound(sound_click); local_setup_open = false
	queue_redraw()

func cycle_local_character(player: int, direction: int) -> void:
	var count := selectable_character_count()
	if player == 1:
		p1_character = posmod(p1_character + direction, count)
		while p1_character == p2_character: p1_character = posmod(p1_character + direction, count)
	else:
		p2_character = posmod(p2_character + direction, count)
		while p2_character == p1_character: p2_character = posmod(p2_character + direction, count)

func _draw() -> void:
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), ui_background())
	draw_set_transform(view_offset())
	if mode == 0:
		draw_menu(); return
	draw_rect(Rect2(OX, OY, COLS * CELL, ROWS * CELL), ui_surface())
	for r in walls: draw_rect(r, Color("8892a8") if dark_mode else Color("3b4355"))
	for p in pickups: draw_pickup(p)
	for beam in laser_beams:
		var beam_alpha: float = clampf(float(beam.life) / float(beam.max_life), 0.0, 1.0)
		draw_polyline(beam.points, Color(1.0, 0.08, 0.04, beam_alpha * 0.35), 7.0, true)
		draw_polyline(beam.points, Color(1.0, 0.92, 0.65, beam_alpha), 2.0, true)
	for b in bullets:
		draw_circle(b.pos, BULLET_R, Color("f1f4ff") if dark_mode else Color("111827"))
	for tank_index in tanks.size(): draw_tank(tanks[tank_index])
	for p in particles:
		var alpha: float = clampf(p.life / p.max_life, 0.0, 1.0)
		var pc: Color = p.color; pc.a = alpha
		draw_circle(p.pos, 3.0 + alpha * 3.0, pc)
	draw_string(ThemeDB.fallback_font, Vector2(26, 43), "TANK  TROUBLE", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, ui_text())
	draw_string(ThemeDB.fallback_font, Vector2(455, 43), "%d  :  %d" % scores, HORIZONTAL_ALIGNMENT_LEFT, -1, 27, ui_text())
	var mode_text := ("隐藏模式" if ai_count == 5 else "游戏开发部") if mode == 1 else ("本地双人" if mode == 2 else "BOSS: 优香")
	draw_string(ThemeDB.fallback_font, Vector2(835, 40), mode_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ui_muted())
	if mode == 3 and tanks.size() > 1 and tanks[1].alive:
		draw_string(ThemeDB.fallback_font, Vector2(790, 68), "BOSS 耐久", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("6f2ca8"))
		for hp_index in int(tanks[1].max_hp):
			var hp_color := Color("8e44d6") if hp_index < int(tanks[1].hp) else Color("d8d8d8")
			draw_rect(Rect2(875 + hp_index * 25, 54, 18, 12), hp_color)
			draw_rect(Rect2(875 + hp_index * 25, 54, 18, 12), Color("333333"), false, 1.0)
	draw_touch_controls()
	if not mobile:
		draw_string(ThemeDB.fallback_font, Vector2(205, H - 12.0), "拖动左摇杆移动 · 点击右侧开火 / 鼠标右键 · WASD备用 · Esc暂停", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("666666"))
	if paused:
		if music_picker_open:
			draw_rect(Rect2(0, 0, W, H), ui_background())
			draw_music_picker()
		elif pause_settings_open:
			draw_rect(Rect2(0, 0, W, H), ui_background())
			draw_settings()
		else:
			draw_neu_panel(Rect2(300, 190, 400, 330), 26.0)
			draw_string(ThemeDB.fallback_font, Vector2(350, 258), "游戏暂停", HORIZONTAL_ALIGNMENT_CENTER, 300, 31, ui_text())
			draw_button(Rect2(330, 290, 340, 52), "继续游戏（Esc）", Color("46a96b"))
			draw_button(Rect2(330, 355, 340, 52), "设置", Color("5d8df7"))
			draw_button(Rect2(330, 420, 340, 52), "返回主页（M）", Color("8e44d6"))
	elif round_over:
		draw_neu_panel(Rect2(190, 300, 620, 170), 26.0)
		var sub := "轻触或按空格开始下一局" if mobile else "按空格开始下一局"
		draw_string(ThemeDB.fallback_font, Vector2(220, 370), round_message, HORIZONTAL_ALIGNMENT_CENTER, 560, 27, ui_text())
		draw_string(ThemeDB.fallback_font, Vector2(300, 426), sub, HORIZONTAL_ALIGNMENT_CENTER, 400, 17, ui_muted())
	elif countdown > 0.0:
		var count_text := "GO!" if countdown < 0.7 else str(ceili((countdown - 0.7) / 0.7))
		var count_center := Vector2(W / 2.0, H / 2.0)
		var count_font := ThemeDB.fallback_font
		draw_circle(count_center, 54, Color(1, 1, 1, 0.88))
		var count_baseline := count_center.y + count_font.get_ascent(48) * 0.5
		draw_string(count_font, Vector2(count_center.x - 55.0, count_baseline), count_text, HORIZONTAL_ALIGNMENT_CENTER, 110, 48, Color("333333"))
		var skip_hint := "点击屏幕或按空格跳过" if mobile else "按空格跳过"
		draw_string(count_font, Vector2(count_center.x - 150.0, count_center.y + 82.0), skip_hint, HORIZONTAL_ALIGNMENT_CENTER, 300, 15, ui_muted())

func view_offset() -> Vector2:
	return (get_viewport_rect().size - Vector2(W, H)) * 0.5

func ui_background() -> Color:
	return Color("171b26") if dark_mode else Color("e9edf7")

func ui_surface() -> Color:
	return Color("242a39") if dark_mode else Color("edf1fa")

func ui_text() -> Color:
	return Color("eef2ff") if dark_mode else Color("30384d")

func ui_muted() -> Color:
	return Color("a9b2c8") if dark_mode else Color("68738c")

func ui_shadow() -> Color:
	return Color(0.02, 0.025, 0.045, 0.72) if dark_mode else Color(0.38, 0.44, 0.58, 0.25)

func ui_highlight() -> Color:
	return Color(0.34, 0.39, 0.52, 0.28) if dark_mode else Color(1.0, 1.0, 1.0, 0.92)

func draw_round_rect(rect: Rect2, color: Color, radius: float) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	var corner := maxi(0, int(radius))
	style.corner_radius_top_left = corner
	style.corner_radius_top_right = corner
	style.corner_radius_bottom_left = corner
	style.corner_radius_bottom_right = corner
	draw_style_box(style, rect)

func draw_neu_panel(rect: Rect2, radius := 28.0) -> void:
	draw_round_rect(Rect2(rect.position + Vector2(10, 12), rect.size), ui_shadow(), radius)
	draw_round_rect(Rect2(rect.position - Vector2(4, 4), rect.size), ui_highlight(), radius)
	draw_round_rect(rect, ui_surface(), radius)

func draw_neu_inset(rect: Rect2, radius := 18.0) -> void:
	draw_round_rect(rect, ui_shadow(), radius)
	draw_round_rect(Rect2(rect.position + Vector2(3, 3), rect.size - Vector2(6, 6)), ui_background(), maxf(2.0, radius - 3.0))

func draw_menu() -> void:
	if music_picker_open:
		draw_music_picker()
		return
	if settings_open:
		draw_settings()
		return
	if local_setup_open:
		draw_local_setup()
		return
	draw_neu_panel(Rect2(175, 30, 650, 690), 34.0)
	draw_circle(Vector2(232, 82), 22.0, Color("67a5ff"))
	draw_circle(Vector2(768, 82), 8.0, Color("69dfdf"))
	draw_circle(Vector2(792, 82), 8.0, Color("a884ff"))
	draw_string(ThemeDB.fallback_font, Vector2(235, 90), "TANK  TROUBLE", HORIZONTAL_ALIGNMENT_CENTER, 530, 42, ui_text())
	draw_setting_row(155, "地图宽度", str(COLS), 38.0)
	draw_setting_row(201, "地图高度", str(ROWS), 38.0)
	draw_setting_row(247, "电脑数量", str(ai_count), 38.0)
	var challenge_label := "隐藏模式：优香 VS 游戏开发部全员" if ai_count == 5 else "挑战游戏开发部"
	draw_button(Rect2(270, 315, 460, 54), challenge_label, Color("46a96b"))
	var boss_label := "BOSS: 优香（角色已解锁）" if boss_character_unlocked else "BOSS: 优香（击败后解锁）"
	draw_button(Rect2(270, 381, 460, 54), boss_label, Color("8e44d6"))
	draw_button(Rect2(270, 447, 460, 54), "本地双人对战", Color("ff5c74"))
	draw_button(Rect2(270, 513, 460, 54), "设置", Color("537a8a"))

func draw_settings() -> void:
	draw_neu_panel(Rect2(175, 26, 650, 728 if mobile else 628), 34.0)
	draw_string(ThemeDB.fallback_font, Vector2(235, 92), "游戏设置", HORIZONTAL_ALIGNMENT_CENTER, 530, 38, ui_text())
	var settings_subtitle := "声音 · 外观 · 手机触控" if mobile else "声音 · 外观"
	draw_string(ThemeDB.fallback_font, Vector2(300, 132), settings_subtitle, HORIZONTAL_ALIGNMENT_CENTER, 400, 17, ui_muted())
	draw_audio_slider(180, "总音量", master_volume)
	draw_audio_slider(240, "音效", sfx_volume)
	draw_audio_slider(300, "音乐", music_volume)
	draw_string(ThemeDB.fallback_font, Vector2(245, 388), "背景曲目", HORIZONTAL_ALIGNMENT_RIGHT, 110, 17, ui_muted())
	draw_button(Rect2(370, 360, 260, 42), MUSIC_NAMES[music_index], Color("7b72e9"))
	if mobile:
		draw_setting_row(420, "按钮高度", ["高", "中", "低"][touch_height_index])
		draw_setting_row(480, "按钮间距", ["紧凑", "标准", "宽"][touch_spacing_index])
	draw_setting_row(540 if mobile else 420, "深色模式", "开启" if dark_mode else "关闭")
	var save_label := "保存并返回暂停菜单" if pause_settings_open else "保存并返回主页"
	draw_button(Rect2(270, 625 if mobile else 505, 460, 54), save_label, Color("5d8df7"))

func draw_music_picker() -> void:
	draw_neu_panel(Rect2(175, 26, 650, 728), 34.0)
	draw_string(ThemeDB.fallback_font, Vector2(235, 86), "选择背景音乐", HORIZONTAL_ALIGNMENT_CENTER, 530, 34, ui_text())
	draw_string(ThemeDB.fallback_font, Vector2(300, 122), "滚轮或手指上下滑动 · 点击立即试听", HORIZONTAL_ALIGNMENT_CENTER, 400, 15, ui_muted())
	draw_neu_inset(Rect2(250, 140, 500, 490), 22.0)
	for track_index in MUSIC_NAMES.size():
		var row_y := 150.0 + float(track_index) * 54.0 - music_scroll
		if row_y + 46.0 <= 140.0 or row_y >= 630.0: continue
		var selected := track_index == music_index
		var row_color := Color("657fe8") if selected else ui_surface()
		draw_round_rect(Rect2(270, row_y, 460, 46), row_color.lerp(ui_surface(), 0.12 if selected else 0.0), 18.0)
		var number_text := "%02d" % (track_index + 1)
		draw_string(ThemeDB.fallback_font, Vector2(286, row_y + 29), number_text, HORIZONTAL_ALIGNMENT_LEFT, 42, 14, Color("dfe7ff") if selected else ui_muted())
		draw_string(ThemeDB.fallback_font, Vector2(330, row_y + 30), MUSIC_NAMES[track_index], HORIZONTAL_ALIGNMENT_LEFT, 330, 18, Color("ffffff") if selected else ui_text())
		if selected: draw_string(ThemeDB.fallback_font, Vector2(650, row_y + 29), "正在播放", HORIZONTAL_ALIGNMENT_RIGHT, 62, 12, Color("ffffff"))
	# 用面板色遮住平滑滚动时越过列表上下边界的半行。
	draw_round_rect(Rect2(250, 128, 500, 12), ui_surface(), 6.0)
	draw_round_rect(Rect2(250, 630, 500, 25), ui_surface(), 8.0)
	draw_button(Rect2(270, 665, 460, 50), "返回设置", Color("5d8df7"))

func draw_local_setup() -> void:
	draw_neu_panel(Rect2(175, 52, 650, 560), 34.0)
	draw_string(ThemeDB.fallback_font, Vector2(235, 105), "本地双人角色选择", HORIZONTAL_ALIGNMENT_CENTER, 530, 38, ui_text())
	draw_string(ThemeDB.fallback_font, Vector2(300, 158), "双方不能选择相同角色", HORIZONTAL_ALIGNMENT_CENTER, 400, 17, ui_muted())
	draw_character_row(220, "玩家一", p1_character, 42.0)
	draw_character_row(282, "玩家二", p2_character, 42.0)
	draw_button(Rect2(270, 365, 460, 60), "开始双人对战", Color("ff5c74"))
	draw_button(Rect2(270, 445, 460, 54), "返回主页", Color("777777"))
	var hint := "已解锁优香" if boss_character_unlocked else "击败 Boss 后可选择优香"
	draw_string(ThemeDB.fallback_font, Vector2(250, 545), hint, HORIZONTAL_ALIGNMENT_CENTER, 500, 16, ui_muted())

func draw_setting_row(y: float, label: String, value: String, row_height := 42.0) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(245, y + row_height * 0.5 + 7), label, HORIZONTAL_ALIGNMENT_RIGHT, 110, 17, ui_muted())
	draw_button(Rect2(370, y, 52, row_height), "−", Color("888888"))
	draw_neu_inset(Rect2(434, y, 132, row_height), row_height / 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(438, y + row_height * 0.5 + 8), value, HORIZONTAL_ALIGNMENT_CENTER, 124, 18, ui_text())
	draw_button(Rect2(578, y, 52, row_height), "+", Color("888888"))

func draw_audio_slider(y: float, label: String, value: float) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(245, y + 28), label, HORIZONTAL_ALIGNMENT_RIGHT, 110, 17, ui_muted())
	var track := Rect2(400, y + 13, 240, 16)
	draw_neu_inset(track, 8.0)
	var fill_width := maxf(0.0, track.size.x * value)
	if fill_width > 1.0: draw_round_rect(Rect2(track.position, Vector2(fill_width, track.size.y)), Color("618df7").lerp(Color("a36cff"), value), 8.0)
	var knob := Vector2(track.position.x + track.size.x * value, track.get_center().y)
	draw_circle(knob + Vector2(3, 4), 12.0, Color(0.02, 0.04, 0.1, 0.22))
	draw_circle(knob, 12.0, Color("eef2ff") if not dark_mode else Color("d9e1f5"))
	draw_string(ThemeDB.fallback_font, Vector2(650, y + 28), "%d%%" % int(round(value * 100.0)), HORIZONTAL_ALIGNMENT_LEFT, 58, 16, ui_text())

func draw_character_row(y: float, label: String, character_index: int, row_height := 38.0) -> void:
	var data := character_data(character_index)
	draw_string(ThemeDB.fallback_font, Vector2(180, y + row_height * 0.5 + 7), label, HORIZONTAL_ALIGNMENT_RIGHT, 100, 17, ui_muted())
	draw_button(Rect2(300, y, 52, row_height), "‹", Color("888888"))
	draw_round_rect(Rect2(360, y, 280, row_height), ui_surface(), row_height / 2.0)
	var border_color: Color = Color("222222") if character_index == 4 else data.color
	draw_rect(Rect2(360, y, 280, row_height), border_color, false, 2.0)
	draw_character_thumbnail(data.portrait, Vector2(385, y + row_height / 2.0), minf(32.0, row_height - 6.0))
	draw_string(ThemeDB.fallback_font, Vector2(410, y + row_height * 0.5 + 7), data.name, HORIZONTAL_ALIGNMENT_CENTER, 215, 17, ui_text())
	draw_button(Rect2(648, y, 52, row_height), "›", Color("888888"))

func draw_character_thumbnail(portrait: Texture2D, center: Vector2, max_side: float) -> void:
	var source_size := portrait.get_size()
	var scale_factor := minf(max_side / source_size.x, max_side / source_size.y)
	var display_size := source_size * scale_factor
	var portrait_rect := Rect2(center - display_size / 2.0, display_size)
	draw_texture_rect(portrait, portrait_rect, false)

func draw_button(r: Rect2, text: String, color: Color) -> void:
	draw_round_rect(Rect2(r.position + Vector2(6, 7), r.size), ui_shadow(), minf(22.0, r.size.y / 2.0))
	draw_round_rect(Rect2(r.position - Vector2(2, 2), r.size), ui_highlight(), minf(22.0, r.size.y / 2.0))
	var face := ui_surface().lerp(color, 0.16 if not dark_mode else 0.25)
	draw_round_rect(r, face, minf(22.0, r.size.y / 2.0))
	draw_string(ThemeDB.fallback_font, r.position + Vector2(8, r.size.y * 0.5 + 8), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 16, 20, ui_text())

func draw_tank(t: Dictionary) -> void:
	if not t.alive:
		for i in 10:
			var v := Vector2.from_angle(i * TAU / 10.0) * 30.0
			draw_line(t.pos, t.pos + v, Color("ffb347"), 3)
		return
	var outer := tank_box_points(t.pos, float(t.angle), TANK_LENGTH, TANK_WIDTH)
	var inner := tank_box_points(t.pos, float(t.angle), TANK_LENGTH - 5.0, TANK_WIDTH - 5.0)
	# The visible hull uses the exact same 28 x 20 oriented rectangle as collision.
	draw_colored_polygon(outer, Color("0b1016"))
	draw_colored_polygon(inner, t.color)
	draw_line(t.pos, t.pos + Vector2.from_angle(t.angle) * 21.0, t.color, 7, true)
	draw_circle(t.pos, 4, Color("192330"))
	if t.portrait != null:
		draw_tank_portrait(t.pos, t.portrait)
	if t.weapon != "normal":
		draw_string(ThemeDB.fallback_font, t.pos + Vector2(-20, -25), weapon_code(t.weapon), HORIZONTAL_ALIGNMENT_CENTER, 40, 11, Color("222222"))

func draw_tank_portrait(tank_pos: Vector2, portrait: Texture2D) -> void:
	# Keep the portrait upright at the tank center. It is purely visual and never
	# changes the physical 28 x 20 collision rectangle.
	var source_size := portrait.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0: return
	var max_side := clampf(CELL * 0.50, 24.0, 34.0)
	var portrait_scale := minf(max_side / source_size.x, max_side / source_size.y)
	var display_size := source_size * portrait_scale
	var portrait_rect := Rect2(tank_pos - display_size / 2.0, display_size)
	draw_texture_rect(portrait, portrait_rect, false)

func tank_box_points(center: Vector2, angle: float, length: float, width: float) -> PackedVector2Array:
	var forward := Vector2.from_angle(angle) * length / 2.0
	var side := Vector2.from_angle(angle + PI / 2.0) * width / 2.0
	return PackedVector2Array([
		center + forward + side,
		center + forward - side,
		center - forward - side,
		center - forward + side
	])

func draw_pickup(p: Dictionary) -> void:
	var r := Rect2(p.pos - Vector2(15, 15), Vector2(30, 30))
	draw_rect(r, Color("f4c542")); draw_rect(r, Color("333333"), false, 3)
	var center: Vector2 = p.pos
	match p.kind:
		"shotgun":
			for a in [-0.45, 0.0, 0.45]: draw_line(center - Vector2(8, 0), center + Vector2.from_angle(a) * 11, Color("222222"), 2)
		"laser": draw_line(center - Vector2(10, 0), center + Vector2(10, 0), Color("e84141"), 4)
		"minigun":
			for y in [-5.0, 0.0, 5.0]: draw_line(center + Vector2(-9, y), center + Vector2(10, y), Color("222222"), 2)
		"homing":
			draw_arc(center, 9, -1.4, 1.4, 12, Color("222222"), 2); draw_circle(center + Vector2(8, 0), 3, Color("222222"))

func weapon_code(kind: String) -> String:
	return {"shotgun": "S", "laser": "L", "minigun": "M", "homing": "H"}.get(kind, "")


func draw_touch_controls() -> void:
	if mode == 2 and mobile:
		draw_circle(p1_move_center(), 72, Color(0.25, 0.82, 0.65, 0.16))
		draw_circle(p1_move_center() + touch_move * 42, 28, Color(0.35, 0.95, 0.72, 0.42))
		draw_circle(p1_fire_center(), 57, Color(0.25, 0.82, 0.65, 0.20))
		draw_string(ThemeDB.fallback_font, p1_fire_center() + Vector2(-45, 7), "P1 开火", HORIZONTAL_ALIGNMENT_CENTER, 90, 16, Color("27966f"))
		draw_circle(p2_move_center(), 72, Color(1.0, 0.36, 0.45, 0.16))
		draw_circle(p2_move_center() + p2_touch_move * 42, 28, Color(1.0, 0.48, 0.56, 0.42))
		draw_circle(p2_fire_center(), 57, Color(1.0, 0.36, 0.45, 0.20))
		draw_string(ThemeDB.fallback_font, p2_fire_center() + Vector2(-45, 7), "P2 开火", HORIZONTAL_ALIGNMENT_CENTER, 90, 16, Color("cf4054"))
	else:
		draw_circle(p1_move_center(), 76, Color(0.7, 0.8, 0.85, 0.12))
		draw_circle(p1_move_center() + touch_move * 43, 30, Color(0.8, 0.9, 0.9, 0.35))
		draw_circle(single_fire_center(), 64, Color(1.0, 0.36, 0.45, 0.22))
		draw_string(ThemeDB.fallback_font, single_fire_center() + Vector2(-50, 8), "开 火", HORIZONTAL_ALIGNMENT_CENTER, 100, 20, Color("ff8495"))
