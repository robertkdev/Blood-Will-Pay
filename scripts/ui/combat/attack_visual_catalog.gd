extends RefCounted
class_name AttackVisualCatalog

const PLAYABLE_SIGNATURE_IDS: Array[String] = [
	"axiom", "bastionne", "berebell", "bo", "bonko", "brute", "caldera", "cinder", "creep",
	"draxelle", "egress", "gable", "grint", "hexeon", "ivara", "juno_vale", "kett", "knoll",
	"korath", "kythera", "luna", "malachor", "mara", "marble", "meridian", "miri", "morrak",
	"mortem", "noxley", "nullora", "nyxa", "omenry", "orielle", "paisley", "pilfer", "prisma",
	"quillith", "quorra", "ravel", "repo", "rooket", "sable", "saffron", "sari", "teller",
	"totem", "velour", "vesper", "veyra", "volt", "vykos",
]

static func style_for(unit: Unit, source_team: String, crit: bool) -> Dictionary[String, Variant]:
	var unit_id: String = ""
	var primary_role: String = ""
	var approaches: Array[String] = []
	if unit != null:
		unit_id = String(unit.id).strip_edges().to_lower()
		primary_role = String(unit.primary_role).strip_edges().to_lower()
		approaches = unit.get_approaches()

	var style: Dictionary[String, Variant] = _role_fallback(primary_role, approaches)
	_apply_unit_override(style, unit_id)
	style["unit_id"] = unit_id
	style["signature_overridden"] = has_unit_signature(unit_id)
	style["source_team"] = source_team
	if crit:
		style["radius_scale"] = float(style.get("radius_scale", 1.0)) * 1.28
		style["trail_width"] = float(style.get("trail_width", 3.0)) * 1.20
		style["impact_radius"] = float(style.get("impact_radius", 24.0)) * 1.22
		style["crit"] = true
	else:
		style["crit"] = false
	return style

static func has_unit_signature(unit_id: String) -> bool:
	return PLAYABLE_SIGNATURE_IDS.has(String(unit_id).strip_edges().to_lower())

static func _make_style(
		shape: String,
		core_color: Color,
		edge_color: Color,
		trail_color: Color,
		accent_color: Color,
		radius_scale: float,
		trail_width: float,
		impact_radius: float,
		speed_scale: float = 1.0,
		arc_curve: float = 0.0,
		arc_freq: float = 6.0
) -> Dictionary[String, Variant]:
	return {
		"shape": shape,
		"core_color": core_color,
		"edge_color": edge_color,
		"trail_color": trail_color,
		"accent_color": accent_color,
		"radius_scale": radius_scale,
		"trail_width": trail_width,
		"impact_radius": impact_radius,
		"speed_scale": speed_scale,
		"arc_curve": arc_curve,
		"arc_freq": arc_freq,
		"trail_length": 8,
		"spin_rate": 8.0,
	}

