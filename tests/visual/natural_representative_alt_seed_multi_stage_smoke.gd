extends "res://tests/visual/natural_representative_multi_stage_main_flow_smoke.gd"

const ALT_MULTI_STAGE_SMOKE_NAME: String = "NaturalRepresentativeAltSeedMultiStageSmoke"
const ALT_MULTI_STAGE_STARTERS: Array[String] = ["axiom", "brute", "mara", "repo", "sari", "bonko"]
const ALT_MULTI_STAGE_SEEDS: Array[int] = [6101, 6501, 6601, 7101, 7201, 6401]

func _representative_smoke_name() -> String:
	return ALT_MULTI_STAGE_SMOKE_NAME

func _representative_starters() -> Array[String]:
	return ALT_MULTI_STAGE_STARTERS

func _representative_seeds() -> Array[int]:
	return ALT_MULTI_STAGE_SEEDS

func _flow_verbose_round_logs() -> bool:
	return false
