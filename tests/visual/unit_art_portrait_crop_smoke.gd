extends Node

## Focused contract for the shop portrait crop.
##
## The framing is a pure function of a sprite's alpha profile, so this smoke
## builds synthetic alpha shapes instead of touching shipped unit art and checks
## the region the shop card would actually use. It exists because the first
## implementation sized the window from the topmost alpha band: a broad weapon
## raised above the body could satisfy the "shoulder" test on its own, which
## collapsed the crop into a sliver of weapon. The cases below are the shapes
## that used to break it - a broad object above the head, a single-pixel top
## row, a tall narrow figure and a wide stance - plus the degenerate empty
## sprite, and every case shares the bounds/positivity contract.
##
## The second half drives a real `ShopCard` through the lifecycle the framing
## previously ignored: a card is hydrated before its container has given it its
## final rect, and the window was measured once, at assignment time, against
## whatever transient rect the layout happened to be in. One card in five kept a
## 3.04:1 window inside a 1.02:1 rect that way, which drew the portrait
## letterboxed with black bands. These cases bind before and after layout, resize,
## rebind and repeat the compact presentation, and assert that the window the card
## keeps is the framer's answer for the rect it actually holds - with the subjects
## whose own bounds decide the shape asserted as such rather than presumed to match
## the rect.

const UnitArtPresentation: GDScript = preload("res://scripts/ui/unit_art_presentation.gd")
const SHOP_CARD_SCENE: PackedScene = preload("res://scenes/ui/shop/ShopCard.tscn")
const UserSettingsScript: GDScript = preload("res://scripts/game/settings/user_settings.gd")

const SMOKE_NAME: String = "UnitArtPortraitCropSmoke"
const CANVAS: int = 200
## The live shop card icon window is about 1.5:1 at 100 percent UI.
const CARD_ASPECT: float = 1.5
## Loose floors, so the contract is "a character, not a sliver" rather than a
## restatement of the framing constants.
const MIN_WIDTH_SHARE: float = 0.55
const MIN_HEIGHT_SHARE: float = 0.40
const ASPECT_TOLERANCE: float = 0.35
## Card geometry for the lifecycle fixture. `SETTLED` is the 187x204 fixed card
## the reported capture measured. `TRANSIENT` is the wide pre-layout rect that
## produced the stale window: the report's 3.04498 solves to a ~341x138 card under
## the portrait anchors, which is the scene's own authored 138 minimum height with
## a whole row's width. The size setters clamp a control to its combined minimum,
## so the fixture widens the card at the compact minimum height instead; the shape
## that matters - a window measured for a much wider rect than the card settles at
## - is the same. `MID` and `NARROW` are that card family at the narrower rects a
## scaled rail gives it.
const SETTLED_CARD_SIZE: Vector2 = Vector2(187.0, 204.0)
const TRANSIENT_CARD_SIZE: Vector2 = Vector2(420.0, 188.0)
const MID_CARD_SIZE: Vector2 = Vector2(200.0, 214.0)
const NARROW_CARD_SIZE: Vector2 = Vector2(132.0, 188.0)
## The window is derived from the same rect read, so this only absorbs float
## drift. The failure this fixture exists for was a factor of three.
const FRAME_TOLERANCE: float = 0.02
## The shared framer picks its region in whole source pixels, so the region's own
## aspect is allowed this much slack against the rect it was measured for. The
## claim is only made for subjects the framer can actually shape to an aspect; a
## subject that is narrow for its height is bound by its own height floor and
## width cap, and the fixture asserts that bound instead.
const REGION_ASPECT_TOLERANCE: float = 0.08
const RAIL_VIEWPORT: Vector2i = Vector2i(1920, 1080)
const TEST_SETTINGS_PATH: String = "user://unit_art_portrait_crop_smoke_settings.cfg"
const SOURCE_IMAGE_PATH: String = "user://unit_art_portrait_crop_smoke_source.png"
const REBOUND_IMAGE_PATH: String = "user://unit_art_portrait_crop_smoke_rebound.png"
const NARROW_SUBJECT_IMAGE_PATH: String = "user://unit_art_portrait_crop_smoke_narrow.png"
## Alpha bounds of the narrow synthetic subject, from the bands it is drawn from
## rather than from the framer: the body is 61 columns wide and the subject spans
## 183 rows. These are the bounds the fixture's own window assertions derive from.
const NARROW_SUBJECT_WIDTH: float = 61.0
const NARROW_SUBJECT_HEIGHT: float = 183.0

