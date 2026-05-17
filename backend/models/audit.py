from pydantic import BaseModel, Field, computed_field
from typing import Literal, Optional, List
from datetime import datetime

class CheckResult(BaseModel):
    # -- Frontend Fields --
    id: str = ""
    title: str = ""
    status: Literal["PASS", "FAIL", "NEEDS_REVIEW", "MANUAL", "ERROR"] = "ERROR"
    type: Literal["automated", "manual"] = "automated"
    section: str = ""
    evidence: str = ""
    remediable: bool = False
    
    # -- Old Backend/Bash Fields --
    check_id: str = ""
    severity: str = "MEDIUM"
    current_value: str = ""
    expected_value: str = ""
    remediation: str = ""
    node: str = ""

class AuditScore(BaseModel):
    total: int
    automated: int
    manual: int
    passed: int
    failed: int
    needs_review: int

    @computed_field
    @property
    def compliance_pct(self) -> float:
        scorable = self.total - self.manual
        if scorable <= 0:
            return 0.0
        return round(self.passed / scorable * 100, 1)

class AuditReport(BaseModel):
    node: str
    timestamp: str = ""
    score: AuditScore
    checks: List[CheckResult] = Field(default_factory=list)
    error: Optional[str] = None

    # -- Old Backend Fields --
    total_checks: int = 0
    passed: int = 0
    failed: int = 0
    manual: int = 0
    errors: int = 0
    
    @classmethod
    def from_checks(cls, node: str, checks: List[CheckResult]) -> "AuditReport":
        passed = sum(1 for c in checks if c.status == "PASS")
        failed = sum(1 for c in checks if c.status in ("FAIL", "ERROR"))
        manual = sum(1 for c in checks if c.status in ("MANUAL", "NEEDS_REVIEW"))
        total = len(checks)
        
        score_obj = AuditScore(
            total=total,
            automated=total - manual,
            manual=manual,
            passed=passed,
            failed=failed,
            needs_review=manual
        )
        
        return cls(
            node=node,
            timestamp=datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
            score=score_obj,
            checks=checks,
            total_checks=total,
            passed=passed,
            failed=failed,
            manual=manual,
            errors=sum(1 for c in checks if c.status == "ERROR")
        )

class ClusterAuditReport(BaseModel):
    timestamp: str
    nodes: List[AuditReport] = Field(default_factory=list)

    @computed_field
    @property
    def cluster_score(self) -> AuditScore:
        if not self.nodes:
            return AuditScore(total=0, automated=0, manual=0, passed=0, failed=0, needs_review=0)
        totals = {
            "total": sum(n.score.total for n in self.nodes),
            "automated": sum(n.score.automated for n in self.nodes),
            "manual": sum(n.score.manual for n in self.nodes),
            "passed": sum(n.score.passed for n in self.nodes),
            "failed": sum(n.score.failed for n in self.nodes),
            "needs_review": sum(n.score.needs_review for n in self.nodes),
        }
        return AuditScore(**totals)

class HardenRequest(BaseModel):
    section: str = "all"
    dry_run: bool = False

class HardenResult(BaseModel):
    node: str
    section: str
    exit_code: int
    stdout: str
    stderr: str
    success: bool
