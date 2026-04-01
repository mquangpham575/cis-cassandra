#!/usr/bin/env bash
# CIS Section 4: Auditing and Logging

SECTION4="Auditing and Logging"

check_4_1() {
  local evidence logback="${LOGBACK_XML:-/etc/cassandra/logback.xml}"
  evidence=$(grep -v '<!--' "$logback" 2>/dev/null | grep -E "appender|root level" | head -3 \
    || echo "logback.xml not found")
  if [ -f "$logback" ] && grep -v '<!--' "$logback" 2>/dev/null | grep -qi "appender-ref"; then
    echo_check "4.1" "Ensure that logging is enabled" \
      "PASS" "automated" "$SECTION4" "$evidence"
  else
    echo_check "4.1" "Ensure that logging is enabled" \
      "FAIL" "automated" "$SECTION4" "$evidence" "true"
  fi
}

check_4_2() {
  local evidence
  evidence=$(grep -A10 "audit_logging_options:" \
    "${CASSANDRA_YAML:-/etc/cassandra/cassandra.yaml}" 2>/dev/null || echo "not found")
  if echo "$evidence" | grep -qi "enabled: true"; then
    echo_check "4.2" "Ensure that auditing is enabled" \
      "PASS" "manual" "$SECTION4" "$evidence"
  else
    echo_check "4.2" "Ensure that auditing is enabled" \
      "NEEDS_REVIEW" "manual" "$SECTION4" "$evidence"
  fi
}

check_section_4() {
  check_4_1
  check_4_2
}
