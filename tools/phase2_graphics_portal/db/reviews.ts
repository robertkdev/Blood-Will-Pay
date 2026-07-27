import type { ChatGPTUser } from "../app/chatgpt-auth";
import type { ReviewDecision, UnitReview } from "../lib/reviews";

type DecisionRow = {
  decision: ReviewDecision;
  reviewer_name: string;
  updated_at: number;
};

type CommentRow = {
  id: string;
  body: string;
  author_name: string;
  created_at: number;
};

let schemaReady: Promise<void> | null = null;

async function getReviewDatabase(): Promise<D1Database> {
  const { env } = await import("cloudflare:workers");
  if (!env.DB) {
    throw new Error("Review database is unavailable.");
  }
  await ensureReviewSchema(env.DB);
  return env.DB;
}

async function ensureReviewSchema(db: D1Database): Promise<void> {
  if (schemaReady === null) {
    schemaReady = db
      .batch([
        db.prepare(
          `CREATE TABLE IF NOT EXISTS concept_comments (
            id TEXT PRIMARY KEY NOT NULL,
            unit_id TEXT NOT NULL,
            concept_sha256 TEXT NOT NULL,
            body TEXT NOT NULL,
            author_email TEXT NOT NULL,
            author_name TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )`,
        ),
        db.prepare(
          `CREATE INDEX IF NOT EXISTS concept_comments_unit_sha_created_idx
           ON concept_comments (unit_id, concept_sha256, created_at)`,
        ),
        db.prepare(
          `CREATE TABLE IF NOT EXISTS concept_decisions (
            unit_id TEXT NOT NULL,
            concept_sha256 TEXT NOT NULL,
            decision TEXT NOT NULL,
            reviewer_email TEXT NOT NULL,
            reviewer_name TEXT NOT NULL,
            updated_at INTEGER NOT NULL,
            PRIMARY KEY (unit_id, concept_sha256)
          )`,
        ),
      ])
      .then(() => undefined)
      .catch((error: unknown) => {
        schemaReady = null;
        throw error;
      });
  }

  await schemaReady;
}

export async function readUnitReview(
  unitId: string,
  conceptSha256: string,
): Promise<UnitReview> {
  const db = await getReviewDatabase();
  const [decisionResult, commentResult] = await db.batch([
    db
      .prepare(
        `SELECT decision, reviewer_name, updated_at
         FROM concept_decisions
         WHERE unit_id = ?1 AND concept_sha256 = ?2`,
      )
      .bind(unitId, conceptSha256),
    db
      .prepare(
        `SELECT id, body, author_name, created_at
         FROM (
           SELECT id, body, author_name, created_at
           FROM concept_comments
           WHERE unit_id = ?1 AND concept_sha256 = ?2
           ORDER BY created_at DESC, id DESC
           LIMIT 100
         )
         ORDER BY created_at ASC, id ASC`,
      )
      .bind(unitId, conceptSha256),
  ]);

  const decisionRow = decisionResult.results[0] as DecisionRow | undefined;
  const commentRows = commentResult.results as unknown as CommentRow[];

  return {
    unitId,
    conceptSha256,
    decision: decisionRow
      ? {
          value: decisionRow.decision,
          reviewerName: decisionRow.reviewer_name,
          updatedAt: decisionRow.updated_at,
        }
      : null,
    comments: commentRows.map((row) => ({
      id: row.id,
      body: row.body,
      authorName: row.author_name,
      createdAt: row.created_at,
    })),
  };
}

export async function saveUnitDecision(
  unitId: string,
  conceptSha256: string,
  decision: ReviewDecision,
  user: ChatGPTUser,
): Promise<void> {
  const now = Date.now();
  const db = await getReviewDatabase();
  await db
    .prepare(
      `INSERT INTO concept_decisions
        (unit_id, concept_sha256, decision, reviewer_email, reviewer_name, updated_at)
       VALUES (?1, ?2, ?3, ?4, ?5, ?6)
       ON CONFLICT(unit_id, concept_sha256) DO UPDATE SET
         decision = excluded.decision,
         reviewer_email = excluded.reviewer_email,
         reviewer_name = excluded.reviewer_name,
         updated_at = excluded.updated_at`,
    )
    .bind(
      unitId,
      conceptSha256,
      decision,
      user.email,
      user.displayName,
      now,
    )
    .run();
}

export async function addUnitComment(
  unitId: string,
  conceptSha256: string,
  body: string,
  user: ChatGPTUser,
): Promise<void> {
  const db = await getReviewDatabase();
  await db
    .prepare(
      `INSERT INTO concept_comments
        (id, unit_id, concept_sha256, body, author_email, author_name, created_at)
       VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)`,
    )
    .bind(
      crypto.randomUUID(),
      unitId,
      conceptSha256,
      body,
      user.email,
      user.displayName,
      Date.now(),
    )
    .run();
}
