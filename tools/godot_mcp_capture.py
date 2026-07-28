#!/usr/bin/env python3
"""Capture a live Godot editor/game image through the godot-ai MCP server."""

from __future__ import annotations

import argparse
import asyncio
import base64
import hashlib
import json
import os
from pathlib import Path
import struct
import time
from typing import Any
import zlib

from mcp import ClientSession
from mcp.client.streamable_http import streamablehttp_client


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Capture Godot through its live godot-ai MCP session.",
    )
    parser.add_argument("--url", default="http://127.0.0.1:8000/mcp")
    parser.add_argument("--output", required=True)
    parser.add_argument("--project-path", default="")
    parser.add_argument("--session-hint", default="")
    parser.add_argument(
        "--run",
        choices=("none", "main", "current", "custom"),
        default="none",
    )
    parser.add_argument("--scene", default="")
    parser.add_argument(
        "--source",
        choices=("game", "viewport", "viewport_2d", "cinematic"),
        default="game",
    )
    parser.add_argument("--max-resolution", type=int, default=0)
    parser.add_argument("--expected-width", type=int, default=0)
    parser.add_argument("--expected-height", type=int, default=0)
    parser.add_argument(
        "--force-relaunch",
        action="store_true",
        help="Stop an existing game before running the requested entrypoint.",
    )
    parser.add_argument("--wait-seconds", type=float, default=20.0)
    parser.add_argument("--visual-wait-seconds", type=float, default=15.0)
    parser.add_argument("--settle-seconds", type=float, default=0.0)
    parser.add_argument("--connection-attempts", type=int, default=3)
    return parser.parse_args()


def _result_texts(result: Any) -> list[str]:
    return [
        str(item.text)
        for item in result.content
        if getattr(item, "type", None) == "text"
    ]


def _result_json(result: Any) -> dict[str, Any]:
    texts: list[str] = _result_texts(result)
    if not texts:
        return {}
    try:
        payload: Any = json.loads(texts[0])
    except json.JSONDecodeError:
        return {"text": texts[0]}
    return payload if isinstance(payload, dict) else {"value": payload}


def _raise_for_tool_error(tool_name: str, result: Any) -> None:
    if bool(getattr(result, "isError", False)):
        raise RuntimeError(f"{tool_name} failed: {' | '.join(_result_texts(result))}")


def _normalize_path(value: str) -> str:
    return os.path.normcase(os.path.abspath(value.rstrip("/\\")))


def _game_is_active(state: dict[str, Any]) -> bool:
    game_status: dict[str, Any] = state.get("game_status", {})
    status: str = str(game_status.get("status", ""))
    return bool(
        game_status.get("active", False)
        or state.get("session_active", False)
        or state.get("is_playing", False)
        or status not in ("", "not_live", "stopped")
    )


def _choose_session(
    sessions: list[dict[str, Any]],
    project_path: str,
    session_hint: str,
) -> dict[str, Any]:
    candidates: list[dict[str, Any]] = sessions
    if project_path:
        wanted_path: str = _normalize_path(project_path)
        candidates = [
            session
            for session in candidates
            if _normalize_path(str(session.get("project_path", ""))) == wanted_path
        ]
    if session_hint:
        hint: str = session_hint.casefold()
        candidates = [
            session
            for session in candidates
            if hint
            in " ".join(
                (
                    str(session.get("session_id", "")),
                    str(session.get("name", "")),
                    str(session.get("project_path", "")),
                )
            ).casefold()
        ]
    if len(candidates) != 1:
        summary: list[dict[str, str]] = [
            {
                "session_id": str(session.get("session_id", "")),
                "name": str(session.get("name", "")),
                "project_path": str(session.get("project_path", "")),
            }
            for session in candidates
        ]
        raise RuntimeError(
            f"Expected exactly one matching Godot session; found {len(candidates)}: "
            f"{json.dumps(summary)}"
        )
    return candidates[0]


async def _call(session: ClientSession, tool_name: str, arguments: dict[str, Any]) -> Any:
    result: Any = await session.call_tool(tool_name, arguments)
    _raise_for_tool_error(tool_name, result)
    return result


