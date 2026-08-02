from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
DOC_PATH = ROOT / "docs" / "art" / "unit_art_style_workflow.md"
CASES_PATH = ROOT / "docs" / "art" / "unit_art_prompt_cases.json"
TEST_LOG_PATH = ROOT / "docs" / "art" / "unit_art_workflow_test_log_2026-06-29.md"
ROSTER_MATRIX_PATH = ROOT / "docs" / "art" / "unit_art_roster_prompt_matrix.json"
PROOF_MATRIX_PATH = ROOT / "docs" / "art" / "unit_art_proof_matrix.json"
REVIEW_DECISION_HELPER_PATH = ROOT / "tools" / "art" / "apply_unit_art_review_decision.py"
CUTOUT_FRINGE_AUDIT_BUILDER_PATH = ROOT / "tools" / "art" / "audit_unit_cutout_orange_fringe.py"
CUTOUT_EDGE_CLEANER_PATH = ROOT / "tools" / "art" / "clean_unit_cutout_orange_edge.py"
ROSTER_PACKET_BUILDER_PATH = ROOT / "tools" / "art" / "build_unit_roster_prompt_packet.py"
STYLE_DRIFT_BUILDER_PATH = ROOT / "tools" / "art" / "build_unit_style_drift_audit.py"
CANDIDATE_TRIAGE_PATH = ROOT / "docs" / "art" / "unit_art_candidate_style_triage_2026-07-01.md"
CANDIDATE_TRIAGE_BUILDER_PATH = ROOT / "tools" / "art" / "build_unit_art_candidate_triage.py"
QUICK_AUDIT_GATE_PATH = ROOT / "tools" / "art" / "check_unit_art_audit_gates.py"
CUTOUT_FRINGE_AUDIT_PATH = ROOT / "docs" / "art" / "unit_art_cutout_orange_fringe_audit_2026-07-01.md"
REVIEW_PACKET_PATH = ROOT / "docs" / "art" / "creep_review_decision_packet_2026-07-01.md"
REVIEW_PACKET_BUILDER_PATH = ROOT / "tools" / "art" / "build_unit_art_review_packet.py"
SOURCE_IDENTITY_SHEET_BUILDER_PATH = ROOT / "tools" / "art" / "build_unit_art_source_identity_sheet.py"
REVIEW_QUEUE_BUILDER_PATH = ROOT / "tools" / "art" / "build_unit_art_review_queue.py"
COMPLETION_AUDIT_BUILDER_PATH = ROOT / "tools" / "art" / "build_unit_art_workflow_completion_audit.py"
WORKFLOW_RUNNER_PATH = ROOT / "tools" / "art" / "run_unit_art_workflow_validation.py"
STYLE_DRIFT_AUDIT_PATH = ROOT / "docs" / "art" / "unit_art_style_drift_audit_2026-06-30.md"
COMPLETION_AUDIT_PATH = ROOT / "docs" / "art" / "unit_art_workflow_completion_audit_2026-06-30.md"
REVIEW_QUEUE_PATH = ROOT / "docs" / "art" / "unit_art_review_queue_2026-06-30.md"
FUTURE_AGENT_HANDOFF_PATH = ROOT / "docs" / "art" / "unit_art_future_agent_handoff.md"
CREEP_REVISION_PROMPT_PACKET_PATH = ROOT / "docs" / "art" / "creep_revision_prompt_packet_2026_07_01" / "creep.md"

REQUIRED_DOC_SNIPPETS = [
    "Current Best Anchor",
    "Locked Art Target",
    "Prompt Contract",
    "Background Removal Decision Tree",
    "Acceptance Checklist",
    "Future Agent Quick Start",
    "vellum_10pct_real_deshine_selected_raw.png",
    "--foreground-ml --despill-orange",
    "flat solid safety-orange #f84401",
    "Do not replace `assets/units/*.png`",
    "unit_art_workflow_test_log_2026-06-29.md",
    "unit_art_roster_prompt_matrix.json",
    "build_unit_roster_prompt_packet.py",
    "apply_unit_art_review_decision.py",
    "build_unit_style_drift_audit.py",
    "build_unit_art_candidate_triage.py",
    "check_unit_art_audit_gates.py",
    "build_unit_art_review_packet.py",
    "build_unit_art_source_identity_sheet.py",
    "build_unit_art_review_queue.py",
    "build_unit_art_workflow_completion_audit.py",
    "audit_unit_cutout_orange_fringe.py",
    "clean_unit_cutout_orange_edge.py",
    "run_unit_art_workflow_validation.py",
    "End-to-End Validation",
    "unit_art_proof_matrix.json",
    "proof ledger",
    "Hard Matte Gothic Gate",
    "Creep is the current horror-side research example, not a final style anchor",
    "smooth oval alien face",
    "real planned unit",
    "unit_art_style_drift_audit_2026-06-30.md",
    "unit_art_candidate_style_triage_2026-07-01.md",
    "unit_art_cutout_orange_fringe_audit_2026-07-01.md",
    "creep_review_decision_packet_2026-07-01.md",
    "creep_review_decision_packet_2026-07-01_scorecard_template.json",
    "unit_art_future_agent_handoff.md",
    "less shine is not the same as less detail",
    "Vellum is the primary/ultimate style anchor",
    "do not average all passing images together",
    "Every future candidate must be checked side by side against Vellum first",
    "prompt_context_status",
    "blocked_*",
    "Vellum-first side-by-side comparison",
    "reference-ladder sheet",
    "--scorecard-json",
    "Vellum can veto any candidate",
    "they cannot rescue a candidate that is weaker than Vellum",
    "--edge-orange-clean",
    "orange-fringe audit",
    "Cutout cleanliness is not judged against Vellum",
    "if one exists and is not blocked by `prompt_context_status`",
    "hot-highlight/luma proxies",
    "possible sheen, pale-material glare, or board-scale hot spots",
    "synthetic edge-clean regression",
    "raw-key internal-hole regression",
    "visual background-fringe control",
    "--raw-source <raw.png>",
    "raw_key_visible_pixels == 0",
    "visual_fringe_pixels == 0",
    "A cutout-only strict pass is not a perfect exit",
    "raw_key_alpha_cleared_pixels",
    "visual_fringe_alpha_cleared_pixels",
    "remaining_raw_key_visible_pixels",
    "remaining_visual_fringe_pixels",
    "intentional interior orange material",
    "Fast brutal gate",
    "non-rejected cutout contamination fails",
    "Vellum-first pairwise/reference-ladder sheets must exist and be nonblank",
    "metrics CSV must keep Vellum/Paisley/token as the only anchor rows",
]

REQUIRED_STYLE_DRIFT_AUDIT_SNIPPETS = [
    "high-detail matte gothic rendering",
    "Vellum and Paisley",
    "The drift came from treating \"matte\" as lower-detail smoothness",
    "Creep Reassessment",
    "rejected as the current best style proof",
    "de-shining must preserve high-detail dry rendering",
    "Vellum is the ultimate character style reference",
    "Do not average the passing pool into the target style",
    "Vellum-first pairwise comparison sheet",
]

REQUIRED_COMPLETION_AUDIT_SNIPPETS = [
    "Unit Art Workflow Completion Audit",
    "Verdict: **INCOMPLETE**",
    "candidate needs human approval",
    "style negative control, must fail audit",
    "Expected style negative controls are not candidates for approval",
    "needs visual proof",
    "current candidates, not accepted proofs",
    "coverage gaps remain",
    "next recommended stress test remains `creep`",
    "Revise Creep before Veyra or broader roster work",
]

REQUIRED_CANDIDATE_TRIAGE_SNIPPETS = [
    "Unit Art Candidate Style Triage",
    "Vellum is the ultimate character reference",
    "Passing-pool rule",
    "Visual review sheet",
    "Style negative-control sheet",
    "Required Style Negative Controls",
    "Totem is the current required negative control",
    "Human Negative-Control Failures",
    "Metric False-Positive Controls",
    "Metric false-positive controls are required failures",
    "Totem",
    "Hot-Highlight Matte Review",
    "Hot-highlight matte-review rows",
    "hot_highlight_matte_review",
    "style_audit_failed_negative_control",
    "metric_false_positive_style_sentinel",
    "Highest Risk Rows",
    "Prompt-Context Quarantine",
    "Prompt-context quarantine is the machine-readable guardrail",
    "Small-asset context rows are not character palette references",
    "small_asset_context_only_not_character_palette",
    "blocked_until_vellum_pairwise_review",
    "Grint",
    "high_risk_re_review_before_acceptance",
    "Start visual review from the Vellum pairwise sheet",
    "candidate_style_triage_review_sheet.png",
    "style_negative_control_review_sheet.png",
]

REQUIRED_CUTOUT_FRINGE_AUDIT_SNIPPETS = [
    "Unit Art Cutout Orange-Fringe Audit",
    "Objective Background-Contamination Gate",
    "does not compare to Vellum, Paisley, the token, or any other reference image",
    "cutout-only mode reads only each cutout's RGBA pixels",
    "Perfect-exit claims must use raw-backed mode",
    "Manifest:",
    "Manifest rule",
    "Protected ledger rows flagged: `0`",
    "Current candidates that fail can stay in the ledger as review candidates",
    "unit_art_cutout_orange_fringe_review_sheet.png",
]

REQUIRED_REVIEW_PACKET_SNIPPETS = [
    "Review Decision Packet",
    "Visual decision sheet",
    "Board-scale decision sheet",
    "Creep is the next revision gate",
    "Active revision request",
    "Revision prompt packet",
    "creep_revision_prompt_packet_2026_07_01/creep.md",
    "Latest scorecard",
    "Approve only if",
    "Vellum-First Scoring Contract",
    "Decision Scorecard",
    "Scorecard rule",
    "Scorecard template",
    "Human Reply Contract",
    "weaker than Vellum",
    "Reference ladder audit",
    "orange-fringe audit",
    "--scorecard-json",
    "request_revision",
    "Prior Creep Lessons",
]

