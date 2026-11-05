class_name UI
extends RefCounted
## Helpers de interface no estilo osu!.

const PINK := Color("ff66aa")
const PINK_DARK := Color("d6428a")
const PURPLE := Color("6b4bd8")
const ORANGE := Color("ff8a1f")
const BLUE := Color("1f8fff")
const BG := Color("0b0814")
const PANEL := Color(0.05, 0.04, 0.10, 0.82)

static func box(color: Color, radius := 10, border := Color(0, 0, 0, 0), bw := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 22
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		var c := PURPLE
		match st:
			"hover": c = PURPLE.lightened(0.18)
			"pressed": c = PINK
			"disabled": c = Color(0.25, 0.25, 0.3)
			"focus": c = PURPLE
		if st == "focus":
			t.set_stylebox(st, "Button", box(Color(0, 0, 0, 0), 12, Color(1, 1, 1, 0.5), 2))
		else:
			t.set_stylebox(st, "Button", box(c, 12))
	t.set_color("font_color", "Button", Color.WHITE)
	t.set_font_size("font_size", "Button", 24)
	t.set_stylebox("panel", "PanelContainer", box(PANEL, 14))
	t.set_stylebox("normal", "OptionButton", box(PURPLE, 10))
	t.set_stylebox("hover", "OptionButton", box(PURPLE.lightened(0.18), 10))
	t.set_stylebox("pressed", "OptionButton", box(PINK, 10))
	t.set_stylebox("normal", "LineEdit", box(Color(0, 0, 0, 0.5), 8))
	return t

static func button(text: String, color := PURPLE, min_size := Vector2(0, 56), font := 24) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font)
	b.add_theme_stylebox_override("normal", box(color, 12))
	b.add_theme_stylebox_override("hover", box(color.lightened(0.2), 12))
	b.add_theme_stylebox_override("pressed", box(color.darkened(0.2), 12))
	return b

static func label(text: String, size := 22, color := Color.WHITE, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	return l

static func panel(color := PANEL, radius := 14) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(color, radius))
	return p

## Barra superior com botão Voltar e título.
static func header(screen: Control, title: String, back_to := "menu") -> void:
	var back := button("◀  Voltar", PINK_DARK, Vector2(150, 52), 22)
	back.position = Vector2(14, 12)
	back.pressed.connect(func(): Game.goto(back_to))
	screen.add_child(back)
	var t := label(title, 36, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	t.set_anchors_preset(Control.PRESET_TOP_WIDE)
	t.position.y = 10
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(t)

## Seletor de arquivo (nativo quando possível; no Android usa o do próprio Godot).
static func pick_file(host: Node, filters: PackedStringArray, on_pick: Callable, save := false, default_name := "") -> void:
	var fd := FileDialog.new()
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.use_native_dialog = true
	fd.file_mode = FileDialog.FILE_MODE_SAVE_FILE if save else FileDialog.FILE_MODE_OPEN_FILE
	fd.filters = filters
	fd.title = "Salvar" if save else "Escolher arquivo"
	if default_name != "":
		fd.current_file = default_name
	if OS.has_feature("android"):
		OS.request_permissions()
		fd.current_dir = "/storage/emulated/0"
		fd.use_native_dialog = false
	fd.size = Vector2i(900, 560)
	fd.file_selected.connect(func(p): on_pick.call(p))
	fd.canceled.connect(func(): fd.queue_free())
	fd.file_selected.connect(func(_p): fd.queue_free())
	host.add_child(fd)
	fd.popup_centered()

static func _make_dialog(mode: int, title: String) -> FileDialog:
	var fd := FileDialog.new()
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.use_native_dialog = true
	fd.file_mode = mode
	fd.title = title
	if OS.has_feature("android"):
		OS.request_permissions()
		fd.current_dir = "/storage/emulated/0"
		fd.use_native_dialog = false
	fd.size = Vector2i(900, 560)
	return fd

## Seletor de pasta. on_pick recebe o caminho da pasta.
static func pick_dir(host: Node, on_pick: Callable) -> void:
	var fd := _make_dialog(FileDialog.FILE_MODE_OPEN_DIR, "Escolher pasta")
	fd.dir_selected.connect(func(p): on_pick.call(p))
	fd.dir_selected.connect(func(_p): fd.queue_free())
	fd.canceled.connect(func(): fd.queue_free())
	host.add_child(fd)
	fd.popup_centered()

## Seletor de vários arquivos. on_pick recebe um PackedStringArray.
static func pick_files(host: Node, filters: PackedStringArray, on_pick: Callable) -> void:
	var fd := _make_dialog(FileDialog.FILE_MODE_OPEN_FILES, "Escolher arquivos")
	fd.filters = filters
	fd.files_selected.connect(func(ps): on_pick.call(ps))
	fd.files_selected.connect(func(_ps): fd.queue_free())
	fd.canceled.connect(func(): fd.queue_free())
	host.add_child(fd)
	fd.popup_centered()
