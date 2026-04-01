export type CheckStatus = 'PASS' | 'FAIL' | 'NEEDS_REVIEW'
export type CheckType = 'automated' | 'manual'
export type Tab = 'compliance' | 'monitoring'

export interface CheckResult {
  id: string
  title: string
  status: CheckStatus
  type: CheckType
  section: string
  evidence: string
  remediable: boolean
}

export interface AuditScore {
  total: number
  automated: number
  manual: number
  passed: number
  failed: number
  needs_review: number
  compliance_pct: number
}

export interface AuditReport {
  node: string
  timestamp: string
  score: AuditScore
  checks: CheckResult[]
  error?: string | null
}

export interface ClusterAuditReport {
  timestamp: string
  nodes: AuditReport[]
  cluster_score: AuditScore
}

export interface NodeStatus {
  ip: string
  reachable: boolean
  cassandra_running: boolean
  latency_ms: number | null
}

export interface HardenRequest {
  section: string
  dry_run: boolean
}

export interface HardenResult {
  node: string
  section: string
  exit_code: number
  stdout: string
  stderr: string
  success: boolean
}
