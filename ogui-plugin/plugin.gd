extends Plugin

const MagicModules := preload("res://plugins/ayaneo-modules/core/magic_modules.gd")

var backend := MagicModules.new()
var card_scene := load("res://plugins/ayaneo-modules/core/modules_card.tscn") as PackedScene
var card


func _init() -> void:
	_rescue.call_deferred()


## Work around OGUI v0.46 overlay mode instantiating CardUIOverlayMode
## twice: plugins can end up under an orphaned PluginManager that never
## enters the scene tree, so _ready never fires. If that happens,
## reparent ourselves into the live scene tree.
func _rescue() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if not tree:
		return
	for i in 300:
		if is_inside_tree():
			return
		if tree.get_first_node_in_group("quick-bar"):
			break
		await tree.process_frame
	if is_inside_tree():
		return
	logger.warn("Orphaned plugin node detected, reparenting into the live scene tree")
	var parent := get_parent()
	if parent:
		parent.remove_child(self)
	tree.root.add_child(self)


func _ready() -> void:
	logger = Log.get_logger("AyaneoModules", Log.LEVEL.INFO)

	if not backend.is_supported():
		logger.info("AYANEO 3 magic module interface not found; plugin will stay idle")
		backend = null
		return
	add_child(backend)

	# The quick bar menu wraps this content in its own card and takes
	# the row title from the SectionLabel child.
	card = card_scene.instantiate()
	card.setup(backend)

	var icon := load("res://assets/ui/icons/gamepad-bold.svg") as Texture2D
	add_to_quick_bar(card, icon)
	logger.info("AYANEO Magic Modules plugin loaded")


func unload() -> void:
	if card:
		card.queue_free()
	if backend:
		backend.queue_free()