async def _wait_for_capture(
    session: ClientSession,
    session_id: str,
    source: str,
    wait_seconds: float,
) -> dict[str, Any]:
    deadline: float = asyncio.get_running_loop().time() + max(wait_seconds, 0.5)
    last_state: dict[str, Any] = {}
    while asyncio.get_running_loop().time() < deadline:
        state_result: Any = await _call(
            session,
            "editor_state",
            {"session_id": session_id},
        )
        last_state = _result_json(state_result)
        status: str = str(last_state.get("game_status", {}).get("status", ""))
        if status == "break":
            raise RuntimeError(
                "Godot entered debugger break before capture became ready. "
                "Read editor/game logs and stop the broken run through MCP."
            )
        if source != "game" or bool(last_state.get("game_capture_ready", False)):
            return last_state
        await asyncio.sleep(0.25)
    raise TimeoutError(
        f"Godot capture was not ready after {wait_seconds:.1f}s: "
        f"{json.dumps(last_state)}"
    )


async def _wait_for_editor_ready(
    session: ClientSession,
    session_id: str,
    wait_seconds: float,
) -> dict[str, Any]:
    """Require two stable ready polls before launching a stopped project."""
    deadline: float = asyncio.get_running_loop().time() + max(wait_seconds, 0.5)
    last_state: dict[str, Any] = {}
    consecutive_ready: int = 0
    while asyncio.get_running_loop().time() < deadline:
        state_result: Any = await _call(
            session,
            "editor_state",
            {"session_id": session_id},
        )
        last_state = _result_json(state_result)
        status: str = str(last_state.get("game_status", {}).get("status", ""))
        if status == "break":
            raise RuntimeError(
                "Godot entered debugger break before the editor became ready. "
                "Read editor/game logs and stop the broken run through MCP."
            )
        readiness: str = str(last_state.get("readiness", "")).casefold()
        if readiness == "ready" and not _game_is_active(last_state):
            consecutive_ready += 1
            if consecutive_ready >= 2:
                return last_state
        else:
            consecutive_ready = 0
        await asyncio.sleep(0.25)
    raise TimeoutError(
        f"Godot editor was not stably ready after {wait_seconds:.1f}s: "
        f"{json.dumps(last_state)}"
    )


def _paeth_predictor(left: int, up: int, upper_left: int) -> int:
    estimate: int = left + up - upper_left
    left_distance: int = abs(estimate - left)
    up_distance: int = abs(estimate - up)
    upper_left_distance: int = abs(estimate - upper_left)
    if left_distance <= up_distance and left_distance <= upper_left_distance:
        return left
    if up_distance <= upper_left_distance:
        return up
    return upper_left


