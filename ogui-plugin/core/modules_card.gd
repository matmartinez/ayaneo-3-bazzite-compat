extends VBoxContainer
## Quick Bar card content for the AYANEO 3 Magic Modules: shows which
## module is inserted on each side and provides pop-out buttons.

const OGUIButton := preload("res://core/ui/components/button.tscn")

var backend: Node

var left_label: Label
var right_label: Label
var status_label: Label
var pop_left: Button
var pop_right: Button
var pop_both: Button


func setup(b: Node) -> void:
	backend = b
	backend.state_changed.connect(_refresh)
	backend.eject_started.connect(_on_eject_started)
	backend.eject_finished.connect(_on_eject_finished)


func _ready() -> void:
	add_theme_constant_override("separation", 8)

	left_label = _add_label("Left: …")
	right_label = _add_label("Right: …")

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	add_child(buttons)
	pop_left = _make_button("Pop Left", func(): backend.eject("left"))
	pop_right = _make_button("Pop Right", func(): backend.eject("right"))
	pop_both = _make_button("Pop Both", func(): backend.eject("both"))
	for b in [pop_left, pop_right, pop_both]:
		buttons.add_child(b)

	status_label = _add_label("")
	status_label.modulate = Color(1, 1, 1, 0.7)

	if backend:
		_refresh()


func _add_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	add_child(label)
	return label


func _make_button(text: String, on_pressed: Callable) -> Button:
	var button := OGUIButton.instantiate() as Button
	button.text = text
	button.pressed.connect(on_pressed)
	return button


func _refresh() -> void:
	if not backend or not is_inside_tree():
		return

	var busy: bool = backend.ejecting
	var ready_state: bool = backend.attached == "both" and backend.powered and not busy
	for b in [pop_left, pop_right, pop_both]:
		b.disabled = not ready_state

	match backend.attached:
		"both":
			left_label.text = "Left: " + backend.left_name
			right_label.text = "Right: " + backend.right_name
			if not busy:
				status_label.text = ""
		"left":
			left_label.text = "Left: " + backend.left_name
			right_label.text = "Right: Disconnected"
			status_label.text = "Reinsert the module to reactivate"
		"right":
			left_label.text = "Left: Disconnected"
			right_label.text = "Right: " + backend.right_name
			status_label.text = "Reinsert the module to reactivate"
		"none":
			left_label.text = "Left: Disconnected"
			right_label.text = "Right: Disconnected"
			status_label.text = "Reinsert the modules to reactivate"
		_:
			status_label.text = "Module state unavailable"


func _on_eject_started(side: String) -> void:
	status_label.text = "Ejecting " + side + "…"
	_refresh()


func _on_eject_finished(side: String, ok: bool) -> void:
	if ok:
		status_label.text = "Module released — pull it out, reinsert to reactivate"
	else:
		status_label.text = "Eject failed — check permissions (see plugin README)"
	_refresh()