REQUIRED_REVIEW_QUEUE_SNIPPETS = [
    "Unit Art Review Queue",
    "Current candidates needing review",
    "Next gate unit: `creep`",
    "Creep (`creep`)",
    "creep_vellum_primary_detail_refit",
    "approve as accepted proof, reject with reason, or request revision",
    "Expected style negative controls are non-approvable",
    "style_negative_control",
    "must fail style audit and cannot be accepted",
    "Do not continue to Veyra or broader roster generation",
    "Approval Checklist",
    "Rejection Checklist",
    "too glossy or sweaty",
    "too low-detail or smooth after de-shining",
    "orange-fringe audit",
    "Do not let the growing passing pool muddy the target",
    "Vellum pairwise audit",
    "Reference ladder audit",
    "creep_review_decision_packet_2026-07-01.md",
    "apply_unit_art_review_decision.py",
    "--decision request_revision",
    "--scorecard-json",
    "Scorecard template",
    "creep_review_decision_packet_2026-07-01_scorecard_template.json",
    "Active revision request",
    "Revision prompt packet",
    "creep_revision_prompt_packet_2026_07_01/creep.md",
    "revise before approval",
]

REQUIRED_FUTURE_AGENT_HANDOFF_SNIPPETS = [
    "Blood Will Pay Unit Art Future Agent Handoff",
    "The larger art-workflow goal is active, not complete",
    "Vellum is the only primary/ultimate character style anchor",
    "Every serious candidate must also get a Vellum-first pairwise audit sheet",
    "prompt_context_status",
    "Grint is accepted as narrow proof history but currently blocked from prompt influence",
    "reference-ladder sheet",
    "Do not generate Veyra or broader roster batches",
    "Do not replace any live `assets/units/*.png` file",
    "Board-scale decision sheet",
    "Vellum can veto any candidate",
    "Later proofs can answer only narrow risk questions",
    "Matte does not mean low-detail",
    "reference_role",
    "Current Next Gate",
    "creep_vellum_primary_detail_refit_2026_06_30",
    "Standard Validation Command",
    "run_unit_art_workflow_validation.py",
    "apply_unit_art_review_decision.py",
    "audit_unit_cutout_orange_fringe.py",
    "unit_art_candidate_style_triage_2026-07-01.md",
    "unit_art_cutout_orange_fringe_audit_2026-07-01.md",
    "objective safety-orange background-contamination gate",
    "do not compare cutout cleanliness to Vellum",
    "reference-free standalone cutout audit",
    "creep_review_decision_packet_2026-07-01.md",
    "creep_review_decision_packet_2026-07-01_scorecard_template.json",
    "creep_revision_prompt_packet_2026_07_01/creep.md",
    "--scorecard-json",
    "RoleMatrixProbe.tscn",
    "Completion Standard",
    "segmented armor tendrils",
    "mechanical black tube tendrils",
]

REQUIRED_CREEP_REVISION_PROMPT_PACKET_SNIPPETS = [
    "Unit Roster Prompt Packet - Creep",
    "Revision lock",
    "original source sprite",
    "Creep Vellum-primary candidate only as a negative comparison",
    "smooth oval face",
    "uninterrupted gray-blue skin",
    "unsegmented tendril/blade ring",
    "surface weathering rather than armor clutter",
    "surface weathering, not armor clutter",
    "segmented mechanical tube tendrils",
    "segmented armor tendrils",
    "mechanical black tube tendrils",
    "talisman clutter as fake detail",
    "Paisley only as secondary contrast context",
    "low-detail smooth creature model",
    "--edge-orange-clean",
    "Vellum-level dry detail richness",
]

REQUIRED_PACKET_BUILDER_SNIPPETS = [
    "high-detail matte gothic illustration",
    "layered fabric, parchment, and dry edge wear",
    "hand-painted surface breakup",
    "Vellum-level dry detail richness",
    "Paisley as secondary contrast context only",
    "Detail-richness rule: de-shining must preserve tactile dry detail",
    "palette-only match",
    "Raw image matches Vellum-level dry detail richness",
    "edge-orange-clean",
    "orange-fringe audit",
    "reviewed side by side against the primary Vellum anchor first",
    "do not dilute or average away the Vellum target",
    "Vellum veto rule",
    "Reference Hierarchy",
    "reference_policy",
    "Promotion rule",
    "Current candidates are review-only",
    "Side-by-side rule",
    "Passing-pool rule",
    "Small-asset rule",
    "warmer parchment palette",
    "Prompt-context rule",
    "Unit Proof Context",
    "proof_prompt_context_status",
    "Do not use as prompt/style context",
    "Same-unit identity/process history only",
    "Identity/process-history raw, not a style reference",
    "small_asset_context_only_not_character_palette",
    "orange-fringe audit",
]

REQUIRED_STYLE_DRIFT_BUILDER_SNIPPETS = [
    "REF Vellum raw",
    "REF Paisley",
    "REF Token",
    "candidate_entry",
    "--candidate-raw",
    "pre-ledger candidate",
    "Vellum = primary/ultimate",
    "later proofs are narrow coverage",
    "reference_role",
    "ledger reference_role",
    "foreground_detail_metrics.csv",
    "p99_luma",
    "bright_pixel_ratio",
    "hot_highlight_ratio",
    "Hot-highlight ratios flag possible sheen",
    "visual audit decides",
    "Mandatory Vellum-first side-by-side audit",
    "vellum_first_pairwise_raw_comparison.png",
    "reference_ladder_raw_comparison.png",
    "Vellum can veto",
    "cannot rescue weaker candidates",
    "passing proofs are narrow comparisons",
]

REQUIRED_WORKFLOW_RUNNER_SNIPPETS = [
    "validate_unit_art_workflow_doc.py",
    "apply_unit_art_review_decision.py",
    "build_unit_art_review_queue.py",
    "build_unit_art_candidate_triage.py",
    "check_unit_art_audit_gates.py",
    "audit_unit_cutout_orange_fringe.py",
    "clean_unit_cutout_orange_edge.py",
    "build_unit_art_review_packet.py",
    "build_unit_art_source_identity_sheet.py",
    "build_unit_art_workflow_completion_audit.py",
    "build_unit_roster_prompt_packet.py",
    "build_unit_style_drift_audit.py",
    "reference_role",
    "Workflow Document Validator",
    "Full Roster Prompt Packet Build",
    "Grint prompt packet carries its prompt-context quarantine",
    "Accepted same-unit proof raws are labeled identity/process history",
    "Paisley remains secondary reference context",
    "All Current Style Drift Audit",
    "Focused Proof Style Drift Audit",
    "Pre-Ledger Candidate Style Audit Dry Run",
    "--candidate-raw",
    "validation_preledger_candidate",
    "Workflow Completion Audit",
    "Review Queue",
    "Review Decision Packet",
    "Source Identity Review Sheet",
    "Creep Revision Prompt Packet",
    "assert_creep_revision_prompt_packet",
    "assert_source_identity_sheet",
    "Review Decision Helper Dry Run",
    "Review Decision Helper Accept Scorecard Dry Run",
    "Review Decision Helper Missing Scorecard Guard",
    "Review Decision Helper Style Negative-Control Guard",
    "style negative control",
    "accept without scorecard unexpectedly passed",
    "unexpectedly accepted",
    "write_all_pass_scorecard",
    "--scorecard-json",
    "Candidate Style Triage",
    "Totem remains a metric false-positive sentinel",
    "Hot-highlight proxy flags bright/pale-material rows for matte visual review",
    "Token remains small-asset context only",
    "prompt_context_status",
    "accepted risky proofs are not prompt-context quarantined",
    "Grint is not quarantined from prompt context",
    "Cutout Orange-Fringe Audit",
    "CUTOUT_AUDIT_THRESHOLDS",
    "Synthetic Cutout Orange-Fringe Negative Control",
    "synthetic orange-fringe negative control",
    "edge cleaner removes synthetic safety-orange edge/soft-alpha contamination",
    "edge-cleaner pixel delta is limited to safety-orange alpha-edge/soft-alpha targets",
    "edge_clean_delta_stats",
    "assert_edge_clean_delta_contract",
    "assert_cleaner_stats_json",
    "parse_cleaner_delta_stdout",
    "edge-cleaner stats JSON records the cutout-only/no-reference contract",
    "edge-cleaner stats JSON path provenance matches the audited input, output, review image, and stats file",
    "edge-cleaner stats JSON file hashes match the audited input, output, and review image bytes",
    "cleaned_safety_orange_pixels",
    "file_sha256",
    "input_sha256",
    "output_sha256",
    "review_output_sha256",
    "edge-cleaner default stats-output path is exercised",
    "synthetic cleaned cutout audit reruns with strict-zero thresholds",
    "Strict-Zero Cutout Gate",
    "default-threshold audit passes a one-pixel edge-orange residue control",
    "strict-zero audit fails the same one-pixel edge-orange residue control",
    "Raw-Key Background-Hole Gate",
    "cutout-only strict-zero audit passes a recolored raw-key hole",
    "raw-backed audit fails the same cutout for visible reserved background-key pixels",
    "raw-backed cleaner clears the measured background-key alpha leak",
    "Proof-Matrix Raw-Source Gate",
    "proof-matrix raw-source audit fails an internal raw-key hole through --use-proof-raw-source",
    "proof-matrix raw-source cleaner stats JSON records raw-source hashes, stdout parity, and pixel delta",
    "cleaned proof-matrix raw-source audit passes with strict-zero raw-key thresholds",
    "proof-matrix raw-source review sheets are nonblank",
    "stats_output_path",
    "changed_outside_target_pixels",
    "changed_outside_edge_pixels",
    "changed_opaque_interior_pixels",
    "changed_alpha_pixels",
    "remaining_edge_orange_pixels",
    "remaining_soft_orange_pixels",
    "intentional interior orange material",
    "assert_alpha_unchanged",
    "count_safety_orange_pixels_in_box",
    "Quick Unit Art Audit Gates",
    "check_unit_art_audit_gates.py",
    "non-rejected cutouts have no objective safety-orange edge/soft-alpha contamination",
    "edge-orange 51-pixel threshold control fails exactly one pixel over the limit",
    "edge-orange ratio threshold control fails even below the pixel-count limit",
    "soft-alpha 21-pixel threshold control fails exactly one pixel over the limit",
    "Godot Validation",
    "Vellum Pairwise Audit Output",
    "reference_ladder_raw_comparison.png",
    "PASS: art workflow docs",
]

