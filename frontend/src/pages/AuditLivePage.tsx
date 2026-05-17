import { useEffect, useRef, useState } from 'react'
import { useAuditStream } from '../hooks/useAuditStream'
import { api } from '../api'
import type { AuditReport, NodeStatus } from '../types'

const SECTIONS = [
  { value: 'all', label: 'All Sections' },
  { value: '1', label: 'Section 1 — Installation' },
  { value: '2', label: 'Section 2 — Authentication' },
  { value: '3', label: 'Section 3 — Authorization' },
  { value: '4', label: 'Section 4 — Logging' },
  { value: '5', label: 'Section 5 — Encryption' },
  { value: 'os', label: 'Section OS — OS Hardening' },
]

function lineColor(line: string): string {
  const l = line.toLowerCase()
  if (l.includes('"pass"') || l.includes('✅') || l.includes('pass')) return 'text-green-400'
  if (l.includes('"fail"') || l.includes('❌') || l.includes('fail')) return 'text-red-400'
  if (l.includes('"manual"') || l.includes('⚠') || l.includes('warn') || l.includes('review')) return 'text-yellow-400'
  if (l.includes('error')) return 'text-red-500'
  return 'text-gray-300'
}

async function downloadAuditExcel(report: AuditReport) {
  try {
    const blob = await api.exportAudit(report.node)
    const fileName = `audit-${report.node}-${new Date(report.timestamp).toISOString().replace(/[:.]/g, '-')}.xlsx`
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = fileName
    document.body.appendChild(a)
    a.click()
    a.remove()
    URL.revokeObjectURL(url)
  } catch (e) {
    console.error('Export failed', e)
  }
}

