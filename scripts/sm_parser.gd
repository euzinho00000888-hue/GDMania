class_name SmParser
extends RefCounted
## Lê StepMania .sm e .ssc (dance-single, 4 lanes) -> lista de Chart (uma por dificuldade).

## Lista ordenada [[TAG, valor], ...] (necessária para o .ssc, onde a ordem importa).
static func _tag_list(text: String) -> Array:
	var out: Array = []
	var clean := ""
	for line in text.replace("\r", "").split("\n"):
		var i := line.find("//")
		clean += (line.substr(0, i) if i >= 0 else line) + "\n"
	var pos := 0
	while true:
		var s := clean.find("#", pos)
		if s < 0:
			break
		var colon := clean.find(":", s)
		if colon < 0:
			break
		var semi := clean.find(";", colon)
		if semi < 0:
			break
		var key := clean.substr(s + 1, colon - s - 1).strip_edges().to_upper()
		var val := clean.substr(colon + 1, semi - colon - 1)
		out.append([key, val])
		pos = semi + 1
	return out

## Retorna {TAG: [valores...]} (NOTES pode aparecer várias vezes)
static func _tags(text: String) -> Dictionary:
	var res := {}
	for kv in _tag_list(text):
		if not res.has(kv[0]):
			res[kv[0]] = []
		res[kv[0]].append(kv[1])
	return res

static func _parse_pairs(v: String) -> Array:
	var out: Array = []
	for p in v.replace("\n", "").split(",", false):
		var kv := p.split("=")
		if kv.size() == 2:
			out.append([kv[0].strip_edges().to_float(), kv[1].strip_edges().to_float()])
	out.sort_custom(func(a, b): return a[0] < b[0])
	return out

## Meta do arquivo: {title, artist, music, offset, banner, background}
static func meta(tags: Dictionary) -> Dictionary:
	var g := func(k: String, d := "") -> String:
		return str(tags[k][0]).strip_edges() if tags.has(k) else d
	return {
		"title": g.call("TITLE", "Sem título"),
		"artist": g.call("ARTIST", ""),
		"music": g.call("MUSIC", ""),
		"offset": g.call("OFFSET", "0").to_float(),
		"banner": g.call("BANNER", ""),
		"background": g.call("BACKGROUND", ""),
	}

static func meta_of(text: String) -> Dictionary:
	return meta(_tags(text))

static func parse_text(text: String) -> Array:
	var list := _tag_list(text)
	for kv in list:
		if kv[0] == "NOTEDATA":
			return _parse_ssc(list)
	return _parse_sm(text)

static func _parse_sm(text: String) -> Array:
	var tags := _tags(text)
	var m := meta(tags)
	var bpms := _parse_pairs(str(tags.get("BPMS", ["0=120"])[0]))
	if bpms.is_empty():
		bpms = [[0.0, 120.0]]
	var stops := _parse_pairs(str(tags.get("STOPS", [""])[0]))
	var charts: Array = []
	for nt in tags.get("NOTES", []):
		var parts: PackedStringArray = nt.split(":")
		if parts.size() < 6:
			continue
		if parts[0].strip_edges() != "dance-single":
			continue
		var c := Chart.new()
		c.source = "sm"
		c.title = m.title
		c.artist = m.artist
		c.difficulty = parts[2].strip_edges() if parts[2].strip_edges() != "" else parts[1].strip_edges()
		c.meter = parts[3].strip_edges().to_int()
		_build(c, parts[5], bpms, stops, m.offset)
		charts.append(c)
	return charts

## .ssc: tags globais, depois blocos #NOTEDATA com tags próprias e #NOTES com as notas.
static func _parse_ssc(list: Array) -> Array:
	var g := {}
	var cur := {}
	var in_chart := false
	var seen_chart := false
	var charts: Array = []
	for kv in list:
		var k: String = kv[0]
		var v: String = kv[1]
		if k == "NOTEDATA":
			in_chart = true
			seen_chart = true
			cur = {}
			continue
		if not in_chart:
			if not seen_chart:
				g[k] = v
			continue
		if k == "NOTES":
			in_chart = false
			if str(cur.get("STEPSTYPE", "")).strip_edges() != "dance-single":
				continue
			var bpm_s: String = str(cur.get("BPMS", g.get("BPMS", "0=120")))
			var stop_s: String = str(cur.get("STOPS", g.get("STOPS", "")))
			var bpms := _parse_pairs(bpm_s)
			if bpms.is_empty():
				bpms = [[0.0, 120.0]]
			var stops := _parse_pairs(stop_s)
			var c := Chart.new()
			c.source = "sm"
			c.title = str(g.get("TITLE", "Sem título")).strip_edges()
			c.artist = str(g.get("ARTIST", "")).strip_edges()
			var diff := str(cur.get("DIFFICULTY", "")).strip_edges()
			c.difficulty = diff if diff != "" else str(cur.get("DESCRIPTION", "Normal")).strip_edges()
			c.meter = str(cur.get("METER", "1")).strip_edges().to_int()
			var off: float = str(cur.get("OFFSET", g.get("OFFSET", "0"))).strip_edges().to_float()
			_build(c, v, bpms, stops, off)
			charts.append(c)
			continue
		cur[k] = v
	return charts

static func _beat_to_sec(beat: float, bpms: Array, stops: Array) -> float:
	var t := 0.0
	var last_beat := 0.0
	var bpm: float = bpms[0][1]
	for b in bpms:
		if b[0] >= beat:
			break
		if b[0] > last_beat:
			t += (b[0] - last_beat) * 60.0 / bpm
			last_beat = b[0]
		bpm = b[1]
	t += (beat - last_beat) * 60.0 / bpm
	for s in stops:
		if s[0] < beat:
			t += s[1]
	return t

static func _build(c: Chart, data: String, bpms: Array, stops: Array, offset: float) -> void:
	c.bpm_changes = []
	for b in bpms:
		c.bpm_changes.append([_beat_to_sec(b[0], bpms, stops) * 1000.0, b[1]])
	c.bpm_changes[0][0] = 0.0
	var shift_ms := -offset * 1000.0
	c.beat0_ms = shift_ms   # momento (no áudio) em que o beat 0 toca
	var measures := data.strip_edges().split(",")
	var holds := [-1.0, -1.0, -1.0, -1.0]
	var hold_idx := [-1, -1, -1, -1]
	for mi in measures.size():
		var rows: Array = []
		for r in measures[mi].split("\n"):
			var rr: String = r.strip_edges()
			if rr.length() >= 4:
				rows.append(rr)
		var n := rows.size()
		for ri in n:
			var beat := mi * 4.0 + 4.0 * ri / float(n)
			var ms := _beat_to_sec(beat, bpms, stops) * 1000.0 + shift_ms
			var row: String = rows[ri]
			for lane in 4:
				var ch := row[lane]
				if ch == "1":
					c.notes.append({"t": ms, "lane": lane, "len": 0.0})
				elif ch == "2" or ch == "4":
					c.notes.append({"t": ms, "lane": lane, "len": 0.0})
					hold_idx[lane] = c.notes.size() - 1
					holds[lane] = ms
				elif ch == "3" and hold_idx[lane] >= 0:
					c.notes[hold_idx[lane]].len = maxf(0.0, ms - holds[lane])
					hold_idx[lane] = -1
	c.sort_notes()