def _png_visual_metrics(image_bytes: bytes) -> dict[str, Any]:
    """Measure whether a Godot PNG contains visible pixels without Pillow."""
    if not image_bytes.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValueError("Screenshot payload is not a PNG")

    offset: int = 8
    width: int = 0
    height: int = 0
    bit_depth: int = 0
    color_type: int = -1
    interlace: int = -1
    compressed_parts: list[bytes] = []
    while offset + 12 <= len(image_bytes):
        length: int = struct.unpack(">I", image_bytes[offset : offset + 4])[0]
        chunk_type: bytes = image_bytes[offset + 4 : offset + 8]
        data_start: int = offset + 8
        data_end: int = data_start + length
        if data_end + 4 > len(image_bytes):
            raise ValueError("Screenshot PNG contains a truncated chunk")
        chunk_data: bytes = image_bytes[data_start:data_end]
        if chunk_type == b"IHDR":
            width, height, bit_depth, color_type, _, _, interlace = struct.unpack(
                ">IIBBBBB",
                chunk_data,
            )
        elif chunk_type == b"IDAT":
            compressed_parts.append(chunk_data)
        elif chunk_type == b"IEND":
            break
        offset = data_end + 4

    channels_by_color_type: dict[int, int] = {0: 1, 2: 3, 4: 2, 6: 4}
    if (
        width <= 0
        or height <= 0
        or bit_depth != 8
        or color_type not in channels_by_color_type
        or interlace != 0
        or not compressed_parts
    ):
        raise ValueError(
            "Unsupported screenshot PNG layout "
            f"(width={width}, height={height}, bit_depth={bit_depth}, "
            f"color_type={color_type}, interlace={interlace})"
        )

    channels: int = channels_by_color_type[color_type]
    stride: int = width * channels
    raw: bytes = zlib.decompress(b"".join(compressed_parts))
    expected_length: int = height * (stride + 1)
    if len(raw) != expected_length:
        raise ValueError(
            "Screenshot PNG scanline size mismatch "
            f"(expected={expected_length}, actual={len(raw)})"
        )

    previous: bytearray = bytearray(stride)
    visible_pixels: int = 0
    sampled_pixels: int = 0
    max_channel: int = 0
    sample_step: int = max(1, (width * height) // 100_000)
    raw_offset: int = 0
    pixel_index: int = 0
    for _row_index in range(height):
        filter_type: int = raw[raw_offset]
        raw_offset += 1
        filtered: bytes = raw[raw_offset : raw_offset + stride]
        raw_offset += stride
        reconstructed: bytearray = bytearray(stride)
        for index, value in enumerate(filtered):
            left: int = reconstructed[index - channels] if index >= channels else 0
            up: int = previous[index]
            upper_left: int = previous[index - channels] if index >= channels else 0
            if filter_type == 0:
                reconstructed[index] = value
            elif filter_type == 1:
                reconstructed[index] = (value + left) & 0xFF
            elif filter_type == 2:
                reconstructed[index] = (value + up) & 0xFF
            elif filter_type == 3:
                reconstructed[index] = (value + ((left + up) // 2)) & 0xFF
            elif filter_type == 4:
                reconstructed[index] = (
                    value + _paeth_predictor(left, up, upper_left)
                ) & 0xFF
            else:
                raise ValueError(f"Unsupported screenshot PNG filter {filter_type}")

        for column in range(width):
            if pixel_index % sample_step != 0:
                pixel_index += 1
                continue
            start: int = column * channels
            if color_type == 0:
                red = green = blue = reconstructed[start]
                alpha: int = 255
            elif color_type == 2:
                red, green, blue = reconstructed[start : start + 3]
                alpha = 255
            elif color_type == 4:
                red = green = blue = reconstructed[start]
                alpha = reconstructed[start + 1]
            else:
                red, green, blue, alpha = reconstructed[start : start + 4]
            brightest: int = max(red, green, blue)
            max_channel = max(max_channel, brightest)
            sampled_pixels += 1
            if alpha > 8 and brightest > 8:
                visible_pixels += 1
            pixel_index += 1
        previous = reconstructed

    visible_ratio: float = (
        float(visible_pixels) / float(sampled_pixels) if sampled_pixels else 0.0
    )
    return {
        "width": width,
        "height": height,
        "sampled_pixels": sampled_pixels,
        "visible_pixels": visible_pixels,
        "visible_ratio": visible_ratio,
        "max_channel": max_channel,
        "nonblank": max_channel >= 16 and visible_ratio >= 0.0005,
    }


async def _capture_visible_frame(
    session: ClientSession,
    session_id: str,
    source: str,
    max_resolution: int,
    wait_seconds: float,
    expected_width: int = 0,
    expected_height: int = 0,
) -> tuple[Any, bytes, dict[str, Any], int]:
    deadline: float = asyncio.get_running_loop().time() + max(wait_seconds, 0.5)
    last_metrics: dict[str, Any] = {}
    attempts: int = 0
    while asyncio.get_running_loop().time() < deadline:
        attempts += 1
        screenshot_result: Any = await _call(
            session,
            "editor_screenshot",
            {
                "source": source,
                "max_resolution": max_resolution,
                "include_image": True,
                "session_id": session_id,
            },
        )
        image_items: list[Any] = [
            item
            for item in screenshot_result.content
            if getattr(item, "type", None) == "image"
        ]
        if not image_items:
            raise RuntimeError(
                "editor_screenshot returned no image: "
                + " | ".join(_result_texts(screenshot_result))
            )
        image_bytes: bytes = base64.b64decode(image_items[0].data)
        last_metrics = _png_visual_metrics(image_bytes)
        dimensions_match: bool = (
            expected_width <= 0
            or expected_height <= 0
            or (
                int(last_metrics["width"]) == expected_width
                and int(last_metrics["height"]) == expected_height
            )
        )
        if bool(last_metrics["nonblank"]) and dimensions_match:
            return image_items[0], image_bytes, last_metrics, attempts
        await asyncio.sleep(0.5)
    raise TimeoutError(
        "Godot framebuffer remained blank or at the wrong dimensions after "
        f"{wait_seconds:.1f}s and {attempts} capture attempts: "
        f"{json.dumps(last_metrics)}"
    )


async def _capture(args: argparse.Namespace) -> dict[str, Any]:
    if args.run == "custom" and not args.scene:
        raise ValueError("--scene is required when --run custom is selected")
    has_width: bool = args.expected_width > 0
    has_height: bool = args.expected_height > 0
    if has_width != has_height:
        raise ValueError(
            "--expected-width and --expected-height must be provided together"
        )

    output_path: Path = Path(args.output).expanduser().resolve()
    async with streamablehttp_client(args.url) as (read_stream, write_stream, _):
        async with ClientSession(read_stream, write_stream) as session:
            await session.initialize()

            list_result: Any = await _call(session, "session_manage", {"op": "list"})
            list_payload: dict[str, Any] = _result_json(list_result)
            sessions: list[dict[str, Any]] = list_payload.get("sessions", [])
            selected: dict[str, Any] = _choose_session(
                sessions,
                args.project_path,
                args.session_hint,
            )
            session_id: str = str(selected["session_id"])
            await _call(session, "session_activate", {"session_id": session_id})

            initial_state: dict[str, Any] = _result_json(
                await _call(session, "editor_state", {"session_id": session_id})
            )
            game_active: bool = _game_is_active(initial_state)
            if args.run != "none" and game_active and args.force_relaunch:
                await _call(
                    session,
                    "project_manage",
                    {
                        "op": "stop",
                        "params": {},
                        "session_id": session_id,
                    },
                )
                await _wait_for_editor_ready(
                    session,
                    session_id,
                    args.wait_seconds,
                )
                game_active = False
            if args.run != "none" and not game_active:
                await _wait_for_editor_ready(
                    session,
                    session_id,
                    args.wait_seconds,
                )
                run_arguments: dict[str, Any] = {
                    "mode": args.run,
                    "autosave": False,
                    "session_id": session_id,
                }
                if args.run == "custom":
                    run_arguments["scene"] = args.scene
                await _call(session, "project_run", run_arguments)
                # A completed launch consumes the relaunch request. If a later
                # screenshot call fails, connection retries must not cycle the
                # task editor through another stop/start sequence.
                args.force_relaunch = False
            elif args.source == "game" and not game_active:
                raise RuntimeError(
                    "No live game is available. Pass --run main/current/custom, "
                    "or start the game through Godot MCP before capturing."
                )

            ready_state: dict[str, Any] = await _wait_for_capture(
                session,
                session_id,
                args.source,
                args.wait_seconds,
            )
            if args.settle_seconds > 0.0:
                await asyncio.sleep(args.settle_seconds)
            (
                image_item,
                image_bytes,
                visual_metrics,
                capture_attempts,
            ) = await _capture_visible_frame(
                session,
                session_id,
                args.source,
                args.max_resolution,
                args.visual_wait_seconds,
                args.expected_width,
                args.expected_height,
            )
            if has_width and (
                int(visual_metrics["width"]) != args.expected_width
                or int(visual_metrics["height"]) != args.expected_height
            ):
                raise RuntimeError(
                    "Godot framebuffer dimensions did not match the expected "
                    f"viewport {args.expected_width}x{args.expected_height}: "
                    f"{json.dumps(visual_metrics)}"
                )
            output_path.parent.mkdir(parents=True, exist_ok=True)
            output_path.write_bytes(image_bytes)
            return {
                "ok": True,
                "output": str(output_path),
                "bytes": len(image_bytes),
                "sha256": hashlib.sha256(image_bytes).hexdigest(),
                "mime_type": str(image_item.mimeType),
                "session_id": session_id,
                "project_path": str(selected.get("project_path", "")),
                "source": args.source,
                "settle_seconds": args.settle_seconds,
                "capture_attempts": capture_attempts,
                "visual_metrics": visual_metrics,
                "game_status": ready_state.get("game_status", {}),
            }


def _exception_messages(exc: BaseException) -> list[str]:
    nested: tuple[BaseException, ...] = getattr(exc, "exceptions", ())
    if nested:
        messages: list[str] = []
        for child in nested:
            messages.extend(_exception_messages(child))
        return messages
    message: str = str(exc).strip()
    return [f"{type(exc).__name__}: {message}" if message else type(exc).__name__]


def main() -> int:
    args: argparse.Namespace = _parse_args()
    attempts: int = max(1, args.connection_attempts)
    errors: list[str] = []
    for attempt in range(1, attempts + 1):
        try:
            result: dict[str, Any] = asyncio.run(_capture(args))
        except Exception as exc:
            errors.extend(
                f"attempt {attempt}: {message}" for message in _exception_messages(exc)
            )
            if attempt < attempts:
                time.sleep(0.5)
                continue
            print(
                json.dumps(
                    {"ok": False, "attempts": attempt, "errors": errors},
                    ensure_ascii=True,
                )
            )
            return 1
        print(json.dumps(result, ensure_ascii=True))
        return 0
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
