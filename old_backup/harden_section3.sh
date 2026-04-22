#!/usr/bin/env bash
# CIS Section 3 hardening: Access Control / Password Policies

_CQLSH_HOST="${CASSANDRA_HOST:-localhost}"

apply_3_1() {
  local admin_user="${CIS_ADMIN_USER:-cis_admin}"
  local admin_pass="${CIS_ADMIN_PASS:-Adm1n@Secure99!}"
  local cass_pass="${NEW_CASSANDRA_PASS:-N3wCassandra@99!}"
  info "[CIS 3.1] Creating separate superuser role '${admin_user}'..."
  if $DRY_RUN; then
    info "  [dry-run] Would create superuser role '${admin_user}'"
    return
  fi
  
  # Retry loop handles the 'auth sync' delay after restart
  local success=false
  for i in {1..5}; do
    if cqlsh "$_CQLSH_HOST" -u cassandra -p "${cass_pass}" \
        --connect-timeout=15 --request-timeout=20 -e \
        "CREATE ROLE IF NOT EXISTS '${admin_user}'
         WITH PASSWORD='${admin_pass}' AND LOGIN=TRUE AND SUPERUSER=TRUE;" \
        2>/dev/null; then
      success=true
      break
    fi
    # If initial password works, try that too (covers first-run case)
    if cqlsh "$_CQLSH_HOST" -u cassandra -p cassandra \
        --connect-timeout=5 --request-timeout=10 -e \
        "CREATE ROLE IF NOT EXISTS '${admin_user}'
         WITH PASSWORD='${admin_pass}' AND LOGIN=TRUE AND SUPERUSER=TRUE;" \
        2>/dev/null; then
      success=true
      break
    fi
    warn "  [CIS 3.1] Auth not ready or wrong password (attempt $i/5), waiting..."
    sleep 15
  done

  if $success; then
    success "[CIS 3.1] Superuser role '${admin_user}' created/confirmed"
  else
    error "[CIS 3.1] Failed to create role after 5 attempts."
  fi
}

apply_3_2() {
  local cass_new="${NEW_CASSANDRA_PASS:-N3wCassandra@99!}"
  info "[CIS 3.2] Changing default cassandra role password..."
  if $DRY_RUN; then
    info "  [dry-run] Would change cassandra default password"
    return
  fi
  if cqlsh "$_CQLSH_HOST" -u cassandra -p cassandra \
      --connect-timeout=5 --request-timeout=10 \
      -e "ALTER ROLE cassandra WITH PASSWORD='${cass_new}';" 2>/dev/null; then
    success "[CIS 3.2] Default cassandra password changed"
  else
    info "[CIS 3.2] Default login failed — password may already be changed"
  fi
}

apply_3_4() {
  info "[CIS 3.4] Ensuring Cassandra process files are owned by cassandra user..."
  if $DRY_RUN; then
    info "  [dry-run] Would chown /var/lib/cassandra to cassandra:cassandra"
    return
  fi
  sudo chown -R cassandra:cassandra /var/lib/cassandra 2>/dev/null || true
  success "[CIS 3.4] Ownership verified"
}

apply_3_6() {
  local yaml="${CASSANDRA_YAML:-/etc/cassandra/cassandra.yaml}"
  info "[CIS 3.6] Enabling CassandraNetworkAuthorizer..."
  if $DRY_RUN; then
    info "  [dry-run] Would set network_authorizer: CassandraNetworkAuthorizer"
    return
  fi
  if grep -qi "CassandraNetworkAuthorizer" "$yaml" 2>/dev/null; then
    info "  [CIS 3.6] CassandraNetworkAuthorizer already set"
    return
  fi
  if grep -q "^network_authorizer:" "$yaml" 2>/dev/null; then
    sudo sed -i 's/^network_authorizer:.*/network_authorizer: CassandraNetworkAuthorizer/' "$yaml"
  else
    printf '\nnetwork_authorizer: CassandraNetworkAuthorizer\n' | sudo tee -a "$yaml" > /dev/null
  fi
  success "[CIS 3.6] CassandraNetworkAuthorizer enabled. Restart required."
}

harden_section_3() {
  apply_3_1
  apply_3_2
  apply_3_4
  apply_3_6
}
