extends RefCounted
## Pure geometry for the composed planning screen.
##
## The planning screen reads as assembled strips when the bench, status line,
## wager controls and shop each claim their own full-width row. This helper
## returns the numbers for one authored base instead: equal support rails, a
## floor raster that keeps the field column, deployment grids inscribed into
## that raster, and a lower dock split into a shop territory, a wager column and
## an action bay holding one concentrated primary plaque.
##
## It owns no nodes and no gameplay meaning. The game is authored for one
## fullscreen size, so every metric below is a single authored number: there is
## no interface scale to divide out and no resize tier to satisfy.
class_name PlanningComposition

## The dock is budgeted in framebuffer pixels, so the band owns a fixed share of
## the fullscreen composition instead of chasing the field.
const DOCK_PHYSICAL_TARGET: float = 270.0
const DOCK_PHYSICAL_MIN: float = 250.0
const DOCK_PHYSICAL_MAX: float = 280.0
## The band never collapses past this height even on a short fullscreen display.
const DOCK_MIN_HEIGHT: float = 150.0
const DOCK_MAX_VIEWPORT_SHARE: float = 0.34
const DOCK_MARGIN: float = 12.0
## Shared material rule: the gameplay panel surface carries 40px nine-slice
## bands, so it is only safe on surfaces at least this tall.
const MIN_PANEL_SURFACE_HEIGHT: float = 80.0

## Equal support rails as one authored mass. `SIDE_RAIL_PHYSICAL` is published
## to the theme owner through CombatView's composition metadata, which is the
## marker to use when removing competing outer minima.
const SIDE_RAIL_PHYSICAL: float = 308.0

## The primary plaque keeps its authored physical size inside a quieter bay.
const PLAQUE_PHYSICAL: Vector2 = Vector2(280.0, 157.0)
const PLAQUE_ASPECT: float = 16.0 / 9.0
const PLAQUE_BAY_PADDING_PHYSICAL: float = 18.0
## The action bay hugs the plaque instead of taking a share of the band.
const BAY_PHYSICAL_MIN: float = 316.0
const BAY_PHYSICAL_MAX: float = 344.0
## The wager column must be wide enough for its complete content, not for a
## share of the band: a too-narrow column wrapped the quote and grew taller than
## the dock.
const WAGER_CONTENT_PHYSICAL: float = 300.0

## Row metrics that hold controls are authored against the fullscreen size.
const SHOP_HEADER_HEIGHT: float = 44.0
const SHOP_CARD_MIN_HEIGHT: float = 104.0
const SHOP_CARD_MAX_HEIGHT: float = 232.0
const DOCK_GUTTER_HEIGHT: float = 10.0
## The composed dock keeps the authored compact gutter contract: the shop header
## and the card row stay far enough apart to read as separate territories, and
## the cards keep pointer-clear gutters between them.
const DOCK_SEPARATION_HEIGHT: float = 10.0
const CARD_GAP: float = 12.0
## Architectural gaps between territories stay physical.
const DOCK_GAP_PHYSICAL: float = 12.0
## The band must leave a small framebuffer gutter below itself.
const DOCK_BOTTOM_GUTTER_PHYSICAL: float = 8.0
## Card cells read as taller than they are wide.
const CARD_ASPECT: float = 0.92
const SHOP_MIN_CARD_PHYSICAL: float = 150.0
const MIN_WAGER_PHYSICAL: float = 264.0

const BENCH_GAP: float = 8.0
const BENCH_MAX_TILE_PHYSICAL: float = 88.0
const BENCH_MIN_TILE_PHYSICAL: float = 46.0

const BOARD_COLUMNS: int = 8
const BOARD_GAP: float = 8.0
const BOARD_PLANNING_SEPARATION: float = 8.0
## The floor raster keeps the whole field column; the grids are inscribed into
## its central share so braziers and walls stay visible on the floor.
const BOARD_RASTER_SHARE: float = 0.76
const BOARD_TILE_MIN_PHYSICAL: float = 64.0
const BOARD_MAX_TILE_HEIGHT_PHYSICAL: float = 108.0
## Floor left visible under the last row, so figure feet stand on stone.
const BOARD_FOOT_PAD_PHYSICAL: float = 22.0