static func _role_fallback(primary_role: String, approaches: Array[String]) -> Dictionary[String, Variant]:
	if approaches.has("execute"):
		return _make_style("needle", Color(0.95, 0.98, 1.0, 1.0), Color(0.25, 0.94, 1.0, 0.95), Color(0.18, 0.65, 1.0, 0.52), Color(1.0, 0.28, 0.74, 0.95), 0.95, 3.0, 24.0, 1.14)
	if approaches.has("dot") or approaches.has("zone"):
		return _make_style("ember", Color(0.95, 0.92, 0.62, 1.0), Color(0.96, 0.36, 0.12, 0.95), Color(0.70, 0.20, 0.08, 0.48), Color(0.98, 0.68, 0.22, 0.90), 1.05, 3.5, 28.0, 0.96, 0.05, 4.5)
	if approaches.has("ramp"):
		return _make_style("spark", Color(0.82, 0.96, 1.0, 1.0), Color(0.20, 0.72, 1.0, 0.95), Color(0.16, 0.48, 1.0, 0.52), Color(1.0, 0.90, 0.35, 0.95), 0.92, 3.2, 25.0, 1.20, 0.10, 8.0)
	match primary_role:
		"tank":
			return _make_style("shield", Color(0.86, 0.95, 1.0, 1.0), Color(0.40, 0.72, 1.0, 0.95), Color(0.24, 0.48, 0.86, 0.45), Color(0.78, 0.95, 1.0, 0.95), 1.18, 4.1, 31.0, 0.92)
		"brawler":
			return _make_style("slash", Color(1.0, 0.80, 0.54, 1.0), Color(1.0, 0.34, 0.16, 0.95), Color(0.80, 0.20, 0.08, 0.46), Color(1.0, 0.92, 0.58, 0.92), 1.16, 4.2, 30.0, 1.04)
		"assassin":
			return _make_style("needle", Color(0.86, 0.96, 1.0, 1.0), Color(0.34, 0.98, 0.92, 0.95), Color(0.12, 0.72, 0.82, 0.48), Color(1.0, 0.16, 0.58, 0.92), 0.88, 2.8, 23.0, 1.22)
		"marksman":
			return _make_style("bolt", Color(0.98, 0.92, 0.58, 1.0), Color(0.22, 0.80, 1.0, 0.95), Color(0.18, 0.54, 1.0, 0.50), Color(1.0, 0.86, 0.28, 0.94), 0.94, 3.0, 24.0, 1.24)
		"mage":
			return _make_style("rune", Color(0.88, 0.82, 1.0, 1.0), Color(0.62, 0.40, 1.0, 0.95), Color(0.38, 0.20, 0.86, 0.46), Color(0.82, 1.0, 0.96, 0.92), 1.10, 3.7, 30.0, 1.02, 0.08, 5.0)
		"support":
			return _make_style("ring", Color(0.84, 1.0, 0.86, 1.0), Color(0.34, 1.0, 0.64, 0.95), Color(0.16, 0.76, 0.46, 0.44), Color(0.94, 0.98, 0.62, 0.92), 1.02, 3.3, 27.0, 1.00, 0.05, 5.5)
		_:
			return _make_style("orb", Color(0.90, 0.96, 1.0, 1.0), Color(0.28, 0.72, 1.0, 0.95), Color(0.16, 0.44, 0.88, 0.46), Color(1.0, 0.90, 0.55, 0.90), 1.0, 3.0, 25.0)

