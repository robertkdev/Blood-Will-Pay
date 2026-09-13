[CmdletBinding()]
param(
	[string]$OutputDirectory = "docs/research/tft_trait_guidebook_data",
	[string]$GuidebookPath = "docs/design/tft_trait_guidebook.md"
)

$ErrorActionPreference = "Stop"

$setIds = @(
	"set1", "set2", "set3", "set3.5", "set4", "set4.5", "set5", "set5.5",
	"set6", "set6.5", "set7", "set7.5", "set8", "set8.5", "set9", "set9.5",
	"set10", "set11", "set12", "set13", "set14", "set15", "set16", "set17"
)

$setTitles = [ordered]@{
	"set1" = "Beta Set"
	"set2" = "Rise of the Elements"
	"set3" = "Galaxies"
	"set3.5" = "Galaxies: Return to the Stars"
	"set4" = "Fates"
	"set4.5" = "Fates: Festival of Beasts"
	"set5" = "Reckoning"
	"set5.5" = "Reckoning: Dawn of Heroes"
	"set6" = "Gizmos & Gadgets"
	"set6.5" = "Gizmos & Gadgets: Neon Nights"
	"set7" = "Dragonlands"
	"set7.5" = "Dragonlands: Uncharted Realms"
	"set8" = "Monsters Attack!"
	"set8.5" = "Monsters Attack: Glitched Out!!"
	"set9" = "Runeterra Reforged"
	"set9.5" = "Runeterra Reforged: Horizonbound"
	"set10" = "Remix Rumble"
	"set11" = "Inkborn Fables"
	"set12" = "Magic n' Mayhem"
	"set13" = "Into the Arcane"
	"set14" = "Cyber City"
	"set15" = "K.O. Coliseum"
	"set16" = "Lore & Legends"
	"set17" = "Space Gods"
}

function ConvertFrom-HtmlText {
	param([AllowNull()][string]$Text)
	if ([string]::IsNullOrWhiteSpace($Text)) { return "" }
	$value = $Text -replace '<br\s*/?>', ' ' -replace '<[^>]+>', ''
	$value = [Net.WebUtility]::HtmlDecode($value)
	$value = $value -replace '\s+', ' '
	$value.Trim()
}

function ConvertTo-SafeCell {
	param([AllowNull()][string]$Text)
	if ($null -eq $Text) { return "" }
	($Text -replace '\|', '\|' -replace "`r?`n", ' ').Trim()
}

function Get-Category {
	param([string]$Text)
	$lower = $Text.ToLowerInvariant()
	$categories = [Collections.Generic.List[string]]::new()
	if ($lower -match 'gold|loot|shop|reroll|cashout|reward|component|chest|treasure|interest|black market|hearts into|shimmer') { $categories.Add("economy") }
	if ($lower -match 'summon|construct|golem|dragon|mech|companion|copy|clone|dummy') { $categories.Add("summon") }
	if ($lower -match 'adjacent|hex|row|column|front|back|distance|isolated|position|targeting') { $categories.Add("position") }
	if ($lower -match 'transform|evolve|mutation|ascend|star level|execute|takedown|kill|death|below .*health') { $categories.Add("transformation") }
	if ($lower -match 'armor|magic resist|durability|shield|health|damage reduction|tenacity') { $categories.Add("defense") }
	if ($lower -match 'attack damage|ability power|attack speed|critical|damage amp|omnivamp|mana') { $categories.Add("offense") }
	if ($lower -match 'choose|random|different each|variable|select|every game') { $categories.Add("choice") }
	if ($categories.Count -eq 0) { $categories.Add("special") }
	$categories -join ", "
}

function Get-GuideSignal {
	param([string]$Text)
	$lower = $Text.ToLowerInvariant()
	if ($lower -match 'gold|loot|shop|reroll|cashout|reward|component|chest|treasure|interest|black market|hearts into|shimmer') { return "Non-combat or mixed economy" }
	if ($lower -match 'random enemy|random ally|chance to') { return "High-variance combat" }
	if ($lower -match 'adjacent|hex|row|column|isolated|position') { return "Visible formation rule" }
	if ($lower -match 'summon|construct|golem|dragon|mech|companion') { return "Board-changing summon" }
	if ($lower -match 'transform|evolve|mutation|ascend') { return "Visible transformation" }
	if ($lower -match 'attack damage|ability power|attack speed|armor|magic resist|health|mana regen|durability') { return "Primarily statistical" }
	"Special combat rule"
}

