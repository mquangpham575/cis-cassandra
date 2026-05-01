"""
Pydantic models cho audit — phải thống nhất 100% với JSON output
của cis-tool.sh (Member 2).
"""
from pydantic import BaseModel, Field
from typing import Literal, Optional, List
from datetime import datetime


class CheckResult(BaseModel):
    """Kết quả 1 CIS check đơn lẻ."""
    check_id: str = Field(..., example="2.1")
    title: str = Field(..., example="Ensure authentication is enabled")
    status: Literal["PASS", "FAIL", "MANUAL", "ERROR"] = Field(
        ..., description="PASS=ok, FAIL=cần fix, MANUAL=cần kiểm tra tay, ERROR=script lỗi"
    )
    severity: Literal["CRITICAL", "HIGH", "MEDIUM", "LOW"] = Field(
        ..., description="Mức độ nghiêm trọng"
    )
    current_value: str = Field(
        "", description="Giá trị hiện tại trên server"
    )
    expected_value: str = Field(
        "", description="Giá trị mong đợi theo CIS"
    )
    remediation: str = Field(
        "", description="Hướng dẫn khắc phục"
    )
    section: str = Field(
        "", example="Authentication and Authorization"
    )
    node: str = Field(..., example="10.0.1.11")
    timestamp: datetime = Field(default_factory=datetime.utcnow)


class AuditReport(BaseModel):
    """Báo cáo tổng hợp audit cho 1 node."""
    node: str
    total_checks: int
    passed: int
    failed: int
    manual: int
    errors: int = 0
    score: float = Field(
        ...,
        description="passed / (total - manual) * 100"
    )
    checks: List[CheckResult]
    run_at: datetime = Field(default_factory=datetime.utcnow)

    @classmethod
    def from_checks(cls, node: str, checks: List[CheckResult]) -> "AuditReport":
        """Tính toán tự động từ danh sách checks."""
        passed = sum(1 for c in checks if c.status == "PASS")
        failed = sum(1 for c in checks if c.status == "FAIL")
        manual = sum(1 for c in checks if c.status == "MANUAL")
        errors = sum(1 for c in checks if c.status == "ERROR")
        total = len(checks)
        scorable = total - manual
        score = (passed / scorable * 100) if scorable > 0 else 0.0

        return cls(
            node=node,
            total_checks=total,
            passed=passed,
            failed=failed,
            manual=manual,
            errors=errors,
            score=round(score, 1),
            checks=checks,
        )
