import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import App from '../App'

// Mock the page components — we test them separately
vi.mock('../pages/CompliancePage', () => ({
  CompliancePage: () => <div data-testid="compliance-page">Compliance</div>,
}))
vi.mock('../pages/MonitoringPage', () => ({
  MonitoringPage: () => <div data-testid="monitoring-page">Monitoring</div>,
}))

describe('App', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('renders the app shell', () => {
    render(<App />)
    expect(screen.getByText('CIS Cassandra')).toBeInTheDocument()
    expect(screen.getByText('Compliance Dashboard')).toBeInTheDocument()
  })

  it('shows the Compliance tab by default', () => {
    render(<App />)
    expect(screen.getByTestId('compliance-page')).toBeInTheDocument()
    expect(screen.queryByTestId('monitoring-page')).not.toBeInTheDocument()
  })

  it('switches to Monitoring tab on click', () => {
    render(<App />)
    fireEvent.click(screen.getByText(/Monitoring/))
    expect(screen.getByTestId('monitoring-page')).toBeInTheDocument()
    expect(screen.queryByTestId('compliance-page')).not.toBeInTheDocument()
  })

  it('switches back to Compliance tab', () => {
    render(<App />)
    fireEvent.click(screen.getByText(/Monitoring/))
    fireEvent.click(screen.getByText(/Compliance Audit/))
    expect(screen.getByTestId('compliance-page')).toBeInTheDocument()
  })

  it('shows version badge', () => {
    render(<App />)
    expect(screen.getByText('v1.3.0')).toBeInTheDocument()
  })
})
