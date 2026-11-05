extends Control
## Opções: controles, scroll, velocidade, offset e áudio.

var rebinding := -1
var key_buttons: Array = []

func _ready() -> void:
	UI.header(self, "Opções")
	var sc := ScrollContainer.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.offset_top = 76
	sc.offset_left = 24
	sc.offset_right = -24
	sc.offset_bottom = -12
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 14)
	sc.add_child(v)
	# ---- controles
	v.add_child(_title("Controles (teclado)"))
	var kp := UI.panel()
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	kp.add_child(grid)
	for i in 4:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_child(UI.label(Settings.LANE_NAMES[i], 20, GameColors.lane(i), HORIZONTAL_ALIGNMENT_CENTER))
		var b := UI.button(OS.get_keycode_string(Settings.keys[i]), UI.PURPLE, Vector2(0, 64), 28)
		b.pressed.connect(func(): _start_rebind(i))
		cell.add_child(b)
		key_buttons.append(b)
		grid.add_child(cell)
	v.add_child(kp)
	var reset := UI.button("Restaurar D F J K", UI.PINK_DARK, Vector2(260, 52), 20)
	reset.pressed.connect(func():
		Settings.keys = [KEY_D, KEY_F, KEY_J, KEY_K]
		_refresh_keys()
		Settings.save())
	v.add_child(reset)
	v.add_child(UI.label("No Android a tela inteira vira a hitbox (4 zonas), independente de onde as setas ficam.", 18, Color(1, 1, 1, 0.6)))
	# ---- gameplay
	v.add_child(_title("Jogabilidade"))
	var gp := UI.panel()
	var gv := VBoxContainer.new()
	gv.add_theme_constant_override("separation", 12)
	gp.add_child(gv)
	var opt := OptionButton.new()
	opt.custom_minimum_size = Vector2(0, 56)
	opt.add_item("Automático (PC: downscroll / Android: middlescroll)")
	opt.add_item("Downscroll")
	opt.add_item("Upscroll")
	opt.add_item("Middlescroll")
	opt.selected = ["auto", "down", "up", "middle"].find(Settings.scroll_mode)
	opt.item_selected.connect(func(i):
		Settings.scroll_mode = ["auto", "down", "up", "middle"][i]
		Settings.save())
	gv.add_child(UI.label("Direção do scroll", 20))
	gv.add_child(opt)
	gv.add_child(_slider("Velocidade das notas", 0.5, 5.0, 0.1, Settings.scroll_speed, func(x): Settings.scroll_speed = x, "x"))
	gv.add_child(_slider("Offset de áudio (ms)", -300, 300, 1, Settings.audio_offset_ms, func(x): Settings.audio_offset_ms = int(x), " ms"))
	gv.add_child(_check("Mostrar barras coloridas da hitbox", Settings.show_hitbox_bars, func(b): Settings.show_hitbox_bars = b))
	v.add_child(gp)
	# ---- áudio
	v.add_child(_title("Áudio"))
	var ap := UI.panel()
	var av := VBoxContainer.new()
	av.add_theme_constant_override("separation", 12)
	ap.add_child(av)
	av.add_child(_slider("Volume da música", 0.0, 1.0, 0.05, Settings.music_volume, func(x): Settings.music_volume = x, ""))
	av.add_child(_slider("Volume do hitsound", 0.0, 1.0, 0.05, Settings.hit_volume, func(x): Settings.hit_volume = x, ""))
	av.add_child(_check("Hitsounds", Settings.hitsounds, func(b): Settings.hitsounds = b))
	v.add_child(ap)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 40)
	v.add_child(pad)

func _title(t: String) -> Label:
	return UI.label(t, 30, UI.PINK)

func _slider(title: String, mn: float, mx: float, step: float, val: float, setter: Callable, suffix: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	var l := UI.label("", 20)
	l.custom_minimum_size = Vector2(300, 0)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = step
	s.value = val
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(0, 44)
	var upd := func(x): l.text = "%s: %s%s" % [title, String.num(x, 2 if step < 1 else 0), suffix]
	upd.call(val)
	s.value_changed.connect(func(x):
		setter.call(x)
		upd.call(x)
		Settings.save())
	h.add_child(s)
	return h

func _check(text: String, val: bool, setter: Callable) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = val
	c.custom_minimum_size = Vector2(0, 48)
	c.toggled.connect(func(b):
		setter.call(b)
		Settings.save())
	return c

func _refresh_keys() -> void:
	for i in 4:
		key_buttons[i].text = OS.get_keycode_string(Settings.keys[i])

func _start_rebind(i: int) -> void:
	rebinding = i
	key_buttons[i].text = "Pressione..."

func _input(e: InputEvent) -> void:
	if rebinding >= 0 and e is InputEventKey and e.pressed and not e.echo:
		if e.keycode != KEY_ESCAPE:
			Settings.keys[rebinding] = e.keycode
			Settings.save()
		rebinding = -1
		_refresh_keys()
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("ui_cancel") and rebinding < 0:
		Game.goto("menu")
