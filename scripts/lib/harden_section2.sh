#!/usr/bin/env bash
# CIS Section 2 hardening: Authentication and Authorization

apply_2_1() {
  local yaml="${CASSANDRA_YAML:-/etc/cassandra/cassandra.yaml}"
  info "[CIS 2.1] Enabling PasswordAuthenticator..."
  if $DRY_RUN; then
    info "  [dry-run] Would set authenticator: PasswordAuthenticator in $yaml"
    return
  fi
  if grep -qiE "^[Aa]uthenticator:.*PasswordAuthenticator" "$yaml" 2>/dev/null; then
    info "  [CIS 2.1] PasswordAuthenticator already set"
    return
  fi
  sudo sed -i 's/^[Aa]uthenticator:.*/authenticator: PasswordAuthenticator/' "$yaml"
  grep "^authenticator:" "$yaml"
  success "[CIS 2.1] Done. Cassandra restart required."
}

apply_2_2() {
  local yaml="${CASSANDRA_YAML:-/etc/cassandra/cassandra.yaml}"
  info "[CIS 2.2] Enabling CassandraAuthorizer..."
  if $DRY_RUN; then
    info "  [dry-run] Would set authorizer: CassandraAuthorizer in $yaml"
    return
  fi
  if grep -qiE "^[Aa]uthorizer:.*CassandraAuthorizer" "$yaml" 2>/dev/null; then
    info "  [CIS 2.2] CassandraAuthorizer already set"
    return
  fi
  sudo sed -i 's/^[Aa]uthorizer:.*/authorizer: CassandraAuthorizer/' "$yaml"
  grep "^authorizer:" "$yaml"
  success "[CIS 2.2] Done. Cassandra restart required."
}

harden_section_2() {
  apply_2_1
  apply_2_2
}
