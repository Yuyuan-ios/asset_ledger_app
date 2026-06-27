from __future__ import annotations

import builtins
import contextlib
import contextvars
import inspect
import os
import threading
from typing import Any, Iterator


STORAGE_MODULE_NAME = "storage"
STORAGE_GATEWAY_FILE = "subscription_storage_gateway.py"
IMPORT_FIREWALL_ERROR = "RBL PHYSICAL ENFORCEMENT: forbidden storage import"

_STORAGE_IMPORT_ALLOWED: contextvars.ContextVar[bool] = contextvars.ContextVar(
    "fleet_ledger_storage_import_allowed",
    default=False,
)
_INSTALL_LOCK = threading.Lock()
_ORIGINAL_IMPORT = builtins.__import__
_INSTALLED = False


def install_import_firewall() -> None:
    global _INSTALLED
    with _INSTALL_LOCK:
        if _INSTALLED:
            return
        builtins.__import__ = _guarded_import
        _INSTALLED = True


@contextlib.contextmanager
def allow_storage_import() -> Iterator[None]:
    token = _STORAGE_IMPORT_ALLOWED.set(True)
    try:
        yield
    finally:
        _STORAGE_IMPORT_ALLOWED.reset(token)


def assert_storage_import_allowed() -> None:
    if _STORAGE_IMPORT_ALLOWED.get():
        return
    if _caller_file_is_storage_gateway():
        return
    raise RuntimeError(IMPORT_FIREWALL_ERROR)


def _guarded_import(
    name: str,
    globals: dict[str, Any] | None = None,
    locals: dict[str, Any] | None = None,
    fromlist: tuple[str, ...] = (),
    level: int = 0,
) -> Any:
    if _targets_storage_module(name, level) and not _storage_import_is_allowed(globals):
        raise RuntimeError(IMPORT_FIREWALL_ERROR)
    return _ORIGINAL_IMPORT(name, globals, locals, fromlist, level)


def _targets_storage_module(name: str, level: int) -> bool:
    if level != 0:
        return False
    root_name = name.split(".", 1)[0]
    return root_name == STORAGE_MODULE_NAME


def _storage_import_is_allowed(globals: dict[str, Any] | None) -> bool:
    if _STORAGE_IMPORT_ALLOWED.get():
        return True
    if globals is not None:
        file_name = globals.get("__file__")
        if isinstance(file_name, str) and os.path.basename(file_name) == STORAGE_GATEWAY_FILE:
            return True
    return _caller_file_is_storage_gateway()


def _caller_file_is_storage_gateway() -> bool:
    for frame_info in inspect.stack()[2:]:
        file_name = os.path.basename(frame_info.filename)
        if file_name == STORAGE_GATEWAY_FILE:
            return True
        if file_name not in {"import_firewall.py", "<frozen importlib._bootstrap>"}:
            return False
    return False