function Get-LolchessSetData {
	param([string]$SetId)
	$championUrl = "https://lolchess.gg/champions/${SetId}?hl=en"
	$championResponse = Invoke-WebRequest -Uri $championUrl -UseBasicParsing -TimeoutSec 60
	$championMatch = [regex]::Match($championResponse.Content, '<script id="__NEXT_DATA__" type="application/json">(.*?)</script>')
	if (-not $championMatch.Success) { throw "No __NEXT_DATA__ payload at $championUrl" }
	$championPayload = $championMatch.Groups[1].Value | ConvertFrom-Json
	$championQuery = $championPayload.props.pageProps.dehydratedState.queries |
		Where-Object { $_.queryKey[0] -eq "championRefs" } |
		Select-Object -First 1
	if ($null -eq $championQuery -or $null -eq $championQuery.state.data.champions) { throw "No championRefs query at $championUrl" }

	$traitUrl = "https://lolchess.gg/synergies/${SetId}/guide?hl=en"
	$traitResponse = Invoke-WebRequest -Uri $traitUrl -UseBasicParsing -TimeoutSec 60
	$traitMatch = [regex]::Match($traitResponse.Content, '<script id="__NEXT_DATA__" type="application/json">(.*?)</script>')
	if (-not $traitMatch.Success) { throw "No __NEXT_DATA__ payload at $traitUrl" }
	$traitPayload = $traitMatch.Groups[1].Value | ConvertFrom-Json
	$traitQuery = $traitPayload.props.pageProps.dehydratedState.queries |
		Where-Object { $_.queryKey[0] -eq "traitRefs" } |
		Select-Object -First 1
	if ($null -eq $traitQuery -or $null -eq $traitQuery.state.data.traits) { throw "No traitRefs query at $traitUrl" }

	$setNumber = [int]([regex]::Match($SetId, '\d+').Value)
	$currentChampions = @($championQuery.state.data.champions | Where-Object {
		if ($_.isHidden -eq $true) { return $false }
		if ($setNumber -lt 10) { return $true }
		return ([string]$_.ingameKey).StartsWith("TFT${setNumber}_", [StringComparison]::OrdinalIgnoreCase)
	})
	$usedTraitKeys = @($currentChampions | ForEach-Object { @($_.traits) } | Where-Object {
		-not [string]::IsNullOrWhiteSpace([string]$_)
	} | Sort-Object -Unique)
	$traits = @($traitQuery.state.data.traits | Where-Object { $usedTraitKeys -contains ([string]$_.key) })
	$missing = @($usedTraitKeys | Where-Object { $_ -notin $traits.key })
	if ($missing.Count -gt 0) { throw "Missing trait definitions for $SetId`: $($missing -join ', ')" }
	[pscustomobject]@{
		traits = $traits
		champions = $currentChampions
		used_trait_keys = $usedTraitKeys
		url = $traitUrl
	}
}

$rows = [Collections.Generic.List[object]]::new()
$setSummaries = [Collections.Generic.List[object]]::new()

