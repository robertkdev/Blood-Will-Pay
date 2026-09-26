# Gameplay Composition Gap: Reference vs Current Runtime

Scope: art and layout only. This compares the supplied concept image with the
current player-facing gameplay runtime. It deliberately ignores rules, economy,
roster, board topology, and terminology. Nothing here re-opens gameplay behaviour.

## What Was Compared

| Item | File | Size |
| --- | --- | --- |
| Reference | `docs/art/references/gameplay_composition.png` | 1672 x 941 |
| Ours, populated planning, 100 percent | `outputs/visual_iter/composition_v10/03_populated_100.png` | 1920 x 1080 |
| Ours, sparse planning, 100 percent | `outputs/visual_iter/composition_v10/01_sparse_100.png` | 1920 x 1080 |
| Ours, active combat | `outputs/visual_iter/composition_v10/07_combat_active.png` | 1920 x 1080 |

Method: direct inspection of all four frames, plus a pixel measurement pass over
four fixed regions (left rail, centre field, right rail, lower band). Region
boundaries are proportional, so the two different image sizes are comparable.
Highlight figures are the share of pixels above a luminance, not a count of
decorative elements.

This is a still-frame comparison. It does not evaluate motion, frame pacing, or
interaction, and it is not an approval of any unit artwork.

## The Measured Gap

| Measure | Reference | Ours (populated) | Gap |
| --- | --- | --- | --- |
| Frame mean luminance | 0.0753 | 0.0641 | ours 15 percent darker |
| Frame p99 luminance | 0.617 | 0.582 | similar ceiling |
| Frame share above 0.40 | 2.80 percent | 2.89 percent | similar |
| Frame mean chroma | 0.0452 | 0.0374 | ours 17 percent less saturated |
| Warm ratio (mean R / mean B) | 1.75 | 1.77 | same warmth, less colour |
| Centre field mean luminance | 0.0932 | 0.0584 | ours 37 percent darker |
| Centre field median luminance | 0.0661 | 0.0428 | ours 35 percent darker |
| Centre field p99 luminance | 0.588 | 0.423 | ours 28 percent lower ceiling |
| Centre field share above 0.35 | 3.32 percent | 1.57 percent | ours 2.1x thinner |
| Centre field edge energy (x / y) | 0.030 / 0.036 | 0.019 / 0.022 | ours 35 to 39 percent weaker |
| Lower band share above 0.35 | 3.97 percent | 5.87 percent | ours 1.5x hotter |
| Lower band p99 luminance | 0.640 | 0.703 | ours brighter |
| Brightest full-width row | y 0.729 at 0.355 | y 0.014 at 0.250 | ours has no bright spine |
| Row-structure energy (full frame) | 0.0307 | 0.0099 | ours 3.1x flatter |
| Grid line prominence | 0.090 | 0.056 | ours 38 percent weaker |
| Left rail border edge strength | 0.179 | 0.248 | ours 38 percent harder |
| Right rail border edge strength | 0.238 | 0.288 | ours 21 percent harder |
| Right rail median luminance | 0.0162 | 0.0330 | ours rows 2x brighter inside |
| Right rail p99 luminance | 0.633 | 0.558 | ours 12 percent lower top end |

Combat, measured separately: field mean 0.117, field median 0.114, field p99
0.423, and p99/median only 3.7. A high median with a low ceiling is the numeric
signature of an evenly lit surface with nothing dominating it.

Three findings follow directly from those numbers.

1. Our highlight budget is inverted. In the reference, the playfield carries
   3.32 percent of hot pixels and the lower band carries 3.97 percent, so the
   field and the shop carry comparable energy. In ours the field carries 1.57
   percent and the lower band carries 5.87 percent, so the brightest, busiest
   territory on screen is the shop row and the darkest, flattest is the fight.
   The eye is being sent to the catalogue instead of the board.
2. Our chrome is louder than our content. Our rail borders produce stronger
   edges than the reference's (0.248 and 0.288 against 0.179 and 0.238) while
   the interior of those rails is flatter. The frame is doing the talking and
   the content is whispering. That is the specific mechanism behind the
   "UI skin" reading.
3. Our screen has no horizontal spine. The reference's single brightest
   full-width row sits at y 0.729 with luminance 0.355, and its second brightest
   at y 0.627 with 0.328. Ours peaks at the very top edge (y 0.014, 0.250) and
   then falls to 0.223 in the lower third. Their lower third is braced by two
   full-width light rules; ours is braced by nothing, which is why the lower
   part of our screen reads as stacked bands instead of one composed base.

