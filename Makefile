# OpenCode Termux Builder
# Build wrapped OpenCode packages for Termux

.PHONY: all clean wrap deb

VER ?= latest
PKG ?= deb
OPENCODE_DIR ?= opencode-source
LOADER_DIR ?= bun-termux-loader

all: clean wrap deb

clean:
	rm -rf artifacts staging $(OPENCODE_DIR) $(LOADER_DIR)

clone-opencode:
	git clone --depth 1 --branch dev https://github.com/anomalyco/opencode.git $(OPENCODE_DIR)
	cd $(OPENCODE_DIR) && git apply ../patches/0001-android-support.patch 2>/dev/null || true

install-deps:
	cd $(OPENCODE_DIR) && bun install

build-binary:
	cd $(OPENCODE_DIR)/packages/opencode && bun run build --single --skip-install

clone-loader:
	git clone --depth 1 https://github.com/kaan-escober/bun-termux-loader.git $(LOADER_DIR)

wrap: clone-opencode install-deps build-binary clone-loader
	@BIN="$$(find $(OPENCODE_DIR)/dist -name 'opencode-linux-arm64' -type f | head -1)"; \
	if [ -z "$$BIN" ]; then echo "Binary not found"; exit 1; fi; \
	python3 $(LOADER_DIR)/build.py "$$BIN" \
	  --wrapper $(LOADER_DIR)/wrapper \
	  --shim $(LOADER_DIR)/bunfs_shim.so; \
	mkdir -p artifacts; \
	cp "$${BIN}-termux" artifacts/opencode-termux-aarch64

deb: wrap
	bash scripts/package-deb.sh artifacts/opencode-termux-aarch64 $(VER) artifacts/
