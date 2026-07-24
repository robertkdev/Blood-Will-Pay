"use client";

import { useMemo, useState } from "react";
import model from "../data/model.json";
import proofReport from "../public/proof-report.json";

type TabId = "matrix" | "traits" | "bridges" | "teams";
type CounterStrength = "hard" | "soft";

const tabs: Array<{ id: TabId; label: string; hint: string }> = [
  { id: "matrix", label: "Counter matrix", hint: "Who beats whom, and why" },
  { id: "traits", label: "Trait atlas", hint: "Capstones, supply, and answers" },
  { id: "bridges", label: "Bridge roster", hint: "23 numbered unit concepts" },
  { id: "teams", label: "Team lab", hint: "Proven 10-slot double verticals" },
];

const traitFamilies = ["all", ...Array.from(new Set(model.traits.map((trait) => trait.family))).sort()];

function titleCase(value: string) {
  return value
    .replaceAll("_", " ")
    .replaceAll("-", " ")
    .replace(/\b\w/g, (letter) => letter.toUpperCase());
}

function traitFinalCount(traitId: string) {
  const trait = model.traits.find((item) => item.id === traitId);
  if (!trait) return 0;
  return trait.currentCarriers.length + model.bridgeUnits.filter((unit) => unit.traits.includes(traitId)).length;
}

function matchup(rowId: string, columnId: string) {
  if (rowId === columnId) {
    return {
      score: 0,
      label: "Mirror",
      tone: "mirror",
      reason: "Same archetype. Positioning, unit quality, and execution decide the fight.",
      expected: 50,
    };
  }

  const direct = model.counterEdges.find((edge) => edge.winner === rowId && edge.loser === columnId);
  const reverse = model.counterEdges.find((edge) => edge.winner === columnId && edge.loser === rowId);
  const edge = direct ?? reverse;
  const rowWins = Boolean(direct);
  const strength = edge?.strength as CounterStrength;
  const magnitude = strength === "hard" ? 2 : 1;
  return {
    score: rowWins ? magnitude : -magnitude,
    label: `${rowWins ? "Favored" : "Unfavored"} · ${titleCase(strength)}`,
    tone: rowWins ? `win-${strength}` : `loss-${strength}`,
    reason: edge?.reason ?? "",
    expected: rowWins ? (strength === "hard" ? 72 : 61) : strength === "hard" ? 28 : 39,
  };
}

