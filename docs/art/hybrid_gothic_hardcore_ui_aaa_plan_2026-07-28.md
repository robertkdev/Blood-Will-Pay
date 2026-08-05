# Blood Will Pay Hybrid Gothic / Hardcore UI Plan

Date: 2026-07-28
Status: art-direction and production plan; no UI implementation in this task
Former project name: Gamble Battle

## Decision

Blood Will Pay should use two deliberately different visual languages instead
of blending every screen into one texture treatment:

1. **Gothic war-horror owns the world.** The battlefield, units, persistent
   tactical HUD, world-authored ledgers, and information that must remain on
   screen during combat should feel native to the dark place where the units
   are fighting.
2. **Hardcore print owns the game's voice.** The title and command shell,
   interstitials, announcements, battle results, unlocks, warnings, purchase
   feedback, and other non-world interruptions should feel cut, pasted,
   stamped, photocopied, and authored directly at the player.
3. **Neutral utility typography protects dense information.** Stats,
   tooltips, odds, prices, and long descriptions may sit inside either visual
   language, but their text and number system must stay calm, aligned, and
   immediately readable.

The contrast is the feature. A quiet, oppressive gothic battlefield gives a
hardcore interruption somewhere to hit. If everything is distressed paper,
nothing feels like an interruption; if everything is carved gothic framing,
the game loses urgency and contemporary personality.

## Current Direction Reconciliation

The approved `BLOOD WILL PAY` forest title artwork should remain the visual
source of truth for the game's world palette, material realism, black levels,
eclipse motif, hostile negative space, and horror tone. The active rename/title
integration task should finish without this plan interfering with its
worktree.

For the eventual full-hardcore main menu, preserve that artwork as source
material rather than discarding it. Crop, halftone, overprint, tear, mask, or
partially bury the forest image inside a poster composition. That lets the
main menu go fully hardcore while the same forest still establishes the
gothic world the player enters.

The previous all-hardcore UI preview proves that torn paper, photocopy
contrast, abrupt scale, safety pins, hand marks, and one-color ink can make the
game much more distinctive. It also demonstrates the risk of applying that
density to every permanent tactical surface. Its energy should be harvested
for the shell and interruptions, not copied wholesale over the board.

## Visual Jurisdiction Rules

Every UI surface should be classified before it is redesigned.

| Question | Gothic war-horror | Hardcore print | Neutral utility |
| --- | --- | --- | --- |
| Does it represent the physical world or a world-authored object? | Primary | No | Supporting |
| Does it interrupt play to announce, judge, warn, unlock, or sell? | Supporting | Primary | Supporting |
| Must it remain readable continuously while units fight? | Primary | Accent only | Primary |
| Is it a full-screen shell or meta-game destination? | Background/source imagery | Primary | Supporting |
| Is it data-dense or frequently scanned? | Frame only | Sparse labels only | Primary |

### Intensity tiers

- **Tier 0 — World:** no torn-paper treatment. Environment, units, arena,
  world VFX, and world-native artifacts.
- **Tier 1 — Utility:** gothic or near-neutral frame, clean type, restrained
  texture. Always-on HUD, odds, stage progress, stats, health, mana, targeting.
- **Tier 2 — Card:** controlled hardcore component within play. Shop offers,
  tooltips, contracts, item acquisition, trait activation, warning cards.
- **Tier 3 — Poster:** maximal authored interruption. Title/menu shell,
  chapter cards, victory/defeat, boss arrival, loss screen, major unlock.

Tier 3 should disappear after it lands. Tier 1 should become almost invisible
when the player is focused on combat.

## Surface Selection Matrix

