# Main Menu Redesign Goal: The World Is the Breakdown

Date: 2026-07-28
Status: title-screen direction approved; 4K production master created but not wired into the game

## Core Intent

Blood Will Pay should not depict metal culture literally. Metal and hardcore are
the emotional and formal references: aggression, compression, rupture,
relentless rhythm, ugliness with conviction, sudden silence before impact, and
the feeling that violence is about to become uncontrollable.

The world itself is the subject. It is a brutal war-horror reality that metal
artists might write songs about and where a horror film could take place. The
mosh pit is not represented as a crowd at a show; the comparison is fulfilled
by making the battlefield itself feel like the war zone people compare a pit
to.

## Rejected Literal Translation

The generated `Basement Threshold` concept is rejected. It translated the
inspiration into a staircase, venue, crowd, performer-like villain, pasted
flyer, and admission ticket. Those elements explain "metal concert" rather than
making the player feel what metal feels like. The image is retained only in Git
history as evidence of the rejected interpretation and is not an active visual
target.

The same prohibition applies across the game:

- No stages, audiences, performers, microphones, amplifiers, speakers, set
  lists, tickets, backstage passes, venue barricades, or concert lighting as
  worldbuilding.
- No UI metaphors that turn units into bands, battles into shows, chapters into
  tours, or the shop into a merch table.
- No industrial-science-fiction substitute of road cases, hazard stripes,
  factory machinery, or cyberpunk panels.
- No generic "metal" shortcut made from skull piles, pentagrams, unreadable
  logos, and black-red texture without a coherent world.

## Redesign Goal

The title screen should be one terrible moment inside Blood Will Pay's actual
world: a place already damaged by war, cruelty, monstrous power, and
consequence. It should feel like the held breath before a breakdown lands.

The player is not entering a concert. The player is crossing into a conflict
that has the pressure and inevitability of one.

Use the approved title-screen copy:

- `BLOOD WILL PAY`
- `THEIR LIVES. YOUR ODDS.`

The title screen is a click-anywhere continuation surface. It has no visible
`ENTER` button, instructional prompt, or other call to action.

## Emotional Construction

Translate music into visual form rather than objects:

| Metal feeling | Visual translation |
| --- | --- |
| Low-tuned weight | Massive dark shapes, low horizon, compressed vertical space, heavy foreground obstruction |
| Breakdown anticipation | A held composition with one unresolved point of impact and deliberate empty silence around it |
| Rhythmic chug | Repeated hard silhouettes, scars, stakes, bodies, or architecture with controlled spacing |
| Sudden impact | One violent diagonal, rupture, flare, or displaced mass that breaks the repeated structure |
| Dissonance | Slightly wrong scale, asymmetry, damaged anatomy, impossible shadow, or architecture under stress |
| Vocal aggression | A title mark that feels cut, struck, or forced into the frame while remaining readable |
| Pit pressure | Units and environment closing space from several directions; no safe heroic center |
| Brutal honesty | Dry materials, visible damage, grime, mud, ash, blood, worn iron, and no glamorous polish |

## Main-Menu World Direction

The next concept should show a real location from the game's war-horror world,
not an allegory for a show. Candidate situations include:

- A churned killing field beneath a colossal ruined structure whose scale makes
  the combatants feel trapped rather than heroic.
- A breached fortress interior moments after something inhuman forced its way
  through.
- A dead settlement under siege by an unseen force, with evidence of organized
  cruelty rather than random decay.
- A battlefield at the instant before two masses collide, framed from inside
  the crush instead of from a spectator's viewpoint.
- A ritualized execution ground or military tribunal where the architecture
  reveals how this world turns violence into law.

The best situation will imply a larger world, an immediate threat, and a
specific consequence without requiring lore text.

## Composition

- Use asymmetry, compression, and blocked escape routes.
- Avoid a centered hero or villain posing for the viewer.
- Place the camera within danger: low to the ground, partially occluded, or
  surrounded by evidence that violence has already crossed the frame.
- Build one dominant mass, one rupture, and one area of visual silence.
- Let the title occupy the silence as a hard graphic interruption rather than a
  diegetic sign or poster.
- Leave the lower-left space beneath the tagline visually quiet. The entire
  screen advances on click, keyboard input, or controller input rather than
  presenting a visible button.

## World Materials and Palette

- Ash, wet earth, scorched stone, splintered timber, worn iron, old blood,
  butchered cloth, smoke, bone, and ruined masonry.
- Matte black and charcoal as mass, dirty bone as information, dried oxblood as
  consequence, and one sickly or supernatural accent tied to the world's
  threat.
- Lighting should behave like horror cinematography: motivated, directional,
  obscuring, and dangerous. It should not resemble stage lighting.
- Texture belongs to the world image. Functional UI remains clean enough to
  scan immediately.

## Interface Character

The UI can inherit metal's force without pretending to be music memorabilia:

- Hard rectangular information fields with severe spacing and abrupt cuts.
- Condensed utility typography for labels and sturdy numerals for game state.
- An original aggressive wordmark used only at identity scale.
- Focus states that snap, strike, split, or briefly displace rather than glow
  decoratively.
- Motion built around tension and release: long stillness, short impact, fast
  recovery.
- Audio direction should eventually follow the same rule: physical pressure and
  rhythmic consequence, not a simulated concert mix.

## Acceptance Gates

- A viewer describes a brutal horror-war world before mentioning music or a
  concert.
- The screen feels aggressive even if the logo and all explicit music
  references are removed.
- The image suggests a specific conflict, threat, or social order native to
  Blood Will Pay.
- No stage, crowd-as-audience, performer, venue, ticket, flyer, speaker,
  amplifier, or tour metaphor is visible.
- The title and tagline remain readable at 3840x2160, 1920x1080, and 1280x720.
- The title image remains the sole visual headline. A compact incident docket
  and one minimal click/confirm prompt may support navigation, but neither may
  resemble promotional copy, approach the title's scale, or compete with its
  first-read dominance.
- The composition feels like pressure before impact rather than a poster
  advertising impact.
- Horror comes from place, consequence, scale, and implication—not Halloween
  props or gore quantity.
- Metal comes from rhythm, weight, rupture, and attitude—not literal
  iconography.

## Working Summary

The creative rule is:

> Do not put metal culture into the world. Build the kind of world that makes
> metal feel like the natural way to describe it.

Approved production artwork:

- `assets/ui/title/blood_will_pay_title_screen_4k.png`
- 3840x2160 PNG
- Button-free click-anywhere composition
- Not yet connected to the runtime title scene
