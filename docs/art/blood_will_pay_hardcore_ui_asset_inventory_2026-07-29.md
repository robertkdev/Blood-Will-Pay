# Blood Will Pay Menu, Result, and Pressure Asset Freeze

Date: 2026-07-29
Status: frozen implementation inventory; implementation must not add an unlisted
player-facing surface without updating this file first
Runtime source audited: `codex/019fabad-cbc-blood-will-pay-rename` at
`1c04a983da8342cc4c938b2d556a81484e5f65f2`
Concept source: `codex/019fabb0-baa-hybrid-ui-art-direction-plan` at
`4a2e2670c5de3715d42068440e06d8240997928f`

## Visual boundary

- Keep the approved 3840x2160 click-anywhere title page gothic and button-free.
- Make the command menu after the title page a full hardcore poster.
- Use the hardcore family for out-of-world menus, decision modals, battle
  outcomes, run loss, Arena Pressure, and short authored announcements.
- Keep portraits, the battlefield, persistent tactical information, the Black
  Ledger's world-authored content, shop unit art, wager math, and stat tables
  gothic or neutral. Their frames and controls still receive the complete
  replacement/state pass below.
- Keep all functional copy live in Godot. No price, percentage, binding,
  outcome, timer, unit name, or menu action may be baked into raster art.
- `scripts/ui/audit/audit_panel.gd` is debug-only and excluded. Combat VFX,
  board cells, actors, health/mana bars, item/trait bodies, and noninteractive
  lore art are outside this menu/result/pressure pass.

## Shipping surfaces covered

| Surface | Runtime evidence | Direction |
| --- | --- | --- |
| Gothic click-anywhere title gateway | `scripts/main.gd:304-416` | Preserve and regression-test |
| Command menu shell | `scenes/Main.tscn`, `scripts/ui/title_menu.gd` | Hardcore poster |
| Overview, How to Play, Units, Combat Terms, Settings | `scripts/ui/title_menu.gd:529-979` | Hardcore editorial shell, neutral body |
| System/pause menu | `scripts/main.gd:207-302` | Hardcore modal |
| Black Ledger | `scripts/ui/black_ledger.gd` | Gothic world artifact with complete controls |
| Unit selection | `scenes/UnitSelect.tscn`, `scripts/ui/unit_select.gd` | Hardcore shell, gothic portraits |
| Shop offers and command/research strip | `scenes/ui/shop/ShopCard.tscn`, `scripts/ui/shop/*.gd` | Gothic portrait/card with print state stamps |
| Wager controls | `scenes/CombatView.tscn`, `scripts/ui/combat/economy_ui.gd` | Gothic utility, hardcore risk punctuation |
| Chapter Contracts and Champion target selection | `combat_controller.gd:1490-1702` | Hardcore warrant/choice modal |
| Level Four Ascension and Legacy Bound | `combat_controller.gd:1704-1811` | Hardcore decision modal, gothic unit identity |
| Stats selector tabs and scoreboard expand control | `scenes/ui/stats/*.tscn`, `scripts/ui/combat/stats/*.gd` | Neutral utility in gothic frame |
| Round result card | `combat_controller.gd:2115-2153,2870-2994` | Hardcore result poster |
| Terminal defeat/run summary | `scenes/ui/LossScreen.tscn`, `scripts/ui/loss_screen.gd` | Hardcore obituary poster |
| Arena Pressure status | `scripts/ui/combat/combat_vfx_bridge.gd:317-382` | Restrained hardcore warning strip |
| Encounter escalation, reinforcement, hazard, contract, and legacy callouts | `combat_controller.gd:2480-2782` | Brief hardcore interruption family |

## Asset manifest

Every state named below is a separate audited file even when it is produced
from one recovered texture and deterministic color/registration transforms.
Dimensions are source canvases. Nine-slice assets must retain the listed safe
margins at runtime.

### A. Full-screen identity and texture sources

