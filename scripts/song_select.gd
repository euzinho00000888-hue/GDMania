extends Control
## Seleção de música no estilo osu! (lista à direita, informações à esquerda).

var sel_song := 0
var sel_chart := 0
var filtered: Array = []
var list_box: VBoxContainer
var scroll_c: ScrollContainer
var info_title: Label
var info_artist: Label
var info_meta: Label
var best_box: VBoxContainer
var search: LineEdit
var empty_msg: Label
var status_label: Label
var import_ui: Control

func _ready() -> void:
	var left := UI.panel(Color(0.03, 0.02, 0.08, 0.78), 0)
	left.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	left.anchor_right = 0.40
	left.offset_right = 0
	add_child(left)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 6)
	left.add_child(lv)
	lv.add_child(Control.new())
	lv.get_child(0).custom_minimum_size = Vector2(0, 56)
	info_title = UI.label("", 30)
	info_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lv.add_child(info_title)
	info_artist = UI.label("", 22, Color(1, 1, 1, 0.75))
	lv.add_child(info_artist)
	info_meta = UI.label("", 18, Color(1, 0.85, 0.5))
	lv.add_child(info_meta)
	lv.add_child(UI.label("Ranking local", 20, UI.PINK))
	best_box = VBoxContainer.new()
	best_box.add_theme_constant_override("separation", 4)
	lv.add_child(best_box)
	status_label = UI.label("", 18, Color(1, 1, 1, 0.8))
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lv.add_child(status_label)
	# topo
	var back := UI.button("◀  Voltar", UI.PINK_DARK, Vector2(150, 48), 22)
	back.position = Vector2(10, 8)
	back.pressed.connect(func(): Game.goto("menu"))
	add_child(back)
	search = LineEdit.new()
	search.placeholder_text = "Digite para buscar..."
	search.anchor_left = 0.42
	search.anchor_right = 1.0
	search.offset_left = 0
	search.offset_right = -12
	search.offset_top = 10
	search.offset_bottom = 54
	search.text_changed.connect(func(_t): _refilter())
	add_child(search)
	# lista
	scroll_c = ScrollContainer.new()
	scroll_c.anchor_left = 0.42
	scroll_c.anchor_right = 1.0
	scroll_c.anchor_bottom = 1.0
	scroll_c.offset_top = 64
	scroll_c.offset_bottom = -86
	scroll_c.offset_right = -6
	scroll_c.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll_c)
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 8)
	scroll_c.add_child(list_box)
	empty_msg = UI.label("Nenhuma música ainda.\nVá em Importar música.", 28, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_CENTER)
	empty_msg.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	empty_msg.anchor_left = 0.7
	empty_msg.anchor_right = 0.7
	empty_msg.offset_left = -230
	empty_msg.offset_right = 230
	add_child(empty_msg)
	# barra inferior
	var bar := HBoxContainer.new()
	bar.anchor_top = 1.0
	bar.anchor_right = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_top = -76
	bar.offset_left = 10
	bar.offset_right = -10
	bar.offset_bottom = -8
	bar.add_theme_constant_override("separation", 10)
	add_child(bar)
	var bdefs := [["Importar", _open_import_menu, UI.PURPLE],
		["Aleatório", _random, UI.PURPLE], ["Opções", func(): Game.goto("settings"), UI.PURPLE],
		["Excluir", _delete, Color("8a2a3a")]]
	for d in bdefs:
		var b := UI.button(d[0], d[2], Vector2(150, 64), 22)
		b.pressed.connect(d[1])
		bar.add_child(b)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(sp)
	var play := UI.button("JOGAR ▶", UI.PINK, Vector2(260, 64), 30)
	play.pressed.connect(_play)
	bar.add_child(play)
	_build_import_menu()
	_refilter()

func _refilter() -> void:
	var q := search.text.strip_edges().to_lower()
	filtered = []
	for s in Game.library:
		if q == "" or s.title.to_lower().contains(q) or s.artist.to_lower().contains(q):
			filtered.append(s)
	sel_song = clampi(sel_song, 0, maxi(0, filtered.size() - 1))
	_rebuild()

func _rebuild() -> void:
	for c in list_box.get_children():
		c.queue_free()
	empty_msg.visible = filtered.is_empty()
	for i in filtered.size():
		var s: Dictionary = filtered[i]
		var is_sel := i == sel_song
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = "%s\n%s" % [s.title, s.artist if s.artist != "" else "%d dificuldade(s)" % s.charts.size()]
		b.custom_minimum_size = Vector2(0, 84 if not is_sel else 96)
		b.add_theme_font_size_override("font_size", 22)
		var col := UI.PINK if is_sel else UI.ORANGE
		b.add_theme_stylebox_override("normal", UI.box(col, 8))
		b.add_theme_stylebox_override("hover", UI.box(col.lightened(0.15), 8))
		b.add_theme_stylebox_override("pressed", UI.box(col.darkened(0.15), 8))
		b.add_theme_color_override("font_color", Color.WHITE)
		b.pressed.connect(func():
			sel_song = i
			sel_chart = 0
			_rebuild())
		list_box.add_child(b)
		if is_sel:
			for ci in s.charts.size():
				var c: Chart = s.charts[ci]
				var cb := Button.new()
				cb.alignment = HORIZONTAL_ALIGNMENT_LEFT
				cb.text = "   %s    ★ %d    (%d notas)" % [c.difficulty, c.meter, c.note_count()]
				cb.custom_minimum_size = Vector2(0, 62)
				var cc := Color("2a8fdc") if ci == sel_chart else Color("2a3a5c")
				cb.add_theme_stylebox_override("normal", UI.box(cc, 8))
				cb.add_theme_stylebox_override("hover", UI.box(cc.lightened(0.15), 8))
				cb.add_theme_stylebox_override("pressed", UI.box(cc.darkened(0.1), 8))
				cb.pressed.connect(func():
					if sel_chart == ci:
						_play()
					else:
						sel_chart = ci
						_rebuild())
				var wrap := MarginContainer.new()
				wrap.add_theme_constant_override("margin_left", 40)
				wrap.add_child(cb)
				list_box.add_child(wrap)
	_update_info()