## Layout: Mass And Territory

The reference resolves into a small number of large, unequal shapes. A left
column of about 16 percent of the width, a centre field of about 68 percent, a
right column of about 15 percent, and a lower band of about 20 percent of the
height split into three territories: shop, wager, and a large red commit plate.
The centre itself is split into two stacked fields of roughly equal height by a
full-width labelled divider.

Ours has the same skeleton, so the difference is not the plan, it is the
resolution of the plan.

- The centre is one continuous surface. Our status line is a floating pill
  sitting inside the field instead of a band that divides two territories. The
  reference's divider does structural work: it separates hostile ground from
  friendly ground and gives the eye a fixed horizon. Our pill occupies the most
  valuable real estate on the board and returns no structure.
- Our lower band has three territories, but they are not equally weighted. The
  commit action is a small plate at the far right, roughly the same visual mass
  as two shop cards. In the reference the equivalent plate is the largest single
  saturated mass on the screen. Psychologically, ours presents the decision as
  one option among several; theirs presents it as the point of the screen.
- Our rails are single panels holding repeated rows, and each panel is taller
  than its content. In the sparse state the left rail is roughly half empty
  black below the last trait row, and the right rail is roughly a third empty
  black below the last roster row. Two large residual voids sit symmetrically
  on either side of a mostly empty board. The reference has quiet areas too,
  but they are contained: the banner and motto inside the left column, the
  architecture and skull inside the right column, the dark corners of the
  board. Its quiet space is framed; ours is left over.
- Repeated shapes. Our trait rows, roster rows, bench slots, deployment tiles,
  and shop cards are all rounded rectangles of similar width and similar edge
  treatment. Repetition is not itself the problem, the reference repeats rows
  too. The difference is that its repeated rows vary internally (portrait, name,
  value, bar, silhouette) while our rows are close to uniform and are outlined
  at a consistent brightness, so they compete with each other for attention
  instead of forming a single readable column.

Net effect: the reference reads as four large shapes that balance before you
read a single word. Ours reads as a broad centre flanked by two columns, with
five horizontal strips stacked into the lower half. That is assembled sections,
not composed screen.

## Board, Ground, And Figures

The reference's board is a surface inside a room. Cell separations are visible
as markings on that surface, the hostile half is tinted differently from the
friendly half, and the surrounding architecture, standing figures, and grid all
agree about the viewing angle. Our planning board is a flat, screen-aligned
matrix laid over an environment whose architecture does not share its geometry,
so the tiles read as an overlay rather than as paving. Our measured grid
prominence is 0.056 against the reference's 0.090, which is the numeric version
of "the grid is barely there".

The same split shows in value. Our field median (0.043) is close to our field
mean (0.058), meaning the field is a fairly even mid-dark mass, and our field
ceiling (0.423) is well below the reference's (0.588). Their field is darker at
the median but has real high values in it: lit faces, metal edges, ivory and
gold figures against near-black cells. Ours has no such high values on the
board, so figures sitting on it have nothing to separate them from the ground.
Our characters do not read as placed in a lit room; they read as decals on a
mid-dark plane.

Across the four frames the figures are also not one colour family. Some are
pale grey-white, some carry saturated red and green. On the board this produces
a patchwork of unrelated values, which is why the individual figures are hard to
rank at a glance even when they are large enough to read.

## Side Rails

The reference's trait column carries icon, name, count, and a small pip row per
entry, and its roster column carries portrait, name, bar, and number per entry.
Both are dense with small high-contrast marks, and their borders stay quiet so
those marks do the work. Our trait rows are icon plus name plus count plus pips,
which is close, but they are separated by brighter borders and the panel
interior has a visible vertical streak that adds noise without adding meaning.

Our roster column is the weaker of the two. Measured, its row interiors are
twice as bright as the reference's (median 0.033 against 0.016) while its top
end is 12 percent lower (p99 0.558 against 0.633), and it carries about 40
percent less edge energy. In plain terms: our rows are large, mid-dark, and
mostly empty, with a small portrait on the left and a small zero at the far
right, and a wide dead gap between them. The reference's rows have the same
width but the bar and the number fill it, so the row reads as one statement.
Eight near-identical half-empty rows is also, psychologically, eight blank
looks: the column is present but says nothing.

## Lower Band

The reference splits the base into three clearly different territories with
three different shape languages: tall portrait cards with a vertical
image/name/cost sequence, a numeric control block with steppers and two outcome
rows, and a large red plate. Those three shapes are visually distinct before you
read them.

