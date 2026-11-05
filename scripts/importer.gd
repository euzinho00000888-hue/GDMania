extends Control
## Importar chart (.json FNF / .sm StepMania) + inst + voices (opcional).

var chart_path := ""
var inst_path := ""
var voices_path := ""
var labels := {}
var status: Label

func _ready() -> void:
	UI.header(self, "Importar música")
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	col.anchor_left = 0.5
	col.anchor_right = 0.5
	col.offset_left = -440
	col.offset_right = 440
	col.offset_top = -200
	col.offset_bottom = 220
	col.add_theme_constant_override("separation", 16)
	add_child(col)
	col.add_child(UI.label("Chart do FNF (.json) ou do StepMania (.sm), mais o áudio.", 22, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_CENTER))
	_row(col, "chart", "Chart (.json / .sm / .ssc / .osu)  *obrigatório", PackedStringArray(["*.json,*.sm,*.ssc,*.osu ; Charts"]))
	_row(col, "inst", "inst.ogg  *obrigatório", PackedStringArray(["*.ogg,*.mp3,*.wav ; Áudio"]))
	_row(col, "voices", "voices.ogg  (opcional)", PackedStringArray(["*.ogg,*.mp3,*.wav ; Áudio"]))
	var go := UI.button("IMPORTAR", UI.PINK, Vector2(0, 72), 32)
	go.pressed.connect(_import)
	col.add_child(go)
	status = UI.label("", 22, Color(1, 1, 1, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(status)

func _row(parent: Control, key: String, title: String, filters: PackedStringArray) -> void:
	var p := UI.panel()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(UI.label(title, 22))
	var path := UI.label("(nenhum arquivo)", 18, Color(1, 1, 1, 0.55))
	path.clip_text = true
	path.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(path)
	labels[key] = path
	var b := UI.button("Escolher", UI.PURPLE, Vector2(160, 56), 22)
	b.pressed.connect(func():
		UI.pick_file(self, filters, func(p2):
			set(key + "_path", p2)
			path.text = p2.get_file()
			path.add_theme_color_override("font_color", Color("9dff9d"))))
	h.add_child(b)
	parent.add_child(p)

func _import() -> void:
	var r := Game.import_files(chart_path, inst_path, voices_path)
	if r.begins_with("OK:"):
		status.text = "Importado: %s ✔" % r.substr(3)
		status.add_theme_color_override("font_color", Color("9dff9d"))
	else:
		status.text = r
		status.add_theme_color_override("font_color", Color("ff6b6b"))
