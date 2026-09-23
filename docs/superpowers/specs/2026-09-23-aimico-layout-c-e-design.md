# AIMICO layouts C (Card fix) + E (Split Mirror)

Date: 2026-09-23  
Repo: `Garmin-xDrip-Watchface` (`dev/aimico-e1`)  
Status: approved by user (C first, then try E)

## Goal

1. **C — Card Band repaired:** keep official AIMICO V2 mascot; fix broken trend arrows, stacking, and spacing so the current face is readable.
2. **E — Split Mirror:** alternate layout (same data + same mascot set) for the square Venu X1: portrait left, metrics stack right.

Out of scope for this pass: full pixel-art redesign (A), Soft AMOLED (B), Arcade HUD (D). Those remain future options.

## Shared rules (C and E)

- **Data source default:** `xDripSpike = 4` (AAPS `127.0.0.1:28891`).
- **App identity:** keep fork UUID / name `AIMICO E1 Watchface` (do not reuse Store UUID).
- **Mascot:** AIMICO V2 `CoverPlate` / `CoverPlateLow` / `CoverPlateHigh` → `mascot_*.png`. Kind from SGV vs target range (`AimicoState.mascotKind`). If SGV null → show in-range mascot (current behavior).
- **Trend arrows:** do **not** use the broken V2 arrow PNG exports (they rasterize as rainbow blobs). Draw arrows with `dc` geometry (white strokes) from `auswahlPfeil`, or re-use clean Classic arrow bitmaps (`id_1`…`id_7`) if geometry is too heavy. Prefer **vector draw in code** for flat/45/up/down/double.
- **No JSON CWF:** `CustomWatchface.json` is unused on Connect IQ.
- **Settings:** `layoutStyle`: `0` Classic, `1` Card (C), `2` Split Mirror (E). Default `1`. For MTP trials without Connect IQ settings, ship a second PRG with `layoutStyle` default `2` if needed (`AIMICO-E1-Split.prg`).

## Layout C — Card Band (repaired)

### Composition

```
[ date (L)                    steps · HR (R) ]
[ ┌──────────────────────────────────────┐ ]
[ │  mascot (large)     BG (huge, R)     │ ]
[ │                     age  delta  →    │ ]
[ └──────────────────────────────────────┘ ]
[ IOB · basal                              ]
[ COB                                      ]
[              HH:MM                       ]
```

### Rules

- Card fill: **black** (or very dark), not DK_GRAY/blue-looking panel. Thin light border optional (1 px `COLOR_LT_GRAY`) if contrast needs it.
- Mascot: left inside card; max height ≈ `cardH - 16`; width scales proportionally; target visual weight ~40–45% of card width.
- BG + age + delta + **code-drawn arrow** stay **inside** the card, right column. Never draw the arrow at `stripY`.
- Loop strip: two lines max under the card (`FONT_TINY`):
  - Line 1: IOB · basal (omit empty parts)
  - Line 2: COB alone
- Time: bottom center, existing large number font.
- Errors: short single-line status above time (existing friendly strings).

### Bug fixes explicitly required

| Bug on device | Fix |
|---|---|
| Rainbow “tail” over IOB row | Replace AIMICO arrow PNGs with code arrows (or Classic arrows); keep draw Y inside card |
| IOB/COB/arrow overlap | Separate strip lines; arrow not in strip |
| Tiny muddy unicorn | Larger draw + black card; keep V2 assets |

## Layout E — Split Mirror

### Composition

```
[ date (L)                    steps · HR (R) ]
[ ┌──────────┬─────────────────────────────┐ ]
[ │          │  BG (huge)                  │ ]
[ │  mascot  │  age · delta · →            │ ]
[ │  full    │  IOB                        │ ]
[ │  height  │  basal                      │ ]
[ │          │  COB                        │ ]
[ └──────────┴─────────────────────────────┘ ]
[              HH:MM                       ]
```

### Rules

- Vertical split ~ **42% left / 58% right** (tweak to fit Venu X1 so 3-digit BG never clips).
- Left: mascot only, vertically centered, as large as the left pane allows (padding 6–8 px). No card chrome required; optional subtle divider line between panes.
- Right stack (top → bottom), left-aligned in the right pane:
  1. BG (`FONT_NUMBER_HOT` / medium if width tight)
  2. age · delta · arrow (one row)
  3. IOB
  4. basal
  5. COB
- Time remains full-width bottom center (outside the split), same as C.
- Same mascot/arrow/error behavior as C.
- Header (date / steps·HR) unchanged.

### Why E

Square AMOLED: portrait mascot gets a real column; metrics don’t fight the sprite inside one blue band.

## Module / file plan

| File | Change |
|---|---|
| `source/CGMWatchfaceE1.mc` | Repair Card draw (C); extract shared helpers (arrow draw, header, time, errors) |
| `source/CGMWatchfaceE2.mc` (new) | Split Mirror draw (E) |
| `source/CGMWatchfaceView.mc` | Gate: `layoutStyle==1` → E1, `==2` → E2 |
| `source/AimicoState.mc` | Keep mascot helpers; arrow helper may return enum only (drawing in E1/E2) |
| `resources/settings/properties.xml` | `layoutStyle` default `1`; document value `2` |
| `resources/settings/settings.xml` + `strings.xml` | Add list entry “AIMICO Split Mirror (E)” |
| `resources/drawables/*` | Keep V2 mascots; stop relying on broken `aimico_arrow_*.png` (may leave files unused) |

No change to AAPS HTTP path in `CGMWatchfaceBG.mc` for this work.

## Verification

1. Sideload `AIMICO-E1-Watchface.prg` (default C): no rainbow blob; arrow under BG inside card; IOB/COB readable; mascot larger on black card.
2. Force low / high BG (or mock): mascot swaps low / inrange / high.
3. Sideload E default (or set `layoutStyle=2`): split readable; BG never overlaps mascot; time still clear.
4. Classic (`layoutStyle=0`) still draws if selected (no regression required beyond compile).

## Non-goals

- Inventing new pixel unicorn art (A/B/D).
- Connect IQ `.iq` install UX on Samsung (documented separately; MTP `.prg` remains primary).
- Replacing Store watchface in-place.
