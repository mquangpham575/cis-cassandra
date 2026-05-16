import { useMemo, useState, useEffect } from 'react'
import { api } from '../api'
import type { Note, NoteSegment } from '../types'

interface NoteCard {
  id: string
  title: string
  isEditing: boolean
  segments: NoteSegment[]
}

function createId(prefix: string, seed: number) {
  return `${prefix}-${seed}`
}

export function NotesPage() {
  const [noteSeed, setNoteSeed] = useState(1)
  const [segmentSeed, setSegmentSeed] = useState(1)
  const [notes, setNotes] = useState<NoteCard[]>([])

  useEffect(() => {
    let mounted = true
    api.getNotes().then((serverNotes: Note[]) => {
      if (!mounted) return
      // Map server notes to local NoteCard shape
      setNotes(serverNotes.map((n: Note) => ({
        id: n.id,
        title: n.title,
        isEditing: false,
        segments: n.segments.map((s: NoteSegment) => ({ id: s.id, text: s.text })),
      })))
    }).catch(() => {
      // keep empty state on error
    })
    return () => { mounted = false }
  }, [])

  const nextNoteId = useMemo(() => () => {
    setNoteSeed(prev => prev + 1)
    return createId('note', noteSeed + 1)
  }, [noteSeed])

  const nextSegmentId = useMemo(() => () => {
    setSegmentSeed(prev => prev + 1)
    return createId('segment', segmentSeed + 1)
  }, [segmentSeed])

  const addNote = () => {
    const id = nextNoteId()
    const segmentId = nextSegmentId()
    const newLocal = {
      id,
      title: 'New note',
      isEditing: true,
      segments: [{ id: segmentId, text: '' }],
    }
    setNotes(prev => [...prev, newLocal])
    // Persist to backend (server will assign canonical id, but we keep optimistic id)
    api.createNote({ title: newLocal.title, segments: newLocal.segments }).then((created: Note) => {
      setNotes(prev => prev.map(n => n.id === id ? { ...n, id: created.id } : n))
    }).catch(() => {
      // ignore error for now
    })
  }

  const removeNote = (noteId: string) => {
    setNotes(prev => prev.filter(note => note.id !== noteId))
    api.deleteNote(noteId).catch(() => {
      // ignore
    })
  }

  const updateTitle = (noteId: string, title: string) => {
    setNotes(prev => prev.map(note => note.id === noteId ? { ...note, title } : note))
  }

  const toggleEditMode = (noteId: string) => {
    // When toggling from edit -> view, save note to backend
    const toSave = notes.find(n => n.id === noteId)
    setNotes(prev => prev.map(note => note.id === noteId ? { ...note, isEditing: !note.isEditing } : note))
    if (toSave) {
      api.updateNote(noteId, { title: toSave.title, segments: toSave.segments }).catch(() => {
        // ignore
      })
    }
  }

  const addSegment = (noteId: string) => {
    const segmentId = nextSegmentId()
    setNotes(prev => prev.map(note => {
      if (note.id !== noteId) return note
      return {
        ...note,
        segments: [...note.segments, { id: segmentId, text: '' }],
      }
    }))
  }

  const updateSegment = (noteId: string, segmentId: string, text: string) => {
    setNotes(prev => prev.map(note => {
      if (note.id !== noteId) return note
      return {
        ...note,
        segments: note.segments.map(segment => segment.id === segmentId ? { ...segment, text } : segment),
      }
    }))
  }

  const removeSegment = (noteId: string, segmentId: string) => {
    setNotes(prev => prev.map(note => {
      if (note.id !== noteId) return note
      return {
        ...note,
        segments: note.segments.filter(segment => segment.id !== segmentId),
      }
    }))
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h2 className="text-xl font-bold">Notes Dashboard</h2>
          <p className="text-sm text-gray-400 mt-0.5">
            Capture quick headers, break them into small segments, and remove entire notes when they are no longer useful.
          </p>
        </div>

        <button
          onClick={addNote}
          className="px-4 py-2 rounded-lg bg-brand-600 hover:bg-brand-700 text-sm font-semibold transition-colors self-start sm:self-auto"
        >
          + Add Note
        </button>
      </div>

      {notes.length === 0 ? (
        <div className="rounded-xl border border-dashed border-gray-700 bg-gray-900/60 p-10 text-center text-gray-400">
          <p className="font-medium text-gray-200">No notes yet</p>
          <p className="text-sm mt-1">Create a note card to start typing headers and mini segments.</p>
          <button
            onClick={addNote}
            className="mt-4 px-4 py-2 rounded-lg bg-gray-800 hover:bg-gray-700 text-sm font-semibold transition-colors"
          >
            Create first note
          </button>
        </div>
      ) : (
        <div className="grid max-w-3xl grid-cols-1 gap-5 xl:grid-cols-2">
          {notes.map((note, index) => (
            <section
              key={note.id}
              className="rounded-2xl border border-gray-700 bg-gradient-to-br from-gray-900 to-gray-950 shadow-lg overflow-hidden"
            >
              <div className="h-1 bg-gradient-to-r from-brand-500 via-cyan-500 to-emerald-500" />
              <div className="p-5 space-y-4">
                <div className="flex items-start justify-between gap-3">
                  <div className="space-y-1 flex-1">
                    <p className="text-xs uppercase tracking-[0.25em] text-gray-500 font-mono">Note {index + 1}</p>
                    {note.isEditing ? (
                      <input
                        value={note.title}
                        onChange={e => updateTitle(note.id, e.target.value)}
                        placeholder="Note header"
                        className="w-full rounded-xl border border-gray-700 bg-gray-950/70 px-4 py-3 text-[1.375rem] font-semibold text-gray-100 placeholder:text-gray-600 focus:outline-none focus:border-brand-500"
                      />
                    ) : (
                      <div className="rounded-xl border border-transparent bg-transparent px-4 py-3">
                        <p className="text-[1.375rem] font-semibold text-gray-100">
                          {note.title || 'Untitled note'}
                        </p>
                      </div>
                    )}
                  </div>

                  <div className="flex shrink-0 flex-col gap-2">
                    <button
                      onClick={() => toggleEditMode(note.id)}
                      className="rounded-lg border border-gray-700 bg-gray-800 px-3 py-2 text-sm font-semibold text-gray-200 hover:bg-gray-700 transition-colors"
                    >
                      {note.isEditing ? 'View' : 'Edit'}
                    </button>
                    <button
                      onClick={() => removeNote(note.id)}
                      className="rounded-lg border border-red-900/70 bg-red-950/50 px-3 py-2 text-sm font-semibold text-red-300 hover:bg-red-900/70 transition-colors"
                    >
                      Remove
                    </button>
                  </div>
                </div>

                <div className="space-y-3 rounded-xl border border-gray-800 bg-gray-950/70 p-3">
                  {note.isEditing ? (
                    note.segments.map((segment, segmentIndex) => (
                      <div
                        key={segment.id}
                        className="rounded-xl border border-gray-700 bg-gray-900/70 p-3 space-y-2"
                      >
                        <div className="flex items-center justify-between gap-3">
                          <p className="text-xs uppercase tracking-[0.2em] text-gray-500 font-mono">
                            Segment {segmentIndex + 1}
                          </p>
                          <button
                            onClick={() => removeSegment(note.id, segment.id)}
                            className="text-xs font-semibold text-gray-400 hover:text-red-300 transition-colors"
                          >
                            Delete segment
                          </button>
                        </div>
                        <textarea
                          value={segment.text}
                          onChange={e => updateSegment(note.id, segment.id, e.target.value)}
                          placeholder="Type a mini segment here..."
                          rows={3}
                          className="w-full resize-y rounded-lg border border-gray-700 bg-gray-900/80 px-3 py-2 text-sm text-gray-100 placeholder:text-gray-600 focus:outline-none focus:border-cyan-500"
                        />
                      </div>
                    ))
                  ) : (
                    <div className="space-y-2">
                      {note.segments.length > 0 ? (
                        note.segments.map((segment, segmentIndex) => (
                          <div
                            key={segment.id}
                            className="rounded-xl border border-gray-800 bg-gray-900/60 px-4 py-3"
                          >
                            <p className="text-xs uppercase tracking-[0.2em] text-gray-500 font-mono mb-1">
                              Segment {segmentIndex + 1}
                            </p>
                            <p className="text-sm text-gray-200 whitespace-pre-wrap">
                              {segment.text || 'No segment text yet'}
                            </p>
                          </div>
                        ))
                      ) : (
                        <div className="rounded-xl border border-gray-800 bg-gray-950/60 px-4 py-3 text-sm text-gray-500">
                          No segments yet
                        </div>
                      )}
                    </div>
                  )}
                </div>

                <div className="flex items-center justify-between gap-3 pt-1">
                  <p className="text-xs text-gray-500">
                    {note.segments.length} segment{note.segments.length === 1 ? '' : 's'} inside
                  </p>
                  {note.isEditing ? (
                    <button
                      onClick={() => addSegment(note.id)}
                      className="rounded-lg bg-gray-800 hover:bg-gray-700 px-3 py-2 text-sm font-semibold transition-colors"
                    >
                      + Add Segment
                    </button>
                  ) : (
                    <span className="text-xs text-gray-500">Switch to edit mode to change content</span>
                  )}
                </div>
              </div>
            </section>
          ))}
        </div>
      )}
    </div>
  )
}