.PHONY: all patch build wrap deb clean

OPENCODE_DIR ?= ./opencode
BUILD_DIR = $(OPENCODE_DIR)/packages/opencode
WRAPPER_DIR ?= ./bun-termux-loader
OUTPUT_BINARY ?= ./opencode-termux
DEB_FILE ?= ./opencode-termux.deb

all: patch build wrap deb

patch:
	@echo "[*] Applying patches..."
	bash scripts/termux-patch.sh $(OPENCODE_DIR)

build:
	@echo "[*] Building OpenCode..."
	cd $(OPENCODE_DIR) && bun install
	cd $(BUILD_DIR) && bun run script/build.ts --single --skip-install --skip-embed-web-ui

wrap:
	@echo "[*] Wrapping with bun-termux-loader..."
	cd $(WRAPPER_DIR) && python3 build.py \
		../$(BUILD_DIR)/dist/opencode-linux-arm64/bin/opencode \
		../$(OUTPUT_BINARY)

deb:
	@echo "[*] Building .deb package..."
	bash scripts/package-deb.sh $(OUTPUT_BINARY) $(DEB_FILE)

clean:
	rm -rf $(OPENCODE_DIR)/dist
	rm -f $(OUTPUT_BINARY) $(DEB_FILE)
