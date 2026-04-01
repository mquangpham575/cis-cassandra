#!/usr/bin/env bash
# CIS Section 4 hardening: Auditing and Logging

apply_4_2() {
  local yaml="${CASSANDRA_YAML:-/etc/cassandra/cassandra.yaml}"
  info "[CIS 4.2] Enabling audit logging in cassandra.yaml..."
  if $DRY_RUN; then
    info "  [dry-run] Would enable audit_logging_options.enabled: true in $yaml"
    return
  fi
  # Check if already enabled
  if grep -A10 "audit_logging_options:" "$yaml" 2>/dev/null | grep -qi "enabled: true"; then
    info "  [CIS 4.2] Audit logging already enabled"
    return
  fi
  if grep -q "^audit_logging_options:" "$yaml" 2>/dev/null; then
    # Section exists: use awk for safe in-block substitution (avoids /^[^ ]/ range issue)
    sudo awk '
      /^audit_logging_options:/ { in_block=1 }
      in_block && /^[^ #]/ && !/^audit_logging_options:/ { in_block=0 }
      in_block && /enabled: false/ { sub(/enabled: false/, "enabled: true") }
      { print }
    ' "$yaml" | sudo tee "$yaml.tmp" > /dev/null && sudo mv "$yaml.tmp" "$yaml"
  else
    # Section missing: append it
    printf '\naudit_logging_options:\n    enabled: true\n    logger:\n      - class_name: BinAuditLogger\n' \
      | sudo tee -a "$yaml" > /dev/null
  fi
  grep -A5 "audit_logging_options:" "$yaml" || true
  success "[CIS 4.2] Audit logging enabled. Restart required."
}

harden_section_4() {
  apply_4_2
}