static func _apply_unit_override(style: Dictionary[String, Variant], unit_id: String) -> void:
	match unit_id:
		"axiom":
			_merge_style(style, _make_style("ring", Color(0.78, 1.0, 0.95, 1.0), Color(0.20, 0.98, 0.86, 0.96), Color(0.10, 0.70, 0.74, 0.46), Color(0.96, 1.0, 0.72, 0.96), 1.08, 3.4, 28.0, 1.02, 0.08, 5.0))
		"berebell":
			_merge_style(style, _make_style("shield", Color(0.92, 0.98, 1.0, 1.0), Color(0.58, 0.78, 1.0, 0.96), Color(0.32, 0.50, 0.90, 0.42), Color(0.78, 1.0, 1.0, 0.92), 1.22, 4.4, 33.0, 0.90))
		"bo":
			_merge_style(style, _make_style("coin", Color(1.0, 0.86, 0.34, 1.0), Color(0.92, 0.48, 0.10, 0.96), Color(0.88, 0.42, 0.08, 0.44), Color(0.98, 1.0, 0.70, 0.94), 1.10, 3.7, 28.0, 1.06))
		"bonko":
			_merge_style(style, _make_style("ember", Color(1.0, 0.78, 0.42, 1.0), Color(1.0, 0.22, 0.10, 0.96), Color(0.84, 0.16, 0.06, 0.46), Color(1.0, 0.92, 0.42, 0.96), 1.18, 4.5, 32.0, 1.00, 0.05, 4.0))
		"brute":
			_merge_style(style, _make_style("hammer", Color(0.92, 0.92, 0.88, 1.0), Color(0.72, 0.58, 0.44, 0.98), Color(0.46, 0.34, 0.26, 0.42), Color(1.0, 0.70, 0.34, 0.94), 1.30, 4.8, 35.0, 0.86))
		"mara":
			_merge_style(style, _make_style("ribbon", Color(1.0, 0.84, 0.94, 1.0), Color(0.96, 0.36, 0.72, 0.94), Color(0.70, 0.22, 0.54, 0.42), Color(0.78, 1.0, 0.94, 0.90), 1.02, 3.2, 27.0, 1.04, 0.16, 4.8))
		"grint":
			_merge_style(style, _make_style("chain", Color(0.86, 0.94, 1.0, 1.0), Color(0.38, 0.62, 0.90, 0.96), Color(0.18, 0.36, 0.64, 0.44), Color(1.0, 0.82, 0.38, 0.94), 1.14, 4.0, 30.0, 1.08))
		"hexeon":
			_merge_style(style, _make_style("needle", Color(0.92, 1.0, 1.0, 1.0), Color(0.18, 1.0, 0.92, 0.98), Color(0.08, 0.76, 0.84, 0.50), Color(1.0, 0.12, 0.52, 0.96), 0.88, 2.9, 24.0, 1.30))
		"korath":
			_merge_style(style, _make_style("shield", Color(0.82, 0.94, 1.0, 1.0), Color(0.20, 0.64, 1.0, 0.96), Color(0.10, 0.36, 0.78, 0.45), Color(0.92, 0.96, 1.0, 0.94), 1.25, 4.6, 34.0, 0.92))
		"kythera":
			_merge_style(style, _make_style("rune", Color(0.98, 0.86, 1.0, 1.0), Color(0.86, 0.38, 1.0, 0.96), Color(0.46, 0.18, 0.86, 0.46), Color(0.68, 1.0, 0.95, 0.92), 1.12, 3.7, 30.0, 1.06, 0.12, 5.4))
		"luna":
			_merge_style(style, _make_style("crescent", Color(0.82, 0.94, 1.0, 1.0), Color(0.36, 0.62, 1.0, 0.96), Color(0.18, 0.32, 0.86, 0.48), Color(0.96, 1.0, 0.86, 0.94), 1.04, 3.2, 30.0, 1.04, 0.10, 4.8))
		"morrak":
			_merge_style(style, _make_style("scythe", Color(0.92, 1.0, 0.82, 1.0), Color(0.42, 1.0, 0.42, 0.96), Color(0.16, 0.70, 0.24, 0.48), Color(1.0, 0.18, 0.34, 0.92), 1.08, 3.6, 29.0, 1.16))
		"mortem":
			_merge_style(style, _make_style("blood", Color(1.0, 0.68, 0.58, 1.0), Color(0.96, 0.06, 0.12, 0.98), Color(0.64, 0.04, 0.08, 0.48), Color(0.98, 0.86, 0.62, 0.90), 1.20, 4.3, 33.0, 0.98))
		"nyxa":
			_merge_style(style, _make_style("star", Color(0.96, 0.84, 1.0, 1.0), Color(0.78, 0.28, 1.0, 0.96), Color(0.44, 0.16, 0.82, 0.50), Color(1.0, 0.96, 0.44, 0.96), 0.96, 3.1, 26.0, 1.22, 0.22, 8.0))
		"paisley":
			_merge_style(style, _make_style("bubble", Color(0.74, 1.0, 0.98, 1.0), Color(0.28, 0.90, 1.0, 0.92), Color(0.14, 0.62, 0.82, 0.40), Color(1.0, 0.82, 0.96, 0.92), 1.08, 3.2, 29.0, 0.98, 0.18, 4.6))
		"repo":
			_merge_style(style, _make_style("paper", Color(0.98, 0.92, 0.76, 1.0), Color(0.82, 0.58, 0.28, 0.96), Color(0.56, 0.40, 0.20, 0.42), Color(0.36, 0.86, 1.0, 0.92), 1.00, 3.1, 27.0, 1.06))
		"rooket":
			_merge_style(style, _make_style("brace", Color(0.90, 0.96, 1.0, 1.0), Color(0.30, 0.70, 1.0, 0.98), Color(0.14, 0.42, 0.76, 0.46), Color(1.0, 0.78, 0.24, 0.96), 1.08, 3.7, 30.0, 1.12))
		"sari":
			_merge_style(style, _make_style("bolt", Color(1.0, 0.94, 0.58, 1.0), Color(0.24, 0.78, 1.0, 0.98), Color(0.12, 0.54, 1.0, 0.52), Color(1.0, 0.72, 0.24, 0.96), 0.90, 2.9, 24.0, 1.34))
		"teller":
			_merge_style(style, _make_style("card", Color(0.96, 0.98, 0.84, 1.0), Color(0.34, 0.92, 0.68, 0.96), Color(0.18, 0.68, 0.46, 0.42), Color(1.0, 0.84, 0.24, 0.94), 1.00, 3.2, 27.0, 1.10))
		"totem":
			_merge_style(style, _make_style("glyph", Color(0.90, 1.0, 0.74, 1.0), Color(0.54, 0.86, 0.24, 0.96), Color(0.30, 0.58, 0.14, 0.42), Color(0.96, 0.80, 0.34, 0.94), 1.14, 3.8, 31.0, 0.96))
		"veyra":
			_merge_style(style, _make_style("ribbon", Color(0.84, 0.96, 1.0, 1.0), Color(0.28, 0.82, 1.0, 0.96), Color(0.12, 0.54, 0.86, 0.44), Color(1.0, 0.64, 0.86, 0.92), 1.00, 3.1, 27.0, 1.14, 0.14, 5.8))
		"volt":
			_merge_style(style, _make_style("spark", Color(0.94, 1.0, 0.58, 1.0), Color(0.38, 0.86, 1.0, 0.96), Color(0.18, 0.58, 1.0, 0.52), Color(1.0, 0.96, 0.28, 0.98), 0.94, 3.0, 25.0, 1.30, 0.18, 9.5))
		"vykos":
			_merge_style(style, _make_style("blood", Color(1.0, 0.72, 0.64, 1.0), Color(0.82, 0.06, 0.18, 0.98), Color(0.52, 0.02, 0.10, 0.48), Color(0.98, 0.58, 0.92, 0.92), 1.12, 3.8, 30.0, 1.08))
		"beegle":
			_merge_style(style, _make_style("thorn", Color(0.90, 1.0, 0.56, 1.0), Color(0.48, 0.84, 0.22, 0.94), Color(0.28, 0.56, 0.10, 0.42), Color(0.94, 0.82, 0.32, 0.90), 0.98, 3.0, 25.0, 1.08))
		"drubble":
			_merge_style(style, _make_style("stone", Color(0.82, 0.80, 0.72, 1.0), Color(0.56, 0.48, 0.38, 0.94), Color(0.34, 0.28, 0.22, 0.40), Color(0.96, 0.74, 0.42, 0.88), 1.18, 4.0, 30.0, 0.88))
		"drueling":
			_merge_style(style, _make_style("thorn", Color(0.82, 1.0, 0.78, 1.0), Color(0.28, 0.78, 0.38, 0.94), Color(0.12, 0.52, 0.22, 0.42), Color(0.86, 1.0, 0.36, 0.90), 1.00, 3.2, 26.0, 1.12))
		"faeling":
			_merge_style(style, _make_style("ember", Color(1.0, 0.88, 0.52, 1.0), Color(0.88, 0.36, 0.10, 0.94), Color(0.58, 0.20, 0.06, 0.42), Color(0.98, 0.72, 0.28, 0.90), 1.04, 3.5, 28.0, 1.02, 0.10, 5.4))
		"creep":
			_merge_style(style, _make_style("orb", Color(0.78, 0.86, 0.78, 1.0), Color(0.48, 0.62, 0.48, 0.92), Color(0.26, 0.38, 0.26, 0.38), Color(0.84, 0.92, 0.62, 0.86), 0.95, 2.8, 23.0, 0.96))
		"cinder":
			_merge_style(style, _make_style("fuse", Color(1.0, 0.90, 0.46, 1.0), Color(1.0, 0.30, 0.08, 0.98), Color(0.72, 0.12, 0.04, 0.48), Color(1.0, 0.70, 0.18, 0.96), 1.10, 3.8, 30.0, 0.92, 0.10, 4.2))
		"miri":
			_merge_style(style, _make_style("lesson", Color(1.0, 0.94, 0.72, 1.0), Color(0.96, 0.62, 0.22, 0.96), Color(0.60, 0.34, 0.10, 0.42), Color(0.44, 0.92, 1.0, 0.96), 1.06, 3.4, 28.0, 1.02))
		"pilfer":
			_merge_style(style, _make_style("swap", Color(0.76, 1.0, 0.92, 1.0), Color(0.10, 0.92, 0.76, 0.98), Color(0.04, 0.58, 0.48, 0.48), Color(1.0, 0.78, 0.24, 0.96), 0.96, 3.0, 26.0, 1.26))
		"knoll":
			_merge_style(style, _make_style("receipt", Color(1.0, 0.94, 0.78, 1.0), Color(0.86, 0.62, 0.30, 0.96), Color(0.54, 0.36, 0.18, 0.42), Color(0.54, 0.92, 1.0, 0.94), 1.00, 3.2, 27.0, 1.04))
		"velour":
			_merge_style(style, _make_style("knot", Color(1.0, 0.80, 0.94, 1.0), Color(0.92, 0.28, 0.72, 0.98), Color(0.58, 0.12, 0.44, 0.42), Color(0.70, 1.0, 0.84, 0.96), 1.08, 3.6, 30.0, 0.98, 0.18, 4.6))
		"caldera":
			_merge_style(style, _make_style("crater", Color(1.0, 0.78, 0.42, 1.0), Color(0.96, 0.22, 0.06, 0.98), Color(0.64, 0.10, 0.02, 0.48), Color(1.0, 0.94, 0.46, 0.96), 1.28, 4.6, 35.0, 0.88, 0.06, 3.8))
		"egress":
			_merge_style(style, _make_style("exit", Color(0.92, 1.0, 1.0, 1.0), Color(0.18, 0.94, 1.0, 0.98), Color(0.06, 0.58, 0.76, 0.48), Color(1.0, 0.10, 0.36, 0.98), 0.88, 2.8, 24.0, 1.30))
		"ivara":
			_merge_style(style, _make_style("bid", Color(1.0, 0.92, 0.58, 1.0), Color(0.30, 0.84, 1.0, 0.98), Color(0.12, 0.54, 0.82, 0.46), Color(1.0, 0.58, 0.22, 0.96), 0.96, 3.0, 26.0, 1.20))
		"juno_vale":
			_merge_style(style, _make_style("constellation", Color(0.88, 0.94, 1.0, 1.0), Color(0.52, 0.54, 1.0, 0.98), Color(0.28, 0.26, 0.74, 0.44), Color(0.76, 1.0, 0.90, 0.96), 1.16, 3.7, 32.0, 0.98, 0.20, 4.4))
		"kett":
			_merge_style(style, _make_style("fist", Color(1.0, 0.82, 0.56, 1.0), Color(0.94, 0.30, 0.12, 0.98), Color(0.66, 0.14, 0.06, 0.46), Color(1.0, 0.96, 0.62, 0.96), 1.18, 4.3, 32.0, 1.06))
		"marble":
			_merge_style(style, _make_style("sanctuary", Color(0.92, 1.0, 0.86, 1.0), Color(0.44, 0.84, 1.0, 0.98), Color(0.20, 0.52, 0.82, 0.44), Color(1.0, 0.86, 0.34, 0.96), 1.08, 3.4, 30.0, 1.08))
		"noxley":
			_merge_style(style, _make_style("static", Color(1.0, 0.62, 0.62, 1.0), Color(0.96, 0.04, 0.18, 0.98), Color(0.62, 0.02, 0.10, 0.48), Color(0.48, 0.88, 1.0, 0.96), 1.08, 3.5, 29.0, 1.16, 0.20, 9.0))
		"prisma":
			_merge_style(style, _make_style("prism", Color(0.94, 0.86, 1.0, 1.0), Color(0.70, 0.30, 1.0, 0.98), Color(0.38, 0.12, 0.78, 0.46), Color(0.34, 1.0, 0.86, 0.96), 1.18, 3.9, 33.0, 0.96, 0.12, 5.2))
		"quorra":
			_merge_style(style, _make_style("timeplate", Color(0.82, 0.98, 1.0, 1.0), Color(0.18, 0.78, 1.0, 0.98), Color(0.08, 0.42, 0.82, 0.46), Color(1.0, 0.38, 0.72, 0.96), 0.96, 3.0, 27.0, 1.24))
		"sable":
			_merge_style(style, _make_style("footnote", Color(1.0, 0.94, 0.70, 1.0), Color(0.34, 0.74, 1.0, 0.98), Color(0.16, 0.44, 0.78, 0.46), Color(0.96, 0.62, 0.22, 0.96), 0.94, 3.0, 26.0, 1.26))
		"bastionne":
			_merge_style(style, _make_style("gate", Color(0.84, 0.94, 1.0, 1.0), Color(0.28, 0.62, 1.0, 0.98), Color(0.12, 0.34, 0.72, 0.46), Color(1.0, 0.82, 0.34, 0.96), 1.34, 4.8, 37.0, 0.84))
		"draxelle":
			_merge_style(style, _make_style("hook", Color(0.94, 0.90, 0.82, 1.0), Color(0.78, 0.38, 0.14, 0.98), Color(0.48, 0.20, 0.08, 0.46), Color(1.0, 0.70, 0.24, 0.96), 1.26, 4.7, 35.0, 0.94))
		"gable":
			_merge_style(style, _make_style("market", Color(1.0, 0.92, 0.62, 1.0), Color(0.28, 0.88, 0.72, 0.98), Color(0.12, 0.54, 0.42, 0.44), Color(1.0, 0.56, 0.18, 0.96), 1.02, 3.3, 28.0, 1.16))
		"omenry":
			_merge_style(style, _make_style("isolate", Color(0.92, 0.96, 1.0, 1.0), Color(0.24, 0.72, 1.0, 0.98), Color(0.10, 0.42, 0.78, 0.46), Color(1.0, 0.26, 0.44, 0.96), 0.92, 2.9, 25.0, 1.28))
		"orielle":
			_merge_style(style, _make_style("debt", Color(0.92, 0.82, 1.0, 1.0), Color(0.66, 0.24, 1.0, 0.98), Color(0.38, 0.10, 0.72, 0.46), Color(1.0, 0.72, 0.28, 0.96), 1.18, 3.9, 33.0, 0.92, 0.12, 4.8))
		"ravel":
			_merge_style(style, _make_style("puppet", Color(1.0, 0.84, 0.94, 1.0), Color(0.86, 0.24, 0.68, 0.98), Color(0.52, 0.10, 0.40, 0.44), Color(0.60, 0.96, 1.0, 0.96), 1.18, 4.0, 32.0, 1.00, 0.18, 5.0))
		"saffron":
			_merge_style(style, _make_style("poultice", Color(1.0, 0.96, 0.70, 1.0), Color(0.92, 0.62, 0.18, 0.98), Color(0.58, 0.34, 0.08, 0.42), Color(0.56, 1.0, 0.66, 0.96), 1.14, 3.7, 31.0, 0.96))
		"vesper":
			_merge_style(style, _make_style("late_fee", Color(0.92, 1.0, 1.0, 1.0), Color(0.20, 0.88, 1.0, 0.98), Color(0.08, 0.50, 0.76, 0.48), Color(1.0, 0.08, 0.38, 0.98), 0.90, 2.8, 25.0, 1.30))
		"malachor":
			_merge_style(style, _make_style("flesh_chain", Color(1.0, 0.68, 0.62, 1.0), Color(0.76, 0.04, 0.14, 0.98), Color(0.44, 0.02, 0.08, 0.50), Color(0.94, 0.78, 0.48, 0.96), 1.42, 5.2, 40.0, 0.82))
		"meridian":
			_merge_style(style, _make_style("spectrum", Color(0.98, 0.92, 1.0, 1.0), Color(0.50, 0.42, 1.0, 0.98), Color(0.22, 0.20, 0.76, 0.46), Color(0.28, 1.0, 0.80, 0.98), 1.30, 4.5, 37.0, 0.92, 0.16, 5.0))
		"nullora":
			_merge_style(style, _make_style("last_word", Color(0.94, 1.0, 1.0, 1.0), Color(0.10, 0.90, 1.0, 0.98), Color(0.04, 0.50, 0.72, 0.50), Color(1.0, 0.04, 0.30, 1.0), 0.92, 3.0, 27.0, 1.34))
		"quillith":
			_merge_style(style, _make_style("exam", Color(0.94, 0.90, 1.0, 1.0), Color(0.62, 0.28, 1.0, 0.98), Color(0.34, 0.12, 0.72, 0.46), Color(1.0, 0.84, 0.30, 0.98), 1.32, 4.4, 37.0, 0.90))

static func _merge_style(base: Dictionary[String, Variant], override: Dictionary[String, Variant]) -> void:
	for key in override.keys():
		base[String(key)] = override[key]
