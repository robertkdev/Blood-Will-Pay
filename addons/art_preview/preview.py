"""Agent interface for the native fullscreen ArtPreview scene (Python 3.11+).

No screenshot is accepted by appearance metrics. This validates provenance and
packages raw reference/runtime evidence; an image reviewer supplies the verdict.
"""
from __future__ import annotations

import argparse
import asyncio
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import uuid

PROJECT = Path(__file__).resolve().parents[2]
SESSION = PROJECT / ".godot/art_preview/session.json"
SCENE = "res://addons/art_preview/ArtPreview.tscn"


def read(path):
    # Godot's Windows file replacement can briefly deny readers while publishing
    # status. This is contention, not failed evidence; retry within a fixed bound.
    for attempt in range(50):
        try:
            return json.loads(Path(path).read_text(encoding="utf-8-sig"))
        except (PermissionError, FileNotFoundError, json.JSONDecodeError):
            if attempt == 49:
                raise
            time.sleep(.02)


def write(path, data):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_text(json.dumps(data, indent=2), encoding="utf-8")
    for attempt in range(50):
        try:
            temporary.replace(path)
            break
        except PermissionError:
            if attempt == 49:
                raise
            time.sleep(.02)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def source_files():
    # Include uncommitted source, since a Git revision alone misses live edits.
    return {str(p.relative_to(PROJECT)).replace("\\", "/"): sha(p)
            for base in ("scripts", "scenes", "assets", "data", "fonts", "addons/art_preview")
            for p in (PROJECT / base).rglob("*")
            if p.suffix.lower() in (".gd", ".tscn", ".tres", ".gdshader", ".gdshaderinc", ".py", ".json",
                                    ".png", ".jpg", ".jpeg", ".webp", ".svg", ".ttf", ".otf")}


def reference_info(path):
    path = Path(path).resolve(strict=True)
    from PIL import Image
    with Image.open(path) as image:
        image.verify()
    manifest = path.parent / "capture.json"
    if manifest.exists() and Path(read(manifest).get("actual", "__missing__")).resolve() == path:
        raise ValueError("A tool-produced actual capture cannot become its own art reference")
    return {"reference": str(path), "reference_sha256": sha(path)}


def session():
    if not SESSION.exists():
        raise ValueError("Run prepare first")
    return read(SESSION)


def release_dead_runtime(root):
    import psutil
    lock = Path(root) / "runtime.lock"
    if lock.exists():
        owner = int(read(lock)["pid"])
        if psutil.pid_exists(owner):
            raise ValueError(f"Preview runtime {owner} still owns this output directory")
        lock.unlink()


def archive_fixture_saves(data):
    # Preserve earlier test saves, but give every composition run a clean boot.
    # Only explicitly listed paths inside this task-created APPDATA are movable.
    root = Path(data["output_dir"]).resolve(strict=True)
    profile = read(PROJECT / "addons/art_preview/profile.json")
    private = (root / "art-preview-user-data/Godot/app_userdata" / profile["user_data_name"]).resolve()
    if not private.is_relative_to(root) or "art-preview-user-data" not in private.parts:
        raise ValueError("Fixture user-data path escaped the prepared output directory")
    for relative in profile["archive_before_run"]:
        source = (private / relative).resolve()
        if not source.is_relative_to(private) or source == private:
            raise ValueError("Fixture archive path escaped private user data")
        if source.exists():
            target = (root / "archived-fixtures" / data["session_id"] / relative).resolve()
            if not target.is_relative_to(root):
                raise ValueError("Fixture archive destination escaped output directory")
            target.parent.mkdir(parents=True, exist_ok=True)
            source.rename(target)


def prepare(args):
    reference = reference_info(args.reference)
    previous = read(SESSION) if SESSION.exists() else {}
    previous_dir = Path(previous.get("output_dir", "__missing__"))
    release_dead_runtime(previous_dir)
    run = Path(args.output).resolve()
    run.mkdir(parents=True, exist_ok=False)
    data = {"session_id": uuid.uuid4().hex, "output_dir": str(run), **reference,
            "source_files": source_files(), "settings": {}, "runtime_provenance": {
                "source_sha": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=PROJECT, text=True).strip(),
                "prepared_at_unix": time.time()}}
    if args.preset:
        data["settings"] = read(args.preset)["settings"]
    write(SESSION, data)
    write(run / "session.json", data)
    return {"session": str(SESSION), "output_dir": str(run), "scene": SCENE}


