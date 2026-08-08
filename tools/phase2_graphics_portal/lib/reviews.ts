export const REVIEW_DECISIONS = ["approve", "needs_work"] as const;
export type ReviewDecision = (typeof REVIEW_DECISIONS)[number];

export const REVIEW_DECISION_LABELS: Record<ReviewDecision, string> = {
  approve: "Approve",
  needs_work: "Needs work",
};

export const UNIT_IDS = [
  "korath",
  "veyra",
  "cashmere",
  "pilfer",
  "nyxa",
  "creep",
  "knoll",
  "quillith",
  "kett",
  "luna",
  "malachor",
  "sable",
] as const;

const unitIdSet = new Set<string>(UNIT_IDS);
const decisionSet = new Set<string>(REVIEW_DECISIONS);

export const MAX_COMMENT_LENGTH = 2000;

export function isUnitId(value: unknown): value is (typeof UNIT_IDS)[number] {
  return typeof value === "string" && unitIdSet.has(value);
}

export function isReviewDecision(
  value: unknown,
): value is ReviewDecision {
  return typeof value === "string" && decisionSet.has(value);
}

export function normalizeComment(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const normalized = value.replace(/\r\n?/g, "\n").trim();
  if (!normalized || normalized.length > MAX_COMMENT_LENGTH) return null;
  return normalized;
}

export type ReviewComment = {
  id: string;
  body: string;
  authorName: string;
  createdAt: number;
};

export type UnitReview = {
  unitId: string;
  conceptSha256: string;
  decision: {
    value: ReviewDecision;
    reviewerName: string;
    updatedAt: number;
  } | null;
  comments: ReviewComment[];
};
