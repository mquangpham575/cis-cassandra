"""Cassandra-backed note storage for demo notes."""
from __future__ import annotations

import asyncio
import json
import logging
from dataclasses import asdict, dataclass
from datetime import datetime
from typing import Any

from cassandra.auth import PlainTextAuthProvider
from cassandra.cluster import Cluster
from cassandra.query import SimpleStatement

from config import settings
from models import Note, NoteSegment

logger = logging.getLogger(__name__)


@dataclass(slots=True)
class _NoteRow:
    id: str
    title: str
    segments_json: str
    node: str | None
    created_at: str | None
    updated_at: str | None


class CassandraNoteStore:
    def __init__(self) -> None:
        self._cluster: Cluster | None = None
        self._session = None
        self._ready = False

    def _auth_candidates(self) -> list[tuple[str, str]]:
        candidates: list[tuple[str, str]] = []
        admin_user = settings.cassandra_admin_username.strip()
        admin_pass = settings.cassandra_admin_password.strip()
        if admin_user and admin_pass:
            candidates.append((admin_user, admin_pass))

        if settings.cassandra_username.strip() and settings.cassandra_password.strip():
            legacy = (settings.cassandra_username, settings.cassandra_password)
            if legacy not in candidates:
                candidates.append(legacy)
        return candidates

    def _connect_sync(self) -> None:
        if self._ready and self._session is not None:
            return

        last_error: Exception | None = None
        for username, password in self._auth_candidates():
            try:
                auth_provider = PlainTextAuthProvider(username=username, password=password)
                self._cluster = Cluster(
                    contact_points=settings.cassandra_contact_points,
                    port=settings.cassandra_port,
                    auth_provider=auth_provider,
                )
                self._session = self._cluster.connect()
                self._session.execute(
                    "CREATE KEYSPACE IF NOT EXISTS %s WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 3}"
                    % settings.cassandra_keyspace
                )
                self._session.set_keyspace(settings.cassandra_keyspace)
                self._session.execute(
                    """
                    CREATE TABLE IF NOT EXISTS notes (
                        id text PRIMARY KEY,
                        title text,
                        segments_json text,
                        node text,
                        created_at text,
                        updated_at text
                    )
                    """
                )
                self._ready = True
                logger.info(
                    "Cassandra notes store ready on %s using role %s",
                    ", ".join(settings.cassandra_contact_points),
                    username,
                )
                return
            except Exception as exc:
                last_error = exc
                self._ready = False
                self._session = None
                if self._cluster is not None:
                    try:
                        self._cluster.shutdown()
                    except Exception:
                        pass
                    self._cluster = None

        raise ConnectionError(f"Cassandra notes store unavailable: {last_error}")

    async def ensure_ready(self) -> None:
        await asyncio.to_thread(self._connect_sync)

    def _row_to_note(self, row: _NoteRow) -> Note:
        segments = []
        if row.segments_json:
            try:
                raw_segments = json.loads(row.segments_json)
                segments = [NoteSegment(**segment) for segment in raw_segments]
            except Exception:
                segments = []
        return Note(
            id=row.id,
            title=row.title,
            segments=segments,
            node=row.node,
            created_at=row.created_at,
            updated_at=row.updated_at,
        )

    def _note_to_row(self, note: Note) -> _NoteRow:
        return _NoteRow(
            id=note.id,
            title=note.title,
            segments_json=json.dumps([segment.model_dump() for segment in note.segments], ensure_ascii=False),
            node=note.node,
            created_at=note.created_at,
            updated_at=note.updated_at,
        )

    def _list_notes_sync(self) -> list[Note]:
        self._connect_sync()
        query = SimpleStatement("SELECT id, title, segments_json, node, created_at, updated_at FROM notes")
        rows = self._session.execute(query)
        return [
            self._row_to_note(
                _NoteRow(
                    id=row.id,
                    title=row.title,
                    segments_json=row.segments_json or "[]",
                    node=row.node,
                    created_at=row.created_at,
                    updated_at=row.updated_at,
                )
            )
            for row in rows
        ]

    async def list_notes(self) -> list[Note]:
        try:
            return await asyncio.to_thread(self._list_notes_sync)
        except ConnectionError:
            raise
        except Exception as exc:
            raise ConnectionError(f"Cannot read notes from Cassandra: {exc}") from exc

    def _upsert_note_sync(self, note: Note) -> Note:
        self._connect_sync()
        row = self._note_to_row(note)
        self._session.execute(
            """
            INSERT INTO notes (id, title, segments_json, node, created_at, updated_at)
            VALUES (%s, %s, %s, %s, %s, %s)
            """,
            (row.id, row.title, row.segments_json, row.node, row.created_at, row.updated_at),
        )
        return note

    async def upsert_note(self, note: Note) -> Note:
        try:
            return await asyncio.to_thread(self._upsert_note_sync, note)
        except ConnectionError:
            raise
        except Exception as exc:
            raise ConnectionError(f"Cannot write note to Cassandra: {exc}") from exc

    def _delete_note_sync(self, note_id: str) -> bool:
        self._connect_sync()
        existing = self._session.execute("SELECT id FROM notes WHERE id = %s", (note_id,))
        if not list(existing):
            return False
        self._session.execute("DELETE FROM notes WHERE id = %s", (note_id,))
        return True

    async def delete_note(self, note_id: str) -> bool:
        try:
            return await asyncio.to_thread(self._delete_note_sync, note_id)
        except ConnectionError:
            raise
        except Exception as exc:
            raise ConnectionError(f"Cannot delete note from Cassandra: {exc}") from exc

    async def seed_demo_notes_if_empty(self) -> None:
        notes = await self.list_notes()
        if notes:
            return

        seed_node = settings.node_ips[0] if settings.node_ips else None
        now = datetime.utcnow().isoformat() + "Z"
        seed_notes = [
            Note(
                id="seed-encryption",
                title="Encryption follow-up",
                node=seed_node,
                segments=[
                    NoteSegment(id="seed-encryption-1", text="5.1 Inter-node encryption is failing in the fixture."),
                    NoteSegment(id="seed-encryption-2", text="5.2 Client encryption is also failing; verify cassandra.yaml."),
                ],
                created_at=now,
                updated_at=now,
            ),
            Note(
                id="seed-audit",
                title="Audit logging follow-up",
                node=seed_node,
                segments=[
                    NoteSegment(id="seed-audit-1", text="4.2 audit logging is disabled in the fixture."),
                    NoteSegment(id="seed-audit-2", text="Track whether the remediation changes replicate across the cluster."),
                ],
                created_at=now,
                updated_at=now,
            ),
        ]
        for note in seed_notes:
            await self.upsert_note(note)

    async def close(self) -> None:
        if self._cluster is None:
            return
        await asyncio.to_thread(self._cluster.shutdown)
        self._cluster = None
        self._session = None
        self._ready = False


notes_store = CassandraNoteStore()