export function Explorer() {
  const [tab, setTab] = useState<TabId>("matrix");
  const [rowId, setRowId] = useState("bastion");
  const [columnId, setColumnId] = useState("dive");
  const [traitSearch, setTraitSearch] = useState("");
  const [family, setFamily] = useState("all");
  const [selectedTraitId, setSelectedTraitId] = useState("Arcanist");
  const [bridgeSearch, setBridgeSearch] = useState("");

  const selectedRow = model.archetypes.find((item) => item.id === rowId) ?? model.archetypes[0];
  const selectedColumn = model.archetypes.find((item) => item.id === columnId) ?? model.archetypes[1];
  const selectedMatchup = matchup(rowId, columnId);
  const selectedTrait = model.traits.find((trait) => trait.id === selectedTraitId) ?? model.traits[0];

  const visibleTraits = useMemo(() => {
    const query = traitSearch.trim().toLowerCase();
    return model.traits.filter((trait) => {
      const matchesFamily = family === "all" || trait.family === family;
      const haystack = `${trait.id} ${trait.family} ${trait.strategicJob} ${trait.enables.join(" ")} ${trait.answers.join(" ")}`.toLowerCase();
      return matchesFamily && (!query || haystack.includes(query));
    });
  }, [family, traitSearch]);

  const visibleBridgeUnits = useMemo(() => {
    const query = bridgeSearch.trim().toLowerCase();
    if (!query) return model.bridgeUnits;
    return model.bridgeUnits.filter((unit) =>
      `${unit.label} ${unit.role} ${unit.cost} ${unit.goal} ${unit.traits.join(" ")} ${unit.approaches.join(" ")} ${unit.archetypes.join(" ")}`
        .toLowerCase()
        .includes(query),
    );
  }, [bridgeSearch]);

  return (
    <main>
      <header className="hero">
        <div className="hero-grid">
          <div>
            <p className="eyebrow">Gamble Battle · planning laboratory</p>
            <h1>Every strategy has prey. Every answer has a predator.</h1>
            <p className="lede">
              A mathematically balanced RGA counter web, a complete trait supply plan, and 23 numbered
              bridge units that turn verticals into real team-composition choices.
            </p>
          </div>
          <div className="proof-seal" aria-label="Model validation summary">
            <span className="proof-seal-label">Model proof</span>
            <strong>{proofReport.summary.checks}</strong>
            <span>deterministic checks passed</span>
            <small>Source snapshot · 49 live units · 21 active traits</small>
          </div>
        </div>
        <div className="summary-strip">
          <div><strong>9</strong><span>balanced archetypes</span></div>
          <div><strong>36</strong><span>authored matchups</span></div>
          <div><strong>23</strong><span>numbered bridges</span></div>
          <div><strong>72</strong><span>planned roster</span></div>
          <div><strong>4</strong><span>proven double verticals</span></div>
        </div>
      </header>

      <nav className="tab-bar" aria-label="Explorer sections">
        {tabs.map((item) => (
          <button
            className={tab === item.id ? "tab active" : "tab"}
            key={item.id}
            onClick={() => setTab(item.id)}
            type="button"
          >
            <strong>{item.label}</strong>
            <span>{item.hint}</span>
          </button>
        ))}
      </nav>

      {tab === "matrix" && (
        <section className="section-shell" aria-labelledby="matrix-heading">
          <div className="section-heading">
            <div>
              <p className="eyebrow">Zero-sum tournament</p>
              <h2 id="matrix-heading">RGA counter matrix</h2>
            </div>
            <p>
              Read across a row. Every archetype has exactly two hard wins, two soft wins, two soft
              losses, and two hard losses. Every row sums to zero.
            </p>
          </div>

          <div className="matrix-layout">
            <div className="matrix-scroll" role="region" aria-label="Archetype counter matrix" tabIndex={0}>
              <table className="matrix-table">
                <thead>
                  <tr>
                    <th className="corner">ROW VS</th>
                    {model.archetypes.map((column) => (
                      <th key={column.id} title={column.name}>{column.code}</th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {model.archetypes.map((row) => (
                    <tr key={row.id}>
                      <th title={row.name}>{row.code}</th>
                      {model.archetypes.map((column) => {
                        const result = matchup(row.id, column.id);
                        const selected = row.id === rowId && column.id === columnId;
                        return (
                          <td key={column.id}>
                            <button
                              type="button"
                              className={`matrix-cell ${result.tone} ${selected ? "selected" : ""}`}
                              aria-label={`${row.name} versus ${column.name}: ${result.label}`}
                              title={`${row.name} vs ${column.name}: ${result.label}`}
                              onClick={() => {
                                setRowId(row.id);
                                setColumnId(column.id);
                              }}
                            >
                              {result.score > 0 ? `+${result.score}` : result.score}
                            </button>
                          </td>
                        );
                      })}
                    </tr>
                  ))}
                </tbody>
              </table>
              <div className="legend" aria-label="Matrix legend">
                <span><i className="swatch hard-win" />+2 hard edge</span>
                <span><i className="swatch soft-win" />+1 soft edge</span>
                <span><i className="swatch neutral" />0 mirror</span>
                <span><i className="swatch soft-loss" />−1 soft loss</span>
                <span><i className="swatch hard-loss" />−2 hard loss</span>
              </div>
            </div>

            <aside className="matchup-card">
              <p className="eyebrow">Selected matchup</p>
              <div className="versus-line">
                <strong>{selectedRow.name}</strong>
                <span>vs</span>
                <strong>{selectedColumn.name}</strong>
              </div>
              <div className={`verdict ${selectedMatchup.tone}`}>
                <span>{selectedMatchup.label}</span>
                <strong>{selectedMatchup.expected}%</strong>
                <small>planning-model win expectation</small>
              </div>
              <p>{selectedMatchup.reason}</p>
              <div className="matchup-split">
                <div>
                  <span>{selectedRow.code} plan</span>
                  <p>{selectedRow.plan}</p>
                </div>
                <div>
                  <span>{selectedColumn.code} failure mode</span>
                  <p>{selectedColumn.failureMode}</p>
                </div>
              </div>
            </aside>
          </div>

          <div className="archetype-grid">
            {model.archetypes.map((archetype) => (
              <article className="archetype-card" key={archetype.id}>
                <div className="card-title-line">
                  <span className="code-badge">{archetype.code}</span>
                  <h3>{archetype.name}</h3>
                </div>
                <p>{archetype.plan}</p>
                <div className="chip-row">
                  {archetype.signatureTraits.map((trait) => <span className="chip trait-chip" key={trait}>{trait}</span>)}
                </div>
                <dl className="role-shape">
                  {Object.entries(archetype.roleShape).filter(([, count]) => count > 0).map(([role, count]) => (
                    <div key={role}><dt>{titleCase(role)}</dt><dd>{count}</dd></div>
                  ))}
                </dl>
              </article>
            ))}
          </div>
        </section>
      )}

      {tab === "traits" && (
        <section className="section-shell" aria-labelledby="traits-heading">
          <div className="section-heading">
            <div>
              <p className="eyebrow">Natural capstones + redundancy</p>
              <h2 id="traits-heading">Trait atlas</h2>
            </div>
            <p>
              Mogul is retired. Every active trait reaches its natural maximum without lowering a
              threshold, and every vertical has at least one extra draftable carrier.
            </p>
          </div>
          <div className="filters">
            <label>
              <span>Search traits</span>
              <input value={traitSearch} onChange={(event) => setTraitSearch(event.target.value)} placeholder="Try sustain, zone, source kill…" />
            </label>
            <label>
              <span>Family</span>
              <select value={family} onChange={(event) => setFamily(event.target.value)}>
                {traitFamilies.map((item) => <option value={item} key={item}>{titleCase(item)}</option>)}
              </select>
            </label>
          </div>

          <div className="trait-layout">
            <div className="trait-grid">
              {visibleTraits.map((trait) => {
                const maxTier = Math.max(...trait.thresholds);
                const finalCount = traitFinalCount(trait.id);
                const currentCount = trait.currentCarriers.length;
                return (
                  <button
                    type="button"
                    key={trait.id}
                    className={selectedTrait.id === trait.id ? "trait-card selected" : "trait-card"}
                    onClick={() => setSelectedTraitId(trait.id)}
                  >
                    <div className="card-title-line">
                      <span className={`family-dot family-${trait.family}`} />
                      <h3>{trait.id}</h3>
                      <span className="family-label">{titleCase(trait.family)}</span>
                    </div>
                    <div className="supply-line">
                      <span><b>{currentCount}</b> current</span>
                      <i>→</i>
                      <span><b>{finalCount}</b> planned</span>
                      <em>max {maxTier}</em>
                    </div>
                    <div className="tier-track" aria-label={`${trait.id} thresholds ${trait.thresholds.join(", ")}`}>
                      {trait.thresholds.map((tier) => <span key={tier} className={tier === maxTier ? "capstone" : ""}>{tier}</span>)}
                    </div>
                    <p>{trait.strategicJob}</p>
                  </button>
                );
              })}
            </div>

            <aside className="trait-detail">
              <p className="eyebrow">Trait contract</p>
              <h3>{selectedTrait.id}</h3>
              <p className="detail-job">{selectedTrait.strategicJob}</p>
              <div className="detail-metric">
                <span>Supply</span>
                <strong>{selectedTrait.currentCarriers.length} → {traitFinalCount(selectedTrait.id)}</strong>
                <small>capstone at {Math.max(...selectedTrait.thresholds)}</small>
              </div>
              <h4>Enables</h4>
              <div className="chip-row">{selectedTrait.enables.map((item) => <span className="chip" key={item}>{item}</span>)}</div>
              <h4>Readable answers</h4>
              <div className="chip-row">{selectedTrait.answers.map((item) => <span className="chip answer-chip" key={item}>{titleCase(item)}</span>)}</div>
              <h4>Numbered bridges</h4>
              <ul className="compact-list">
                {model.bridgeUnits.filter((unit) => unit.traits.includes(selectedTrait.id)).map((unit) => (
                  <li key={unit.id}><strong>{unit.label}</strong><span>Cost {unit.cost} · {titleCase(unit.role)}</span></li>
                ))}
              </ul>
            </aside>
          </div>
        </section>
      )}

      {tab === "bridges" && (
        <section className="section-shell" aria-labelledby="bridges-heading">
          <div className="section-heading">
            <div>
              <p className="eyebrow">Temporary identities, not production names</p>
              <h2 id="bridges-heading">Numbered bridge roster</h2>
            </div>
            <p>
              The additions balance all six roles at 12 each, preserve a descending cost curve,
              cover all 22 approaches, and make the trait graph draftable.
            </p>
          </div>
          <div className="bridge-summary">
            {Object.entries(model.catalog.targetFinalRoleCounts).map(([role, count]) => (
              <span key={role}><b>{count}</b>{titleCase(role)}</span>
            ))}
          </div>
          <div className="filters single-filter">
            <label>
              <span>Find a bridge</span>
              <input value={bridgeSearch} onChange={(event) => setBridgeSearch(event.target.value)} placeholder="Trait, role, approach, archetype…" />
            </label>
          </div>
          <div className="bridge-table-wrap">
            <table className="bridge-table">
              <thead>
                <tr>
                  <th>Unit</th>
                  <th>Cost / role</th>
                  <th>Trait bridge</th>
                  <th>RGA identity</th>
                  <th>Kit hypothesis</th>
                </tr>
              </thead>
              <tbody>
                {visibleBridgeUnits.map((unit) => (
                  <tr key={unit.id}>
                    <td><strong>{unit.label}</strong><small>{unit.id}</small></td>
                    <td><span className={`cost-badge cost-${unit.cost}`}>{unit.cost}</span>{titleCase(unit.role)}</td>
                    <td><div className="chip-row">{unit.traits.map((trait) => <span className="chip trait-chip" key={trait}>{trait}</span>)}</div></td>
                    <td><strong>{titleCase(unit.goal)}</strong><div className="approach-list">{unit.approaches.map(titleCase).join(" · ")}</div></td>
                    <td>{unit.hook}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      )}

      {tab === "teams" && (
        <section className="section-shell" aria-labelledby="teams-heading">
          <div className="section-heading">
            <div>
              <p className="eyebrow">10-slot feasibility proof</p>
              <h2 id="teams-heading">Promised double verticals</h2>
            </div>
            <p>
              For capstones A and B, required shared carriers are max(0, A + B − 10).
              Each board below meets that lower bound exactly.
            </p>
          </div>
          <div className="formula-card">
            <span>Fieldability invariant</span>
            <strong>overlap ≥ max(0, tier A + tier B − board cap)</strong>
            <small>No emblems, trait-count augments, or hidden capacity assumptions.</small>
          </div>
          <div className="pair-grid">
            {model.promisedPairs.map((pair) => {
              const left = model.traits.find((trait) => trait.id === pair.traits[0])!;
              const right = model.traits.find((trait) => trait.id === pair.traits[1])!;
              const leftTier = Math.max(...left.thresholds);
              const rightTier = Math.max(...right.thresholds);
              return (
                <article className="pair-card" key={pair.identity}>
                  <div className="pair-card-head">
                    <div>
                      <p className="eyebrow">{pair.identity}</p>
                      <h3>{pair.traits[0]} {leftTier} + {pair.traits[1]} {rightTier}</h3>
                    </div>
                    <span className="pass-badge">FIELDABLE</span>
                  </div>
                  <div className="overlap-proof">
                    <div><span>Required</span><strong>{pair.requiredOverlap}</strong></div>
                    <i>≤</i>
                    <div><span>Planned</span><strong>{pair.plannedOverlap}</strong></div>
                    <i>·</i>
                    <div><span>Board</span><strong>{pair.board.length}/10</strong></div>
                  </div>
                  <p>{pair.choice}</p>
                  <h4>Shared bridge carriers</h4>
                  <div className="chip-row">
                    {pair.overlapUnits.map((unit) => <span className="chip" key={unit}>{titleCase(unit)}</span>)}
                  </div>
                  <details>
                    <summary>Show full 10-unit board</summary>
                    <ol className="board-list">
                      {pair.board.map((unit) => <li key={unit}>{titleCase(unit)}</li>)}
                    </ol>
                  </details>
                </article>
              );
            })}
          </div>
        </section>
      )}

      <footer>
        <div>
          <strong>What is proven here</strong>
          <span>Graph balance, capstone supply, redundancy, cost curve, role balance, approach coverage, and 10-slot overlap feasibility.</span>
        </div>
        <div>
          <strong>What still needs runtime proof</strong>
          <span>Ability numbers, real combat win rates, item interactions, shop odds, and player-facing fun across repeated runs.</span>
        </div>
        <a href="/proof-report.json">Open machine proof report</a>
      </footer>
    </main>
  );
}