## Full-HD planning is the authored composition target: 1920x1080 takes the
## composed dock.
static func is_full_hd_dock(viewport_size: Vector2) -> bool:
	return viewport_size.x >= 1680.0 and viewport_size.y >= 1000.0

static func dock_height(viewport_size: Vector2) -> float:
	var physical_target: float = clampf(DOCK_PHYSICAL_TARGET, DOCK_PHYSICAL_MIN, DOCK_PHYSICAL_MAX)
	var share_limit: float = maxf(DOCK_MIN_HEIGHT, viewport_size.y * DOCK_MAX_VIEWPORT_SHARE)
	return clampf(physical_target, DOCK_MIN_HEIGHT, share_limit)

## The band a given dock height can actually hold: header, one card cell, the
## footer gutter and the two separations.
static func authored_dock_height(dock_height_value: float) -> float:
	return SHOP_HEADER_HEIGHT + shop_card_height(dock_height_value) + DOCK_GUTTER_HEIGHT + DOCK_SEPARATION_HEIGHT * 2.0

static func dock_gap() -> float:
	return DOCK_GAP_PHYSICAL

static func dock_bottom_gutter() -> float:
	return DOCK_BOTTOM_GUTTER_PHYSICAL

static func side_rail_width() -> float:
	return SIDE_RAIL_PHYSICAL

static func shop_header_height() -> float:
	return SHOP_HEADER_HEIGHT

static func shop_separation() -> float:
	return DOCK_SEPARATION_HEIGHT

static func shop_card_gap() -> float:
	return CARD_GAP

static func shop_gutter_height() -> float:
	return DOCK_GUTTER_HEIGHT

static func minimum_wager_width() -> float:
	return MIN_WAGER_PHYSICAL

static func wager_content_width() -> float:
	return WAGER_CONTENT_PHYSICAL

static func bay_width_for(plaque_width: float) -> float:
	return clampf(plaque_width + PLAQUE_BAY_PADDING_PHYSICAL * 2.0, BAY_PHYSICAL_MIN, BAY_PHYSICAL_MAX)

## The dock's territory allocation. Nothing grows to absorb slack: the wager is
## sized by its content, the bay is the plaque's close fit, the shop keeps its
## authored portrait cells, and the gaps are the authored separation. Whatever
## the band has left over stays as environment beside the territories, so no
## territory is inflated and no minimum changes to chase the free space.
## When the band is short the order of concession is explicit and recorded:
## shop keeps its authored cells, then the bay trims toward its minimum, then the
## wager trims to its content minimum, and only then does the shop shrink.
static func dock_allocation(content_width: float, shop_authored: float, wager_content_min: float, wager_insets: float) -> Dictionary:
	var gap: float = dock_gap()
	# The wager's requirement is its real content plus the insets the nested
	# containers actually apply (panel style margins plus the padding box), not the
	# content alone: a minimum is a floor, so a territory that ignores its insets
	# still lets the content draw past the panel edge.
	var wager_floor: float = maxf(maxf(minimum_wager_width(), wager_content_width()), wager_content_min + wager_insets + shop_separation() * 2.0)
	var wager: float = wager_floor
	var plaque: Vector2 = plaque_size()
	var bay: float = bay_width_for(plaque.x)
	var reason: String = ""
	var shop: float = shop_authored
	var used: float = shop + wager + bay + gap * 2.0
	if used > content_width:
		var deficit: float = used - content_width
		if deficit > 0.0:
			var bay_trim: float = minf(deficit, maxf(0.0, bay - bay_width_for(plaque.x) * 0.75))
			bay -= bay_trim
			deficit -= bay_trim
			reason = "bay_trimmed"
		if deficit > 0.0:
			# Never concede below the true nested minimum: content plus the panel and
			# padding insets, not content alone.
			var wager_true_min: float = wager_content_min + wager_insets + shop_separation()
			var wager_trim: float = minf(deficit, maxf(0.0, wager - wager_true_min))
			wager -= wager_trim
			deficit -= wager_trim
			reason = "wager_trimmed_to_content"
		if deficit > 0.0:
			shop = maxf(1.0, shop - deficit)
			reason = "shop_below_authored"
		used = shop + wager + bay + gap * 2.0
	return {
		"shop": shop,
		"wager": wager,
		"bay": bay,
		"gap": gap,
		"plaque": plaque,
		"reason": reason,
		"used": used,
		"residual_environment": maxf(0.0, content_width - used),
	}

