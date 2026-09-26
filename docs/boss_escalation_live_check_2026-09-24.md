# The early-boss change, confirmed live - and depth still did not move - 2026-09-24

`docs/what_ends_runs_and_early_boss_escalation_2026-09-24.md` shipped the chapter-scaled boss
escalation on a deterministic measurement and said the live effect was not measured. This is it.

## Same seeds, two arms, only the escalation differing

Six seeds played through the heuristic lane on the current code, against the same six seeds from
the previous turn - those runs carried the mirror fix but predate the boss change, so they are an
exact same-seed control for it.

| arm | ch1-3 boss | ch4+ boss | mean chapter |
| --- | ---: | ---: | ---: |
| control (un-scaled escalation) | **14 / 19 = 74%** | 6 / 23 = 26% | 4.33 |
| treatment (chapters 1-2 softened) | **10 / 11 = 91%** | 4 / 11 = 36% | 3.33 |

The chapter 1-3 boss rate rises from 74% to 91%, in the same direction and of the same order as
the deterministic probe's exact result - where a prepared chapter-2 board went from 78% to a
certainty. Two independent instruments, one constructed and one live, agree on the effect.

The chapter 4+ figure also moved, 26% to 36%, and **the change does not touch chapter 4 or
later at all** - the probe showed those cells byte-identical. That movement is run selection:
the two arms reached different chapters, so the population of chapter-4-plus boss fights differs
between them. It is recorded as noise rather than as an effect.

## And depth did not move - for the third time

Mean chapter went from 4.33 to **3.33**, which is *shallower*, not deeper. Four of the
treatment's six runs ended in chapter 2 against two of the control's.

This is now the third gate-softening in a row that worked exactly as designed and moved no
depth:

1. the mirror, from a 45% coin flip to a 100% win (`docs/mirror_change_verified_wall_moved_2026-09-24.md`);
2. this, the chapter 1-2 boss, from 74% to 91%;
3. and before both, every re-pricing of a stage target.

The explanation is the one that experiment produced: a run advances only by passing **every**
stage, so a chapter survives as the *product* of its gates, and a run has to survive ten of
those. Softening one gate raises the product by a few percent and then the run dies at the next
one. The single-run depth figures here are also inside the same-seed spread this project has
measured at 1.75 chapters, so "shallower" is not itself a finding - the finding is that a
verified, large gate improvement produced no visible depth change.

## What would actually move it

The arithmetic is unforgiving and worth stating plainly: reaching chapter 10 means passing on the
order of fifty stages. To land there in 10% of runs you need an average per-stage pass rate near
95%, and to land there at all you need the *worst* gate in each chapter to stop being the boss
at 65%.

Three shapes could do it, and they are design decisions rather than corrections:

- **Fewer gates per chapter.** Four stages instead of five multiplies chapter survival by about
  1/0.9, and it is the cheapest lever on the product.
- **A genuinely rising curve.** Early bosses at 90%+, late bosses at 50%, which is what the
  escalation scaling has now started - it needs to extend past chapter 2 rather than stop there.
- **A bigger retry allowance on late stages**, which raises the product without making any fight
  easier. The run already allows four attempts; the boss's 65% first-attempt rate becomes 98.5%
  within those four, and yet runs still stall, so this lever is smaller than it looks.

The item criterion is downstream of this: at the measured 0.71 items per chapter, reaching
chapter 10 would produce about 7.1 of the 8 required, so depth is still the binding constraint
there too.

## Gates

| gate | result |
| --- | --- |
| live heuristic, 6 seeds | 0-6 technical failures per run |
| build | unchanged since the last commit; this turn adds no code |
