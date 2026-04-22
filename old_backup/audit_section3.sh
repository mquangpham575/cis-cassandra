#!/usr/bin/env bash
# CIS Section 3: Access Control / Password Policies

SECTION3="Access Control and Password Policies"
_CQLSH_HOST="${CASSANDRA_HOST:-localhost}"
_CQLSH_USER="${CIS_ADMIN_USER:-cis_admin}"
_CQLSH_PASS="${CIS_ADMIN_PASS:-changeme}"

_cqlsh() {
  cqlsh "$_CQLSH_HOST" -u "$_CQLSH_USER" -p "$_CQLSH_PASS" \
    --connect-timeout=5 --request-timeout=10 "$@" 2>/dev/null
}

check_3_1() {
  local evidence superusers non_default_superuser
  evidence=$(_cqlsh -e \
    "SELECT role FROM system_auth.roles WHERE is_superuser=True ALLOW FILTERING;" \
    | grep -v "^$\|role\|---\|(0 rows)" || echo "cqlsh error")
  # PASS = at least one superuser role that is NOT 'cassandra' exists
  non_default_superuser=$(echo "$evidence" | grep -vi "cassandra\|cqlsh error" | grep -c '\S' || true)
  if [ "${non_default_superuser:-0}" -gt 0 ]; then
    echo_check "3.1" "Ensure cassandra and superuser roles are separate" \
      "PASS" "automated" "$SECTION3" "$evidence"
  else
    echo_check "3.1" "Ensure cassandra and superuser roles are separate" \
      "FAIL" "automated" "$SECTION3" "${evidence:-no separate superuser found}" "true"
  fi
}

check_3_2() {
  local evidence
  if cqlsh "$_CQLSH_HOST" -u cassandra -p cassandra \
      --connect-timeout=5 --request-timeout=10 \
      -e "DESC CLUSTER;" &>/dev/null; then
    evidence="Default password 'cassandra' still works"
    echo_check "3.2" "Ensure default password is changed for cassandra role" \
      "FAIL" "automated" "$SECTION3" "$evidence" "true"
  else
    evidence="Default password rejected - password has been changed"
    echo_check "3.2" "Ensure default password is changed for cassandra role" \
      "PASS" "automated" "$SECTION3" "$evidence"
  fi
}

check_3_3() {
  local evidence
  evidence=$(_cqlsh -e "LIST ROLES;" 2>/dev/null \
    | grep -v "^$\|role\|---" || echo "cqlsh error")
  echo_check "3.3" "Ensure no unnecessary roles or excessive privileges" \
    "NEEDS_REVIEW" "manual" "$SECTION3" "$evidence"
}

check_3_4() {
  local cass_pid cass_uid proc_uid
  cass_uid=$(id -u cassandra 2>/dev/null || echo "notfound")
  cass_pid=$(pgrep -f "java.*cassandra" | head -1)

  if [ -n "$cass_pid" ]; then
    proc_uid=$(ps -o uid= -p "$cass_pid" | tr -d ' ')
    if [ "$proc_uid" = "$cass_uid" ]; then
      echo_check "3.4" "Ensure Cassandra runs as non-privileged dedicated account" \
        "PASS" "automated" "$SECTION3" "Running as matching UID: $proc_uid"
    else
      echo_check "3.4" "Ensure Cassandra runs as non-privileged dedicated account" \
        "FAIL" "automated" "$SECTION3" "Cassandra NOT running as 'cassandra' user (UID: $proc_uid)" "true"
    fi
  else
    echo_check "3.4" "Ensure Cassandra runs as non-privileged dedicated account" \
      "FAIL" "automated" "$SECTION3" "Cassandra process not found" "true"
  fi
}

check_3_5() {
  local evidence
  evidence=$(grep -E "^listen_address:|^rpc_address:" \
    "${CASSANDRA_YAML:-/etc/cassandra/cassandra.yaml}" 2>/dev/null || echo "not found")
  echo_check "3.5" "Ensure Cassandra only listens on authorized interfaces" \
    "NEEDS_REVIEW" "manual" "$SECTION3" "$evidence"
}

check_3_6() {
  local evidence
  evidence=$(grep -i "network_authorizer:" \
    "${CASSANDRA_YAML:-/etc/cassandra/cassandra.yaml}" 2>/dev/null || echo "not configured")
  if echo "$evidence" | grep -qi "CassandraNetworkAuthorizer"; then
    echo_check "3.6" "Ensure Data Center Authorizations is activated" \
      "PASS" "manual" "$SECTION3" "$evidence"
  else
    echo_check "3.6" "Ensure Data Center Authorizations is activated" \
      "NEEDS_REVIEW" "manual" "$SECTION3" "$evidence"
  fi
}

check_3_7() {
  local evidence
  evidence=$(_cqlsh -e "LIST ROLES;" 2>/dev/null \
    | grep -v "^$\|name\|---" || echo "cqlsh error")
  echo_check "3.7" "Review User-Defined Roles" \
    "NEEDS_REVIEW" "manual" "$SECTION3" "$evidence"
}

check_3_8() {
  local evidence
  evidence=$(_cqlsh -e \
    "SELECT role,is_superuser FROM system_auth.roles ALLOW FILTERING;" \
    2>/dev/null | grep "True" || echo "cqlsh error")
  echo_check "3.8" "Review Superuser and Admin Roles" \
    "NEEDS_REVIEW" "manual" "$SECTION3" "$evidence"
}

check_section_3() {
  check_3_1; check_3_2; check_3_3; check_3_4
  check_3_5; check_3_6; check_3_7; check_3_8
}
