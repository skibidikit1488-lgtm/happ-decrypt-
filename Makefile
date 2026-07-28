.PHONY: all patch build wrap deb clean

OPENCODE_DIR ?= ./opencode
BUILD_DIR = $(OPENCODE_DIR)/packages/opencode
WRAPPER_DIR ?= ./bun-termux-loader
OUTPUT_BINARY ?= ./opencode-termux
DEB_FILE ?= ./opencode-termux.deb

all: patch build wrap deb

patch:
	@echo "[*] Applying patches..."
	cd $(OPENCODE_DIR) && git apply ../patches/0001-android-support.patch 2>/dev/null || true
	bash scripts/termux-patch.sh $(OPENCODE_DIR)

build:
	@echo "[*] Building OpenCode..."
	cd $(BUILD_DIR) && bun install
	cd $(BUILD_DIR) && bun run script/build.ts --single --skip-install --skip-embed-web-ui

wrap:
	@echo "[*] Verifying Bun marker..."
	@BINARY="$(BUILD_DIR)/dist/opencode-linux-arm64/bin/opencode"; \
	if ! strings "$$BINARY" | grep -q "---- Bun! ----"; then \
		echo "ERROR: Bun marker not found in $$BINARY"; exit 1; \
	fi; \
	echo "[*] Wrapping with bun-termux-loader..."; \
	python3 $(WRAPPER_DIR)/build.py --input "$$BINARY" --output $(OUTPUT_BINARY)

deb:
	@echo "[*] Building .deb package..."
	bash scripts/package-deb.sh --binary $(OUTPUT_BINARY) --output $(DEB_FILE)

clean:
	rm -rf $(BUILD_DIR)/dist
	rm -f $(OUTPUT_BINARY) $(DEB_FILE)
