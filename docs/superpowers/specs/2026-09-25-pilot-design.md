# Pilot (CONCEPT B) — predictive cockpit watchface

Date: 2026-09-25  
Branch: `dev/venu-x1-v2-pilot`  
Repo: `Garmin-xDrip-Watchface`

## Goal

Cockpit-style face: target band 70–180, past sparkline (solid) + mocked +60m future (dotted), double TIR/delta ring, tech strip, always-on status pill.

## Packaging

| | |
|---|---|
| Jungle | `monkey-pilot.jungle` |
| Manifest UUID | `7fec5e9e…` |
| `layoutStyle` | `5` |
| PRG | `bin/PilotAAPS.prg` / `bin/PilotAAPS-venu3s.prg` |

## Data (HTTP plan A)

- Past: existing `sgv.json` graph (36 pts)
- Future: **mocked** from last SGV + delta until AAPS sends `graphFuture[12]`
- States: &lt;70 HYPO, ≥250 HYPER, else NORMAL

## References

`~/Downloads/CONCEPT_B_PILOT/`
