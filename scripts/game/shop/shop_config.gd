extends Object
class_name ShopConfig

# Single source of truth for shop-related constants.
# Keep data-only and minimal; no logic here.

# Slots and general behavior
const SLOT_COUNT := 5                              # Number of offers shown per shop refresh
const ALLOW_DUPLICATES := true                    # PVE: duplicates allowed in a single shop
const REPLACE_PURCHASE_WITH_EMPTY := true         # Purchased slots become SOLD/EMPTY placeholders
const FIRST_SHOP_HELPERS_BY_STARTER: Dictionary = {
    "axiom": ["sari"],
    "bo": ["berebell", "grint"],
    "bonko": ["morrak", "grint", "mortem"],
    "cashmere": ["brute", "bonko"],
    "korath": ["bonko", "sari", "morrak", "berebell"],
    "knoll": ["sari", "brute", "grint", "bonko", "morrak"],
    "morrak": ["berebell", "sari", "bonko"],
    "mortem": ["morrak", "bonko", "sari", "berebell"],
    "pilfer": ["brute", "bonko", "grint", "morrak", "sari"],
    "repo": ["berebell", "bonko", "sari"],
    "sari": ["bonko", "grint", "brute", "berebell", "morrak"],
}
const FIRST_SHOP_BLOCKED_HELPERS_BY_STARTER: Dictionary = {
    "axiom": ["axiom", "repo", "grint", "korath", "brute", "bo", "bonko", "morrak", "berebell", "mortem", "cashmere"],
    "bo": ["cashmere", "brute", "axiom"],
    "bonko": ["axiom", "repo", "korath"],
    "cashmere": ["korath", "repo", "axiom"],
    "korath": ["brute", "axiom"],
    "knoll": ["axiom", "knoll", "pilfer"],
    "morrak": ["repo", "brute", "korath", "grint"],
    "mortem": ["brute", "axiom"],
    "pilfer": ["axiom", "knoll", "pilfer"],
    "repo": ["axiom", "mortem", "korath", "brute", "cashmere", "grint", "repo"],
    "sari": ["axiom"],
}

# Reroll and XP/Command costs are expressed in current Stakes units.
const REROLL_STAKE_UNITS: int = 2
const PROGRESSION_STAKE_UNITS: int = 4
# Compatibility aliases for early-game tests where U = 1.
const REROLL_COST: int = REROLL_STAKE_UNITS
const BUY_XP_COST: int = PROGRESSION_STAKE_UNITS
const XP_PER_BUY := 4                             # XP granted per purchase
const COMMAND_POINTS_PER_BUY: int = 1
const OPENING_HELPER_GUARDED_SHOPS := 1           # Guarantee the first post-opener helper, then return to normal variety

# Player level band
const STARTING_LEVEL := 1
const MIN_LEVEL := 1
const MAX_LEVEL := 14                             # 3 starting slots + 13 level-ups = 16 max board slots
const DEFAULT_BOARD_CAPACITY := 3                 # New runs start with three usable board slots
const MAX_BOARD_CAPACITY: int = 16                # Physical/readability ceiling; contracts cannot exceed it
const POST_OPENING_MIN_TEAM_SIZE := DEFAULT_BOARD_CAPACITY
const POST_OPENING_TEAM_SIZE_BONUS := 0           # Board slots now come from DEFAULT_BOARD_CAPACITY + player levels
const EARLY_RUN_CAP_FLOOR_STAGE := 3              # By the second shop, bought bench units should be deployable
const EARLY_RUN_CAP_FLOOR_TEAM_SIZE := 3
const EARLY_LEVEL_TWO_CAP_FLOOR_STAGE := 3        # By the second shop, Buy XP should create a real board-slot payoff
const EARLY_LEVEL_TWO_CAP_FLOOR_TEAM_SIZE := 4
const CHAPTER_TWO_CAP_FLOOR_STAGE := 7            # Chapter 2 round 2 should let roster depth break retry loops
const CHAPTER_TWO_CAP_FLOOR_TEAM_SIZE := 6
const CHAPTER_THREE_CAP_FLOOR_STAGE := 12         # Chapter 3 should let accumulated bench depth matter before normal fights
const CHAPTER_THREE_CAP_FLOOR_TEAM_SIZE := 7
const CHAPTER_FOUR_CAP_FLOOR_STAGE := 17          # Late chapters should not strand a full bench at the same board cap
const CHAPTER_FOUR_CAP_FLOOR_TEAM_SIZE := 8
const CHAPTER_FIVE_CAP_FLOOR_STAGE := 22
const CHAPTER_FIVE_CAP_FLOOR_TEAM_SIZE := 9

# XP required to go from (level-1) -> level. Keys are target level.
# Example: reaching level 3 requires XP_TO_REACH_LEVEL[3] total XP from level 2.
const XP_TO_REACH_LEVEL := {
    2: 2,
    3: 6,
    4: 10,
    5: 16,
    6: 24,
    7: 40,
    8: 64,
    9: 100,
    10: 154,
    11: 232,
    12: 344,
    13: 504,
    14: 728,
}

# Lock rules
const LOCK_PERSISTS_ACROSS_INTERMISSION := true   # Locked shop persists across PREVIEW/POST_COMBAT
const CLEAR_LOCK_ON_REROLL := true                # Any manual reroll clears lock
const CLEAR_LOCK_ON_NEW_RUN := true               # Starting a new run clears lock

# Minimal roll odds by player level. Probabilities per cost tier sum to 1.0.
# Current content spans 1-cost foundations through 5-cost capstones.
const VALID_COSTS := [1, 2, 3, 4, 5]
const ODDS_BY_LEVEL := {
    1: {1: 1.00},
    2: {1: 0.80, 2: 0.20},
    3: {1: 0.65, 2: 0.30, 3: 0.05},
    4: {1: 0.50, 2: 0.35, 3: 0.13, 4: 0.02},
    5: {1: 0.36, 2: 0.38, 3: 0.20, 4: 0.05, 5: 0.01},
    6: {1: 0.25, 2: 0.32, 3: 0.27, 4: 0.13, 5: 0.03},
    7: {1: 0.20, 2: 0.28, 3: 0.30, 4: 0.17, 5: 0.05},
    8: {1: 0.16, 2: 0.24, 3: 0.31, 4: 0.21, 5: 0.08},
    9: {1: 0.12, 2: 0.20, 3: 0.31, 4: 0.25, 5: 0.12},
    10: {1: 0.09, 2: 0.17, 3: 0.30, 4: 0.28, 5: 0.16},
    11: {1: 0.07, 2: 0.14, 3: 0.28, 4: 0.31, 5: 0.20},
    12: {1: 0.05, 2: 0.11, 3: 0.25, 4: 0.34, 5: 0.25},
    13: {1: 0.04, 2: 0.08, 3: 0.22, 4: 0.36, 5: 0.30},
    14: {1: 0.03, 2: 0.06, 3: 0.18, 4: 0.38, 5: 0.35},
}

# Fallback behavior for undefined levels (e.g., clamp to last defined)
const DEFAULT_ROLL_LEVEL := STARTING_LEVEL

# Debug toggles (off by default)
const DEBUG_VERBOSE := false
const DEBUG_SEED := -1     # Set to >=0 to fix RNG seed
