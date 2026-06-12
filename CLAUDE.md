# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Claude Dash: a native macOS (14+) menu-bar app showing Claude Code token usage as an always-on-top Porsche 911 GT3-style gauge cluster. Pure SwiftPM (no .xcodeproj), unsandboxed, Swift 5.10 language mode. `gt3.avif` is the visual reference for the GT3 design; `exige.jpg` for the Lotus design.

## Commands

```sh
swift build                # debug build
swift test                 # all tests
swift test --filter TranscriptParserTests                      # one suite
swift test --filter UsageMonitorTests/testDeduplicatesByRequestId  # one test
swift run                  # dev loop (works outside an .app bundle)
make app                   # assemble build/ClaudeDash.app (release + ad-hoc codesign)
make install               # copy to /Applications
```

Visual development (screencapture is TCC-blocked; use the built-in renderer instead):

```sh
./build/ClaudeDash.app/Contents/MacOS/ClaudeDash --snapshot /tmp/out.png [--low-fuel] [--stale] [--enterprise]
CLAUDE_DASH_DEMO=1 open build/ClaudeDash.app --env CLAUDE_DASH_DEMO=1   # synthetic events, separate state-demo.json
```

Kill a running instance before rebuilding/relaunching: `pkill -x ClaudeDash`.

## Architecture

Strict one-way flow: **Core (data) → DashboardModel → Designs (presentation)**.

```
TranscriptWatcher (FSEvents on ~/.claude/projects, bg queue)
  └─ TranscriptTailer per file (byte-offset tail) ─ TranscriptParser (line → UsageEvent)
       └─ Update batches hop to @MainActor → UsageMonitor (dedup, totals, trip, RateWindow)
            ├─ OdometerStore (state.json persistence)
            └─ DashboardModel  ←also─ StatuslineFeed (fuel/rate-limit data)
                 └─ read-only by designs via DashboardDesign.makeView(model:)
```

- `Designs/DashboardModel.swift` is the only interface designs see. Designs must never import/touch Core types; Core never references a specific design. Adding a design = new folder under `Sources/ClaudeDash/Designs/<Name>/` conforming to `DashboardDesign` + one entry in `DesignRegistry.all`. Shared gauge primitives (parameterized `DialFace`, `NeedleView`, `OdometerView`, `FontLoader`) live in `Designs/Shared/`.
- `AppDelegate` owns the object graph, the `OverlayPanel` (borderless non-activating NSPanel), CLI flags (`--snapshot`, `--install-statusline`/`--uninstall-statusline`), and the first-launch statusline consent dialog.

## Correctness invariants (the bugs that matter here)

- **Dedup by requestId**: transcript JSONL lines repeat per `requestId` with identical usage; count only the first occurrence. `UsageMonitor` keeps an in-memory seen-set plus a persisted ring (~1k) in state.json so restarts straddling a duplicate don't double-count. Tailer offsets commit only at newline boundaries, after ingest.
- **Subagent transcripts** live at `<project-slug>/<session-uuid>/subagents/*.jsonl` and carry the *parent* sessionId — discovery must stay recursive (and skip `tool-results/`).
- **Odometer never decrements**: totals in state.json are independent of file presence (Claude cleans transcripts up after ~30 days). Truncated/replaced files re-parse from 0 and rely on the seen-ring.
- **Four token components stored separately** (input/output/cacheCreation/cacheRead) everywhere — the "count cache tokens" setting is display-only and must never require a rescan.
- **Monthly spend is an estimate** computed per event (`Pricing.costUSD`: tokens × per-model family rates, cache writes 1.25×/2× by TTL split, reads 0.1×) and accumulated into `state.monthlySpend["YYYY-MM"]` inside the same deduped ingest path as the odometer. `SpendSeeder` runs once on upgrade from v1 state: it prices only the checkpointed byte ranges `[0, offset)` (events already token-counted) and must finish **before** the watcher starts — that partition is what prevents spend double-counting. `monthlySpend`/`spendSeeded` are optional in `DashState` so v1 state files decode without resetting the odometer. Pricing table is cached (2026-06) — refresh from the claude-api skill when models change.
- **Rate-limit (fuel) data is NOT in transcripts** — only in the statusline JSON written by the forwarder script. `StatuslineInstaller` is the sole component that modifies the user's `~/.claude/settings.json`: backup first, merge only the `statusLine` key, atomic write, chain (don't replace) a foreign statusline, uninstall restores. Tests must pass explicit temp `configDir:`/`scriptDir:` — never let tests touch the real config or Application Support.
- Installing the statusline into the user's live settings requires the user's own action (app consent dialog / Settings button); don't script it against the real `~/.claude`.

## User-confirmed product decisions (don't re-litigate)

Speedo needle = tokens/min over rolling 60s (auto-ranging ×1k–×50k multiplier, face always 0–10); trip = currently-active session (most recent live event's sessionId); default counting = input+output; fuel gauges = 5h/7d windows remaining, Max/Pro only (Enterprise hides them; `AdminAPIFuelSource` is a phase-2 stub). Multiple dashboard designs must remain supported.

## App data locations

`~/Library/Application Support/ClaudeDash/` — `state.json` (odometer/checkpoints), `statusline.json` (feed), `statusline-forwarder.sh`. Config dir resolution: settings override → `CLAUDE_CONFIG_DIR` env → `launchctl getenv` → `~/.claude` (`Paths.swift`).
