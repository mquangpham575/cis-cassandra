import type {
  ClusterAuditReport, AuditReport, NodeStatus, HardenRequest, HardenResult
} from './types'

const BASE = import.meta.env.VITE_API_URL ?? ''

async function get<T>(path: string): Promise<T> {
  const res = await fetch(`${BASE}${path}`)
  if (!res.ok) throw new Error(`HTTP ${res.status}: ${await res.text()}`)
  return res.json() as Promise<T>
}

async function post<T>(path: string, body: unknown): Promise<T> {
  const res = await fetch(`${BASE}${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })
  if (!res.ok) throw new Error(`HTTP ${res.status}: ${await res.text()}`)
  return res.json() as Promise<T>
}

async function put<T>(path: string, body: unknown): Promise<T> {
  const res = await fetch(`${BASE}${path}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })
  if (!res.ok) throw new Error(`HTTP ${res.status}: ${await res.text()}`)
  return res.json() as Promise<T>
}

async function del(path: string): Promise<void> {
  const res = await fetch(`${BASE}${path}`, { method: 'DELETE' })
  if (!res.ok) throw new Error(`HTTP ${res.status}: ${await res.text()}`)
}

export const api = {
  clusterStatus: () => get<NodeStatus[]>('/api/cluster/status'),
  auditCluster: (section = 'all') =>
    get<ClusterAuditReport>(`/api/audit/cluster?section=${encodeURIComponent(section)}`),
  auditNode: (ip: string, section = 'all') =>
    get<AuditReport>(`/api/audit/node/${ip}?section=${encodeURIComponent(section)}`),
  hardenNode: (ip: string, req: HardenRequest) =>
    post<HardenResult>(`/api/harden/node/${ip}`, req),
  auditStreamUrl: (ip: string, section = 'all') =>
    `${BASE}/api/audit/stream/${ip}?section=${encodeURIComponent(section)}`,
  // Notes CRUD
  getNotes: () => get<import('./types').Note[]>('/api/notes'),
  createNote: (payload: Partial<import('./types').Note>) => post<import('./types').Note>('/api/notes', payload),
  updateNote: (id: string, payload: Partial<import('./types').Note>) => put<import('./types').Note>(`/api/notes/${id}`, payload),
  deleteNote: (id: string) => del(`/api/notes/${id}`),
}
