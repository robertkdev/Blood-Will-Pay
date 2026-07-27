"use client";

import {
  type FormEvent,
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import {
  MAX_COMMENT_LENGTH,
  REVIEW_DECISION_LABELS,
  type ReviewDecision,
  type UnitReview,
} from "../lib/reviews";
import { unitConcepts, type ConceptStatus } from "./unitData";

type Filter = "all" | ConceptStatus;

const filters: Array<{ value: Filter; label: string }> = [
  { value: "all", label: "All 12" },
  { value: "locked", label: "Locked redesigns · 2" },
  { value: "repaired", label: "Rebuilt masters · 4" },
  { value: "reinspect", label: "Reinspect · 6" },
];

function commentDate(timestamp: number): string {
  return new Intl.DateTimeFormat(undefined, {
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
  }).format(new Date(timestamp));
}

export function ConceptGallery() {
  const [filter, setFilter] = useState<Filter>("all");
  const [activeId, setActiveId] = useState<string | null>(null);
  const [review, setReview] = useState<UnitReview | null>(null);
  const [reviewLoading, setReviewLoading] = useState(false);
  const [reviewError, setReviewError] = useState<string | null>(null);
  const [commentDraft, setCommentDraft] = useState("");
  const [savingComment, setSavingComment] = useState(false);
  const [savingDecision, setSavingDecision] = useState(false);
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

  const activateConcept = useCallback((unitId: string) => {
    setReview(null);
    setReviewError(null);
    setReviewLoading(true);
    setCommentDraft("");
    setActiveId(unitId);
  }, []);

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
    if (!activeConcept) return;

    const controller = new AbortController();

    fetch(`/api/reviews?unit=${encodeURIComponent(activeConcept.id)}`, {
      cache: "no-store",
      signal: controller.signal,
    })
      .then(async (response) => {
        if (!response.ok) {
          const payload = (await response.json().catch(() => null)) as {
            error?: string;
          } | null;
          throw new Error(payload?.error ?? "Could not load review notes.");
        }
        return response.json() as Promise<UnitReview>;
      })
      .then(setReview)
      .catch((error: unknown) => {
        if (error instanceof DOMException && error.name === "AbortError") return;
        setReviewError(
          error instanceof Error ? error.message : "Could not load review notes.",
        );
      })
      .finally(() => {
        if (!controller.signal.aborted) setReviewLoading(false);
      });

    return () => controller.abort();
  }, [activeConcept]);

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if (!activeConcept) return;
      if (event.key === "Escape") {
        event.preventDefault();
        setActiveId(null);
        return;
      }

      const target = event.target;
      const isEditing =
        target instanceof HTMLInputElement ||
        target instanceof HTMLTextAreaElement ||
        target instanceof HTMLSelectElement;
      if (isEditing) return;

      if (event.key === "ArrowLeft") {
        event.preventDefault();
        activateConcept(
          visibleConcepts[
            (activeIndex - 1 + visibleConcepts.length) %
              visibleConcepts.length
          ].id,
        );
      }
      if (event.key === "ArrowRight") {
        event.preventDefault();
        activateConcept(
          visibleConcepts[(activeIndex + 1) % visibleConcepts.length].id,
        );
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [activeConcept, activeIndex, activateConcept, visibleConcepts]);

  const move = (direction: -1 | 1) => {
    if (!activeConcept) return;
    const nextIndex =
      (activeIndex + direction + visibleConcepts.length) %
      visibleConcepts.length;
    activateConcept(visibleConcepts[nextIndex].id);
  };

  const saveDecision = async (decision: ReviewDecision) => {
    if (!activeConcept) return;
    setSavingDecision(true);
    setReviewError(null);
    try {
      const response = await fetch(
        `/api/reviews?unit=${encodeURIComponent(activeConcept.id)}`,
        {
          method: "PUT",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ decision }),
        },
      );
      const payload = (await response.json()) as UnitReview & { error?: string };
      if (!response.ok) throw new Error(payload.error ?? "Decision was not saved.");
      setReview(payload);
    } catch (error: unknown) {
      setReviewError(
        error instanceof Error ? error.message : "Decision was not saved.",
      );
    } finally {
      setSavingDecision(false);
    }
  };

  const submitComment = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!activeConcept || !commentDraft.trim()) return;
    setSavingComment(true);
    setReviewError(null);
    try {
      const response = await fetch(
        `/api/reviews?unit=${encodeURIComponent(activeConcept.id)}`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ body: commentDraft }),
        },
      );
      const payload = (await response.json()) as UnitReview & { error?: string };
      if (!response.ok) throw new Error(payload.error ?? "Comment was not sent.");
      setReview(payload);
      setCommentDraft("");
    } catch (error: unknown) {
      setReviewError(
        error instanceof Error ? error.message : "Comment was not sent.",
      );
    } finally {
      setSavingComment(false);
    }
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
        <p className="inspection-hint">
          Inspect, comment, and record a decision
        </p>
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
              onClick={() => activateConcept(concept.id)}
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
        aria-label={
          activeConcept ? `${activeConcept.name} review` : "Concept review"
        }
        onCancel={(event) => {
          event.preventDefault();
          setActiveId(null);
        }}
        onClose={() => setActiveId(null)}
      >
        {activeConcept && (
          <div className="viewer-shell">
            <section className="viewer-stage" aria-label="Full-size concept image">
              <div className="viewer-heading">
                <p>{activeConcept.role}</p>
                <h2>{activeConcept.name}</h2>
                <span>{activeConcept.statusLabel}</span>
              </div>

              <a
                className="viewer-image"
                href={activeConcept.image}
                target="_blank"
                rel="noreferrer"
                title="Open original image"
              >
                <img
                  src={activeConcept.image}
                  alt={`${activeConcept.name} — ${activeConcept.sourceLabel}`}
                  width={activeConcept.width}
                  height={activeConcept.height}
                />
              </a>

              <button
                className="viewer-nav viewer-nav-previous"
                type="button"
                aria-label="Previous unit"
                onClick={() => move(-1)}
              >
                ←
              </button>
              <button
                className="viewer-nav viewer-nav-next"
                type="button"
                aria-label="Next unit"
                onClick={() => move(1)}
              >
                →
              </button>

              <div className="viewer-foot">
                <span>
                  {activeIndex + 1} / {visibleConcepts.length}
                </span>
                <span>Click image for original · Arrow keys navigate</span>
              </div>
            </section>

            <aside className="review-panel">
              <div className="review-panel-head">
                <div>
                  <p className="role">Unit review</p>
                  <h3>{activeConcept.name}</h3>
                </div>
                <button
                  className="close-button"
                  type="button"
                  aria-label="Close full-screen review"
                  onClick={() => setActiveId(null)}
                >
                  <span aria-hidden="true">×</span>
                </button>
              </div>

              <label className="decision-field">
                <span>Decision</span>
                <select
                  value={review?.decision?.value ?? ""}
                  disabled={reviewLoading || savingDecision}
                  onChange={(event) => {
                    if (event.target.value) {
                      void saveDecision(event.target.value as ReviewDecision);
                    }
                  }}
                >
                  <option value="" disabled>
                    Choose a decision
                  </option>
                  <option value="approve">
                    {REVIEW_DECISION_LABELS.approve}
                  </option>
                  <option value="needs_work">
                    {REVIEW_DECISION_LABELS.needs_work}
                  </option>
                </select>
                <small aria-live="polite">
                  {savingDecision
                    ? "Saving…"
                    : review?.decision
                      ? `Saved by ${review.decision.reviewerName}`
                      : "No decision recorded"}
                </small>
              </label>

              <section className="comment-section" aria-label="Review comments">
                <div className="comment-title">
                  <h4>Comments</h4>
                  <span>{review?.comments.length ?? 0}</span>
                </div>

                <form className="comment-form" onSubmit={submitComment}>
                  <label htmlFor="review-comment">Add a note for this unit</label>
                  <textarea
                    id="review-comment"
                    value={commentDraft}
                    maxLength={MAX_COMMENT_LENGTH}
                    placeholder="What works? What should change?"
                    disabled={reviewLoading || savingComment}
                    onChange={(event) => setCommentDraft(event.target.value)}
                  />
                  <div>
                    <span>
                      {commentDraft.length}/{MAX_COMMENT_LENGTH}
                    </span>
                    <button
                      type="submit"
                      disabled={!commentDraft.trim() || savingComment}
                    >
                      {savingComment ? "Sending…" : "Send comment"}
                    </button>
                  </div>
                </form>

                {reviewError && (
                  <p className="review-error" role="alert">
                    {reviewError}
                  </p>
                )}

                <div className="comment-list" aria-live="polite">
                  {reviewLoading && <p className="review-muted">Loading review…</p>}
                  {!reviewLoading &&
                    review &&
                    review.comments.length === 0 && (
                      <p className="review-muted">
                        No comments yet. Start the review here.
                      </p>
                    )}
                  {review?.comments.map((comment) => (
                    <article className="comment" key={comment.id}>
                      <div>
                        <strong>{comment.authorName}</strong>
                        <time dateTime={new Date(comment.createdAt).toISOString()}>
                          {commentDate(comment.createdAt)}
                        </time>
                      </div>
                      <p>{comment.body}</p>
                    </article>
                  ))}
                </div>
              </section>

              <details className="concept-details">
                <summary>Source details</summary>
                <dl>
                  <div>
                    <dt>Direction</dt>
                    <dd>{activeConcept.sourceLabel}</dd>
                  </div>
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
              </details>
            </aside>
          </div>
        )}
      </dialog>
    </main>
  );
}
