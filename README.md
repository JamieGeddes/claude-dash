# Claude Dash

A native macOS menu-bar app that shows your Claude Code token usage as an
always-on-top Porsche 911 GT3–style instrument cluster.

![reference](gt3.avif)

## Gauges

- **Tachometer (center)** — live token rate (tokens/min over a rolling 60s
  window). The needle kicks on every token-incurring action and decays back to
  zero when idle. The face always reads 0–10; the `TOK/MIN ×Nk` multiplier
  auto-ranges (lockable in Settings).
- **Digital readouts (inside the tach)** — current rate, **TRIP** (tokens in
  the currently-active Claude Code session), and a rolling-digit **odometer**
  (all-time total, persisted independently of Claude's 30-day transcript
  cleanup).
- **Fuel gauges (5H / 7D)** — percentage remaining of your Max/Pro 5-hour and
  7-day rate-limit windows, with reset countdowns, a red low-fuel zone, and an
  amber staleness dot when no fresh data has arrived. Hidden on Enterprise.

## How it gets data

- **Token events**: tails `~/.claude/projects/**/*.jsonl` (including subagent
  transcripts) via FSEvents, deduplicating streamed lines by `requestId`.
  Honors `CLAUDE_CONFIG_DIR`; overridable in Settings.
- **Rate-limit windows**: a small statusline forwarder script (installed with
  your consent — first-launch prompt or Settings) receives Claude Code's
  statusline JSON after every message and stores it for the app.
  `~/.claude/settings.json` is backed up before the one-key change, an existing
  statusline is chained (not replaced), and Uninstall restores everything.

State lives in `~/Library/Application Support/ClaudeDash/`.

The panel is draggable; hover over it for a close button (hides it — reopen
from the menu bar gauge icon, which also has Settings and Quit).

## Build

```sh
make test      # unit tests
make app       # build/ClaudeDash.app (ad-hoc signed)
make install   # copy to /Applications
swift run      # dev loop
```

Useful dev modes:

```sh
CLAUDE_DASH_DEMO=1 open build/ClaudeDash.app --env CLAUDE_DASH_DEMO=1  # synthetic data
./build/ClaudeDash.app/Contents/MacOS/ClaudeDash --snapshot out.png \
    [--low-fuel] [--stale] [--enterprise]                              # render PNG and exit
./build/ClaudeDash.app/Contents/MacOS/ClaudeDash --install-statusline  # scripted consent
```

## Settings

Menu-bar gauge icon → Settings: dashboard design, speedometer scale
(auto/fixed), cache-token counting (off by default — cache reads dwarf real
usage), plan type (Max/Pro vs Enterprise), statusline install/uninstall,
config-dir override, launch at login.

## Adding a dashboard design

Designs are skins over a design-agnostic `DashboardModel`. Create
`Sources/ClaudeDash/Designs/<Name>/`, conform to `DashboardDesign`
(`id`, `displayName`, `preferredSize`, `makeView(model:)`), and add one entry
to `DesignRegistry.all`. Shared primitives (`DialFace`, `NeedleView`,
`OdometerView`, `FontLoader`) are reusable; the GT3 design is the reference
implementation.

## Fonts

Bundles Saira SemiCondensed (SIL OFL) as the closest free match to the Porsche
cluster typeface; if you have Porsche Next installed locally the app uses it
automatically.