| ID | Shipping path | Canvas | Use |
| --- | --- | ---: | --- |
| A01 | `assets/ui/hardcore/menu_backdrop_4k.png` | 3840x2160 | Full-hardcore command-menu background derived from the approved forest/eclipsed world |
| A02 | `assets/ui/hardcore/menu_poster_border_4k.png` | 3840x2160 | Transparent torn/xerox perimeter; no copy |
| A03 | `assets/ui/hardcore/loss_backdrop_4k.png` | 3840x2160 | Terminal run-loss poster field |
| A04 | `assets/ui/hardcore/xerox_grain_tile.png` | 512x512 | Seamless low-opacity print grain, never placed behind small body copy |
| A05 | `assets/ui/hardcore/menu_scrim.png` | 1920x1080 | Transparent readability layer for menu and compact crops |
| A06 | `assets/ui/hardcore/hazard_border.png` | 1920x1080 | Transparent arena-edge impact border; scalable to 7 px and 10 px intensity |

`assets/ui/title/blood_will_pay_title_screen_4k.png` remains the title gateway
asset and is not replaced.

### B. Panel, card, and divider family

| ID | Shipping path | Canvas | Texture margins L/T/R/B | Content margins L/T/R/B |
| --- | --- | ---: | ---: | ---: |
| B01 | `assets/ui/hardcore/panel_menu_rail.png` | 640x1024 | 48/48/48/48 | 36/32/36/32 |
| B02 | `assets/ui/hardcore/panel_menu_content.png` | 1280x768 | 48/48/48/48 | 32/28/32/28 |
| B03 | `assets/ui/hardcore/panel_modal.png` | 1020x680 | 48/48/48/48 | 40/36/40/36 |
| B04 | `assets/ui/hardcore/panel_choice_card.png` | 900x132 | 36/28/36/28 | 24/18/24/18 |
| B05 | `assets/ui/hardcore/panel_info_card.png` | 640x192 | 32/28/32/28 | 18/16/18/16 |
| B06 | `assets/ui/hardcore/panel_popup_menu.png` | 360x256 | 24/22/24/22 | 14/12/14/12 |
| B07 | `assets/ui/hardcore/popup_item_highlight.png` | 320x40 | 18/10/18/10 | 14/7/14/7 |
| B08 | `assets/ui/hardcore/panel_tooltip.png` | 640x384 | 32/28/32/28 | 22/20/22/20 |
| B09 | `assets/ui/hardcore/panel_loss_summary.png` | 900x720 | 48/48/48/48 | 42/38/42/38 |
| B10 | `assets/ui/hardcore/panel_result_data.png` | 760x280 | 40/36/40/36 | 32/28/32/28 |
| B11 | `assets/ui/hardcore/tag.png` | 160x28 | 16/8/16/8 | 10/4/10/4 |
| B12 | `assets/ui/hardcore/number_badge.png` | 40x40 | 10/10/10/10 | 6/6/6/6 |
| B13 | `assets/ui/hardcore/torn_rule.png` | 512x8 | 64/0/64/0 | 0/0/0/0 |
| B14 | `assets/ui/gothic_v3/ledger_panel.png` | 1080x610 | 48/48/48/48 | 34/26/34/26 |
| B15 | `assets/ui/gothic_v3/ledger_row_available.png` | 455x72 | 28/22/28/22 | 16/12/16/12 |
| B16 | `assets/ui/gothic_v3/ledger_row_sealed.png` | 455x72 | 28/22/28/22 | 16/12/16/12 |
| B17 | `assets/ui/gothic_v3/ledger_row_complete.png` | 455x72 | 28/22/28/22 | 16/12/16/12 |
| B18 | `assets/ui/gothic_v3/utility_tooltip.png` | 640x384 | 32/28/32/28 | 22/20/22/20 |
| B19 | `assets/ui/gothic_v3/stats_panel.png` | 720x360 | 40/36/40/36 | 22/18/22/18 |