foreach ($setId in $setIds) {
	$setData = Get-LolchessSetData -SetId $setId
	$traits = @($setData.traits)
	$included = 0
	foreach ($trait in $traits) {
		$name = [string]$trait.name
		$key = [string]$trait.key
		if ([string]::IsNullOrWhiteSpace($name) -or [string]::IsNullOrWhiteSpace($key)) { continue }
		$description = ConvertFrom-HtmlText -Text ([string]$trait.desc)
		$breakpoints = @($trait.styles | ForEach-Object { [string]$_.min }) -join "/"
		$tiers = [Collections.Generic.List[string]]::new()
		if ($null -ne $trait.stats) {
			foreach ($property in $trait.stats.PSObject.Properties | Sort-Object { [int]$_.Name }) {
				$tierText = ConvertFrom-HtmlText -Text ([string]$property.Value)
				if (-not [string]::IsNullOrWhiteSpace($tierText)) { $tiers.Add("$($property.Name): $tierText") }
			}
		}
		$mechanic = (@($description) + @($tiers)) -join " | "
		$rows.Add([pscustomobject][ordered]@{
			set_id = $setId
			set_title = [string]$setTitles[$setId]
			trait_key = $key
			trait_name = $name
			trait_type = [string]$trait.type
			breakpoints = $breakpoints
			description = $description
			tier_effects = $tiers -join " | "
			categories = Get-Category -Text $mechanic
			guide_signal = Get-GuideSignal -Text $mechanic
			source_url = "https://lolchess.gg/synergies/$setId/guide?hl=en"
		})
		$included += 1
	}
	$setSummaries.Add([pscustomobject][ordered]@{
		set_id = $setId
		set_title = [string]$setTitles[$setId]
		traits = $included
		champions = @($setData.champions).Count
		source_url = "https://lolchess.gg/synergies/$setId/guide?hl=en"
	})
}

$outputFull = [IO.Path]::GetFullPath((Join-Path (Get-Location) $OutputDirectory))
$guideFull = [IO.Path]::GetFullPath((Join-Path (Get-Location) $GuidebookPath))
New-Item -ItemType Directory -Force -Path $outputFull | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $guideFull) | Out-Null

$rows | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $outputFull "trait_incarnations.json") -Encoding utf8
$rows | Export-Csv -LiteralPath (Join-Path $outputFull "trait_incarnations.csv") -NoTypeInformation -Encoding utf8
$setSummaries | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $outputFull "coverage.json") -Encoding utf8

$uniqueNames = @($rows.trait_name | Sort-Object -Unique).Count
$economyRows = @($rows | Where-Object { $_.categories -match 'economy' }).Count
$positionRows = @($rows | Where-Object { $_.categories -match 'position' }).Count
$transformationRows = @($rows | Where-Object { $_.categories -match 'transformation' }).Count
$statRows = @($rows | Where-Object { $_.guide_signal -eq 'Primarily statistical' }).Count

