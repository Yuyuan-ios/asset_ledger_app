from __future__ import annotations

import threading
import time
from typing import Dict, List

from http_helpers import HttpError


class SlidingWindowRateLimiter:
    def __init__(self, max_requests: int = 120, window_seconds: int = 60):
        self.max_requests = max_requests
        self.window_seconds = window_seconds
        self._lock = threading.Lock()
        self._requests: Dict[str, List[float]] = {}

    def check(self, user_id: str) -> None:
        now = time.time()
        cutoff = now - self.window_seconds
        with self._lock:
            recent = [value for value in self._requests.get(user_id, []) if value >= cutoff]
            if len(recent) >= self.max_requests:
                self._requests[user_id] = recent
                raise HttpError(429, "rate_limited", "too many backup requests")
            recent.append(now)
            self._requests[user_id] = recent