var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_assert_broad_weapon_above_body()
	_assert_tiny_first_row()
	_assert_tall_narrow_figure()
	_assert_wide_pose()
	_assert_empty_sprite_falls_back()
	await _assert_card_lifecycle()
	_remove_fixture_sources()
	if _failures.is_empty():
		print("%s: PASS" % SMOKE_NAME)
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("%s: %s" % [SMOKE_NAME, failure])
	get_tree().quit(1)


## A club held above the head: a two-pixel tip, a broad weapon head, then a
## narrow body. The weapon band is the widest row in the sprite, so a window
## sized from the top alpha band would frame the club and nothing else.
func _assert_broad_weapon_above_body() -> void:
	var image: Image = _blank()
	_fill(image, 99, 0, 100, 0)
	_fill(image, 10, 4, 190, 26)
	_fill(image, 80, 40, 120, 190)
	var subject_width: float = 181.0
	var subject_height: float = 191.0
	var region: Rect2 = _region_of(image)
	_expect(region.size.x >= subject_width * MIN_WIDTH_SHARE, "broad weapon: crop is only %.1f wide, subject is %.1f" % [region.size.x, subject_width])
	_expect(region.size.y >= subject_height * MIN_HEIGHT_SHARE, "broad weapon: crop is only %.1f tall, subject is %.1f" % [region.size.y, subject_height])
	_expect(region.position.y <= 4.0, "broad weapon: crop starts below the top of the sprite (%s)" % str(region))
	_expect(region.end.y >= 60.0, "broad weapon: crop stops above the body band (%s)" % str(region))
	_assert_card_shaped(region, "broad weapon")
	_report("broad_weapon_above_body", region, subject_width, subject_height)


## A single opaque pixel at the very top, then a gap, then the body. The top row
## must not be read as the subject's own head band.
func _assert_tiny_first_row() -> void:
	var image: Image = _blank()
	_fill(image, 99, 0, 99, 0)
	_fill(image, 60, 30, 140, 150)
	var subject_width: float = 81.0
	var subject_height: float = 151.0
	var region: Rect2 = _region_of(image)
	_expect(region.size.x >= subject_width * MIN_WIDTH_SHARE, "tiny first row: crop is only %.1f wide, subject is %.1f" % [region.size.x, subject_width])
	_expect(region.size.y >= subject_height * MIN_HEIGHT_SHARE, "tiny first row: crop is only %.1f tall, subject is %.1f" % [region.size.y, subject_height])
	_expect(region.end.y >= 45.0, "tiny first row: crop stops above the body (%s)" % str(region))
	_assert_card_shaped(region, "tiny first row")
	_report("tiny_first_row", region, subject_width, subject_height)


## A tall, thin figure. The crop has to keep a bounded share of the subject's
## height and still cover the whole subject width, without stretching it.
func _assert_tall_narrow_figure() -> void:
	var image: Image = _blank()
	_fill(image, 90, 5, 110, 195)
	var subject_width: float = 21.0
	var subject_height: float = 191.0
	var region: Rect2 = _region_of(image)
	_expect(region.size.x >= subject_width * MIN_WIDTH_SHARE, "tall narrow: crop is only %.1f wide, subject is %.1f" % [region.size.x, subject_width])
	_expect(region.size.y >= subject_height * MIN_HEIGHT_SHARE, "tall narrow: crop is only %.1f tall, subject is %.1f" % [region.size.y, subject_height])
	_expect(region.end.y >= 5.0 + subject_height * 0.35, "tall narrow: crop stops in the top third of the figure (%s)" % str(region))
	_report("tall_narrow_figure", region, subject_width, subject_height)


