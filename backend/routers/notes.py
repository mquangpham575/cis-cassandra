"""Simple CRUD endpoints for demo notes persisted in Cassandra."""
from __future__ import annotations

import uuid
from datetime import datetime
from typing import List

from fastapi import APIRouter, HTTPException

from models import Note, NoteSegment
from services.cassandra_store import notes_store

router = APIRouter(prefix="/api/notes", tags=["Notes"])


@router.get("", response_model=List[Note])
async def list_notes():
    try:
        return await notes_store.list_notes()
    except ConnectionError as exc:
        raise HTTPException(status_code=503, detail=str(exc))


@router.post("", response_model=Note)
async def create_note(payload: dict):
    now = datetime.utcnow().isoformat() + "Z"
    note = Note(
        id=str(uuid.uuid4()),
        title=payload.get("title", "New note"),
        segments=[NoteSegment(**segment) for segment in payload.get("segments", [])],
        node=payload.get("node"),
        created_at=now,
        updated_at=now,
    )
    try:
        return await notes_store.upsert_note(note)
    except ConnectionError as exc:
        raise HTTPException(status_code=503, detail=str(exc))


@router.put("/{note_id}", response_model=Note)
async def update_note(note_id: str, payload: dict):
    try:
        notes = await notes_store.list_notes()
        existing = next((note for note in notes if note.id == note_id), None)
        if not existing:
            raise HTTPException(status_code=404, detail="Note not found")

        updated = Note(
            id=note_id,
            title=payload.get("title", existing.title),
            segments=[NoteSegment(**segment) for segment in payload.get("segments", [segment.model_dump() for segment in existing.segments])],
            node=payload.get("node", existing.node),
            created_at=existing.created_at,
            updated_at=datetime.utcnow().isoformat() + "Z",
        )
        return await notes_store.upsert_note(updated)
    except ConnectionError as exc:
        raise HTTPException(status_code=503, detail=str(exc))


@router.delete("/{note_id}")
async def delete_note(note_id: str):
    try:
        deleted = await notes_store.delete_note(note_id)
        if not deleted:
            raise HTTPException(status_code=404, detail="Note not found")
        return {"deleted": True}
    except ConnectionError as exc:
        raise HTTPException(status_code=503, detail=str(exc))
