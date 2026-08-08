extends "res://tests/visual/natural_input_main_flow_smoke.gd"

const BRUTE_INPUT_SMOKE_NAME: String = "NaturalBruteInputMainFlowSmoke"

func _smoke_name() -> String:
	return BRUTE_INPUT_SMOKE_NAME

func _starter_ids_for_run(_catalog: UnitCatalog) -> Array[String]:
	return ["brute"]
