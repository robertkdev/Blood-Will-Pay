extends "res://tests/pacing/longitudinal_pacing_harness.gd"

## Longitudinal comparison policy that behaves like a competent first-pass
## player: it buys affordable power while retaining the one-gold planning
## reserve, rather than imposing the natural-flow fixture's one-buy cap during
## the first boss approach. This is a test policy only; production economy and
## shop rules are not modified.

const COMPETENT_SMOKE_NAME: String = "CompetentPolicyPacingHarness"
const COMPETENT_SAMPLE_ID: String = "competent_campaign_bonko"
const COMPETENT_OUTPUT_STEM: String = "competent_policy_pacing"

var _transition_chapter_before: int = -1
var _transition_round_before: int = -1

func _flow_smoke_name() -> String:
	return COMPETENT_SMOKE_NAME

func _flow_sample_id() -> String:
	return COMPETENT_SAMPLE_ID

func _flow_output_stem() -> String:
	return COMPETENT_OUTPUT_STEM

func _flow_target_stage() -> int:
	# The natural fixture's target is the second-boss preview (stage 9). The
	# competent comparison deliberately runs one beat farther so that the
	# second boss resolves before the longitudinal verdict is written.
	return 10

func _flow_target_round() -> int:
	return 5

func _press_continue(expect_forced: bool, label: String) -> void:
	await _pace_delay(PACING_HUMAN_PLAN_DELAY_SECONDS)
	var deadline_msec: int = Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline_msec:
		var button: Button = _main.find_child("ContinueButton", true, false) as Button
		if button != null and is_instance_valid(button) and not button.disabled:
			break
		await get_tree().process_frame
	await super._press_continue(expect_forced, label)

func _play_two_stage_round() -> Dictionary:
	# Chapter rollover opens the player-facing contract market before the next
	# planning round. Resolve that visible decision before touching the shop or
	# Start Battle control; otherwise the overlay intentionally keeps the start
	# button disabled and a longitudinal run would misclassify a real decision
	# as a pacing/runtime failure.
	await _resolve_pending_contract_market()
	_transition_chapter_before = int(GameState.chapter)
	_transition_round_before = int(GameState.stage_in_chapter)
	return await super._play_two_stage_round()

func _wait_for_preview_or_loss(timeout_seconds: float) -> bool:
	var resolved: bool = await super._wait_for_preview_or_loss(timeout_seconds)
	if not resolved or get_tree().root.get_node_or_null("LossOverlayLayer") != null:
		return resolved
	# Result settlement and progression are separate frames. Give the real
	# transition a bounded grace window so a transient PREVIEW state cannot be
	# recorded as a same-stage win and retried as though combat had failed.
	var deadline_msec: int = Time.get_ticks_msec() + 2500
	while Time.get_ticks_msec() < deadline_msec:
		var advanced: bool = int(GameState.chapter) > _transition_chapter_before
		advanced = advanced or (int(GameState.chapter) == _transition_chapter_before and int(GameState.stage_in_chapter) > _transition_round_before)
		if advanced or Economy.combat_active or GameState.phase != GameState.GamePhase.PREVIEW:
			break
		await get_tree().process_frame
	return resolved

func _second_fight_result(resolved: bool) -> String:
	if not resolved:
		return "timeout"
	if get_tree().root.get_node_or_null("LossOverlayLayer") != null:
		return "loss"
	if _recorder != null and _recorder.has_method("latest_outcome"):
		var outcome: String = String(_recorder.call("latest_outcome"))
		if outcome == "defeat":
			return "loss"
		if outcome == "tie":
			return "tie"
		if outcome == "victory":
			return "shop"
	return super._second_fight_result(resolved)

