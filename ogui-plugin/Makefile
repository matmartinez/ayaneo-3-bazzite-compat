PLUGIN_ID ?= $(shell grep 'plugin\.id' plugin.json | grep -o ':.*' | grep -o '"[^"]\+"' | sed 's/"//g')
PLUGIN_NAME ?= $(shell grep 'plugin\.name' plugin.json | grep -o ':.*' | grep -o '"[^"]\+"' | sed 's/"//g')

GODOT ?= /usr/bin/godot
OPENGAMEPAD_UI_REPO ?= https://github.com/ShadowBlip/OpenGamepadUI.git
OPENGAMEPAD_UI_BASE ?= ../OpenGamepadUI
EXPORT_PRESETS ?= $(OPENGAMEPAD_UI_BASE)/export_presets.cfg
PLUGINS_DIR := $(OPENGAMEPAD_UI_BASE)/plugins
INSTALL_DIR := $(HOME)/.local/share/opengamepadui/plugins

.PHONY: dist
dist: build ## Build and package plugin

.PHONY: build
build: $(PLUGINS_DIR)/$(PLUGIN_ID) export_preset ## Build the plugin
	@echo "Exporting plugin package"
	cd $(OPENGAMEPAD_UI_BASE) && $(MAKE) addons
	mkdir -p dist
	touch dist/.gdignore
	$(GODOT) --headless \
		--path $(OPENGAMEPAD_UI_BASE) \
		--export-pack "$(PLUGIN_NAME)" \
		plugins/$(PLUGIN_ID)/dist/$(PLUGIN_ID).zip
	cd dist && sha256sum $(PLUGIN_ID).zip > $(PLUGIN_ID).zip.sha256.txt

.PHONY: install
install: dist ## Install the plugin for the current user
	mkdir -p "$(INSTALL_DIR)"
	cp dist/$(PLUGIN_ID).zip "$(INSTALL_DIR)"

.PHONY: export_preset
export_preset: ## Add an export preset for this plugin to the OGUI checkout
	@grep -q 'name="$(PLUGIN_NAME)"' $(EXPORT_PRESETS) || { \
		echo "Add an export preset named '$(PLUGIN_NAME)' to $(EXPORT_PRESETS)"; \
		echo "including only res://plugins/$(PLUGIN_ID)/* (copy an existing plugin preset)."; \
		exit 1; \
	}

$(PLUGINS_DIR)/$(PLUGIN_ID): $(OPENGAMEPAD_UI_BASE)
	mkdir -p $(PLUGINS_DIR)
	ln -sfn $(CURDIR) $(PLUGINS_DIR)/$(PLUGIN_ID)

$(OPENGAMEPAD_UI_BASE):
	git clone $(OPENGAMEPAD_UI_REPO) $(OPENGAMEPAD_UI_BASE)