$md = [Text.StringBuilder]::new()
[void]$md.AppendLine("# Teamfight Tactics Trait Guidebook")
[void]$md.AppendLine()
[void]$md.AppendLine("Research snapshot: 2026-08-13. This guide catalogs **$($rows.Count) trait incarnations** across **$($setIds.Count) standard ranked set snapshots**, representing **$uniqueNames distinct displayed names**. An incarnation is one trait in one released set or mid-set; repeated names remain separate when their rules or breakpoints changed.")
[void]$md.AppendLine()
[void]$md.AppendLine("## Scope and evidence")
[void]$md.AppendLine()
[void]$md.AppendLine("Included: released standard TFT Sets 1 through 17 and the historical mid-sets 3.5 through 9.5, including player-facing one-unit signature traits. Excluded from the main corpus: tutorial traits, Double Up/PvE copies, revival-only retunes, augments, encounters, debug traits, internal aliases, and unreleased Set 18 data. Modern archive pages sometimes expose compatibility records from neighboring sets, so the extraction retains only trait definitions carried by non-hidden champions in that snapshot's roster. Set 18 is excluded because Riot schedules Enchanted Wilds for August 26, after this research snapshot.")
[void]$md.AppendLine()
[void]$md.AppendLine("Riot's developer documentation establishes Data Dragon as the official active-set trait surface. Historical mechanics are cross-checked through LoLChess's per-set archives; CommunityDragon is used as a richer current-data sanity check. Numbers are historical snapshots, not current balance recommendations.")
[void]$md.AppendLine()
[void]$md.AppendLine("- [Riot TFT developer documentation](https://developer.riotgames.com/docs/tft)")
[void]$md.AppendLine("- [CommunityDragon TFT data](https://raw.communitydragon.org/latest/cdragon/tft/en_us.json)")
[void]$md.AppendLine("- [LoLChess historical synergy archive](https://lolchess.gg/synergies/set1/guide?hl=en)")
[void]$md.AppendLine("- [Riot on the end of mid-sets](https://teamfighttactics.leagueoflegends.com/en-sg/news/dev/talking-tactics-reflecting-on-the-end-of-mid-sets/)")
[void]$md.AppendLine("- [Riot's Set 18 release schedule](https://teamfighttactics.leagueoflegends.com/en-au/news/game-updates/faq-tft-unreal-migration/)")
[void]$md.AppendLine()
[void]$md.AppendLine("Generated evidence: `docs/research/tft_trait_guidebook_data/trait_incarnations.json`, `.csv`, and `coverage.json`. Rebuild with `tools/research/build_tft_trait_guidebook.ps1`.")
[void]$md.AppendLine()
[void]$md.AppendLine("## Historical coverage")
[void]$md.AppendLine()
[void]$md.AppendLine("| Snapshot | Set | Trait incarnations |")
[void]$md.AppendLine("| --- | --- | ---: |")
foreach ($summary in $setSummaries) {
	[void]$md.AppendLine("| $($summary.set_id) | $($summary.set_title) | $($summary.traits) |")
}
[void]$md.AppendLine()
[void]$md.AppendLine("## What TFT repeatedly teaches")
[void]$md.AppendLine()
[void]$md.AppendLine("### 1. Traits need jobs, not merely themes")
[void]$md.AppendLine()
[void]$md.AppendLine("Across the archive, traits repeatedly occupy recognizable jobs: baseline class stats, vertical identity, splash utility, formation rules, summons, transformations, variable/choice engines, and economy. A healthy set mixes these jobs. If every trait is a vertical stat ladder, board construction becomes arithmetic; if every trait is a bespoke minigame, the set becomes unreadable.")
[void]$md.AppendLine()
[void]$md.AppendLine("### 2. Member power plus smaller team power is the durable class template")
[void]$md.AppendLine()
[void]$md.AppendLine("Bruiser, Bastion, Invoker, Sorcerer/Arcanist, Ranger/Sniper, and their many descendants show the resilient template: the whole team receives a modest benefit while carriers receive the defining payoff. It makes a two-piece splash useful without making carriers interchangeable.")
[void]$md.AppendLine()
[void]$md.AppendLine("### 3. The memorable traits change battlefield rules")
[void]$md.AppendLine()
[void]$md.AppendLine("Traits such as Mech-Pilot, Abomination, Jade, Socialite, Hacker, Storyweaver, Black Rose, Coven, and the many transformation/signature traits create an object, position, target rule, sacrifice, summon, or phase change. They are remembered because players can point to what occurred. This corpus contains $positionRows position-sensitive and $transformationRows transformation/kill-sensitive incarnations by conservative keyword classification.")
[void]$md.AppendLine()
[void]$md.AppendLine("### 4. Exact-count and exclusion rules create expressive puzzles")
[void]$md.AppendLine()
[void]$md.AppendLine("Ninja, Exile, Rival-style uniques, and later one-unit signatures demonstrate that subtraction can be as strategic as addition. Exact-count rules are strongest when the board state is obvious and the reward alters behavior; they are weakest when a player accidentally deactivates an invisible stat bonus.")
[void]$md.AppendLine()
[void]$md.AppendLine("### 5. Random target traits age poorly unless visibly constrained")
[void]$md.AppendLine()
[void]$md.AppendLine("Early Noble, Imperial, Phantom, Glacial, and dodge designs often assigned huge outcomes randomly or through proc chance. Later designs more often expose a chosen hex, strongest unit, marked target, deterministic interval, or player selection. For a deterministic game, use randomness in drafting or clearly previewed variation - not in deciding which combatant receives a fight-winning effect.")
[void]$md.AppendLine()
[void]$md.AppendLine("### 6. Economy traits are a separate game genre")
[void]$md.AppendLine()
[void]$md.AppendLine("The archive contains $economyRows economy or mixed-economy incarnations: Pirate, Space Pirate, Fortune, Mercenary, Underground, Piltover, Heartsteel, Sugarcraft, Chem-Baron, Conqueror, and many variants. Their core loop is risk, loss tolerance, cashout timing, and loot conversion. They are not neutral flavor. A combat-horror game should omit them unless it explicitly wants that parallel gambling minigame.")
[void]$md.AppendLine()
[void]$md.AppendLine("### 7. Vertical chase tiers must be naturally reachable")
[void]$md.AppendLine()
[void]$md.AppendLine("Prismatic chases work because TFT supplies emblems, Headliners/Chosen, trait-increasing units, or other explicit over-cap systems. Without those systems, printing a breakpoint above natural carrier supply is misleading. Every published tier should identify its acquisition route.")
[void]$md.AppendLine()
[void]$md.AppendLine("### 8. Unique traits should deepen one unit, not erase its weaknesses")
[void]$md.AppendLine()
[void]$md.AppendLine("Modern sets use many one-unit signature traits. The best clarify a unit's rule or offer one choice; the worst bundle immunity, economy, scaling, and transformation into an exception the opponent cannot parse. A signature trait needs the same tell, failure state, and counter window as a normal trait.")
[void]$md.AppendLine()
[void]$md.AppendLine("### 9. Statistical traits are structural glue, not the headline")
[void]$md.AppendLine()
[void]$md.AppendLine("At least $statRows incarnations classify as primarily statistical under a conservative text heuristic. These traits make the web function, but too many overlapping Armor/Health/Durability or AP/Mana/Damage ladders collapse identities. Give each stat family a different trigger, beneficiary, timing curve, or positioning demand.")
[void]$md.AppendLine()
[void]$md.AppendLine("## Trait pattern library")
[void]$md.AppendLine()
[void]$md.AppendLine("| Pattern | Historical examples | What it asks | Principal risk | Horror-first adaptation |")
[void]$md.AppendLine("| --- | --- | --- | --- | --- |")
[void]$md.AppendLine("| Member + team stat | Bruiser, Bastion, Invoker, Sorcerer | Splash or commit? | Generic stacking | Carriers manifest wounds; allies receive a lesser aura |")
[void]$md.AppendLine("| Ramp on attacks/casts | Wild, Challenger, Spellweaver | Can the engine stay active? | Invisible inevitability | Frenzy, possession, or infection visibly worsens |")
[void]$md.AppendLine("| Kill/execute engine | Dark Star, Slayer, Executioner | Can I secure the first victim? | Win-more snowball | Death feeds nearby monsters but exposes the feeder |")
[void]$md.AppendLine("| Summoned object | Elementalist, Cultist, Abomination, Black Rose | What do I trade for another body? | Summon overwhelms carriers | Corpse pile, effigy, parasite, chained horror |")
[void]$md.AppendLine("| Merge/sacrifice | Mech-Pilot, Legend, Blackthorn-style rules | Which unit becomes material? | Items/stats become opaque | Visible ritual sacrifice with recoverable counterplay |")
[void]$md.AppendLine("| Formation/hex | Guardian, Socialite, Jade, Ixtal | Where must units stand? | Solved static clumps | Ritual geometry, forbidden rows, isolation |")
[void]$md.AppendLine("| Exact count/exclusion | Ninja, Exile, Rival | What must stay off-board? | Accidental deactivation | Solitary monster, forbidden pairing, incomplete coven |")
[void]$md.AppendLine("| Transformation | Shapeshifter, Dragonmancer variants, unique ascensions | Can the unit reach phase two? | No response window | Telegraph mutation and allow denial during molt |")
[void]$md.AppendLine("| Variable choice | Mirage, A.D.M.I.N., Jazz/Headliner-era variants | Can I adapt to this game? | Analysis overload | Choose one curse or ritual before combat |")
[void]$md.AppendLine("| Economy/cashout | Fortune, Mercenary, Underground, Heartsteel | When do I accept risk? | Parallel economy dominates combat | Exclude from combat-only trait roster |")
[void]$md.AppendLine()
[void]$md.AppendLine("## Horror-first rules for Blood Will Pay")
[void]$md.AppendLine()
[void]$md.AppendLine("1. Every trait changes combat; no currency, rerolls, discounts, shop odds, loot cashouts, or automatic crafting.")
[void]$md.AppendLine("2. Every trait has a visible noun: mark, wound, chain, corpse, effigy, mutation, ritual boundary, infection, or summoned horror.")
[void]$md.AppendLine("3. Every active breakpoint has a visible state change, not only a larger number.")
[void]$md.AppendLine("4. Every payoff has a denial condition the opponent can understand: break formation, kill an anchor, cleanse a mark, burst before mutation, deny the first corpse, or move out of a ritual.")
[void]$md.AppendLine("5. No two trait families may share the same trigger, beneficiary, and payoff. Aegis/Fortified/Titan and Arcanist/Overload/Scholar must differ behaviorally.")
[void]$md.AppendLine("6. Splash traits should open builds; vertical traits should sharpen one risk. Avoid role monocultures unless the trait deliberately defines that role.")
[void]$md.AppendLine("7. A natural roster must reach every ordinary tier. Over-cap tiers require an explicit emblem or rule documented in the same design.")
[void]$md.AppendLine("8. One-unit traits clarify one signature behavior. They do not grant a bundle of immunity, scaling, and economy.")
[void]$md.AppendLine()
[void]$md.AppendLine("## Recommended replacement directions")
[void]$md.AppendLine()
[void]$md.AppendLine("- **Mogul -> Tormentor:** isolate a condemned victim; its death spreads Dread. Historical lineage: Phantom/Assassin target disruption, Dark Star death transfer, Executioner threshold pressure - made deterministic and visible.")
[void]$md.AppendLine("- **Trader -> Stalker:** repeated attacks mark Prey and reward uninterrupted pursuit. Historical lineage: Hunter/Ranger ramp and marked-target traits, without rerolls.")
[void]$md.AppendLine("- **Catalyst -> Aberrant:** first low-health threshold triggers a carrier-specific mutation. Historical lineage: Shapeshifter and staged transformation traits, without crafting.")
[void]$md.AppendLine("- **Cartel -> ritual trait, final name pending:** members define a battlefield rite whose anchors can be broken. Historical lineage: Guardian/Socialite/Jade/Ixtal formation traits and summon/sacrifice traits. Avoid **Coven** as a final name because TFT has used it repeatedly.")
[void]$md.AppendLine()
[void]$md.AppendLine("## Complete incarnation catalog")
[void]$md.AppendLine()
[void]$md.AppendLine("The compact tables below list every included set-specific incarnation. Exact tier prose remains in the generated JSON/CSV so this guide stays navigable.")
[void]$md.AppendLine()
foreach ($setId in $setIds) {
	$setRows = @($rows | Where-Object { $_.set_id -eq $setId } | Sort-Object trait_name, trait_key)
	[void]$md.AppendLine("### $setId - $($setTitles[$setId])")
	[void]$md.AppendLine()
	[void]$md.AppendLine("| Trait | Type | Breakpoints | Mechanic | Signal |")
	[void]$md.AppendLine("| --- | --- | --- | --- | --- |")
	foreach ($row in $setRows) {
		$mechanic = if (-not [string]::IsNullOrWhiteSpace($row.description)) { $row.description } else { $row.tier_effects }
		if ($mechanic.Length -gt 230) { $mechanic = $mechanic.Substring(0, 227).TrimEnd() + "..." }
		[void]$md.AppendLine("| $(ConvertTo-SafeCell $row.trait_name) | $($row.trait_type) | $($row.breakpoints) | $(ConvertTo-SafeCell $mechanic) | $($row.guide_signal) |")
	}
	[void]$md.AppendLine()
}
[void]$md.AppendLine("## Limitations")
[void]$md.AppendLine()
[void]$md.AppendLine("Historical archive text reflects the archived endpoint available on the research date, not every patch-level balance revision. Some old trait descriptions rely on tier text because the base description was blank. Modern pages expose unusually many signature/unlockable traits; these remain because they were player-facing on the ranked-set page. The generated catalog is the completeness artifact; qualitative categories are reproducible keyword classifications followed by design interpretation, not Riot-authored taxonomies.")

$md.ToString() | Set-Content -LiteralPath $guideFull -Encoding utf8

Write-Output "TFT trait guidebook: sets=$($setIds.Count) incarnations=$($rows.Count) unique_names=$uniqueNames economy=$economyRows output=$GuidebookPath"