func _can_retry_after_same_stage(round_result: Dictionary) -> bool:
	if not bool(round_result.get("resolved", false)):
		return false
	if int(round_result.get("chapter_after", -1)) != int(round_result.get("chapter_before", -2)):
		return false
	if int(round_result.get("round_after", -1)) != int(round_result.get("round_before", -2)):
		return false
	var result: String = String(round_result.get("fight_result", ""))
	if result != "loss" and result != "tie" and result != "shop":
		return false
	var can_retry: bool = int(Economy.gold) > 0
	print("%s: retry_decision result=%s gold=%d can_retry=%s" % [COMPETENT_SMOKE_NAME, result, int(Economy.gold), str(can_retry)])
	return can_retry

func _resolve_pending_contract_market() -> void:
	if Shop == null or not Shop.has_method("has_pending_contract_choice"):
		return
	var deadline_msec: int = Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline_msec:
		if not bool(Shop.call("has_pending_contract_choice")):
			return
		var overlay: Control = _main.find_child("ChapterContractOverlay", true, false) as Control if _main != null else null
		if overlay != null and overlay.visible:
			break
		await get_tree().process_frame
	if not bool(Shop.call("has_pending_contract_choice")):
		return
	var pass_button: Button = _main.find_child("ContractPass", true, false) as Button if _main != null else null
	if pass_button == null or pass_button.disabled:
		_expect(false, "competent contract market did not expose an actionable PASS choice")
		return
	var clicked: bool = await _click_button(pass_button, "competent contract pass")
	_expect(clicked, "competent contract pass click did not fire")
	await _settle_frames(4)
	if _recorder != null:
		_recorder.mark("contract_passed", {"chapter": int(GameState.chapter)})

func _max_natural_buys_for_round(_chapter_before: int, _round_before: int) -> int:
	# The baseline fixture limits rounds 1-4 to one purchase. A real player can
	# make a second affordable purchase when the planning reserve remains intact.
	return _flow_max_buys_per_shop()

func _flow_max_retries_per_stage() -> int:
	# The production loss-recovery rule preserves a retry bankroll. Five is a
	# bounded player-policy allowance, not an infinite loop, and keeps the
	# longitudinal sample from stopping after the inherited smoke cap of three.
	return 5

func _flow_max_battles() -> int:
	# Retries consume resolved battles; keep the run bounded while leaving room
	# to resolve the second boss after a few legitimate recovery attempts.
	return 40

func _two_stage_offer_score(summary: Dictionary) -> int:
	var score: int = super._two_stage_offer_score(summary)
	# Keep the production role/cost heuristic's role diversity preference. The
	# competent comparison is about buying the second affordable offer, not about
	# granting the harness a synthetic duplicate bonus that a player may not see.
	if int(summary.get("cost", 0)) > 0:
		score += 10
	return score

func _click_shop_slot(slot_index: int) -> bool:
	# ShopPanel queues old cards for deletion before adding the fresh offer row.
	# Resolve the card by both logical slot and current offer id so a queued card
	# cannot turn a valid decision into a stale purchase.
	var desired_id: String = ""
	if Shop != null and Shop.state != null and slot_index >= 0 and slot_index < Shop.state.offers.size():
		var offer: Variant = Shop.state.offers[slot_index]
		if offer != null:
			desired_id = String(offer.id)
	var deadline: int = Time.get_ticks_msec() + 2500
	while Time.get_ticks_msec() < deadline:
		var combat: Node = _main.get_node_or_null("CombatView") if _main != null else null
		var grid: GridContainer = combat.get_node_or_null("MarginContainer/VBoxContainer/BottomStorageArea/ShopGrid") as GridContainer if combat != null else null
		if grid != null:
			for child: Node in grid.get_children():
				var card: ShopCard = child as ShopCard
				if card == null or int(card.slot_index) != slot_index:
					continue
				if desired_id == "" or String(card.offer_id) != desired_id:
					continue
				return await _click_button(card, "competent shop slot %d" % slot_index)
		await get_tree().process_frame
	_expect(false, "competent shop slot %d did not render current offer %s" % [slot_index, desired_id])
	return false