### C. Button families

The following seven suffixes are mandatory for each family:
`normal`, `hover`, `pressed`, `focus`, `selected`, `hover_selected`, and
`disabled`.

| ID | Filename expansion | Canvas | Margins | Runtime consumers |
| --- | --- | ---: | ---: | --- |
| C01-C07 | `assets/ui/hardcore/button_poster_row_{state}.png` | 520x56 | 40/16/40/16 | Command menu actions and navigation |
| C08-C14 | `assets/ui/hardcore/button_primary_{state}.png` | 320x56 | 28/16/28/16 | Start/New Run/New Game, modal primary actions |
| C15-C21 | `assets/ui/hardcore/button_compact_{state}.png` | 180x40 | 20/12/20/12 | Clear Search, binding/reset, top Menu, Close, Pass |
| C22-C28 | `assets/ui/hardcore/button_choice_{state}.png` | 900x132 | 36/28/36/28 | Contract, Champion target, Ascension choices |
| C29-C35 | `assets/ui/gothic_v3/button_utility_{state}.png` | 180x40 | 20/12/20/12 | Black Ledger, stats tabs, shop commands |
| C36-C42 | `assets/ui/gothic_v3/button_wager_{state}.png` | 224x48 | 24/14/24/14 | Start Battle, All In, wager/continue actions |

Additional semantic choice states:

| ID | Shipping path | Canvas | Use |
| --- | --- | ---: | --- |
| C43 | `assets/ui/hardcore/button_choice_exhausted.png` | 900x132 | Expired/exhausted contract |
| C44 | `assets/ui/hardcore/button_choice_error.png` | 900x132 | Failed purchase/invalid ascension |
| C45 | `assets/ui/hardcore/button_choice_success.png` | 900x132 | Accepted contract/legacy confirmation |
| C46 | `assets/ui/hardcore/button_primary_loading.png` | 320x56 | Preparing Battle / loading |
| C47 | `assets/ui/hardcore/focus_overlay_poster_row.png` | 520x56 | Non-color focus cue composable with hover/selected |
| C48 | `assets/ui/hardcore/focus_overlay_primary.png` | 320x56 | Non-color focus cue |
| C49 | `assets/ui/hardcore/focus_overlay_compact.png` | 180x40 | Non-color focus cue |
| C50 | `assets/ui/hardcore/focus_overlay_choice.png` | 900x132 | Non-color focus cue |

### D. Form, search, dropdown, and scroll assets

| ID | Shipping path or expansion | Canvas | States/use |
| --- | --- | ---: | --- |
| D01-D07 | `assets/ui/hardcore/input_{normal,hover,focus,populated,disabled,error,success}.png` | 640x40 | Search and remapping status |
| D08-D14 | `assets/ui/hardcore/checkbox_{unchecked,unchecked_hover,unchecked_focus,checked,checked_hover,checked_focus,disabled}.png` | 24x24 | Fullscreen and Reduced Motion |
| D15 | `assets/ui/hardcore/icon_clear_normal.png` | 20x20 | Search clear |
| D16 | `assets/ui/hardcore/icon_clear_hover.png` | 20x20 | Search clear hover |
| D17 | `assets/ui/hardcore/icon_clear_pressed.png` | 20x20 | Search clear pressed |
| D18 | `assets/ui/hardcore/icon_dropdown_normal.png` | 20x20 | UI scale |
| D19 | `assets/ui/hardcore/icon_dropdown_hover.png` | 20x20 | UI scale hover/open |
| D20 | `assets/ui/hardcore/icon_dropdown_disabled.png` | 20x20 | UI scale disabled |
| D21 | `assets/ui/hardcore/icon_check.png` | 20x20 | Selected popup item |
| D22 | `assets/ui/hardcore/slider_track.png` | 512x12 | Master volume/wager rail |
| D23 | `assets/ui/hardcore/slider_track_disabled.png` | 512x12 | Locked rail |
| D24 | `assets/ui/hardcore/slider_fill.png` | 512x12 | Active fill |
| D25 | `assets/ui/hardcore/slider_fill_disabled.png` | 512x12 | Locked fill |
| D26-D30 | `assets/ui/hardcore/slider_grabber_{normal,hover,focus,pressed,disabled}.png` | 28x28 | Volume and wager interaction |
| D31 | `assets/ui/hardcore/scroll_track.png` | 16x96 | Menu/selector/ledger scrollbars |
| D32-D35 | `assets/ui/hardcore/scroll_grabber_{normal,hover,pressed,disabled}.png` | 16x56 | Scroll thumb states |
| D36 | `assets/ui/hardcore/icon_scroll_up.png` | 12x12 | Optional scroll step |
| D37 | `assets/ui/hardcore/icon_scroll_down.png` | 12x12 | Optional scroll step |