## A wide stance or spread arms under a narrow head. The width floor is what
## keeps the pose readable instead of cropping to the head.
func _assert_wide_pose() -> void:
	var image: Image = _blank()
	_fill(image, 95, 5, 105, 29)
	_fill(image, 10, 30, 190, 120)
	var subject_width: float = 181.0
	var subject_height: float = 116.0
	var region: Rect2 = _region_of(image)
	_expect(region.size.x >= subject_width * MIN_WIDTH_SHARE, "wide pose: crop is only %.1f wide, subject is %.1f" % [region.size.x, subject_width])
	_expect(region.size.y >= subject_height * MIN_HEIGHT_SHARE, "wide pose: crop is only %.1f tall, subject is %.1f" % [region.size.y, subject_height])
	_expect(region.position.y <= 5.0, "wide pose: crop cuts the head off the top (%s)" % str(region))
	_expect(region.end.y >= 40.0, "wide pose: crop stops above the body (%s)" % str(region))
	_report("wide_pose", region, subject_width, subject_height)


## No visible pixels at all is the degenerate case; it must still return a
## positive region inside the texture rather than a zero rect.
func _assert_empty_sprite_falls_back() -> void:
	var image: Image = _blank()
	var region: Rect2 = _region_of(image)
	_expect(region.size.x >= float(CANVAS) * 0.5, "empty sprite: fallback crop is too narrow (%s)" % str(region))
	_expect(region.size.y >= float(CANVAS) * 0.5, "empty sprite: fallback crop is too short (%s)" % str(region))
	_report("empty_sprite", region, float(CANVAS), float(CANVAS))