export function AuditLivePage() {
  const [nodes, setNodes] = useState<NodeStatus[]>([])
  const [selectedIp, setSelectedIp] = useState<string>('')
  const [selectedSection, setSelectedSection] = useState('all')
  const [lines, setLines] = useState<string[]>([])
  const [isHardening, setIsHardening] = useState(false)
  const terminalRef = useRef<HTMLDivElement>(null)
  const { state, startStream, stop } = useAuditStream()
 
  // Load node list on mount
  useEffect(() => {
    api.clusterStatus()
      .then(s => {
        setNodes(s)
        if (s.length > 0 && !selectedIp) setSelectedIp(s[0].ip)
      })
      .catch(() => {
        const defaults = ['10.0.1.11', '10.0.1.12', '10.0.1.13']
        setNodes(defaults.map(ip => ({ ip, reachable: false, cassandra_running: false, latency_ms: null })))
        setSelectedIp(defaults[0])
      })
  }, [selectedIp])

  // Collect stream messages into lines array
  useEffect(() => {
    if (state.status === 'done') {
      setLines(prev => [
        ...prev,
        '─────────────────────────────────────',
        `✅ Audit complete — ${state.report.score.passed}/${state.report.score.total} checks passed (${state.report.score.compliance_pct}% compliant)`,
        '─────────────────────────────────────',
      ])
    }
    if (state.status === 'error') {
      setLines(prev => [...prev, `❌ Error: ${state.message}`])
    }
  }, [state])

  // Auto-scroll terminal to bottom
  useEffect(() => {
    if (terminalRef.current) {
      terminalRef.current.scrollTop = terminalRef.current.scrollHeight
    }
  }, [lines])

  const handleStart = () => {
    if (!selectedIp) return
    setLines([
      `$ cis-tool.sh --audit --section ${selectedSection} --node ${selectedIp}`,
      `Starting audit on ${selectedIp} at ${new Date().toLocaleTimeString()}...`,
      '',
    ])
    startStream(selectedIp, selectedSection, (raw: string) => {
      setLines(prev => [...prev, raw])
    })
  }

  const handleHarden = async () => {
    if (!selectedIp) return
    setIsHardening(true)
    setLines([
      `$ cis-tool.sh --harden --section ${selectedSection} --node ${selectedIp}`,
      `Running automated hardening on ${selectedIp} at ${new Date().toLocaleTimeString()}...`,
      'Applying CIS recommended hardening controls...',
      '',
    ])

    try {
      const res = await api.hardenNode(selectedIp, {
        section: selectedSection,
        dry_run: false,
      })
      
      const outLines = res.stdout ? res.stdout.split('\n') : []
      const errLines = res.stderr ? res.stderr.split('\n') : []
      
      setLines(prev => [
        ...prev,
        ...outLines,
        ...errLines,
        '─────────────────────────────────────',
        res.success 
          ? `✅ Hardening completed successfully! (Exit code: ${res.exit_code})`
          : `❌ Hardening failed! (Exit code: ${res.exit_code})`,
        '─────────────────────────────────────',
        '🔄 Auto-triggering fresh audit to verify compliance...',
        '',
      ])

      // Auto-trigger audit after 1.5s
      setTimeout(() => {
        setLines([
          `$ cis-tool.sh --audit --section ${selectedSection} --node ${selectedIp}`,
          `Starting verification audit on ${selectedIp} at ${new Date().toLocaleTimeString()}...`,
          '',
        ])
        startStream(selectedIp, selectedSection, (raw: string) => {
          setLines(prev => [...prev, raw])
        })
      }, 1500)
    } catch (e: any) {
      setLines(prev => [
        ...prev,
        `❌ Error invoking hardening API: ${e.message || String(e)}`,
      ])
    } finally {
      setIsHardening(false)
    }
  }

  const handleStop = () => {
    stop()
    setLines(prev => [...prev, '', '⏹ Audit stopped by user.'])
  }

  const handleClear = () => setLines([])

  const handleExport = () => {
    if (state.status !== 'done') return
    void downloadAuditExcel(state.report)
  }

  const isStreaming = state.status === 'streaming'
  const canExport = state.status === 'done'

  return (
    <div className="space-y-4">
      {/* Header */}
      <div>
        <h2 className="text-xl font-bold">Audit Live</h2>
        <p className="text-sm text-gray-400 mt-0.5">Real-time CIS audit output streamed from node</p>
      </div>

      {/* Controls */}
      <div className="flex flex-wrap items-center gap-3 rounded-xl bg-gray-900 border border-gray-700 p-4">
        {/* Node selector */}
        <div className="flex flex-col gap-1">
          <label className="text-xs text-gray-400 uppercase tracking-wider">Node</label>
          <select
            value={selectedIp}
            onChange={e => setSelectedIp(e.target.value)}
            disabled={isStreaming || isHardening}
            className="bg-gray-800 border border-gray-600 rounded-lg px-3 py-1.5 text-sm font-mono text-gray-200 disabled:opacity-50 focus:outline-none focus:border-brand-500"
          >
            {nodes.map(n => (
              <option key={n.ip} value={n.ip}>
                {n.ip} {n.cassandra_running ? '🟢' : '⚫'}
              </option>
            ))}
          </select>
        </div>

        {/* Section selector */}
        <div className="flex flex-col gap-1">
          <label className="text-xs text-gray-400 uppercase tracking-wider">Section</label>
          <select
            value={selectedSection}
            onChange={e => setSelectedSection(e.target.value)}
            disabled={isStreaming || isHardening}
            className="bg-gray-800 border border-gray-600 rounded-lg px-3 py-1.5 text-sm text-gray-200 disabled:opacity-50 focus:outline-none focus:border-brand-500"
          >
            {SECTIONS.map(s => (
              <option key={s.value} value={s.value}>{s.label}</option>
            ))}
          </select>
        </div>

        {/* Action buttons */}
        <div className="flex gap-2 ml-auto items-end pb-0.5">
          {!isStreaming ? (
            <>
              <button
                onClick={handleStart}
                disabled={!selectedIp || isHardening}
                className="px-4 py-2 rounded-lg bg-brand-600 hover:bg-brand-700 disabled:opacity-50 text-sm font-semibold transition-colors"
              >
                Start Audit
              </button>
              <button
                onClick={handleHarden}
                disabled={!selectedIp || isHardening}
                className="px-4 py-2 rounded-lg bg-amber-600 hover:bg-amber-700 disabled:opacity-50 text-sm font-semibold transition-colors flex items-center gap-1.5"
              >
                {isHardening ? (
                  <>
                    <span className="animate-spin rounded-full h-3.5 w-3.5 border-2 border-white border-t-transparent" />
                    Hardening...
                  </>
                ) : (
                  <>Harden</>
                )}
              </button>
            </>
          ) : (
            <button
              onClick={handleStop}
              className="px-4 py-2 rounded-lg bg-red-700 hover:bg-red-600 text-sm font-semibold transition-colors"
            >
              ⏹ Stop
            </button>
          )}
          <button
            onClick={handleClear}
            disabled={isStreaming || isHardening}
            className="px-4 py-2 rounded-lg bg-gray-700 hover:bg-gray-600 disabled:opacity-50 text-sm transition-colors"
          >
            Clear
          </button>
          <button
            onClick={handleExport}
            disabled={!canExport || isStreaming || isHardening}
            title={canExport ? 'Export the last completed audit to Excel' : 'Run an audit first to enable export'}
            className="px-4 py-2 rounded-lg bg-emerald-600 hover:bg-emerald-500 disabled:opacity-40 text-sm font-semibold transition-colors"
          >
            Export to Excel
          </button>
        </div>
      </div>

      {/* Terminal window */}
      <div className="rounded-xl overflow-hidden border border-gray-700">
        {/* Terminal title bar */}
        <div className="flex items-center gap-2 px-4 py-2 bg-gray-800 border-b border-gray-700">
          <span className="w-3 h-3 rounded-full bg-red-500" />
          <span className="w-3 h-3 rounded-full bg-yellow-500" />
          <span className="w-3 h-3 rounded-full bg-green-500" />
          <span className="text-xs font-mono text-gray-400 ml-2">
            cis-tool.sh — {selectedIp || 'no node selected'}
          </span>
          {isStreaming && (
            <span className="ml-auto flex items-center gap-1.5 text-xs text-brand-400">
              <span className="animate-pulse w-2 h-2 rounded-full bg-brand-400 inline-block" />
              Streaming
            </span>
          )}
        </div>

        {/* Terminal body */}
        <div
          ref={terminalRef}
          className="bg-gray-950 font-mono text-xs p-4 overflow-y-auto"
          style={{ height: '460px' }}
        >
          {lines.length === 0 ? (
            <p className="text-gray-600">
              Select a node and click ▶ Start Audit to begin streaming...
            </p>
          ) : (
            lines.map((line, i) => (
              <div key={i} className={`leading-5 whitespace-pre-wrap ${lineColor(line)}`}>
                {line || '\u00A0'}
              </div>
            ))
          )}
          {isStreaming && (
            <span className="animate-pulse text-brand-400">█</span>
          )}
        </div>
      </div>

      {/* Status bar */}
      <div className="flex items-center gap-4 text-xs text-gray-500 font-mono">
        <span>Status: <span className={
          isStreaming ? 'text-brand-400' :
          state.status === 'done' ? 'text-green-400' :
          state.status === 'error' ? 'text-red-400' : 'text-gray-400'
        }>{state.status}</span></span>
        <span>Lines: {lines.length}</span>
        {state.status === 'done' && (
          <span className="text-green-400">
            {state.report.score.passed}/{state.report.score.total} passed ({state.report.score.compliance_pct}%)
          </span>
        )}
      </div>
    </div>
  )
}
