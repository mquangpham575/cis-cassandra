"""
Service SSH dùng asyncssh để kết nối và chạy lệnh trên VM.
Đây là layer quan trọng nhất — mọi tương tác với VM đều qua đây.
"""
import asyncssh
import asyncio
import json
import logging
from typing import AsyncGenerator, Optional
import os

from config import settings

logger = logging.getLogger(__name__)


class SSHService:
    """Quản lý SSH connections tới các Cassandra nodes."""

    def __init__(self):
        self._connections: dict[str, asyncssh.SSHClientConnection] = {}

    async def _get_connection(self, node_ip: str) -> asyncssh.SSHClientConnection:
        """
        Lấy hoặc tạo SSH connection tới node.
        Tái sử dụng connection nếu còn sống.
        """
        if node_ip in self._connections:
            conn = self._connections[node_ip]
            # Kiểm tra connection còn sống không
            try:
                result = await asyncio.wait_for(
                    conn.run("echo ping", check=True),
                    timeout=5
                )
                return conn
            except Exception:
                # Connection chết, xóa và tạo mới
                del self._connections[node_ip]

        # Resolve path like ~/.ssh/cis_key
        key_path = os.path.expanduser(settings.cis_ssh_key)

        try:
            conn = await asyncssh.connect(
                node_ip,
                port=settings.ssh_port,
                username=settings.cis_ssh_user,
                client_keys=[key_path],
                known_hosts=None,  # Skip host key checking (trong VPN nội bộ)
                connect_timeout=settings.ssh_timeout,
            )
            self._connections[node_ip] = conn
            logger.info(f"SSH connected to {node_ip}")
            return conn
        except Exception as e:
            logger.error(f"SSH connection failed to {node_ip}: {e}")
            raise ConnectionError(f"Cannot SSH to {node_ip}: {e}")

    async def run_command(self, node_ip: str, command: str) -> str:
        """
        Chạy 1 lệnh trên node, trả về stdout.
        Dùng cho các lệnh nhanh (nodetool status, version checks...).
        """
        conn = await self._get_connection(node_ip)
        try:
            result = await asyncio.wait_for(
                conn.run(command, check=True),
                timeout=settings.ssh_timeout,
            )
            return result.stdout.strip()
        except asyncssh.ProcessError as e:
            logger.error(f"Command failed on {node_ip}: {e.stderr}")
            raise RuntimeError(f"Command failed: {e.stderr}")
        except asyncio.TimeoutError:
            raise TimeoutError(f"Command timed out on {node_ip}")

    async def run_audit(self, node_ip: str, section: Optional[str] = None) -> str:
        """
        Chạy cis-tool.sh --audit trên node.
        Trả về toàn bộ JSON output.
        """
        cmd = f"sudo {settings.cis_tool_path} --audit"
        if section:
            cmd += f" --section '{section}'"

        return await self.run_command(node_ip, cmd)

    async def run_harden(self, node_ip: str, section: Optional[str] = None) -> str:
        """
        Chạy cis-tool.sh --harden trên node.
        Thực hiện remediation cho các FAIL checks.
        """
        cmd = f"sudo {settings.cis_tool_path} --harden"
        if section:
            cmd += f" --section '{section}'"

        return await self.run_command(node_ip, cmd)

    async def run_verify(self, node_ip: str) -> str:
        """
        Chạy cis-tool.sh --verify trên node.
        Kiểm tra lại sau khi harden.
        """
        cmd = f"sudo {settings.cis_tool_path} --verify"
        return await self.run_command(node_ip, cmd)

    async def stream_audit(self, node_ip: str) -> AsyncGenerator[str, None]:
        """
        Stream output từng dòng khi chạy audit.
        Dùng cho WebSocket endpoint — gửi real-time cho frontend.
        """
        conn = await self._get_connection(node_ip)
        cmd = f"sudo {settings.cis_tool_path} --audit --stream"

        try:
            async with conn.create_process(cmd) as proc:
                async for line in proc.stdout:
                    line = line.strip()
                    if line:
                        yield line
        except Exception as e:
            logger.error(f"Stream audit failed on {node_ip}: {e}")
            yield json.dumps({"error": str(e)})

    async def get_nodetool_status(self, node_ip: str) -> str:
        """Lấy output nodetool status."""
        return await self.run_command(node_ip, "nodetool status")

    async def get_cassandra_version(self, node_ip: str) -> str:
        """Lấy version Cassandra."""
        return await self.run_command(node_ip, "cassandra -v")

    async def get_java_version(self, node_ip: str) -> str:
        """Lấy version Java."""
        return await self.run_command(node_ip, "java -version 2>&1 | head -1")

    async def get_python_version(self, node_ip: str) -> str:
        """Lấy version Python."""
        return await self.run_command(node_ip, "python3 --version")

    async def close_all(self):
        """Đóng tất cả connections. Gọi khi shutdown."""
        for ip, conn in self._connections.items():
            conn.close()
            logger.info(f"SSH disconnected from {ip}")
        self._connections.clear()


# Singleton instance — dùng chung cho toàn app
ssh_service = SSHService()
