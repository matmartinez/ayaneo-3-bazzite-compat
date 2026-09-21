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

**SHIPPED in Bazzite** (verified on device 2026-09-17 after an OS update):
the script is now in the image at
`/usr/share/gamescope/scripts/00-gamescope/displays/ayaneo.3.oled.lua` and
matches without any local copy — the `~/.config` copy was retired (backup at
`~/ayaneo.3.oled.lua.bak` on the device). Root-cause note for the record,
established while answering matte-schwartz's review question on #2347: the
panel's EDID CTA block advertises BT2020RGB + ST2084, so script-less
gamescope exposes HDR with PQ output encoding on a natively gamma-2.2 panel
— that PQ path, not colorimetry, caused the washed-out look. The EDID base
block carries the same primaries the script states (the
`di_edid_get_chromaticity_coords` fallback uses them identically, A/B
verified via bind-mount hiding the script), so the script's load-bearing
line is `eotf = gamescope.eotf.gamma22`.

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
- Driver: [OpenGamingCollective/linux#101](https://github.com/OpenGamingCollective/linux/pull/101) — **MERGED 2026-09-18** by KyleGospo (single `[FROM-ML]` commit, v3 state, lore Link trailer): hid-ayaneo is in the regular OGC kernel (`features/ayaneo`)
- Config: [OpenGamingCollective/kernel-packages#35](https://github.com/OpenGamingCollective/kernel-packages/pull/35) (`CONFIG_HID_AYANEO=m`) — **MERGED 2026-09-20**: the next OGC kernel build ships the driver, so the next Bazzite kernel bump ends the insmod ritual
- Driver: **MERGED** into [OpenGamingCollective/linux-unstable](https://github.com/OpenGamingCollective/linux-unstable/pull/3) (2026-08-24, by NeroReflex, after two review rounds + CI config-gate/gcc build; squashed `[FOR-UPSTREAM]` patch + `[NOT-FOR-UPSTREAM]` CI-fragment commit). The unstable OGC kernel now ships hid-ayaneo. Post-merge note: an AI-review claim that `hid_is_usb()` is uhid-spoofable was retracted as slop (since ~7.x it checks `ll_driver == &usb_hid_driver`, kernel-set); hid-ayaneo never casts `dev.parent` anyway.
- InputPlumber LED-name glob (RGB keeps matching the renamed LED): [ShadowBlip/InputPlumber#666](https://github.com/ShadowBlip/InputPlumber/pull/666) — **MERGED** by pastaq 2026-09-03
- Plugin udev rule (plugin-store prerequisite per pastaq): [ShadowBlip/OpenGamepadUI#536](https://github.com/ShadowBlip/OpenGamepadUI/pull/536) — **MERGED** by pastaq 2026-09-03, released in OpenGamepadUI **v0.46.1**; the registry PR to OpenGamepadUI-plugins is now unblocked (next plugin action)
- Coordination/interface feedback: comment posted on [ShadowBlip/OpenGamepadUI#528](https://github.com/ShadowBlip/OpenGamepadUI/issues/528)
- OGUI overlay-mode plugin bug found while building the UI: reported as [ShadowBlip/OpenGamepadUI#535](https://github.com/ShadowBlip/OpenGamepadUI/issues/535)
- OGUI plugin: **IN THE PLUGIN STORE** — registry PR merged by pastaq
  2026-09-18. Submitted 2026-09-17 as
  [ShadowBlip/OpenGamepadUI-plugins#9](https://github.com/ShadowBlip/OpenGamepadUI-plugins/pull/9).
  The plugin now lives in its own repo
  [matmartinez/OpenGamepadUI-ayaneo-modules](https://github.com/matmartinez/OpenGamepadUI-ayaneo-modules)
  (subtree-split from `ogui-plugin/` with history; that directory is
  frozen at the split point), with release v1.0.0 carrying the store zip
  (sha256 `0f30e9c2…`), hardware-verified byte-exact from the release
  asset before the PR. Store entry has no icon yet; offered to follow up
  if one is wanted.
- LKML: **submitted 2026-08-24** — `[PATCH] HID: ayaneo: Add AYANEO 3 detachable controller driver`, Message-ID `20260824215041.79892-1-hello@matias.me`, based on hid.git for-next, To: Jiri Kosina + Benjamin Tissoires, Cc: linux-input, LKML, Antheas Kapenekakis, Denis Benato (his Reviewed-by included per linux-unstable#3). Track replies at https://lore.kernel.org/linux-input/20260824215041.79892-1-hello@matias.me/
- LKML v2 sent 2026-08-24 (Message-ID `20260824223103.93947-1-hello@matias.me`, threaded into v1): fixes a real teardown UAF found via review + on-device stress repro (LED work racing unbind — also affects the merged OGC driver, backport pending), eject-loop bail, maxcollection guard, drops the joystick-sensitivity bytes (Antheas), adds breathing mode via hw_pattern (Antheas). Dmitry Torokhov added to Cc. Scope discussion ongoing (Antheas endorses the LED part; eject scope deferred to HID maintainers); v3 held per reviewer pacing advice.
- Teardown-UAF backport to the merged OGC driver: [OpenGamingCollective/linux-unstable#5](https://github.com/OpenGamingCollective/linux-unstable/pull/5) — **MERGED** 2026-08-25 (NeroReflex, on CI green); the unstable OGC kernel no longer ships the vulnerable teardown
- pastaq (Derek J. Clark) posted an 11-point code review on linux-unstable#3
  (2026-08-27). Adopted for v3 (staged in `hid-ayaneo/hid-ayaneo.c`, four
  commits): generic `ayaneo_*` driver-plumbing names (wire protocol stays
  `AYA3_*`), packed `aya3_config`/`aya3_resp` wire structs replacing offset
  defines, `scoped_cond_guard` at every lock site, `LED_COLOR_ID_RGB` on the
  LED classdev, vibration levels named in an enum. Deferred to the v3 cover
  letter (ABI growth while scope is under discussion): `rumble_intensity`
  (+index), `eject_index`, and a hid-ayaneo→ayaneo-ec notification framework
  (Cc pdx86: Ilpo, Armin). Factual replies: module/eject state is already
  probed live per read; RGB/vibration has no read-back command in the known
  protocol; sensitivity bytes were dropped entirely in v2. Reworked driver
  hardware-retested 2026-08-27; reply posted. His review-body debounce
  question (mod_delayed_work on RGB writes) resolved 2026-08-28 with source
  tracing + on-device measurements (5.3 ms avg command round trip; 1000
  back-to-back sysfs stores in 12 ms, coalesced by the LED core's
  `brightness_set_blocking` deferral): "not a blocker for v3".
- Full v2/v3 sync to the OGC tree:
  [OpenGamingCollective/linux-unstable#11](https://github.com/OpenGamingCollective/linux-unstable/pull/11)
  — opened 2026-08-28, six commits (v2 remainder, timing constants, then
  the four review adoptions with Suggested-by: Derek J. Clark); end state
  byte-identical to `hid-ayaneo/hid-ayaneo.c`. Patches archived in
  `hid-ayaneo/lu-sync/`. **CLOSED by pastaq 2026-08-31** (process, not
  content — CI was green): once a series is on LKML it belongs in the
  regular OGC kernel repo, pulled from the list with `b4 am -cl <url>` and
  `[FROM-ML]`-prefixed subjects. He asked on OGC/linux#101 (2026-09-01) to
  update that PR once v3 is on the mailing list — so #101 is the sync path
  now, fed by v3.
- LKML v3: **SENT 2026-09-17** — Message-ID
  `20260917160722.89391-1-hello@matias.me`, threaded on v2, confirmed
  rendering on lore. Single patch on hid.git for-next, driver
  byte-identical to workbench HEAD, checkpatch clean (known ENOSYS false
  positive only). Under the cut: v3 changelog crediting Derek J. Clark,
  hardware retest note, debounce measurements, deferred-ABI paragraph. Cc
  added Derek J. Clark, Ilpo Järvinen, Armin Wolf. Patch archived as
  `hid-ayaneo/v3-0001-...patch`.
- OGC/linux#101 **updated 2026-09-17** per pastaq's ask: branch rebuilt as
  one `[FROM-ML]` commit off current `features/ayaneo` with the lore Link
  trailer (MAINTAINERS hunk re-anchored for the older base, content
  unchanged; driver byte-identical), PR retitled to match, comment posted
  with the lore link. Awaiting pastaq/NeroReflex.
- gamescope#2347 review round: matte-schwartz asked (2026-09-16) whether
  the washed-out colors were just the old PQ script and why colorimetry is
  re-stated. Replied 2026-09-17
  with the source-verified root cause (EDID CTA advertises BT2020+ST2084 →
  script-less gamescope picks PQ output encoding; colorimetry table conceded
  as redundant, offered to drop it; full edid-decode attached).

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
