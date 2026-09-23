# Design: AIMICO V1 mascot + Layout E1 on Garmin xDrip Watchface

**Repo:** https://github.com/MTR93600/Garmin-xDrip-Watchface  
**Date:** 2026-09-23  
**Status:** Awaiting user review before implementation plan  

## Goal

Modernize the Connect IQ watchface UI to match the AIMICO V1 / photo-style layout (mascot left, glucose XXL right, time bottom) while:

1. Keeping **all current data advantages** (AAPS/xDrip/Spike/Nightscout sync, IOB/TBR/COB, graph, HR/steps display and **HTTP upload** to AAPS).
2. Switching the **unicorn bitmap** by glucose range (low / in-range / high).
3. Switching the **trend arrow** by glucose direction.

## Non-goals (this phase)

- Porting the full xDrip Custom Watchface JSON engine (phone).
- Shipping AIMICO V2 art (V1 only for now; V2 can be a later skin setting).
- Changing AAPS server endpoints or Request Key behavior.
- Store submission / renaming the CIQ app id (can follow later).

## Approved direction

| Choice | Decision |
|--------|----------|
| Layout | **E1** — mascot left, BG XXL right, loop metrics under/near mascot, activity under BG, time large at bottom |
| Mascot set | **AIMICO V1** (`CoverPlateLow` / `CoverPlate` / `CoverPlateHigh`) |
| Trend | AIMICO V1 `Arrow*.svg` → PNGs |
| Data path | Preserve existing `CGMWatchfaceBG.mc` request/response + HR/steps query params |

Source art (reference, already copied under `assets/aimico-v1/`):

- `CoverPlateLow.svg` — BG below low target  
- `CoverPlate.svg` — in range (sunglasses)  
- `CoverPlateHigh.svg` — BG above high target  
- `ArrowFlat.svg`, `ArrowSingleUp.svg`, `ArrowSingleDown.svg`, `Arrow45Up.svg`, `Arrow45Down.svg`, `ArrowDoubleUp.svg`, `ArrowDoubleDown.svg`, `ArrowNone.svg`

## Functional requirements

### Keep (must not regress)

- Data sources: xDrip+, AAPS (`127.0.0.1:28891`), Spike, Nightscout (± token).
- Display: time, date (where space allows), SGV, age, delta/trend, graph points, IOB, TBR/basal, COB, steps (+ goal bar if space), heart rate, notification/alarm indicators as today when feasible.
- **Outbound to AAPS** on `/sgv.json`: `steps`, `hr`, `hrStart`, `hrEnd`, `device` (existing behavior in `CGMWatchfaceBG.mc`).
- Settings: companion app, units, targets, delay, low power, pin fit, colors, notifications.
- Low power mode: reduced face (clock + SGV minimum); mascot optional via setting (default off in low power to save memory/draw).

### Add

1. **Mascot state machine** driven by last SGV vs `Zielbereich1` / `Zielbereich2` (existing target properties):
   - `sgv < low` → `MascotLow`
   - `low ≤ sgv ≤ high` → `MascotInRange`
   - `sgv > high` → `MascotHigh`
   - No valid SGV → hide mascot or show InRange greyed (prefer hide).

2. **Arrow state machine** driven by existing trend logic (delta / arrow selection already used for `auswahlPfeil` / trend icons):
   - Map current trend enum to the matching AIMICO arrow drawable.
   - If unknown → `ArrowNone` or Flat.

3. **Layout E1 drawing** (high power / full face):
   - Top: optional status row (Bluetooth / battery / notifications) if already available.
   - Left ~45%: mascot bitmap + compact IOB / TBR / COB stack.
   - Right ~55%: large SGV (color by range), age, delta, steps + HR.
   - Bottom: centered time (large).
   - Graph: compact (mini sparkline under loop stack **or** thin vertical strip) — must remain, may be smaller than classic 4-quadrant.

4. **Setting** `showMascot` (list: On / Off / Off in low power only). Default: On for high power, Off in low power.

## Architecture

```
CGMWatchfaceBG.mc          # UNCHANGED contract: fetch SGV + post hr/steps
        │
        ▼
Stored reading map         # punkte[0]: sgv, iob, cob, tbr, date, …
        │
        ▼
CGMWatchfaceView.mc        # REWORK draw path for E1
        │
        ├─ resolveMascot(sgv, low, high) → Rez.Drawables.Mascot*
        ├─ resolveArrow(trend) → Rez.Drawables.Arrow*
        └─ drawE1Layout(dc) / drawLowPower(dc)
```

No change to HTTP URL builders except if a future AAPS field is needed (out of scope).

### Asset pipeline

1. Rasterize SVGs → PNG (transparent), max height ~110–130 px for mascots, ~28–36 px for arrows.
2. Place under `resources/drawables/` + declare in `drawables.xml`.
3. Keep originals in `assets/aimico-v1/` for regeneration (not loaded by CIQ at runtime).

Memory budget: prefer ≤ ~80–100 KB total new bitmaps on mid devices; test on `venux1` and one MIP device.

## UI layout sketch (rectangular / Venu X1)

```
┌─────────────────────────────────────┐
│  status (optional)                  │
│  ┌──────────┐    ┌───────────────┐  │
│  │  MASCOT  │    │   150  (XXL) │  │
│  │  (V1)    │    │   3m  · −2 ↑ │  │
│  │          │    │   steps · HR │  │
│  │ IOB/TBR  │    └───────────────┘  │
│  │ COB+graph│                       │
│  └──────────┘                       │
│              5:50                   │
└─────────────────────────────────────┘
```

Round faces: same hierarchy with tighter padding; time slightly smaller if needed.

## Error / edge cases

| Case | Behavior |
|------|----------|
| HTTP error | Keep last good reading + last mascot/arrow; show error text as today |
| mmol vs mg/dl | Compare in mg/dl internally (convert if needed) before mascot thresholds |
| Target props missing | Fall back 70 / 180 mg/dl |
| Drawable missing | Skip bitmap, keep numbers |

## Testing

1. Simulator `venux1` + one round device: in-range / low / high SGV → correct mascot.
2. Forced deltas → each arrow drawable.
3. AAPS mode: confirm request still includes `steps` + `hr*` (log / proxy).
4. Low power: clock+SGV; mascot respects setting.
5. Side-load PRG; verify no out-of-memory on older CIQ devices in product list.

## Implementation order (preview — detailed plan after spec approval)

1. Asset conversion + `drawables.xml`
2. Mascot + arrow resolvers (unit-testable pure functions if split)
3. E1 `onUpdate` layout (feature-flag or setting to fall back to classic temporarily)
4. Wire setting `showMascot`
5. Regression pass on BG fetch + AAPS HR/steps
6. README update (AIMICO skin + screenshot)

## Open points (resolve during plan if needed)

- Exact graph placement (sparkline under loop vs side strip).
- Whether classic 4-quadrant remains selectable via setting (`layoutStyle`: Classic / E1) for safer rollout — **recommended: yes**, default E1.
