extends Plugin

const MagicModules := preload("res://plugins/ayaneo-modules/core/magic_modules.gd")

var backend: Node = MagicModules.new()
var card_scene := load("res://plugins/ayaneo-modules/core/modules_card.tscn") as PackedScene
var card: Control


func _ready() -> void:
	logger = Log.get_logger("AyaneoModules", Log.LEVEL.INFO)

	if not backend.is_supported():
		logger.info("AYANEO 3 magic module interface not found; plugin will stay idle")
		backend = null
		return
	add_child(backend)

	card = card_scene.instantiate()
	var content := card.find_child("MagicModulesContent", true, false)
	if content:
		content.setup(backend)
	else:
		logger.error("Unable to find card content node")

	var icon := load("res://assets/ui/icons/gamepad-bold.svg") as Texture2D
	add_to_quick_bar(card, icon)
	logger.info("AYANEO Magic Modules plugin loaded")


func unload() -> void:
	if card:
		card.queue_free()
	if backend:
		backend.queue_free()