| Surface | Direction | Intensity | Specific treatment |
| --- | --- | --- | --- |
| Title screen | Hardcore poster using gothic forest source | Tier 3 | Full-bleed poster composition, huge `BLOOD WILL PAY` lockup, dirty-bone paper/ink contrast, forest as halftone or torn photographic field |
| Command menu / main navigation | Hardcore print system | Tier 2-3 | Liner-note or flyer hierarchy, strong section blocks, restrained collage; avoid seven identical gothic buttons |
| How to Play / combat glossary | Hardcore editorial shell + neutral body | Tier 2 | Zine/editorial navigation, large chapter markers, clean body copy and diagrams |
| Settings / system menu | Neutral utility inside controlled print shell | Tier 1-2 | Clear rows, focus states, sliders, remapping; texture kept outside interaction targets |
| Unit selection | Hybrid | Tier 2 | “Lineup” energy in headings and selection marks; gothic portraits remain the heroes; clean role/ability copy |
| Battlefield and board cells | Gothic world | Tier 0 | Environment materials, restrained cell readability, depth, fog, damage, and motivated light |
| Unit actors and portraits | Gothic world | Tier 0 | Villain-first art, strong silhouettes, grounded rim separation, no flyer costume language |
| Health/mana/status bars | Gothic utility | Tier 1 | Low-profile world-compatible bars with exact silhouettes and color-independent status markers |
| Stage progress top bar | Gothic utility | Tier 1 | Campaign march or omen track; reduce repeated gold ornament and keep scan speed high |
| Planning timer / board cap / odds | Neutral utility in gothic frame | Tier 1 | Tabular numerals, clear grouping, one restrained accent per state |
| Traits panel | Gothic ledger + neutral utility | Tier 1 | World-authored obligation/brand list; clearer active versus next-threshold hierarchy |
| Black Ledger | Gothic world artifact | Tier 1-2 | Keep as an in-world ledger; do not convert it into a concert flyer |
| Team metrics / scoreboard | Neutral utility | Tier 1 | Strong columns, stable number alignment, restrained gothic containment, near-zero paper noise |
| Unit detail panel | Gothic dossier | Tier 1 | Portrait-led threat file with clean headings and stat grids |
| Item and trait tooltips | Hybrid | Tier 2 | Small torn label/kicker and stamp state, but a calm opaque body for readable copy |
| Shop area | Hybrid hardcore market | Tier 2 | Gothic unit art inside cut-paper offer cards; price, rarity, and buy state use print labels and stamps |
| Reroll / XP / Command purchase feedback | Hardcore interruption | Tier 2 | Fast stamped receipt, overprint, or ripped ticket-like response; do not cover the board for long |
| Wager slider / all-in control | Gothic utility with hardcore risk punctuation | Tier 1-2 | Precise control and odds; `ALL IN` becomes a high-impact print action only when armed |
| Encounter / boss banner | Hardcore interruption | Tier 3 | One violent headline, brief photographic or sigil fragment, fast entry, short hold, clean exit |
| Arena pressure banner | Hardcore interruption | Tier 2 | Compressed warning strip with large verb and readable timer/state |
| Victory / defeat / stalemate card | Hardcore poster | Tier 3 | Outcome owns the screen momentarily; result, consequence, payout, and next action have distinct hierarchy |
| Chapter transition | Hardcore poster over gothic source image | Tier 3 | New chapter as a campaign flyer/propaganda sheet derived from that chapter's world location |
| Contracts market | Hybrid warrant/handbill | Tier 2 | Each contract is a printed proposition, but terms and consequences remain clean and comparable |
| Unit ascension / legacy bound | Hardcore interruption + gothic portrait | Tier 3 | Portrait or silhouette remains world-native; the game stamps the transformation over it |
| Level-up / combine / unlock callouts | Hardcore micro-interruption | Tier 2 | Quick stamp, tear, or registration snap; no long modal unless a decision is required |
| Loss screen | Hardcore poster | Tier 3 | Strongest run-ending composition after the title; stats become a restrained obituary/casualty block |
| Sell zone / drag feedback | Gothic utility | Tier 1 | Spatially precise, low-noise, color-independent valid/invalid feedback |
| Combat VFX, beams, hit flashes | Gothic world | Tier 0 | Physical and supernatural consequences tied to the world; never paper, text, or poster effects |

## AAA Quality Is a System, Not More Decoration

### 1. Shared visual DNA

Both languages should share a small palette so the contrast feels intentional:

- Matte black and charcoal for mass.
- Dirty bone for readable information.
- Dried oxblood for consequence and high-risk action.
- Muted iron, ash, and wet gray for gothic structure.
- One chapter- or threat-specific accent, such as bruised violet, sickly teal,
  or corpse-light green.

Hardcore surfaces may push dirty bone and xerox black to much higher contrast.
Gothic surfaces should stay material, dimensional, and low-saturation. Avoid
bringing back decorative gold as the universal importance color.