Keyboard binding capture also uses the input and compact-button families for
idle, listening, saved-success, conflict-error, canceled, and reset states.

### E. Unit select, shop, wager, ledger, and stats-specific assets

| ID | Shipping path or expansion | Canvas | Use |
| --- | --- | ---: | --- |
| E01 | `assets/ui/hardcore/unit_select_backdrop_4k.png` | 3840x2160 | Hybrid selector shell |
| E02 | `assets/ui/hardcore/unit_roster_panel.png` | 760x880 | Roster list frame |
| E03 | `assets/ui/hardcore/unit_preview_panel.png` | 500x880 | Selected-unit information |
| E04 | `assets/ui/gothic_v3/portrait_frame_large.png` | 360x360 | World-native preview art |
| E05-E11 | `assets/ui/hardcore/unit_card_{normal,hover,focus,pressed,selected,hover_selected,disabled}.png` | 150x138 | Starter portrait selector |
| E12 | `assets/ui/hardcore/role_badge.png` | 160x28 | Unit role |
| E13 | `assets/ui/hardcore/goal_field.png` | 500x56 | Unit goal |
| E14 | `assets/ui/hardcore/approach_tag.png` | 160x28 | Approach chips |
| E15-E21 | `assets/ui/gothic_v3/shop_card_{normal,hover,focus,pressed,selected,hover_selected,disabled}.png` | 150x138 | Shop card frame with gothic portrait ownership |
| E22 | `assets/ui/hardcore/stamp_sold.png` | 220x80 | Sold offer |
| E23 | `assets/ui/hardcore/stamp_unaffordable.png` | 300x80 | Unaffordable |
| E24 | `assets/ui/hardcore/stamp_locked.png` | 220x80 | Opening/combat lock |
| E25 | `assets/ui/hardcore/stamp_research_complete.png` | 360x80 | Command cap |
| E26 | `assets/ui/hardcore/stamp_selected.png` | 260x80 | Persistent selection |
| E27 | `assets/ui/hardcore/stamp_success.png` | 260x80 | Purchase/unlock success |
| E28 | `assets/ui/hardcore/stamp_error.png` | 260x80 | Purchase/input error |
| E29 | `assets/ui/gothic_v3/shop_empty_slot.png` | 150x138 | Empty/sold/forced-opening slot base |
| E30 | `assets/ui/gothic_v3/shop_command_strip.png` | 1120x64 | Reroll/Lock/XP/Research controls |
| E31 | `assets/ui/gothic_v3/wager_strip.png` | 640x64 | Odds, wager, reward summary |
| E32-E38 | `assets/ui/gothic_v3/stats_tab_{normal,hover,pressed,focus,selected,hover_selected,disabled}.png` | 120x40 | ALL/3s/metric/expand selectors |
| E39 | `assets/ui/gothic_v3/scoreboard_row_normal.png` | 720x54 | Loss/stats row |
| E40 | `assets/ui/gothic_v3/scoreboard_row_hover.png` | 720x54 | Row hover/inspection |
| E41 | `assets/ui/gothic_v3/scoreboard_value_well.png` | 120x42 | Tabular metric value |
| E42 | `assets/ui/gothic_v3/metric_bar_track.png` | 512x12 | Damage/heal bar |
| E43 | `assets/ui/gothic_v3/metric_bar_fill.png` | 512x12 | Metric fill |
| E44 | `assets/ui/gothic_v3/portrait_frame_small.png` | 42x42 | Scoreboard portrait |