static func shop_card_height(dock_height_value: float) -> float:
	var reserved: float = SHOP_HEADER_HEIGHT + DOCK_GUTTER_HEIGHT + DOCK_SEPARATION_HEIGHT * 2.0
	return clampf(dock_height_value - reserved, SHOP_CARD_MIN_HEIGHT, SHOP_CARD_MAX_HEIGHT)

## Card width follows the cell height, so the five cells stay taller than wide.
static func shop_card_width(card_height: float) -> float:
	return floorf(maxf(96.0, card_height * CARD_ASPECT))

static func shop_width_for(card_width: float, slots: int, gap: float) -> float:
	return card_width * float(maxi(1, slots)) + gap * float(maxi(0, slots - 1))

static func min_shop_width(slots: int, gap: float) -> float:
	var card: float = SHOP_MIN_CARD_PHYSICAL
	return card * float(maxi(1, slots)) + gap * float(maxi(0, slots - 1))

## The primary plaque at its authored physical size, shrunk only when its bay
## genuinely cannot hold it.
static func plaque_size(available: Vector2 = Vector2.ZERO) -> Vector2:
	var size: Vector2 = PLAQUE_PHYSICAL
	if available.x > 1.0 and available.y > 1.0:
		var room: Vector2 = available - Vector2(PLAQUE_BAY_PADDING_PHYSICAL, PLAQUE_BAY_PADDING_PHYSICAL) * 2.0
		var fit: float = minf(1.0, minf(room.x / maxf(1.0, size.x), room.y / maxf(1.0, size.y)))
		if fit < 1.0:
			size = Vector2(roundf(size.x * fit), roundf(size.y * fit))
	return Vector2(roundf(size.x), roundf(size.y))

## Field column width once both rails and the row separations are removed. No
## fixed floor beyond what is actually there.
static func field_width(logical_size: Vector2, rail_width: float, separation: float, horizontal_inset: float) -> float:
	return maxf(240.0, logical_size.x - rail_width * 2.0 - separation * 2.0 - horizontal_inset * 2.0)

## Width the deployment grids and the bench occupy inside the floor raster. The
## raster itself is the field column; the inscribed width is additionally capped
## by the column the container actually gave us, so the rendered board can never
## be wider than its column.
static func board_width(field_width_value: float, actual_column_width: float = 0.0) -> float:
	var basis: float = field_width_value
	if actual_column_width > 1.0:
		basis = minf(basis, actual_column_width)
	return maxf(240.0, basis * BOARD_RASTER_SHARE)

static func board_foot_pad() -> float:
	return BOARD_FOOT_PAD_PHYSICAL

## Board cells fill the inscribed board column and are capped by the vertical
## space the field actually received.
static func board_tile_width(board_column_width: float) -> float:
	var usable: float = board_column_width - BOARD_GAP * float(BOARD_COLUMNS - 1)
	var slot_width: float = usable / float(BOARD_COLUMNS)
	var width: float = floorf(maxf(1.0, minf(maxf(slot_width, 0.0), 190.0)))
	return maxf(width, minf(BOARD_TILE_MIN_PHYSICAL, maxf(1.0, slot_width)))

