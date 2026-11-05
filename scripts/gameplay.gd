extends Control
## Tela de jogo: 4 lanes, teclado no PC / hitbox de tela inteira no Android.

const LANE_COLORS := [Color("c24b99"), Color("00e5ff"), Color("12fa05"), Color("f9393f")]
const WINDOWS := [45.0, 90.0, 135.0, 180.0]          # ms: Perfeito, Ótimo, Bom, Ruim
const JUDGE_NAMES := ["PERFEITO", "ÓTIMO", "BOM", "RUIM", "ERRO"]
const JUDGE_COLORS := [Color("6ee7ff"), Color("7dff7a"), Color("ffd24a"), Color("ff9f43"), Color("ff4d5e")]
const JUDGE_ACC := [1.0, 0.75, 0.5, 0.25, 0.0]
const JUDGE_SCORE := [300, 200, 100, 50, 0]
const LEAD_IN := 3.0

var chart: Chart
var song: Dictionary
var notes: Array = []            # runtime: {t, lane, len, state, hold}
var lane_notes: Array = [[], [], [], []]
var lane_ptr := [0, 0, 0, 0]
var lane_down := [false, false, false, false]
var lane_flash := [0.0, 0.0, 0.0, 0.0]
var touch_lane := {}             # touch index -> lane

var inst_player: AudioStreamPlayer
var voices_player: AudioStreamPlayer
var hit_player: AudioStreamPlayer
var has_audio := false
var song_time := -LEAD_IN
var audio_started := false
var paused := false
var finished := false
var end_time := 0.0

var score := 0
var combo := 0
var max_combo := 0
var counts := [0, 0, 0, 0, 0]
var acc_sum := 0.0
var judged := 0
var last_judge := -1
var judge_timer := 0.0
var combo_pop := 0.0
var scroll := "down"
var hitbox := false
var px_per_sec := 600.0
var hit_y := 0.0
var field_x := 0.0
var lane_w := 100.0              # largura da pista das setas (visual)
var hit_w := 100.0               # largura de cada zona de toque (hitbox), independente das setas
var pause_ui: Control
var effects: Array = []          # {lane, t}

func _ready() -> void:
	chart = Game.current_chart
	song = Game.current_song
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	scroll = Settings.effective_scroll()
	hitbox = Settings.is_mobile() or DisplayServer.is_touchscreen_available()
	for n in chart.notes:
		var rn := {"t": n.t, "lane": n.lane, "len": n.len, "state": 0, "hold": false}
		notes.append(rn)
		lane_notes[n.lane].append(rn)
	end_time = (chart.length_ms() / 1000.0) + 1.5
	_setup_audio()
	_layout()
	resized.connect(_layout)
	_build_pause_ui()

func _setup_audio() -> void:
	inst_player = AudioStreamPlayer.new()
	voices_player = AudioStreamPlayer.new()
	hit_player = AudioStreamPlayer.new()
	add_child(inst_player)
	add_child(voices_player)
	add_child(hit_player)
	var inst := Game.load_audio(song.get("inst", ""))
	var voices := Game.load_audio(song.get("voices", ""))
	if inst:
		inst_player.stream = inst
		inst_player.volume_db = linear_to_db(maxf(Settings.music_volume, 0.001))
		has_audio = true
	if voices:
		voices_player.stream = voices
		voices_player.volume_db = linear_to_db(maxf(Settings.music_volume, 0.001))
	hit_player.stream = _make_tick()
	hit_player.volume_db = linear_to_db(maxf(Settings.hit_volume, 0.001))

static func _make_tick() -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = 22050
	var n := 900
	var d := PackedByteArray()
	d.resize(n * 2)
	for i in n:
		var env := 1.0 - float(i) / n
		var v := int(sin(float(i) * 0.35) * env * env * 20000.0)
		d.encode_s16(i * 2, v)
	w.data = d
	return w

func _layout() -> void:
	var s := size
	# setas: tamanho fixo, centralizadas (não dependem da hitbox)
	lane_w = minf(clampf(s.y * 0.19, 90.0, 150.0), s.x / 4.0)
	field_x = (s.x - lane_w * 4.0) * 0.5
	# hitbox: a tela inteira dividida em 4 zonas iguais
	hit_w = s.x / 4.0
	match scroll:
		"up":
			hit_y = s.y * 0.14
		"middle":
			hit_y = s.y * 0.5
		_:
			hit_y = s.y * 0.86
	px_per_sec = s.y * 0.55 * Settings.scroll_speed

## A zona de toque não depende de onde as setas estão desenhadas.
func lane_at_x(x: float) -> int:
	return clampi(int(x / hit_w), 0, 3)

