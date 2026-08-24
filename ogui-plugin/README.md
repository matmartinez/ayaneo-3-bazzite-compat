# AYANEO Magic Modules — OpenGamepadUI plugin

Quick Bar card for the AYANEO 3 detachable controller: shows which module
is inserted on each side and provides Pop Left / Pop Right / Pop Both,
replicating the UX Handheld Daemon used to offer.

Built ahead of maintainer feedback (see below) against OGUI v0.46 /
plugin API 2.0.0, mirroring the structure of
[OpenGamepadUI-discord](https://github.com/ShadowBlip/OpenGamepadUI-discord)
and the core quick-bar cards.

## Requirements

- `ayaneo-ec` kernel driver (mainline ≥ 6.19, in Bazzite 44)
- `hid-ayaneo` kernel driver
  ([OpenGamingCollective/linux#101](https://github.com/OpenGamingCollective/linux/pull/101),
  source in `../hid-ayaneo/`)
- Write access to the control attributes for the OGUI user — install
  `70-ayaneo-modules.rules` into `/etc/udev/rules.d/` (development
  stopgap; see "Open questions").

## How it works

`core/magic_modules.gd` polls `ayaneo-ec`'s `controller_modules` /
`controller_power` and reads module IDs from `hid-ayaneo`. Pop-out flow:
write `left|right|both` to `hid-ayaneo`'s `eject` (blocks until the
firmware confirms, done on a worker thread), then write `0` to
`controller_power` to release the module. When the module is reinserted
(`controller_modules` back to `both` while unpowered), power is restored
automatically. `core/modules_card.gd`/`.tscn` is the Quick Bar card
(instances the core `qb_card.tscn`).

`plugin.json` carries the `"quick-bar"` store tag — mandatory, since
Bazzite 44 runs OGUI in overlay mode, which only loads plugins with that
tag.

## Build

Plugins are exported as Godot resource packs with the OGUI project:

```sh
make build OPENGAMEPAD_UI_BASE=../OpenGamepadUI GODOT=/path/to/godot4.7
make install   # copies dist/ayaneo-modules.zip to ~/.local/share/opengamepadui/plugins
```

(The export needs a one-time export preset named "AYANEO Magic Modules"
in the OGUI checkout including `res://plugins/ayaneo-modules/*` — copy an
existing plugin preset.)

## Status

Working end to end on an AYANEO 3 running Bazzite 44 (OGUI 0.46, overlay
mode): card renders in the Quick Bar, controller focus works, module
names live-update, and a full pop/reinsert cycle driven from the UI was
verified on hardware. UI layout follows AYANEO's native MagicModule
panel: state-carrying pop buttons, a Pop Both bar, and a fixed footer
hint (the L/R-not-interchangeable warning from AYASpace).

### Dev loop (no Godot export needed)

The PluginLoader mounts plugin zips as plain resource packs and GDScript
compiles at runtime, so a hand-built zip works:

```sh
python3 -c "import zipfile
z = zipfile.ZipFile('ayaneo-modules.zip', 'w')
for f in ['plugin.json', 'plugin.gd', 'core/magic_modules.gd', 'core/modules_card.gd', 'core/modules_card.tscn']:
    z.write(f, 'plugins/ayaneo-modules/' + f)"
cp ayaneo-modules.zip ~/.local/share/opengamepadui/plugins/
rm -rf ~/.local/share/opengamepadui/plugins/ayaneo-modules  # stale extraction
systemctl --user restart gamescope-session-plus@ogui-steam.service
```

### Hard-won integration notes

- **Orphaned PluginManager (OGUI v0.46 overlay-mode bug):** overlay mode
  constructs `CardUIOverlayMode` twice; plugins initialize under an
  orphaned `PluginManager` whose subtree never enters the scene tree, so
  `_ready` never fires. `plugin.gd` detects this and reparents itself
  into the live tree (`_rescue`). Reported upstream as
  [ShadowBlip/OpenGamepadUI#535](https://github.com/ShadowBlip/OpenGamepadUI/issues/535).
- **Silent GDScript failures:** release export templates print no script
  errors; compile-check plugins against Godot 4.7 locally before
  deploying (see the harness pattern in the workbench history).
- **sysfs reads:** `FileAccess.get_as_text()` returns "" on sysfs files
  (bogus reported size); read with `get_line()`.
- **Quick Bar contract:** pass plain content (not a `qb_card` instance)
  to `add_to_quick_bar`; the menu wraps it and consumes a child named
  `SectionLabel` as the row title. Include a `FocusGroup`
  (`core/systems/input/focus_group.tscn` with the quick-bar focus stack)
  for controller navigation.
- **No layout reflow:** avoid `Button.disabled` (its stylebox changes
  size); dim with `modulate` and gate the press handler instead. Keep
  the footer populated with fixed-height single-line text.
- **Module ID table:** hhd's right-side base/rotated labels are swapped
  relative to hardware; `magic_modules.gd` carries the corrected table
  (0x50 = ABXY on top, verified on device).

### Deferred: RGB row

The kernel driver exposes `ayaneo:rgb:joystick_rings` (solid color), but
InputPlumber's AYANEO 3 config references the same LED, so ownership
must be checked before adding UI (same conflict class as OGUI PR #531 /
SteamOS-Manager TDP). If it goes ahead: preset color swatches + a
brightness slider (OGUI `slider.tscn`), as a separate row or card — not
interleaved with the pop buttons. No existing OGUI RGB plugin to
reference; the closest UI pattern is the core quick-settings sliders.

## Open questions (pending ShadowBlip/OpenGamepadUI#528 feedback)

1. **External plugin vs. in-tree platform code.** OGUI has a
   `core/platform/` per-device layer with an established pkexec/polkit
   pattern. If maintainers prefer that, this code ports over — the
   backend and card logic are the same, only packaging changes.
2. **Privilege model.** Plugin zips install to the user's home and
   cannot ship udev rules or polkit policies, so unprivileged sysfs
   access must be granted by the OS/driver packaging (the udev rule
   here) — or the pkexec pattern if in-tree.
3. **Driver sysfs names** may change during kernel review; paths are
   confined to `core/magic_modules.gd`.
