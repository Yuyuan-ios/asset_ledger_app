from __future__ import annotations

import threading
import time
from typing import Dict, List, Optional

from config import DEFAULT_RATE_LIMIT_MAX_REQUESTS, DEFAULT_RATE_LIMIT_WINDOW_SECONDS
from http_helpers import HttpError


class SlidingWindowRateLimiter:
    def __init__(
        self,
        max_requests: int = DEFAULT_RATE_LIMIT_MAX_REQUESTS,
        window_seconds: int = DEFAULT_RATE_LIMIT_WINDOW_SECONDS,
    ):
        self.max_requests = max_requests
        self.window_seconds = window_seconds
        self._lock = threading.Lock()
        self._requests: Dict[str, List[float]] = {}

    def check(self, account_id: Optional[str]) -> None:
        bucket = (
            account_id.strip()
            if isinstance(account_id, str) and account_id.strip()
            else "anonymous"
        )
        now = time.time()
        cutoff = now - self.window_seconds
        with self._lock:
            recent = [
                value
                for value in self._requests.get(bucket, [])
                if value >= cutoff
            ]
            if len(recent) >= self.max_requests:
                self._requests[bucket] = recent
                raise HttpError(429, "rate_limited", "too many sync requests")
            recent.append(now)
            self._requests[bucket] = recent
