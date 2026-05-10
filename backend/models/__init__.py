from pydantic import BaseModel, Field

from .audit import CheckResult, AuditReport
from .node import NodeInfo, NodeStatus, ComplianceReport


class NoteSegment(BaseModel):
    id: str
    text: str


class Note(BaseModel):
    id: str
    title: str
    segments: list[NoteSegment] = Field(default_factory=list)
    node: str | None = None
    created_at: str | None = None
    updated_at: str | None = None

__all__ = [
    "CheckResult",
    "AuditReport",
    "NodeInfo",
    "NodeStatus",
    "ComplianceReport",
    "Note",
    "NoteSegment",
]
