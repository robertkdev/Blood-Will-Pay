# Unit Ability Quality System

Status: design gate v1, 2026-08-04. This system judges the whole playable roster. It does not use damage totals or win rates as a substitute for ability design.

## The one-line test

Every ability must answer four questions in one short sentence:

1. What is the unit's unmistakable verb?
2. Who or what does it affect?
3. What team problem does it solve?
4. What can the opposing formation do about it?

Bonko is the reference shape: **Bonko bonks one target.** The animation, utility, and counterplay can elaborate on that promise, but the rules should not turn it into five unrelated promises.

## Seven scored gates

Each gate is scored `0`, `1`, or `2`. A `0` is a design failure, `1` needs revision or stronger proof, and `2` is roster-ready.

| Gate | 0 | 1 | 2 |
| --- | --- | --- | --- |
| Cohesion | Unrelated effects share one cast | A theme exists but has removable riders | Every effect expresses the same verb |
| Uniqueness | Functionally duplicates another unit | Familiar job with one real twist | Owns a recognizable roster niche |
| Team utility / RGA | Generic power with no formation job | Useful but weakly tied to the RGA identity | Clearly advances one primary goal through one or two approaches |
| Player clarity | Needs clauses, exceptions, or hidden math | Explainable with jargon or a long sentence | One short player sentence predicts the outcome |
| Visual satisfaction | Mostly invisible stats or generic noise | Readable but lacks a signature impact | Clear setup, unmistakable impact, and readable aftermath |
| Counterplay | Reliable payoff with no practical answer | One narrow answer or unclear response window | At least two visible levers plus a real failure or partial-denial state |
| Cost fit | Carries too many independent jobs for its tier | At the ceiling or dependent on a waiver | Delivers tier-appropriate depth without becoming a bundle |

`keep` requires every score to be at least `1` and a total of at least `11/14`. `simplify` means the core promise is worth keeping but at least one rider should be removed or exposed. `redesign` means the current promise, counterplay, or roster niche is unsound.

## Effect-family budget

Count independent outcomes, not individual numeric fields. Armor plus Magic Resist used as one visible fortification is one defensive buff; a shield plus a heal plus damage reduction are three defensive outcomes unless one is merely the conversion rule for another.

The canonical families are:

- `damage`
- `movement`
- `hard_cc`
- `ally_defense`
- `self_defense`
- `sustain`
- `offensive_buff`
- `enemy_debuff`
- `resource`
- `execute_reset`
- `economy`
- `zone`

| Cost | Normal family ceiling | Design expectation |
| --- | ---: | --- |
| 1 | 2 | One clean action, occasionally with one inseparable rider |
| 2 | 3 | One action plus a clear specialization hook |
| 3 | 4 | A developed play pattern with a readable condition |
| 4 | 4 | A premium formation tool, not four generic rewards |
| 5 | 5 | A capstone rule or spectacle with strategic depth, still one promise |

Exceeding the ceiling is never silently accepted. A `simplify` or `redesign` entry must name the breach and the proposed cut. Cohesion can still fail below the ceiling.

## Counterplay contract

Every unit must expose at least two of these levers:

- telegraph or mark before impact;
- formation or positioning requirement;
- target-selection manipulation;
- response window for healing, shielding, cleansing, or displacement;
- commitment or exposure after the cast;
- cooldown, resource, or setup dependency;
- partial denial, such as reducing targets hit or preventing the bonus condition.

Every contract also names a failure state. "The damage number can be tuned down" is not counterplay.

Assassins receive an additional gate. A single cast may not own all four of:

1. guaranteed backline access;
2. high-confidence kill or forced execute setup;
3. safe exit or untargetability;
4. reset or repeatability.

An assassin should normally own two, earn a third through a visible condition, and surrender the fourth.

## Trait and RGA relationship

The ability is not required to restate every trait. Its first responsibility is a specific team job. A trait hook is good when it changes how that job is assembled or timed; it is bad when it adds another unrelated reward merely to mention the trait.

Each contract records the live primary role, goal, and approaches. The automated smoke fails if those values drift. Design review should normally keep one primary goal and one or two ability-facing approaches; a third approach needs an especially coherent expression.

## Visual proof

Every ability needs a temporal proof with three readable beats:

1. **setup** — the player can identify the caster, intended target or area, and condition;
2. **impact** — one frame communicates the main verb without reading combat text;
3. **aftermath** — the resulting movement, link, zone, mark, or protection remains legible long enough to understand.

Generic damage, buff, shield, and debuff glyphs are feedback, not a unique ability signature. A roster-ready visual result needs a unit-specific silhouette, path, prop, timing pattern, or persistent state.

## Required evidence per unit

The machine-readable contract is `tests/design/unit_ability_quality_contract_v1.json`. Every playable unit records:

- the live unit, ability, cost, traits, role, goal, and approaches;
- one core promise and player sentence;
- current effect families;
- signature moment and specific team utility;
- counterplay levers and failure state;
- verdict, seven scores, problem, and exact design direction;
- at least one behavioral/RGA test case and one temporal visual test case.

Run `tests/design/AbilityDesignContractSmoke.tscn` after any playable unit, ability, cost, trait, or RGA identity change. Runtime balance still requires the existing Role Matrix and counter-outcome gates; this contract prevents those numeric gates from approving an incoherent or unanswerable ability.
