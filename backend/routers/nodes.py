"""
Endpoints liên quan đến thông tin nodes Cassandra.
Không cần authentication vì chỉ đọc thông tin.
"""
from fastapi import APIRouter, HTTPException
from typing import List

from models.node import NodeInfo, NodeStatus
from services.ssh import ssh_service
from services.parser import parse_nodetool_status
from config import settings

router = APIRouter(prefix="/nodes", tags=["Nodes"])


@router.get("", response_model=List[NodeInfo])
async def list_nodes():
    """
    Lấy danh sách 3 nodes với status UP/DOWN.
    Gọi nodetool status trên seed node (VM1).
    """
    try:
        raw = await ssh_service.get_nodetool_status(settings.node_ips[0])
        nodes = parse_nodetool_status(raw)

        # Thêm version cho mỗi node tìm được
        for node in nodes:
            try:
                ver = await ssh_service.get_cassandra_version(node.ip)
                node.cassandra_version = ver
            except Exception:
                node.cassandra_version = "unknown"

        return nodes

    except ConnectionError as e:
        # Nếu không SSH được, trả về danh sách mặc định với status UNKNOWN
        return [
            NodeInfo(ip=ip, status="UNKNOWN")
            for ip in settings.node_ips
        ]


@router.get("/{node_ip}/status", response_model=NodeStatus)
async def get_node_status(node_ip: str):
    """
    Lấy thông tin chi tiết 1 node:
    Cassandra version, Java version, nodetool info...
    """
    if node_ip not in settings.node_ips:
        raise HTTPException(status_code=404, detail=f"Node {node_ip} not found")

    try:
        # Chạy song song nhiều lệnh
        import asyncio
        nodetool_task = ssh_service.get_nodetool_status(node_ip)
        version_task = ssh_service.get_cassandra_version(node_ip)
        java_task = ssh_service.get_java_version(node_ip)
        python_task = ssh_service.get_python_version(node_ip)

        nodetool_raw, version, java_ver, python_ver = await asyncio.gather(
            nodetool_task, version_task, java_task, python_task,
            return_exceptions=True,
        )

        # Parse nodetool
        nodes = []
        if isinstance(nodetool_raw, str):
            nodes = parse_nodetool_status(nodetool_raw)

        # Tìm node hiện tại trong danh sách
        target = next((n for n in nodes if n.ip == node_ip), None)

        return NodeStatus(
            ip=node_ip,
            status=target.status if target else "UNKNOWN",
            cassandra_version=version if isinstance(version, str) else "unknown",
            java_version=java_ver if isinstance(java_ver, str) else "unknown",
            python_version=python_ver if isinstance(python_ver, str) else "unknown",
            load=target.load if target else "",
            tokens=target.tokens if target else 0,
            datacenter=target.datacenter if target else "",
            rack=target.rack if target else "",
            host_id=target.host_id if target else "",
        )

    except ConnectionError:
        raise HTTPException(
            status_code=503,
            detail=f"Cannot connect to {node_ip}"
        )
