class_name Chart
extends RefCounted
## Representação interna de um chart de 4 lanes. Tempos em milissegundos.

var title := "Sem título"
var artist := ""
var difficulty := "Normal"
var meter := 1
var source := "fnf"                 # fnf | sm
var bpm_changes: Array = [[0.0, 120.0]]  # [[ms, bpm], ...] ordenado
var stops: Array = []               # [[ms, duracao_ms]] (apenas informativo)
var notes: Array = []               # [{t: ms, lane: 0..3, len: ms}]
var beat0_ms := 0.0                 # tempo no áudio do beat 0 (offset do .sm)
var scroll_speed := 1.0             # velocidade nativa do chart (FNF)

func first_bpm() -> float:
	return float(bpm_changes[0][1])

func sort_notes() -> void:
	notes.sort_custom(func(a, b): return a.t < b.t if a.t != b.t else a.lane < b.lane)

func length_ms() -> float:
	var m := 0.0
	for n in notes:
		m = maxf(m, n.t + n.len)
	return m

func note_count() -> int:
	return notes.size()

## ms -> beat usando bpm_changes.
func ms_to_beat(ms_abs: float) -> float:
	var ms := ms_abs - beat0_ms
	var beat := 0.0
	for i in bpm_changes.size():
		var start: float = bpm_changes[i][0]
		var bpm: float = bpm_changes[i][1]
		var end: float = bpm_changes[i + 1][0] if i + 1 < bpm_changes.size() else INF
		if ms <= end:
			return beat + (ms - start) / (60000.0 / bpm)
		beat += (end - start) / (60000.0 / bpm)
	return beat

## beat -> ms (sem stops).
func beat_to_ms(beat: float) -> float:
	var b := 0.0
	for i in bpm_changes.size():
		var start: float = bpm_changes[i][0]
		var bpm: float = bpm_changes[i][1]
		var ms_per_beat := 60000.0 / bpm
		var end: float = bpm_changes[i + 1][0] if i + 1 < bpm_changes.size() else INF
		var seg_beats: float = (end - start) / ms_per_beat
		if beat <= b + seg_beats:
			return beat0_ms + start + (beat - b) * ms_per_beat
		b += seg_beats
	return beat0_ms
