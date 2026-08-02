param(
	[string]$ReportDir = "",
	[string]$OutputDir = "outputs/audit_playtest/rga_accepted_misses_current",
	[string[]]$IgnoredReportNames = @("faeling.json")
)

$renamedReportDir = "$env:APPDATA\Godot\app_userdata\Blood Will Pay\identity_reports"
$legacyReportDir = "$env:APPDATA\Godot\app_userdata\Gamble Battle\identity_reports"
if ([string]::IsNullOrWhiteSpace($ReportDir)) {
	$ReportDir = if (Test-Path -LiteralPath $renamedReportDir) { $renamedReportDir } else { $legacyReportDir }
}

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-StringArray($Value) {
	$out = @()
	if ($null -eq $Value) {
		return $out
	}
	if ($Value -is [System.Array]) {
		foreach ($item in $Value) {
			$out += [string]$item
		}
		return $out
	}
	$out += [string]$Value
	return $out
}

function Get-OptionalProperty($Object, [string]$Name, $DefaultValue = $null) {
	if ($null -eq $Object) {
		return $DefaultValue
	}
	if ($Object.PSObject.Properties.Name -contains $Name) {
		return $Object.$Name
	}
	return $DefaultValue
}

function Get-SpanTopic($Label) {
	$text = [string]$Label
	if ($text -match 'peel|cleanse|cc_immunity|cc_prevented|cc_sync|debuff_cleanse|tenacity|cooldown_trade') {
		return "support_peel_cleanse_cc"
	}
	if ($text -match 'time_to_first_cc') {
		return "engage_cc_timing"
	}
	if ($text -match 'a_first_frac') {
		return "assassin_opening_presence"
	}
	if ($text -match 'team_fortification_buff_uptime') {
		return "team_fortification_buff_uptime"
	}
	if ($text -match 'backline_share|team_share|sustained_z|sustained_3_10s|team_damage_share|long_range_damage_share|pressure_without_exposure') {
		return "marksman_damage_positioning"
	}
	if ($text -match 'burst|execute|kill|peak_1s') {
		return "burst_execute_kill"
	}
	if ($text -match 'frontline|body_block|redirect|taunt|engage') {
		return "tank_redirect_frontline"
	}
	if ($text -match 'sustain(?!ed)|ehp_ratio') {
		return "sustain_survival"
	}
	if ($text -match 'targets_hit|aoe|wombo') {
		return "aoe_wombo_targeting"
	}
	if ($text -match 'step_tiles|displacement|backline_contact') {
		return "mobility_reposition"
	}
	if ($text -match 'direct_attrition') {
		return "brawler_direct_attrition"
	}
	if ($text -match 'magic_share') {
		return "magic_share"
	}
	if ($text -match 'ramp') {
		return "ramp_state"
	}
	return "other"
}

function Get-SupportPeelTriageGroup($Unit, $Label) {
	$topic = Get-SpanTopic $Label
	if ($topic -ne "support_peel_cleanse_cc") {
		return ""
	}
	$unitId = [string]$Unit
	switch ($unitId) {
		"axiom" { return "axiom_soft_peel_team_save_gap" }
		"paisley" { return "paisley_shield_peel_team_save_gap" }
		"totem" { return "totem_all_unit_scenario_threshold_gap" }
		"luna" { return "luna_wombo_cc_sync_gap" }
		"brute" { return "debuff_lockdown_counterplay_response_gap" }
		"grint" { return "debuff_lockdown_counterplay_response_gap" }
		"kythera" { return "debuff_lockdown_counterplay_response_gap" }
		"sari" { return "debuff_lockdown_counterplay_response_gap" }
		"volt" { return "debuff_lockdown_counterplay_response_gap" }
		default { return "support_peel_other" }
	}
}