### F. Results, loss, pressure, and announcement assets

| ID | Shipping path | Canvas | Margins | Use |
| --- | --- | ---: | ---: | --- |
| F01 | `assets/ui/hardcore/result_victory.png` | 560x176 | 36/30/36/30 | Standard victory |
| F02 | `assets/ui/hardcore/result_victory_bounty.png` | 560x176 | 36/30/36/30 | Omen/bounty victory |
| F03 | `assets/ui/hardcore/result_defeat.png` | 560x176 | 36/30/36/30 | Nonterminal defeat |
| F04 | `assets/ui/hardcore/result_stalemate.png` | 560x176 | 36/30/36/30 | Tie/watchdog stalemate |
| F05 | `assets/ui/hardcore/result_scrim.png` | 1920x1080 | none | Transparent result interruption scrim |
| F06 | `assets/ui/hardcore/intermission_track.png` | 480x8 | 24/0/24/0 | Two-second result timer |
| F07 | `assets/ui/hardcore/intermission_fill.png` | 480x8 | 24/0/24/0 | Result timer fill |
| F08 | `assets/ui/hardcore/loss_record_badge.png` | 360x80 | 28/18/28/18 | Best-run/high-score emphasis |
| F09 | `assets/ui/hardcore/loss_empty_stats.png` | 720x220 | 32/28/32/28 | Missing/empty tracker state |
| F10 | `assets/ui/hardcore/pressure_status_low.png` | 572x40 | 48/12/48/12 | First weakening stage |
| F11 | `assets/ui/hardcore/pressure_status_high.png` | 572x40 | 48/12/48/12 | Percentage reduction |
| F12 | `assets/ui/hardcore/pressure_status_critical.png` | 572x40 | 48/12/48/12 | Floor/critical pressure |
| F13 | `assets/ui/hardcore/pressure_impact_low.png` | 1180x112 | 90/24/90/24 | Low-intensity escalation |
| F14 | `assets/ui/hardcore/pressure_impact_high.png` | 1180x112 | 90/24/90/24 | Boss/major escalation |
| F15 | `assets/ui/hardcore/pressure_impact_critical.png` | 1180x112 | 90/24/90/24 | Highest-intensity interruption |
| F16 | `assets/ui/hardcore/reinforcement_callout_normal.png` | 232x54 | 24/14/24/14 | Returned unit |
| F17 | `assets/ui/hardcore/reinforcement_callout_critical.png` | 232x54 | 24/14/24/14 | High-intensity return |
| F18 | `assets/ui/hardcore/warning_icon.png` | 64x64 | none | Non-color warning cue |
| F19 | `assets/ui/hardcore/icon_reinforcement.png` | 64x64 | none | Reinforcement cue |
| F20 | `assets/ui/hardcore/icon_ward.png` | 64x64 | none | Starting ward cue |
| F21 | `assets/ui/hardcore/icon_hazard.png` | 64x64 | none | Arena hazard cue |
| F22 | `assets/ui/hardcore/icon_legacy.png` | 64x64 | none | Legacy/ascension cue |

All result and announcement text remains live. `F10-F12` are the persistent
572x40 Arena Pressure status. `F13-F15` are brief 80-112 px authored impacts;
they must not become permanent battlefield decoration.

## State contract

Every interactive control must prove:

