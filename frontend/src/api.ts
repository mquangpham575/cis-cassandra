import type {
  ClusterAuditReport, AuditReport, NodeStatus, HardenRequest, HardenResult, Note
} from './types'

const BASE = import.meta.env.VITE_API_URL ?? ''
const API_SECRET_KEY = import.meta.env.VITE_API_SECRET_KEY?.trim()

function authHeaders(): HeadersInit {
  return API_SECRET_KEY
    ? { Authorization: `Bearer ${API_SECRET_KEY}` }
    : {}
}

async function get<T>(path: string): Promise<T> {
  const res = await fetch(`${BASE}${path}`, {
    headers: authHeaders(),
  })
  if (!res.ok) throw new Error(`HTTP ${res.status}: ${await res.text()}`)
  return res.json() as Promise<T>
}

async function post<T>(path: string, body: unknown): Promise<T> {
  const res = await fetch(`${BASE}${path}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...authHeaders(),
    },
    body: JSON.stringify(body),
  })
  if (!res.ok) throw new Error(`HTTP ${res.status}: ${await res.text()}`)
  return res.json() as Promise<T>
}

async function put<T>(path: string, body: unknown): Promise<T> {
  const res = await fetch(`${BASE}${path}`, {
    method: 'PUT',
    headers: {
      'Content-Type': 'application/json',
      ...authHeaders(),
    },
    body: JSON.stringify(body),
  })
  if (!res.ok) throw new Error(`HTTP ${res.status}: ${await res.text()}`)
  return res.json() as Promise<T>
}

async function del<T>(path: string): Promise<T> {
  const res = await fetch(`${BASE}${path}`, {
    method: 'DELETE',
    headers: authHeaders(),
  })
  if (!res.ok) throw new Error(`HTTP ${res.status}: ${await res.text()}`)
  return res.json() as Promise<T>
}

export const api = {
  clusterStatus: () => get<NodeStatus[]>('/api/cluster/status'),
  auditCluster: (section = 'all') =>
    get<ClusterAuditReport>(`/api/audit/cluster?section=${encodeURIComponent(section)}`),
  auditNode: (ip: string, section = 'all') =>
    get<AuditReport>(`/api/audit/node/${ip}?section=${encodeURIComponent(section)}`),
  hardenNode: (ip: string, req: HardenRequest) =>
    post<HardenResult>(`/api/harden/node/${ip}`, req),
  hardenCluster: (req: HardenRequest) =>
    post<HardenResult[]>('/api/harden/cluster', req),
  auditStreamUrl: (ip: string, section = 'all') => {
    const wsBase = BASE ? BASE.replace(/^http/, 'ws') : (window.location.protocol === 'https:' ? 'wss:' : 'ws:') + '//' + window.location.host
    return `${wsBase}/ws/audit/${ip}?section=${encodeURIComponent(section)}`
  },
  exportAudit: async (ip: string) => {
    const res = await fetch(`${BASE}/api/audit/${encodeURIComponent(ip)}/export`, {
      headers: authHeaders(),
    })
    if (!res.ok) throw new Error(`HTTP ${res.status}: ${await res.text()}`)
    return res.blob()
  },
  exportClusterAudit: async () => {
    const res = await fetch(`${BASE}/api/audit/cluster/export`, {
      headers: authHeaders(),
    })
    if (!res.ok) throw new Error(`HTTP ${res.status}: ${await res.text()}`)
    return res.blob()
  },

  // Notes API
  getNotes: () => get<Note[]>('/api/notes'),
  createNote: (note: Partial<Note>) => post<Note>('/api/notes', note),
  updateNote: (id: string, note: Partial<Note>) =>
    put<Note>(`/api/notes/${id}`, note),
  deleteNote: (id: string) => del<{ deleted: boolean }>(`/api/notes/${id}`),
}
