"""
WebSocket endpoint cho live audit streaming.
"""
import json
import logging
from fastapi import WebSocket, WebSocketDisconnect

from services.ssh import ssh_service
from services.parser import parse_single_check
from config import settings

logger = logging.getLogger(__name__)


async def audit_websocket_handler(websocket: WebSocket, node_ip: str):
    """
    WebSocket handler cho /ws/audit/{node_ip}.
    """
    await websocket.accept()

    if node_ip not in settings.node_ips:
        await websocket.send_json({"error": f"Node {node_ip} not found"})
        await websocket.close()
        return

    try:
        await websocket.send_json({
            "type": "start",
            "node": node_ip,
            "message": f"Starting audit on {node_ip}..."
        })

        checks = []
        check_count = 0

        async for line in ssh_service.stream_audit(node_ip):
            check = parse_single_check(line, node_ip)

            if check:
                check_count += 1
                checks.append(check)

                await websocket.send_json({
                    "type": "check",
                    "index": check_count,
                    "data": check.model_dump(mode="json"),
                })
            else:
                await websocket.send_json({
                    "type": "log",
                    "message": line,
                })

        from models.audit import AuditReport
        report = AuditReport.from_checks(node_ip, checks)

        await websocket.send_json({
            "type": "complete",
            "summary": {
                "total": report.total_checks,
                "passed": report.passed,
                "failed": report.failed,
                "manual": report.manual,
                "score": report.score,
            }
        })

        from routers.audit import _audit_cache
        _audit_cache[node_ip] = report

    except WebSocketDisconnect:
        logger.info(f"Client disconnected from audit WS for {node_ip}")
    except Exception as e:
        logger.error(f"WebSocket error for {node_ip}: {e}")
        try:
            await websocket.send_json({"type": "error", "message": str(e)})
        except Exception:
            pass
    finally:
        try:
            await websocket.close()
        except Exception:
            pass
