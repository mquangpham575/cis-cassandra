import { useState, useCallback, useRef, useEffect } from 'react'
import { api } from '../api'
import type { AuditReport } from '../types'

export type StreamState =
  | { status: 'idle' }
  | { status: 'streaming'; node: string }
  | { status: 'done'; report: AuditReport }
  | { status: 'error'; message: string }

export function useAuditStream() {
  const [state, setState] = useState<StreamState>({ status: 'idle' })
  const wsRef = useRef<WebSocket | null>(null)

  // Close WebSocket on unmount to prevent resource leaks.
  useEffect(() => {
    return () => {
      wsRef.current?.close()
      wsRef.current = null
    }
  }, [])

  const startStream = useCallback((
    nodeIp: string,
    section = 'all',
    onLine?: (raw: string) => void,   // optional per-line callback for live terminal
  ) => {
    wsRef.current?.close()
    wsRef.current = null
    setState({ status: 'streaming', node: nodeIp })

    const ws = new WebSocket(api.auditStreamUrl(nodeIp, section))
    wsRef.current = ws

    ws.onmessage = (ev: MessageEvent) => {
      if (typeof ev.data !== 'string') return

      // Emit raw text line to caller before parsing (powers Audit Live terminal)
      if (onLine) onLine(ev.data)

      try {
        const payload = JSON.parse(ev.data) as Record<string, unknown>

        if (payload.type === 'complete' && payload.summary) {
          const summary = payload.summary as Record<string, unknown>
          setState({
            status: 'done',
            report: {
              node: nodeIp,
              timestamp: new Date().toISOString(),
              score: {
                total: Number(summary.total ?? 0),
                automated: 0,
                manual: Number(summary.manual ?? 0),
                passed: Number(summary.passed ?? 0),
                failed: Number(summary.failed ?? 0),
                needs_review: 0,
                compliance_pct: Number(summary.score ?? 0),
              },
              checks: [],
            } as AuditReport,
          })
          ws.close()
          wsRef.current = null
          return
        }
        if (payload.type === 'error') {
          setState({ status: 'error', message: String(payload.message ?? 'Unknown error') })
          ws.close()
          wsRef.current = null
          return
        }
      } catch {
        setState({ status: 'error', message: 'Failed to parse WebSocket payload' })
        ws.close()
        wsRef.current = null
      }
    }

    ws.onerror = () => {
      setState({ status: 'error', message: 'WebSocket connection lost' })
      ws.close()
      wsRef.current = null
    }
  }, [])

  const stop = useCallback(() => {
    wsRef.current?.close()
    wsRef.current = null
    setState({ status: 'idle' })
  }, [])

  return { state, startStream, stop }
}
