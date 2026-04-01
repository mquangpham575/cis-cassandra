import { useState, useCallback, useRef } from 'react'
import { api } from '../api'
import type { AuditReport } from '../types'

export type StreamState =
  | { status: 'idle' }
  | { status: 'streaming'; node: string }
  | { status: 'done'; report: AuditReport }
  | { status: 'error'; message: string }

export function useAuditStream() {
  const [state, setState] = useState<StreamState>({ status: 'idle' })
  const esRef = useRef<EventSource | null>(null)

  const startStream = useCallback((nodeIp: string, section = 'all') => {
    esRef.current?.close()
    setState({ status: 'streaming', node: nodeIp })

    const es = new EventSource(api.auditStreamUrl(nodeIp, section))
    esRef.current = es

    es.onmessage = (ev: MessageEvent) => {
      try {
        const payload = JSON.parse(ev.data as string) as Record<string, unknown>
        if (payload.status === 'done') {
          es.close()
          return
        }
        if (payload.status === 'error') {
          setState({ status: 'error', message: String(payload.detail ?? 'Unknown error') })
          es.close()
          return
        }
        if (payload.checks) {
          setState({ status: 'done', report: payload as unknown as AuditReport })
          es.close()
        }
      } catch {
        setState({ status: 'error', message: 'Failed to parse SSE payload' })
        es.close()
      }
    }

    es.onerror = () => {
      setState({ status: 'error', message: 'SSE connection lost' })
      es.close()
    }
  }, [])

  const stop = useCallback(() => {
    esRef.current?.close()
    setState({ status: 'idle' })
  }, [])

  return { state, startStream, stop }
}
