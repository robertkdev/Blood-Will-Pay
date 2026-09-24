# The mirror change is verified - and it did not buy any depth - 2026-09-24

Two things, both measured, and the second is the more important one.

## 1. The change works, unambiguously

Six seeds, two arms, the heuristic lane, only the mirror's body count differing:

| arm | mirror fights | body margin | mirror win rate |
| --- | ---: | --- | ---: |
| control (same-size mirror) | 42 | all **0** | **19 / 42 = 45%** |
| change (mirror fields one fewer body) | 20 | all **+1** | **20 / 20 = 100%** |

The control reproduces the historical mirror rate exactly - 45%, which is what the recorded era
showed for chapter 2 and near its 57% overall - so the arm is a valid baseline rather than a
lucky sample. The change takes it to 100%; a coin flip would produce 20 wins in a row about once
in eighteen million trials, so this is not a borderline result.

Consistent with the 2,474-fight table, which says one extra body is worth about 92%: observed
100% on twenty samples has a 95% interval of roughly 83-100%.

**The mirror change moves from "effect unconfirmed" to confirmed**, and the caveat in
`docs/mirror_body_count_fix_2026-09-24.md` is now closed for the mechanism it claimed.

## 2. And depth did not move at all

| arm | mean chapter | run endings |
| --- | ---: | --- |
| control | **4.2** | ch1 mirror, ch2 normal, ch2 mirror, ch2 mirror, ch9 boss, ch9 boss |
| change | **4.3** | ch2 normal, ch2 boss, ch5 boss, ch5 boss, ch5 boss, ch7 boss |

Three of the control's six runs ended on the mirror. **None of the change's six did** - and four
of them ended on the boss stage instead.

The wall moved; it did not come down. Full win rate by encounter kind:

| kind | control | change |
| --- | ---: | ---: |
| CREEPS | 19/19 = 100% | 20/20 = 100% |
| NORMAL | 48/55 = 87% | 50/54 = 93% |
| BOSS | 22/38 = 58% | 20/42 = 48% |
| MIRROR | 19/42 = 45% | **20/20 = 100%** |

Runs advance by passing **every** stage in a chapter, so a chapter's survival is the *product* of
its gates. Making one gate free does not raise that product much when a second gate sits right
behind it at 48-58%: the run that used to die at the mirror now dies at the boss four rounds
later. That is exactly what the numbers show, and it is the same reason every earlier
single-lever change in this review was absorbed.

## What this means for the requirements

- **"Stage 10 should be easy to hit"** is now satisfied literally: stage 10 is the chapter-2
  mirror and it is a 100% win. It is arguably *too* free - the mirror no longer functions as a
  check at all. Dropping one body only in the early chapters is the obvious refinement, and it
  is a design decision rather than a correction.
- **"Chapter 10 as a good run"** needs the whole ladder, not one gate. With gates at roughly
  90% (normal), 50% (boss) and 100% (mirror), a chapter survives about 0.9 x 0.9 x 0.9 x 0.5 =
  0.36 before retries. Eight chapters of that is about 0.03%, and retries soften it but do not
  change the shape. Depth is a *product* problem and single-stage levers cannot fix it.
- The boss stage is now the binding gate, at 48-58%, and it is where four of six change runs
  ended. If one stage is to be softened next, it is that one - and the honest prediction, from
  this experiment, is that depth still will not move much unless the normal stages soften too.

## Gates and hygiene

| gate | result |
| --- | --- |
| heuristic lane, 12 runs | 0-8 technical failures per run, down from 21-26 before this session's deadlock fixes |
| worktree | the temporary control edit was reverted; the tree matches the last commit |

The control arm required a temporary one-line change to `mirror_board_store.gd`. It was reverted
and `git diff` is empty, which is stated because an un-reverted control arm is exactly the kind
of thing that silently becomes a shipped change.