### 2. Three typographic jobs

- **Identity:** custom `BLOOD WILL PAY` wordmark and rare chapter/outcome marks.
- **Impact:** condensed, forceful display face for short headings, warnings,
  prices, and calls to action.
- **Utility:** highly legible sans-serif with tabular numerals for stats,
  descriptions, odds, timers, settings, and tooltips.

Expressive type is not a body font. At 1080p, important functional text should
target at least 26 px where layout permits, with tested 1280x720 fallbacks.

### 3. Hierarchy before texture

Each screen needs one dominant read, one supporting decision region, and one
quiet information field. Texture can reinforce those layers, but it cannot
create hierarchy by itself. The current UI often gives every panel similar
ornament weight; the redesign should make low-priority framing recede and let
units, decisions, and consequences dominate.

### 4. State-complete components

Every redesigned control must define:

- Idle, hover, keyboard/controller focus, pressed, disabled, selected, error,
  success, and loading states.
- Mouse, keyboard, and controller affordances.
- Reduced-motion behavior.
- 1280x720, 1920x1080, 4K, and ultrawide behavior.
- Long-copy and text-scaling behavior.

AAA polish fails if the default screenshot looks good but focus, disabled,
compact, and transition states feel like a different product.

### 5. Motion language

Use motion as tension and release:

- Gothic world UI: settle, reveal through light, material shift, restrained
  depth, and deliberate camera-linked movement.
- Hardcore UI: snap, hard cut, paper slam, misregistration lock-in, stamp,
  short lateral tear, and abrupt scale change.
- Utility UI: fast fades and positional continuity.

No constant shaking, flicker, jitter, or fake film damage over functional text.
Major interruptions should usually complete their entrance in 160-260 ms,
hold long enough to read, and clear the battlefield. Reduced-motion mode should
replace snaps and scale hits with short opacity transitions.

### 6. Audio punctuation

The two visual languages need matching UI sound:

- Gothic: iron tension, wet stone, low wood strain, distant impact, restrained
  supernatural resonance.
- Hardcore: dry paper hit, staple snap, ink stamp, amplifier-like transient
  without literal concert ambience.
- Utility: short, clean confirmation tones with no fatigue.

The poster style should feel physical without pretending that the player is at
a show.

### 7. Attention and occlusion budgets

- Permanent HUD may frame the board but should not reduce actor contrast or
  cover tactical cells.
- Tier 2 interruptions should occupy no more than roughly one quarter of the
  screen and usually clear within two seconds.
- Tier 3 moments may own the screen only when gameplay is paused or the outcome
  is already decided.
- Never place animated texture behind prices, odds, timers, or long copy.
- Use non-color cues for selected, dangerous, unaffordable, and disabled states.

## Production Plan

### Phase 0 — Freeze the new foundation

1. Let the active title/rename task finish and reach a remote-verified commit.
2. Capture the implemented title, command menu, unit select, planning, shop,
   combat, result, loss, contracts, ascension, tooltips, settings, and compact
   states at 1920x1080 and 1280x720.
3. Create a UI inventory sheet. Score each surface for persistence, world
   ownership, information density, emotional importance, and allowed
   interruption intensity.
4. Lock the jurisdiction matrix above before producing assets.

### Phase 1 — Build the visual-system kit

Create a small reusable kit before redesigning screens:

- Gothic frame family: world panel, utility panel, portrait frame, slot,
  tooltip body, and quiet divider.
- Hardcore family: poster field, torn card, warning strip, stamp, price tag,
  headline block, chapter card, and result card.
- Shared type scale, spacing scale, palette tokens, focus language, icon grid,
  and motion durations.
- Exact-size nine-slice and texture tests at every real component size.

The kit should be previewed on black, the gothic forest, the board, and the
brightest unit art. Do not promote raw generated images directly into runtime
assets; crop, mask, resize, rebuild alpha, and audit borders deterministically.

### Phase 2 — Prove the contrast with one vertical slice

Redesign only these representative surfaces first:

1. Full-hardcore title/main menu.
2. Gothic planning/combat frame with reduced ornament and stronger actor focus.
3. Hybrid shop card plus purchase feedback.
4. Hardcore encounter banner.
5. Hardcore victory/defeat result card.
6. Neutral stats panel inside a quiet gothic frame.

