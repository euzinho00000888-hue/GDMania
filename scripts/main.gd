extends Control
## Raiz: gerencia o fundo, o tema e a troca de telas.

const SCREENS := {
	"menu": "res://scripts/menu.gd",
	"song_select": "res://scripts/song_select.gd",
	"importer": "res://scripts/importer.gd",
	"converter": "res://scripts/converter_screen.gd",
	"settings": "res://scripts/settings_screen.gd",
	"gameplay": "res://scripts/gameplay.gd",
	"results": "res://scripts/results.gd",
}

var backdrop: Control
var current: Control

func _ready() -> void:
	Game.root = self
	theme = UI.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop = Control.new()
	backdrop.set_script(load("res://scripts/backdrop.gd"))
	add_child(backdrop)
	get_tree().set_auto_accept_quit(true)
	show_screen("menu")

func show_screen(name: String, args := {}) -> void:
	if current:
		current.queue_free()
		current = null
	var node := Control.new()
	node.set_script(load(SCREENS[name]))
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	node.name = name
	add_child(node)
	current = node
	backdrop.visible = name != "gameplay"
	node.modulate.a = 0.0
	create_tween().tween_property(node, "modulate:a", 1.0, 0.18)
