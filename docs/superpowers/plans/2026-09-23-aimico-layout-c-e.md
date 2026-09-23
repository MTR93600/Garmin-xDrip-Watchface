# AIMICO Layout C + E Implementation Plan

> **For agentic workers:** Implement task-by-task. Checkboxes track progress.

**Goal:** Repair Card Band (C) and add Split Mirror (E) for AIMICO E1 on Venu X1.

**Architecture:** Shared helpers for header/time/errors/code-drawn arrows; `CGMWatchfaceE1` = Card; `CGMWatchfaceE2` = Split; `layoutStyle` 1/2 gate in View.

**Tech Stack:** Monkey C Connect IQ, existing AIMICO V2 mascot PNGs, geometric arrows via `dc`.

## Global Constraints

- Keep fork UUID / AppName AIMICO E1; default `xDripSpike=4`, `layoutStyle=1`
- No broken V2 arrow PNGs for drawing
- MTP `.prg` primary deliverable

---

### Task 1: Shared arrow + chrome helpers

- [x] Add `source/AimicoDraw.mc` with `drawTrendArrow(dc, rightX, midY, auswahlPfeil)`, `drawHeader`, `drawTime`, `friendlyError`, `shouldShowMascot`
- [x] Build compiles

### Task 2: Repair Card Band (C)

- [x] Rewrite `CGMWatchfaceE1.mc` per spec (black card, large mascot, in-card delta/arrow, 2-line loop strip)
- [x] Build + produce `bin/AIMICO-E1-Watchface.prg`

### Task 3: Split Mirror (E)

- [x] Add `CGMWatchfaceE2.mc`
- [x] Gate `layoutStyle==2` in View; settings/strings entry
- [x] Build `AIMICO-E1-Watchface.prg` (default C) + `AIMICO-E1-Split.prg` (default layoutStyle 2)

### Task 4: Verify

- [x] `monkeyc` venux1 success both PRGs
- [x] Note sideload paths for user
