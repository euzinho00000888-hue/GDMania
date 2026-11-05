class_name Converter
extends RefCounted
## Conversões Chart -> .json do FNF e Chart -> .sm do StepMania.

static func _bpm_at(c: Chart, ms: float) -> float:
	var bpm: float = c.bpm_changes[0][1]
	for b in c.bpm_changes:
		if c.beat0_ms + b[0] <= ms + 0.5:
			bpm = b[1]
	return bpm

## ---------- Chart -> FNF json ----------
static func to_fnf_json(c: Chart, song_name := "") -> String:
	var sections: Array = []
	var notes := c.notes.duplicate()
	var end_ms := c.length_ms() + 1000.0
	var t := 0.0
	var idx := 0
	var last_bpm := -1.0
	while t < end_ms:
		var bpm := _bpm_at(c, t)
		var sec_ms := 60000.0 / bpm * 4.0
		var sn: Array = []
		while idx < notes.size() and notes[idx].t < t + sec_ms:
			var n = notes[idx]
			sn.append([snappedf(n.t, 0.01), n.lane, snappedf(n.len, 0.01)])
			idx += 1
		sections.append({
			"lengthInSteps": 16, "bpm": bpm, "changeBPM": bpm != last_bpm and last_bpm > 0.0,
			"mustHitSection": true, "typeOfSection": 0, "altAnim": false,
			"sectionNotes": sn,
		})
		last_bpm = bpm
		t += sec_ms
	var name := song_name if song_name != "" else c.title
	var data := {"song": {
		"song": name, "bpm": c.first_bpm(), "speed": maxf(1.0, c.scroll_speed),
		"needsVoices": true, "player1": "bf", "player2": "dad", "gfVersion": "gf",
		"stage": "stage", "validScore": true, "notes": sections,
	}}
	return JSON.stringify(data, "  ")

## ---------- Chart -> StepMania .sm ----------
const DIVS := 48   # linhas por beat (resolução 192nd)

static func _fmt(f: float) -> String:
	return String.num(f, 3)

static func to_sm(c: Chart, music_file := "inst.ogg") -> String:
	var rows := {}   # row_index -> Array[4] chars
	var max_row := 0
	var get_row := func(r: int) -> Array:
		if not rows.has(r):
			rows[r] = ["0", "0", "0", "0"]
		return rows[r]
	for n in c.notes:
		var r := roundi(c.ms_to_beat(n.t) * DIVS)
		r = maxi(r, 0)
		var row: Array = get_row.call(r)
		if n.len > 1.0:
			var r2 := maxi(roundi(c.ms_to_beat(n.t + n.len) * DIVS), r + 1)
			row[n.lane] = "2"
			var tail: Array = get_row.call(r2)
			if tail[n.lane] == "0":
				tail[n.lane] = "3"
			max_row = maxi(max_row, r2)
		else:
			row[n.lane] = "1"
		max_row = maxi(max_row, r)
	var measures := int(max_row / (DIVS * 4)) + 1
	var body: Array = []
	for m in measures:
		var base := m * DIVS * 4
		var q := _best_quant(rows, base)
		var step := DIVS * 4 / q
		var lines: Array = []
		for i in q:
			var r: Array = rows.get(base + i * step, ["0", "0", "0", "0"])
			lines.append("".join(r))
		body.append("\n".join(lines))
	var bpms: Array = []
	for b in c.bpm_changes:
		bpms.append("%s=%s" % [_fmt(c.ms_to_beat(c.beat0_ms + b[0])), _fmt(b[1])])
	var s := "#TITLE:%s;\n#SUBTITLE:;\n#ARTIST:%s;\n#MUSIC:%s;\n#OFFSET:%s;\n" % [
		c.title, c.artist, music_file, _fmt(-c.beat0_ms / 1000.0)]
	s += "#SAMPLESTART:0.000;\n#SAMPLELENGTH:12.000;\n#SELECTABLE:YES;\n"
	s += "#BPMS:%s;\n#STOPS:;\n\n" % ",".join(bpms)
	s += "//---------------dance-single - GDMania----------------\n"
	s += "#NOTES:\n     dance-single:\n     GDMania:\n     %s:\n     %d:\n     0,0,0,0,0:\n" % [
		c.difficulty if c.difficulty != "" else "Edit", maxi(1, c.meter)]
	s += ",\n".join(body) + "\n;\n"
	return s

static func _best_quant(rows: Dictionary, base: int) -> int:
	for q in [4, 8, 12, 16, 24, 32, 48, 64, 96, 192]:
		var step: int = DIVS * 4 / q
		var ok := true
		for r in rows.keys():
			if r >= base and r < base + DIVS * 4 and (r - base) % step != 0:
				ok = false
				break
		if ok:
			return q
	return 192