func _cur_chart() -> Chart:
	if filtered.is_empty():
		return null
	var s: Dictionary = filtered[sel_song]
	return s.charts[clampi(sel_chart, 0, s.charts.size() - 1)]

func _update_info() -> void:
	for c in best_box.get_children():
		c.queue_free()
	var ch := _cur_chart()
	if ch == null:
		info_title.text = ""
		info_artist.text = ""
		info_meta.text = ""
		return
	var s: Dictionary = filtered[sel_song]
	info_title.text = s.title
	info_artist.text = s.artist
	var secs := int(ch.length_ms() / 1000.0)
	info_meta.text = "Duração: %d:%02d   BPM: %d   Notas: %d   Fonte: %s" % [secs / 60, secs % 60, int(ch.first_bpm()), ch.note_count(), {"sm": "StepMania", "osu": "osu!mania", "fnf": "FNF"}.get(ch.source, "FNF")]
	var best := Game.get_best(s.folder, ch.difficulty)
	if best.is_empty():
		best_box.add_child(UI.label("Sem recorde ainda.", 20, Color(1, 1, 1, 0.6)))
	else:
		best_box.add_child(UI.label("%s   %08d   %.2f%%   combo %dx" % [best.rank, best.score, best.acc * 100.0, best.combo], 22))
	if s.inst == "":
		best_box.add_child(UI.label("⚠ Sem inst.ogg nesta pasta.", 20, Color("ff6b6b")))

func _random() -> void:
	if filtered.is_empty():
		return
	sel_song = randi() % filtered.size()
	sel_chart = 0
	_rebuild()

func _delete() -> void:
	if filtered.is_empty():
		return
	Game.delete_song(filtered[sel_song])
	_refilter()

func _play() -> void:
	var ch := _cur_chart()
	if ch == null:
		return
	Game.play(filtered[sel_song], ch)

# ------------------------------------------------------------------ importação
func _build_import_menu() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.visible = false
	add_child(dim)
	import_ui = dim
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(cc)
	var p := UI.panel(Color(0.08, 0.06, 0.16, 0.98), 16)
	p.custom_minimum_size = Vector2(620, 0)
	cc.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	v.add_child(UI.label("Importar músicas", 32, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	var d1 := UI.label("Pasta do StepMania (.sm/.ssc + áudio), pack com várias músicas, ou pasta com .osz / FNF.", 18, Color(1, 1, 1, 0.7))
	d1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d1)
	var b1 := UI.button("Importar pasta", UI.PINK, Vector2(0, 64), 26)
	b1.pressed.connect(_pick_folder)
	v.add_child(b1)
	var d2 := UI.label("Arquivos avulsos: .osz, .sm/.ssc/.osu, .json do Psych Engine + inst.ogg e voices.ogg (selecione todos de uma vez).", 18, Color(1, 1, 1, 0.7))
	d2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d2)
	var b2 := UI.button("Importar arquivos", UI.PINK, Vector2(0, 64), 26)
	b2.pressed.connect(_pick_files)
	v.add_child(b2)
	var b3 := UI.button("Importação manual (chart + inst + voices)", UI.PURPLE, Vector2(0, 56), 22)
	b3.pressed.connect(func(): Game.goto("importer"))
	v.add_child(b3)
	var b4 := UI.button("Cancelar", Color("3a3a5c"), Vector2(0, 52), 22)
	b4.pressed.connect(func(): import_ui.visible = false)
	v.add_child(b4)

func _open_import_menu() -> void:
	import_ui.visible = true

func _pick_folder() -> void:
	import_ui.visible = false
	UI.pick_dir(self, func(path): _do_import(func(): return Game.import_folder(path)))

func _pick_files() -> void:
	import_ui.visible = false
	var filters := PackedStringArray(["*.osz,*.sm,*.ssc,*.osu,*.json,*.ogg,*.mp3,*.wav ; Músicas e charts", "* ; Todos os arquivos"])
	UI.pick_files(self, filters, func(paths): _do_import(func(): return Game.import_loose(paths)))

func _do_import(job: Callable) -> void:
	_set_status("Importando...", Color(1, 1, 1, 0.8))
	await get_tree().process_frame
	await get_tree().process_frame
	var r: String = job.call()
	if r.begins_with("OK:"):
		_set_status("Importado: %s" % r.substr(3), Color("9dff9d"))
	else:
		_set_status(r, Color("ff6b6b"))
	_refilter()

func _set_status(t: String, c: Color) -> void:
	status_label.text = t
	status_label.add_theme_color_override("font_color", c)
