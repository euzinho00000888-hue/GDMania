extends Node
## Configurações persistentes do GDMania.

const PATH := "user://settings.cfg"
const LANE_NAMES := ["Esquerda", "Baixo", "Cima", "Direita"]

var keys: Array[int] = [KEY_D, KEY_F, KEY_J, KEY_K]
var scroll_mode := "auto"   # auto | down | up | middle
var scroll_speed := 2.0     # multiplicador
var audio_offset_ms := 0
var music_volume := 0.8
var hit_volume := 0.5
var hitsounds := true
var show_hitbox_bars := true

func is_mobile() -> bool:
	return OS.has_feature("android") or OS.has_feature("ios")

## Resolve "auto": downscroll no celular? Pedido: downscroll e middlescroll já vêm definidos.
## Padrão: PC = downscroll, Android (hitbox) = middlescroll.
func effective_scroll() -> String:
	if scroll_mode != "auto":
		return scroll_mode
	return "middle" if is_mobile() else "down"

func songs_dir() -> String:
	return "user://songs"

func save() -> void:
	var c := ConfigFile.new()
	c.set_value("input", "keys", keys)
	c.set_value("gameplay", "scroll_mode", scroll_mode)
	c.set_value("gameplay", "scroll_speed", scroll_speed)
	c.set_value("gameplay", "audio_offset_ms", audio_offset_ms)
	c.set_value("gameplay", "show_hitbox_bars", show_hitbox_bars)
	c.set_value("audio", "music_volume", music_volume)
	c.set_value("audio", "hit_volume", hit_volume)
	c.set_value("audio", "hitsounds", hitsounds)
	c.save(PATH)

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(songs_dir())
	var c := ConfigFile.new()
	if c.load(PATH) != OK:
		return
	var k = c.get_value("input", "keys", keys)
	if k is Array and k.size() == 4:
		for i in 4:
			keys[i] = int(k[i])
	scroll_mode = c.get_value("gameplay", "scroll_mode", scroll_mode)
	scroll_speed = c.get_value("gameplay", "scroll_speed", scroll_speed)
	audio_offset_ms = c.get_value("gameplay", "audio_offset_ms", audio_offset_ms)
	show_hitbox_bars = c.get_value("gameplay", "show_hitbox_bars", show_hitbox_bars)
	music_volume = c.get_value("audio", "music_volume", music_volume)
	hit_volume = c.get_value("audio", "hit_volume", hit_volume)
	hitsounds = c.get_value("audio", "hitsounds", hitsounds)
