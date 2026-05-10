"""Pydantic models for note persistence."""
from __future__ import annotations

from pydantic import BaseModel, Field


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