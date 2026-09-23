# AIMICO V1 + Layout E1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an opt-in E1 AIMICO layout (dynamic unicorn + trend arrows) on branch `dev/aimico-e1` without changing default Classic behavior or AAPS/xDrip data sync.

**Architecture:** Keep `CGMWatchfaceBG.mc` HTTP contract untouched. Add rasterized AIMICO V1 bitmaps + small resolvers. Gate new UI behind `layoutStyle` setting (`0` Classic default, `1` E1). Extract E1 drawing into `CGMWatchfaceE1.mc` so `CGMWatchfaceView.mc` classic path stays intact.

**Tech Stack:** Connect IQ Monkey C, existing WatchUi/Gfx/Communications, ImageMagick for SVG→PNG, Garmin Simulator `venux1`.

**Branch:** `dev/aimico-e1` (never force-push `master`).

## Global Constraints

- Default `layoutStyle=0` (Classic) — existing look/behavior unchanged until user opts in.
- Do not change AAPS/xDrip URL builders or HR/steps query params in `CGMWatchfaceBG.mc`.
- Mascot art = AIMICO V1 only (`assets/aimico-v1/`).
- Compare SGV to targets in mg/dl for mascot thresholds.
- Prefer ≤ ~100 KB new bitmap payload; transparent PNGs.
- Spec: `docs/superpowers/specs/2026-09-23-aimico-e1-watchface-design.md`.

---

## File map

| File | Role |
|------|------|
| `assets/aimico-v1/*.svg` | Source art (already committed) |
| `resources/drawables/mascot_*.png`, `aimico_arrow_*.png` | Runtime bitmaps |
| `resources/drawables/drawables.xml` | Register new bitmaps |
| `resources/settings/properties.xml` | `layoutStyle`, `showMascot` defaults |
| `resources/settings/settings.xml` | User-facing options |
| `resources/strings/strings.xml` | Setting labels |
| `source/AimicoState.mc` | Pure helpers: mascot + arrow resolution |
| `source/CGMWatchfaceE1.mc` | E1 layout drawing |
| `source/CGMWatchfaceView.mc` | Branch to Classic vs E1; leave Classic path alone |
| `source/CGMWatchfaceBG.mc` | **No functional changes** |
| `README.md` | Document layout setting + branch |

---

### Task 1: Rasterize AIMICO V1 assets + register drawables

**Files:** `resources/drawables/*`, `drawables.xml`, `scripts/rasterize-aimico.sh` (optional)

- [ ] Step 1: Convert `CoverPlateLow/CoverPlate/CoverPlateHigh` → `mascot_low.png`, `mascot_inrange.png`, `mascot_high.png` (transparent, ~120 px tall).
- [ ] Step 2: Convert `Arrow*.svg` → `aimico_arrow_*.png` (~32 px).
- [ ] Step 3: Register all in `drawables.xml` with stable ids (`MascotLow`, `MascotInRange`, `MascotHigh`, `AimicoArrowFlat`, …).
- [ ] Step 4: Commit `Rasterize AIMICO V1 mascot and arrow bitmaps.`

---

### Task 2: Settings — layoutStyle + showMascot (Classic default)

**Files:** `properties.xml`, `settings.xml`, `strings.xml`

- [ ] Step 1: Add `layoutStyle` number default `0` (Classic=0, E1=1).
- [ ] Step 2: Add `showMascot` number default `1` (Off=0, On=1, OffInLowPower=2).
- [ ] Step 3: Wire list entries + English strings.
- [ ] Step 4: Commit `Add Classic/E1 layout and mascot settings (Classic default).`

---

### Task 3: AimicoState resolvers

**Files:** `source/AimicoState.mc` (new)

- [ ] Step 1: Implement `mascotKind(sgvMgdl, low, high)` → `:low | :inrange | :high | :none`.
- [ ] Step 2: Implement `arrowKind(auswahlPfeil as String)` mapping existing strings (`DoubleDown`…`DoubleUp`) → AIMICO drawable ids / symbols.
- [ ] Step 3: Manually verify mapping table against View’s delta thresholds (no Monkey unit runner required).
- [ ] Step 4: Commit `Add AimicoState mascot and arrow resolvers.`

---

### Task 4: E1 layout module (draw only)

**Files:** `source/CGMWatchfaceE1.mc` (new)

- [ ] Step 1: Implement `draw(dc, ctx)` with E1 regions: mascot+loop left, SGV XXL+delta+steps/HR right, time bottom, compact graph.
- [ ] Step 2: Respect `showMascot` + low-power (no mascot when Off / OffInLowPower).
- [ ] Step 3: Use existing colors (in-range / alarm) for SGV.
- [ ] Step 4: Commit `Add CGMWatchfaceE1 layout drawer.`

---

### Task 5: Wire View without breaking Classic

**Files:** `source/CGMWatchfaceView.mc`

- [ ] Step 1: After data prep (punkte, anzeige*, auswahlPfeil), if `layoutStyle==1` and high-power (or low-power rules), call `CGMWatchfaceE1.draw(...)` and return; else existing Classic path unchanged.
- [ ] Step 2: Build for `venux1` (and one round product if SDK available).
- [ ] Step 3: Smoke: Classic default looks identical; E1 shows mascot changes when targets crossed (sim properties / mocked punkte).
- [ ] Step 4: Commit `Wire E1 layout behind layoutStyle setting.`

---

### Task 6: Docs + PR

**Files:** `README.md`

- [ ] Step 1: Document `layoutStyle` / mascot setting and that Classic remains default.
- [ ] Step 2: Note AIMICO credit (Deise + MTR) and asset source folder.
- [ ] Step 3: Push `dev/aimico-e1` and open PR → `master` (do not merge without user OK).
- [ ] Step 4: Commit `Document AIMICO E1 opt-in layout.`

---

## Rollback

- Users on Classic (`layoutStyle=0`): zero UI change.
- Revert branch / leave unmerged to keep published Store/`master` face intact.