## The reported defect, driven end to end through the real card.
##
## The fifth card in the capture was hydrated while the grid still held a
## pre-layout rect and settled afterwards; the first four were bound once the
## rect had already settled. That difference is the whole bug, so this fixture
## builds both orders at the same final size and requires the same window from
## each. It closes with the presentation sequences the composition pass repeats:
## re-applied compact presentation, a resize sweep across the rects a scaled rail
## hands the card, and a rebind to another subject.
func _assert_card_lifecycle() -> void:
	var window: Window = get_window()
	_remove_fixture_sources()
	UserSettingsScript.configure_storage_path(TEST_SETTINGS_PATH)
	UserSettingsScript.initialize(window)
	UserSettingsScript.set_ui_scale(1.0, window)
	var scene_root: SubViewport = SubViewport.new()
	scene_root.name = "CropSmokeViewport"
	scene_root.size = RAIL_VIEWPORT
	scene_root.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(scene_root)
	var host: Control = Control.new()
	host.name = "CropSmokeHost"
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene_root.add_child(host)
	# The card subjects are deliberately broad for their height: a subject the
	# framer can shape to the rect's aspect is what lets these cases assert that the
	# window follows the rect, rather than only that the measurement did. The
	# narrow subject below covers the other half of the framer's contract.
	_write_subject_source(SOURCE_IMAGE_PATH, Vector2i(200, 200), [
		Vector4i(84, 8, 116, 44),
		Vector4i(30, 46, 170, 190),
	])
	_write_subject_source(REBOUND_IMAGE_PATH, Vector2i(240, 160), [
		Vector4i(30, 20, 210, 60),
		Vector4i(70, 66, 170, 150),
	])
	_write_subject_source(NARROW_SUBJECT_IMAGE_PATH, Vector2i(200, 200), [
		Vector4i(84, 8, 116, 44),
		Vector4i(70, 46, 130, 190),
	])
	var stale_card: Control = _add_card(host, TRANSIENT_CARD_SIZE)
	if stale_card == null:
		scene_root.queue_free()
		return
	await _settle_frames(3)
	stale_card.call("set_data", _board_art_props("smoke_transient", SOURCE_IMAGE_PATH))
	await _settle_frames(3)
	var transient_frame: float = _frame_aspect(stale_card)
	_expect(
		transient_frame > 1.8,
		"fixture: the pre-layout rect should measure a wide window, got %.3f" % transient_frame
	)
	stale_card.size = SETTLED_CARD_SIZE
	await _settle_frames(4)
	_expect(
		absf(_live_rect_aspect(stale_card) - transient_frame) > 0.5,
		"fixture: resizing the card did not resize its anchored icon, so the lifecycle case cannot run"
	)
	var settled_state: Dictionary = _assert_crop_matches_rect(stale_card, "bind before layout")
	_expect(
		float(settled_state.get("frame", 0.0)) < 1.5,
		"bind before layout: the settled rect kept the pre-layout window (%.3f after resizing from %.3f)" % [
			float(settled_state.get("frame", 0.0)), transient_frame
		]
	)
	# The measurement is not the only thing that has to be current: for a subject
	# the framer can shape, the window itself must differ from the one the
	# pre-layout frame asks for.
	var wide_source: Texture2D = _portrait_source(stale_card)
	if wide_source != null:
		var stale_window: Rect2 = UnitArtPresentation.portrait_region(wide_source, transient_frame)
		_expect(
			not _same_region(settled_state.get("region", Rect2()), stale_window),
			"bind before layout: the settled window %s is still the pre-layout window %s" % [
				str(settled_state.get("region", Rect2())), str(stale_window)
			]
		)
	var settled_card: Control = _add_card(host, SETTLED_CARD_SIZE)
	if settled_card != null:
		await _settle_frames(3)
		settled_card.call("set_data", _board_art_props("smoke_settled", SOURCE_IMAGE_PATH))
		await _settle_frames(3)
		var ordered_state: Dictionary = _assert_crop_matches_rect(settled_card, "bind after layout")
		_expect(
			_same_region(settled_state.get("region", Rect2()), ordered_state.get("region", Rect2())),
			"the same final rect produced different windows by binding order (%s vs %s)" % [
				str(settled_state.get("region", Rect2())), str(ordered_state.get("region", Rect2()))
			]
		)
		settled_card.call("set_data", _board_art_props("smoke_settled", SOURCE_IMAGE_PATH))
		await _settle_frames(3)
		var rebound_same: Dictionary = _assert_crop_matches_rect(settled_card, "rebind same source")
		_expect(
			_same_region(ordered_state.get("region", Rect2()), rebound_same.get("region", Rect2())),
			"rebinding the same source moved the window (%s -> %s)" % [
				str(ordered_state.get("region", Rect2())), str(rebound_same.get("region", Rect2()))
			]
		)
		settled_card.call("set_data", _board_art_props("smoke_rebound", REBOUND_IMAGE_PATH))
		await _settle_frames(3)
		var rebound_other: Dictionary = _assert_crop_matches_rect(settled_card, "rebind other source")
		var rebound_source_size: Vector2 = rebound_other.get("source_size", Vector2.ZERO)
		_expect(
			rebound_source_size == Vector2(240.0, 160.0),
			"rebind other source: the atlas still carries the previous sprite (%s)" % str(rebound_source_size)
		)
		_assert_source_pixels_preserved(settled_card, REBOUND_IMAGE_PATH, "rebind other source")
		# Re-applying the compact presentation at an unchanged rect must reuse the
		# atlas instead of minting a new one and re-measuring the sprite each pass.
		var atlas_before: AtlasTexture = _portrait_atlas(settled_card)
		var region_before: Rect2 = _portrait_region(settled_card)
		for _repeat: int in range(3):
			settled_card.call("set_compact_presentation", true, false)
			await _settle_frames(2)
		var atlas_after: AtlasTexture = _portrait_atlas(settled_card)
		_expect(atlas_after != null, "repeated compact: the card lost its portrait atlas")
		_expect(atlas_after == atlas_before, "repeated compact: the atlas was rebuilt for an unchanged rect")
		_expect(
			_same_region(_portrait_region(settled_card), region_before),
			"repeated compact: the window moved without the rect changing (%s -> %s)" % [
				str(region_before), str(_portrait_region(settled_card))
			]
		)
		# Every rect a scaled rail hands the card has to describe itself, and the
		# settled window has to come back unchanged instead of drifting.
		var sweep_names: Array[String] = ["mid rail", "narrow rail", "settled rail"]
		var sweep_sizes: Array[Vector2] = [MID_CARD_SIZE, NARROW_CARD_SIZE, SETTLED_CARD_SIZE]
		for index: int in range(sweep_sizes.size()):
			settled_card.size = sweep_sizes[index]
			await _settle_frames(4)
			var sweep_state: Dictionary = _assert_crop_matches_rect(settled_card, sweep_names[index])
			if index == 1:
				_expect(
					not _same_region(sweep_state.get("region", Rect2()), region_before),
					"narrow rail: the window did not follow the narrower rect (%s)" % str(sweep_state.get("region", Rect2()))
				)
		_expect(
			_same_region(_portrait_region(settled_card), region_before),
			"settled rail: returning to the settled rect did not restore its window (%s -> %s)" % [
				str(region_before), str(_portrait_region(settled_card))
			]
		)
		_assert_source_pixels_preserved(settled_card, REBOUND_IMAGE_PATH, "settled rail")
	await _assert_narrow_subject_is_bounded(host)
	scene_root.queue_free()


