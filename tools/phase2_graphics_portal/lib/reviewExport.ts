import type { UnitConcept } from "../app/unitData.ts";
import type {
  ReviewCommentExportRow,
  ReviewDecisionExportRow,
} from "../db/reviews.ts";
import {
  REVIEW_DECISION_LABELS,
  type ReviewDecision,
} from "./reviews.ts";

export type ReviewExport = {
  schemaVersion: 1;
  sourceHead: string;
  changedAt: number | null;
  units: Array<{
    id: string;
    name: string;
    role: string;
    currentVersionId: string;
    revisions: Array<{
      versionId: string;
      referenceName: string;
      conceptSha256: string;
      current: boolean;
      status: string;
      decision: {
        value: ReviewDecision;
        reviewerName: string;
        updatedAt: number;
      } | null;
      comments: Array<{
        id: string;
        body: string;
        authorName: string;
        createdAt: number;
      }>;
    }>;
  }>;
};

type ReviewRows = {
  decisions: ReviewDecisionExportRow[];
  comments: ReviewCommentExportRow[];
};

function activityTimestamp(
  decision: ReviewDecisionExportRow | undefined,
  comments: ReviewCommentExportRow[],
): number {
  return Math.max(
    decision?.updated_at ?? 0,
    ...comments.map((comment) => comment.created_at),
  );
}

export function buildReviewExport(
  concepts: UnitConcept[],
  sourceHead: string,
  rows: ReviewRows,
): ReviewExport {
  const knownUnits = new Set(concepts.map((concept) => concept.id));
  const unknownUnit = [...rows.decisions, ...rows.comments].find(
    (row) => !knownUnits.has(row.unit_id),
  );
  if (unknownUnit) {
    throw new Error(`Review data contains unknown unit: ${unknownUnit.unit_id}`);
  }

  const allActivity = [
    ...rows.decisions.map((row) => row.updated_at),
    ...rows.comments.map((row) => row.created_at),
  ];

  return {
    schemaVersion: 1,
    sourceHead,
    changedAt: allActivity.length > 0 ? Math.max(...allActivity) : null,
    units: concepts.map((concept) => {
      const knownVersionsBySha = new Map(
        concept.versions.map((version) => [version.sha256, version]),
      );
      const unitDecisions = rows.decisions.filter(
        (row) => row.unit_id === concept.id,
      );
      const unitComments = rows.comments.filter(
        (row) => row.unit_id === concept.id,
      );
      const reviewHashes = new Set([
        ...unitDecisions.map((row) => row.concept_sha256),
        ...unitComments.map((row) => row.concept_sha256),
      ]);
      const unknownHash = [...reviewHashes].find(
        (sha256) => !knownVersionsBySha.has(sha256),
      );
      if (unknownHash) {
        throw new Error(
          `Review data for ${concept.id} references an unknown art version.`,
        );
      }

      const revisions = concept.versions.map((version) => {
        const decision = unitDecisions.find(
          (row) => row.concept_sha256 === version.sha256,
        );
        const comments = unitComments.filter(
          (row) => row.concept_sha256 === version.sha256,
        );
        return {
          versionId: version.id,
          referenceName: version.referenceName,
          conceptSha256: version.sha256,
          current: version.id === concept.currentVersionId,
          status: version.status,
          decision: decision
            ? {
                value: decision.decision,
                reviewerName: decision.reviewer_name,
                updatedAt: decision.updated_at,
              }
            : null,
          comments: comments.map((comment) => ({
            id: comment.id,
            body: comment.body,
            authorName: comment.author_name,
            createdAt: comment.created_at,
          })),
          activity: activityTimestamp(decision, comments),
        };
      });

      revisions.sort((left, right) => {
        if (left.current !== right.current) return left.current ? -1 : 1;
        if (left.activity !== right.activity) return right.activity - left.activity;
        return right.versionId.localeCompare(left.versionId);
      });

      return {
        id: concept.id,
        name: concept.name,
        role: concept.role,
        currentVersionId: concept.currentVersionId,
        revisions: revisions.map((revision) => ({
          versionId: revision.versionId,
          referenceName: revision.referenceName,
          conceptSha256: revision.conceptSha256,
          current: revision.current,
          status: revision.status,
          decision: revision.decision,
          comments: revision.comments,
        })),
      };
    }),
  };
}

function markdownDate(timestamp: number | null): string {
  if (timestamp === null) return "No review activity yet";
  return new Date(timestamp).toISOString().replace("T", " ").replace(".000Z", " UTC");
}

function markdownText(value: string): string {
  return value
    .replace(/\\/g, "\\\\")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

export function reviewExportToMarkdown(reviewExport: ReviewExport): string {
  const lines = [
    "# Gamble Battle Phase II Portal Feedback",
    "",
    `Last portal change: ${markdownDate(reviewExport.changedAt)}`,
    `Source head: \`${reviewExport.sourceHead}\``,
    "",
    "> Read-only offline mirror of the private Phase II review portal. Comments and decisions are bound to the exact named art version.",
    "",
  ];

  for (const unit of reviewExport.units) {
    lines.push(`## ${unit.name}`, "");
    for (const revision of unit.revisions) {
      const currentLabel = revision.current ? " · CURRENT" : "";
      lines.push(`### ${markdownText(revision.referenceName)}${currentLabel}`, "");
      lines.push(
        `- Version ID: \`${revision.versionId}\``,
        `- Art SHA-256: \`${revision.conceptSha256}\``,
        `- Decision: ${
          revision.decision
            ? `${REVIEW_DECISION_LABELS[revision.decision.value]} — ${markdownText(revision.decision.reviewerName)} at ${markdownDate(revision.decision.updatedAt)}`
            : "Not set"
        }`,
        `- Comments: ${revision.comments.length}`,
        "",
      );
      if (revision.comments.length === 0) {
        lines.push("_No comments._", "");
      } else {
        for (const comment of revision.comments) {
          lines.push(
            `**${markdownText(comment.authorName)} · ${markdownDate(comment.createdAt)}**`,
          );
          for (const commentLine of markdownText(comment.body).split("\n")) {
            lines.push(`> ${commentLine}`);
          }
          lines.push("");
        }
      }
    }
  }

  return `${lines.join("\n").trimEnd()}\n`;
}
