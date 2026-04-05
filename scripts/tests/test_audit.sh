#!/usr/bin/env bash
# test_audit.sh — Unit tests for CIS audit functions
# Run: bash scripts/tests/test_audit.sh
# No Cassandra required — uses mocked environment files

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

# ─────────────────────────────────────────────
# Test framework (tiny, no deps)
# ─────────────────────────────────────────────
PASS_COUNT=0
FAIL_COUNT=0

_assert() {
  local name="$1" condition="$2"
  if eval "$condition"; then
    printf "  ✅ PASS: %s\n" "$name"
    PASS_COUNT=$(( PASS_COUNT + 1 ))
  else
    printf "  ❌ FAIL: %s\n" "$name"
    FAIL_COUNT=$(( FAIL_COUNT + 1 ))
  fi
}

_test() {
  printf "\n▶  %s\n" "$1"
}

# ─────────────────────────────────────────────
# Setup: mock environment
# ─────────────────────────────────────────────
TMPDIR_TEST=$(mktemp -d)
trap "rm -rf '$TMPDIR_TEST'" EXIT

# Create a mock cassandra.yaml with INSECURE defaults (pre-hardening state)
MOCK_YAML="$TMPDIR_TEST/cassandra.yaml"
cat > "$MOCK_YAML" << 'YAML'
cluster_name: 'Test Cluster'
authenticator: AllowAllAuthenticator
authorizer: AllowAllAuthorizer
network_authorizer: AllowAllNetworkAuthorizer
listen_address: localhost
rpc_address: localhost
server_encryption_options:
    internode_encryption: none
    keystore: conf/.keystore
    keystore_password: cassandra
    truststore: conf/.truststore
    truststore_password: cassandra
client_encryption_options:
    enabled: false
    keystore: conf/.keystore
    keystore_password: cassandra
audit_logging_options:
    enabled: false
    logger:
      - class_name: BinAuditLogger
YAML
export CASSANDRA_YAML="$MOCK_YAML"

# Create a mock logback.xml with active appender-ref
MOCK_LOGBACK="$TMPDIR_TEST/logback.xml"
cat > "$MOCK_LOGBACK" << 'XML'
<configuration>
  <appender name="FILE" class="ch.qos.logback.core.rolling.RollingFileAppender">
    <file>${cassandra.logdir}/system.log</file>
  </appender>
  <root level="INFO">
    <appender-ref ref="FILE" />
  </root>
</configuration>
XML
export LOGBACK_XML="$MOCK_LOGBACK"

# ─────────────────────────────────────────────
# Test 1: echo_check JSON validity
# ─────────────────────────────────────────────
_test "echo_check — JSON structure"

OUT=$(echo_check "2.1" "Test check" "PASS" "automated" "Section" "some evidence")
_assert "6-arg output is valid JSON" "echo '$OUT' | python3 -m json.tool > /dev/null 2>&1"
_assert "contains 'id' field"        "echo '$OUT' | grep -q '\"id\"'"
_assert "contains 'status' field"    "echo '$OUT' | grep -q '\"status\"'"
_assert "contains 'type' field"      "echo '$OUT' | grep -q '\"type\"'"
_assert "contains 'remediable' field" "echo '$OUT' | grep -q '\"remediable\"'"
_assert "remediable defaults to false" "echo '$OUT' | grep -q '\"remediable\":false'"

OUT7=$(echo_check "2.1" "Test check" "FAIL" "automated" "Section" "evidence" "true")
_assert "7-arg output is valid JSON" "echo '$OUT7' | python3 -m json.tool > /dev/null 2>&1"
_assert "7th arg sets remediable=true" "echo '$OUT7' | grep -q '\"remediable\":true'"

OUT_SPECIAL=$(echo_check "1.1" "Test" "PASS" "manual" "S" 'evidence with "quotes" and \backslash')
_assert "special chars in evidence produce valid JSON" \
  "echo '$OUT_SPECIAL' | python3 -m json.tool > /dev/null 2>&1"

# ─────────────────────────────────────────────
# Test 2: build_report JSON validity
# ─────────────────────────────────────────────
_test "build_report — JSON structure"

CHECKS_FILE="$TMPDIR_TEST/checks.jsonl"
echo_check "2.1" "Auth enabled" "PASS" "automated" "Auth" "PasswordAuthenticator" > "$CHECKS_FILE"
echo_check "2.2" "Authz enabled" "FAIL" "automated" "Auth" "AllowAllAuthorizer" "true" >> "$CHECKS_FILE"
echo_check "5.1" "Internode TLS" "FAIL" "automated" "Enc" "internode_encryption: none" "true" >> "$CHECKS_FILE"

REPORT=$(build_report "192.168.56.11" "$CHECKS_FILE")
_assert "build_report output is valid JSON" \
  "echo '$REPORT' | python3 -m json.tool > /dev/null 2>&1"
_assert "report contains 'node' field" \
  "echo '$REPORT' | python3 -c \"import sys,json; d=json.load(sys.stdin); assert 'node' in d\" 2>/dev/null"
_assert "report contains 'score.total'" \
  "echo '$REPORT' | python3 -c \"import sys,json; d=json.load(sys.stdin); assert d['score']['total'] == 3\" 2>/dev/null"
_assert "report contains 'checks' array" \
  "echo '$REPORT' | python3 -c \"import sys,json; d=json.load(sys.stdin); assert len(d['checks']) == 3\" 2>/dev/null"
_assert "passed count is correct (1)" \
  "echo '$REPORT' | python3 -c \"import sys,json; d=json.load(sys.stdin); assert d['score']['passed'] == 1\" 2>/dev/null"
