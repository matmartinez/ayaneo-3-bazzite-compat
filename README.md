# AYANEO 3 × Bazzite 44 compatibility workbench

Bazzite 43 supported the AYANEO 3 well (via Handheld Daemon). Bazzite 44
(stable `44.20260820`) replaced hhd with the ShadowBlip/OGC stack and
introduced two regressions on the AYANEO 3. This repo tracks fixes and the
upstreaming path for both.

## Regression 1: washed-out colors in gaming mode

**Root cause path:** Bazzite 44 builds gamescope from the
[OpenGamingCollective fork](https://github.com/OpenGamingCollective/gamescope)
(`ogc` branch, currently commit `7282613d`). A display script for the
AYANEO 3 panel was merged there as
[OGC PR #11](https://github.com/OpenGamingCollective/gamescope/pull/11)
on 2026-07-27, but the `ogc` branch was later force-pushed and **the file was
silently dropped** — the merge commit (`74aace05`) is orphaned and no AYA
script exists anywhere in the current tree. The upstream PR
[ValveSoftware/gamescope#2260](https://github.com/ValveSoftware/gamescope/pull/2260)
is open with no review activity; Bazzite doesn't ship from there anyway.

**Panel facts** (from the EDID in
[ublue-os/bazzite#5219](https://github.com/ublue-os/bazzite/issues/5219)):
1080x1920 portrait 10-bit OLED, gamma 2.2, up to 144Hz, primaries identical
to the Zotac Zone's DXQ7D0023 panel (which already has a working script,
`zotac.zone.oled.lua`, in the OGC fork).

**Known-bad prior versions:**
- PR #2260 / OGC #11 version (`gamescope-display/AYA-AYAOLED_FHD.lua`, kept
  for reference): no colorimetry table (references an undefined variable),
  ST2084 EOTF on a gamma-2.2 panel, latent `set_res`/`res` typo.
- Issue #5219 attachment: correct approach (Zotac-derived) but assigns
  `colorimetry = ayaneo_amoled_colorimetry` while defining
  `ayaneo3_amoled_colorimetry` → colorimetry is nil at runtime.

**Fixed version:** `gamescope-display/ayaneo.3.oled.lua` — colorimetry from
the panel spec/EDID, gamma22 EOTF, 60/72/90/120/144Hz, EDID H/V timings.

**Test on device:** copy `ayaneo.3.oled.lua` to `~/.config/gamescope/scripts/`
(create the dir if needed), reboot or restart the gamescope session.

**Upstreaming: DONE.** [OpenGamingCollective/gamescope#19](https://github.com/OpenGamingCollective/gamescope/pull/19)
**merged 2026-08-24** (approved by pastaq) — Bazzite picks it up on its next
gamescope bump; until then the `~/.config/gamescope/scripts/` copy applies.
Corrected version also submitted upstream at pastaq's request as
[ValveSoftware/gamescope#2347](https://github.com/ValveSoftware/gamescope/pull/2347)
(co-authored with sknowledge1, supersedes their #2260).

## Regression 2: magic modules (detachable controllers) not supported

**What changed in 44:** hhd was removed in
[`ce953e43`](https://github.com/ublue-os/bazzite/commit/ce953e4306f2effa58f2fbb8a833081685aa5424)
(2026-03-16, "drop HHD") and replaced by InputPlumber (input),
SteamOS-Manager + PowerStation (TDP — AYANEO 3 is listed in
`hwsupport/powerstation-hardware`), and OpenGamepadUI (overlay UX). hhd's
magic-module handling (hidraw init sequence, module-type identification,
software eject, RGB — see `src/hhd/device/ayaneo/base.py` in hhd-dev/hhd)
has no replacement in this stack.

**Kernel status:** the `ayaneo-ec` platform driver (by Antheas Kapenekakis,
mainline since Linux 6.19; shipped and enabled in Bazzite 44's OGC 7.2 kernel)
exposes `controller_modules` (attachment state) and `controller_power` sysfs
attributes — but that's only **half the handshake**. Per OGUI maintainer
pastaq in [ShadowBlip/OpenGamepadUI#528](https://github.com/ShadowBlip/OpenGamepadUI/issues/528):
a `hid-ayaneo` HID kernel driver is still needed for the second half
(module ID, custom-mode init, eject), and module pop-out is explicitly out of
scope for InputPlumber; the plan of record is kernel driver → OGUI plugin.

**Status: working driver in `hid-ayaneo/`** — built against the OGC
7.2.0-ogc4.1 kernel on the device and verified on hardware (2026-08-23):
module identification (sysfs `module_left`/`module_right`), RGB via a
multicolor LED class device named `ayaneo:rgb:joystick_rings` (the name
InputPlumber's AYANEO 3 config expects), and software eject (sysfs `eject`,
takes `left`/`right`/`both`, blocks until firmware confirms). A full
eject+reattach cycle was tested end to end: eject → EC power off → module
released → reinsert → EC reports `both` → power on → controller re-enumerates
in custom mode → driver rebinds. Design choices: DMI-gated to AYANEO 3
(the 1c4f:0002 VID/PID is a generic SigmaMicro ID), binds only the vendor
interface (application usage 0xff000001), EC power-off deliberately left to
userspace to keep layering clean (orchestration belongs to the OGUI plugin).
Protocol notes: 65-byte unnumbered reports, checksum = LE16 sum of bytes
7..64 at bytes 1-2, subcommand echo at response byte 3; needs
`hid_device_io_start()` for probe-time transactions; USB transfer buffers
must be heap-allocated.

**Submitted:**
- Driver: [OpenGamingCollective/linux#101](https://github.com/OpenGamingCollective/linux/pull/101) (base `features/ayaneo`, checkpatch-clean, with MAINTAINERS + ABI docs)
- Config: [OpenGamingCollective/kernel-packages#35](https://github.com/OpenGamingCollective/kernel-packages/pull/35) (`CONFIG_HID_AYANEO=m`)
- Driver: **MERGED** into [OpenGamingCollective/linux-unstable](https://github.com/OpenGamingCollective/linux-unstable/pull/3) (2026-08-24, by NeroReflex, after two review rounds + CI config-gate/gcc build; squashed `[FOR-UPSTREAM]` patch + `[NOT-FOR-UPSTREAM]` CI-fragment commit). The unstable OGC kernel now ships hid-ayaneo. Post-merge note: the `hid_is_usb()`/uhid-spoofing concern NeroReflex shared doesn't apply — the driver never casts `dev.parent`.
- Plugin udev rule (plugin-store prerequisite per pastaq): [ShadowBlip/OpenGamepadUI#536](https://github.com/ShadowBlip/OpenGamepadUI/pull/536); registry PR to OpenGamepadUI-plugins follows once merged
- Coordination/interface feedback: comment posted on [ShadowBlip/OpenGamepadUI#528](https://github.com/ShadowBlip/OpenGamepadUI/issues/528)
- OGUI overlay-mode plugin bug found while building the UI: reported as [ShadowBlip/OpenGamepadUI#535](https://github.com/ShadowBlip/OpenGamepadUI/issues/535)
- OGUI plugin (`ogui-plugin/`): working on-device; registry/in-tree submission deliberately held until #528 answers plugin-vs-platform-code (packaging differs, code ports either way)
- LKML series: pending interface feedback

**Contribution plan (maintainer-blessed pattern):**
1. **Kernel:** write/land `hid-ayaneo` implementing what hhd does over hidraw
   (init sequence, module ID table, eject protocol, RGB as a LED class device
   `<dev>:rgb:joystick_rings` — per-device prefix per linux-unstable#3 review;
   InputPlumber's `50-ayaneo_3.yaml` matches `sys_name` by glob, so once the
   driver lands it needs a one-line change to `*:rgb:joystick_rings`).
   Coordinate with Antheas Kapenekakis (ayaneo-ec)
   and Derek J. Clark (OGC/ShadowBlip). Land upstream + in OGC
   kernel-packages (`config/ogc.config.set`) so Bazzite's kernel gets it.
2. **OpenGamepadUI:** plugin replicating hhd's `modules.yml` UX
   (pop left/right/both, module-type display) on top of the sysfs/kernel
   interfaces — tracked in ShadowBlip/OpenGamepadUI#528, blocked on step 1.
3. **Bazzite repo:** essentially nothing — device detection and TDP fallback
   already cover the AYANEO 3; at most udev/hwdb tweaks.

Reference implementation for the protocol: hhd's `Ayaneo3Hidraw`
(`AYA3_INIT` command sequence, `AYA_CHECK` polling, 16 known module IDs,
eject verification via status register).
