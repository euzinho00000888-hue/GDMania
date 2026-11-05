extends Control
## Menu inicial estilo osu!.

var pulse := 0.0
var logo_center := Vector2.ZERO
var logo_r := 200.0
var tips := [
	"Em Jogar → Importar: pastas do StepMania, .osz, ou .json do Psych Engine + inst.ogg / voices.ogg.",
	"No Android, a tela inteira é dividida em 4 barras: toque na barra para apertar a seta.",
	"Use os conversores para transformar .sm em .json do FNF e vice-versa.",
	"Nas opções você troca as teclas (D F J K) e o tipo de scroll.",
]
var tip_idx := 0
var tip_label: Label
var logo_btn: Button

func _ready() -> void:
	var info := UI.label("Você tem %d músicas disponíveis!" % Game.library.size(), 22, Color.WHITE)
	info.position = Vector2(24, 14)
	add_child(info)
	tip_label = UI.label(tips[0], 20, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_CENTER)
	tip_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	tip_label.position.y = -52
	tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(tip_label)
	var t := Timer.new()
	t.wait_time = 5.0
	t.autostart = true
	t.timeout.connect(func():
		tip_idx = (tip_idx + 1) % tips.size()
		tip_label.text = tips[tip_idx])
	add_child(t)
	var col := VBoxContainer.new()
	col.name = "Buttons"
	col.add_theme_constant_override("separation", 16)
	add_child(col)
	var defs := [["Jogar", "song_select", UI.PURPLE], ["Importar música", "importer", UI.PURPLE], ["Conversores", "converter", UI.PURPLE], ["Opções", "settings", UI.PURPLE]]
	for d in defs:
		var b := UI.button(d[0], d[2], Vector2(380, 84), 34)
		b.pressed.connect(func(): Game.goto(d[1]))
		col.add_child(b)
	if not OS.has_feature("web") and not Settings.is_mobile():
		var q := UI.button("Sair", UI.PINK_DARK, Vector2(380, 70), 30)
		q.pressed.connect(func(): get_tree().quit())
		col.add_child(q)
	logo_btn = Button.new()
	logo_btn.flat = true
	logo_btn.focus_mode = Control.FOCUS_NONE
	logo_btn.pressed.connect(func(): Game.goto("song_select"))
	add_child(logo_btn)
	resized.connect(_layout)
	_layout()

func _layout() -> void:
	logo_r = minf(size.y * 0.30, size.x * 0.20)
	logo_center = Vector2(size.x * 0.30, size.y * 0.48)
	var col: Control = get_node("Buttons")
	col.position = Vector2(size.x * 0.56, size.y * 0.5 - col.size.y * 0.5 - 10)
	logo_btn.position = logo_center - Vector2(logo_r, logo_r)
	logo_btn.size = Vector2(logo_r, logo_r) * 2.0

func _process(delta: float) -> void:
	pulse = lerpf(pulse, 0.0, delta * 4.0)
	if int(Time.get_ticks_msec() / 600) % 2 == 0 and pulse < 0.01:
		pulse = 1.0
	var col: Control = get_node("Buttons")
	col.position.y = size.y * 0.5 - col.size.y * 0.5
	queue_redraw()

func _draw() -> void:
	var r := logo_r * (1.0 + pulse * 0.03)
	draw_circle(logo_center, r * 1.12, Color(1, 1, 1, 0.9))
	draw_circle(logo_center, r, UI.BLUE)
	for k in 6:
		var a := Time.get_ticks_msec() / 4000.0 + k * TAU / 6.0
		var c := logo_center + Vector2(cos(a), sin(a)) * r * 0.55
		var pts := PackedVector2Array()
		for q in 3:
			pts.append(c + Vector2(cos(a * 2.0 + q * TAU / 3.0), sin(a * 2.0 + q * TAU / 3.0)) * r * 0.22)
		draw_colored_polygon(pts, Color(1, 1, 1, 0.12))
	var font := get_theme_default_font()
	var fs := int(r * 0.36)
	draw_string(font, logo_center + Vector2(-r, fs * 0.33), "gdmania!", HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, Color.WHITE)
