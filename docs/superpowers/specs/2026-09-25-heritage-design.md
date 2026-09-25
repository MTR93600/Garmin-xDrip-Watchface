# Heritage (CONCEPT C) — central unicorn watchface

Date: 2026-09-25  
Branch: `dev/venu-x1-v2-heritage`  
Repo: `Garmin-xDrip-Watchface`

## Goal

Emotional community face: unicorn (~40% screen) carries glycaemia state; glucose is secondary (small above).

## Packaging

| | |
|---|---|
| Jungle | `monkey-heritage.jungle` |
| Manifest UUID | `c8a41b2e…` |
| `layoutStyle` | `6` |
| PRG | `bin/HeritageAAPS.prg` / `bin/HeritageAAPS-venu3s.prg` |

## Unicorn mapping

| Condition | Asset |
|---|---|
| SGV &lt; 70 | `unicorn_hypo` |
| SGV ≥ 250 | `unicorn_hyper` |
| DoubleUp | `unicorn_double_up` |
| DoubleDown | `unicorn_double_down` |
| else | `unicorn_normal` (sleeping) |

Note: package lacked `unicorn_hypo_shivering.png` — temporary copy of double_down until the shivering cutout is added.

## Layout

Top bar → small glucose + arrow → halo ring + unicorn → 3 moons (IOB/COB/TIR) → smile sparkline → pill → time.

## References

`~/Downloads/CONCEPT_C_HERITAGE/`