This slice proves the full spectrum: shell, world, hybrid commerce, transient
interrupt, outcome, and dense utility. Do not expand until all six look like
one product and the board remains the visual priority during combat.

### Phase 3 — Expand authored interruptions

Apply the proven hardcore system to:

- Boss arrival and pressure warnings.
- Chapter transitions.
- Level-up, combine, item, and trait unlocks.
- Contract and ascension decisions.
- Loss screen and run summary.
- Reroll, XP, Command, wager, and affordability feedback.

Build reusable data-driven announcement components instead of one-off panels.

### Phase 4 — Rebuild the meta-game shell

Apply the poster/editorial system to:

- Command menu.
- How to Play and combat glossary.
- Settings and remapping.
- Unit selection headings, filters, and selection state.

Keep portraits, world lore, and long reading surfaces controlled. The shell can
be loud; the information cannot be exhausting.

### Phase 5 — Polish the persistent gothic game

- Reduce equal-weight gold framing and empty decorative mass.
- Improve board-versus-HUD depth separation.
- Strengthen selected, targetable, threatened, unaffordable, and disabled
  states without relying on color alone.
- Give unit portraits and actors cleaner silhouette separation.
- Align stats, odds, prices, and timers to stable grids.
- Harmonize icons, status bars, tooltips, and focus states.
- Preserve world immersion by keeping print effects out of combat VFX.

### Phase 6 — Runtime acceptance

Use real player-facing runs and fresh visual packets. Required review states:

- Title idle and input.
- Command menu navigation.
- Unit-select idle, hover, selected, scrolled, and compact.
- First shop, later shop, hover tooltip, purchase, reroll, XP, and unaffordable.
- Planning, betting, all-in armed, combat, and result.
- Boss/pressure warning, contract choice, ascension, chapter transition.
- Stats collapsed/expanded, item and trait tooltips.
- System menu, settings focus/remapping, loss screen.
- 1280x720, 1920x1080, 4K, ultrawide, text scaling, and reduced motion.

Acceptance requires:

- The battlefield remains visually dominant while combat is active.
- A viewer can tell whether a surface belongs to the world or is the game
  speaking directly to them.
- Hardcore interruptions feel exciting because they are scarce.
- No critical text is carried by texture, color, or expressive lettering alone.
- Focus, hover, selected, disabled, success, and error states are unmistakable.
- No clipping, overlap, unreadable black levels, excessive flashes, or
  persistent motion.
- Final runtime captures, not source mockups, pass independent visual review.

## Recommended First Approval Board

Before implementation, create one comparison board with six equal-size
runtime-target mockups:

1. Poster title/menu.
2. Gothic combat frame.
3. Hybrid shop card and purchase stamp.
4. Encounter warning strip.
5. Victory/defeat poster card.
6. Neutral stats/tooltip treatment.

Each panel should include a small strip showing idle, focus, selected, and
disabled states. Approval of this board becomes the visual contract for the
component kit and prevents the redesign from drifting into unrelated styles
screen by screen.

## Evidence Consulted

- `docs/art/metal_hardcore_visual_research_2026-07-28.md` on
  `codex/019faa9c-9de-metal-hardcore-visual-research` at `b487b53`.
- Approved 4K title source on `codex/019fab5a-232-title-screen-4k` at
  `6dbbb53`.
- User-referenced all-hardcore UI preview:
  `C:\Users\Flipm\.codex\generated_images\019faa9c-9deb-7553-be8c-bfaef26b9a03\call_dlrBHyxnZmuWP4lMuyDGlufK.png`.
- Approved title preview:
  `C:\Users\Flipm\.codex\generated_images\019fab5a-2326-70b0-b92b-3eb16d75bd04\call_q7TEw9WN9ZkscWTgM5ZvMD4O.png`.
- Recent player-facing 1280x720 unit-select, command-menu, and planning
  captures from the integrated playtest worktree.
- Latest remote source inventory at `origin/main` commit `057f60b`.

Fresh duplicate Godot capture was intentionally deferred because active editor
and runtime lanes belonged to other current playtest tasks. The implementation
phase must begin with the Phase 0 capture matrix after those lanes are free.
