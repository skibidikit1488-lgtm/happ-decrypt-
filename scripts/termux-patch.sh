#!/bin/bash
set -euo pipefail

OPENCODE_DIR="${1:-./opencode}"
CORE_DIR="$OPENCODE_DIR/packages/core"
PKG_DIR="$OPENCODE_DIR/packages/opencode"

echo "[termux-patch] Patching for Termux wrapper build..."

# ═══════════════════════════════════════════════════════════════════
# 1. Disable code-splitting for single build (self-contained binary)
# ═══════════════════════════════════════════════════════════════════
echo "[*] Patching build.ts — disable splitting for single build..."
sed -i 's/splitting: true,/splitting: singleFlag ? false : true,/' "$PKG_DIR/script/build.ts"

# ═══════════════════════════════════════════════════════════════════
# 2. Patch @opentui/core parser.worker loading (graceful fallback)
# ═══════════════════════════════════════════════════════════════════
echo "[*] Patching build.ts for @opentui/core..."
sed -i \
  's/const treeSitterWorker = await Bun\.file(fileURLToPath(import\.meta\.resolve('\''@opentui\/core\/parser\.worker'\'')))\.text()/let treeSitterWorker = '\'''\''; try { treeSitterWorker = await Bun.file(fileURLToPath(import.meta.resolve('\''@opentui\/core\/parser.worker'\''))).text(); } catch(e) { console.warn('\''[termux] parser.worker unavailable:'\'', e.message); treeSitterWorker = '\''\/* termux: parser worker unavailable *\/'\''; }/' \
  "$PKG_DIR/script/build.ts"

# ═══════════════════════════════════════════════════════════════════
# 3. Remove glibc prebuild deps (not needed with wrapper)
# ═══════════════════════════════════════════════════════════════════
echo "[*] Removing glibc prebuild devDependencies..."
node -e "
const fs = require('fs');
const pkgs = [
    '$CORE_DIR/package.json',
    '$PKG_DIR/package.json'
];
const toRemove = [
    '@parcel/watcher-darwin-arm64',
    '@parcel/watcher-darwin-x64',
    '@parcel/watcher-linux-arm64-glibc',
    '@parcel/watcher-linux-arm64-musl',
    '@parcel/watcher-linux-x64-glibc',
    '@parcel/watcher-linux-x64-musl',
    '@parcel/watcher-win32-arm64',
    '@parcel/watcher-win32-x64',
    '@lydell/node-pty-darwin-arm64',
    '@lydell/node-pty-darwin-x64',
    '@lydell/node-pty-linux-arm64',
    '@lydell/node-pty-linux-x64',
    '@lydell/node-pty-win32-arm64',
    '@lydell/node-pty-win32-x64'
];
for (const p of pkgs) {
    if (!fs.existsSync(p)) continue;
    const pkg = JSON.parse(fs.readFileSync(p, 'utf8'));
    for (const dep of toRemove) {
        delete (pkg.devDependencies || {})[dep];
        delete (pkg.dependencies || {})[dep];
    }
    fs.writeFileSync(p, JSON.stringify(pkg, null, 2) + '\n');
    console.log('  ok cleaned ' + p);
}
"

# ═══════════════════════════════════════════════════════════════════
# 4. Binary-level telemetry disable
# ═══════════════════════════════════════════════════════════════════
echo "[*] Patching telemetry: otlp.ts..."
cat > "$CORE_DIR/src/observability/otlp.ts" << 'OTLP_EOF'
import { Layer } from "effect"
import { Flag } from "../flag/flag"
import { InstallationChannel, InstallationVersion } from "../installation/version"
import { runID } from "./shared"

function resourceAttributes() {
  const value = process.env.OTEL_RESOURCE_ATTRIBUTES
  if (!value) return {}
  try {
    return Object.fromEntries(
      value.split(",").map((entry) => {
        const index = entry.indexOf("=")
        if (index < 1) throw new Error("Invalid OTEL_RESOURCE_ATTRIBUTES entry")
        return [decodeURIComponent(entry.slice(0, index)), decodeURIComponent(entry.slice(index + 1))]
      }),
    )
  } catch {
    return {}
  }
}

export function resource(): { serviceName: string; serviceVersion: string; attributes: Record<string, string> } {
  return {
    serviceName: "opencode",
    serviceVersion: InstallationVersion,
    attributes: {
      ...resourceAttributes(),
      "deployment.environment.name": InstallationChannel,
      "opencode.client": Flag.OPENCODE_CLIENT,
      "opencode.run": runID,
      "service.instance.id": runID,
    },
  }
}

export function loggers() { return [] }
export async function tracingLayer() { return Layer.empty }
export * as Otlp from "./otlp"
OTLP_EOF

echo "[*] Patching telemetry: share-next.ts..."
sed -i 's/const disabled = .*/const disabled = true/' "$PKG_DIR/src/share/share-next.ts"

echo "[*] Patching telemetry: agent.ts..."
sed -i 's/const tracer = cfg.experimental?.openTelemetry/const tracer = undefined/' "$PKG_DIR/src/agent/agent.ts"
sed -i 's/isEnabled: cfg.experimental?.openTelemetry,/isEnabled: false,/' "$PKG_DIR/src/agent/agent.ts"

echo "[*] Patching telemetry: llm.ts..."
sed -i 's/const tracer = cfg.experimental?.openTelemetry/const tracer = undefined/' "$PKG_DIR/src/session/llm.ts"
sed -i 's/isEnabled: cfg.experimental?.openTelemetry,/isEnabled: false,/' "$PKG_DIR/src/session/llm.ts"

echo "[*] Patching telemetry: trace.ts..."
cat > "$PKG_DIR/src/cli/cmd/run/trace.ts" << 'TRACE_EOF'
import { Global } from "@opencode-ai/core/global"

export type Trace = { write(type: string, data?: unknown): void }
let state: Trace | false | undefined

export function trace(): Trace | undefined {
  if (state !== undefined) return state || undefined
  state = false
  return undefined
}
TRACE_EOF

# ═══════════════════════════════════════════════════════════════════
# 5. Add android to OS list
# ═══════════════════════════════════════════════════════════════════
echo "[*] Patching opencode package.json OS list..."
sed -i 's/"os": \["darwin", "linux", "win32"\]/"os": ["darwin", "linux", "win32", "android"]/' "$PKG_DIR/package.json"


echo "[*] Done."
