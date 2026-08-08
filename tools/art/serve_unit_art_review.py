#!/usr/bin/env python3
"""Serve the unit-art reviewer with one durable, atomic JSON state file."""

from __future__ import annotations

import argparse
import json
import os
from datetime import datetime, timezone
from http import HTTPStatus
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Lock
from typing import Any
from urllib.parse import urlsplit


STATE_SCHEMA_VERSION = 1
PROJECT_ID = "blood-will-pay"
MAX_REQUEST_BYTES = 1024 * 1024
STATE_API_PATHS = {
    "/api/unit-art-review-state",
    "/tools/art/unit-art-review/state",
}
REVIEW_PAGE_PATHS = {
    "/tools/art/unit-art-review",
    "/tools/art/unit-art-review/",
}
VALID_DECISIONS = {"like", "maybe", "cut"}


class StateFileError(Exception):
    def __init__(self, code: str, message: str, status: HTTPStatus) -> None:
        super().__init__(message)
        self.code = code
        self.status = status


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def _validate_string_map(
    value: Any,
    field: str,
    *,
    allowed_values: set[str] | None = None,
) -> dict[str, str]:
    if not isinstance(value, dict):
        raise StateFileError(
            "STATE_INVALID",
            f"{field} must be a JSON object.",
            HTTPStatus.UNPROCESSABLE_ENTITY,
        )
    validated: dict[str, str] = {}
    for key, item in value.items():
        if not isinstance(key, str) or not isinstance(item, str):
            raise StateFileError(
                "STATE_INVALID",
                f"{field} must contain only string keys and string values.",
                HTTPStatus.UNPROCESSABLE_ENTITY,
            )
        if allowed_values is not None and item not in allowed_values:
            raise StateFileError(
                "STATE_INVALID",
                f"{field}.{key} has unsupported value {item!r}.",
                HTTPStatus.UNPROCESSABLE_ENTITY,
            )
        validated[key] = item
    return validated


def normalize_state_document(value: Any) -> dict[str, Any]:
    """Validate known fields while preserving forward-compatible unknown data."""
    if not isinstance(value, dict):
        raise StateFileError(
            "STATE_INVALID",
            "Review state must be a JSON object.",
            HTTPStatus.UNPROCESSABLE_ENTITY,
        )

    document: dict[str, Any] = dict(value)
    schema_version = document.get("schema_version", STATE_SCHEMA_VERSION)
    if schema_version != STATE_SCHEMA_VERSION:
        raise StateFileError(
            "STATE_SCHEMA_UNSUPPORTED",
            f"Unsupported review-state schema_version {schema_version!r}.",
            HTTPStatus.UNPROCESSABLE_ENTITY,
        )

    project = document.get("project", PROJECT_ID)
    if project != PROJECT_ID:
        raise StateFileError(
            "STATE_PROJECT_MISMATCH",
            f"Review state belongs to {project!r}, not {PROJECT_ID!r}.",
            HTTPStatus.UNPROCESSABLE_ENTITY,
        )

    document["schema_version"] = STATE_SCHEMA_VERSION
    document["project"] = PROJECT_ID
    document["decisions"] = _validate_string_map(
        document.get("decisions", {}),
        "decisions",
        allowed_values=VALID_DECISIONS,
    )
    document["comments"] = _validate_string_map(document.get("comments", {}), "comments")
    document["defaults"] = _validate_string_map(document.get("defaults", {}), "defaults")

    pins = document.get("pins", [])
    if not isinstance(pins, list) or any(not isinstance(pin, str) for pin in pins):
        raise StateFileError(
            "STATE_INVALID",
            "pins must be an array of strings.",
            HTTPStatus.UNPROCESSABLE_ENTITY,
        )
    document["pins"] = list(dict.fromkeys(pins))

    for optional_object in ("ui", "selection", "migration"):
        optional_value = document.get(optional_object, {})
        if not isinstance(optional_value, dict):
            raise StateFileError(
                "STATE_INVALID",
                f"{optional_object} must be a JSON object.",
                HTTPStatus.UNPROCESSABLE_ENTITY,
            )
        document[optional_object] = dict(optional_value)

    revision = document.get("revision", 0)
    if not isinstance(revision, int) or isinstance(revision, bool) or revision < 0:
        raise StateFileError(
            "STATE_INVALID",
            "revision must be a non-negative integer.",
            HTTPStatus.UNPROCESSABLE_ENTITY,
        )
    document["revision"] = revision
    return document


