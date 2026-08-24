extends VBoxContainer
## Quick Bar card content for the AYANEO 3 Magic Modules.
##
## Layout modeled after AYANEO's native MagicModule panel: one button per
## side carrying the module state, a Pop Both bar, and a persistent
## footer hint (fixed height, so state changes never reflow the card).

const OGUIButton := preload("res://core/ui/components/button.tscn")

const HINT_IDLE := "L/R modules are not interchangeable"
const HINT_EJECTING := "Hold the device"
const HINT_RELEASED := "Pull it out — don't swap sides!"
const HINT_WAITING := "Waiting for module…"

var backend

var pop_left: Button
var pop_right: Button
var pop_both: Button
var footer: Label

var _ejecting_side := ""
var _released_hint := false


func setup(b) -> void:
	backend = b
	backend.state_changed.connect(_refresh)
	backend.eject_started.connect(_on_eject_started)
	backend.eject_finished.connect(_on_eject_finished)


func _ready() -> void:
	add_theme_constant_override("separation", 8)

	pop_left = _make_button(func(): _try_eject("left"))
	pop_right = _make_button(func(): _try_eject("right"))
	pop_both = _make_button(func(): _try_eject("both"))
	pop_both.text = "Pop Both"
	pop_both.alignment = HORIZONTAL_ALIGNMENT_CENTER

	footer = Label.new()
	footer.text = HINT_IDLE
	footer.modulate = Color(1, 1, 1, 0.7)
	footer.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(footer)

	if backend:
		_refresh()


func _make_button(on_pressed: Callable) -> Button:
	var button := OGUIButton.instantiate() as Button
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.pressed.connect(on_pressed)
	add_child(button)
	return button


func _try_eject(side: String) -> void:
	if backend.ejecting:
		return
	if backend.attached != "both" or not backend.powered:
		footer.text = HINT_WAITING
		return
	backend.eject(side)


func _refresh() -> void:
	if not backend or not is_inside_tree():
		return

	var busy: bool = backend.ejecting
	var attached: String = backend.attached
	var ready_state: bool = attached == "both" and backend.powered and not busy

	_refresh_side(pop_left, "left", "Left", backend.left_name, busy, attached, ready_state)
	_refresh_side(pop_right, "right", "Right", backend.right_name, busy, attached, ready_state)
	pop_both.modulate = _alpha(ready_state)

	if busy:
		footer.text = HINT_EJECTING
	elif attached == "both":
		_released_hint = false
		footer.text = HINT_IDLE
	else:
		footer.text = HINT_RELEASED if _released_hint else HINT_WAITING


func _refresh_side(button: Button, side: String, side_name: String, module_name: String, busy: bool, attached: String, ready_state: bool) -> void:
	if busy and _ejecting_side in [side, "both"]:
		button.text = "Ejecting " + side + "…"
		button.modulate = _alpha(true)
	elif attached in ["both", side]:
		button.text = "● Pop " + side_name + " · " + module_name
		button.modulate = _alpha(ready_state)
	else:
		button.text = "○ " + side_name + " · Reinsert"
		button.modulate = _alpha(false)


func _alpha(active: bool) -> Color:
	return Color(1, 1, 1, 1.0 if active else 0.4)


func _on_eject_started(side: String) -> void:
	_ejecting_side = side
	_refresh()


func _on_eject_finished(_side: String, ok: bool) -> void:
	_ejecting_side = ""
	_released_hint = ok
	if not ok:
		footer.text = "Eject failed"
	_refresh()
