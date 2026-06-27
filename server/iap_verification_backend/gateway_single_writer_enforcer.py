from __future__ import annotations

from typing import Any


GATEWAY_WRITER_SOURCE = "subscription_gateway.py"


class SingleWriterEnforcer:
    """Ensures entitlement mutations originate from the unified gateway."""

    @staticmethod
    def assert_writer(context: Any) -> None:
        source = str(getattr(context, "source", "")).strip()
        if source != GATEWAY_WRITER_SOURCE:
            raise RuntimeError("RBL VIOLATION: non-gateway write attempt")
