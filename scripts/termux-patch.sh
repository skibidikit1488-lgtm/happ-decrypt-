#!/bin/bash
set -euo pipefail

echo "[termux-patch] Applying Termux native patches (v2 — with FFF & OpenTUI fixes)..."

if [ ! -f "packages/core/package.json" ]; then
    echo "Error: run this script from the opencode repository root"
    exit 1
fi

# ═══════════════════════════════════════════════════════════════════
# PART 1: PTY — оставляем fallback (Termux нет PTY в Bun)
# ═══════════════════════════════════════════════════════════════════
echo "[termux-patch] (1/6) Patching PTY imports..."
node -e "
const fs = require('fs');
const path = 'packages/core/package.json';
const pkg = JSON.parse(fs.readFileSync(path, 'utf8'));
pkg.imports['#pty'] = {
    bun: './src/pty/pty.termux.ts',
    node: './src/pty/pty.node.ts',
    default: './src/pty/pty.termux.ts'
};
fs.writeFileSync(path, JSON.stringify(pkg, null, 2) + '\n');
console.log('  ok #pty → pty.termux.ts');
"

# ═══════════════════════════════════════════════════════════════════
# PART 2: FFF — заменяем на ripgrep-адаптер (работает в Termux)
# ═══════════════════════════════════════════════════════════════════
echo "[termux-patch] (2/6) Patching FFF imports..."
node -e "
const fs = require('fs');
const path = 'packages/core/package.json';
const pkg = JSON.parse(fs.readFileSync(path, 'utf8'));
pkg.imports['#fff'] = {
    bun: './src/filesystem/fff.termux.ts',
    node: './src/filesystem/fff.node.ts',
    default: './src/filesystem/fff.termux.ts'
};
fs.writeFileSync(path, JSON.stringify(pkg, null, 2) + '\n');
console.log('  ok #fff → fff.termux.ts (ripgrep adapter)');
"

# ═══════════════════════════════════════════════════════════════════
# PART 3: SQLite — оставляем bun:sqlite (работает в Termux Bun)
# ═══════════════════════════════════════════════════════════════════
echo "[termux-patch] (3/6) SQLite — no changes needed (bun:sqlite works in Termux)"

