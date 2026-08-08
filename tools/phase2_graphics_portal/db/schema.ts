import {
  index,
  integer,
  primaryKey,
  sqliteTable,
  text,
} from "drizzle-orm/sqlite-core";

export const conceptDecisions = sqliteTable(
  "concept_decisions",
  {
    unitId: text("unit_id").notNull(),
    conceptSha256: text("concept_sha256").notNull(),
    decision: text("decision", { enum: ["approve", "needs_work"] }).notNull(),
    reviewerEmail: text("reviewer_email").notNull(),
    reviewerName: text("reviewer_name").notNull(),
    updatedAt: integer("updated_at").notNull(),
  },
  (table) => [
    primaryKey({ columns: [table.unitId, table.conceptSha256] }),
  ],
);

export const conceptComments = sqliteTable(
  "concept_comments",
  {
    id: text("id").primaryKey(),
    unitId: text("unit_id").notNull(),
    conceptSha256: text("concept_sha256").notNull(),
    body: text("body").notNull(),
    authorEmail: text("author_email").notNull(),
    authorName: text("author_name").notNull(),
    createdAt: integer("created_at").notNull(),
  },
  (table) => [
    index("concept_comments_unit_sha_created_idx").on(
      table.unitId,
      table.conceptSha256,
      table.createdAt,
    ),
  ],
);
