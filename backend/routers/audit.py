import asyncio
from typing import Optional, List
from datetime import datetime
from fastapi import APIRouter, HTTPException, Depends, Query
from fastapi.responses import FileResponse
import tempfile
import json
import importlib.util
import os
import time

from models.audit import AuditReport, ClusterAuditReport
from services.ssh import ssh_service
from services.parser import parse_audit_output
from config import settings
from routers._auth import verify_token

router = APIRouter(prefix="/api/audit", tags=["Audit"])

# In-memory cache cho kết quả audit gần nhất
_audit_cache: dict[str, AuditReport] = {}


@router.get("/cluster", response_model=ClusterAuditReport)
async def get_cluster_audit(
    section: str = Query("all", description="Filter section"),
):
    """
    Chạy audit trên toàn cụm song song và trả về báo cáo tổng hợp.
    """
    tasks = [
        ssh_service.run_audit(ip, section=section)
        for ip in settings.node_ips
    ]

    results = await asyncio.gather(*tasks, return_exceptions=True)
    reports = []

    for ip, result in zip(settings.node_ips, results):
        if isinstance(result, Exception):
            reports.append(AuditReport.from_checks(ip, []))
        else:
            report = parse_audit_output(result, ip)
            _audit_cache[ip] = report
            reports.append(report)

    return ClusterAuditReport(
        timestamp=datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
        nodes=reports
    )


@router.get("/node/{node_ip}", response_model=AuditReport)
async def get_node_audit(
    node_ip: str,
    section: Optional[str] = Query(None, description="Filter theo section"),
):
    """
    Chạy audit trên một node cụ thể và trả về kết quả.
    """
    if node_ip not in settings.node_ips:
        raise HTTPException(status_code=404, detail=f"Node {node_ip} not found")

    try:
        raw_json = await ssh_service.run_audit(node_ip, section=section)
        report = parse_audit_output(raw_json, node_ip)
        _audit_cache[node_ip] = report
        return report
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/all", response_model=list[AuditReport])
async def run_audit_all(_=Depends(verify_token)):
    """
    Chạy audit trên TẤT CẢ nodes song song (POST có auth).
    """
    tasks = [
        ssh_service.run_audit(ip)
        for ip in settings.node_ips
    ]

    results = await asyncio.gather(*tasks, return_exceptions=True)
    reports = []

    for ip, result in zip(settings.node_ips, results):
        if isinstance(result, Exception):
            reports.append(AuditReport.from_checks(ip, []))
        else:
            report = parse_audit_output(result, ip)
            _audit_cache[ip] = report
            reports.append(report)

    return reports


@router.post("/{node_ip}", response_model=AuditReport)
async def run_audit(
    node_ip: str,
    section: Optional[str] = Query(None, description="Filter theo section, vd: 'encryption'"),
    _=Depends(verify_token),
):
    """
    Chạy CIS audit trên 1 node (POST có auth).
    """
    if node_ip not in settings.node_ips:
        raise HTTPException(status_code=404, detail=f"Node {node_ip} not found")

    try:
        raw_json = await ssh_service.run_audit(node_ip, section=section)
        report = parse_audit_output(raw_json, node_ip)
        _audit_cache[node_ip] = report
        return report

    except ConnectionError:
        raise HTTPException(status_code=503, detail=f"Cannot SSH to {node_ip}")
    except TimeoutError:
        raise HTTPException(status_code=504, detail=f"Audit timed out on {node_ip}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/{node_ip}/latest", response_model=Optional[AuditReport])
async def get_latest_audit(node_ip: str):
    """
    Trả về kết quả audit gần nhất (từ cache).
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


@router.get("/{node_ip}/export")
async def export_latest_audit(node_ip: str):
    """
    Export the latest cached audit for `node_ip` to an Excel file using scripts/export_excel.py
    Returns the generated .xlsx as a file response.
    """
    if node_ip not in settings.node_ips:
        raise HTTPException(status_code=404, detail=f"Node {node_ip} not found")

    report = _audit_cache.get(node_ip)
    if not report:
        raise HTTPException(status_code=404, detail=f"No cached audit for {node_ip}")

    # Build lines compatible with scripts/export_excel.py expectations
    entries = []
    for check in report.checks:
        entries.append({
            "node": report.node,
            "check_id": getattr(check, 'check_id', ''),
            "title": getattr(check, 'title', ''),
            "status": getattr(check, 'status', ''),
            "severity": getattr(check, 'severity', ''),
            "current_value": getattr(check, 'current_value', '') or "",
            "expected_value": getattr(check, 'expected_value', '') or "",
            "remediation": getattr(check, 'remediation', '') or "",
        })

    # Temp files
    ts = int(time.time())
    tmp_dir = tempfile.gettempdir()
    json_path = os.path.join(tmp_dir, f"audit_export_{node_ip.replace('.', '_')}_{ts}.json")
    xlsx_path = os.path.join(tmp_dir, f"audit_export_{node_ip.replace('.', '_')}_{ts}.xlsx")

    # Write newline-delimited JSON as expected by export_excel
    with open(json_path, 'w', encoding='utf-8') as jf:
        for obj in entries:
            jf.write(json.dumps(obj, ensure_ascii=False) + "\n")

    # Dynamically load scripts/export_excel.py and call export_to_excel
    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
    # repo_root currently points to backend/.. -> project root
    script_path = os.path.abspath(os.path.join(repo_root, '..', 'scripts', 'export_excel.py'))
    if not os.path.exists(script_path):
        # try alternative relative path
        script_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', 'scripts', 'export_excel.py'))

    if not os.path.exists(script_path):
        raise HTTPException(status_code=500, detail=f"export_excel.py not found at {script_path}")

    spec = importlib.util.spec_from_file_location("export_excel", script_path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)

    try:
        mod.export_to_excel(json_path, xlsx_path)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Export failed: {e}")

    if not os.path.exists(xlsx_path):
        raise HTTPException(status_code=500, detail="Export did not produce an xlsx file")

    return FileResponse(xlsx_path, media_type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', filename=os.path.basename(xlsx_path))
