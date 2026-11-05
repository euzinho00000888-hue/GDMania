extends Control
## Fundo animado (triângulos translúcidos).

var tris: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i in 26:
		tris.append({"p": Vector2(randf(), randf()), "s": randf_range(0.04, 0.16), "v": randf_range(0.01, 0.04), "r": randf() * TAU, "a": randf_range(0.03, 0.10)})

func _process(delta: float) -> void:
	for t in tris:
		t.p.y -= t.v * delta
		t.r += delta * 0.1
		if t.p.y < -0.2:
			t.p.y = 1.2
			t.p.x = randf()
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UI.BG)
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(0, size.y)]),
		PackedColorArray([Color(0.22, 0.08, 0.24), Color(0.22, 0.08, 0.24), UI.BG, UI.BG]))
	for t in tris:
		var c: Vector2 = Vector2(t.p.x * size.x, t.p.y * size.y)
		var r: float = t.s * size.y
		var pts := PackedVector2Array()
		for k in 3:
			pts.append(c + Vector2(cos(t.r + k * TAU / 3.0), sin(t.r + k * TAU / 3.0)) * r)
		draw_colored_polygon(pts, Color(1, 0.4, 0.7, t.a))