## The bounded half of the framer's contract, and the case root's run surfaced: a
## subject that is narrow for its height cannot take an arbitrary aspect. The
## framer keeps a floor of `PORTRAIT_MIN_HEIGHT_SHARE` of the subject's height and
## caps the width at the subject's own, so the window comes out taller than the
## rect asks for - on this subject 61 x 76.9 for a 1.0168 rect, aspect 0.7937.
## That is correct framing, not a stale window. What still has to hold is that the
## measurement followed the rect, that the atlas carries the framer's answer for
## that measurement, and that the window stays inside the bounds the subject
## itself sets. The bounds below are derived from the authored bands, not from the
## framer, so they check the framer rather than restate it.
func _assert_narrow_subject_is_bounded(host: Control) -> void:
	var card: Control = _add_card(host, SETTLED_CARD_SIZE)
	if card == null:
		return
	await _settle_frames(3)
	card.call("set_data", _board_art_props("smoke_narrow", NARROW_SUBJECT_IMAGE_PATH))
	await _settle_frames(4)
	_assert_crop_matches_rect(card, "narrow subject")
	var atlas: AtlasTexture = _portrait_atlas(card)
	if atlas == null:
		return
	var region: Rect2 = atlas.region
	var rect_aspect: float = _live_rect_aspect(card)
	var region_aspect: float = region.size.x / region.size.y
	_expect(
		region.size.x >= NARROW_SUBJECT_WIDTH * MIN_WIDTH_SHARE,
		"narrow subject: window is only %.2f wide of a %.0f subject" % [region.size.x, NARROW_SUBJECT_WIDTH]
	)
	_expect(
		region.size.x <= NARROW_SUBJECT_WIDTH + 0.01,
		"narrow subject: window is wider than the subject itself (%.2f of %.0f)" % [region.size.x, NARROW_SUBJECT_WIDTH]
	)
	_expect(
		region.size.y >= NARROW_SUBJECT_HEIGHT * UnitArtPresentation.PORTRAIT_MIN_HEIGHT_SHARE - 0.01,
		"narrow subject: window %.2f is under the framer's subject-height floor %.2f" % [
			region.size.y, NARROW_SUBJECT_HEIGHT * UnitArtPresentation.PORTRAIT_MIN_HEIGHT_SHARE
		]
	)
	_expect(
		region.size.y <= NARROW_SUBJECT_HEIGHT + 0.01,
		"narrow subject: window is taller than the subject itself (%.2f of %.0f)" % [region.size.y, NARROW_SUBJECT_HEIGHT]
	)
	# The documented consequence of those bounds: the window is taller than the
	# rect's own aspect, which is why the shape claim is skipped for this subject.
	_expect(
		region_aspect < rect_aspect - 0.1,
		"narrow subject: the subject bound was expected to hold the window below the %.4f rect aspect, got %.4f" % [
			rect_aspect, region_aspect
		]
	)
	print("%s: narrow_subject window %s (aspect %.4f) for a %.4f rect, subject %.0fx%.0f" % [
		SMOKE_NAME, str(region), region_aspect, rect_aspect, NARROW_SUBJECT_WIDTH, NARROW_SUBJECT_HEIGHT
	])


