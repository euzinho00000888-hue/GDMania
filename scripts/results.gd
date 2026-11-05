extends Control
## Tela de resultados.

func _ready() -> void:
	var r: Dictionary = Game.last_result
	var new_best := Game.save_best(Game.current_song.folder, Game.current_chart.difficulty, r)
	var left := VBoxContainer.new()
	left.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	left.offset_left = 80
	left.offset_right = 760
	left.offset_top = -250
	left.offset_bottom = 250
	left.add_theme_constant_override("separation", 10)
	add_child(left)
	left.add_child(UI.label(r.title, 40))
	left.add_child(UI.label("%s  [%s]" % [r.artist, r.diff], 22, Color(1, 1, 1, 0.7)))
	left.add_child(UI.label("%08d" % r.score + ("   NOVO RECORDE!" if new_best else ""), 54, UI.PINK))
	left.add_child(UI.label("Precisão %.2f%%    Combo máx. %dx" % [r.acc * 100.0, r.max_combo], 28))
	var names := ["PERFEITO", "ÓTIMO", "BOM", "RUIM", "ERRO"]
	var cols := [Color("6ee7ff"), Color("7dff7a"), Color("ffd24a"), Color("ff9f43"), Color("ff4d5e")]
	for i in 5:
		left.add_child(UI.label("%s   %d" % [names[i], r.counts[i]], 26, cols[i]))
	var rank := UI.label(r.rank, 220, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	rank.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	rank.offset_left = -440
	rank.offset_right = -40
	rank.offset_top = -170
	add_child(rank)
	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -90
	bar.offset_left = 24
	bar.offset_right = -24
	bar.offset_bottom = -16
	bar.add_theme_constant_override("separation", 14)
	add_child(bar)
	var back := UI.button("◀  Músicas", UI.PINK_DARK, Vector2(240, 64), 26)
	back.pressed.connect(func(): Game.goto("song_select"))
	bar.add_child(back)
	var retry := UI.button("Tentar de novo", UI.PINK, Vector2(280, 64), 26)
	retry.pressed.connect(func(): Game.goto("gameplay"))
	bar.add_child(retry)
