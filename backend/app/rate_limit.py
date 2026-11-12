from __future__ import annotations

import threading
import time
from collections import deque
from typing import Callable


class SlidingWindowRateLimiter:
    """Limitador em memória; cada processo mantém a própria contagem."""

    MAX_TRACKED_KEYS = 50_000

    def __init__(self, clock: Callable[[], float] = time.monotonic) -> None:
        self._clock = clock
        self._hits: dict[str, deque[float]] = {}
        self._lock = threading.Lock()

    def allow(self, key: str, limit: int, window_seconds: float) -> bool:
        now = self._clock()
        cutoff = now - window_seconds
        with self._lock:
            hits = self._hits.get(key)
            if hits is None:
                if len(self._hits) >= self.MAX_TRACKED_KEYS:
                    self._discard_expired(cutoff)
                hits = deque()
                self._hits[key] = hits
            while hits and hits[0] <= cutoff:
                hits.popleft()
            if len(hits) >= limit:
                return False
            hits.append(now)
            return True

    def _discard_expired(self, cutoff: float) -> None:
        expired = [key for key, hits in self._hits.items() if not hits or hits[-1] <= cutoff]
        for key in expired:
            del self._hits[key]
        if len(self._hits) >= self.MAX_TRACKED_KEYS:
            # Janelas diferentes convivem no mapa; sob ataque, recomeça a contagem.
            self._hits.clear()
