#!/usr/bin/env bash
# CIS Section 2: Authentication and Authorization

SECTION2="Authentication and Authorization"

check_2_1() {
  local evidence
  evidence=$(grep -i "^authenticator:" "${CASSANDRA_YAML:-/etc/cassandra/cassandra.yaml}" 2>/dev/null \
    || echo "not found")
  if echo "$evidence" | grep -qi "PasswordAuthenticator"; then
    echo_check "2.1" "Ensure authentication is enabled" \
      "PASS" "automated" "$SECTION2" "$evidence"
  else
    echo_check "2.1" "Ensure authentication is enabled" \
      "FAIL" "automated" "$SECTION2" "$evidence" "true"
  fi
}

check_2_2() {
  local evidence
  evidence=$(grep -i "^authorizer:" "${CASSANDRA_YAML:-/etc/cassandra/cassandra.yaml}" 2>/dev/null \
    || echo "not found")
  if echo "$evidence" | grep -qi "CassandraAuthorizer"; then
    echo_check "2.2" "Ensure authorization is enabled" \
      "PASS" "automated" "$SECTION2" "$evidence"
  else
    echo_check "2.2" "Ensure authorization is enabled" \
      "FAIL" "automated" "$SECTION2" "$evidence" "true"
  fi
}

check_section_2() {
  check_2_1
  check_2_2
}
