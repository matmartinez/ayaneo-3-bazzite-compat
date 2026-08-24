# Testing the AYANEO 3 magic modules stack on Bazzite 44

For AYANEO 3 owners on Bazzite ≥ 44 who want to try the module support
(pop-out + identification + Quick Bar UI) before it ships in the OGC
kernel. Everything runs from your user account; nothing modifies the OS
image. Roughly 5 minutes.

> ⚠️ The eject test physically releases a controller module. Hold the
> device so the module can't drop. Also: L/R modules are not
> interchangeable — don't swap sides when reinserting.

## 1. Build and load the kernel driver

Bazzite ships `kernel-devel`, `gcc` and `make` in the base image:

```sh
git clone https://github.com/matmartinez/ayaneo-3-bazzite-compat.git
cd ayaneo-3-bazzite-compat/hid-ayaneo
make
sudo insmod hid-ayaneo.ko
```

Verify it bound and sees your modules:

```sh
sudo dmesg | grep hid-ayaneo
# hid-ayaneo ...: modules: left 0x04 right 0x50   <- your module IDs
```

The module does not persist across reboots — re-run `sudo insmod` after
each boot (until the driver lands in the OGC kernel).

## 2. Install the udev rule (unprivileged access)

```sh
sudo cp ../ogui-plugin/70-ayaneo-modules.rules /etc/udev/rules.d/
sudo udevadm control --reload
sudo udevadm trigger -c add --subsystem-match=platform
sudo udevadm trigger -c bind --subsystem-match=hid
```

## 3. Install the OpenGamepadUI plugin

Download `ayaneo-modules.zip` from the repo's
[Releases](https://github.com/matmartinez/ayaneo-3-bazzite-compat/releases)
page (or build it: `cd ogui-plugin && python3 pack.py`), then:

```sh
mkdir -p ~/.local/share/opengamepadui/plugins
cp ayaneo-modules.zip ~/.local/share/opengamepadui/plugins/
```

Reboot (or from game mode: `systemctl --user restart
gamescope-session-plus@ogui-steam.service` over SSH — note this
restarts Steam).

## 4. Use it

In game mode press **AYA + B** to open the OpenGamepadUI Quick Bar. You
should see a **Magic Modules** card:

```
● Pop Left · Cross / Joystick
● Pop Right · ABXY \ Joystick
          Pop Both
L/R modules are not interchangeable
```

Select a Pop button (hold the device!): the button shows "Ejecting…",
the controller powers off, and the module releases. Reinsert it and the
controller powers back on automatically within a couple of seconds.

## Command-line smoke test (no UI needed)

```sh
D=$(ls -d /sys/bus/hid/drivers/hid-ayaneo/0003:1C4F:0002.* | head -1)
cat $D/module_left $D/module_right          # module type IDs
cat /sys/devices/platform/ayaneo-ec/controller_modules   # both/left/right/none
echo right | sudo tee $D/eject              # blocks ~4s until firmware confirms
echo 0 | sudo tee /sys/devices/platform/ayaneo-ec/controller_power  # releases it
# reinsert, then:
echo 1 | sudo tee /sys/devices/platform/ayaneo-ec/controller_power
```

## Reporting results

Please include: Bazzite version (`rpm-ostree status`), kernel
(`uname -r`), `sudo dmesg | grep hid-ayaneo`, your module IDs, and what
worked/failed. Comment on
[ShadowBlip/OpenGamepadUI#528](https://github.com/ShadowBlip/OpenGamepadUI/issues/528)
or open an issue on this repo.