## One card in a plain host: the host gives it no geometry, so the rect this
## fixture sets is the rect the card and its anchored icon actually hold.
func _add_card(host: Control, card_size: Vector2) -> Control:
	var card: Control = SHOP_CARD_SCENE.instantiate() as Control
	if card == null:
		_expect(false, "ShopCard scene failed to instantiate")
		return null
	host.add_child(card)
	# The card scene ships with unequal opposite anchors, and a direct size on
	# those is overridden by the offsets (Godot warns about it too). Top-left
	# anchors make the rect this fixture sets the rect the card actually holds.
	card.set_anchors_preset(Control.PRESET_TOP_LEFT)
	card.position = Vector2.ZERO
	card.size = card_size
	return card


func _board_art_props(offer_id: String, image_path: String) -> Dictionary:
	return {
		"id": offer_id,
		"name": "Smoke Subject",
		"price": 4,
		"image_path": image_path,
		"uses_board_art": true,
	}


func _assert_card_shaped(region: Rect2, label: String) -> void:
	var aspect: float = region.size.x / region.size.y
	_expect(absf(aspect - CARD_ASPECT) <= ASPECT_TOLERANCE, "%s: crop aspect %.2f drifts from the %.2f card window" % [label, aspect, CARD_ASPECT])


## The live contract in one place: the recorded measurement is the rect the icon
## holds, the drawn window is the framer's own answer for that measurement, the
## atlas is clipped to the source it was cut from, and the published metadata
## describes the atlas in use rather than an earlier one. Whether the window can
## also take the rect's shape is the framer's own decision and is checked with that
## precondition in `_assert_window_shape`.
func _assert_crop_matches_rect(card: Control, label: String) -> Dictionary:
	var icon: TextureRect = card.get_node_or_null("Icon") as TextureRect
	if icon == null:
		_expect(false, "%s: card has no Icon node" % label)
		return {}
	var rect_aspect: float = icon.size.x / icon.size.y
	var frame: float = _frame_aspect(card)
	_expect(
		absf(frame - rect_aspect) <= FRAME_TOLERANCE,
		"%s: window measured %.4f for a %.4f icon rect (%s)" % [label, frame, rect_aspect, str(icon.size)]
	)
	var atlas: AtlasTexture = icon.texture as AtlasTexture
	if atlas == null:
		_expect(false, "%s: the portrait is not an atlas crop (%s)" % [label, str(icon.texture)])
		return {"frame": frame, "rect_aspect": rect_aspect}
	var source_size: Vector2 = atlas.atlas.get_size() if atlas.atlas != null else Vector2.ZERO
	_expect(atlas.filter_clip, "%s: the crop lost filter_clip" % label)
	_expect(
		atlas.region.position.x >= 0.0 and atlas.region.position.y >= 0.0,
		"%s: the crop starts outside the source (%s)" % [label, str(atlas.region)]
	)
	_expect(
		atlas.region.end.x <= source_size.x + 0.01 and atlas.region.end.y <= source_size.y + 0.01,
		"%s: the crop ends outside the source (%s of %s)" % [label, str(atlas.region), str(source_size)]
	)
	var published: Rect2 = card.get_meta("shop_portrait_region", Rect2())
	_expect(
		_same_region(published, atlas.region),
		"%s: published window %s does not describe the atlas %s" % [label, str(published), str(atlas.region)]
	)
	_assert_window_shape(card, label)
	return {
		"frame": frame,
		"region": atlas.region,
		"rect_aspect": rect_aspect,
		"source_size": source_size,
	}


