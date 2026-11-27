from datetime import datetime, timezone

import pytest

from app.core.throttle import FailureLimiter, TooManyAttempts
from app.services.link_codes import ALPHABET, CODE_RE, code_out, generate_code, normalize_code


def test_generated_codes_have_the_dashboards_format():
    for _ in range(500):
        code = generate_code()
        assert CODE_RE.fullmatch(code)
        assert set(code.replace("DMS-", "").replace("-", "")) <= set(ALPHABET)


def test_the_alphabet_has_no_lookalikes():
    assert len(ALPHABET) == 31
    assert not set("01ILO") & set(ALPHABET)


@pytest.mark.parametrize(
    "typed",
    ["DMS-2345-6789-AB", "dms-2345-6789-ab", "dms 2345 6789 ab", "DMS23456789AB", "  DMS-2345-6789-AB \n"],
)
def test_normalize_accepts_what_people_type(typed):
    assert normalize_code(typed) == "DMS-2345-6789-AB"


@pytest.mark.parametrize(
    "typed",
    ["", "DMS-2345-6789", "DMS-2345-6789-ABC", "XYZ-2345-6789-AB", "DMS-0345-6789-AB", "DMS-2345-6789-AI", "٢٣٤٥"],
)
def test_normalize_rejects_everything_else(typed):
    assert normalize_code(typed) is None


def test_code_out_skips_documents_that_are_not_codes():
    created = datetime(2026, 11, 27, tzinfo=timezone.utc)
    good = {"id": "DMS-2345-6789-AB", "createdAt": created, "status": "pending", "label": None}
    assert code_out(good).label == ""
    assert code_out({**good, "id": "junk"}) is None
    assert code_out({**good, "createdAt": None}) is None
    assert code_out({**good, "status": "weird"}) is None


def test_limiter_blocks_then_lets_go_after_the_window():
    now = [1000.0]
    limiter = FailureLimiter(max_failures=2, window_seconds=60, clock=lambda: now[0])
    limiter.record_failure("a")
    limiter.check("a")
    now[0] += 10
    limiter.record_failure("a")
    with pytest.raises(TooManyAttempts) as e:
        limiter.check("a")
    assert 49 <= e.value.retry_after <= 51
    limiter.check("b")  # other keys are not affected
    now[0] += 51  # the first failure leaves the window
    limiter.check("a")


def test_limiter_clear_forgets_failures():
    limiter = FailureLimiter(max_failures=1, window_seconds=60)
    limiter.record_failure("a")
    limiter.clear("a")
    limiter.check("a")