REQUIRED_SOURCE_IDENTITY_SHEET_BUILDER_SNIPPETS = [
    "Build a source identity vs Vellum vs candidate review sheet",
    "source identity, not passing style proof",
    "Vellum ultimate reference",
    "material/detail authority",
    "board-scale identity read",
    "Decision rule: do not promote",
    "the original source stays the identity reference",
    "--source-image",
    "--candidate",
    "--fallback",
    "--board-sizes",
]

REQUIRED_REVIEW_DECISION_HELPER_SNIPPETS = [
    "VALID_DECISIONS",
    "SCORECARD_GATES",
    "scorecard-gate",
    "scorecard-json",
    "load_scorecard_json",
    "merge_scorecards",
    "accept requires every scorecard gate to be pass",
    "style_negative_control",
    "cannot be accepted",
    "request_revision",
    "current_candidate",
    "review_candidate_not_anchor",
    "negative_example",
    "review helper does not promote proofs into global style anchors",
    "dry_run=true",
]

REQUIRED_CANDIDATE_TRIAGE_BUILDER_SNIPPETS = [
    "Vellum is the ultimate character reference",
    "Passing-pool rule",
    "style_audit_override",
    "style_negative_control",
    "REQUIRED_STYLE_NEGATIVE_CONTROLS",
    "validate_required_negative_control_policy",
    "--proof-matrix",
    "required style negative control missing from proof matrix",
    "required style negative control must be explicit style_negative_control=true",
    "required style negative control must declare style_audit_override verdict=fail",
    "required style negative control must include style_audit_override reason",
    "enforce_negative_controls",
    "required_style_negative_control",
    "human_style_fail_negative_control",
    "style_audit_failed_negative_control",
    "metric_false_positive_control",
    "metric_false_positive_controls",
    "metric_false_positive_style_sentinel",
    "hot_highlight_review_rows",
    "hot_highlight_matte_review",
    "Hot-Highlight Matte Review",
    "prompt_context_status",
    "small_asset_context_only_not_character_palette",
    "prompt_context_quarantine_rows",
    "blocked_until_vellum_pairwise_review",
    "Prompt-Context Quarantine",
    "high_risk_re_review_before_acceptance",
    "Start visual review from the Vellum pairwise sheet",
    "edge_detail_far_below_paisley",
    "candidate_style_triage_review_sheet.png",
    "write_visual_review_sheet",
    "style_negative_control_review_sheet.png",
    "write_negative_control_sheet",
    "Required Style Negative Controls: Vellum First",
    "Small asset only, not unit palette",
]

REQUIRED_CUTOUT_FRINGE_AUDIT_BUILDER_SNIPPETS = [
    "Unit Art Cutout Orange-Fringe Audit",
    "Objective Background-Contamination Gate",
    "does not compare to Vellum, Paisley, the token, or any other reference image",
    "safety_orange_residue",
    "background_key_residue",
    "background_residue_masks",
    "visual_background_fringe_contamination",
    "visual_fringe_pixels",
    "alpha_edge_band",
    "edge_background_orange_contamination",
    "raw_key_visible_background_contamination",
    "write_manifest",
    "audit_input_contract",
    "cutout_rgba_pixels_only",
    "cutout_rgba_plus_raw_background_key_pixels_plus_visual_background_fringe",
    "reference_images_loaded",
    "raw_images_loaded",
    "board_preview_images_loaded",
    "style_anchor_images_loaded",
    "proof_matrix_loaded_for_cutout_paths",
    "--cutout",
    "--raw-source",
    "--use-proof-raw-source",
    "raw_key_visible_pixels",
    "visual_blue_fringe_pixels",
    "--no-include-proof-matrix",
    "standalone_cutout",
    "unit_art_cutout_orange_fringe_review_sheet.png",
    "Protected ledger rows flagged",
    "fail-on-accepted-fail",
]

REQUIRED_CUTOUT_EDGE_CLEANER_SNIPPETS = [
    "clean_edge_orange",
    "edge_clean_delta_stats",
    "edge_clean_delta_contract_errors",
    "assert_edge_clean_delta_contract",
    "edge_clean_stats_payload",
    "file_sha256",
    "input_sha256",
    "output_sha256",
    "review_output_sha256",
    "write_stats_json",
    "stats_output_path",
    "safety_orange_residue",
    "alpha_edge_band",
    "cleanup_target_mask",
    "raw_background_key_target_mask",
    "visual_background_fringe_target_mask",
    "background_alpha_target_masks",
    "clean_cutout_background",
    "cleaned_safety_orange_pixels",
    "cleaned_edge_orange_pixels",
    "raw_key_alpha_cleared_pixels",
    "visual_fringe_alpha_cleared_pixels",
    "changed_alpha_pixels",
    "changed_outside_target_pixels",
    "changed_outside_edge_pixels",
    "changed_opaque_interior_pixels",
    "remaining_edge_orange_pixels",
    "remaining_soft_orange_pixels",
    "remaining_raw_key_visible_pixels",
    "remaining_visual_fringe_pixels",
    "changed_alpha_outside_background_target_pixels",
    "changed_opaque_interior_outside_background_target_pixels",
    "Unit cutout safety-orange post-clean review",
]

REQUIRED_QUICK_AUDIT_GATE_SNIPPETS = [
    "Quick Unit Art Audit Gates",
    "non-rejected cutouts have no objective safety-orange edge/soft-alpha contamination",
    "assert_reference_free_manifest",
    "CUTOUT_AUDIT_THRESHOLDS",
    "current cutout audit manifest",
    "proves reference-free cutout-only input contract",
    "current cutout orange-fringe review sheet exists and is nonblank",
    "Objective Cutout Self-Test Matrix",
    "cutout self-test matrix manifest",
    "write_cutout_self_test_images",
    "write_strict_zero_single_pixel_control",
    "assert_strict_zero_cutout_gate",
    "write_raw_key_hole_control",
    "write_visual_background_fringe_control",
    "assert_visual_background_fringe_gate",
    "assert_raw_key_hole_gate",
    "write_raw_key_hole_proof_matrix",
    "assert_proof_matrix_raw_source_gate",
    "assert_raw_backed_cutout_manifest",
    "clean_cutout_control",
    "interior_orange_material_control",
    "edge_orange_contamination_control",
    "soft_alpha_orange_halo_control",
    "edge_orange_51_pixel_threshold_control",
    "edge_orange_ratio_threshold_control",
    "soft_alpha_21_pixel_threshold_control",
    "intentional interior orange material control passes",
    "cutout self-test matrix review sheet exists and is nonblank",
    "soft-alpha safety-orange halo control fails",
    "edge-orange 51-pixel threshold control fails exactly one pixel over the limit",
    "edge-orange ratio threshold control fails even below the pixel-count limit",
    "soft-alpha 21-pixel threshold control fails exactly one pixel over the limit",
    "Synthetic Edge-Clean Regression",
    "Synthetic Raw-Key Internal-Hole Regression",
    "write_raw_key_hole_control",
    "assert_synthetic_raw_key_hole_clean",
    "assert_raw_backed_cutout_manifest",
    "parse_cleaner_delta_stdout",
    "assert_cleaner_stats_json",
    "edge cleaner stats JSON records the cutout-only/no-reference contract",
    "edge cleaner stats JSON path provenance matches the audited input, output, review image, and stats file",
    "edge cleaner stats JSON file hashes match the audited input, output, and review image bytes",
    "cleaned_safety_orange_pixels",
    "edge cleaner default stats-output path is exercised",
    "synthetic cleaned cutout audit reruns with strict-zero thresholds",
    "Strict-Zero Cutout Gate",
    "default-threshold audit passes a one-pixel edge-orange residue control",
    "strict-zero audit fails the same one-pixel edge-orange residue control",
    "Visual Background-Fringe Gate",
    "visual_background_fringe_contamination",
    "visual-fringe cleaner alpha-clears measured blue/orange background-field residue",
    "visual-fringe cleaned cutout reruns with strict-zero visual-fringe thresholds",
    "visual-fringe review sheets are nonblank",
    "Raw-Key Background-Hole Gate",
    "cutout-only strict-zero audit passes a recolored raw-key hole",
    "raw-backed audit fails the same cutout for visible reserved background-key pixels",
    "raw-backed cleaner clears the measured background-key alpha leak",
    "synthetic contaminated cutout audit manifest",
    "synthetic cleaned cutout audit manifest",
    "synthetic edge-clean review sheets exist and are nonblank",
    "edge cleaner pixel delta is limited to safety-orange alpha-edge/soft-alpha targets",
    "cutout-only strict audit reproduces the old blind spot on an opaque internal raw-key hole",
    "raw-backed strict audit fails that same internal-hole control with raw_key_visible_background_contamination",
    "raw-backed cleaner alpha-clears the raw-key internal hole while preserving non-key intentional orange material",
    "raw-backed cleaned cutout reruns with strict-zero raw-key thresholds",
    "Proof-Matrix Raw-Source Gate",
    "proof-matrix raw-source audit fails an internal raw-key hole through --use-proof-raw-source",
    "proof-matrix raw-source cleaner stats JSON records raw-source hashes, stdout parity, and pixel delta",
    "cleaned proof-matrix raw-source audit passes with strict-zero raw-key thresholds",
    "proof-matrix raw-source review sheets are nonblank",
    "changed_alpha_pixels",
    "changed_outside_target_pixels",
    "changed_outside_edge_pixels",
    "changed_opaque_interior_pixels",
    "flagged=1",
    "flagged=0",
    "intentional interior orange material",
    "Totem fails style triage while still proving proxy metrics can lie",
    "Token remains small-asset-only context",
    "hot-highlight matte-review rows present",
    "find_latest_metrics_csv",
    "Vellum-First Visual Evidence Gate",
    "Metrics Reference Hierarchy Gate",
    "REFERENCE_ROLE_EXPECTATIONS",
    "ANCHOR_ROLES",
    "assert_metrics_reference_hierarchy",
    "assert_tampered_metrics_negative_controls",
    "Tampered Metrics Negative-Control Gate",
    "Tampered Proof-Matrix Negative-Control Gate",
    "assert_tampered_proof_matrix_negative_controls",
    "proof_matrix_copy_with_totem_mutation",
    "expect_tampered_proof_matrix_failure",
    "bad_reference_order",
    "duplicate_vellum_reference",
    "wrong_token_anchor_role",
    "extra_ref_anchor_role",
    "ordinary_row_anchor_role",
    "missing_totem_negative_control",
    "totem_low_proxy_metrics",
    "missing_totem_proof",
    "totem_negative_control_flag_removed",
    "totem_verdict_promoted_to_pass",
    "totem_override_reason_removed",
    "missing Totem metrics row fails required negative-control enforcement",
    "Totem low-proxy metric mutation",
    "tampered proof-matrix controls prove Totem source-policy corruption fails before style report generation",
    "REF Vellum raw",
    "REF Paisley",
    "REF Token",
    "only locked reference rows can use anchor roles",
    "STYLE_AUDIT_SHEETS",
    "assert_nonblank_image",
    "vellum_first_pairwise_raw_comparison.png",
    "reference_ladder_raw_comparison.png",
    "triage_width",
    "triage_height",
]