function Get-SupportPeelGapKind($Label, $BlockType, $Block) {
	$text = [string]$Label
	$blockText = [string]$Block
	if ($text -match 'debuff_cleanse_bait_rate') {
		return "debuff_cleanse_bait_rate_below_target"
	}
	if ($text -match 'debuff_cleanse_pressure') {
		return "debuff_cleanse_pressure_absent"
	}
	if ($text -match 'debuff_cleanse_scenario_delta') {
		return "debuff_cleanse_scenario_delta_below_target"
	}
	if ($text -match 'debuff_cleanse') {
		return "debuff_counterplay_response_below_target"
	}
	if ($text -match 'lockdown_cleanse_scenario_delta') {
		return "lockdown_cleanse_scenario_delta_below_target"
	}
	if ($text -match 'lockdown_high_tenacity_effective_drop_s') {
		return "lockdown_high_tenacity_effective_drop_below_target"
	}
	if ($text -match 'lockdown_cleanse|tenacity') {
		return "lockdown_counterplay_response_below_target"
	}
	if ($text -match 'cc_sync') {
		return "wombo_cc_sync_absent"
	}
	if ($text -match 'subject_cc_immunity_cooldown_trade_efficiency') {
		return "cc_immunity_approach_cooldown_trade_below_target"
	}
	if ($text -match 'goal_peel_carry_cooldown_trade_efficiency') {
		return "peel_carry_goal_cooldown_trade_below_target"
	}
	if ($text -match 'cooldown_trade_efficiency') {
		return "cooldown_trade_quality_below_target"
	}
	if ($text -match 'cc_prevented') {
		return "cc_prevention_context_absent"
	}
	if ($text -match 'interrupt_events') {
		return "peel_interrupt_context_absent"
	}
	if ($text -match 'goal_peel_carry_peel_saves') {
		return "peel_carry_goal_save_proxy_absent"
	}
	if ($text -match 'team_peel_saves_total' -and $blockText -eq "peel") {
		return "peel_approach_team_save_proxy_absent"
	}
	if ($text -match 'peel_saves_med' -and $blockText -eq "support") {
		return "support_role_team_peel_proxy_absent"
	}
	if ($text -match 'peel_saves') {
		return "team_peel_save_proxy_absent"
	}
	if ($text -match 'cc_immunity|cleanse') {
		return "hard_peel_submode_absent"
	}
	return ""
}

function Get-SupportPeelNextAction($GapKind) {
	switch ([string]$GapKind) {
		"counterplay_response_below_target" { return "Tune cleanse/high-tenacity response composition, counterplay thresholds, or the debuff/lockdown tag if this identity should not require response-pressure proof." }
		"debuff_cleanse_bait_rate_below_target" { return "Tune enemy cleanse bait opportunities, bait-rate thresholds, or debuff tags for identities that should draw cleanse decisions." }
		"debuff_cleanse_pressure_absent" { return "Tune cleanse response composition or debuff application so counterplay pressure records at least one cleanse response." }
		"debuff_cleanse_scenario_delta_below_target" { return "Tune the neutral-vs-cleanse scenario pair, cleanse response composition, or scenario-delta threshold for debuff identities." }
		"debuff_counterplay_response_below_target" { return "Tune cleanse response composition, cleanse-pressure thresholds, or debuff tags for identities that should prove cleanse response pressure." }
		"lockdown_cleanse_scenario_delta_below_target" { return "Tune the neutral-vs-cleanse lockdown scenario pair, cleanse response composition, or scenario-delta threshold for lockdown identities." }
		"lockdown_high_tenacity_effective_drop_below_target" { return "Tune high-tenacity response composition, lockdown duration/effectiveness, or effective-drop threshold for lockdown identities." }
		"lockdown_counterplay_response_below_target" { return "Tune cleanse/high-tenacity response composition, lockdown counterplay thresholds, or lockdown tags for identities that should prove anti-CC response pressure." }
		"wombo_cc_sync_absent" { return "Decide whether wombo requires direct CC-sync evidence or whether burst/AoE aggregate evidence is sufficient." }
		"cc_immunity_approach_cooldown_trade_below_target" { return "Tune incoming-threat setup, CC-immunity response timing, or approach cooldown-trade threshold for Totem's CC-immunity evidence." }
		"peel_carry_goal_cooldown_trade_below_target" { return "Tune carry-threat setup, support response timing, or goal cooldown-trade threshold for Totem's peel-carry evidence." }
		"cooldown_trade_quality_below_target" { return "Tune the threat-response setup or the cooldown-trade efficiency threshold for the all-unit support scenario." }
		"cc_prevention_context_absent" { return "Create an incoming-CC threat context that can prove subject CC prevention, or keep it as optional quality evidence." }
		"peel_interrupt_context_absent" { return "Create an interruptible carry-threat context so peel-carry can prove direct interrupt evidence." }
		"peel_carry_goal_save_proxy_absent" { return "Create or tune a carry-threat scenario where peel-carry can earn direct goal-level peel-save attribution." }
		"peel_approach_team_save_proxy_absent" { return "Create or tune a live dive/carry-threat scenario that lets the peel approach fallback record team peel saves." }
		"support_role_team_peel_proxy_absent" { return "Treat this as a support-role proxy diagnostic unless support identity should require team peel-save attribution in addition to direct utility evidence." }
		"team_peel_save_proxy_absent" { return "Create a live dive/carry-threat scenario that can trigger team peel-save attribution." }
		"hard_peel_submode_absent" { return "Confirm whether this identity should prove hard peel through cleanse/CC immunity, then retag or add/tune direct evidence." }
		default { return "" }
	}
}