Ours splits into: five portrait cards, a run-on line of numbers
("1 bucket, 84-99 percent, 10 buckets / 8 buckets"), a slider, a small chip and
a small reroll button, then the commit plate. The wager territory is the weak
point. The reference presents the same information as two opposed rows with
icons and opposed colours, one gain and one loss, which reads instantly. Ours
presents it as a single dense text line with bullet separators, which the viewer
must parse. That is a hierarchy failure, not a content difference: the same
facts are available in both, but ours spends them on a sentence instead of a
shape.

Colour discipline compounds it. Red currently does at least five jobs on our
screen: the hostile label, the bench health bars, the trait chips, the shop cost
text, and the commit plate. The reference concentrates saturated red on
hostility and the commit plate, so red is a signal rather than decoration. When
the same hue marks a health bar and a purchase price and the primary action, it
stops marking anything.

## Type And Material

Type. Our "CHAPTER I" and panel titles use the Cinzel serif, which suits the
ceremonial frame, but the values, names, costs, and counts are heavy bold sans
at a weight that outranks the headings. The reference keeps its headings and
its numbers in a coordinated relationship, so the eye moves from title to value
along a single path. Our small labels are also the least legible element on the
screen, which is the wrong end of the scale to be weak at.

Material. The reference repeats one convincing material language for its
furniture: dark iron, restrained aged gold, recessed black interiors, and
burgundy cloth. Our furniture mixes a pale mint-grey border on the roster
column, warm gold borders on the trait column and the cards, thin gold tile
outlines, a bright red rule above the bench, and vertically streaked panel
interiors. Individually each is defensible. Together the thickness, brightness,
and texture scale of those borders do not agree, and the streaked interiors in
particular introduce a surface character that appears nowhere else on the
screen.

## Why Theirs Feels Alive

The reference is a still frame and still feels more animated than ours. That is
the most useful thing about it. Its energy is not coming from motion, it is
coming from contrast and variety: dark recesses against lit faces, one saturated
hue reserved for danger and decision, a hanging cloth and an angled grid
against an orthogonal frame, tall card shapes against wide roster rows,
silhouettes that face different directions.

Our screen has motion and still reads rigid, because variety has to be composed
before motion can enrich it. Motion on a uniform mid-dark field mostly produces
uniform mid-dark movement.

## Where The Reference Is Weak

Its small text is genuinely small and would fail our compact checks. Its edges
are crowded and several figures are still dark. Its roster column is doing more
work than it needs to. None of that should be reproduced. Its advantage is not
detail level or ornament count, it is that every part looks like it belongs to
one place and one hierarchy.

## Priority Order

The order matters. Doing these out of order spends effort on elements that the
larger structure will move anyway.

1. Value structure. Give the field its own highlights and stop the lower band
   from owning every bright pixel.
2. Horizontal articulation. Restore one dominant full-width accent in the lower
   third and a real divider between the two field halves.
3. Ground and figures. Make the grid a marking on the surface and give figures
   a value family that separates them from it.
4. Territory weighting. Make the commit plate the largest saturated mass on the
   screen and give the wager block a shape language of its own.
5. Colour discipline. Reserve red for hostility and commit.
6. Chrome and material. Unify border weights and temperatures, and remove the
   interior streak.
7. Typography. One family logic with tabular values in rows.
8. Portraits and icons, last, once the frame supports them.

## Measurable Acceptance Targets

Re-run the same measurement on fresh 1920 x 1080 captures. These are targets,
not achieved results.

| Measure | Now | Target |
| --- | --- | --- |
| Centre field mean luminance | 0.058 | 0.085 or higher |
| Centre field p99 luminance | 0.423 | 0.550 or higher |
| Centre field share above 0.35 | 1.57 percent | 3.0 percent or higher |
| Lower band share above 0.35 | 5.87 percent | at or below 4.5 percent |
| Row-structure energy | 0.0099 | 0.025 or higher |
| Grid line prominence | 0.056 | 0.080 or higher |
| Frame mean chroma | 0.0374 | 0.042 or higher |
| Rail border edge strength | 0.248 / 0.288 | 0.240 or lower |
| Combat field p99 / median | 3.70 | 5.0 or higher |

The point of the targets is that they are the reference's own envelope, not a
preference. Hitting them means our screen is spending light the way theirs does,
which is the part of their quality that actually transfers.

## What This Document Does Not Claim

It does not approve any unit artwork, frame asset, or generated UI texture. It
does not claim the reference should be copied, and it does not treat unit count,
occupied slots, or displayed values as differences worth correcting. Every
measurement above was taken from the stated files on 2026-09-26 and is only
valid for those captures.
