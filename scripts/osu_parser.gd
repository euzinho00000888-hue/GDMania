class_name OsuParser
extends RefCounted
## Lê .osu do osu!mania (modo 3, 4 teclas) -> Chart. Retorna null se não for mania 4K.
## O nome do arquivo de áudio fica em chart.get_meta("audio").

static func parse_text(text: String) -> Chart:
	var section := ""
	var meta := {}
	var timing: Array = []
	var objs: Array = []
	for raw in text.replace("\r", "").split("\n"):
		var line := raw.strip_edges()
		if line == "" or line.begins_with("//"):
			continue
		if line.begins_with("[") and line.ends_with("]"):
			section = line.substr(1, line.length() - 2)
			continue
		match section:
			"General", "Metadata", "Difficulty":
				var i := line.find(":")
				if i > 0:
					meta[line.substr(0, i).strip_edges()] = line.substr(i + 1).strip_edges()
			"TimingPoints":
				timing.append(line)
			"HitObjects":
				objs.append(line)
	if str(meta.get("Mode", "0")).to_int() != 3:
		return null
	if int(round(str(meta.get("CircleSize", "4")).to_float())) != 4:
		return null
	if objs.is_empty():
		return null

	var c := Chart.new()
	c.source = "osu"
	c.title = str(meta.get("Title", "Sem título"))
	c.artist = str(meta.get("Artist", ""))
	c.difficulty = str(meta.get("Version", "Normal"))
	c.set_meta("audio", str(meta.get("AudioFilename", "")))

	# BPM: pontos de timing não herdados (beatLength > 0)
	var pts: Array = []
	for tl in timing:
		var parts: PackedStringArray = str(tl).split(",")
		if parts.size() < 2:
			continue
		var beat_len := parts[1].to_float()
		var uninherited := true
		if parts.size() >= 7:
			uninherited = parts[6].strip_edges() == "1"
		if uninherited and beat_len > 0.0:
			pts.append([parts[0].to_float(), 60000.0 / beat_len])
	pts.sort_custom(func(a, b): return a[0] < b[0])
	if pts.is_empty():
		pts = [[0.0, 120.0]]
	c.beat0_ms = pts[0][0]
	c.bpm_changes = []
	for p in pts:
		c.bpm_changes.append([p[0] - c.beat0_ms, p[1]])

	for o in objs:
		var f: PackedStringArray = str(o).split(",")
		if f.size() < 4:
			continue
		var x := f[0].to_float()
		var t := f[2].to_float()
		var type := f[3].to_int()
		var lane := clampi(int(x * 4.0 / 512.0), 0, 3)
		var len_ms := 0.0
		if (type & 128) != 0 and f.size() >= 6:
			var end_t := f[5].split(":")[0].to_float()
			len_ms = maxf(0.0, end_t - t)
		c.notes.append({"t": t, "lane": lane, "len": len_ms})
	c.sort_notes()
	c.meter = clampi(int(c.note_count() / maxf(1.0, c.length_ms() / 1000.0) * 2.0), 1, 20)
	return c
