from __future__ import annotations

import datetime as dt
import http.server
import json
import logging
import time
import uuid
from typing import Any, Dict, Mapping, Optional

from config import header_value


LOGGER = logging.getLogger("fleet_ledger.cloud_sync")


def configure_logging() -> None:
    logging.basicConfig(level=logging.INFO, format="%(message)s")


class HttpError(Exception):
    def __init__(self, status: int, code: str, message: str):
        super().__init__(message)
        self.status = status
        self.code = code
        self.message = message


def json_response(handler: http.server.BaseHTTPRequestHandler, status: int, body: Mapping[str, Any]) -> None:
    payload = json.dumps(body, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    handler.send_response(status)
    handler.send_header("content-type", "application/json; charset=utf-8")
    handler.send_header("content-length", str(len(payload)))
    handler.end_headers()
    handler.wfile.write(payload)


def error_response(handler: http.server.BaseHTTPRequestHandler, error: HttpError) -> None:
    json_response(
        handler,
        error.status,
        {"error": {"code": error.code, "message": error.message}},
    )


def read_json_body(handler: http.server.BaseHTTPRequestHandler, max_bytes: int) -> Dict[str, Any]:
    raw_length = handler.headers.get("content-length")
    if not raw_length:
        raise HttpError(411, "content_length_required", "Content-Length is required")
    try:
        length = int(raw_length)
    except ValueError as exc:
        raise HttpError(400, "invalid_content_length", "Content-Length is invalid") from exc
    if length < 0:
        raise HttpError(400, "invalid_content_length", "Content-Length is invalid")
    if length > max_bytes:
        raise HttpError(413, "request_too_large", "request body exceeds allowed size")
    body = handler.rfile.read(length)
    if len(body) > max_bytes:
        raise HttpError(413, "request_too_large", "request body exceeds allowed size")
    try:
        decoded = json.loads(body.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise HttpError(400, "invalid_json", "request body must be valid JSON") from exc
    if not isinstance(decoded, dict):
        raise HttpError(400, "invalid_json", "request body must be a JSON object")
    return decoded


def request_id_from_headers(headers: Mapping[str, Any]) -> str:
    return header_value(headers, "X-Request-Id") or str(uuid.uuid4())


def log_internal_error(request_id: str, method: str, path: Optional[str]) -> None:
    fields: Dict[str, Any] = {
        "event": "internal_error",
        "method": method,
        "request_id": request_id,
    }
    if path is not None:
        fields["path"] = path
    LOGGER.exception(
        "sync_request_error %s",
        json.dumps(fields, sort_keys=True, separators=(",", ":")),
    )


def duration_ms_since(started: float) -> int:
    return int((time.monotonic() - started) * 1000)


def log_sync_event(fields: Mapping[str, Any]) -> None:
    LOGGER.info("sync_event %s", json.dumps(fields, sort_keys=True, separators=(",", ":")))


def utc_now_iso() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")
