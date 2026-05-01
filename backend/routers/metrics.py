"""
Proxy Prometheus metrics cho từng node.
Frontend gọi endpoint này thay vì gọi trực tiếp Prometheus.
"""
import httpx
from fastapi import APIRouter, HTTPException
from fastapi.responses import PlainTextResponse

from config import settings

router = APIRouter(prefix="/metrics", tags=["Metrics"])


@router.get("/{node_ip}", response_class=PlainTextResponse)
async def get_node_metrics(node_ip: str):
    """
    Lấy Prometheus metrics của 1 node.
    Proxy query tới Prometheus server.
    """
    if node_ip not in settings.node_ips:
        raise HTTPException(status_code=404, detail=f"Node {node_ip} not found")

    url = f"{settings.prometheus_url}/api/v1/query"

    try:
        async with httpx.AsyncClient(timeout=10) as client:
            metrics = {}
            queries = {
                "heap_used": f'cassandra_stats_heap_used{{instance="{node_ip}:7199"}}',
                "client_latency": f'cassandra_client_request_latency{{instance="{node_ip}:7199"}}',
                "disk_used": f'cassandra_storage_live_disk_space_used{{instance="{node_ip}:7199"}}',
                "dropped_messages": f'cassandra_net_droppedmessage{{instance="{node_ip}:7199"}}',
            }

            results = {}
            for key, query in queries.items():
                resp = await client.get(url, params={"query": query})
                if resp.status_code == 200:
                    data = resp.json()
                    results[key] = data.get("data", {}).get("result", [])

            return PlainTextResponse(
                content=str(results),
                media_type="application/json",
            )

    except httpx.ConnectError:
        raise HTTPException(
            status_code=503,
            detail="Cannot connect to Prometheus"
        )
