"""
Parse JSON output từ cis-tool.sh (Member 2) thành Pydantic models.
Đây là nơi chuyển đổi dữ liệu thô → structured data.
"""
import json
import re
import logging
from typing import List, Optional
from datetime import datetime

from models.audit import CheckResult, AuditReport
from models.node import NodeInfo

logger = logging.getLogger(__name__)


def parse_audit_output(raw_json: str, node_ip: str) -> AuditReport:
    """
    Parse toàn bộ JSON output từ cis-tool.sh --audit.
    """
    try:
        data = json.loads(raw_json)
    except json.JSONDecodeError as e:
        logger.error(f"Invalid JSON from {node_ip}: {e}")
        return AuditReport(
            node=node_ip,
            total_checks=0,
            passed=0,
            failed=0,
            manual=0,
            errors=1,
            score=0.0,
            checks=[],
        )

    checks: List[CheckResult] = []
    raw_checks = data.get("checks", [])

    for item in raw_checks:
        try:
            check = CheckResult(
                check_id=item.get("check_id", "unknown"),
                title=item.get("title", "Unknown check"),
                status=item.get("status", "ERROR"),
                severity=item.get("severity", "MEDIUM"),
                current_value=item.get("current_value", ""),
                expected_value=item.get("expected_value", ""),
                remediation=item.get("remediation", ""),
                section=item.get("section", ""),
                node=node_ip,
                timestamp=datetime.utcnow(),
            )
            checks.append(check)
        except Exception as e:
            logger.warning(f"Failed to parse check {item}: {e}")
            checks.append(CheckResult(
                check_id=item.get("check_id", "unknown"),
                title=item.get("title", "Parse error"),
                status="ERROR",
                severity="LOW",
                node=node_ip,
            ))

    return AuditReport.from_checks(node_ip, checks)


def parse_single_check(line: str, node_ip: str) -> Optional[CheckResult]:
    """
    Parse 1 dòng JSON (dùng cho stream mode).
    """
    try:
        item = json.loads(line)
        return CheckResult(
            check_id=item.get("check_id", "unknown"),
            title=item.get("title", ""),
            status=item.get("status", "ERROR"),
            severity=item.get("severity", "MEDIUM"),
            current_value=item.get("current_value", ""),
            expected_value=item.get("expected_value", ""),
            remediation=item.get("remediation", ""),
            section=item.get("section", ""),
            node=node_ip,
        )
    except (json.JSONDecodeError, Exception) as e:
        logger.debug(f"Non-JSON line: {line}")
        return None


def parse_nodetool_status(raw_output: str) -> List[NodeInfo]:
    """
    Parse output của 'nodetool status' thành danh sách NodeInfo.
    """
    nodes = []
    current_dc = ""

    for line in raw_output.split("\n"):
        line = line.strip()

        if line.startswith("Datacenter:"):
            current_dc = line.split(":")[1].strip()
            continue

        match = re.match(
            r'^([UD][NLJM])\s+(\d+\.\d+\.\d+\.\d+)\s+'
            r'([\d.]+\s+\w+)\s+(\d+)\s+.*?(\S{36})\s+(\S+)$',
            line
        )
        if match:
            status_code, ip, load, tokens, host_id, rack = match.groups()
            status = "UP" if status_code[0] == "U" else "DOWN"

            nodes.append(NodeInfo(
                ip=ip,
                status=status,
                datacenter=current_dc,
                rack=rack,
                load=load,
                tokens=int(tokens),
                host_id=host_id,
            ))

    return nodes