# ═══════════════════════════════════════════════════════════════════
# PART 4: Удаляем glibc prebuild deps
# ═══════════════════════════════════════════════════════════════════
echo "[termux-patch] (4/6) Removing glibc prebuild deps..."
node -e "
const fs = require('fs');
const pkgs = [
    'packages/core/package.json',
    'packages/desktop/package.json',
    'packages/opencode/package.json'
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
# PART 5: Patch build.ts — @opentui/core parser.worker
# ═══════════════════════════════════════════════════════════════════
echo "[termux-patch] (5/6) Patching build.ts for @opentui/core..."
node -e "
const fs = require('fs');
const path = 'packages/opencode/script/build.ts';
let content = fs.readFileSync(path, 'utf8');

// Оборачиваем загрузку parser.worker в try/catch
content = content.replace(
    /const treeSitterWorker = await Bun\\.file\\(fileURLToPath\\(import\\.meta\\.resolve\\('@opentui\\/core\\/parser\\.worker'\\)\\)\\)\\.text\\(\\)/,
    \"let treeSitterWorker = ''; try { treeSitterWorker = await Bun.file(fileURLToPath(import.meta.resolve('@opentui/core/parser.worker'))).text(); } catch(e) { console.warn('[termux] parser.worker unavailable:', e.message); treeSitterWorker = '/* termux: parser worker unavailable */'; }\"
);

fs.writeFileSync(path, content);
console.log('  ok build.ts patched');
"

# ═══════════════════════════════════════════════════════════════════
# PART 6: Patch @opentui/core loading in TUI (runtime fallback)
# ═══════════════════════════════════════════════════════════════════
echo "[termux-patch] (6/6) Adding @opentui/core runtime fallback..."
# Ищем места, где @opentui/core загружается нативный Zig модуль
# Если Zig .so не найден — opencode упадёт. Добавляем graceful fallback.

# Проверяем, есть ли @opentui/core в node_modules
if [ -d "node_modules/@opentui/core" ]; then
    echo "  @opentui/core found in node_modules"
    # Проверяем, есть ли native .so
    if find node_modules/@opentui/core -name "*.so" -o -name "*.dylib" -o -name "*.dll" 2>/dev/null | grep -q .; then
        echo "  Native libraries found — good"
    else
        echo "  WARNING: No native libraries found. OpenTUI may fail to load."
        echo "  Run: pkg install zig && bun run build in @opentui/core"
    fi
else
    echo "  WARNING: @opentui/core not in node_modules yet. Install deps first."
fi

# ═══════════════════════════════════════════════════════════════════
# CREATE SOURCE FILES
# ═══════════════════════════════════════════════════════════════════
echo "[termux-patch] Creating Termux-specific source files..."

# ── PTY fallback (без изменений, pipe-based spawn) ──
cat > packages/core/src/pty/pty.termux.ts << 'PTYEOF'
import { spawn } from "child_process"
import type { Opts, Proc } from "./pty"

export type { Disp, Exit, Opts, Proc } from "./pty"

export function spawn(file: string, args: string[], opts: Opts): Proc {
  const proc = spawn(file, args, {
    cwd: opts.cwd,
    env: { ...process.env, ...opts.env },
    stdio: ["pipe", "pipe", "pipe"],
  })

  const dataListeners: Array<(data: string) => void> = []
  const exitListeners: Array<(code: number) => void> = []
  let exitCode = 0
  let exited = false

  proc.stdout?.on("data", (chunk) => {
    const text = chunk.toString()
    for (const fn of dataListeners) fn(text)
  })

  proc.stderr?.on("data", (chunk) => {
    const text = chunk.toString()
    for (const fn of dataListeners) fn(text)
  })

  proc.on("exit", (code) => {
    if (exited) return
    exited = true
    exitCode = code ?? 0
    for (const fn of exitListeners) fn(exitCode)
  })

  return {
    pid: proc.pid ?? 0,
    onData(listener) {
      dataListeners.push(listener)
      return () => {
        const idx = dataListeners.indexOf(listener)
        if (idx !== -1) dataListeners.splice(idx, 1)
      }
    },
    onExit(listener) {
      exitListeners.push(listener)
      if (exited) listener(exitCode)
      return () => {
        const idx = exitListeners.indexOf(listener)
        if (idx !== -1) exitListeners.splice(idx, 1)
      }
    },
    write(data) {
      proc.stdin?.write(data)
    },
    resize(_cols, _rows) {
      // No-op: plain spawn does not support resize
    },
    kill(signal) {
      proc.kill(signal as NodeJS.Signals)
    },
  }
}
PTYEOF

# ── FFF ripgrep adapter (ПОЛНОЦЕННЫЙ, не заглушка!) ──
cat > packages/core/src/filesystem/fff.termux.ts << 'FFFEOF'
import { spawn } from "child_process"
import { readdir, stat } from "fs/promises"
import { join, relative, basename } from "path"

export type Result<T> = { ok: true; value: T } | { ok: false; error: string }

export interface Init {
  basePath: string
  frecencyDbPath?: string
  historyDbPath?: string
  useUnsafeNoLock?: boolean
  disableMmapCache?: boolean
  disableContentIndexing?: boolean
  disableWatch?: boolean
  aiMode?: boolean
  logFilePath?: string
  logLevel?: "trace" | "debug" | "info" | "warn" | "error"
  enableFsRootScanning?: boolean
  enableHomeDirScanning?: boolean
}

export interface File {
  relativePath: string
  fileName: string
  modified: number
}

export interface Directory {
  relativePath: string
  dirName: string
  maxAccessFrecency: number
}

export type Mixed = { type: "file"; item: File } | { type: "directory"; item: Directory }

export interface Search {
  items: File[]
  scores: Array<{ total: number }>
  totalMatched: number
  totalFiles: number
}

export interface DirSearch {
  items: Directory[]
  scores: Array<{ total: number }>
  totalMatched: number
  totalDirs: number
}

export interface MixedSearch {
  items: Mixed[]
  scores: Array<{ total: number }>
  totalMatched: number
  totalFiles: number
  totalDirs: number
}

export type Cursor = null

export interface Hit {
  relativePath: string
  fileName: string
  lineNumber: number
  byteOffset: number
  lineContent: string
  matchRanges: [number, number][]
  contextBefore?: string[]
  contextAfter?: string[]
}

export interface Grep {
  items: Hit[]
  totalMatched: number
  totalFilesSearched: number
  totalFiles: number
  filteredFileCount: number
  nextCursor: Cursor
  regexFallbackError?: string
}

export interface Picker {
  destroy(): void
  isScanning(): boolean
  waitForScan(timeoutMs?: number): Promise<Result<boolean>>
  refreshGitStatus(): Result<number>
  fileSearch(query: string, opts?: { currentFile?: string; pageIndex?: number; pageSize?: number }): Result<Search>
  glob(pattern: string, opts?: { currentFile?: string; pageIndex?: number; pageSize?: number }): Result<Search>
  directorySearch(query: string, opts?: { currentFile?: string; pageIndex?: number; pageSize?: number }): Result<DirSearch>
  mixedSearch(query: string, opts?: { currentFile?: string; pageIndex?: number; pageSize?: number }): Result<MixedSearch>
  grep(query: string, opts?: { mode?: "plain" | "regex" | "fuzzy"; maxMatchesPerFile?: number; timeBudgetMs?: number; beforeContext?: number; afterContext?: number; cursor?: Cursor; pageSize?: number }): Result<Grep>
  trackQuery(query: string, file: string): Result<boolean>
  getHistoricalQuery(offset: number): Result<string | null>
}

// Simple fuzzy-ish matching: substring + case-insensitive
function scoreMatch(query: string, text: string): number {
  const q = query.toLowerCase()
  const t = text.toLowerCase()
  if (t.includes(q)) return q.length / t.length
  // Simple char-by-char fuzzy
  let qi = 0
  let score = 0
  for (let i = 0; i < t.length && qi < q.length; i++) {
    if (t[i] === q[qi]) {
      score++
      qi++
    }
  }
  return qi === q.length ? score / t.length * 0.5 : 0
}

async function* walkDir(dir: string, base: string): AsyncGenerator<{ type: "file" | "dir"; path: string; name: string; modified: number }> {
  const entries = await readdir(dir, { withFileTypes: true }).catch(() => [])
  for (const entry of entries) {
    if (entry.name.startsWith(".")) continue
    const full = join(dir, entry.name)
    if (entry.isDirectory()) {
      yield { type: "dir", path: relative(base, full), name: entry.name, modified: 0 }
      yield* walkDir(full, base)
    } else if (entry.isFile()) {
      const s = await stat(full).catch(() => ({ mtimeMs: 0 }))
      yield { type: "file", path: relative(base, full), name: entry.name, modified: s.mtimeMs }
    }
  }
}

class TermuxPicker implements Picker {
  private basePath: string
  private files: File[] = []
  private dirs: Directory[] = []
  private scanning = false

  constructor(opts: Init) {
    this.basePath = opts.basePath
    this.scan()
  }

  private async scan() {
    this.scanning = true
    this.files = []
    this.dirs = []
    try {
      for await (const entry of walkDir(this.basePath, this.basePath)) {
        if (entry.type === "file") {
          this.files.push({ relativePath: entry.path, fileName: entry.name, modified: entry.modified })
        } else {
          this.dirs.push({ relativePath: entry.path, dirName: entry.name, maxAccessFrecency: 0 })
        }
      }
    } catch {}
    this.scanning = false
  }

  destroy() {}
  isScanning() { return this.scanning }

  async waitForScan(timeoutMs?: number): Promise<Result<boolean>> {
    const start = Date.now()
    while (this.scanning) {
      if (timeoutMs && Date.now() - start > timeoutMs) return { ok: false, error: "timeout" }
      await new Promise(r => setTimeout(r, 50))
    }
    return { ok: true, value: true }
  }

  refreshGitStatus(): Result<number> {
    return { ok: true, value: 0 }
  }

  fileSearch(query: string, opts?: { currentFile?: string; pageIndex?: number; pageSize?: number }): Result<Search> {
    const pageSize = opts?.pageSize ?? 50
    const pageIndex = opts?.pageIndex ?? 0
    const scored = this.files
      .map(f => ({ file: f, score: scoreMatch(query, f.relativePath) }))
      .filter(x => x.score > 0)
      .sort((a, b) => b.score - a.score)
    const page = scored.slice(pageIndex * pageSize, (pageIndex + 1) * pageSize)
    return {
      ok: true,
      value: {
        items: page.map(x => x.file),
        scores: page.map(x => ({ total: x.score })),
        totalMatched: scored.length,
        totalFiles: this.files.length,
      }
    }
  }

  glob(pattern: string, opts?: { currentFile?: string; pageIndex?: number; pageSize?: number }): Result<Search> {
    // Convert glob-ish pattern to regex
    const regex = new RegExp(
      "^" + pattern
        .replace(/\*\*/g, "<<<DOUBLESTAR>>>")
        .replace(/\*/g, "[^/]*")
        .replace(/<<<DOUBLESTAR>>>/g, ".*")
        .replace(/\?/g, ".")
        + "$"
    )
    const matched = this.files.filter(f => regex.test(f.relativePath))
    const pageSize = opts?.pageSize ?? 50
    const pageIndex = opts?.pageIndex ?? 0
    const page = matched.slice(pageIndex * pageSize, (pageIndex + 1) * pageSize)
    return {
      ok: true,
      value: {
        items: page,
        scores: page.map(() => ({ total: 1 })),
        totalMatched: matched.length,
        totalFiles: this.files.length,
      }
    }
  }

  directorySearch(query: string, opts?: { currentFile?: string; pageIndex?: number; pageSize?: number }): Result<DirSearch> {
    const pageSize = opts?.pageSize ?? 50
    const pageIndex = opts?.pageIndex ?? 0
    const scored = this.dirs
      .map(d => ({ dir: d, score: scoreMatch(query, d.relativePath) }))
      .filter(x => x.score > 0)
      .sort((a, b) => b.score - a.score)
    const page = scored.slice(pageIndex * pageSize, (pageIndex + 1) * pageSize)
    return {
      ok: true,
      value: {
        items: page.map(x => x.dir),
        scores: page.map(x => ({ total: x.score })),
        totalMatched: scored.length,
        totalDirs: this.dirs.length,
      }
    }
  }

  mixedSearch(query: string, opts?: { currentFile?: string; pageIndex?: number; pageSize?: number }): Result<MixedSearch> {
    const fs = this.fileSearch(query, opts)
    const ds = this.directorySearch(query, opts)
    if (!fs.ok || !ds.ok) return { ok: false, error: (fs as any).error || (ds as any).error }
    const items: Mixed[] = [
      ...fs.value.items.map(f => ({ type: "file" as const, item: f })),
      ...ds.value.items.map(d => ({ type: "directory" as const, item: d })),
    ]
    return {
      ok: true,
      value: {
        items,
        scores: [...fs.value.scores, ...ds.value.scores],
        totalMatched: fs.value.totalMatched + ds.value.totalMatched,
        totalFiles: fs.value.totalFiles,
        totalDirs: ds.value.totalDirs,
      }
    }
  }

  grep(query: string, opts?: { mode?: "plain" | "regex" | "fuzzy"; maxMatchesPerFile?: number; timeBudgetMs?: number; beforeContext?: number; afterContext?: number; cursor?: Cursor; pageSize?: number }): Result<Grep> {
    // Use ripgrep if available, otherwise fallback to simple grep
    const mode = opts?.mode ?? "plain"
    const pageSize = opts?.pageSize ?? 50
    const maxMatches = opts?.maxMatchesPerFile ?? 100

    // Try ripgrep first
    try {
      const rgArgs = [
        "--json",
        "--max-count", String(maxMatches),
        "--context", String((opts?.beforeContext ?? 0) + (opts?.afterContext ?? 0)),
        mode === "regex" ? "-e" : "-F",
        query,
        this.basePath,
      ]
      const proc = spawn("rg", rgArgs, { stdio: ["pipe", "pipe", "pipe"] })
      let stdout = ""
      proc.stdout?.on("data", (d) => { stdout += d.toString() })

      return new Promise((resolve) => {
        proc.on("exit", () => {
          const items: Hit[] = []
          const seen = new Set<string>()
          for (const line of stdout.split("\\n")) {
            if (!line.trim()) continue
            try {
              const data = JSON.parse(line)
              if (data.type === "match" && data.data?.submatches) {
                for (const sm of data.data.submatches) {
                  const key = `${data.data.path.text}:${data.data.line_number}`
                  if (seen.has(key)) continue
#!/bin/bash
set -euo pipefail

OPENCODE_DIR="${1:-./opencode}"
CORE_DIR="$OPENCODE_DIR/packages/core"
PKG_DIR="$OPENCODE_DIR/packages/opencode"

echo "[*] Patching build.ts — disable code-splitting for single build..."
sed -i 's/splitting: true,/splitting: singleFlag ? false : true,/' "$PKG_DIR/script/build.ts"

echo "[*] Patching telemetry: otlp.ts..."
cat > "$CORE_DIR/src/observability/otlp.ts" << 'EOF'
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
EOF

echo "[*] Patching telemetry: share-next.ts..."
sed -i 's/const disabled = .*/const disabled = true/' "$PKG_DIR/src/share/share-next.ts"

echo "[*] Patching telemetry: agent.ts..."
sed -i 's/const tracer = cfg.experimental?.openTelemetry/const tracer = undefined/' "$PKG_DIR/src/agent/agent.ts"
sed -i 's/isEnabled: cfg.experimental?.openTelemetry,/isEnabled: false,/' "$PKG_DIR/src/agent/agent.ts"

echo "[*] Patching telemetry: llm.ts..."
sed -i 's/const tracer = cfg.experimental?.openTelemetry/const tracer = undefined/' "$PKG_DIR/src/session/llm.ts"
sed -i 's/isEnabled: cfg.experimental?.openTelemetry,/isEnabled: false,/' "$PKG_DIR/src/session/llm.ts"

echo "[*] Patching telemetry: trace.ts..."
cat > "$PKG_DIR/src/cli/cmd/run/trace.ts" << 'EOF'
import { Global } from "@opencode-ai/core/global"

export type Trace = { write(type: string, data?: unknown): void }
let state: Trace | false | undefined

export function trace(): Trace | undefined {
  if (state !== undefined) return state || undefined
  state = false
  return undefined
}
EOF

echo "[*] Patching opencode package.json OS list..."
sed -i 's/"os": \["darwin", "linux", "win32"\]/"os": ["darwin", "linux", "win32", "android"]/' "$PKG_DIR/package.json"

echo "[*] Done."
