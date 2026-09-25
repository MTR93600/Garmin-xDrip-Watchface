# Calm Loop (CONCEPT A) — Venu X1 / round adaptive

Date: 2026-09-25  
Status: implemented  
Branch: `dev/venu-x1-v2-calm`  
Repo: `Garmin-xDrip-Watchface`

## Goal

Minimal “Calm Technology” watchface over existing AAPS HTTP (`28891/sgv.json`). Hide IOB/tech chrome in NORMAL; alert with edge vignette + small pill only in HYPO/HYPER.

## Packaging (same pattern as V2)

| Artifact | Value |
|---|---|
| Jungle | `monkey-calm.jungle` |
| Manifest | `manifest-calm.xml` (UUID `bd94e838…`) |
| Default `layoutStyle` | `4` |
| PRG | `bin/CalmLoop.prg` (`venux1`) |

## Layout

- Top: date · steps·HR · tiny unicorn outline (center)
- Center: thin TIR ring + large SGV + mg/dL + trend under value
- Sparkline ~22px, faint
- Time small gray bottom
- Pill `HYPO/HIGH · AAPS` only if alert
- No IOB/basal/COB line

## States

- `sgv < low` → HYPO  
- `sgv ≥ hyper (250)` → HYPER  
- else → NORMAL (including 180–249)

## References

`~/Downloads/CONCEPT_A_CALM_LOOP/` (SPEC + assets).