REQUIRED_REVIEW_PACKET_BUILDER_SNIPPETS = [
    "Review Decision Packet",
    "CREEP_REVISION_PROMPT_PACKET",
    "Creep is the next human-review gate",
    "Creep is the next revision gate",
    "Active revision request",
    "Revision prompt packet",
    "revision_prompt_packet",
    "Latest scorecard",
    "format_latest_scorecard",
    "Prior Creep Lessons",
    "Board-Scale Decision Sheet",
    "Board-scale decision sheet",
    "Decision Scorecard",
    "Scorecard rule",
    "Vellum-First Scoring Contract",
    "Human Reply Contract",
    "later passing proofs cannot average away the target",
    "Reference ladder audit",
    "orange-fringe audit",
    "Scorecard template",
    "write_scorecard_template",
    "write_visual_packet",
    "Visual decision sheet",
]

REQUIRED_REVIEW_QUEUE_BUILDER_SNIPPETS = [
    "current_candidate",
    "style_negative_control",
    "Expected style negative controls are non-approvable",
    "must fail style audit and cannot be accepted",
    "CREEP_REVISION_PROMPT_PACKET",
    "next_gate",
    "review_candidate_not_anchor",
    "Active revision request",
    "Revision prompt packet",
    "revision_prompt_packet",
    "revise before approval",
    "approve as accepted proof",
    "Rejection needs a concrete reason",
    "apply_unit_art_review_decision.py",
    "--scorecard-json",
    "--decision accept",
    "--decision reject",
    "--decision request_revision",
    "Do not continue to Veyra or broader roster generation",
    "Approval Checklist",
    "Rejection Checklist",
    "Do not let the growing passing pool muddy the target",
    "orange-fringe audit",
    "Vellum pairwise audit",
    "Reference ladder audit",
    "creep_review_decision_packet_2026-07-01.md",
    "creep_review_decision_packet_2026-07-01_scorecard_template.json",
]

REQUIRED_COMPLETION_BUILDER_SNIPPETS = [
    "verdict = \"INCOMPLETE\"",
    "candidate needs human approval",
    "style negative control, must fail audit",
    "Expected style negative controls are not candidates for approval",
    "needs visual proof",
    "coverage_gaps",
    "next_recommended_stress_test",
    "current_candidate",
    "accepted proof",
]

REQUIRED_PROOF_MATRIX_SNIPPETS = [
    "high-detail matte gothic illustration",
    "Vellum-level dry detail richness",
    "Paisley as secondary contrast context only",
    "layered fabric/parchment/dry edge wear",
    "hand-painted surface breakup",
    "style_audit_override",
    "style_negative_control",
    "user says Totem should fail",
    "--edge-orange-clean",
    "orange-fringe audit",
    "reference_policy",
    "scorecard_template",
    "promotion_rule",
    "reference_role",
    "low-detail smooth creature model",
    "palette-only match",
    "Vellum is the primary and ultimate character style anchor",
    "Later accepted/current proofs are narrow coverage examples",
    "side_by_side_rule",
    "veto_rule",
    "passing_pool_rule",
    "prompt_context_rule",
    "small_asset_rule",
    "warmer parchment palette",
    "prompt_context_status",
    "blocked_until_vellum_pairwise_review",
]

REQUIRED_TEST_LOG_SNIPPETS = [
    "Kythera Mummy Goth Refit",
    "Vellum Contract-Mark Ability Token",
    "Paisley Gothic Bubble Refit",
    "BiRefNet preserved the body but dropped detached bubbles",
    "exactly two large smoky ink-orb bubbles",
    "ability_token_contract_mark_raw_selected.png",
    "paisley_goth_bubble_refit_raw_selected.png",
    "kythera_mummy_goth_refit_raw.png",
    "Creep Planned Unit Horror Refit",
    "creep_unit_refit_raw.png",
    "Google design doc lists Creep",
    "Creep Smooth Alien Matte Refit",
    "creep_smooth_alien_refit_raw_selected.png",
    "smooth uninterrupted alien skin",
    "Creep Hard Matte Smooth Alien Refit",
    "creep_hard_matte_smooth_alien_refit_raw_selected.png",
    "message `102`",
    "Creep Smooth Alien Matte Match Refit",
    "creep_smooth_alien_matte_match_refit_raw_selected.png",
    "ribbed/slick",
    "message `117`",
    "Creep Vellum-Primary Detail Refit",
    "creep_vellum_primary_detail_refit_raw_selected.png",
    "Vellum-first audit sheet",
    "message `118`",
    "message `119`",
    "32.65",
    "Grint Tank Weapon Refit",
    "grint_tank_weapon_refit_raw.png",
    "Grint Hard Matte Refit",
    "grint_hard_matte_refit_raw_selected.png",
    "message `96`",
    "Korath Haloed Tank Matte Refit",
    "korath_haloed_tank_refit_raw_selected.png",
    "mathematically perfect flat key",
    "Luna Bright Caster Matte Refit",
    "luna_bright_caster_refit_raw_selected.png",
    "message `98`",
    "Morrak Polearm Executioner Matte Refit",
    "morrak_polearm_executioner_refit_raw_selected.png",
    "mounted-rider/horse drift",
    "message `99`",
    "Teller Contract Mogul Matte Refit",
    "teller_contract_mogul_refit_raw_selected.png",
    "glossy formalwear",
    "message `100`",
    "Bo Large Brute Matte Refit",
    "bo_large_brute_refit_raw_selected.png",
    "wet monster skin",
    "message `103`",
    "Axiom Compact Scholar Matte Refit",
    "axiom_compact_scholar_refit_raw_selected.png",
    "glossy feathers",
    "message `104`",
    "Volt Attached Energy Matte Refit",
    "volt_attached_energy_refit_raw_selected.png",
    "detached particle confetti",
    "message `105`",
    "Vykos Pale Sanguine Matte Refit",
    "vykos_pale_sanguine_refit_raw_selected.png",
    "shiny anatomy",
    "message `106`",
    "Brute Guardian Bulk Matte Refit",
    "brute_guardian_bulk_refit_raw_selected.png",
    "orange-clean post-pass",
    "message `107`",
    "Bonko Wiry Raider Matte Refit",
    "bonko_wiry_raider_refit_raw_selected.png",
    "sports-bat read",
    "message `108`",
    "Hexeon Time Blade Matte Refit",
    "hexeon_time_blade_refit_raw_selected.png",
    "glossy/black-latex",
    "message `109`",
    "Totem Dry Wood Guardian Matte Refit",
    "totem_dry_wood_guardian_refit_raw_selected.png",
    "glossy varnished wood",
    "message `110`",
    "Sari Spectral Tendril Matte Refit",
    "sari_spectral_tendril_refit_raw_selected.png",
    "shiny/spaghetti",
    "message `112`",
    "build_unit_roster_prompt_packet.py",
    "unit_art_proof_matrix.json",
]

REQUIRED_POSITIVES = [
    "western dark gothic",
    "10 percent grounded realism",
    "powder-matte",
    "de-shined",
    "flat solid safety-orange #f84401 background",
    "clean readable game-board silhouette",
    "no text, logo, watermark",
    "grim low-sheen gothic realism",
    "rough dry material texture",
    "low-specular ambient light",
    "high-detail matte gothic illustration",
    "layered fabric, parchment, and dry edge wear",
    "hand-painted surface breakup",
    "Vellum-level dry detail richness",
    "Paisley as secondary contrast context only",
]