_assert "failed count is correct (2)" \
  "echo '$REPORT' | python3 -c \"import sys,json; d=json.load(sys.stdin); assert d['score']['failed'] == 2\" 2>/dev/null"
_assert "automated count derived from type field" \
  "echo '$REPORT' | python3 -c \"import sys,json; d=json.load(sys.stdin); assert d['score']['automated'] == 3\" 2>/dev/null"

# ─────────────────────────────────────────────
# Test 3: Section 2 audit — FAIL on insecure YAML
# ─────────────────────────────────────────────
_test "audit_section2 — FAIL on insecure cassandra.yaml (AllowAll*)"
source "$SCRIPT_DIR/../lib/audit_section2.sh"

OUT_2_1=$(check_2_1)
OUT_2_2=$(check_2_2)
_assert "check_2_1 output is valid JSON" \
  "echo '$OUT_2_1' | python3 -m json.tool > /dev/null 2>&1"
_assert "check_2_1 status=FAIL for AllowAllAuthenticator" \
  "echo '$OUT_2_1' | grep -q '\"status\":\"FAIL\"'"
_assert "check_2_2 status=FAIL for AllowAllAuthorizer" \
  "echo '$OUT_2_2' | grep -q '\"status\":\"FAIL\"'"
_assert "check_2_1 remediable=true" \
  "echo '$OUT_2_1' | grep -q '\"remediable\":true'"

# ─────────────────────────────────────────────
# Test 4: Section 2 audit — PASS on hardened YAML
# ─────────────────────────────────────────────
_test "audit_section2 — PASS on hardened cassandra.yaml"
MOCK_YAML_HARDENED="$TMPDIR_TEST/cassandra_hardened.yaml"
sed 's/AllowAllAuthenticator/PasswordAuthenticator/;s/AllowAllAuthorizer/CassandraAuthorizer/' \
  "$MOCK_YAML" > "$MOCK_YAML_HARDENED"
CASSANDRA_YAML="$MOCK_YAML_HARDENED" OUT_H_2_1=$(check_2_1)
CASSANDRA_YAML="$MOCK_YAML_HARDENED" OUT_H_2_2=$(check_2_2)
_assert "check_2_1 status=PASS for PasswordAuthenticator" \
  "echo '$OUT_H_2_1' | grep -q '\"status\":\"PASS\"'"
_assert "check_2_2 status=PASS for CassandraAuthorizer" \
  "echo '$OUT_H_2_2' | grep -q '\"status\":\"PASS\"'"

# ─────────────────────────────────────────────
# Test 5: Section 4 audit
# ─────────────────────────────────────────────
_test "audit_section4 — logging/audit checks"
source "$SCRIPT_DIR/../lib/audit_section4.sh"

OUT_4_1=$(check_4_1)
OUT_4_2=$(check_4_2)
_assert "check_4_1 output is valid JSON" \
  "echo '$OUT_4_1' | python3 -m json.tool > /dev/null 2>&1"
_assert "check_4_1 status=PASS (logback has active appender-ref)" \
  "echo '$OUT_4_1' | grep -q '\"status\":\"PASS\"'"
_assert "check_4_2 status=NEEDS_REVIEW (audit logging enabled: false)" \
  "echo '$OUT_4_2' | grep -q '\"status\":\"NEEDS_REVIEW\"'"

# ─────────────────────────────────────────────
# Test 6: Section 5 audit — FAIL on insecure YAML
# ─────────────────────────────────────────────
_test "audit_section5 — FAIL on insecure encryption config"
source "$SCRIPT_DIR/../lib/audit_section5.sh"

OUT_5_1=$(check_5_1)
OUT_5_2=$(check_5_2)
_assert "check_5_1 output is valid JSON" \
  "echo '$OUT_5_1' | python3 -m json.tool > /dev/null 2>&1"
_assert "check_5_1 status=FAIL for internode_encryption: none" \
  "echo '$OUT_5_1' | grep -q '\"status\":\"FAIL\"'"
_assert "check_5_2 status=FAIL for client encryption enabled: false" \
  "echo '$OUT_5_2' | grep -q '\"status\":\"FAIL\"'"

# ─────────────────────────────────────────────
# Test 7: Full audit pipeline via cis-tool.sh
# ─────────────────────────────────────────────
_test "cis-tool.sh audit 2 — full pipeline produces valid JSON"

FULL_REPORT=$(CASSANDRA_YAML="$MOCK_YAML" bash "$SCRIPT_DIR/../cis-tool.sh" audit 2 2>/dev/null)
_assert "cis-tool audit 2 output is valid JSON" \
  "echo '$FULL_REPORT' | python3 -m json.tool > /dev/null 2>&1"
_assert "cis-tool audit 2 contains node field" \
  "echo '$FULL_REPORT' | python3 -c \"import sys,json; d=json.load(sys.stdin); assert 'node' in d\" 2>/dev/null"
_assert "cis-tool audit 2 has 2 checks" \
  "echo '$FULL_REPORT' | python3 -c \"import sys,json; d=json.load(sys.stdin); assert len(d['checks']) == 2\" 2>/dev/null"

# ─────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════"
echo "  Test Results: ${PASS_COUNT} passed, ${FAIL_COUNT} failed"
TOTAL=$(( PASS_COUNT + FAIL_COUNT ))
SCORE=$(( PASS_COUNT * 100 / TOTAL ))
echo "  Score: ${SCORE}%  (${PASS_COUNT}/${TOTAL})"
echo "══════════════════════════════════════════"
if [ "$FAIL_COUNT" -eq 0 ]; then
  success "All tests passed!"
  exit 0
else
  error "${FAIL_COUNT} test(s) failed"
  exit 1
fi
