#!/usr/bin/env python3
"""Pack the plugin into the zip layout OpenGamepadUI's PluginLoader expects."""
import zipfile

FILES = [
    "plugin.json",
    "plugin.gd",
    "core/magic_modules.gd",
    "core/modules_card.gd",
    "core/modules_card.tscn",
]

with zipfile.ZipFile("ayaneo-modules.zip", "w", zipfile.ZIP_DEFLATED) as z:
    for f in FILES:
        z.write(f, "plugins/ayaneo-modules/" + f)
print("wrote ayaneo-modules.zip")
