"""Test parser service."""
from services.parser import parse_audit_output, parse_single_check

def test_parse_audit_output(sample_audit_json):
    report = parse_audit_output(sample_audit_json, "10.0.1.11")

    assert report.node == "10.0.1.11"
    assert report.total_checks == 3
    assert report.passed == 1
    assert report.failed == 1
    assert report.manual == 1
    # score = 1 / (3-1) * 100 = 50%
    assert report.score == 50.0

def test_parse_invalid_json():
    report = parse_audit_output("not json", "10.0.1.11")
    assert report.total_checks == 0
    assert report.errors == 1

def test_parse_single_check():
    line = '{"check_id":"2.1","title":"Auth","status":"PASS","severity":"CRITICAL"}'
    check = parse_single_check(line, "10.0.1.11")

    assert check is not None
    assert check.check_id == "2.1"
    assert check.status == "PASS"

def test_parse_single_check_invalid():
    check = parse_single_check("not json", "10.0.1.11")
    assert check is None
