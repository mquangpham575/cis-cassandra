"""
Endpoints thực hiện hardening (remediation) và verify.
"""
from typing import Optional
from fastapi import APIRouter, HTTPException, Depends, Query

from models.audit import AuditReport
from services.ssh import ssh_service
from services.parser import parse_audit_output
from config import settings
from routers._auth import verify_token

router = APIRouter(tags=["Remediation"])


@router.post("/remediate/{node_ip}", response_model=AuditReport)
async def run_remediate(
    node_ip: str,
    section: Optional[str] = Query(None, description="Chỉ harden section cụ thể"),
    _=Depends(verify_token),
):
    """
    Chạy cis-tool.sh --harden trên node.
    Tự động fix các CIS checks đang FAIL.
    """
    if node_ip not in settings.node_ips:
        raise HTTPException(status_code=404, detail=f"Node {node_ip} not found")

    try:
        raw_json = await ssh_service.run_harden(node_ip, section=section)
        report = parse_audit_output(raw_json, node_ip)
        return report

    except ConnectionError:
        raise HTTPException(status_code=503, detail=f"Cannot SSH to {node_ip}")
    except TimeoutError:
        raise HTTPException(status_code=504, detail=f"Harden timed out on {node_ip}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/verify/{node_ip}", response_model=AuditReport)
async def run_verify(
    node_ip: str,
    _=Depends(verify_token),
):
    """
    Chạy cis-tool.sh --verify trên node.
    Kiểm tra lại sau khi đã harden.
    So sánh kết quả trước/sau để xác nhận fix thành công.
    """
    if node_ip not in settings.node_ips:
        raise HTTPException(status_code=404, detail=f"Node {node_ip} not found")

    try:
        raw_json = await ssh_service.run_verify(node_ip)
        report = parse_audit_output(raw_json, node_ip)
        return report

    except ConnectionError:
        raise HTTPException(status_code=503, detail=f"Cannot SSH to {node_ip}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