## The framer is the authority on the window's shape. It sizes from the subject's
## own bounds and keeps a floor of `PORTRAIT_MIN_HEIGHT_SHARE` of the subject's
## height, so a subject that is narrow for its height cannot be framed at an
## arbitrary aspect however tall, wide or square the card's rect is. So ask the
## framer which case this is instead of presuming the rect's shape: only claim
## "the window describes the rect" when the framer itself answers differently for
## a different aspect. The window is always required to be the framer's answer for
## the frame the card just measured, which is what a window left over from an
## earlier rect fails.
func _assert_window_shape(card: Control, label: String) -> void:
	var atlas: AtlasTexture = _portrait_atlas(card)
	var source: Texture2D = _portrait_source(card)
	if atlas == null or source == null:
		return
	var rect_aspect: float = _live_rect_aspect(card)
	var framer_window: Rect2 = UnitArtPresentation.portrait_region(source, rect_aspect)
	_expect(
		_same_region(atlas.region, framer_window),
		"%s: the atlas window %s is not the framer's answer for the measured frame %s" % [
			label, str(atlas.region), str(framer_window)
		]
	)
	var wider_window: Rect2 = UnitArtPresentation.portrait_region(source, rect_aspect * 1.5)
	if _same_region(wider_window, framer_window):
		# Subject-bound: the height floor and the subject-width cap decide the
		# window, so it is deliberately not the rect's own aspect, and it must be
		# the same window for both aspects.
		_expect(
			_same_region(atlas.region, wider_window),
			"%s: subject-bound window moved between aspects it should ignore (%s vs %s)" % [
				label, str(atlas.region), str(wider_window)
			]
		)
		print("%s: %s window is subject-bound %s (aspect %.4f) for a %.4f rect" % [
			SMOKE_NAME, label, str(atlas.region), atlas.region.size.x / atlas.region.size.y, rect_aspect
		])
		return
	_expect(
		absf(atlas.region.size.x / atlas.region.size.y - rect_aspect) <= REGION_ASPECT_TOLERANCE,
		"%s: window aspect %.4f does not describe the %.4f rect" % [
			label, atlas.region.size.x / atlas.region.size.y, rect_aspect
		]
	)


## Framing selects a region; it must not repaint it. The drawn level 0 pixels
## inside the window have to equal the source file's own pixels.
func _assert_source_pixels_preserved(card: Control, image_path: String, label: String) -> void:
	var atlas: AtlasTexture = _portrait_atlas(card)
	if atlas == null or atlas.atlas == null:
		_expect(false, "%s: no atlas to compare against the source" % label)
		return
	var drawn: Image = atlas.atlas.get_image()
	var source: Image = Image.new()
	if drawn == null or source.load(image_path) != OK:
		_expect(false, "%s: could not read the drawn portrait and its source back" % label)
		return
	var region: Rect2 = atlas.region
	var corners: Array[Vector2] = [
		Vector2(0.5, 0.5),
		Vector2(region.size.x * 0.5, region.size.y * 0.5),
		region.size - Vector2(0.5, 0.5),
	]
	for corner: Vector2 in corners:
		var source_point: Vector2i = Vector2i(region.position + corner)
		if source_point.x < 0 or source_point.y < 0 or source_point.x >= source.get_width() or source_point.y >= source.get_height():
			continue
		if source_point.x >= drawn.get_width() or source_point.y >= drawn.get_height():
			continue
		_expect(
			drawn.get_pixel(source_point.x, source_point.y).to_rgba32() == source.get_pixel(source_point.x, source_point.y).to_rgba32(),
			"%s: framing changed the pixel at %s" % [label, str(source_point)]
		)