UNIT_ONLY_POSITIVES = [
    "full-body centered",
    "grounded adult proportions",
]

ASSET_ONLY_POSITIVES = [
    "centered",
]

REQUIRED_NEGATIVES = [
    "sweaty",
    "glossy",
    "shiny",
    "wet",
    "oily",
    "plastic",
    "latex",
    "polished leather",
    "bright specular highlights",
    "polished bevels",
    "smooth airbrushed armor",
    "cartoon",
    "comic-book",
    "toy-like proportions",
    "clean fantasy render",
    "heroic mobile-game lighting",
    "low-detail smooth creature model",
    "over-smoothed simplified matte shapes",
    "palette-only match",
    "anime",
    "gacha",
    "textured background",
    "floor shadow",
    "text",
    "logo",
    "watermark",
]

REQUIRED_CASE_FIELDS = [
    "id",
    "asset_type",
    "source_image",
    "style_reference",
    "output_slug",
    "prompt",
    "negative_prompt",
    "cutout_strategy",
    "acceptance",
]

REQUIRED_ROSTER_FIELDS = [
    "id",
    "display_name",
    "traits",
    "source_image",
    "coverage_group",
    "visual_identity",
    "preserve",
    "avoid_drift",
    "prompt_addendum",
]

REQUIRED_PROOF_FIELDS = [
    "id",
    "subject_type",
    "subject_id",
    "display_name",
    "status",
    "coverage_group",
    "proof_goal",
    "source_image",
    "output_dir",
    "raw",
    "cutout",
    "review",
    "board_preview",
    "style_gate",
    "cutout_gate",
    "decision_notes",
    "reference_role",
]

VALID_PROOF_STATUSES = {"accepted", "current_candidate", "rejected"}
CURRENT_PROOF_STATUSES = {"accepted", "current_candidate"}
VALID_REFERENCE_ROLES = {
    "secondary_contrast_anchor",
    "small_asset_material_reference",
    "narrow_proof_only",
    "review_candidate_not_anchor",
    "negative_example",
}
ANCHOR_REFERENCE_ROLES = {
    "secondary_contrast_anchor",
    "small_asset_material_reference",
}
MINIMUM_CURRENT_PROOF_COVERAGE = {
    "small_narrow",
    "detached_effects",
    "goth_horror_anchor",
    "large_tank",
    "weapon_heavy",
}


def fail(message: str, failures: list[str]) -> None:
    failures.append(message)


def as_text(value: Any) -> str:
    if isinstance(value, str):
        return value
    return json.dumps(value, sort_keys=True)


def check_existing_path(path_text: str | None, field: str, case_id: str, failures: list[str]) -> None:
    if path_text is None:
        return
    path = ROOT / path_text
    if not path.exists():
        fail(f"{case_id}: {field} does not exist: {path_text}", failures)


def resource_has_art_sprite(path: Path) -> bool:
    if not path.exists():
        return False
    text = path.read_text(encoding="utf-8")
    match = re.search(r'^sprite_path\s*=\s*"([^"]*)"', text, re.MULTILINE)
    if not match:
        return False
    sprite_path = match.group(1)
    return sprite_path.startswith("res://assets/")


