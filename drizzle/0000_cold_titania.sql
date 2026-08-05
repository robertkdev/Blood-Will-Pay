CREATE TABLE `concept_comments` (
	`id` text PRIMARY KEY NOT NULL,
	`unit_id` text NOT NULL,
	`concept_sha256` text NOT NULL,
	`body` text NOT NULL,
	`author_email` text NOT NULL,
	`author_name` text NOT NULL,
	`created_at` integer NOT NULL
);
--> statement-breakpoint
CREATE INDEX `concept_comments_unit_sha_created_idx` ON `concept_comments` (`unit_id`,`concept_sha256`,`created_at`);--> statement-breakpoint
CREATE TABLE `concept_decisions` (
	`unit_id` text NOT NULL,
	`concept_sha256` text NOT NULL,
	`decision` text NOT NULL,
	`reviewer_email` text NOT NULL,
	`reviewer_name` text NOT NULL,
	`updated_at` integer NOT NULL,
	PRIMARY KEY(`unit_id`, `concept_sha256`)
);