function Get-AuditGapKind($Topic, $Label, $BlockType, $Block) {
	$topicText = [string]$Topic
	$text = [string]$Label
	$blockText = [string]$Block
	if ($topicText -eq "support_peel_cleanse_cc") {
		return Get-SupportPeelGapKind $Label $BlockType $Block
	}
	if ($text -match 'backline_share') {
		return "backline_pressure_below_target"
	}
	if ($text -match 'goal_marksman_sustained_dps_team_damage_share') {
		return "marksman_sustained_goal_damage_share_below_target"
	}
	if ($text -match 'goal_marksman_sustained_dps_sustained_3_10s_team_share') {
		return "marksman_sustained_goal_window_share_below_target"
	}
	if ($text -match 'goal_marksman_sustained_dps_sustained_3_10s_rate') {
		return "marksman_sustained_goal_window_rate_below_target"
	}
	if ($text -match 'subject_team_damage_share_med') {
		return "marksman_role_subject_damage_share_diagnostic_below_target"
	}
	if ($text -match 'team_share_med') {
		return "marksman_role_candidate_team_share_diagnostic_below_target"
	}
	if ($text -match 'team_damage_share|team_share') {
		return "damage_share_below_target"
	}
	if ($text -match 'goal_wombo_combo_burst_peak_1s_share') {
		return "wombo_goal_peak_share_below_target"
	}
	if ($text -match 'subject_peak_1s_damage_share_med') {
		return "burst_approach_peak_share_below_target"
	}
	if ($text -match 'peak_1s') {
		return "peak_share_below_target"
	}
	if ($text -match 'pick_burst_kill_count') {
		return "pick_burst_kill_count_absent"
	}
	if ($text -match 'execute_bonus') {
		return "execute_bonus_share_absent"
	}
	if ($text -match 'body_block_events') {
		return "body_block_events_absent"
	}
	if ($text -match 'body_block_damage_prevented') {
		return "body_block_prevented_damage_absent"
	}
	if ($text -match 'body_block') {
		return "body_block_evidence_absent"
	}
	if ($text -match 'damage_taken_share') {
		return "frontline_damage_share_below_target"
	}
	if ($text -match 'engage_success_targets') {
		return "engage_success_targets_below_target"
	}
	if ($text -match 'redirect_explicit_threat_swap_events') {
		return "redirect_explicit_threat_swap_absent"
	}
	if ($text -match 'redirect_target_swap_events') {
		return "redirect_target_swap_absent"
	}
	if ($text -match 'redirect_taunt_events') {
		return "redirect_taunt_absent"
	}
	if ($text -match 'redirect') {
		return "redirect_threat_swap_or_taunt_absent"
	}
	if ($text -match 'time_to_first_cc') {
		return "engage_cc_timing_unproven"
	}
	if ($text -match 'subject_sustain_ehp_ratio') {
		return "sustain_approach_ehp_ratio_below_target"
	}
	if ($text -match 'subject_ehp_ratio' -and $blockText -eq "peel") {
		return "peel_approach_ehp_ratio_below_target"
	}
	if ($text -match 'subject_ehp_ratio' -and $blockText -eq "support") {
		return "support_role_subject_ehp_diagnostic_below_target"
	}
	if ($text -match '^ehp_ratio_') {
		return "support_role_team_ehp_proxy_below_target"
	}
	if ($text -match 'ehp_ratio') {
		return "effective_health_ratio_below_target"
	}
	if ($text -match 'targets_hit') {
		return "multi_target_coverage_below_target"
	}
	if ($text -match 'max_step_tiles') {
		return "movement_distance_below_target"
	}
	if ($text -match 'post_cast_displacement') {
		return "post_cast_displacement_below_target"
	}
	if ($text -match 'backline_contact') {
		return "dive_backline_contact_absent"
	}
	if ($text -match 'direct_attrition') {
		return "direct_attrition_evidence_below_target"
	}
	if ($text -match 'magic_share') {
		return "magic_damage_share_below_target"
	}
	if ($text -match 'goal_marksman_sustained_dps_ramp_stack_max') {
		return "marksman_sustained_goal_ramp_stack_below_target"
	}
	if ($text -match 'subject_ramp_stack_max') {
		return "ramp_approach_stack_below_target"
	}
	if ($text -match 'ramp') {
		return "ramp_stack_evidence_below_target"
	}
	if ($text -match 'a_first_frac') {
		return "assassin_opening_presence_below_target"
	}
	if ($text -match 'team_fortification_buff_uptime') {
		return "team_fortification_buff_uptime_absent"
	}
	return ""
}

