extends "res://tests/visual/natural_representative_campaign_main_flow_smoke.gd"

const ALT_CAMPAIGN_SMOKE_NAME: String = "NaturalRepresentativeCampaignAltSeedSmoke"
const ALT_CAMPAIGN_STARTERS: Array[String] = ["axiom", "brute", "mara", "repo", "sari", "bonko"]
const ALT_CAMPAIGN_SEEDS: Array[int] = [6101, 6501, 6601, 7101, 7201, 6401]

func _representative_smoke_name() -> String:
	return ALT_CAMPAIGN_SMOKE_NAME

func _representative_starters() -> Array[String]:
	return ALT_CAMPAIGN_STARTERS

func _representative_seeds() -> Array[int]:
	return ALT_CAMPAIGN_SEEDS

func _flow_verbose_round_logs() -> bool:
	return false
