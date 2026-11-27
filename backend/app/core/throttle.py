"""Stops one account from guessing link codes.

Counts failed attempts per key (the patient's uid) in memory: after
``max_failures`` failures inside ``window_seconds`` the key is refused until
the oldest failure leaves the window. State is per server process, so it
resets on restart and is not shared between several processes; a hosted
deployment should also limit requests per IP address in front of the app.
"""

import threading
import time
from collections import defaultdict, deque


class TooManyAttempts(Exception):
    def __init__(self, retry_after: int) -> None:
        super().__init__("too many failed attempts")
        self.retry_after = retry_after


class FailureLimiter:
    def __init__(self, max_failures: int, window_seconds: int, clock=time.monotonic) -> None:
        self._max = max_failures
        self._window = window_seconds
        self._clock = clock
        self._failures: dict[str, deque[float]] = defaultdict(deque)
        self._lock = threading.Lock()

    def _prune(self, key: str, now: float) -> deque[float]:
        times = self._failures[key]
        while times and now - times[0] >= self._window:
            times.popleft()
        if not times:
            self._failures.pop(key, None)
        return times

    def check(self, key: str) -> None:
        """Raises TooManyAttempts when the key has used up its failures."""
        with self._lock:
            now = self._clock()
            times = self._prune(key, now)
            if len(times) >= self._max:
                raise TooManyAttempts(int(self._window - (now - times[0])) + 1)

    def record_failure(self, key: str) -> None:
        with self._lock:
            self._failures[key].append(self._clock())

    def clear(self, key: str) -> None:
        with self._lock:
            self._failures.pop(key, None)

    def clear_all(self) -> None:
        with self._lock:
            self._failures.clear()


# One failed code per patient account every few minutes is plenty for a typo.
redeem_limiter = FailureLimiter(max_failures=5, window_seconds=15 * 60)
