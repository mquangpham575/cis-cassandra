"""Application settings loaded from environment / .env file."""
from __future__ import annotations
from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    cis_ssh_key: str = Field("~/.ssh/cis_key", validation_alias="CIS_SSH_KEY")
    cis_ssh_user: str = Field("cassandra", validation_alias="CIS_SSH_USER")
    # Accepts comma-separated IPs from NODE_IPS env var
    node_ips_str: str = Field(
        "10.0.1.11,10.0.1.12,10.0.1.13",
        validation_alias="NODE_IPS",
    )

    ssh_port: int = Field(22, validation_alias="SSH_PORT")
    ssh_timeout: int = Field(30, validation_alias="SSH_TIMEOUT")
    cis_tool_path: str = Field("/opt/cis/cis-tool.sh", validation_alias="CIS_TOOL_PATH")
    prometheus_url: str = Field("http://10.0.1.11:9090", validation_alias="PROMETHEUS_URL")
    
    api_host: str = Field("0.0.0.0", validation_alias="API_HOST")
    api_port: int = Field(8000, validation_alias="API_PORT")
    api_secret_key: str = Field("change-me-in-production", validation_alias="API_SECRET_KEY")
    audit_cache_ttl: int = Field(300, validation_alias="AUDIT_CACHE_TTL")

    @property
    def node_ips(self) -> list[str]:
        return [ip.strip() for ip in self.node_ips_str.split(",") if ip.strip()]

settings = Settings()
