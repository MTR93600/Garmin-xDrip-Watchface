# Venu X1 V2 color-aware watchface (HTTP AAPS)

Date: 2026-09-24  
Status: approved (plan A)  
Repo: `Garmin-xDrip-Watchface`  
Branch: `dev/venu-x1-v2-color-aware`

## Goal

New Connect IQ watchface matching the `Garmin_AAPS_V2_DEV_FINAL2` triptyque (NORMAL / HYPO / HIGH·HYPER), using **existing AAPS HTTP data** (`127.0.0.1:28891/sgv.json` + status line). No AAPS phone-push sender in this pass.

## Data

| Field | Source |
|---|---|
| SGV, trend, age | AAPS `/sgv.json` (count ≥ 18–36) |
| Graph 36 pts | Same JSON array (pad/trim) |
| IOB / basal / COB | `aaps` status string (existing parse) |
| Steps / HR | Device sensors (existing) |
| `state` | Computed on watch: HYPO &lt;70, HIGH &gt;180, HYPER ≥250, else NORMAL |
| TIR % | Share of graph points in [70, 180] |

Defaults: `xDripSpike=4` (AAPS), distinct app UUID/name so Store + AIMICO E1 are not overwritten.

## UI (CIQ approximation of mockups)

1. Header: date · steps · HR  
2. Large BG + units + trend arrow; optional unicorn (reuse AIMICO pixel or small mark)  
3. TIR arc (~270°) — green NORMAL, red HYPO, orange HIGH/HYPER  
4. 3h sparkline with fill under line  
5. Loop strip: IOB · basal · COB · age  
6. Time  
7. Bottom banner: `LOOP · AAPS` / `HYPO · AAPS` / `HIGH · AAPS` with solid color in alert  
8. Background tint: black NORMAL, dark red HYPO, dark orange HYPER/HIGH  

## Out of scope

- `GarminV2DataSender` / Connect IQ phone messaging  
- Pixel-perfect parity with PNG mockups  
- AIMI modes inside this face  

## Deliverable

`bin/GarminAAPS-V2.prg` for `venux1` + sideload notes.

## References

`~/Downloads/Garmin_AAPS_V2_DEV_FINAL2/` (assets + prompt + skeleton).
