"""Pytest fixtures dùng chung."""
import pytest
from httpx import AsyncClient, ASGITransport
from main import app

@pytest.fixture
def anyio_backend():
    return "asyncio"

@pytest.fixture
async def client():
    """Async test client cho FastAPI."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c

@pytest.fixture
def sample_audit_json():
    """JSON mẫu giả lập output cis-tool.sh."""
    return '''
    {
        "checks": [
            {
                "check_id": "2.1",
                "title": "Ensure authentication is enabled",
                "status": "FAIL",
                "severity": "CRITICAL",
                "current_value": "AllowAllAuthenticator",
                "expected_value": "PasswordAuthenticator",
                "remediation": "Set authenticator: PasswordAuthenticator",
                "section": "Authentication and Authorization"
            },
            {
                "check_id": "2.2",
                "title": "Ensure authorization is enabled",
                "status": "PASS",
                "severity": "CRITICAL",
                "current_value": "CassandraAuthorizer",
                "expected_value": "CassandraAuthorizer",
                "remediation": "",
                "section": "Authentication and Authorization"
            },
            {
                "check_id": "5.1",
                "title": "Inter-node Encryption",
                "status": "MANUAL",
                "severity": "HIGH",
                "current_value": "",
                "expected_value": "all",
                "remediation": "Set internode_encryption: all",
                "section": "Encryption"
            }
        ]
    }
    '''
