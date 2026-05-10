"""Test Pydantic models."""
from models.audit import CheckResult, AuditReport

def test_check_result_creation():
    check = CheckResult(
        check_id="2.1",
        title="Test check",
        status="PASS",
        severity="CRITICAL",
        node="10.0.1.11",
    )
    assert check.status == "PASS"
    assert check.check_id == "2.1"

def test_audit_report_from_checks():
    checks = [
        CheckResult(check_id="1", title="A", status="PASS", severity="HIGH", node="10.0.1.11"),
        CheckResult(check_id="2", title="B", status="FAIL", severity="HIGH", node="10.0.1.11"),
        CheckResult(check_id="3", title="C", status="MANUAL", severity="LOW", node="10.0.1.11"),
    ]
    report = AuditReport.from_checks("10.0.1.11", checks)

    assert report.total_checks == 3
    assert report.passed == 1
    assert report.failed == 1
    assert report.manual == 1
    # score = 1 / (3-1) * 100 = 50%
    assert report.score == 50.0
