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
