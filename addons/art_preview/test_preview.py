"""The evidence boundary must reject plausible but mismatched captures."""
import argparse
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import time
import unittest
from unittest.mock import patch

from PIL import Image

spec = importlib.util.spec_from_file_location("preview", Path(__file__).with_name("preview.py"))
preview = importlib.util.module_from_spec(spec)
spec.loader.exec_module(preview)


class EvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name).resolve()
        self.project_patch = patch.object(preview, "PROJECT", self.root)
        self.project_patch.start()
        self.image = self.root / "actual.png"
        Image.new("RGB", (1920, 1080), (32, 48, 64)).save(self.image)
        self.data = {"session_id": "owned", "source_files": {}, "editor_pid": 12,
                     "reference": str(self.image), "reference_sha256": preview.sha(self.image),
                     "runtime_provenance": {"source_sha": "abc"}}
        self.status = {"pid": 34, "revision": 2}
        self.capture = {"revision": 2, "actual": str(self.image), "reference": str(self.image),
                        "actual_sha256": preview.sha(self.image), "reference_sha256": preview.sha(self.image),
                        "captured_at_unix": time.time(), "runtime_provenance": {
                            "project_path": str(self.root), "editor_pid": 12, "game_pid": 34,
                            "source_sha": "abc", "session_id": "owned", "frames_before": 40,
                            "reference_source": str(self.image), "reference_source_sha256": preview.sha(self.image),
                            "frames_drawn": 42, "stale_frame": False, "viewport": "1920x1080",
                            "preview_scene": preview.SCENE, "window_mode": 3}}

    def tearDown(self):
        self.project_patch.stop()
        self.temp.cleanup()

    def test_valid_contract_and_invalid_variants(self):
        preview.validate_capture(self.data, self.status, self.capture)
        variants = {"session_id": "other", "frames_drawn": 40, "stale_frame": True,
                    "window_mode": 0, "game_pid": 999, "editor_pid": 999,
                    "source_sha": "other", "preview_scene": "res://wrong.tscn", "viewport": "1280x720"}
        for key, value in variants.items():
            with self.subTest(key=key):
                broken = copy.deepcopy(self.capture)
                broken["runtime_provenance"][key] = value
                with self.assertRaises(ValueError):
                    preview.validate_capture(self.data, self.status, broken)

    def test_pending_settings_revision_is_not_accepted(self):
        self.capture["revision"] = 1
        with self.assertRaises(ValueError):
            preview.validate_capture(self.data, self.status, self.capture)

    def test_image_tampering_is_rejected(self):
        self.image.write_bytes(b"replaced")
        with self.assertRaises(ValueError):
            preview.validate_capture(self.data, self.status, self.capture)

    def test_source_change_requires_new_runtime(self):
        source = self.root / "screen.gd"
        source.write_text("old")
        self.data["source_files"] = {"screen.gd": preview.sha(source)}
        source.write_text("new")
        with self.assertRaises(ValueError):
            preview.validate_capture(self.data, self.status, self.capture)

    def test_concurrent_command_cannot_remove_owner_lock(self):
        lock = self.root / "command.lock"
        lock.write_text("existing owner")
        preview.write(self.root / "status.json", {"ready": True, "session_id": "owned", "revision": 2})
        with patch.object(preview, "session", return_value={"session_id": "owned", "output_dir": str(self.root)}):
            with self.assertRaises(FileExistsError):
                preview.command(argparse.Namespace(op="capture", settings=None, path=None, timeout=.01))
        self.assertEqual(lock.read_text(), "existing owner")

    def test_archive_cannot_escape_private_fixture(self):
        outside = self.root / "outside.json"
        outside.write_text("preserve me")
        preview.write(self.root / "addons/art_preview/profile.json", {
            "user_data_name": "Game", "archive_before_run": [str(outside)]})
        with self.assertRaises(ValueError):
            preview.archive_fixture_saves({"output_dir": str(self.root), "session_id": "owned"})
        self.assertEqual(outside.read_text(), "preserve me")

    def test_expected_revision_rejects_before_sending(self):
        preview.write(self.root / "status.json", {"ready": True, "session_id": "owned", "revision": 3})
        with patch.object(preview, "session", return_value={"session_id": "owned", "output_dir": str(self.root)}):
            with self.assertRaisesRegex(ValueError, "Revision conflict"):
                preview.command(argparse.Namespace(op="set", settings='{"spacing":1.1}', path=None,
                                                    timeout=.1, expected_revision=2))
        self.assertFalse((self.root / "command.json").exists())

    def test_wait_capture_rejects_superseding_writer(self):
        preview.write(self.root / "status.json", {"session_id": "owned", "revision": 4})
        with self.assertRaisesRegex(ValueError, "superseded"):
            preview.wait_capture({"session_id": "owned", "output_dir": str(self.root)}, 3,
                                 time.monotonic() + 1)

    def test_capture_wait_ignores_previous_frame(self):
        pending = {"session_id": "owned", "revision": 2, "last_capture": {"id": "old", "revision": 2}}
        fresh = copy.deepcopy(pending)
        fresh["last_capture"]["id"] = "fresh"
        with patch.object(preview, "read", side_effect=[pending, fresh]), \
                patch.object(preview.time, "sleep"), patch.object(preview, "validate_capture") as validate:
            capture = preview.wait_capture({"session_id": "owned", "output_dir": str(self.root)},
                                           2, time.monotonic() + 1, previous_id="old")
        self.assertEqual(capture["id"], "fresh")
        validate.assert_called_once()

    def test_windows_status_replacement_contention_is_retried(self):
        with patch.object(Path, "read_text", side_effect=[PermissionError("publishing"), '{"revision":3}']), \
                patch.object(preview.time, "sleep"):
            self.assertEqual(preview.read(self.root / "status.json"), {"revision": 3})

    def test_substituted_reference_is_rejected(self):
        alternate = self.root / "other-reference.png"
        Image.new("RGB", (1920, 1080), (255, 64, 32)).save(alternate)
        self.capture["reference"] = str(alternate)
        self.capture["reference_sha256"] = preview.sha(alternate)
        self.capture["runtime_provenance"].update(reference_source=str(alternate),
                                                reference_source_sha256=preview.sha(alternate))
        with self.assertRaisesRegex(ValueError, "selected reference"):
            preview.validate_capture(self.data, self.status, self.capture)

    def test_generated_actual_is_not_an_approved_reference(self):
        preview.write(self.root / "capture.json", {"actual": str(self.image)})
        with self.assertRaisesRegex(ValueError, "own art reference"):
            preview.reference_info(self.image)

    def test_loaded_art_is_hashed_and_changes_invalidate_evidence(self):
        asset = self.root / "assets/backdrop.png"
        asset.parent.mkdir()
        asset.write_bytes(b"original artwork")
        self.data["source_files"] = preview.source_files()
        self.capture["runtime_provenance"]["loaded_sources"] = ["assets/backdrop.png"]
        self.assertIn("assets/backdrop.png", self.data["source_files"])
        preview.validate_capture(self.data, self.status, self.capture)
        asset.write_bytes(b"changed artwork")
        with self.assertRaisesRegex(ValueError, "Source changed"):
            preview.validate_capture(self.data, self.status, self.capture)


if __name__ == "__main__":
    unittest.main()