# ------------------------------------------------------------------ entrada
func _input(e: InputEvent) -> void:
	if finished:
		return
	if e.is_action_pressed("ui_cancel") and not e.is_echo():
		toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if paused:
		return
	if e is InputEventKey and not e.echo:
		for i in 4:
			if e.physical_keycode == Settings.keys[i] or e.keycode == Settings.keys[i]:
				_lane_input(i, e.pressed)
	elif e is InputEventScreenTouch:
		if e.pressed:
			if _pause_btn_rect().has_point(e.position):
				toggle_pause()
				return
			var l := lane_at_x(e.position.x)
			touch_lane[e.index] = l
			_lane_input(l, true)
		else:
			if touch_lane.has(e.index):
				_lane_input(touch_lane[e.index], false)
				touch_lane.erase(e.index)
	elif e is InputEventScreenDrag:
		if touch_lane.has(e.index):
			var l := lane_at_x(e.position.x)
			if l != touch_lane[e.index]:
				_lane_input(touch_lane[e.index], false)
				touch_lane[e.index] = l
				_lane_input(l, true)
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and hitbox == false:
		if e.pressed and _pause_btn_rect().has_point(e.position):
			toggle_pause()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and not finished:
		toggle_pause()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and not paused and not finished and audio_started:
		toggle_pause()

func _pause_btn_rect() -> Rect2:
	return Rect2(size.x - 84, 8, 76, 52)

func _lane_input(lane: int, pressed: bool) -> void:
	if pressed:
		if lane_down[lane]:
			return
		lane_down[lane] = true
		lane_flash[lane] = 1.0
		_try_hit(lane)
	else:
		lane_down[lane] = false
		_release(lane)

# ------------------------------------------------------------------ lógica
var lane_draw := [0, 0, 0, 0]
var last_raw := -1.0
var stall := 0.0
var active_holds: Array = []

func _now_ms() -> float:
	return song_time * 1000.0 - float(Settings.audio_offset_ms)

func _try_hit(lane: int) -> void:
	var now := _now_ms()
	var arr: Array = lane_notes[lane]
	var i: int = lane_ptr[lane]
	while i < arr.size():
		var n = arr[i]
		if n.state == 0:
			var dt: float = n.t - now
			if dt > WINDOWS[3]:
				break
			if dt >= -WINDOWS[3]:
				_hit_note(n, absf(dt))
				return
		i += 1

func _hit_note(n: Dictionary, dt: float) -> void:
	var j := 3
	for k in 4:
		if dt <= WINDOWS[k]:
			j = k
			break
	_register(j)
	effects.append({"lane": n.lane, "t": 0.0, "j": j})
	if Settings.hitsounds:
		hit_player.play()
	voices_player.volume_db = linear_to_db(maxf(Settings.music_volume, 0.001))
	if n.len > 1.0:
		n.state = 2
		active_holds.append(n)
	else:
		n.state = 1

func _release(_lane: int) -> void:
	pass

func _register(j: int) -> void:
	counts[j] += 1
	judged += 1
	acc_sum += JUDGE_ACC[j]
	last_judge = j
	judge_timer = 0.6
	if j <= 3:
		combo += 1
		max_combo = maxi(max_combo, combo)
		combo_pop = 1.0
		score += int(JUDGE_SCORE[j] * (1.0 + minf(combo, 100.0) / 50.0))
	else:
		combo = 0
		if voices_player.stream:
			voices_player.volume_db = -80.0

func _process(delta: float) -> void:
	for l in 4:
		lane_flash[l] = maxf(0.0, lane_flash[l] - delta * 4.0)
	judge_timer = maxf(0.0, judge_timer - delta)
	combo_pop = maxf(0.0, combo_pop - delta * 5.0)
	if paused or finished:
		queue_redraw()
		return
	song_time += delta
	if has_audio:
		if not audio_started and song_time >= 0.0:
			audio_started = true
			inst_player.play()
			if voices_player.stream:
				voices_player.play()
		elif audio_started and inst_player.playing:
			var raw := inst_player.get_playback_position()
			if absf(raw - last_raw) < 0.0001:
				stall += delta
			else:
				stall = 0.0
			last_raw = raw
			if stall < 0.25:   # se o áudio não avança (driver mudo), segue pelo relógio
				var a := raw + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
				var diff := a - song_time
				if absf(diff) > 0.15:
					song_time = a
				elif absf(diff) > 0.005:
					song_time += diff * 0.1
	var now := _now_ms()
	# erros (notas perdidas)
	for l in 4:
		var arr: Array = lane_notes[l]
		var i: int = lane_ptr[l]
		while i < arr.size():
			var n = arr[i]
			if n.state != 0:
				i += 1
				continue
			if n.t < now - WINDOWS[3]:
				n.state = 3
				_register(4)
				i += 1
			else:
				break
		lane_ptr[l] = i
		var d: int = lane_draw[l]
		while d < arr.size() and arr[d].state != 0 and arr[d].state != 2 and arr[d].t + arr[d].len < now - 300.0:
			d += 1
		lane_draw[l] = d
	# holds
	for n in active_holds.duplicate():
		var end: float = n.t + n.len
		if now >= end - 20.0:
			n.state = 1
			score += 100
			active_holds.erase(n)
			effects.append({"lane": n.lane, "t": 0.0, "j": 0})
		elif not lane_down[n.lane] and now < end - 120.0:
			n.state = 4
			active_holds.erase(n)
			_register(4)
		else:
			score += 0
	for e in effects:
		e.t += delta
	effects = effects.filter(func(e): return e.t < 0.35)
	if song_time > end_time:
		_finish()
	queue_redraw()