1. idle/normal;
2. mouse hover;
3. keyboard/controller focus;
4. pressed;
5. selected/toggled;
6. selected plus hover (`hover_pressed`);
7. disabled;
8. semantic loading, success, or error where the control can enter it.

Non-color differences are mandatory: registration shift or torn marker for
hover; double keyline/corner brackets for focus; inward compression for
pressed; stamped bar/check for selected; crossed/struck texture plus reduced
contrast for disabled. State textures must not alter the Control's measured
rect or content margins.

## Exact runtime fit gates

- Viewports: 1280x720, 1920x1080, 3840x2160, and 2560x1080 ultrawide.
- UI scale: 100%, 125%, and 150%; 150% at 1280x720 is the compact stress gate.
- Unit select: full target 1320x900; compact threshold below 1400 px width or
  at/below 780 px height; cards 150x184 with 150x138 art buttons.
- System menu: 430x430 panel; 320x52 actions; top Menu 132x38.
- Black Ledger: 640-1080 x 400-610 responsive panel; 116x44 Close; 126x50 actions.
- Contracts: 980x680 panel, 880x118 offers, 880x48 Pass, 880x72 Champion rows.
- Ascension: 1020x610 panel, 900x132 choices.
- Round result: 560x176 card and 480x8 intermission bar.
- Run loss: 900 px summary frame, 720x220 scoreboard, 300x56 New Game.
- Arena Pressure: 572x40 persistent strip at top offset 82; authored impact
  uses 64% viewport width and 80-112 px height.

No asset passes if it stretches outside its intended aspect, changes layout
between states, clips live text, produces a green/matte fringe, hides focus,
or becomes unreadable over the brightest/darkest approved world captures.

## Required test/capture matrix

Existing tests to extend:

- `TitleMenuSmoke.tscn`, `TitleMenuStateCapture.tscn`,
  `AccessibilitySettingsSmoke.tscn`, and `SystemMenuHoverStabilitySmoke.tscn`.
- `UnitSelectSmoke.tscn` and `UnitSelectPreviewVisualSmoke.tscn`.
- `BlackLedgerSmoke.tscn`, its fresh/restore/veteran fixtures, and
  `ContractSystemVisualCapture.tscn`.
- `ShopCardHoverSmoke.tscn`, `UIThemeSmoke.tscn`, and wager/economy smokes.
- `PostCombatPlanningBeatSmoke.tscn` and `LossScreenSmoke.tscn`.
- `EncounterEscalationVisualCapture.tscn`,
  `CombatVfxReadabilitySmoke.tscn`, and contract/upgrade runtime probes.
- `VisionCaptureSmoke.tscn` for the complete real-player surface sweep.

New state capture/probe coverage must include:

- all seven base control states plus loading/success/error;
- menu Overview, How to Play, Units, Combat Terms, Settings, populated search,
  empty search, dropdown open, remapping listening/success/conflict;
- system menu and Black Ledger at minimum/maximum responsive sizes;
- unit cards idle/hover/focus/selected/selected-hover/disabled and Start
  disabled/ready/loading;
- shop affordable/unaffordable/locked/sold/empty, Lock selected-hover,
  Command Research available/complete, wager drag/focus/locked;
- contract offer/exhausted/error, Champion target, Ascension/error/accepted;
- victory normal/bounty, nonterminal defeat, stalemate, and the two-second
  intermission transition;
- terminal loss with short/long stats, minimum/maximum rows, scoreboard-row
  hover, automatic New Game focus, mouse/keyboard/controller activation;
- Arena Pressure low/high/critical, escalation intensity 1/2/3, zero/one/many
  reinforcements, 7/10 px hazard border, rapid event replacement, z-order
  against results/modals, and reduced-motion substitutes.

Final acceptance requires real `Main.tscn` mouse, keyboard, and controller
runs plus fresh screenshots from the authoritative game framebuffer. Static
asset sheets and test harness screenshots cannot pass the project by
themselves.