function Get-AuditNextAction($GapKind) {
	switch ([string]$GapKind) {
		"backline_pressure_below_target" { return "Tune marksman targeting/positioning scenarios or thresholds so backline pressure is directly proven when the identity claims it." }
		"marksman_sustained_goal_damage_share_below_target" { return "Tune sustained-DPS marksman output, encounter duration, or the 0.25 goal threshold so the identity proves direct team damage share." }
		"marksman_sustained_goal_window_share_below_target" { return "Tune sustained-DPS output or the 3-10s sustained-pressure context so the identity proves windowed sustained team share." }
		"marksman_sustained_goal_window_rate_below_target" { return "Tune sustained-DPS output, encounter duration, or the 3-10s rate threshold so the identity proves sustained throughput after early burst." }
		"marksman_role_subject_damage_share_diagnostic_below_target" { return "Treat this as an auxiliary marksman subject damage-share diagnostic unless role identity should require subject-owned team share; tune output/scenario only if needed." }
		"marksman_role_candidate_team_share_diagnostic_below_target" { return "Treat this as an auxiliary marksman candidate/team-side share diagnostic unless role identity should require team-level carry share; tune output/scenario only if needed." }
		"marksman_role_damage_share_diagnostic_below_target" { return "Treat this as an auxiliary marksman role diagnostic unless the role contract should require team share; tune output/scenario only if the identity should carry more team damage." }
		"damage_share_below_target" { return "Tune damage output, encounter duration, or threshold expectations for identities that should prove team damage share." }
		"wombo_goal_peak_share_below_target" { return "Tune Paisley's Wombo Combo burst window, target grouping, or the 0.25 goal peak-share threshold." }
		"burst_approach_peak_share_below_target" { return "Tune burst ability windows, burst-tagged unit output, scenario grouping, or approach peak-share thresholds." }
		"peak_share_below_target" { return "Tune burst windows, scenario grouping, or peak-share thresholds for identities that should prove peak-share evidence." }
		"pick_burst_kill_count_absent" { return "Create or tune a pick-burst scenario where the subject can secure kills, or retune pick-burst goal requirements." }
		"execute_bonus_share_absent" { return "Create lower-health execute windows or retune execute attribution for identities that claim execute evidence." }
		"body_block_events_absent" { return "Create or tune a live frontline/body-block threat path that records direct body-block events for frontline-absorb identities." }
		"body_block_prevented_damage_absent" { return "Create or tune a live frontline/body-block threat path that records enough prevented damage for frontline-absorb identities." }
		"body_block_evidence_absent" { return "Create a live frontline/body-block threat path that records body-block events and prevented damage, or retune frontline requirements." }
		"frontline_damage_share_below_target" { return "Tune encounter focus, tank durability, or damage-share thresholds so frontline identities absorb enough pressure." }
		"engage_success_targets_below_target" { return "Tune engage setup, CC application, or success-target thresholds for initiate-fight identities." }
		"redirect_explicit_threat_swap_absent" { return "Create or tune explicit redirect threat-swap behavior, or retag if Korath should prove redirect through body-blocking rather than threat swapping." }
		"redirect_target_swap_absent" { return "Create or tune redirect contexts that cause enemies to swap targets onto the subject, or retune target-swap thresholds." }
		"redirect_taunt_absent" { return "Create or tune taunt-command redirect behavior, or retag if taunt is not an intended Korath redirect submode." }
		"redirect_threat_swap_or_taunt_absent" { return "Create redirect/taunt threat-swap contexts or retune redirect tags if explicit swaps are not required." }
		"engage_cc_timing_unproven" { return "Clarify and tune the engage timing scenario so first-CC evidence consistently proves the intended engage window." }
		"sustain_approach_ehp_ratio_below_target" { return "Tune self sustain, shield absorption, incoming-pressure scenario setup, or sustain EHP ratio threshold for sustain-tagged identities." }
		"peel_approach_ehp_ratio_below_target" { return "Tune peel shielding/healing, carry-threat pressure, or the peel EHP threshold when direct ally-protection evidence should not be the only pass path." }
		"support_role_subject_ehp_diagnostic_below_target" { return "Treat this as a support-role subject EHP diagnostic unless the support identity should require self/subject EHP proxy in addition to buffs, ally protection, or peel saves." }
		"support_role_team_ehp_proxy_below_target" { return "Tune team-level support healing/shield contribution, incoming-pressure setup, or support EHP proxy threshold if team EHP should be direct support proof." }
		"effective_health_ratio_below_target" { return "Tune sustain/protection output, survival pressure, or effective-health thresholds for this identity." }
		"multi_target_coverage_below_target" { return "Create clustered-target contexts or tune AoE targeting/radius thresholds for multi-target identities." }
		"movement_distance_below_target" { return "Tune movement/reposition ability output or distance thresholds for reposition-tagged identities." }
		"post_cast_displacement_below_target" { return "Tune post-cast displacement telemetry, ability behavior, or thresholds for reposition identities." }
		"dive_backline_contact_absent" { return "Create a backline-access dive context or retune the skirmish-dive goal if backline contact is optional." }
		"direct_attrition_evidence_below_target" { return "Tune direct attrition output or threshold expectations for brawler attrition identities." }
		"magic_damage_share_below_target" { return "Tune magic damage output/attribution or mage thresholds so magic share is directly proven." }
		"marksman_sustained_goal_ramp_stack_below_target" { return "Tune Sari's sustained-DPS ramp stack buildup, encounter duration, or the goal ramp-stack threshold." }
		"ramp_approach_stack_below_target" { return "Tune ramp-tagged approach stack buildup, stack generation, encounter duration, or approach ramp thresholds." }
		"ramp_stack_evidence_below_target" { return "Tune ramp stack buildup duration, stack generation, or thresholds for ramp-tagged identities." }
		"assassin_opening_presence_below_target" { return "Tune assassin opening access/targeting or role threshold expectations for first-action presence." }
		"team_fortification_buff_uptime_absent" { return "Create or tune a fortification context that records enough ally buff uptime for this tank goal." }
		default { return Get-SupportPeelNextAction $GapKind }
	}
}