func accuracy() -> float:
	var total := maxi(1, notes.size())
	return acc_sum / float(total)

func rank_for(acc: float) -> String:
	if acc >= 0.98 and counts[4] == 0:
		return "SS"
	if acc >= 0.93:
		return "S"
	if acc >= 0.85:
		return "A"
	if acc >= 0.75:
		return "B"
	if acc >= 0.60:
		return "C"
	return "D"

func _finish() -> void:
	finished = true
	inst_player.stop()
	voices_player.stop()
	var acc := accuracy()
	Game.last_result = {
		"title": chart.title, "artist": chart.artist, "diff": chart.difficulty,
		"score": score, "acc": acc, "counts": counts.duplicate(), "max_combo": max_combo,
		"rank": rank_for(acc), "total": notes.size(),
	}
	Game.goto("results")

# ------------------------------------------------------------------ pausa
func _build_pause_ui() -> void:
	pause_ui = ColorRect.new()
	pause_ui.color = Color(0, 0, 0, 0.7)
	pause_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_ui.visible = false
	add_child(pause_ui)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(320, 0)
	box.position = Vector2(-160, -120)
	box.add_theme_constant_override("separation", 14)
	pause_ui.add_child(box)
	var t := Label.new()
	t.text = "PAUSADO"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 40)
	box.add_child(t)
	for pair in [["Continuar", toggle_pause], ["Reiniciar", _retry], ["Sair", _quit]]:
		var b := Button.new()
		b.text = pair[0]
		b.custom_minimum_size = Vector2(0, 64)
		b.add_theme_font_size_override("font_size", 26)
		b.pressed.connect(pair[1])
		box.add_child(b)

func toggle_pause() -> void:
	if finished:
		return
	paused = not paused
	pause_ui.visible = paused
	inst_player.stream_paused = paused
	voices_player.stream_paused = paused
	if paused:
		for l in 4:
			lane_down[l] = false
		touch_lane.clear()

func _retry() -> void:
	Game.goto("gameplay")

func _quit() -> void:
	Game.goto("song_select")

# ------------------------------------------------------------------ desenho
func _y_for(t_ms: float, now: float) -> float:
	var off := (t_ms - now) / 1000.0 * px_per_sec
	return hit_y + off if scroll == "up" else hit_y - off

func _arrow(c: Vector2, r: float, lane: int, col: Color) -> void:
	var pts := PackedVector2Array()
	match lane:
		0: pts = [c + Vector2(-r, 0), c + Vector2(r * 0.6, -r), c + Vector2(r * 0.6, r)]
		1: pts = [c + Vector2(0, r), c + Vector2(-r, -r * 0.6), c + Vector2(r, -r * 0.6)]
		2: pts = [c + Vector2(0, -r), c + Vector2(-r, r * 0.6), c + Vector2(r, r * 0.6)]
		_: pts = [c + Vector2(r, 0), c + Vector2(-r * 0.6, -r), c + Vector2(-r * 0.6, r)]
	draw_colored_polygon(pts, col)

