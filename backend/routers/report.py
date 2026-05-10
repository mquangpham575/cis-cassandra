"""
Endpoint tổng hợp compliance report cho toàn bộ cluster.
"""
from fastapi import APIRouter

from models.audit import AuditReport
from models.node import ComplianceReport
from services.ssh import ssh_service
from services.parser import parse_audit_output
from config import settings

router = APIRouter(tags=["Report"])


@router.get("/report", response_model=ComplianceReport)
async def get_compliance_report():
    """
    Tổng hợp kết quả audit từ tất cả nodes.
    Tính overall compliance score.
    """
    from routers.audit import _audit_cache

    reports: list[AuditReport] = []
    nodes_up = 0

    for ip in settings.node_ips:
        if ip in _audit_cache:
            reports.append(_audit_cache[ip])
            nodes_up += 1
        else:
            try:
                raw = await ssh_service.run_audit(ip)
                report = parse_audit_output(raw, ip)
                _audit_cache[ip] = report
                reports.append(report)
                nodes_up += 1
            except Exception:
                reports.append(AuditReport(
                    node=ip,
                    total_checks=0, passed=0, failed=0,
                    manual=0, errors=1, score=0.0,
                    checks=[],
                ))

    scored_reports = [r for r in reports if r.total_checks > 0]
    overall_score = (
        sum(r.score for r in scored_reports) / len(scored_reports)
        if scored_reports else 0.0
    )

    return ComplianceReport(
        total_nodes=len(settings.node_ips),
        nodes_up=nodes_up,
        nodes_down=len(settings.node_ips) - nodes_up,
        overall_score=round(overall_score, 1),
        reports=[r.model_dump() for r in reports],
    )
