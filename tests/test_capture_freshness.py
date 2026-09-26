"""Regression: nonblank cached game frames are not fresh visual evidence."""
import asyncio
import base64
import importlib.util
import io
import json
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import AsyncMock, patch

from PIL import Image

spec = importlib.util.spec_from_file_location("capture", Path(__file__).parents[1] / "tools/godot_mcp_capture.py")
capture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(capture)


def reply(metadata=None, size=8, structured=False):
    buffer = io.BytesIO()
    Image.new("RGB", (size, size), (200, 130, 80)).save(buffer, format="PNG")
    content = [SimpleNamespace(type="image", data=base64.b64encode(buffer.getvalue()).decode())]
    if metadata is not None and not structured:
        content.append(SimpleNamespace(type="text", text=json.dumps(metadata)))
    return SimpleNamespace(content=content, structuredContent=metadata if structured else None)


class FreshnessTests(unittest.IsolatedAsyncioTestCase):
    async def test_retries_stale_nonblank_frame_and_preserves_freshness(self):
        with patch.object(capture, "_call", AsyncMock(side_effect=[
            reply({"stale_frame": True, "frames_drawn": 40}),
            reply({"stale_frame": False, "frames_drawn": 42})])):
            _, _, metrics, attempts = await capture._capture_visible_frame(None, "s", "game", 0, 2)
        self.assertEqual(attempts, 2)
        self.assertEqual(metrics["freshness"], {"stale_frame": False, "frames_drawn": 42})

    async def test_missing_freshness_is_not_evidence(self):
        with patch.object(capture, "_call", AsyncMock(return_value=reply())):
            with self.assertRaises(TimeoutError):
                await capture._capture_visible_frame(None, "s", "game", 0, .01)

    async def test_stale_frame_never_passes_nonblank_check(self):
        with patch.object(capture, "_call", AsyncMock(return_value=reply({"stale_frame": True, "frames_drawn": 500}))):
            with self.assertRaises(TimeoutError):
                await capture._capture_visible_frame(None, "s", "game", 0, .01)

    async def test_repeated_frame_counter_after_invalid_dimensions_is_rejected(self):
        with patch.object(capture, "_call", AsyncMock(side_effect=[
            reply({"stale_frame": False, "frames_drawn": 42}, 8),
            reply({"stale_frame": False, "frames_drawn": 42}, 16),
            reply({"stale_frame": False, "frames_drawn": 43}, 16)])):
            _, _, metrics, attempts = await capture._capture_visible_frame(None, "s", "game", 0, 2, 16, 16)
        self.assertEqual(attempts, 3)
        self.assertEqual(metrics["freshness"]["frames_drawn"], 43)

    async def test_nested_structured_metadata(self):
        with patch.object(capture, "_call", AsyncMock(return_value=reply(
            {"capture": {"stale_frame": False, "frames_drawn": 11}}, structured=True))):
            _, _, metrics, _ = await capture._capture_visible_frame(None, "s", "game", 0, 1)
        self.assertEqual(metrics["freshness"]["frames_drawn"], 11)

    async def test_editor_viewport_does_not_require_game_counter(self):
        with patch.object(capture, "_call", AsyncMock(return_value=reply())):
            _, _, _, attempts = await capture._capture_visible_frame(None, "s", "viewport", 0, 1)
        self.assertEqual(attempts, 1)


if __name__ == "__main__":
    unittest.main()
