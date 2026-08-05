extends RefCounted
class_name InteractionLatencyBudget

## Player-facing interaction budgets for the 60 Hz desktop playground.
##
## A visible response means that the accepted input has changed the rendered
## interaction state. A settled response means that the next stable gameplay
## state is available for another player action.

const TARGET_FRAME_MS: float = 16.7
const RESULT_DISMISS_VISIBLE_RESPONSE_MS: float = TARGET_FRAME_MS
const RESULT_DISMISS_FIRST_FRAME_RESPONSE_MS: float = 50.0
const RESULT_DISMISS_SETTLED_RESPONSE_MS: float = 400.0
const SHOP_ACTION_VISIBLE_FEEDBACK_MS: float = 100.0
const DRAG_DEPLOY_VISIBLE_FEEDBACK_MS: float = 100.0
const MENU_TRANSITION_VISIBLE_RESPONSE_MS: float = 100.0
const HIGH_FREQUENCY_INPUT_GUARD_MS: float = 50.0
const FRAME_STALL_WARNING_MS: float = 33.4

static func as_dictionary() -> Dictionary[String, float]:
	return {
		"target_frame_ms": TARGET_FRAME_MS,
		"result_dismiss_visible_response_ms": RESULT_DISMISS_VISIBLE_RESPONSE_MS,
		"result_dismiss_first_frame_response_ms": RESULT_DISMISS_FIRST_FRAME_RESPONSE_MS,
		"result_dismiss_settled_response_ms": RESULT_DISMISS_SETTLED_RESPONSE_MS,
		"shop_action_visible_feedback_ms": SHOP_ACTION_VISIBLE_FEEDBACK_MS,
		"drag_deploy_visible_feedback_ms": DRAG_DEPLOY_VISIBLE_FEEDBACK_MS,
		"menu_transition_visible_response_ms": MENU_TRANSITION_VISIBLE_RESPONSE_MS,
		"high_frequency_input_guard_ms": HIGH_FREQUENCY_INPUT_GUARD_MS,
		"frame_stall_warning_ms": FRAME_STALL_WARNING_MS,
	}
