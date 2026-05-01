"""CIS Cassandra Compliance Dashboard — FastAPI Application."""
from __future__ import annotations
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, WebSocket
from fastapi.middleware.cors import CORSMiddleware

from config import settings
from routers import audit, remediate, nodes, metrics, report
from websockets.audit_ws import audit_websocket_handler
from services.ssh import ssh_service

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)-8s %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup & shutdown events."""
    logger.info("Backend API starting up...")
    logger.info(f"Cassandra nodes: {settings.node_ips}")
    yield
    # Shutdown: đóng SSH connections
    logger.info("Shutting down, closing SSH connections...")
    await ssh_service.close_all()

app = FastAPI(
    title="CIS Cassandra Compliance Dashboard",
    description=(
        "Real-time CIS Apache Cassandra 4.0 Benchmark v1.3.0 compliance auditing "
        "and automated remediation for a 3-node cluster."
    ),
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173", "http://localhost:3000", "*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(nodes.router)
app.include_router(audit.router)
app.include_router(remediate.router)
app.include_router(metrics.router)
app.include_router(report.router)

# WebSocket endpoint
@app.websocket("/ws/audit/{node_ip}")
async def ws_audit(websocket: WebSocket, node_ip: str):
    await audit_websocket_handler(websocket, node_ip)

@app.get("/health", tags=["Health"])
async def health() -> dict:
    return {"status": "ok", "service": "cis-cassandra-dashboard", "nodes": settings.node_ips}

@app.get("/")
async def root() -> dict:
    return {
        "service": "CIS Cassandra Compliance Dashboard",
        "docs": "/docs",
        "health": "/health",
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host=settings.api_host,
        port=settings.api_port,
        reload=True,
    )
