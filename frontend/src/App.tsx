import { useState } from 'react'
import { DashboardPage } from './pages/DashboardPage'
import { NotesPage } from './pages/NotesPage'
import { CompliancePage } from './pages/CompliancePage'
import { AuditLivePage } from './pages/AuditLivePage'
import type { Tab } from './types'

const TABS: { id: Tab; label: string; icon: string }[] = [
  { id: 'dashboard', label: 'Dashboard', icon: '' },
  { id: 'notes', label: 'Notes', icon: '' },
  { id: 'compliance', label: 'Cluster Compliance', icon: '' },
  { id: 'audit-live', label: 'Audit Live', icon: '' },
]

export default function App() {
  const [tab, setTab] = useState<Tab>('dashboard')

  return (
    <div className="min-h-screen bg-gray-950 text-gray-100">
      {/* Top navigation */}
      <nav className="sticky top-0 z-40 bg-gray-900/80 backdrop-blur border-b border-gray-800">
        <div className="max-w-7xl mx-auto px-4 sm:px-6">
          <div className="flex items-center justify-between h-14">
            {/* Logo */}
            <div className="flex items-center gap-3">
              <span className="text-xl">🛡️</span>
              <div>
                <p className="text-sm font-bold leading-none">CIS Cassandra</p>
                <p className="text-xs text-gray-400 leading-none">Compliance Dashboard</p>
              </div>
            </div>

            {/* Tab switcher */}
            <div role="tablist" aria-label="Dashboard tabs" className="flex rounded-lg bg-gray-800 p-1 gap-1">
              {TABS.map(t => (
                <button
                  key={t.id}
                  role="tab"
                  aria-selected={tab === t.id}
                  onClick={() => setTab(t.id)}
                  className={`px-3 py-1.5 rounded-md text-sm font-medium transition-all
                    ${tab === t.id
                      ? 'bg-brand-600 text-white shadow'
                      : 'text-gray-400 hover:text-gray-200'
                    }`}
                >
                  {t.icon} {t.label}
                </button>
              ))}
            </div>


          </div>
        </div>
      </nav>

      {/* Page content */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 py-6">
        {tab === 'dashboard' && <DashboardPage />}
        {tab === 'notes' && <NotesPage />}
        {tab === 'compliance' && <CompliancePage />}
        {tab === 'audit-live' && <AuditLivePage />}
      </main>
    </div>
  )
}