class ReviewStateStore:
    def __init__(self, state_path: Path) -> None:
        self.state_path = state_path.resolve()
        self._lock = Lock()

    def load(self) -> dict[str, Any] | None:
        with self._lock:
            return self._load_unlocked()

    def _load_unlocked(self) -> dict[str, Any] | None:
        if not self.state_path.exists():
            return None
        try:
            if self.state_path.stat().st_size > MAX_REQUEST_BYTES:
                raise StateFileError(
                    "STATE_FILE_TOO_LARGE",
                    f"Review state exceeds {MAX_REQUEST_BYTES} bytes: {self.state_path}",
                    HTTPStatus.INTERNAL_SERVER_ERROR,
                )
            raw = self.state_path.read_text(encoding="utf-8")
            parsed = json.loads(raw)
            return normalize_state_document(parsed)
        except StateFileError as error:
            if error.status == HTTPStatus.UNPROCESSABLE_ENTITY:
                raise StateFileError(
                    error.code,
                    f"Durable review state is invalid and was left untouched: {error}",
                    HTTPStatus.INTERNAL_SERVER_ERROR,
                ) from error
            raise
        except (OSError, UnicodeError, json.JSONDecodeError) as error:
            raise StateFileError(
                "STATE_FILE_MALFORMED",
                f"Durable review state could not be read and was left untouched: {self.state_path}: {error}",
                HTTPStatus.INTERNAL_SERVER_ERROR,
            ) from error

    def save(self, value: Any, expected_revision: int | None) -> dict[str, Any]:
        incoming = normalize_state_document(value)
        with self._lock:
            current = self._load_unlocked()
            current_revision = current.get("revision", 0) if current is not None else None
            if current is None:
                if expected_revision not in (None, 0):
                    raise StateFileError(
                        "STATE_CONFLICT",
                        "Review state was created elsewhere; reload before saving.",
                        HTTPStatus.CONFLICT,
                    )
                next_revision = 1
                merged: dict[str, Any] = {}
            else:
                if expected_revision != current_revision:
                    raise StateFileError(
                        "STATE_CONFLICT",
                        f"Review state changed from revision {expected_revision!r} to {current_revision}; reload before saving.",
                        HTTPStatus.CONFLICT,
                    )
                next_revision = int(current_revision) + 1
                merged = dict(current)

            current_ui = merged.get("ui", {}) if isinstance(merged.get("ui", {}), dict) else {}
            current_selection = (
                merged.get("selection", {})
                if isinstance(merged.get("selection", {}), dict)
                else {}
            )
            current_migration = (
                merged.get("migration", {})
                if isinstance(merged.get("migration", {}), dict)
                else {}
            )
            merged.update(incoming)
            merged["ui"] = {**current_ui, **incoming.get("ui", {})}
            merged["selection"] = {**current_selection, **incoming.get("selection", {})}
            merged["migration"] = {**current_migration, **incoming.get("migration", {})}
            merged["schema_version"] = STATE_SCHEMA_VERSION
            merged["project"] = PROJECT_ID
            merged["revision"] = next_revision
            merged["updated_at"] = utc_now()
            validated = normalize_state_document(merged)
            self._atomic_write(validated)
            return validated

    def _atomic_write(self, document: dict[str, Any]) -> None:
        self.state_path.parent.mkdir(parents=True, exist_ok=True)
        temporary_path = self.state_path.with_name(f".{self.state_path.name}.{os.getpid()}.tmp")
        try:
            with temporary_path.open("w", encoding="utf-8", newline="\n") as handle:
                json.dump(document, handle, indent=2, ensure_ascii=False, sort_keys=True)
                handle.write("\n")
                handle.flush()
                os.fsync(handle.fileno())
            os.replace(temporary_path, self.state_path)
        except OSError as error:
            raise StateFileError(
                "STATE_WRITE_FAILED",
                f"Review state could not be written atomically: {self.state_path}: {error}",
                HTTPStatus.INTERNAL_SERVER_ERROR,
            ) from error
        finally:
            try:
                temporary_path.unlink(missing_ok=True)
            except OSError:
                pass


