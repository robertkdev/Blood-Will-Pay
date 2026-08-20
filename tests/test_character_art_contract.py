from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PROFILE = (ROOT / "scripts/game/units/unit_profile.gd").read_text(encoding="utf-8")
CATALOG = (ROOT / "scripts/game/shop/unit_catalog.gd").read_text(encoding="utf-8")
OFFER = (ROOT / "scripts/game/shop/shop_offer.gd").read_text(encoding="utf-8")
PANEL = (ROOT / "scripts/ui/shop/shop_panel.gd").read_text(encoding="utf-8")


def test_unit_art_has_optional_surface_derivatives_with_legacy_fallbacks():
    for field in [
        "shop_card_art_path",
        "portrait_art_path",
        "ledger_unlock_art_path",
        "menu_info_art_path",
    ]:
        assert f"@export var {field}: String" in PROFILE
    assert "func shop_card_path()" in PROFILE
    assert "func portrait_path()" in PROFILE
    assert "else sprite_path" in PROFILE


def test_shop_uses_a_reviewed_card_derivative_when_one_is_declared():
    assert '"shop_card_art_path": shop_card_art_path' in CATALOG
    assert "func get_shop_card_art_path" in CATALOG
    assert "var shop_card_art_path: String" in OFFER
    assert "off.shop_card_art_path" in PANEL
