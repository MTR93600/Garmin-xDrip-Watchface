# Venu X1 V2 Implementation Plan

> Implement on `dev/venu-x1-v2-color-aware`

**Goal:** Color-aware AAPS watchface (layoutStyle=3) using HTTP sgv.json.

## Tasks

- [x] `CGMWatchfaceV2.mc` — draw bg/state, TIR ring, glucose, sparkline, tech, time, banner
- [x] Gate `layoutStyle==3` in View; properties + strings
- [x] AAPS fetch `count=36`
- [x] Distinct build `GarminAAPS-V2.prg` (UUID + AppName + default layoutStyle 3)
- [x] Compile venux1