class UnitArtReviewRequestHandler(SimpleHTTPRequestHandler):
    server_version = "BloodWillPayUnitArtReview/1.0"

    @property
    def state_store(self) -> ReviewStateStore:
        return self.server.state_store  # type: ignore[attr-defined]

    def _path(self) -> str:
        return urlsplit(self.path).path

    def _send_json(self, status: HTTPStatus, payload: dict[str, Any]) -> None:
        body = (json.dumps(payload, ensure_ascii=False) + "\n").encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _send_state_error(self, error: StateFileError) -> None:
        self._send_json(
            error.status,
            {
                "ok": False,
                "error": {
                    "code": error.code,
                    "message": str(error),
                },
            },
        )

    def do_GET(self) -> None:  # noqa: N802 - stdlib handler contract
        request_path = self._path()
        if request_path in STATE_API_PATHS:
            try:
                document = self.state_store.load()
                if document is None:
                    self._send_json(
                        HTTPStatus.NOT_FOUND,
                        {
                            "ok": False,
                            "error": {
                                "code": "STATE_NOT_FOUND",
                                "message": "No durable unit-art review state exists yet.",
                            },
                        },
                    )
                    return
                self._send_json(HTTPStatus.OK, {"ok": True, "state": document})
            except StateFileError as error:
                self._send_state_error(error)
            return

        if request_path in REVIEW_PAGE_PATHS:
            query = urlsplit(self.path).query
            self.path = "/tools/art/unit-art-review.html" + (f"?{query}" if query else "")
        super().do_GET()

    def do_HEAD(self) -> None:  # noqa: N802 - stdlib handler contract
        request_path = self._path()
        if request_path in REVIEW_PAGE_PATHS:
            query = urlsplit(self.path).query
            self.path = "/tools/art/unit-art-review.html" + (f"?{query}" if query else "")
        super().do_HEAD()

    def do_POST(self) -> None:  # noqa: N802 - stdlib handler contract
        if self._path() not in STATE_API_PATHS:
            self._send_json(
                HTTPStatus.NOT_FOUND,
                {"ok": False, "error": {"code": "NOT_FOUND", "message": "Unknown API route."}},
            )
            return

        content_length_header = self.headers.get("Content-Length")
        try:
            content_length = int(content_length_header or "0")
        except ValueError:
            content_length = -1
        if content_length < 1 or content_length > MAX_REQUEST_BYTES:
            self._send_state_error(
                StateFileError(
                    "REQUEST_SIZE_INVALID",
                    f"JSON request body must be between 1 and {MAX_REQUEST_BYTES} bytes.",
                    HTTPStatus.REQUEST_ENTITY_TOO_LARGE,
                )
            )
            return

        try:
            raw = self.rfile.read(content_length)
            payload = json.loads(raw.decode("utf-8"))
            if not isinstance(payload, dict):
                raise StateFileError(
                    "REQUEST_INVALID",
                    "Request body must be a JSON object.",
                    HTTPStatus.BAD_REQUEST,
                )

            if "state" in payload:
                state_value = payload.get("state")
                expected_revision = payload.get("expected_revision")
            else:
                state_value = payload
                expected_revision = payload.get("revision")

            if expected_revision is not None and (
                not isinstance(expected_revision, int)
                or isinstance(expected_revision, bool)
                or expected_revision < 0
            ):
                raise StateFileError(
                    "REQUEST_INVALID",
                    "expected_revision must be null or a non-negative integer.",
                    HTTPStatus.BAD_REQUEST,
                )

            saved = self.state_store.save(state_value, expected_revision)
            self._send_json(HTTPStatus.OK, {"ok": True, "state": saved})
        except StateFileError as error:
            self._send_state_error(error)
        except (UnicodeError, json.JSONDecodeError) as error:
            self._send_state_error(
                StateFileError(
                    "REQUEST_MALFORMED_JSON",
                    f"Request body is not valid UTF-8 JSON: {error}",
                    HTTPStatus.BAD_REQUEST,
                )
            )


class UnitArtReviewServer(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(
        self,
        server_address: tuple[str, int],
        root: Path,
        state_path: Path,
    ) -> None:
        self.state_store = ReviewStateStore(state_path)

        def handler(*args: Any, **kwargs: Any) -> UnitArtReviewRequestHandler:
            return UnitArtReviewRequestHandler(*args, directory=str(root), **kwargs)

        super().__init__(server_address, handler)


def create_server(host: str, port: int, root: Path, state_path: Path) -> UnitArtReviewServer:
    return UnitArtReviewServer((host, port), root.resolve(), state_path.resolve())


def parse_args() -> argparse.Namespace:
    project_root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(
        description="Serve Blood Will Pay's unit-art reviewer with durable file-backed state.",
    )
    parser.add_argument("--bind", default="127.0.0.1", help="Interface to bind (default: 127.0.0.1).")
    parser.add_argument("--port", type=int, default=8769, help="Port to bind (default: 8769).")
    parser.add_argument(
        "--root",
        type=Path,
        default=project_root,
        help="Project root containing tools/art/unit-art-review.html.",
    )
    parser.add_argument(
        "--state-file",
        type=Path,
        default=None,
        help="Durable JSON file (default: <root>/tools/art/unit-art-review-state.json).",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    root = args.root.resolve()
    state_path = (
        args.state_file.resolve()
        if args.state_file is not None
        else root / "tools" / "art" / "unit-art-review-state.json"
    )
    server = create_server(args.bind, args.port, root, state_path)
    print(f"Unit art reviewer: http://{args.bind}:{server.server_port}/tools/art/unit-art-review")
    print(f"Durable review state: {state_path}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