async def launch(args):
    """Private editor environment, without altering project.godot or user settings."""
    data = session()
    if data.get("editor_pid"):
        raise ValueError("This session already launched an editor; use run or prepare a new session")
    godot = Path(args.godot).resolve(strict=True)
    env = os.environ.copy()
    private = Path(data["output_dir"]) / "art-preview-user-data"
    env["APPDATA"] = str(private)
    private.mkdir(parents=True, exist_ok=True)
    editor_settings = private / "Godot/editor_settings-4.5.tres"
    editor_settings.parent.mkdir(parents=True, exist_ok=True)
    editor_settings.write_text('[gd_resource type="EditorSettings" format=3]\n\n[resource]\nrun/window_placement/game_embed_mode = -1\n', encoding="utf-8")
    # A project with the MCP-only launch contract uses the existing pinned,
    # restricted launcher over stdio, with the same private environment.
    if args.launcher:
        from mcp import ClientSession, StdioServerParameters
        from mcp.client.stdio import stdio_client
        parameters = StdioServerParameters(command=sys.executable, args=[
            str(Path(args.launcher).resolve(strict=True)), "--godot-executable", str(godot),
            "--godot-sha256", sha(godot), "--allowed-root", str(PROJECT.parent)], env=env)
        async with stdio_client(parameters) as (r, w):
            async with ClientSession(r, w) as client:
                await client.initialize()
                result = await client.call_tool("launch_editor", {"project_path": str(PROJECT)})
                payload = unpack(result)
                data["editor_pid"] = int(payload["pid"])
                data["runtime_provenance"]["editor_pid"] = data["editor_pid"]
                write(SESSION, data)
                write(Path(data["output_dir"]) / "session.json", data)
                print(json.dumps({"editor_pid": data["editor_pid"], "private_user_data": str(private),
                                  "next": "run --url <Godot-AI endpoint>",
                                  "launcher": "Keep this process open until the editor closes"}), flush=True)
                # The Windows MCP stdio transport kills its process tree when
                # closed. Keep the launcher's lifetime tied to its owned editor.
                import psutil
                while psutil.pid_exists(data["editor_pid"]):
                    await asyncio.sleep(2)
                return {"editor_closed": True}
    else:
        process = subprocess.Popen([str(godot), "--editor", "--path", str(PROJECT),
                                    "--log-file", str(Path(data["output_dir"]) / "editor.log")],
                                   env=env, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                                   stderr=subprocess.DEVNULL,
                                   creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        data["editor_pid"] = process.pid
    data["runtime_provenance"]["editor_pid"] = data["editor_pid"]
    write(SESSION, data)
    write(Path(data["output_dir"]) / "session.json", data)
    return {"editor_pid": data["editor_pid"], "private_user_data": str(private), "next": "run --url <Godot-AI endpoint>"}


def unpack(result):
    if result.isError:
        raise RuntimeError(str(result.content))
    structured = getattr(result, "structuredContent", None)
    if structured:
        return structured
    for item in result.content:
        if item.type == "text":
            return json.loads(item.text)
    raise ValueError("MCP result contains no JSON")


async def run(args):
    from mcp import ClientSession
    from mcp.client.streamable_http import streamablehttp_client
    data = session()
    failure = None
    launch_result = None
    # Keep validation outside the transport's cancellation scope. Some MCP SDK
    # versions suppress exceptions raised inside a closing HTTP context.
    async with streamablehttp_client(args.url) as (r, w, _):
        async with ClientSession(r, w) as client:
            try:
                await client.initialize()
                sessions = unpack(await client.call_tool("session_manage", {"op": "list"}))["sessions"]
                matching = [s for s in sessions if int(s.get("editor_pid", -1)) == int(data["editor_pid"])
                            and Path(s["project_path"]).resolve() == PROJECT]
                if len(matching) != 1:
                    raise ValueError("Private editor not ready on this endpoint; no other editor was touched")
                selected = matching[0]
                if args.action == "stop":
                    launch_result = unpack(await client.call_tool("project_manage", {"op": "stop", "params": {},
                                           "session_id": selected["session_id"]}))
                else:
                    if selected.get("play_state") not in ("stopped", None):
                        raise ValueError("The selected editor already has a running scene")
                    release_dead_runtime(data["output_dir"])
                    current_reference = reference_info(data["reference"])
                    if data.get("reference_sha256", current_reference["reference_sha256"]) != current_reference["reference_sha256"]:
                        raise ValueError("Prepared reference changed; prepare a new reference session")
                    data.update(current_reference)
                    data["runtime_provenance"]["mcp_session_id"] = selected["session_id"]
                    data["runtime_provenance"]["source_sha"] = subprocess.check_output(
                        ["git", "rev-parse", "HEAD"], cwd=PROJECT, text=True).strip()
                    data["session_id"] = uuid.uuid4().hex
                    archive_fixture_saves(data)
                    data["source_files"] = source_files()
                    write(SESSION, data)
                    write(Path(data["output_dir"]) / "session.json", data)
                    launch_result = unpack(await client.call_tool("project_run", {"mode": "custom", "scene": SCENE,
                                       "autosave": False, "session_id": selected["session_id"]}))
            except Exception as error:
                failure = error
    if failure is not None:
        raise failure
    if args.action == "stop":
        if launch_result is None:
            raise RuntimeError("MCP did not return a stop result")
        return launch_result
    deadline = time.monotonic() + 40
    status_path = Path(data["output_dir"]) / "status.json"
    while time.monotonic() < deadline:
        status = read(status_path) if status_path.exists() else {}
        if status.get("session_id") == data["session_id"]:
            if status.get("error"):
                raise ValueError(status["error"])
            if status.get("ready") and status.get("last_capture"):
                validate_capture(data, status, status["last_capture"])
                return {"ready": True, "editor_pid": data["editor_pid"], "game_pid": status["pid"],
                        "session_id": data["session_id"], **capture_result(status["last_capture"]),
                        "mcp_helper_ready": bool((launch_result or {}).get("helper_live", False))}
        await asyncio.sleep(.2)
    raise TimeoutError("MCP launched the scene but no valid preview capture became ready; inspect this editor's logs")


def command(args):
    data = session()
    root = Path(data["output_dir"])
    status = read(root / "status.json")
    if status.get("session_id") != data["session_id"] or not status.get("ready"):
        raise ValueError("This preview run is not ready; old status cannot authorize commands")
    expected = getattr(args, "expected_revision", None)
    if expected is not None and expected != status["revision"]:
        raise ValueError(f"Revision conflict: expected {expected}, current {status['revision']}")
    previous_id = status.get("last_capture", {}).get("id")
    payload = {"id": uuid.uuid4().hex, "session_id": data["session_id"],
               "expected_revision": status["revision"], "op": args.op}
    if args.settings:
        payload["settings"] = json.loads(args.settings)
        if not isinstance(payload["settings"], dict):
            raise ValueError("settings must be a JSON object")
    if args.path:
        payload["path"] = str(Path(args.path).resolve(strict=True))
    if args.op == "reference":
        selected_reference = reference_info(payload["path"])
        payload["reference_sha256"] = selected_reference["reference_sha256"]
    # Refuse concurrent writers rather than dropping one agent's command.
    lock = root / "command.lock"
    handle = lock.open("x")
    try:
        write(root / "command.json", payload)
        deadline = time.monotonic() + args.timeout
        while time.monotonic() < deadline:
            reply_path = root / "command-result.json"
            reply = read(reply_path) if reply_path.exists() else {}
            if reply.get("id") == payload["id"]:
                if not reply.get("ok"):
                    raise ValueError(reply["error"])
                if args.op == "reference":
                    data.update(selected_reference)
                    write(SESSION, data)
                    write(root / "session.json", data)
                if args.op in ("set", "capture", "reference"):
                    fresh = args.op != "set" or reply.get("changed", False)
                    capture = wait_capture(data, reply["revision"], deadline,
                                           previous_id if fresh else None)
                    reply.update(capture_result(capture))
                return reply
            time.sleep(0.1)
        raise TimeoutError("Preview did not acknowledge command; inspect its runtime before retrying")
    finally:
        handle.close()
        lock.unlink(missing_ok=True)


def wait_capture(data, revision, deadline, previous_id=None):
    """Return only the exact requested revision, never another writer's edit."""
    root = Path(data["output_dir"])
    while time.monotonic() < deadline:
        status = read(root / "status.json")
        if status.get("session_id") != data["session_id"]:
            raise ValueError("Preview session changed while waiting for capture")
        if status.get("error"):
            raise ValueError(status["error"])
        if status.get("revision", -1) > revision:
            raise ValueError(f"Requested revision {revision} was superseded by {status['revision']}")
        capture = status.get("last_capture", {})
        if (status.get("revision") == revision and capture.get("revision") == revision
                and capture.get("id") != previous_id):
            validate_capture(data, status, capture)
            return capture
        time.sleep(.1)
    raise TimeoutError(f"Revision {revision} did not produce a verified capture before the deadline")


def capture_result(capture):
    directory = Path(capture["actual"]).parent
    return {"capture_id": capture["id"], "revision": capture["revision"],
            "settings": capture["settings"], "actual": capture["actual"],
            "reference": capture["reference"], "comparison": capture["comparison"],
            "geometry": str(directory / "geometry.json"), "capture_manifest": str(directory / "capture.json"),
            "frames_drawn": capture["runtime_provenance"]["frames_drawn"], "visual_verdict": "unreviewed"}


def describe(args):
    data = session()
    status = read(Path(data["output_dir"]) / "status.json")
    if status.get("session_id") != data["session_id"] or not status.get("ready"):
        raise ValueError("Run the preview before discovering its live controls")
    return {"protocol_version": 1, "revision": status["revision"], "settings": status["settings"],
            "settings_schema": {"type": "object", "additionalProperties": False, "properties": {
                d["key"]: {"type": "number", "minimum": d["min"], "maximum": d["max"],
                           "default": d["value"], "suggested_step": d["step"]}
                for d in status["controls"]}},
            "operations": {"apply": "Batch JSON settings; waits for verified exact-revision reference/game pair",
                           "capture": "Force a new rendered frame and return its pair",
                           "geometry": "Filtered geometry and assets from the current verified capture",
                           "evidence": "Fresh required reference/actual manifest for visual-harness.yaml"},
            "concurrency": "Optional --expected-revision rejects outdated edits; concurrent writers are refused",
            "acceptance": "Capture validity is separate from art-direction acceptance"}


def geometry(args):
    data = session()
    status = read(Path(data["output_dir"]) / "status.json")
    if args.capture_id:
        root = Path(data["output_dir"]).resolve()
        directory = (root / args.capture_id).resolve(strict=True)
        if directory.parent != root:
            raise ValueError("capture-id must name a direct capture directory in this session")
        capture = read(directory / "capture.json")
    else:
        capture = wait_capture(data, status["revision"], time.monotonic() + args.timeout)
    records = read(Path(capture["actual"]).parent / "geometry.json")["controls"]
    filtered = [r for r in records if (args.include_offscreen or r.get("on_screen", True))
                and (not args.path_contains or args.path_contains.lower() in r["path"].lower())
                and (not args.node_type or r["type"] == args.node_type)]
    if args.fields:
        keys = {"path", "type", *args.fields.split(",")}
        filtered = [{k: v for k, v in r.items() if k in keys} for r in filtered]
    return {"capture_id": capture["id"], "revision": capture["revision"], "historical": bool(args.capture_id), "total": len(filtered),
            "offset": args.offset, "controls": filtered[args.offset:args.offset + args.limit]}


def validate_capture(data, status, capture):
    runtime = capture["runtime_provenance"]
    if Path(runtime["project_path"]).resolve() != PROJECT or runtime.get("game_pid") != status.get("pid"):
        raise ValueError("Capture belongs to a different project or runtime process")
    if runtime.get("source_sha") != data["runtime_provenance"]["source_sha"] or runtime.get("editor_pid") != data["editor_pid"]:
        raise ValueError("Capture source/editor identity differs from the prepared session")
    if runtime.get("session_id") != data["session_id"] or capture["revision"] != status["revision"]:
        raise ValueError("Capture is from a different session or an older settings revision")
    if runtime.get("stale_frame") is not False or runtime["frames_drawn"] <= runtime["frames_before"]:
        raise ValueError("Capture does not prove a fresh game frame")
    if runtime.get("viewport") != "1920x1080" or runtime.get("preview_scene") != SCENE:
        raise ValueError("Wrong viewport or runtime scene")
    if runtime.get("window_mode") not in (3, 4):
        raise ValueError("Capture was not made in a fullscreen window")
    if (Path(runtime.get("reference_source", "__missing__")).resolve() != Path(data["reference"]).resolve()
            or runtime.get("reference_source_sha256") != data["reference_sha256"]
            or sha(data["reference"]) != data["reference_sha256"]
            or capture["reference_sha256"] != data["reference_sha256"]):
        raise ValueError("Capture reference differs from the explicitly selected reference source")
    for key in ("actual", "reference"):
        if sha(capture[key]) != capture[key + "_sha256"]:
            raise ValueError(f"{key} image has changed since capture")
    if time.time() - capture["captured_at_unix"] > 3600:
        raise ValueError("Capture is more than one hour old; capture again")
    loaded = runtime.get("loaded_sources", list(data["source_files"]))
    required = set(loaded) | {p for p in data["source_files"] if p.startswith("addons/art_preview/")
                             and Path(p).suffix in (".gd", ".tscn", ".json")}
    for relative in required:
        if relative not in data["source_files"]:
            raise ValueError(f"Loaded resource was absent from the launch snapshot: {relative}")
        expected = data["source_files"][relative]
        if not (PROJECT / relative).exists() or sha(PROJECT / relative) != expected:
            raise ValueError(f"Source changed since this runtime started: {relative}. Relaunch the preview.")
    from PIL import Image
    with Image.open(capture["actual"]) as image:
        if image.size != (1920, 1080):
            raise ValueError("Actual capture is not native 1920x1080")


def evidence(args):
    data = session()
    root = Path(data["output_dir"])
    status = read(root / "status.json")
    if status.get("error"):
        raise ValueError(status["error"])
    capture = read(root / "latest.json")
    # A slider edit is deliberately debounced. Wait for its revision to render
    # instead of treating an in-flight capture as a permanently stale file.
    deadline = time.monotonic() + 20
    while capture.get("revision") != status.get("revision") or capture.get("runtime_provenance", {}).get("session_id") != data["session_id"]:
        if time.monotonic() >= deadline:
            raise TimeoutError("The latest settings revision did not produce a capture")
        time.sleep(.15)
        status = read(root / "status.json")
        if status.get("error"):
            raise ValueError(status["error"])
        capture = read(root / "latest.json")
    validate_capture(data, status, capture)
    result = command(argparse.Namespace(op="capture", settings=None, path=None, timeout=20))
    capture = read(result["capture_manifest"])
    validate_capture(data, read(root / "status.json"), capture)
    captures = [{"path": capture[role], "label": label, "group": "composition", "pair": "art_direction",
                 "role": role, "camera": "player", "layer": "final", "state": "art_preview",
                 "viewport": "fullscreen_1920x1080", "event": "reference_comparison",
                 "metadata": {"runtime_provenance": capture["runtime_provenance"]}}
                for role, label in (("reference", "Art reference"), ("actual", "Fresh production-component runtime"))]
    payload = {"captures": captures, "runtime_provenance": capture["runtime_provenance"]}
    destination = PROJECT / ".godot/art_preview/captures.json"
    write(destination, payload)
    return {"manifest": str(destination), "comparison": capture["comparison"], "revision": capture["revision"],
            "visual_verdict": "unreviewed", "actual": capture["actual"]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="action", required=True)
    p = sub.add_parser("prepare")
    p.add_argument("--reference", required=True)
    p.add_argument("--output", required=True)
    p.add_argument("--preset")
    p = sub.add_parser("launch")
    p.add_argument("--godot", required=True)
    p.add_argument("--launcher", help="Existing restricted MCP launcher; required by BWP")
    for action in ("run", "stop"):
        p = sub.add_parser(action)
        p.add_argument("--url", default="http://127.0.0.1:8000/mcp")
    p = sub.add_parser("command")
    p.add_argument("op", choices=["set", "capture", "reference", "quit"])
    p.add_argument("--settings")
    p.add_argument("--path")
    p.add_argument("--timeout", type=float, default=15)
    p.add_argument("--expected-revision", type=int)
    for action in ("apply", "capture"):
        p = sub.add_parser(action)
        p.set_defaults(op="set" if action == "apply" else "capture", settings=None, path=None)
        if action == "apply":
            p.add_argument("--settings", required=True)
        p.add_argument("--timeout", type=float, default=20)
        p.add_argument("--expected-revision", type=int)
    sub.add_parser("describe")
    p = sub.add_parser("geometry")
    p.add_argument("--path-contains", default="")
    p.add_argument("--node-type")
    p.add_argument("--include-offscreen", action="store_true")
    p.add_argument("--capture-id", help="Read immutable historical geometry without claiming current source validity")
    p.add_argument("--fields", help="Comma-separated fields; path and type are always returned")
    p.add_argument("--offset", type=int, default=0)
    p.add_argument("--limit", type=int, default=50)
    p.add_argument("--timeout", type=float, default=20)
    sub.add_parser("status")
    sub.add_parser("evidence")
    args = parser.parse_args()
    try:
        if args.action == "prepare":
            result = prepare(args)
        elif args.action in ("launch", "run", "stop"):
            result = asyncio.run(launch(args) if args.action == "launch" else run(args))
        elif args.action in ("command", "apply", "capture"):
            result = command(args)
        elif args.action == "describe":
            result = describe(args)
        elif args.action == "geometry":
            result = geometry(args)
        elif args.action == "status":
            result = read(Path(session()["output_dir"]) / "status.json")
        else:
            result = evidence(args)
        print(json.dumps(result, indent=2))
    except Exception as error:
        print(json.dumps({"ok": False, "error": str(error)}), file=sys.stderr)
        raise SystemExit(1)


if __name__ == "__main__":
    main()