function Count-By($Rows, $PropertyName) {
	$map = [ordered]@{}
	foreach ($row in $Rows) {
		$key = [string]$row.$PropertyName
		if (-not $map.Contains($key)) {
			$map[$key] = 0
		}
		$map[$key] = [int]$map[$key] + 1
	}
	return $map
}

function Join-UniqueValues($Rows, $PropertyName) {
	$values = @($Rows | ForEach-Object { [string]$_.$PropertyName } | Where-Object { $_ -ne "" } | Sort-Object -Unique)
	return $values -join ","
}

function Format-MarkdownCell($Value) {
	return ([string]$Value).Replace("|", "\|")
}

function Count-KeywordBuckets($Rows) {
	$buckets = [ordered]@{
		support_peel_cleanse_cc = 'peel|cleanse|cc_immunity|cc_prevented|cc_sync|debuff_cleanse|tenacity|cooldown_trade'
		engage_cc_timing = 'time_to_first_cc'
		assassin_opening_presence = 'a_first_frac'
		team_fortification_buff_uptime = 'team_fortification_buff_uptime'
		ramp_state = 'ramp'
		sustain_survival = 'sustain(?!ed)|ehp_ratio'
		marksman_damage_positioning = 'backline_share|team_share|sustained_z|team_damage_share|long_range_damage_share|pressure_without_exposure'
		burst_execute_kill = 'burst|execute|kill|peak_1s'
		tank_redirect_frontline = 'frontline|body_block|redirect|taunt|engage'
		aoe_wombo_targeting = 'targets_hit|aoe|wombo'
		mobility_reposition = 'step_tiles|displacement|backline_contact'
		brawler_direct_attrition = 'direct_attrition'
		magic_share = 'magic_share'
	}
	$out = [ordered]@{}
	foreach ($bucket in $buckets.Keys) {
		$pattern = $buckets[$bucket]
		$out[$bucket] = @($Rows | Where-Object { [string]$_.label -match $pattern }).Count
	}
	return $out
}