func _frame_aspect(card: Control) -> float:
	return float(card.get_meta("shop_portrait_frame_aspect", 0.0))


func _live_rect_aspect(card: Control) -> float:
	var icon: TextureRect = card.get_node_or_null("Icon") as TextureRect
	return icon.size.x / icon.size.y if icon != null and icon.size.y > 0.0 else 0.0


func _portrait_atlas(card: Control) -> AtlasTexture:
	var icon: TextureRect = card.get_node_or_null("Icon") as TextureRect
	return icon.texture as AtlasTexture if icon != null else null


func _portrait_source(card: Control) -> Texture2D:
	return card.get("_unit_texture") as Texture2D


func _portrait_region(card: Control) -> Rect2:
	var atlas: AtlasTexture = _portrait_atlas(card)
	return atlas.region if atlas != null else Rect2()


func _same_region(left: Rect2, right: Rect2) -> bool:
	return left.is_equal_approx(right)


## A synthetic subject on its own canvas: a head band above a broader body band,
## which is the shape the framing cases above use.
func _write_subject_source(path: String, canvas: Vector2i, bands: Array) -> void:
	var image: Image = Image.create(canvas.x, canvas.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	for band: Vector4i in bands:
		for y: int in range(maxi(0, band.y), mini(canvas.y - 1, band.w) + 1):
			for x: int in range(maxi(0, band.x), mini(canvas.x - 1, band.z) + 1):
				image.set_pixel(x, y, Color(0.52, 0.46, 0.40, 1.0))
	var error: Error = image.save_png(path)
	_expect(error == OK, "fixture: could not write %s (%d)" % [path, error])


func _remove_fixture_sources() -> void:
	for path: String in [TEST_SETTINGS_PATH, SOURCE_IMAGE_PATH, REBOUND_IMAGE_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _settle_frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


## Framing only selects a region: the source pixels must come back unchanged.
func _region_of(image: Image) -> Rect2:
	var before: PackedInt32Array = PackedInt32Array()
	for sample: Vector2i in [Vector2i(10, 5), Vector2i(100, 20), Vector2i(60, 60), Vector2i(150, 100), Vector2i(100, 150)]:
		before.append(image.get_pixel(sample.x, sample.y).to_rgba32())
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	var region: Rect2 = UnitArtPresentation.portrait_region(texture, CARD_ASPECT)
	var after: PackedInt32Array = PackedInt32Array()
	for sample: Vector2i in [Vector2i(10, 5), Vector2i(100, 20), Vector2i(60, 60), Vector2i(150, 100), Vector2i(100, 150)]:
		after.append(image.get_pixel(sample.x, sample.y).to_rgba32())
	_expect(before == after, "framing modified the source pixels")
	_expect(region.size.x > 0.0 and region.size.y > 0.0, "crop must have a positive size, got %s" % str(region))
	_expect(region.position.x >= 0.0 and region.position.y >= 0.0, "crop starts outside the texture: %s" % str(region))
	_expect(region.end.x <= float(CANVAS) + 0.01 and region.end.y <= float(CANVAS) + 0.01, "crop ends outside the texture: %s" % str(region))
	return region


func _blank() -> Image:
	var image: Image = Image.create(CANVAS, CANVAS, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	return image


func _fill(image: Image, left: int, top: int, right: int, bottom: int) -> void:
	for y: int in range(maxi(0, top), mini(CANVAS - 1, bottom) + 1):
		for x: int in range(maxi(0, left), mini(CANVAS - 1, right) + 1):
			image.set_pixel(x, y, Color(0.52, 0.46, 0.40, 1.0))


func _report(case_name: String, region: Rect2, subject_width: float, subject_height: float) -> void:
	print("%s: %s -> %s (subject %.1fx%.1f, share %.2fx%.2f)" % [
		SMOKE_NAME,
		case_name,
		str(region),
		subject_width,
		subject_height,
		region.size.x / subject_width,
		region.size.y / subject_height,
	])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