func _draw() -> void:
	if chart == null:
		return
	var font := get_theme_default_font()
	var s := size
	var now := _now_ms()
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.04, 0.03, 0.08))
	# zonas de toque (hitbox): independentes das setas, ocupam a tela toda
	if hitbox and Settings.show_hitbox_bars:
		for l in 4:
			var hx := l * hit_w
			var hcol: Color = LANE_COLORS[l]
			draw_rect(Rect2(hx, 0, hit_w, s.y), Color(hcol, 0.05 + lane_flash[l] * 0.12 + (0.08 if lane_down[l] else 0.0)))
			draw_line(Vector2(hx, 0), Vector2(hx, s.y), Color(1, 1, 1, 0.05), 2.0)
	# pista das setas
	for l in 4:
		var x := field_x + l * lane_w
		var col: Color = LANE_COLORS[l]
		draw_rect(Rect2(x, 0, lane_w, s.y), Color(col, 0.10 + lane_flash[l] * 0.25 + (0.12 if lane_down[l] else 0.0)))
		draw_line(Vector2(x, 0), Vector2(x, s.y), Color(1, 1, 1, 0.10), 2.0)
	draw_line(Vector2(field_x + 4 * lane_w, 0), Vector2(field_x + 4 * lane_w, s.y), Color(1, 1, 1, 0.10), 2.0)
	# linha de acerto / receptores
	var nh := minf(lane_w * 0.42, 64.0)
	var nw := lane_w * 0.82
	for l in 4:
		var cx := field_x + l * lane_w + lane_w * 0.5
		var col: Color = LANE_COLORS[l]
		var r := Rect2(cx - nw * 0.5, hit_y - nh * 0.5, nw, nh)
		draw_rect(r, Color(col, 0.55 if lane_down[l] else 0.12))
		draw_rect(r, Color(col, 0.9), false, 3.0)
		_arrow(Vector2(cx, hit_y), nh * 0.32, l, Color(1, 1, 1, 0.55))
	# notas
	for l in 4:
		var cx := field_x + l * lane_w + lane_w * 0.5
		var col: Color = LANE_COLORS[l]
		var arr: Array = lane_notes[l]
		for i in range(lane_draw[l], arr.size()):
			var n = arr[i]
			var y := _y_for(n.t, now)
			var oob: bool = (y < -nh) if scroll != "up" else (y > s.y + nh)
			if oob:
				break
			if n.state == 1 and n.len <= 1.0:
				continue
			var head_y := y
			if n.len > 1.0:
				var y_end := _y_for(n.t + n.len, now)
				if n.state == 2:
					head_y = hit_y
				var top := minf(head_y, y_end)
				var bh := absf(y_end - head_y)
				var alpha := 0.45 if n.state in [0, 2] else 0.15
				draw_rect(Rect2(cx - nw * 0.22, top, nw * 0.44, bh), Color(col, alpha + (0.3 if n.state == 2 else 0.0)))
				if n.state == 1:
					continue
			if n.state == 3 or n.state == 4:
				col = col.darkened(0.6)
			var r := Rect2(cx - nw * 0.5, head_y - nh * 0.5, nw, nh)
			draw_rect(r, Color(col, 0.95))
			draw_rect(r, Color(1, 1, 1, 0.8), false, 2.0)
			_arrow(Vector2(cx, head_y), nh * 0.32, l, Color(1, 1, 1, 0.95))
			col = LANE_COLORS[l]
	# efeitos de acerto
	for e in effects:
		var cx: float = field_x + float(e.lane) * lane_w + lane_w * 0.5
		var k: float = e.t / 0.35
		draw_arc(Vector2(cx, hit_y), nh * (0.6 + k), 0, TAU, 32, Color(JUDGE_COLORS[e.j], 1.0 - k), 3.0)
	# HUD
	var cxs := s.x * 0.5
	draw_string(font, Vector2(16, 44), "%08d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color.WHITE)
	draw_string(font, Vector2(16, 76), "%.2f%%" % (accuracy() * 100.0 if judged > 0 else 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, 0.8))
	draw_string(font, Vector2(16, 104), "%s  [%s]" % [chart.title, chart.difficulty], HORIZONTAL_ALIGNMENT_LEFT, int(s.x * 0.4), 18, Color(1, 1, 1, 0.5))
	var prog := clampf(song_time / maxf(end_time, 1.0), 0.0, 1.0)
	draw_rect(Rect2(0, 0, s.x * prog, 5), Color("ff66aa"))
	# botão de pausa
	var pr := _pause_btn_rect()
	draw_rect(pr, Color(0, 0, 0, 0.5))
	draw_rect(pr, Color(1, 1, 1, 0.6), false, 2.0)
	draw_rect(Rect2(pr.position.x + 24, pr.position.y + 14, 8, 24), Color.WHITE)
	draw_rect(Rect2(pr.position.x + 44, pr.position.y + 14, 8, 24), Color.WHITE)
	# combo e julgamento
	var cy := s.y * 0.38 if scroll != "up" else s.y * 0.62
	if combo > 1:
		var fs := int(56 + combo_pop * 14)
		draw_string(font, Vector2(0, cy), str(combo), HORIZONTAL_ALIGNMENT_CENTER, s.x, fs, Color(1, 1, 1, 0.9))
	if judge_timer > 0.0 and last_judge >= 0:
		draw_string(font, Vector2(0, cy + 44), JUDGE_NAMES[last_judge], HORIZONTAL_ALIGNMENT_CENTER, s.x, 30, Color(JUDGE_COLORS[last_judge], minf(1.0, judge_timer * 3.0)))
	if song_time < 0.0:
		draw_string(font, Vector2(0, s.y * 0.5), str(int(ceil(-song_time))), HORIZONTAL_ALIGNMENT_CENTER, s.x, 120, Color(1, 1, 1, 0.8))
