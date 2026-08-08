#!/usr/bin/env python3

from __future__ import annotations

import json
import tempfile
import threading
import unittest
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

from serve_unit_art_review import create_server


def request_json(url: str, payload: dict[str, Any] | None = None) -> tuple[int, dict[str, Any]]:
    body = None
    headers = {"Accept": "application/json"}
    if payload is not None:
        body = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"
    request = urllib.request.Request(url, data=body, headers=headers, method="POST" if body else "GET")
    try:
        with urllib.request.urlopen(request, timeout=5) as response:
            return response.status, json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        return error.code, json.loads(error.read().decode("utf-8"))


class UnitArtReviewPersistenceTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary_directory.name)
        tool_dir = self.root / "tools" / "art"
        tool_dir.mkdir(parents=True)
        (tool_dir / "unit-art-review.html").write_text("<!doctype html><title>review test</title>\n", encoding="utf-8")
        self.state_path = tool_dir / "unit-art-review-state.json"
        self.server = create_server("127.0.0.1", 0, self.root, self.state_path)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.base_url = f"http://127.0.0.1:{self.server.server_port}"

    def tearDown(self) -> None:
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=5)
        self.temporary_directory.cleanup()

    def document(self) -> dict[str, Any]:
        return {
            "schema_version": 1,
            "project": "blood-will-pay",
            "decisions": {"phase2-concepts/versions/luna/p2-06.png": "like"},
            "comments": {"phase2-concepts/versions/luna/p2-06.png": "Keep the ominous smile."},
            "pins": ["luna|p2-06"],
            "defaults": {"luna": "phase2-concepts/versions/luna/p2-06.png"},
            "ui": {"review_set": "phase2"},
            "selection": {"active_item_key": "luna|p2-06"},
            "future_extension": {"preserve_me": True},
        }

    def test_alias_and_atomic_state_round_trip(self) -> None:
        with urllib.request.urlopen(f"{self.base_url}/tools/art/unit-art-review", timeout=5) as response:
            self.assertEqual(response.status, 200)
            self.assertIn(b"review test", response.read())

        status, missing = request_json(f"{self.base_url}/api/unit-art-review-state")
        self.assertEqual(status, 404)
        self.assertEqual(missing["error"]["code"], "STATE_NOT_FOUND")

        status, saved = request_json(
            f"{self.base_url}/api/unit-art-review-state",
            {"expected_revision": None, "state": self.document()},
        )
        self.assertEqual(status, 200)
        self.assertEqual(saved["state"]["revision"], 1)
        self.assertTrue(saved["state"]["future_extension"]["preserve_me"])
        self.assertEqual(json.loads(self.state_path.read_text(encoding="utf-8")), saved["state"])

        status, loaded = request_json(f"{self.base_url}/api/unit-art-review-state")
        self.assertEqual(status, 200)
        self.assertEqual(loaded["state"], saved["state"])

        next_document = dict(saved["state"])
        next_document["comments"] = {
            **next_document["comments"],
            "phase2-concepts/versions/quillith/p2-03.png": "Sharper silhouette.",
        }
        status, updated = request_json(
            f"{self.base_url}/api/unit-art-review-state",
            {"expected_revision": 1, "state": next_document},
        )
        self.assertEqual(status, 200)
        self.assertEqual(updated["state"]["revision"], 2)
        self.assertTrue(updated["state"]["future_extension"]["preserve_me"])

    def test_revision_conflict_does_not_overwrite(self) -> None:
        status, saved = request_json(
            f"{self.base_url}/api/unit-art-review-state",
            {"expected_revision": None, "state": self.document()},
        )
        self.assertEqual(status, 200)
        original_bytes = self.state_path.read_bytes()

        conflicting = dict(saved["state"])
        conflicting["comments"] = {"discarded": "must not overwrite"}
        status, conflict = request_json(
            f"{self.base_url}/api/unit-art-review-state",
            {"expected_revision": 0, "state": conflicting},
        )
        self.assertEqual(status, 409)
        self.assertEqual(conflict["error"]["code"], "STATE_CONFLICT")
        self.assertEqual(self.state_path.read_bytes(), original_bytes)

    def test_malformed_file_is_reported_and_preserved(self) -> None:
        malformed = b'{"decisions": {"luna": "like"}'
        self.state_path.write_bytes(malformed)

        status, loaded = request_json(f"{self.base_url}/api/unit-art-review-state")
        self.assertEqual(status, 500)
        self.assertEqual(loaded["error"]["code"], "STATE_FILE_MALFORMED")
        self.assertEqual(self.state_path.read_bytes(), malformed)

        status, rejected = request_json(
            f"{self.base_url}/api/unit-art-review-state",
            {"expected_revision": None, "state": self.document()},
        )
        self.assertEqual(status, 500)
        self.assertEqual(rejected["error"]["code"], "STATE_FILE_MALFORMED")
        self.assertEqual(self.state_path.read_bytes(), malformed)

    def test_malformed_request_is_rejected_without_state_file(self) -> None:
        invalid = self.document()
        invalid["decisions"] = {"luna": "surprise"}
        status, rejected = request_json(
            f"{self.base_url}/api/unit-art-review-state",
            {"expected_revision": None, "state": invalid},
        )
        self.assertEqual(status, 422)
        self.assertEqual(rejected["error"]["code"], "STATE_INVALID")
        self.assertFalse(self.state_path.exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
