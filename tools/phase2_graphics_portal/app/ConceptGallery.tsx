"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { unitConcepts, type ConceptStatus } from "./unitData";

type Filter = "all" | ConceptStatus;

const filters: Array<{ value: Filter; label: string }> = [
  { value: "all", label: "All 12" },
  { value: "locked", label: "Locked redesigns · 2" },
  { value: "repaired", label: "Rebuilt masters · 4" },
  { value: "reinspect", label: "Reinspect · 6" },
];

export function ConceptGallery() {
  const [filter, setFilter] = useState<Filter>("all");
  const [activeId, setActiveId] = useState<string | null>(null);
  const dialogRef = useRef<HTMLDialogElement>(null);

  const visibleConcepts = useMemo(
    () =>
      filter === "all"
        ? unitConcepts
        : unitConcepts.filter((concept) => concept.status === filter),
    [filter],
  );

  const activeIndex = activeId
    ? visibleConcepts.findIndex((concept) => concept.id === activeId)
    : -1;
  const activeConcept =
    activeIndex >= 0 ? visibleConcepts[activeIndex] : undefined;

  useEffect(() => {
    const dialog = dialogRef.current;
    if (!dialog) return;

    if (activeConcept && !dialog.open) {
      dialog.showModal();
    } else if (!activeConcept && dialog.open) {
      dialog.close();
    }
  }, [activeConcept]);

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if (!activeConcept) return;
      if (event.key === "Escape") {
        event.preventDefault();
        setActiveId(null);
        return;
      }
      if (event.key === "ArrowLeft") {
        event.preventDefault();
        setActiveId(
          visibleConcepts[
            (activeIndex - 1 + visibleConcepts.length) %
              visibleConcepts.length
          ].id,
        );
      }
      if (event.key === "ArrowRight") {
        event.preventDefault();
        setActiveId(
          visibleConcepts[(activeIndex + 1) % visibleConcepts.length].id,
        );
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [activeConcept, activeIndex, visibleConcepts]);

  const move = (direction: -1 | 1) => {
    if (!activeConcept) return;
    const nextIndex =
      (activeIndex + direction + visibleConcepts.length) %
      visibleConcepts.length;
    setActiveId(visibleConcepts[nextIndex].id);
  };

  return (
    <main>
      <header className="archive-header">
        <div className="eyebrow">
          <span className="sigil" aria-hidden="true">
            II
          </span>
          Owner archive · current repository cut
        </div>
        <div className="title-row">
          <div>
            <h1>Phase II Concept Archive</h1>
            <p className="lede">
              Twelve current Gamble Battle directions, gathered into one
              inspection wall.
            </p>
          </div>
          <div className="archive-count" aria-label="12 current concepts">
            <strong>12</strong>
            <span>current concepts</span>
          </div>
        </div>
        <div className="status-note">
          <span className="status-mark" aria-hidden="true" />
          <p>
            <strong>Candidate-only archive.</strong> Phase II reapproval ended
            without a current Board verdict. Knoll and Malachor therefore show
            their later user-locked Stage III directions instead of obsolete
            Phase II masters.
          </p>
        </div>
      </header>

      <section className="controls" aria-label="Concept filters">
        <div className="filter-list" role="group" aria-label="Filter by status">
          {filters.map((item) => (
            <button
              key={item.value}
              className={filter === item.value ? "filter active" : "filter"}
              type="button"
              aria-pressed={filter === item.value}
              onClick={() => {
                setFilter(item.value);
                setActiveId(null);
              }}
            >
              {item.label}
            </button>
          ))}
        </div>
        <p className="inspection-hint">Select any portrait for full-size view</p>
      </section>

      <section className="gallery" aria-live="polite">
        {visibleConcepts.map((concept, index) => (
          <article
            className={`concept-card status-${concept.status}`}
            key={concept.id}
          >
            <button
              type="button"
              className="image-button"
              aria-label={`Inspect ${concept.name} full size`}
              onClick={() => setActiveId(concept.id)}
            >
              <img
                src={concept.image}
                alt={`${concept.name} — ${concept.sourceLabel}`}
                width={concept.width}
                height={concept.height}
                loading={index < 4 ? "eager" : "lazy"}
              />
              <span className="image-identity" aria-hidden="true">
                <small>{concept.role}</small>
                <strong>{concept.name}</strong>
                <em>{concept.statusLabel}</em>
              </span>
              <span className="inspect-chip">Inspect</span>
            </button>
            <div className="card-copy">
              <div className="card-heading">
                <div>
                  <p className="role">{concept.role}</p>
                  <h2>{concept.name}</h2>
                </div>
                <span className="ordinal">
                  {String(index + 1).padStart(2, "0")}
                </span>
              </div>
              <div className="card-status">
                <span className="status-dot" aria-hidden="true" />
                <span>
                  <strong>{concept.statusLabel}</strong>
                  <small>{concept.sourceLabel}</small>
                </span>
              </div>
            </div>
          </article>
        ))}
      </section>

      <footer>
        <p>Repository-backed source cut · July 2026</p>
        <p>Full-resolution originals · no thumbnails or generated caches</p>
      </footer>

      <dialog
        ref={dialogRef}
        className="lightbox"
        aria-label={activeConcept ? `${activeConcept.name} inspection` : "Image inspection"}
        onCancel={(event) => {
          event.preventDefault();
          setActiveId(null);
        }}
        onClose={() => setActiveId(null)}
        onClick={(event) => {
          if (event.target === event.currentTarget) setActiveId(null);
        }}
      >
        {activeConcept && (
          <div className="lightbox-shell">
            <button
              className="close-button"
              type="button"
              aria-label="Close full-size view"
              onClick={() => setActiveId(null)}
            >
              Close <span aria-hidden="true">×</span>
            </button>
            <div className="lightbox-image">
              <img
                src={activeConcept.image}
                alt={`${activeConcept.name} — ${activeConcept.sourceLabel}`}
                width={activeConcept.width}
                height={activeConcept.height}
              />
            </div>
            <aside className="lightbox-info">
              <p className="role">{activeConcept.role}</p>
              <h2>{activeConcept.name}</h2>
              <p className="lightbox-source">{activeConcept.sourceLabel}</p>
              <div className={`detail-status status-${activeConcept.status}`}>
                <span className="status-dot" aria-hidden="true" />
                <span>{activeConcept.statusLabel}</span>
              </div>
              <dl>
                <div>
                  <dt>Working stage</dt>
                  <dd>{activeConcept.stage}</dd>
                </div>
                <div>
                  <dt>Native size</dt>
                  <dd>
                    {activeConcept.width} × {activeConcept.height}
                  </dd>
                </div>
                <div>
                  <dt>Repository date</dt>
                  <dd>{activeConcept.sourceDate}</dd>
                </div>
              </dl>
              <div className="lightbox-nav">
                <button type="button" onClick={() => move(-1)}>
                  <span aria-hidden="true">←</span> Previous
                </button>
                <span>
                  {activeIndex + 1} / {visibleConcepts.length}
                </span>
                <button type="button" onClick={() => move(1)}>
                  Next <span aria-hidden="true">→</span>
                </button>
              </div>
              <p className="key-hint">Arrow keys navigate · Esc closes</p>
            </aside>
          </div>
        )}
      </dialog>
    </main>
  );
}