def main() -> int:
    failures: list[str] = []

    if not DOC_PATH.exists():
        fail(f"Missing workflow doc: {DOC_PATH}", failures)
    if not CASES_PATH.exists():
        fail(f"Missing prompt cases: {CASES_PATH}", failures)
    if not TEST_LOG_PATH.exists():
        fail(f"Missing workflow test log: {TEST_LOG_PATH}", failures)
    if not ROSTER_MATRIX_PATH.exists():
        fail(f"Missing roster prompt matrix: {ROSTER_MATRIX_PATH}", failures)
    if not PROOF_MATRIX_PATH.exists():
        fail(f"Missing proof matrix: {PROOF_MATRIX_PATH}", failures)
    if not REVIEW_DECISION_HELPER_PATH.exists():
        fail(f"Missing review decision helper: {REVIEW_DECISION_HELPER_PATH}", failures)
    if not CUTOUT_FRINGE_AUDIT_BUILDER_PATH.exists():
        fail(f"Missing cutout orange-fringe audit builder: {CUTOUT_FRINGE_AUDIT_BUILDER_PATH}", failures)
    if not CUTOUT_EDGE_CLEANER_PATH.exists():
        fail(f"Missing cutout edge-orange cleaner: {CUTOUT_EDGE_CLEANER_PATH}", failures)
    if not ROSTER_PACKET_BUILDER_PATH.exists():
        fail(f"Missing roster prompt packet builder: {ROSTER_PACKET_BUILDER_PATH}", failures)
    if not STYLE_DRIFT_BUILDER_PATH.exists():
        fail(f"Missing style drift audit builder: {STYLE_DRIFT_BUILDER_PATH}", failures)
    if not CANDIDATE_TRIAGE_BUILDER_PATH.exists():
        fail(f"Missing candidate triage builder: {CANDIDATE_TRIAGE_BUILDER_PATH}", failures)
    if not QUICK_AUDIT_GATE_PATH.exists():
        fail(f"Missing quick audit gate: {QUICK_AUDIT_GATE_PATH}", failures)
    if not REVIEW_PACKET_BUILDER_PATH.exists():
        fail(f"Missing review packet builder: {REVIEW_PACKET_BUILDER_PATH}", failures)
    if not REVIEW_QUEUE_BUILDER_PATH.exists():
        fail(f"Missing review queue builder: {REVIEW_QUEUE_BUILDER_PATH}", failures)
    if not COMPLETION_AUDIT_BUILDER_PATH.exists():
        fail(f"Missing completion audit builder: {COMPLETION_AUDIT_BUILDER_PATH}", failures)
    if not WORKFLOW_RUNNER_PATH.exists():
        fail(f"Missing workflow validation runner: {WORKFLOW_RUNNER_PATH}", failures)
    if not STYLE_DRIFT_AUDIT_PATH.exists():
        fail(f"Missing style drift audit: {STYLE_DRIFT_AUDIT_PATH}", failures)
    if not CANDIDATE_TRIAGE_PATH.exists():
        fail(f"Missing candidate style triage: {CANDIDATE_TRIAGE_PATH}", failures)
    if not CUTOUT_FRINGE_AUDIT_PATH.exists():
        fail(f"Missing cutout orange-fringe audit: {CUTOUT_FRINGE_AUDIT_PATH}", failures)
    if not REVIEW_PACKET_PATH.exists():
        fail(f"Missing review packet: {REVIEW_PACKET_PATH}", failures)
    if not COMPLETION_AUDIT_PATH.exists():
        fail(f"Missing completion audit: {COMPLETION_AUDIT_PATH}", failures)
    if not REVIEW_QUEUE_PATH.exists():
        fail(f"Missing review queue: {REVIEW_QUEUE_PATH}", failures)
    if not FUTURE_AGENT_HANDOFF_PATH.exists():
        fail(f"Missing future agent handoff: {FUTURE_AGENT_HANDOFF_PATH}", failures)
    if not CREEP_REVISION_PROMPT_PACKET_PATH.exists():
        fail(f"Missing Creep revision prompt packet: {CREEP_REVISION_PROMPT_PACKET_PATH}", failures)
    if failures:
        for item in failures:
            print(f"FAIL: {item}")
        return 1

    doc = DOC_PATH.read_text(encoding="utf-8")
    doc_lower = doc.lower()
    for snippet in REQUIRED_DOC_SNIPPETS:
        if snippet.lower() not in doc_lower:
            fail(f"workflow doc missing required snippet: {snippet}", failures)

    test_log = TEST_LOG_PATH.read_text(encoding="utf-8")
    test_log_lower = test_log.lower()
    for snippet in REQUIRED_TEST_LOG_SNIPPETS:
        if snippet.lower() not in test_log_lower:
            fail(f"workflow test log missing required snippet: {snippet}", failures)

    style_drift_audit = STYLE_DRIFT_AUDIT_PATH.read_text(encoding="utf-8")
    style_drift_audit_lower = style_drift_audit.lower()
    for snippet in REQUIRED_STYLE_DRIFT_AUDIT_SNIPPETS:
        if snippet.lower() not in style_drift_audit_lower:
            fail(f"style drift audit missing required snippet: {snippet}", failures)

    candidate_triage = CANDIDATE_TRIAGE_PATH.read_text(encoding="utf-8")
    candidate_triage_lower = candidate_triage.lower()
    for snippet in REQUIRED_CANDIDATE_TRIAGE_SNIPPETS:
        if snippet.lower() not in candidate_triage_lower:
            fail(f"candidate style triage missing required snippet: {snippet}", failures)

    cutout_fringe_audit = CUTOUT_FRINGE_AUDIT_PATH.read_text(encoding="utf-8")
    cutout_fringe_audit_lower = cutout_fringe_audit.lower()
    for snippet in REQUIRED_CUTOUT_FRINGE_AUDIT_SNIPPETS:
        if snippet.lower() not in cutout_fringe_audit_lower:
            fail(f"cutout orange-fringe audit missing required snippet: {snippet}", failures)

    review_packet = REVIEW_PACKET_PATH.read_text(encoding="utf-8")
    review_packet_lower = review_packet.lower()
    for snippet in REQUIRED_REVIEW_PACKET_SNIPPETS:
        if snippet.lower() not in review_packet_lower:
            fail(f"review packet missing required snippet: {snippet}", failures)

    completion_audit = COMPLETION_AUDIT_PATH.read_text(encoding="utf-8")
    completion_audit_lower = completion_audit.lower()
    for snippet in REQUIRED_COMPLETION_AUDIT_SNIPPETS:
        if snippet.lower() not in completion_audit_lower:
            fail(f"completion audit missing required snippet: {snippet}", failures)

    review_queue = REVIEW_QUEUE_PATH.read_text(encoding="utf-8")
    review_queue_lower = review_queue.lower()
    for snippet in REQUIRED_REVIEW_QUEUE_SNIPPETS:
        if snippet.lower() not in review_queue_lower:
            fail(f"review queue missing required snippet: {snippet}", failures)

    future_agent_handoff = FUTURE_AGENT_HANDOFF_PATH.read_text(encoding="utf-8")
    future_agent_handoff_lower = future_agent_handoff.lower()
    for snippet in REQUIRED_FUTURE_AGENT_HANDOFF_SNIPPETS:
        if snippet.lower() not in future_agent_handoff_lower:
            fail(f"future agent handoff missing required snippet: {snippet}", failures)

    creep_revision_prompt_packet = CREEP_REVISION_PROMPT_PACKET_PATH.read_text(encoding="utf-8")
    creep_revision_prompt_packet_lower = creep_revision_prompt_packet.lower()
    for snippet in REQUIRED_CREEP_REVISION_PROMPT_PACKET_SNIPPETS:
        if snippet.lower() not in creep_revision_prompt_packet_lower:
            fail(f"Creep revision prompt packet missing required snippet: {snippet}", failures)

    packet_builder = ROSTER_PACKET_BUILDER_PATH.read_text(encoding="utf-8")
    packet_builder_lower = packet_builder.lower()
    for snippet in REQUIRED_PACKET_BUILDER_SNIPPETS:
        if snippet.lower() not in packet_builder_lower:
            fail(f"roster packet builder missing required snippet: {snippet}", failures)

    review_decision_helper = REVIEW_DECISION_HELPER_PATH.read_text(encoding="utf-8")
    review_decision_helper_lower = review_decision_helper.lower()
    for snippet in REQUIRED_REVIEW_DECISION_HELPER_SNIPPETS:
        if snippet.lower() not in review_decision_helper_lower:
            fail(f"review decision helper missing required snippet: {snippet}", failures)

    style_drift_builder = STYLE_DRIFT_BUILDER_PATH.read_text(encoding="utf-8")
    style_drift_builder_lower = style_drift_builder.lower()
    for snippet in REQUIRED_STYLE_DRIFT_BUILDER_SNIPPETS:
        if snippet.lower() not in style_drift_builder_lower:
            fail(f"style drift audit builder missing required snippet: {snippet}", failures)

    candidate_triage_builder = CANDIDATE_TRIAGE_BUILDER_PATH.read_text(encoding="utf-8")
    candidate_triage_builder_lower = candidate_triage_builder.lower()
    for snippet in REQUIRED_CANDIDATE_TRIAGE_BUILDER_SNIPPETS:
        if snippet.lower() not in candidate_triage_builder_lower:
            fail(f"candidate triage builder missing required snippet: {snippet}", failures)

    quick_audit_gate = QUICK_AUDIT_GATE_PATH.read_text(encoding="utf-8")
    quick_audit_gate_lower = quick_audit_gate.lower()
    for snippet in REQUIRED_QUICK_AUDIT_GATE_SNIPPETS:
        if snippet.lower() not in quick_audit_gate_lower:
            fail(f"quick audit gate missing required snippet: {snippet}", failures)

    cutout_fringe_audit_builder = CUTOUT_FRINGE_AUDIT_BUILDER_PATH.read_text(encoding="utf-8")
    cutout_fringe_audit_builder_lower = cutout_fringe_audit_builder.lower()
    for snippet in REQUIRED_CUTOUT_FRINGE_AUDIT_BUILDER_SNIPPETS:
        if snippet.lower() not in cutout_fringe_audit_builder_lower:
            fail(f"cutout orange-fringe audit builder missing required snippet: {snippet}", failures)

    cutout_edge_cleaner = CUTOUT_EDGE_CLEANER_PATH.read_text(encoding="utf-8")
    cutout_edge_cleaner_lower = cutout_edge_cleaner.lower()
    for snippet in REQUIRED_CUTOUT_EDGE_CLEANER_SNIPPETS:
        if snippet.lower() not in cutout_edge_cleaner_lower:
            fail(f"cutout edge-orange cleaner missing required snippet: {snippet}", failures)

    review_packet_builder = REVIEW_PACKET_BUILDER_PATH.read_text(encoding="utf-8")
    review_packet_builder_lower = review_packet_builder.lower()
    for snippet in REQUIRED_REVIEW_PACKET_BUILDER_SNIPPETS:
        if snippet.lower() not in review_packet_builder_lower:
            fail(f"review packet builder missing required snippet: {snippet}", failures)

    source_identity_sheet_builder = SOURCE_IDENTITY_SHEET_BUILDER_PATH.read_text(encoding="utf-8")
    source_identity_sheet_builder_lower = source_identity_sheet_builder.lower()
    for snippet in REQUIRED_SOURCE_IDENTITY_SHEET_BUILDER_SNIPPETS:
        if snippet.lower() not in source_identity_sheet_builder_lower:
            fail(f"source identity sheet builder missing required snippet: {snippet}", failures)

    review_queue_builder = REVIEW_QUEUE_BUILDER_PATH.read_text(encoding="utf-8")
    review_queue_builder_lower = review_queue_builder.lower()
    for snippet in REQUIRED_REVIEW_QUEUE_BUILDER_SNIPPETS:
        if snippet.lower() not in review_queue_builder_lower:
            fail(f"review queue builder missing required snippet: {snippet}", failures)

    completion_builder = COMPLETION_AUDIT_BUILDER_PATH.read_text(encoding="utf-8")
    completion_builder_lower = completion_builder.lower()
    for snippet in REQUIRED_COMPLETION_BUILDER_SNIPPETS:
        if snippet.lower() not in completion_builder_lower:
            fail(f"completion audit builder missing required snippet: {snippet}", failures)

    workflow_runner = WORKFLOW_RUNNER_PATH.read_text(encoding="utf-8")
    workflow_runner_lower = workflow_runner.lower()
    for snippet in REQUIRED_WORKFLOW_RUNNER_SNIPPETS:
        if snippet.lower() not in workflow_runner_lower:
            fail(f"workflow validation runner missing required snippet: {snippet}", failures)

    data = json.loads(CASES_PATH.read_text(encoding="utf-8"))
    cases = data.get("cases", [])
    if not isinstance(cases, list) or len(cases) < 5:
        fail("prompt cases must include at least five cases", failures)

    style_anchor = data.get("style_anchor", {})
    if not isinstance(style_anchor, dict):
        fail("style_anchor must be an object", failures)
    else:
        for key in ("raw", "cutout_proof", "comparison"):
            value = style_anchor.get(key)
            if not isinstance(value, str):
                fail(f"style_anchor.{key} must be a string", failures)
            else:
                check_existing_path(value, f"style_anchor.{key}", "global", failures)

    positive_contract = " ".join(as_text(item) for item in data.get("global_positive_contract", [])).lower()
    negative_contract = " ".join(as_text(item) for item in data.get("global_negative_contract", [])).lower()
    for phrase in REQUIRED_POSITIVES:
        if phrase.lower() not in positive_contract:
            fail(f"global_positive_contract missing: {phrase}", failures)
    for phrase in REQUIRED_NEGATIVES:
        if phrase.lower() not in negative_contract:
            fail(f"global_negative_contract missing: {phrase}", failures)

    for case in cases:
        if not isinstance(case, dict):
            fail("every case must be an object", failures)
            continue
        case_id = as_text(case.get("id", "<missing id>"))
        for field in REQUIRED_CASE_FIELDS:
            if field not in case:
                fail(f"{case_id}: missing field {field}", failures)

        prompt = as_text(case.get("prompt", "")).lower()
        negative_prompt = as_text(case.get("negative_prompt", "")).lower()
        for phrase in REQUIRED_POSITIVES:
            if phrase.lower() not in prompt:
                fail(f"{case_id}: prompt missing positive phrase: {phrase}", failures)
        asset_type = as_text(case.get("asset_type", "")).lower()
        scoped_positives = UNIT_ONLY_POSITIVES if asset_type == "unit" else ASSET_ONLY_POSITIVES
        for phrase in scoped_positives:
            if phrase.lower() not in prompt:
                fail(f"{case_id}: prompt missing scoped positive phrase: {phrase}", failures)
        for phrase in REQUIRED_NEGATIVES:
            if phrase.lower() not in negative_prompt:
                fail(f"{case_id}: negative_prompt missing: {phrase}", failures)

        acceptance = case.get("acceptance", [])
        if not isinstance(acceptance, list) or len(acceptance) < 3:
            fail(f"{case_id}: acceptance must include at least three checks", failures)

        cutout_strategy = as_text(case.get("cutout_strategy", "")).lower()
        if "birefnet" not in cutout_strategy:
            fail(f"{case_id}: cutout_strategy must name BiRefNet", failures)

        source_image = case.get("source_image")
        if source_image is not None and not isinstance(source_image, str):
            fail(f"{case_id}: source_image must be null or string", failures)
        elif isinstance(source_image, str):
            check_existing_path(source_image, "source_image", case_id, failures)

        style_reference = case.get("style_reference")
        if not isinstance(style_reference, str):
            fail(f"{case_id}: style_reference must be a string", failures)
        else:
            check_existing_path(style_reference, "style_reference", case_id, failures)

    roster_data = json.loads(ROSTER_MATRIX_PATH.read_text(encoding="utf-8"))
    coverage_groups = roster_data.get("coverage_groups", {})
    if not isinstance(coverage_groups, dict) or not coverage_groups:
        fail("roster matrix coverage_groups must be a non-empty object", failures)
        coverage_groups = {}
    roster_units = roster_data.get("units", [])
    other_units = roster_data.get("other_units", [])
    if not isinstance(roster_units, list):
        fail("roster matrix units must be a list", failures)
        roster_units = []
    if not isinstance(other_units, list):
        fail("roster matrix other_units must be a list", failures)
        other_units = []
    data_unit_ids = sorted(path.stem for path in (ROOT / "data" / "units").glob("*.tres"))
    matrix_unit_ids = sorted(as_text(unit.get("id", "")) for unit in roster_units if isinstance(unit, dict))
    if matrix_unit_ids != data_unit_ids:
        fail(f"roster matrix ids do not match data/units ids: matrix={matrix_unit_ids} data={data_unit_ids}", failures)
    other_unit_ids = sorted(as_text(unit.get("id", "")) for unit in other_units if isinstance(unit, dict))
    art_other_unit_ids = sorted(
        re.search(r'^id\s*=\s*"([^"]+)"', path.read_text(encoding="utf-8"), re.MULTILINE).group(1)
        for path in (ROOT / "data" / "other_units" / "other").glob("*.tres")
        if resource_has_art_sprite(path) and re.search(r'^id\s*=\s*"([^"]+)"', path.read_text(encoding="utf-8"), re.MULTILINE)
    )
    if other_unit_ids != art_other_unit_ids:
        fail(f"roster matrix other_units ids do not match art-bearing data/other_units/other ids: matrix={other_unit_ids} data={art_other_unit_ids}", failures)
    for unit in roster_units + other_units:
        if not isinstance(unit, dict):
            fail("every roster unit/extra entry must be an object", failures)
            continue
        unit_id = as_text(unit.get("id", "<missing id>"))
        required_fields = REQUIRED_ROSTER_FIELDS
        for field in required_fields:
            if field not in unit:
                fail(f"roster {unit_id}: missing field {field}", failures)
        resource_path = unit.get("resource_path")
        if unit in other_units:
            if not isinstance(resource_path, str):
                fail(f"roster {unit_id}: other unit must include resource_path", failures)
            else:
                check_existing_path(resource_path, "resource_path", f"roster {unit_id}", failures)
        source_image = unit.get("source_image")
        if not isinstance(source_image, str):
            fail(f"roster {unit_id}: source_image must be a string", failures)
        else:
            check_existing_path(source_image, "source_image", f"roster {unit_id}", failures)
        for field in ("coverage_group", "preserve", "avoid_drift"):
            value = unit.get(field)
            if not isinstance(value, list) or not value:
                fail(f"roster {unit_id}: {field} must be a non-empty list", failures)
            elif field == "coverage_group":
                for group in value:
                    if group not in coverage_groups:
                        fail(f"roster {unit_id}: undefined coverage group: {group}", failures)
        for field in ("visual_identity", "prompt_addendum"):
            value = unit.get(field)
            if not isinstance(value, str) or len(value.strip()) < 20:
                fail(f"roster {unit_id}: {field} must be a descriptive string", failures)
        if unit_id == "creep":
            creep_text = " ".join(as_text(unit.get(field, "")) for field in (
                "design_doc_role",
                "design_doc_ability",
                "visual_identity",
                "preserve",
                "avoid_drift",
                "prompt_addendum",
            )).lower()
            for phrase in (
                "planned unit",
                "assassin",
                "exile",
                "executioner",
                "dash",
                "spin",
                "smooth alien face",
                "smooth gray-blue alien skin",
                "subtle chalk pores",
                "dry mottled skin variation",
                "thin occult scarring",
                "vellum-level dry detail richness",
                "paisley only as secondary contrast context",
                "ripped-apart corpse",
                "exposed muscle",
                "sweaty skin",
                "shiny alien head",
                "slick black tendrils",
                "ribbed corpse torso",
                "anatomy-model surface striations",
                "glossy creature concept",
                "flat powdery skin",
                "dull ink-black tendrils",
                "unsegmented tendril",
                "segmented armor tendrils",
                "mechanical black tube tendrils",
                "talisman clutter as fake detail",
                "surface weathering, not armor clutter",
                "dry chalky",
            ):
                if phrase not in creep_text:
                    fail(f"roster creep: missing design-doc identity phrase: {phrase}", failures)
        if unit_id == "bo":
            bo_text = " ".join(as_text(unit.get(field, "")) for field in (
                "visual_identity",
                "preserve",
                "avoid_drift",
                "prompt_addendum",
            )).lower()
            for phrase in (
                "tusked maw face",
                "chained spiked mace-head",
                "dry red crack-line motif",
                "dry charcoal stone-hide",
                "wet monster skin",
                "shiny lava cracks",
                "glossy demon armor",
                "comedy ogre",
            ):
                if phrase not in bo_text:
                    fail(f"roster bo: missing brute/material phrase: {phrase}", failures)
        if unit_id == "axiom":
            axiom_text = " ".join(as_text(unit.get(field, "")) for field in (
                "visual_identity",
                "preserve",
                "avoid_drift",
                "prompt_addendum",
            )).lower()
            for phrase in (
                "severe owl face",
                "cyan glowing eyes",
                "blue circular chest focus",
                "hanging talisman tags",
                "taloned feet",
                "glossy feathers",
                "cute owl mascot",
                "plain dark blob",
            ):
                if phrase not in axiom_text:
                    fail(f"roster axiom: missing compact scholar phrase: {phrase}", failures)
        if unit_id == "volt":
            volt_text = " ".join(as_text(unit.get(field, "")) for field in (
                "visual_identity",
                "preserve",
                "avoid_drift",
                "prompt_addendum",
            )).lower()
            for phrase in (
                "pale blue wind-swept hair",
                "crown-like head spikes",
                "large square blue chest orb",
                "smaller waist orb",
                "electric hand arcs",
                "detached particle confetti",
                "glossy lightning",
                "neon rave glow",
                "background storm",
            ):
                if phrase not in volt_text:
                    fail(f"roster volt: missing attached-energy phrase: {phrase}", failures)
        if unit_id == "vykos":
            vykos_text = " ".join(as_text(unit.get(field, "")) for field in (
                "visual_identity",
                "preserve",
                "avoid_drift",
                "prompt_addendum",
            )).lower()
            for phrase in (
                "skull-maw face",
                "red glowing eyes",
                "red vein/crack marks",
                "huge curved black blade",
                "dry chalky bone/limestone skin",
                "wet gore",
                "shiny anatomy",
                "slick corpse flesh",
                "flayed muscle",
            ):
                if phrase not in vykos_text:
                    fail(f"roster vykos: missing pale/sanguine phrase: {phrase}", failures)
        if unit_id == "brute":
            brute_text = " ".join(as_text(unit.get(field, "")) for field in (
                "visual_identity",
                "preserve",
                "avoid_drift",
                "prompt_addendum",
            )).lower()
            for phrase in (
                "skull-faced titan tank",
                "dry bone rib armor",
                "huge slab fists",
                "black tattered waist cloth",
                "tiny green fissure",
                "chalky charcoal stone",
                "dull oxidized iron",
                "glossy wet rock",
                "generic golem without skull and ribs",
            ):
                if phrase not in brute_text:
                    fail(f"roster brute: missing guardian-bulk phrase: {phrase}", failures)
        if unit_id == "bonko":
            bonko_text = " ".join(as_text(unit.get(field, "")) for field in (
                "visual_identity",
                "preserve",
                "avoid_drift",
                "prompt_addendum",
            )).lower()
            for phrase in (
                "ivory grinning mask",
                "glowing pale eyes",
                "long sinewy arms",
                "spiked dark shoulder pads",
                "huge banded wooden bat/cannon-club",
                "dry scarred skin",
                "dusty bone mask",
                "splintered raw wood",
                "glossy plastic mask",
                "baseball bat sports read",
                "unreadable tiny weapon",
            ):
                if phrase not in bonko_text:
                    fail(f"roster bonko: missing small-raider phrase: {phrase}", failures)
        if unit_id == "hexeon":
            hexeon_text = " ".join(as_text(unit.get(field, "")) for field in (
                "visual_identity",
                "preserve",
                "avoid_drift",
                "prompt_addendum",
            )).lower()
            for phrase in (
                "eye-covered crystal mask",
                "floating small eye facets",
                "spiked shoulders/back",
                "clawed hands",
                "thin predatory legs",
                "attached prismatic blade shards",
                "black ink-stained mineral skin",
                "dry obsidian gouache",
                "glossy glass armor",
                "polished black latex body",
                "detached particle confetti",
                "busy prism storm",
            ):
                if phrase not in hexeon_text:
                    fail(f"roster hexeon: missing time/blade phrase: {phrase}", failures)
        if unit_id == "totem":
            totem_text = " ".join(as_text(unit.get(field, "")) for field in (
                "visual_identity",
                "preserve",
                "avoid_drift",
                "prompt_addendum",
            )).lower()
            for phrase in (
                "crown-like bark mask",
                "cyan glowing eyes",
                "stern carved wooden face",
                "layered bark armor plates",
                "cyan spiral chest runes",
                "feather/leaf shoulder fringe",
                "clawed wooden hands and feet",
                "dry carved bark",
                "raw splintered wood",
                "chalky turquoise pigment",
                "glossy varnished wood",
                "toy totem",
                "green foliage blob",
            ):
                if phrase not in totem_text:
                    fail(f"roster totem: missing dry-wood guardian phrase: {phrase}", failures)
        if unit_id == "sari":
            sari_text = " ".join(as_text(unit.get(field, "")) for field in (
                "visual_identity",
                "preserve",
                "avoid_drift",
                "prompt_addendum",
            )).lower()
            for phrase in (
                "traitless live-data marksman",
                "grayscale spectral armored body",
                "wind-swept black tendril hair",
                "green glowing eyes",
                "dark face mask/visor",
                "matte black armor plates",
                "leather chest straps",
                "crouched leaping marksman silhouette",
                "grouped ghostly extra arms/tendrils",
                "busy smoke only",
                "cute ghost",
                "werewolf",
                "shiny black armor",
                "hair spaghetti noise",
                "unreadable tendril cloud",
            ):
                if phrase not in sari_text:
                    fail(f"roster sari: missing spectral-tendril phrase: {phrase}", failures)

    proof_data = json.loads(PROOF_MATRIX_PATH.read_text(encoding="utf-8"))
    proof_text = PROOF_MATRIX_PATH.read_text(encoding="utf-8")
    proof_text_lower = proof_text.lower()
    for snippet in REQUIRED_PROOF_MATRIX_SNIPPETS:
        if snippet.lower() not in proof_text_lower:
            fail(f"proof matrix missing required style-contract snippet: {snippet}", failures)

    style_contract = proof_data.get("style_contract", {})
    if not isinstance(style_contract, dict):
        fail("proof matrix style_contract must be an object", failures)
        style_contract = {}
    reference_policy = style_contract.get("reference_policy", {})
    if not isinstance(reference_policy, dict):
        fail("proof matrix style_contract.reference_policy must be an object", failures)
        reference_policy = {}
    primary_anchor = reference_policy.get("primary_anchor", {})
    if not isinstance(primary_anchor, dict):
        fail("reference_policy.primary_anchor must be an object", failures)
        primary_anchor = {}
    else:
        if as_text(primary_anchor.get("id", "")) != "vellum_raw_anchor":
            fail("reference_policy.primary_anchor.id must be vellum_raw_anchor", failures)
        primary_anchor_path = primary_anchor.get("path")
        if not isinstance(primary_anchor_path, str):
            fail("reference_policy.primary_anchor.path must be a string", failures)
        else:
            check_existing_path(primary_anchor_path, "reference_policy.primary_anchor.path", "proof matrix", failures)
        primary_rule = as_text(primary_anchor.get("rule", "")).lower()
        for phrase in ("ultimate character style reference", "do not demote", "later proofs"):
            if phrase not in primary_rule:
                fail(f"reference_policy.primary_anchor.rule missing phrase: {phrase}", failures)
    secondary_anchor_ids = reference_policy.get("secondary_anchor_proof_ids", [])
    small_asset_reference_ids = reference_policy.get("small_asset_reference_proof_ids", [])
    if not isinstance(secondary_anchor_ids, list) or not secondary_anchor_ids:
        fail("reference_policy.secondary_anchor_proof_ids must be a non-empty list", failures)
        secondary_anchor_ids = []
    if not isinstance(small_asset_reference_ids, list) or not small_asset_reference_ids:
        fail("reference_policy.small_asset_reference_proof_ids must be a non-empty list", failures)
        small_asset_reference_ids = []
    for field, phrases in (
        ("promotion_rule", ("user", "explicitly promote", "global style anchors")),
        ("candidate_rule", ("current candidates", "review-only", "never anchor references")),
        ("side_by_side_rule", ("vellum-first", "side-by-side")),
        ("veto_rule", ("vellum can veto", "weaker than vellum")),
        ("passing_pool_rule", ("do not average", "passing pool")),
    ):
        value = as_text(reference_policy.get(field, "")).lower()
        for phrase in phrases:
            if phrase not in value:
                fail(f"reference_policy.{field} missing phrase: {phrase}", failures)

    proofs = proof_data.get("proofs", [])
    if not isinstance(proofs, list) or not proofs:
        fail("proof matrix proofs must be a non-empty list", failures)
        proofs = []

    current_coverage: set[str] = set()
    current_asset_proofs = 0
    proof_ids: set[str] = set()
    proof_reference_roles: dict[str, str] = {}
    known_unit_ids = set(matrix_unit_ids) | set(other_unit_ids)
    for proof in proofs:
        if not isinstance(proof, dict):
            fail("every proof matrix entry must be an object", failures)
            continue
        proof_id = as_text(proof.get("id", "<missing id>"))
        if proof_id in proof_ids:
            fail(f"proof matrix duplicate id: {proof_id}", failures)
        proof_ids.add(proof_id)
        for field in REQUIRED_PROOF_FIELDS:
            if field not in proof:
                fail(f"proof {proof_id}: missing field {field}", failures)

        subject_type = as_text(proof.get("subject_type", "")).lower()
        if subject_type not in ("unit", "asset"):
            fail(f"proof {proof_id}: subject_type must be unit or asset", failures)

        status = as_text(proof.get("status", "")).lower()
        if status not in VALID_PROOF_STATUSES:
            fail(f"proof {proof_id}: invalid status {status}", failures)

        reference_role = as_text(proof.get("reference_role", "")).lower()
        proof_reference_roles[proof_id] = reference_role
        if reference_role not in VALID_REFERENCE_ROLES:
            fail(f"proof {proof_id}: invalid reference_role {reference_role}", failures)
        if status == "rejected" and reference_role != "negative_example":
            fail(f"proof {proof_id}: rejected proof must use reference_role negative_example", failures)
        if reference_role == "negative_example" and status != "rejected":
            fail(f"proof {proof_id}: only rejected proofs may use reference_role negative_example", failures)
        if reference_role == "review_candidate_not_anchor" and status != "current_candidate":
            fail(f"proof {proof_id}: review_candidate_not_anchor must be a current_candidate", failures)
        if reference_role in ANCHOR_REFERENCE_ROLES and status != "accepted":
            fail(f"proof {proof_id}: reference anchor roles must be accepted, not {status}", failures)

        subject_id = as_text(proof.get("subject_id", ""))
        if subject_type == "unit" and subject_id not in known_unit_ids:
            fail(f"proof {proof_id}: unknown unit subject_id {subject_id}", failures)

        coverage = proof.get("coverage_group", [])
        if not isinstance(coverage, list):
            fail(f"proof {proof_id}: coverage_group must be a list", failures)
            coverage = []
        if subject_type == "unit" and not coverage:
            fail(f"proof {proof_id}: unit proof coverage_group must not be empty", failures)
        for group in coverage:
            if group not in coverage_groups:
                fail(f"proof {proof_id}: undefined coverage group: {group}", failures)

        source_image = proof.get("source_image")
        if source_image is not None and not isinstance(source_image, str):
            fail(f"proof {proof_id}: source_image must be null or string", failures)
        elif isinstance(source_image, str):
            check_existing_path(source_image, "source_image", f"proof {proof_id}", failures)

        for field in ("output_dir", "raw", "cutout", "review", "board_preview"):
            value = proof.get(field)
            if not isinstance(value, str):
                fail(f"proof {proof_id}: {field} must be a string path", failures)
            else:
                check_existing_path(value, field, f"proof {proof_id}", failures)

        for field in ("proof_goal", "style_gate", "cutout_gate", "decision_notes"):
            value = proof.get(field)
            if not isinstance(value, str) or len(value.strip()) < 20:
                fail(f"proof {proof_id}: {field} must be a descriptive string", failures)

        if status == "rejected":
            failure_reason = proof.get("failure_reason")
            if not isinstance(failure_reason, str) or len(failure_reason.strip()) < 20:
                fail(f"proof {proof_id}: rejected proofs must include a descriptive failure_reason", failures)
        elif status in CURRENT_PROOF_STATUSES:
            current_coverage.update(str(group) for group in coverage)
            if subject_type == "asset":
                current_asset_proofs += 1
            if "fail:" in as_text(proof.get("style_gate", "")).lower():
                fail(f"proof {proof_id}: current proof style_gate cannot be a fail", failures)

    for proof_id in secondary_anchor_ids:
        if proof_reference_roles.get(as_text(proof_id)) != "secondary_contrast_anchor":
            fail(f"secondary anchor proof id must have reference_role secondary_contrast_anchor: {proof_id}", failures)
    for proof_id in small_asset_reference_ids:
        if proof_reference_roles.get(as_text(proof_id)) != "small_asset_material_reference":
            fail(f"small asset reference proof id must have reference_role small_asset_material_reference: {proof_id}", failures)
    policy_secondary_ids = {as_text(item) for item in secondary_anchor_ids}
    policy_small_asset_ids = {as_text(item) for item in small_asset_reference_ids}
    for proof_id, reference_role in proof_reference_roles.items():
        if reference_role == "secondary_contrast_anchor" and proof_id not in policy_secondary_ids:
            fail(f"secondary_contrast_anchor proof missing from reference_policy: {proof_id}", failures)
        if reference_role == "small_asset_material_reference" and proof_id not in policy_small_asset_ids:
            fail(f"small_asset_material_reference proof missing from reference_policy: {proof_id}", failures)
    if "paisley_goth_bubble_refit" not in policy_secondary_ids:
        fail("reference_policy must keep Paisley as the secondary contrast anchor", failures)
    if "ability_token_contract_mark" not in policy_small_asset_ids:
        fail("reference_policy must keep the contract token as the small-asset reference", failures)

    missing_current_coverage = sorted(MINIMUM_CURRENT_PROOF_COVERAGE - current_coverage)
    if missing_current_coverage:
        fail(f"proof matrix missing current proof coverage groups: {missing_current_coverage}", failures)
    if current_asset_proofs < 1:
        fail("proof matrix must include at least one accepted/current non-character asset proof", failures)

    coverage_gaps = proof_data.get("coverage_gaps", [])
    if not isinstance(coverage_gaps, list) or len(coverage_gaps) < 3:
        fail("proof matrix coverage_gaps must include at least three remaining stress-test gaps", failures)
    next_test = proof_data.get("next_recommended_stress_test", {})
    if not isinstance(next_test, dict) or not next_test.get("unit_id"):
        fail("proof matrix must name a next_recommended_stress_test.unit_id", failures)

    if failures:
        for item in failures:
            print(f"FAIL: {item}")
        return 1

    print("PASS: unit art workflow doc and prompt cases contain the locked style/cutout constraints.")
    print(f"cases={len(cases)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