if (-not (Test-Path -LiteralPath $ReportDir)) {
	throw "ReportDir not found: $ReportDir"
}

$reports = @()
$ignored = @()
foreach ($file in Get-ChildItem -LiteralPath $ReportDir -Filter "*.json" | Sort-Object Name) {
	if ($IgnoredReportNames -contains $file.Name) {
		$ignored += $file.Name
		continue
	}
	$json = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
	$reports += [pscustomobject]@{
		File = $file
		Json = $json
	}
}

$rows = @()
$roleRates = @()
foreach ($report in $reports) {
	$j = $report.Json
	$identity = Get-OptionalProperty $j "assigned_identity" ([pscustomobject]@{})
	$approaches = Get-StringArray (Get-OptionalProperty $identity "approaches" @())
	$diagnostics = Get-OptionalProperty $j "diagnostics" ([pscustomobject]@{})
	$spans = @((Get-OptionalProperty $diagnostics "lower_level_fail_spans" @()))
	foreach ($span in $spans) {
		$label = [string](Get-OptionalProperty $span "label" "")
		$unitId = [string](Get-OptionalProperty $j "unit_id" "")
		$topic = Get-SpanTopic $label
		$blockType = [string](Get-OptionalProperty $span "block_type" "")
		$block = [string](Get-OptionalProperty $span "block" "")
		$supportGapKind = Get-SupportPeelGapKind $label $blockType $block
		$auditGapKind = Get-AuditGapKind $topic $label $blockType $block
		$rows += [pscustomobject]@{
			unit = $unitId
			role = [string](Get-OptionalProperty $identity "primary_role" "")
			goal = [string](Get-OptionalProperty $identity "primary_goal" "")
			approaches = ($approaches -join ",")
			cost = [int](Get-OptionalProperty $identity "cost" 0)
			block_type = $blockType
			block = $block
			metric_id = [string](Get-OptionalProperty $span "metric_id" "")
			label = $label
			value = Get-OptionalProperty $span "value" $null
			want = Get-OptionalProperty $span "want" $null
			reason = [string](Get-OptionalProperty $span "reason" "")
			subject_side = [string](Get-OptionalProperty $span "subject_side" "")
			topic = $topic
			audit_gap_kind = $auditGapKind
			audit_next_action = Get-AuditNextAction $auditGapKind
			support_peel_triage = Get-SupportPeelTriageGroup $unitId $label
			support_peel_gap_kind = $supportGapKind
			support_peel_next_action = Get-SupportPeelNextAction $supportGapKind
		}
	}
	$verdicts = Get-OptionalProperty $j "verdicts" $null
	$roles = Get-OptionalProperty $verdicts "roles" $null
	if ($roles) {
		foreach ($roleName in $roles.PSObject.Properties.Name) {
			$roleVerdict = $roles.$roleName
			$roleRates += [pscustomobject]@{
				unit = [string](Get-OptionalProperty $j "unit_id" "")
				role = [string]$roleName
				pass_rate = [double](Get-OptionalProperty $roleVerdict "pass_rate" 0.0)
				failed_span_count = [int](Get-OptionalProperty $roleVerdict "failed_span_count" 0)
			}
		}
	}
}

