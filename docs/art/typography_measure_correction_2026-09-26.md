# The heading was never too heavy: a measurement correction

Date: 2026-09-26. This closes the last open item on the typography list, and it
closes it by correcting the instrument rather than the screen.

## What the measure said

The tick system reported the chapter heading's stroke at 3.77px against the
reference's 2.01px, which read as "our heading's type is nearly twice the
reference's weight", and put it on the list of open items.

## What it was measuring

It was averaging every horizontal run of ink in the band. Two of our heading
band's 311 runs are about **304 pixels long** - they are the chapter plate's own
rules, not letters - and averaging those into a stroke measure reported 3.77px of
"type" where the letters are 1.58px. The reference's band happens to contain no
such rule inside the measured crop, so its average was type only.

`measure_composition.py` now separates them: a run longer than 12px is counted as
a rule, not a stroke, and both are reported.

## The corrected comparison

| Measure | Reference | Ours |
| --- | --- | --- |
| heading ink share | 0.0248 | 0.0263 |
| heading type stroke | 2.01 px | **1.85 px** |
| heading rule runs in the band | 0 | 1 |
| readout band rule runs | 8 | 0 |
| readout type stroke | 2.16 px | 2.59 px |
| readout type stroke over the heading's | 1.07 | 1.40 |

So the heading's type is **lighter** than the reference's, not heavier, and the
item is closed as an artifact. No runtime change was made for it. Shrinking the
chapter plate to chase the old number would have made the heading worse.

## What the correction leaves open, and why it is copy, not type

The corrected numbers do show one real difference: our readout's type strokes are
20 percent thicker than the reference's (2.59 against 2.16), and they stand 1.40
times our own heading where the reference's stand 1.07 times its own.

That is a copy-length difference before it is a type one. The reference's divider
reads four long segments - "Preparation Phase", "15:37", "Board 9/9",
"Win Chance 80 - 99%" - where ours reads four short tokens, "PLAN", "Plan 1:56",
"Board 8/10", "WIN 1-23%". Matching its ink share with shorter copy needs larger
type, and larger type has thicker strokes; the two cannot both match at this copy
length. Changing the words is a product decision, and the readout's size is one
number per tier if the operator prefers the other trade.

## Verification

- The instrument change is measurement-only; no game code, asset or scene
  changed. The captures and every other reading are unchanged.
- The corrected measures reproduce on the same fresh capture
  (`outputs/visual_iter/composition_v10/03_populated_100.png`) and the same
  reference the rest of this work uses.

## What this does not claim

This does not approve any artwork and does not claim the typography is finished
beyond this item. The trial panel material is still awaiting the operator's
acceptance.
