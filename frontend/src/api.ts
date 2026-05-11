import type {
  ClusterAuditReport, AuditReport, NodeStatus, HardenRequest, HardenResult
} from './types'

// Use relative `/api` paths so the Vite dev-server proxy handles backend routing.
const BASE = ''
const API_SECRET_KEY = import.meta.env.VITE_API_SECRET_KEY?.trim()

function authHeaders(): HeadersInit {
  return API_SECRET_KEY
    ? { Authorization: `Bearer ${API_SECRET_KEY}` }
    : {}
}

async function get<T>(path: string): Promise<T> {
  const res = await fetch(`${BASE}${path}`)
  if (!res.ok) throw new Error(`HTTP ${res.status}: ${await res.text()}`)
  return res.json() as Promise<T>
}

async function post<T>(path: string, body: unknown): Promise<T> {
  const res = await fetch(`${BASE}${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...authHeaders() },
    body: JSON.stringify(body),
  })
  if (!res.ok) throw new Error(`HTTP ${res.status}: ${await res.text()}`)
  return res.json() as Promise<T>
}

async function put<T>(path: string, body: unknown): Promise<T> {
  const res = await fetch(`${BASE}${path}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json', ...authHeaders() },
    body: JSON.stringify(body),
  })
  if (!res.ok) throw new Error(`HTTP ${res.status}: ${await res.text()}`)
  return res.json() as Promise<T>
}

async function del(path: string): Promise<void> {
  const res = await fetch(`${BASE}${path}`, {
    method: 'DELETE',
    headers: authHeaders(),
  })
  if (!res.ok) throw new Error(`HTTP ${res.status}: ${await res.text()}`)
}

type BackendAuditReport = {
  node: string
  total_checks: number
  passed: number
  failed: number
  manual: number
  errors?: number
  score: number
}

function toAuditScore(report: BackendAuditReport) {
  const needsReview = (report.manual ?? 0) + (report.errors ?? 0)
  const automated = Math.max(report.total_checks - report.manual - (report.errors ?? 0), 0)
  return {
    total: report.total_checks,
    automated,
    manual: report.manual,
    passed: report.passed,
    failed: report.failed,
    needs_review: needsReview,
    compliance_pct: report.score,
  }
}

function aggregateClusterReports(reports: BackendAuditReport[]): ClusterAuditReport {
  const nodes = reports.map((report) => ({
    node: report.node,
    timestamp: new Date().toISOString(),
    score: toAuditScore(report),
    checks: [],
    error: report.errors ? `Audit completed with ${report.errors} error(s)` : undefined,
  })) as ClusterAuditReport['nodes']

  const clusterTotals = reports.reduce(
    (acc, report) => {
      acc.total += report.total_checks
      acc.passed += report.passed
      acc.failed += report.failed
      acc.manual += report.manual
      acc.needs_review += (report.manual ?? 0) + (report.errors ?? 0)
      return acc
    },
    { total: 0, passed: 0, failed: 0, manual: 0, needs_review: 0 },
  )

  const scorable = Math.max(clusterTotals.total - clusterTotals.needs_review, 0)
  const compliance_pct = scorable > 0 ? Math.round((clusterTotals.passed / scorable) * 1000) / 10 : 0

  return {
    timestamp: new Date().toISOString(),
    nodes,
    cluster_score: {
      total: clusterTotals.total,
      automated: Math.max(clusterTotals.total - clusterTotals.manual - (clusterTotals.needs_review - clusterTotals.manual), 0),
      manual: clusterTotals.manual,
      passed: clusterTotals.passed,
      failed: clusterTotals.failed,
      needs_review: clusterTotals.needs_review,
      compliance_pct,
    },
  }
}

export const api = {
  clusterStatus: () => get<NodeStatus[]>('/api/cluster/status'),
  auditCluster: async () => {
    const reports = await post<BackendAuditReport[]>('/api/audit/all', {})
    return aggregateClusterReports(reports)
  },
  auditNode: (ip: string, section = 'all') =>
    get<AuditReport>(`/api/audit/${ip}?section=${encodeURIComponent(section)}`),
  hardenNode: (ip: string, req: HardenRequest) =>
    post<HardenResult>(`/api/harden/node/${ip}`, req),
  auditStreamUrl: (ip: string, section = 'all') =>
    `/ws/audit/${ip}?section=${encodeURIComponent(section)}`,
  // Notes CRUD
  getNotes: () => get<import('./types').Note[]>('/api/notes'),
  createNote: (payload: Partial<import('./types').Note>) => post<import('./types').Note>('/api/notes', payload),
  updateNote: (id: string, payload: Partial<import('./types').Note>) => put<import('./types').Note>(`/api/notes/${id}`, payload),
  deleteNote: (id: string) => del(`/api/notes/${id}`),
}
