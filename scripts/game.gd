extends Node
## Estado global, biblioteca de músicas e troca de telas.

signal library_changed

var library: Array = []          # [{folder, title, artist, charts: [Chart], inst, voices}]
var current_song: Dictionary = {}
var current_chart: Chart = null
var last_result: Dictionary = {}
var root: Node = null            # main.gd define

# ---------------------------------------------------------------- utilidades
static func sanitize(s: String) -> String:
	var out := ""
	for ch in s.strip_edges():
		if ch.is_valid_identifier() or ch in "- .()[]":
			out += ch
		else:
			out += "_"
	return out if out != "" else "song"

static func read_text(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f else ""

static func read_bytes(path: String) -> PackedByteArray:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_buffer(f.get_length()) if f else PackedByteArray()

static func load_audio(path: String) -> AudioStream:
	if path == "" or not FileAccess.file_exists(path):
		return null
	var ext := path.get_extension().to_lower()
	if ext == "ogg":
		return AudioStreamOggVorbis.load_from_file(path)
	if ext == "mp3":
		var s := AudioStreamMP3.new()
		s.data = read_bytes(path)
		return s
	if ext == "wav":
		return _load_wav(path)
	return null

## WAV PCM 16-bit simples.
static func _load_wav(path: String) -> AudioStream:
	var b := read_bytes(path)
	if b.size() < 44 or b.slice(0, 4).get_string_from_ascii() != "RIFF":
		return null
	var w := AudioStreamWAV.new()
	var pos := 12
	var channels := 1
	while pos + 8 <= b.size():
		var id := b.slice(pos, pos + 4).get_string_from_ascii()
		var sz := b.decode_u32(pos + 4)
		if id == "fmt ":
			channels = b.decode_u16(pos + 10)
			w.mix_rate = b.decode_u32(pos + 12)
			w.format = AudioStreamWAV.FORMAT_16_BITS
			w.stereo = channels == 2
		elif id == "data":
			w.data = b.slice(pos + 8, pos + 8 + sz)
			return w
		pos += 8 + sz + (sz % 2)
	return null

# ---------------------------------------------------------------- biblioteca
func scan_library() -> void:
	library.clear()
	var base := Settings.songs_dir()
	var d := DirAccess.open(base)
	if d == null:
		library_changed.emit()
		return
	for folder in d.get_directories():
		var entry := _scan_folder(base + "/" + folder, folder)
		if not entry.is_empty():
			library.append(entry)
	library.sort_custom(func(a, b): return a.title.to_lower() < b.title.to_lower())
	library_changed.emit()

func _scan_folder(path: String, folder: String) -> Dictionary:
	var d := DirAccess.open(path)
	if d == null:
		return {}
	var charts: Array = []
	var title := folder
	var artist := ""
	var music_hint := ""
	var sm_file := ""
	var ssc_file := ""
	var osu_files: Array = []
	var json_files: Array = []
	var audios: Array = []
	for f in d.get_files():
		var low := f.to_lower()
		match low.get_extension():
			"sm": sm_file = f
			"ssc": ssc_file = f
			"osu": osu_files.append(f)
			"json":
				if low != "meta.json":
					json_files.append(f)
			"ogg", "mp3", "wav": audios.append(f)
	# StepMania: .ssc tem prioridade sobre .sm (como no StepMania)
	var step_file := ""
	var cs: Array = []
	if ssc_file != "":
		cs = SmParser.parse_text(read_text(path + "/" + ssc_file))
		if not cs.is_empty():
			step_file = ssc_file
	if cs.is_empty() and sm_file != "":
		cs = SmParser.parse_text(read_text(path + "/" + sm_file))
		if not cs.is_empty():
			step_file = sm_file
	if not cs.is_empty():
		var m: Dictionary = SmParser.meta_of(read_text(path + "/" + step_file))
		music_hint = str(m.music)
		title = str(cs[0].title)
		artist = str(cs[0].artist)
		for c in cs:
			c.set_meta("file", path + "/" + step_file)
			charts.append(c)
	# osu!mania
	for f in osu_files:
		var oc := OsuParser.parse_text(read_text(path + "/" + f))
		if oc == null:
			continue
		oc.set_meta("file", path + "/" + f)
		charts.append(oc)
		if music_hint == "":
			music_hint = str(oc.get_meta("audio", ""))
		if title == folder:
			title = oc.title
			artist = oc.artist
	# FNF / Psych Engine
	for f in json_files:
		var c := FnfParser.parse_text(read_text(path + "/" + f), "player")
		if c != null:
			c.difficulty = _fnf_diff_from_name(f.to_lower())
			c.set_meta("file", path + "/" + f)
			charts.append(c)
			title = c.title if c.title != "FNF Song" else folder
	if charts.is_empty():
		return {}
	# áudio
	var inst := ""
	var voices := ""
	for f in audios:
		var low2: String = f.to_lower()
		if low2.begins_with("voices"):
			voices = path + "/" + f
		elif low2.begins_with("inst"):
			inst = path + "/" + f
	if music_hint != "" and FileAccess.file_exists(path + "/" + music_hint):
		inst = path + "/" + music_hint
	if inst == "":
		for f in audios:
			if not f.to_lower().begins_with("voices"):
				inst = path + "/" + f
				break
	charts.sort_custom(func(a, b): return a.meter < b.meter)
	return {"folder": path, "title": title, "artist": artist, "charts": charts, "inst": inst, "voices": voices}

static func _fnf_diff_from_name(low: String) -> String:
	for k in ["easy", "hard", "normal", "insane", "expert"]:
		if low.contains(k):
			return k.capitalize()
	return "Normal"

## Importa arquivos escolhidos para user://songs/<nome>/
## Retorna texto de status.
func import_files(chart_path: String, inst_path: String, voices_path := "") -> String:
	if chart_path == "":
		return "Escolha um chart (.json ou .sm)."
	var ext := chart_path.get_extension().to_lower()
	var name := sanitize(chart_path.get_file().get_basename())
	if ext == "json":
		var c := FnfParser.parse_text(read_text(chart_path))
		if c == null:
			return "Esse .json não parece um chart do FNF."
		name = sanitize(c.title)
	elif ext == "sm" or ext == "ssc":
		var cs := SmParser.parse_text(read_text(chart_path))
		if cs.is_empty():
			return "Nenhum chart dance-single (4 setas) nesse arquivo."
		name = sanitize(cs[0].title)
	elif ext == "osu":
		var oc := OsuParser.parse_text(read_text(chart_path))
		if oc == null:
			return "Esse .osu não é osu!mania 4K."
		name = sanitize(oc.title)
	else:
		return "Formato não suportado: .%s" % ext
	if inst_path == "":
		return "Escolha o inst.ogg (obrigatório)."
	var dir := Settings.songs_dir() + "/" + name
	DirAccess.make_dir_recursive_absolute(dir)
	_copy(chart_path, dir + "/" + chart_path.get_file())
	_copy(inst_path, dir + "/inst." + inst_path.get_extension())
	if voices_path != "":
		_copy(voices_path, dir + "/voices." + voices_path.get_extension())
	scan_library()
	return "OK:" + name

func _copy(src: String, dst: String) -> void:
	var b := read_bytes(src)
	var f := FileAccess.open(dst, FileAccess.WRITE)
	if f:
		f.store_buffer(b)

# ---------------------------------------------------------------- importação em lote
const CHART_EXTS := ["sm", "ssc", "osu", "osz", "json"]
const COPY_EXTS := ["sm", "ssc", "osu", "json", "ogg", "mp3", "wav", "png", "jpg", "jpeg", "bmp"]
const AUDIO_EXTS := ["ogg", "mp3", "wav"]

## Importa uma pasta: pasta de música do StepMania (.sm/.ssc + áudio + imagens),
## pasta com .osz / .osu, pasta do FNF/Psych (json + inst/voices) ou um "pack" com várias dessas.
## Retorna "OK:mensagem" ou texto de erro.
func import_folder(src: String) -> String:
	var found: Array = []
	_find_song_dirs(src, 0, found)
	if found.is_empty():
		return "Nenhum chart (.sm .ssc .osu .osz .json) encontrado nessa pasta."
	var names: Array = []
	for dir in found:
		for n in _import_song_dir(dir):
			if not names.has(n):
				names.append(n)
	scan_library()
	if names.is_empty():
		return "Achei charts, mas nenhum utilizável (precisa ser 4 teclas / dance-single)."
	return "OK:%d música(s): %s" % [names.size(), ", ".join(names.slice(0, 3)) + ("…" if names.size() > 3 else "")]

func _find_song_dirs(path: String, depth: int, out: Array) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	for f in d.get_files():
		var ext := f.get_extension().to_lower()
		if ext in ["sm", "ssc", "osu", "osz"]:
			out.append(path)
			return
		if ext == "json" and f.to_lower() != "meta.json":
			if FnfParser.parse_text(read_text(path + "/" + f)) != null:
				out.append(path)
				return
	if depth >= 3:
		return
	for sub in d.get_directories():
		_find_song_dirs(path + "/" + sub, depth + 1, out)

## Copia uma pasta de música para user://songs/<nome>/. Retorna os títulos importados.
func _import_song_dir(src: String) -> Array:
	var res: Array = []
	var d := DirAccess.open(src)
	if d == null:
		return res
	var dest := Settings.songs_dir() + "/" + sanitize(src.get_file())
	var copied := false
	for f in d.get_files():
		var ext := f.get_extension().to_lower()
		if ext == "osz":
			var t := _extract_osz(src + "/" + f)
			if t != "":
				res.append(t)
		elif ext in COPY_EXTS:
			if not copied:
				DirAccess.make_dir_recursive_absolute(dest)
				copied = true
			_copy(src + "/" + f, dest + "/" + f)
	if copied:
		var e := _scan_folder(dest, dest.get_file())
		if e.is_empty():
			_remove_dir(dest)
		else:
			res.append(e.title)
	return res

## Arquivos avulsos: .osz, .sm/.ssc/.osu, .json (FNF/Psych) e áudios (inst / voices).
func import_loose(paths: PackedStringArray) -> String:
	var charts: Array = []
	var oszs: Array = []
	var audios: Array = []
	for p in paths:
		var ext := p.get_extension().to_lower()
		if ext == "osz":
			oszs.append(p)
		elif ext in ["sm", "ssc", "osu", "json"]:
			charts.append(p)
		elif ext in AUDIO_EXTS:
			audios.append(p)
	var names: Array = []
	var errors: Array = []
	for o in oszs:
		var t := _extract_osz(o)
		if t != "":
			names.append(t)
		else:
			errors.append("%s não é um .osz osu!mania 4K válido." % o.get_file())
	if not charts.is_empty():
		var r := _import_chart_set(charts, audios)
		if r.begins_with("OK:"):
			names.append(r.substr(3))
		else:
			errors.append(r)
	elif oszs.is_empty():
		return "Faltou o chart: escolha um .osz, .sm, .ssc, .osu ou o .json (junto com inst.ogg / voices.ogg)."
	scan_library()
	if names.is_empty():
		return " ".join(errors)
	return "OK:%d música(s): %s" % [names.size(), ", ".join(names)]

func _import_chart_set(charts: Array, audios: Array) -> String:
	var title := ""
	var valid: Array = []
	for p in charts:
		var ext: String = p.get_extension().to_lower()
		var t := ""
		if ext == "json":
			var c := FnfParser.parse_text(read_text(p))
			if c != null:
				t = c.title
		elif ext == "osu":
			var oc := OsuParser.parse_text(read_text(p))
			if oc != null:
				t = oc.title
		else:
			var cs := SmParser.parse_text(read_text(p))
			if not cs.is_empty():
				t = cs[0].title
		if t != "":
			valid.append(p)
			if title == "":
				title = t
	if valid.is_empty():
		return "Nenhum dos charts escolhidos é válido (4 teclas)."
	var inst := ""
	var voices := ""
	for a in audios:
		var low: String = a.get_file().to_lower()
		if low.begins_with("voices"):
			voices = a
		elif low.begins_with("inst"):
			inst = a
	if inst == "":
		for a in audios:
			if a != voices:
				inst = a
				break
	if inst == "":
		return "Falta o áudio: escolha o inst.ogg junto com o chart."
	var dest := Settings.songs_dir() + "/" + sanitize(title)
	DirAccess.make_dir_recursive_absolute(dest)
	for p in valid:
		_copy(p, dest + "/" + p.get_file())
	_copy(inst, dest + "/inst." + inst.get_extension().to_lower())
	if voices != "":
		_copy(voices, dest + "/voices." + voices.get_extension().to_lower())
	return "OK:" + title

## Extrai um .osz (zip) para user://songs/. Retorna o título ou "" se não tiver chart mania 4K.
func _extract_osz(path: String) -> String:
	var z := ZIPReader.new()
	if z.open(path) != OK:
		return ""
	var entries := z.get_files()
	var good: Array = []
	var audio_names := {}
	var title := ""
	var artist := ""
	for n in entries:
		if n.get_extension().to_lower() != "osu":
			continue
		var c := OsuParser.parse_text(z.read_file(n).get_string_from_utf8())
		if c == null:
			continue
		good.append(n)
		audio_names[str(c.get_meta("audio", ""))] = true
		if title == "":
			title = c.title
			artist = c.artist
	if good.is_empty():
		z.close()
		return ""
	var label := ("%s - %s" % [artist, title]) if artist != "" else title
	var dest := Settings.songs_dir() + "/" + sanitize(label)
	DirAccess.make_dir_recursive_absolute(dest)
	for n in entries:
		if n.ends_with("/"):
			continue
		var ext: String = n.get_extension().to_lower()
		var keep: bool = good.has(n) or audio_names.has(n) or audio_names.has(n.get_file()) or ext in ["png", "jpg", "jpeg"]
		if not keep:
			continue
		var f := FileAccess.open(dest + "/" + n.get_file(), FileAccess.WRITE)
		if f:
			f.store_buffer(z.read_file(n))
	z.close()
	return title

func _remove_dir(path: String) -> void:
	var d := DirAccess.open(path)
	if d:
		for f in d.get_files():
			d.remove(f)
	DirAccess.remove_absolute(path)

func delete_song(entry: Dictionary) -> void:
	var d := DirAccess.open(entry.folder)
	if d:
		for f in d.get_files():
			d.remove(f)
	DirAccess.remove_absolute(entry.folder)
	scan_library()

# ---------------------------------------------------------------- telas
func goto(scene_name: String, args := {}) -> void:
	if root:
		root.show_screen(scene_name, args)

func _ready() -> void:
	scan_library()

# ---------------------------------------------------------------- recordes
const SCORES_PATH := "user://scores.cfg"

func _score_key(folder: String, diff: String) -> String:
	return (folder.get_file() + "|" + diff)

func get_best(folder: String, diff: String) -> Dictionary:
	var c := ConfigFile.new()
	if c.load(SCORES_PATH) != OK:
		return {}
	return c.get_value("best", _score_key(folder, diff), {})

func save_best(folder: String, diff: String, res: Dictionary) -> bool:
	var c := ConfigFile.new()
	c.load(SCORES_PATH)
	var key := _score_key(folder, diff)
	var old: Dictionary = c.get_value("best", key, {})
	if old.is_empty() or int(res.score) > int(old.get("score", 0)):
		c.set_value("best", key, {"score": res.score, "acc": res.acc, "rank": res.rank, "combo": res.max_combo})
		c.save(SCORES_PATH)
		return true
	return false

func play(song: Dictionary, chart: Chart) -> void:
	current_song = song
	current_chart = chart
	if song.get("inst", "") == "":
		return
	goto("gameplay")
