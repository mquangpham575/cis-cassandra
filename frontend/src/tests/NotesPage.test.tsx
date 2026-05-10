import { describe, it, expect } from 'vitest'
import { fireEvent, render, screen } from '@testing-library/react'
import { NotesPage } from '../pages/NotesPage'

describe('NotesPage', () => {
  it('switches a note between view mode and edit mode', () => {
    render(<NotesPage />)

    expect(screen.getByText('Notes Dashboard')).toBeInTheDocument()
    expect(screen.getByText('Cluster follow-up')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Edit' })).toBeInTheDocument()
    expect(screen.queryByPlaceholderText('Note header')).not.toBeInTheDocument()

    fireEvent.click(screen.getByRole('button', { name: 'Edit' }))
    expect(screen.getByPlaceholderText('Note header')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'View' })).toBeInTheDocument()

    fireEvent.click(screen.getByRole('button', { name: 'View' }))
    expect(screen.queryByPlaceholderText('Note header')).not.toBeInTheDocument()
    expect(screen.getByText('Cluster follow-up')).toBeInTheDocument()
  })

  it('renders a starter note and allows adding/removing notes and segments in edit mode', () => {
    render(<NotesPage />)

    fireEvent.click(screen.getByRole('button', { name: 'Edit' }))
    fireEvent.click(screen.getByRole('button', { name: /\+ Add Note/i }))
    expect(screen.getAllByPlaceholderText('Note header')).toHaveLength(2)

    const removeButtons = screen.getAllByRole('button', { name: 'Remove' })
    fireEvent.click(removeButtons[0])
    expect(screen.getAllByPlaceholderText('Note header')).toHaveLength(1)

    fireEvent.click(screen.getByRole('button', { name: /\+ Add Segment/i }))
    expect(screen.getAllByPlaceholderText('Type a mini segment here...')).toHaveLength(2)

    fireEvent.click(screen.getAllByRole('button', { name: /Delete segment/i })[0])
    expect(screen.getAllByPlaceholderText('Type a mini segment here...')).toHaveLength(1)
  })
})