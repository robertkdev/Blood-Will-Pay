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
from typing import Any

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
    parser.add_argument("--wait-seconds", type=float, default=20.0)
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


async def _capture(args: argparse.Namespace) -> dict[str, Any]:
    if args.run == "custom" and not args.scene:
        raise ValueError("--scene is required when --run custom is selected")

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
            game_active: bool = bool(
                initial_state.get("game_status", {}).get("active", False)
            )
            if args.run != "none" and not game_active:
                run_arguments: dict[str, Any] = {
                    "mode": args.run,
                    "autosave": False,
                    "session_id": session_id,
                }
                if args.run == "custom":
                    run_arguments["scene"] = args.scene
                await _call(session, "project_run", run_arguments)
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
            screenshot_result: Any = await _call(
                session,
                "editor_screenshot",
                {
                    "source": args.source,
                    "max_resolution": args.max_resolution,
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
            output_path.parent.mkdir(parents=True, exist_ok=True)
            output_path.write_bytes(image_bytes)
            metadata: dict[str, Any] = _result_json(screenshot_result)
            return {
                "ok": True,
                "output": str(output_path),
                "bytes": len(image_bytes),
                "sha256": hashlib.sha256(image_bytes).hexdigest(),
                "mime_type": str(image_items[0].mimeType),
                "session_id": session_id,
                "project_path": str(selected.get("project_path", "")),
                "source": args.source,
                "capture": metadata,
                "game_status": ready_state.get("game_status", {}),
            }


def main() -> int:
    args: argparse.Namespace = _parse_args()
    try:
        result: dict[str, Any] = asyncio.run(_capture(args))
    except Exception as exc:
        print(json.dumps({"ok": False, "error": str(exc)}, ensure_ascii=True))
        return 1
    print(json.dumps(result, ensure_ascii=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
