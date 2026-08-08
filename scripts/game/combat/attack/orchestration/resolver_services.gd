extends RefCounted
class_name ResolverServices

# ResolverServices
# Composes all attack-related services and exposes them for the resolver facade.

const CombatEventsLib := preload("res://scripts/game/combat/attack/support/combat_events.gd")
const AttackRollerLib := preload("res://scripts/game/combat/attack/roll/attack_roller.gd")
const AttackImpactLib := preload("res://scripts/game/combat/attack/impact/attack_impact.gd")
const ShieldServiceLib := preload("res://scripts/game/combat/attack/impact/shield_service.gd")
const BuffHooksImplLib := preload("res://scripts/game/combat/attack/impact/buff_hooks_tags_impl.gd")
const ProjectileEmitterLib := preload("res://scripts/game/combat/attack/projectile/projectile_emitter.gd")
const MultishotSelectorLib := preload("res://scripts/game/combat/attack/projectile/multishot_selector.gd")
const ManaOnAttackLib := preload("res://scripts/game/combat/attack/impact/mana_on_attack.gd")

const CombatStatsLib := preload("res://scripts/game/combat/attack/support/combat_stats.gd")
const CDServiceLib := preload("res://scripts/game/combat/attack/orchestration/cd_service.gd")
const FrameStatusCalculatorLib := preload("res://scripts/game/combat/attack/orchestration/frame_status_calculator.gd")
const PostHitCoordinatorLib := preload("res://scripts/game/combat/attack/orchestration/post_hit_coordinator.gd")
const ProjectilePolicyLib := preload("res://scripts/game/combat/attack/projectile/projectile_policy.gd")
const TargetAssignerLib := preload("res://scripts/game/combat/attack/orchestration/target_assigner.gd")
const OrderedAttackProcessorLib := preload("res://scripts/game/combat/attack/orchestration/ordered_attack_processor.gd")

# Exposed services
var events: CombatEvents
var roller: AttackRoller
var impact: AttackImpact
var shield_service: ShieldService
var hooks
var projectile_emitter: ProjectileEmitter
var multishot: MultishotSelector
var mana_service: ManaOnAttack

var cd_service: CDService
var stats: CombatStats
var frame_calc: FrameStatusCalculator
var post_hit: PostHitCoordinator
var projectile_policy: ProjectilePolicy
var target_assigner: TargetAssigner
var ordered_processor: OrderedAttackProcessor

func configure(state: BattleState, target_controller: TargetController, rng: RandomNumberGenerator, player_ref: Unit, emitters: Dictionary, ability_system: AbilitySystem, buff_system: BuffSystem, deterministic_rolls: bool, overrides: Dictionary = {}) -> void:
    # Wiring core events and helpers
    events = _maybe_override(overrides, KEYS.events, CombatEventsLib.new())
    events.configure(emitters)

    roller = _maybe_override(overrides, KEYS.roller, AttackRollerLib.new())
    roller.deterministic = deterministic_rolls

    hooks = _maybe_override(overrides, KEYS.hooks, BuffHooksImplLib.new())
    hooks.configure(buff_system)

    shield_service = _maybe_override(overrides, KEYS.shield_service, ShieldServiceLib.new())
    shield_service.configure(buff_system)

    impact = _maybe_override(overrides, KEYS.impact, AttackImpactLib.new())
    impact.configure(state, rng, hooks, shield_service)

    projectile_emitter = _maybe_override(overrides, KEYS.projectile_emitter, ProjectileEmitterLib.new())
    projectile_emitter.configure(events)

    multishot = _maybe_override(overrides, KEYS.multishot, MultishotSelectorLib.new())
    multishot.configure(rng, hooks)

    mana_service = _maybe_override(overrides, KEYS.mana_service, ManaOnAttackLib.new())
    mana_service.configure(state, ability_system, buff_system)

    # Secondary services
    cd_service = _maybe_override(overrides, KEYS.cd_service, CDServiceLib.new())
    cd_service.configure(state)

    stats = _maybe_override(overrides, KEYS.stats, CombatStatsLib.new())

    frame_calc = _maybe_override(overrides, KEYS.frame_calc, FrameStatusCalculatorLib.new())

    projectile_policy = _maybe_override(overrides, KEYS.projectile_policy, ProjectilePolicyLib.new())
    projectile_policy.configure(state, multishot, projectile_emitter, hooks)

    target_assigner = _maybe_override(overrides, KEYS.target_assigner, TargetAssignerLib.new())

    post_hit = _maybe_override(overrides, KEYS.post_hit, PostHitCoordinatorLib.new())
    post_hit.configure(state, events, stats, mana_service, cd_service, frame_calc, player_ref)

    ordered_processor = _maybe_override(overrides, KEYS.ordered_processor, OrderedAttackProcessorLib.new())
    ordered_processor.configure(state, target_controller, roller, projectile_policy, rng, target_assigner)

    _assert_service_shapes()

func teardown() -> void:
    events = null
    roller = null
    impact = null
    shield_service = null
    hooks = null
    projectile_emitter = null
    multishot = null
    mana_service = null
    cd_service = null
    stats = null
    frame_calc = null
    post_hit = null
    projectile_policy = null
    target_assigner = null
    ordered_processor = null

func _maybe_override(overrides: Dictionary, key: String, def):
    if overrides != null and overrides.has(key):
        var v: Variant = overrides[key]
        if v != null:
            return v
    return def

func _assert_service_shapes() -> void:
    assert(events != null and events.has_method("projectile_fired") and events.has_method("hit_applied") and events.has_method("unit_stat_changed") and events.has_method("log_line") and events.has_method("stats_snapshot") and events.has_method("team_stats"))
    assert(roller != null and roller.has_method("roll"))
    assert(impact != null and impact.has_method("apply_hit"))
    assert(shield_service != null and shield_service.has_method("absorb"))
    assert(projectile_emitter != null and projectile_emitter.has_method("fire"))
    assert(multishot != null and multishot.has_method("pick_base_target") and multishot.has_method("extra_targets"))
    assert(mana_service != null and mana_service.has_method("gain"))
    assert(cd_service != null and cd_service.has_method("cd_safe") and cd_service.has_method("other_cds") and cd_service.has_method("min_cd"))
    assert(stats != null and stats.has_method("reset_totals") and stats.has_method("begin_frame") and stats.has_method("totals") and stats.has_method("frame_damage_summary"))
    assert(frame_calc != null and frame_calc.has_method("update_after_hit"))
    assert(post_hit != null and post_hit.has_method("apply"))
    assert(projectile_policy != null and projectile_policy.has_method("emit_shots"))
    assert(target_assigner != null and target_assigner.has_method("assign_for_event"))
    assert(ordered_processor != null and ordered_processor.has_method("process"))
const KEYS := {
    "events": "events",
    "roller": "roller",
    "impact": "impact",
    "shield_service": "shield_service",
    "hooks": "hooks",
    "projectile_emitter": "projectile_emitter",
    "multishot": "multishot",
    "mana_service": "mana_service",
    "cd_service": "cd_service",
    "stats": "stats",
    "frame_calc": "frame_calc",
    "post_hit": "post_hit",
    "projectile_policy": "projectile_policy",
    "target_assigner": "target_assigner",
    "ordered_processor": "ordered_processor",
}
