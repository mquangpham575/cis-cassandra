#!/usr/bin/env bash
# CIS Section 5: Encryption

SECTION5="Encryption"

check_5_1() {
  local evidence yaml="${CASSANDRA_YAML:-/etc/cassandra/cassandra.yaml}"
  # internode_encryption is nested under server_encryption_options in C* 4.0
  evidence=$(grep -A10 -i "server_encryption_options:" "$yaml" 2>/dev/null \
    | grep -i "internode_encryption" | head -1 \
    || grep -i "^internode_encryption:" "$yaml" 2>/dev/null \
    || echo "internode_encryption: not found")
  if echo "$evidence" | grep -qiE "internode_encryption\s*:\s*(all|dc|rack)"; then
    echo_check "5.1" "Ensure inter-node encryption is enabled" \
      "PASS" "automated" "$SECTION5" "$evidence"
  else
    echo_check "5.1" "Ensure inter-node encryption is enabled" \
      "FAIL" "automated" "$SECTION5" "$evidence" "true"
  fi
}

check_5_2() {
  local evidence
  evidence=$(grep -A7 -i "client_encryption_options:" \
    "${CASSANDRA_YAML:-/etc/cassandra/cassandra.yaml}" 2>/dev/null | head -5 \
    || echo "not found")
  if echo "$evidence" | grep -qi "enabled: true"; then
    echo_check "5.2" "Ensure client-to-node encryption is enabled" \
      "PASS" "automated" "$SECTION5" "$evidence"
  else
    echo_check "5.2" "Ensure client-to-node encryption is enabled" \
      "FAIL" "automated" "$SECTION5" "$evidence" "true"
  fi
}

check_section_5() {
  check_5_1
  check_5_2
}
