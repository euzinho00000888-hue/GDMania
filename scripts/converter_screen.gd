extends Control
## Conversores: StepMania (.sm) -> FNF (.json) e FNF (.json) -> StepMania (.sm).

var sm_charts: Array = []
var sm_path := ""
var sm_diff: OptionButton
var sm_label: Label
var sm_status: Label
var fnf_chart: Chart
var fnf_label: Label
var fnf_status: Label
var fnf_side: OptionButton
var fnf_music: LineEdit

func _ready() -> void:
	UI.header(self, "Conversores")
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_top = 80
	row.offset_left = 24
	row.offset_right = -24
	row.offset_bottom = -24
	row.add_theme_constant_override("separation", 20)
	add_child(row)
	row.add_child(_card_sm())
	row.add_child(_card_fnf())

func _card_sm() -> Control:
	var p := UI.panel()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	v.add_child(UI.label("StepMania (.sm)  →  FNF (.json)", 28, UI.PINK))
	sm_label = UI.label("(nenhum .sm escolhido)", 18, Color(1, 1, 1, 0.6))
	v.add_child(sm_label)
	var pick := UI.button("Escolher .sm", UI.PURPLE)
	pick.pressed.connect(func(): UI.pick_file(self, PackedStringArray(["*.sm ; StepMania"]), _on_sm))
	v.add_child(pick)
	v.add_child(UI.label("Dificuldade:", 20))
	sm_diff = OptionButton.new()
	sm_diff.custom_minimum_size = Vector2(0, 52)
	v.add_child(sm_diff)
	var go := UI.button("Converter e salvar .json", UI.PINK)
	go.pressed.connect(_do_sm)
	v.add_child(go)
	sm_status = UI.label("", 20)
	sm_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sm_status)
	return p

func _card_fnf() -> Control:
	var p := UI.panel()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	v.add_child(UI.label("FNF (.json)  →  StepMania (.sm)", 28, UI.PINK))
	fnf_label = UI.label("(nenhum .json escolhido)", 18, Color(1, 1, 1, 0.6))
	v.add_child(fnf_label)
	var pick := UI.button("Escolher .json", UI.PURPLE)
	pick.pressed.connect(func(): UI.pick_file(self, PackedStringArray(["*.json ; FNF chart"]), _on_fnf))
	v.add_child(pick)
	v.add_child(UI.label("Lado das notas:", 20))
	fnf_side = OptionButton.new()
	fnf_side.custom_minimum_size = Vector2(0, 52)
	fnf_side.add_item("Jogador (bf)")
	fnf_side.add_item("Oponente")
	fnf_side.add_item("Os dois lados")
	v.add_child(fnf_side)
	v.add_child(UI.label("Nome do áudio (#MUSIC):", 20))
	fnf_music = LineEdit.new()
	fnf_music.text = "inst.ogg"
	fnf_music.custom_minimum_size = Vector2(0, 52)
	v.add_child(fnf_music)
	var go := UI.button("Converter e salvar .sm", UI.PINK)
	go.pressed.connect(_do_fnf)
	v.add_child(go)
	fnf_status = UI.label("", 20)
	fnf_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(fnf_status)
	return p

func _say(l: Label, msg: String, ok := true) -> void:
	l.text = msg
	l.add_theme_color_override("font_color", Color("9dff9d") if ok else Color("ff6b6b"))

func _on_sm(path: String) -> void:
	sm_path = path
	sm_charts = SmParser.parse_text(Game.read_text(path))
	sm_diff.clear()
	for c in sm_charts:
		sm_diff.add_item("%s  (★%d, %d notas)" % [c.difficulty, c.meter, c.note_count()])
	if sm_charts.is_empty():
		_say(sm_status, "Nenhum chart dance-single (4 setas) encontrado.", false)
	else:
		sm_label.text = path.get_file()
		_say(sm_status, "%d dificuldade(s) encontrada(s)." % sm_charts.size())

func _do_sm() -> void:
	if sm_charts.is_empty():
		_say(sm_status, "Escolha um .sm primeiro.", false)
		return
	var c: Chart = sm_charts[sm_diff.selected]
	var txt := Converter.to_fnf_json(c)
	var default := "%s-%s.json" % [Game.sanitize(c.title), c.difficulty.to_lower()]
	UI.pick_file(self, PackedStringArray(["*.json ; FNF chart"]), func(out):
		_say(sm_status, _write(out, txt), true), true, default)

func _on_fnf(path: String) -> void:
	fnf_chart = FnfParser.parse_text(Game.read_text(path), ["player", "opponent", "both"][fnf_side.selected])
	fnf_label.text = path.get_file()
	fnf_label.set_meta("path", path)
	if fnf_chart == null:
		_say(fnf_status, "Esse .json não parece um chart do FNF.", false)
	else:
		_say(fnf_status, "%d notas lidas." % fnf_chart.note_count())

func _do_fnf() -> void:
	if not fnf_label.has_meta("path"):
		_say(fnf_status, "Escolha um .json primeiro.", false)
		return
	var c := FnfParser.parse_text(Game.read_text(fnf_label.get_meta("path")), ["player", "opponent", "both"][fnf_side.selected])
	if c == null:
		_say(fnf_status, "Chart inválido.", false)
		return
	var txt := Converter.to_sm(c, fnf_music.text)
	UI.pick_file(self, PackedStringArray(["*.sm ; StepMania"]), func(out):
		_say(fnf_status, _write(out, txt), true), true, Game.sanitize(c.title) + ".sm")

func _write(path: String, txt: String) -> String:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		# alternativa: pasta interna do app
		DirAccess.make_dir_recursive_absolute("user://exports")
		var alt := "user://exports/" + path.get_file()
		f = FileAccess.open(alt, FileAccess.WRITE)
		if f == null:
			return "Não consegui salvar o arquivo."
		f.store_string(txt)
		return "Salvo em %s" % ProjectSettings.globalize_path(alt)
	f.store_string(txt)
	return "Salvo em %s ✔" % path
