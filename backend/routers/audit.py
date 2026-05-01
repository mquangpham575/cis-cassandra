"""
Endpoints chạy CIS audit trên nodes.
POST endpoints cần Bearer token (bảo vệ action nguy hiểm).
"""
import asyncio
from typing import Optional
from fastapi import APIRouter, HTTPException, Depends, Query

from models.audit import AuditReport
from services.ssh import ssh_service
from services.parser import parse_audit_output
from config import settings
from routers._auth import verify_token

router = APIRouter(prefix="/audit", tags=["Audit"])

# In-memory cache cho kết quả audit gần nhất
_audit_cache: dict[str, AuditReport] = {}


@router.post("/{node_ip}", response_model=AuditReport)
async def run_audit(
    node_ip: str,
    section: Optional[str] = Query(None, description="Filter theo section, vd: 'encryption'"),
    _=Depends(verify_token),
):
    """
    Chạy CIS audit trên 1 node.
    Gọi cis-tool.sh --audit qua SSH, parse JSON, trả về AuditReport.
    """
    if node_ip not in settings.node_ips:
        raise HTTPException(status_code=404, detail=f"Node {node_ip} not found")

    try:
        raw_json = await ssh_service.run_audit(node_ip, section=section)
        report = parse_audit_output(raw_json, node_ip)

        # Lưu cache
        _audit_cache[node_ip] = report

        return report

    except ConnectionError:
        raise HTTPException(status_code=503, detail=f"Cannot SSH to {node_ip}")
    except TimeoutError:
        raise HTTPException(status_code=504, detail=f"Audit timed out on {node_ip}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/all", response_model=list[AuditReport])
async def run_audit_all(_=Depends(verify_token)):
    """
    Chạy audit trên TẤT CẢ nodes song song.
    """
    tasks = [
        ssh_service.run_audit(ip)
        for ip in settings.node_ips
    ]

    results = await asyncio.gather(*tasks, return_exceptions=True)
    reports = []

    for ip, result in zip(settings.node_ips, results):
        if isinstance(result, Exception):
            # Node lỗi → tạo report rỗng
            reports.append(AuditReport(
                node=ip,
                total_checks=0, passed=0, failed=0,
                manual=0, errors=1, score=0.0,
                checks=[],
            ))
        else:
            report = parse_audit_output(result, ip)
            _audit_cache[ip] = report
            reports.append(report)

    return reports


@router.get("/{node_ip}/latest", response_model=Optional[AuditReport])
async def get_latest_audit(node_ip: str):
    """
    Trả về kết quả audit gần nhất (từ cache).
    Không chạy lại audit, chỉ lấy data đã có.
    """
    if node_ip not in settings.node_ips:
        raise HTTPException(status_code=404, detail=f"Node {node_ip} not found")

    report = _audit_cache.get(node_ip)
    if not report:
        raise HTTPException(
            status_code=404,
            detail=f"No audit results for {node_ip}. Run POST /audit/{node_ip} first."
        )

    return report
