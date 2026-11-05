class_name FnfParser
extends RefCounted
## Lê .json do Friday Night Funkin' (formato clássico e variantes) -> Chart.
## side: "player" (padrão), "opponent" ou "both" (mistura os dois lados em 4 lanes).

static func parse_text(text: String, side := "player") -> Chart:
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return null
	var song: Dictionary
	var title := "FNF Song"
	if typeof(data.get("song")) == TYPE_DICTIONARY:
		song = data["song"]
		title = str(song.get("song", title))
	else:
		song = data
		title = str(data.get("song", title))
	if not song.has("notes"):
		return null
	var c := Chart.new()
	c.source = "fnf"
	c.title = title
	c.artist = ""
	c.scroll_speed = float(song.get("speed", 1.0))
	var bpm := float(song.get("bpm", 120.0))
	c.bpm_changes = [[0.0, bpm]]
	var section_start := 0.0
	var cur_bpm := bpm
	for sec in song["notes"]:
		if typeof(sec) != TYPE_DICTIONARY:
			continue
		if sec.get("changeBPM", false) and float(sec.get("bpm", 0)) > 0.0:
			cur_bpm = float(sec["bpm"])
			if section_start == 0.0:
				c.bpm_changes[0][1] = cur_bpm
			else:
				c.bpm_changes.append([section_start, cur_bpm])
		var must: bool = sec.get("mustHitSection", true)
		for n in sec.get("sectionNotes", []):
			if typeof(n) != TYPE_ARRAY or n.size() < 2:
				continue
			var raw := int(n[1])
			if raw < 0:
				continue   # eventos/notas especiais
			var is_player_lane := (raw < 4) == must   # lado do jogador
			var lane := raw % 4
			if side == "player" and not is_player_lane:
				continue
			if side == "opponent" and is_player_lane:
				continue
			var len_ms := float(n[2]) if n.size() > 2 and (typeof(n[2]) == TYPE_INT or typeof(n[2]) == TYPE_FLOAT) else 0.0
			if len_ms < 0.0:
				len_ms = 0.0
			c.notes.append({"t": float(n[0]), "lane": lane, "len": len_ms})
		var steps := float(sec.get("lengthInSteps", 16))
		section_start += (60000.0 / cur_bpm) / 4.0 * steps
	c.sort_notes()
	# remove notas duplicadas (mesmo tempo e lane)
	var out: Array = []
	for n in c.notes:
		if out.size() > 0 and absf(out[-1].t - n.t) < 1.0 and out[-1].lane == n.lane:
			continue
		out.append(n)
	c.notes = out
	c.meter = clampi(int(c.note_count() / maxf(1.0, c.length_ms() / 1000.0) * 2.0), 1, 20)
	return c
