# UI trial assets: what is live, what the evidence says, and the decision each needs

Date: 2026-09-26. Every generated UI surface in the gameplay screen is a trial
rather than an accepted asset. This is the packet for that decision: what is
wired, what it measures, and the one-line change that implements either answer.
Acceptance is the operator's call; nothing here makes it.

## 1. Gameplay panel surface (v5) - the largest trial

- **Asset**: `assets/ui/gothic/generated/gameplay_panel_luna_v5.png`, 320x320,
  40px nine-slice margins.
- **Wired**: yes - `GAMEPLAY_PANEL_SURFACE_ENABLED = true`, used by the six
  allowlisted plates (stats rail, traits rail, item rail, shop plate, command
  plate, utilities plate), with the three rail plates additionally carrying a
  dimmed rim.
- **Evidence, measured**: the question a trial has to answer is whether it beats
  its own fallback, so the surface was switched off for one run.

| Measure | Reference | With the trial | Flat fallback |
| --- | --- | --- | --- |
| left rail strongest edge step | 0.1924 | **0.1216** | 0.2576 |
| right rail interior, median luminance | 0.0154 | **0.0204** | 0.0000 |
| right rail mean chroma | 0.032 | **0.022** | 0.014 |
| frame mean luminance | 0.0753 | **0.0739** | 0.0685 |

  It wins every one of those, and on the left rail's edge it beats the
  reference's own reading. A v6 candidate was generated through the asset lane
  and **rejected** on measurement (rail interiors 0.0204 to 0.0389, twice as
  bright as the live surface and two and a half times the reference's), and is
  kept unwired as `GAMEPLAY_PANEL_SURFACE_V6_REJECTED`.
- **Decision**: accept the v5 surface as the shipping material, or revert to the
  flat quiet-iron fallback.
- **Implementation**: acceptance is deleting the "trial" framing in the constant
  comment; reverting is `GAMEPLAY_PANEL_SURFACE_ENABLED = false`.

## 2. Shop card frame - trial against its own rollback

- **Asset**: `assets/ui/gothic/generated/shop_card_frame_luna_v1.png`, 150x138.
- **Wired**: yes, as `SHOP_CARD_FRAME`, with `SHOP_CARD_FRAME_ROLLBACK` naming the
  original `assets/ui/gothic/shop_card_frame_v2.png` in one line.
- **Evidence**: the two frames measure within noise of each other on the shop
  band - trial: mean chroma 0.0365, saturated share 0.0585; rollback: 0.038 and
  0.055. Nothing on the screen distinguishes them numerically, so this decision
  is purely visual, and the comparison is on disk as local review evidence (not
  a committed asset, matching how the rest of the review output is kept):
  `outputs/visual_iter/composition_v10/shop_frame_trial_vs_rollback.png`
  (trial left, rollback right, same cards, same frame size).
- **Decision**: keep the trial frame, or roll back.
- **Implementation**: `SHOP_CARD_FRAME` is a single constant; either path is one
  line.

## 3. Primary-action emblem - live, and its note is out of date

- **Asset**: `assets/ui/gothic/generated/crossed_swords_emblem_luna_v1.png`.
- **Wired**: yes. `combat_view` attaches it as the commit button's icon in the
  composed dock, centred above the label at 56 physical pixels. The constant's
  comment still says "nothing is attached to a Button yet", which stopped being
  true when the action bay was composed; this brief is the correction.
- **Evidence**: it is decoration on the commit plate, and the plate's own
  readings (0.4597 saturated share, the largest saturated mass on the screen)
  are unchanged by it. Whether the crest belongs on the action is a judgement
  about the action's look, not a measurement.
- **Decision**: accept the crest on the commit action, or remove it.
- **Implementation**: removing is skipping the icon assignment in
  `combat_view._apply_dock_action_plaque`; the asset stays on disk either way.

## Already decided, kept for provenance

- `gameplay_panel_luna_v2.png` - rejected earlier, `GAMEPLAY_PANEL_SURFACE_REJECTED_V2`.
- `gameplay_panel_luna_v6.png` - generated and rejected in this work,
  `GAMEPLAY_PANEL_SURFACE_V6_REJECTED`.
- `gameplay_commit_luna_v2.png` - the crimson commit plaque, declined;
  `GAMEPLAY_COMMIT_SURFACE_ENABLED = false` keeps the original with one line.

## What this packet does not do

It does not accept anything, and it does not recommend for reasons beyond the
measurements: for the panel surface the numbers are decisive, for the frame and
the emblem they are neutral and the call is a look.