## The width the deployment grid really occupies once its cells are quantised to
## whole pixels. The bench is rounded from this span, not from the pre-quantised
## request, so the two rows agree exactly.
static func board_span(board_column_width: float) -> float:
	var width: float = board_tile_width(board_column_width)
	return width * float(BOARD_COLUMNS) + BOARD_GAP * float(BOARD_COLUMNS - 1)

static func board_tile_size(board_column_width: float, available_height: float) -> Vector2:
	var width: float = board_tile_width(board_column_width)
	var height_cap: float = BOARD_MAX_TILE_HEIGHT_PHYSICAL
	var from_width: float = width * 0.72
	# Six rows plus four in-half gaps and the planning seam have to fit.
	var rows_fit: float = floorf((available_height - BOARD_PLANNING_SEPARATION - BOARD_GAP * 4.0) / 6.0)
	var height: float = from_width
	if rows_fit > 0.0:
		height = minf(from_width, rows_fit)
	return Vector2(width, maxf(1.0, floorf(minf(height, height_cap))))

## Bench cells span the board column and are capped by it, for the real slot
## count the bench actually has.
static func bench_tile_size(board_column_width: float, slots: int) -> Vector2:
	var count: int = maxi(1, slots)
	var usable: float = board_column_width - BENCH_GAP * float(count - 1)
	var slot_width: float = usable / float(count)
	var width_floor: float = BENCH_MIN_TILE_PHYSICAL
	var height_cap: float = BENCH_MAX_TILE_PHYSICAL
	var width: float = floorf(maxf(1.0, minf(maxf(slot_width, 0.0), maxf(width_floor, slot_width))))
	var height: float = clampf(width * 0.72, minf(width, height_cap) * 0.5, height_cap)
	return Vector2(width, floorf(maxf(1.0, height)))

## Composes the dock band into [ shop territory | full-height wager column |
## action bay ]. The shop edge is measured from the live container, so an
## inflated child minimum shifts the neighbours instead of being overlapped;
## the plaque is a concentrated physical plaque centred in its bay.
static func dock_plan(dock_band: Rect2, allocation: Dictionary, shop_right_x: float) -> Dictionary:
	var gap: float = float(allocation.get("gap", dock_gap()))
	var wager: float = float(allocation.get("wager", minimum_wager_width()))
	var bay: float = float(allocation.get("bay", bay_width_for(plaque_size().x)))
	var reason: String = String(allocation.get("reason", ""))
	if bay <= 1.0 or wager <= 1.0 or dock_band.size.y <= 1.0:
		return {
			"ok": false,
			"reason": "dock_band_too_small",
			"wager": Rect2(),
			"bay": Rect2(),
			"plaque": Rect2(),
			"wager_width": wager,
			"bay_width": bay,
			"shop_right_x": shop_right_x,
			"reason_code": reason,
		}
	var bay_size: Vector2 = Vector2(bay, dock_band.size.y)
	var plaque: Vector2 = plaque_size(bay_size)
	if plaque.x + 1.0 < PLAQUE_PHYSICAL.x:
		reason = "plaque_shrunk_to_bay"
	var wager_rect: Rect2 = Rect2(
		Vector2(shop_right_x + gap, dock_band.position.y),
		Vector2(wager, dock_band.size.y)
	)
	var bay_rect: Rect2 = Rect2(
		Vector2(wager_rect.end.x + gap, dock_band.position.y),
		bay_size
	)
	var plaque_rect: Rect2 = Rect2(
		Vector2(
			bay_rect.position.x + (bay_rect.size.x - plaque.x) * 0.5,
			bay_rect.position.y + (bay_rect.size.y - plaque.y) * 0.5
		),
		plaque
	)
	return {
		"ok": true,
		"reason": reason,
		"reason_code": String(allocation.get("reason", "")),
		"wager": wager_rect,
		"bay": bay_rect,
		"plaque": plaque_rect,
		"wager_width": wager,
		"bay_width": bay,
		"gap": gap,
		"shop_right_x": shop_right_x,
	}
