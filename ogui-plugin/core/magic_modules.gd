extends Node
## Backend for the AYANEO 3 detachable controller ("Magic Modules").
##
## Talks to two kernel drivers through sysfs:
##  - hid-ayaneo: module identification (module_left/module_right) and the
##    eject handshake (eject attribute, blocks until firmware confirms)
##  - ayaneo-ec: module attach state (controller_modules) and controller
##    power (controller_power)
##
## The full pop-out flow is: write to hid-ayaneo's eject, wait for the
## write to return, then cut power through ayaneo-ec. When the module is
## reinserted (attach state back to "both" while powered off), power is
## restored automatically, mirroring what Handheld Daemon used to do.

signal state_changed
signal eject_started(side: String)
signal eject_finished(side: String, ok: bool)

const EC_MODULES := "/sys/devices/platform/ayaneo-ec/controller_modules"
const EC_POWER := "/sys/devices/platform/ayaneo-ec/controller_power"
const HID_DRIVER_DIR := "/sys/bus/hid/drivers/hid-ayaneo"

const POLL_INTERVAL := 2.0

## Module type names, indexed by the raw ID reported by the firmware.
## Bits 0-5 are the type, bit 6 means the module is inserted rotated.
const LEFT_MODULES := {
	0x02: "Cross Film / Joystick",
	0x04: "Cross / Joystick",
	0x06: "Cross / Touchpad",
	0x08: "Direction / Joystick",
	0x42: "Joystick / Cross Film",
	0x44: "Joystick / Cross",
	0x46: "Touchpad / Cross",
	0x48: "Joystick / Direction",
}
const RIGHT_MODULES := {
	0x10: "ABXY \\ Joystick",
	0x12: "ABXY \\ Touchpad",
	0x14: "ABXYCZ",
	0x16: "ABXY Film \\ Joystick",
	0x50: "Joystick \\ ABXY",
	0x52: "Touchpad \\ ABXY",
	0x54: "ABXYCZ [R]",
	0x56: "Joystick \\ ABXY Film",
}

var logger := Log.get_logger("MagicModules")

var attached := "unknown"       # none|left|right|both
var powered := false
var ejecting := false
var left_name := "Unknown"
var right_name := "Unknown"

var _timer: Timer
var _thread: Thread


func is_supported() -> bool:
	return FileAccess.file_exists(EC_MODULES)


func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = POLL_INTERVAL
	_timer.timeout.connect(_poll)
	add_child(_timer)
	_timer.start()
	_poll()


func _exit_tree() -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()


## Ask the firmware to release a module. side is "left", "right" or "both".
func eject(side: String) -> void:
	if ejecting:
		return
	if not side in ["left", "right", "both"]:
		return
	ejecting = true
	eject_started.emit(side)
	state_changed.emit()

	if _thread and _thread.is_started():
		_thread.wait_to_finish()
	_thread = Thread.new()
	_thread.start(_eject_worker.bind(side))


func _eject_worker(side: String) -> void:
	# This write blocks until the firmware confirms the release
	# handshake (typically ~4s).
	var ok := _write_sysfs(_hid_attr("eject"), side)
	if ok:
		# Cut controller power to physically release the module.
		ok = _write_sysfs(EC_POWER, "0")
	call_deferred("_eject_done", side, ok)


func _eject_done(side: String, ok: bool) -> void:
	ejecting = false
	if not ok:
		logger.error("Eject of " + side + " module failed")
	eject_finished.emit(side, ok)
	_poll()


func _poll() -> void:
	if ejecting:
		return
	var new_attached := _read_sysfs(EC_MODULES)
	var new_powered := _read_sysfs(EC_POWER) == "1"

	# Module reinserted while unpowered: power the controller back on.
	if new_attached == "both" and not new_powered:
		logger.info("Modules reattached, restoring controller power")
		_write_sysfs(EC_POWER, "1")
		new_powered = true

	var changed := new_attached != attached or new_powered != powered
	attached = new_attached
	powered = new_powered

	if powered and attached == "both":
		changed = _refresh_module_names() or changed
	if changed:
		state_changed.emit()


func _refresh_module_names() -> bool:
	var left := _read_sysfs(_hid_attr("module_left"))
	var right := _read_sysfs(_hid_attr("module_right"))
	if left == "" or right == "":
		return false
	var vl: String = LEFT_MODULES.get(left.hex_to_int(), "Unknown (%s)" % left)
	var vr: String = RIGHT_MODULES.get(right.hex_to_int(), "Unknown (%s)" % right)
	var changed := vl != left_name or vr != right_name
	left_name = vl
	right_name = vr
	return changed


## Resolve a hid-ayaneo sysfs attribute path. The HID device address
## changes on every rebind, so glob the driver directory each time.
func _hid_attr(attr: String) -> String:
	var dir := DirAccess.open(HID_DRIVER_DIR)
	if not dir:
		return ""
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.contains(":") and dir.dir_exists(entry):
			return HID_DRIVER_DIR + "/" + entry + "/" + attr
		entry = dir.get_next()
	return ""


func _read_sysfs(path: String) -> String:
	if path == "" or not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return ""
	return f.get_as_text().strip_edges()


func _write_sysfs(path: String, value: String) -> bool:
	if path == "":
		return false
	# Use a shell write so the blocking write syscall and its error are
	# reliably observable (FileAccess buffers and hides write errors).
	var output := []
	var code := OS.execute("sh", ["-c", "printf %s '" + value + "' > '" + path + "'"], output)
	if code != 0:
		logger.error("Failed writing '" + value + "' to " + path)
	return code == 0
