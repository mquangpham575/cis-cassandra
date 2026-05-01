"""
Models cho thông tin node Cassandra.
"""
from pydantic import BaseModel, Field
from typing import Literal, Optional, List
from datetime import datetime


class NodeInfo(BaseModel):
    """Thông tin cơ bản 1 node."""
    ip: str
    status: Literal["UP", "DOWN", "UNKNOWN"] = "UNKNOWN"
    cassandra_version: str = ""
    datacenter: str = ""
    rack: str = ""
    load: str = ""
    tokens: int = 0
    host_id: str = ""


class NodeStatus(BaseModel):
    """Trạng thái chi tiết 1 node (nodetool output)."""
    ip: str
    status: Literal["UP", "DOWN", "UNKNOWN"]
    cassandra_version: str
    java_version: str = ""
    python_version: str = ""
    uptime: str = ""
    heap_used: str = ""
    heap_max: str = ""
    load: str = ""
    tokens: int = 0
    datacenter: str = ""
    rack: str = ""
    host_id: str = ""
    last_checked: datetime = Field(default_factory=datetime.utcnow)


class ComplianceReport(BaseModel):
    """Báo cáo compliance tổng hợp tất cả nodes."""
    total_nodes: int
    nodes_up: int
    nodes_down: int
    overall_score: float
    reports: list  # List[AuditReport] — sẽ import khi cần
    generated_at: datetime = Field(default_factory=datetime.utcnow)