$unitsWithRows = @($rows | Select-Object -ExpandProperty unit -Unique | Sort-Object)
$allUnits = @($reports | ForEach-Object { [string](Get-OptionalProperty $_.Json "unit_id" "") } | Sort-Object)
$unitsWithoutRows = @($allUnits | Where-Object { $unitsWithRows -notcontains $_ })
$nonRampGoalRampCount = @($rows | Where-Object {
	$_.label -match '^goal_.*_ramp_' -and ($_.approaches -split ',') -notcontains 'ramp'
}).Count
$rampFailCount = @($rows | Where-Object { $_.label -match 'ramp' }).Count
$supportPeelRows = @($rows | Where-Object { [string]$_.support_peel_triage -ne "" })
$supportPeelTriageCounts = Count-By $supportPeelRows "support_peel_triage"
$supportPeelTriageSummary = ($supportPeelTriageCounts.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ', '
$supportPeelGapKindCounts = Count-By $supportPeelRows "support_peel_gap_kind"
$supportPeelGapKindSummary = ($supportPeelGapKindCounts.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ', '
$auditGapRows = @($rows | Where-Object { [string]$_.audit_gap_kind -ne "" })
$auditGapKindCounts = Count-By $auditGapRows "audit_gap_kind"
$auditGapKindSummary = ($auditGapKindCounts.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ', '
$primaryTopicCounts = Count-By $rows "topic"
$primaryTopicSummary = ($primaryTopicCounts.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ', '
$keywordBucketCounts = Count-KeywordBuckets $rows

if (-not (Test-Path -LiteralPath $OutputDir)) {
	New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

$csvPath = Join-Path $OutputDir "accepted_lower_level_fail_spans.csv"
$gapSummaryCsvPath = Join-Path $OutputDir "accepted_gap_kind_summary.csv"
$summaryPath = Join-Path $OutputDir "rga_accepted_misses_summary.json"
$readmePath = Join-Path $OutputDir "README.md"

$rows | Sort-Object unit, block_type, block, label | Export-Csv -LiteralPath $csvPath -NoTypeInformation

$gapSummaryRows = @($auditGapRows | Group-Object audit_gap_kind | Sort-Object -Property @{Expression="Count"; Descending=$true}, @{Expression="Name"; Descending=$false} | ForEach-Object {
	$groupRows = @($_.Group)
	$firstRow = $groupRows | Select-Object -First 1
	[pscustomobject]@{
		audit_gap_kind = [string]$_.Name
		count = [int]$_.Count
		topics = Join-UniqueValues $groupRows "topic"
		units = Join-UniqueValues $groupRows "unit"
		labels = Join-UniqueValues $groupRows "label"
		block_types = Join-UniqueValues $groupRows "block_type"
		next_action = [string]$firstRow.audit_next_action
	}
})
$gapSummaryRows | Export-Csv -LiteralPath $gapSummaryCsvPath -NoTypeInformation

$summary = [ordered]@{
	generated_at = (Get-Date).ToUniversalTime().ToString("o")
	source_report_dir = (Resolve-Path -LiteralPath $ReportDir).Path
	current_report_count = $reports.Count
	ignored_reports = $ignored
	current_units = $allUnits
	lower_level_fail_spans = $rows.Count
	units_with_any_lower_level_fail = $unitsWithRows
	units_without_lower_level_fail = $unitsWithoutRows
	block_type_counts = Count-By $rows "block_type"
	primary_topic_counts = $primaryTopicCounts
	keyword_bucket_counts = $keywordBucketCounts
	audit_gap_kind_counts = $auditGapKindCounts
	audit_gap_kind_details = @($gapSummaryRows | ForEach-Object {
		[ordered]@{
			audit_gap_kind = $_.audit_gap_kind
			count = $_.count
			topics = $_.topics
			units = $_.units
			labels = $_.labels
			block_types = $_.block_types
			next_action = $_.next_action
		}
	})
	support_peel_triage_counts = $supportPeelTriageCounts
	support_peel_gap_kind_counts = $supportPeelGapKindCounts
	highest_unit_fail_counts = @($rows | Group-Object unit | Sort-Object -Property @{Expression="Count"; Descending=$true}, @{Expression="Name"; Descending=$false} | ForEach-Object {
		[ordered]@{ unit = $_.Name; count = $_.Count }
	})
	lowest_role_pass_rates = @($roleRates | Sort-Object pass_rate, unit | Select-Object -First 12)
	ramp_fail_spans = $rampFailCount
	non_ramp_goal_ramp_spans = $nonRampGoalRampCount
}
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath

$gapSummaryMarkdown = @()
$gapSummaryMarkdown += "| Gap kind | Rows | Topics | Units | Next action |"
$gapSummaryMarkdown += "| --- | ---: | --- | --- | --- |"
foreach ($gapRow in $gapSummaryRows) {
	$gapSummaryMarkdown += ('| `{0}` | {1} | {2} | {3} | {4} |' -f
		(Format-MarkdownCell $gapRow.audit_gap_kind),
		[int]$gapRow.count,
		(Format-MarkdownCell $gapRow.topics),
		(Format-MarkdownCell $gapRow.units),
		(Format-MarkdownCell $gapRow.next_action)
	)
}

$readme = @(
	"# RoleMatrix Accepted Misses - 2026-06-25",
	"",
	'This artifact is generated from `user://identity_reports/*.json`, not raw console output.',
	"",
	"- Current reports: $($reports.Count)",
	"- Ignored reports: $($ignored -join ', ')",
	"- Subject-side accepted lower-level fail spans: $($rows.Count)",
	"- Units with at least one span: $($unitsWithRows.Count)",
	"- Ramp spans: $rampFailCount",
	"- Non-ramp goal-ramp spans: $nonRampGoalRampCount",
	"- Primary topic counts: $primaryTopicSummary",
	"- Audit gap kinds: $($gapSummaryRows.Count) groups covering $($rows.Count) spans",
	"- Support/peel triage: $supportPeelTriageSummary",
	"- Support/peel gap kinds: $supportPeelGapKindSummary",
	"",
	"Gap-kind summary:",
	""
)
$readme += $gapSummaryMarkdown
$readme += @(
	"",
	"Generated files:",
	'- `accepted_lower_level_fail_spans.csv`',
	'- `accepted_gap_kind_summary.csv`',
	'- `rga_accepted_misses_summary.json`',
	"",
	"Regenerate with:",
	"",
	'```powershell',
	'.\tests\rga_testing\tools\Export-AcceptedMisses.ps1',
	'```'
)
$readme | Set-Content -LiteralPath $readmePath

Write-Output ("accepted_misses_export reports={0} spans={1} ramp_spans={2} non_ramp_goal_ramp={3} out={4}" -f $reports.Count, $rows.Count, $rampFailCount, $nonRampGoalRampCount, $OutputDir)
