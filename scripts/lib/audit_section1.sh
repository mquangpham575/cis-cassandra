#!/usr/bin/env bash
# CIS Section 1: Installation and Updates audit checks

SECTION1="Installation and Updates"

check_1_1() {
  local evidence
  evidence=$(getent passwd cassandra 2>/dev/null; getent group cassandra 2>/dev/null)
  if getent passwd cassandra &>/dev/null && getent group cassandra &>/dev/null; then
    echo_check "1.1" "Ensure separate user and group exist for Cassandra" \
      "PASS" "manual" "$SECTION1" "$evidence"
  else
    echo_check "1.1" "Ensure separate user and group exist for Cassandra" \
      "NEEDS_REVIEW" "manual" "$SECTION1" "${evidence:-user/group not found}"
  fi
}

check_1_2() {
  local evidence
  evidence=$(java -version 2>&1 | head -1)
  if echo "$evidence" | grep -qE '"(1\.8|11|17)\.'; then
    echo_check "1.2" "Ensure the latest supported version of Java is installed" \
      "PASS" "automated" "$SECTION1" "$evidence"
  else
    echo_check "1.2" "Ensure the latest supported version of Java is installed" \
      "FAIL" "automated" "$SECTION1" "${evidence:-java not found}" "true"
  fi
}

check_1_3() {
  local evidence
  evidence=$(python3 --version 2>&1 || python --version 2>&1 || echo "not found")
  if echo "$evidence" | grep -qE 'Python 3\.(9|10|11|12)'; then
    echo_check "1.3" "Ensure the latest version of Python is installed" \
      "PASS" "automated" "$SECTION1" "$evidence"
  else
    echo_check "1.3" "Ensure the latest version of Python is installed" \
      "FAIL" "automated" "$SECTION1" "$evidence" "true"
  fi
}

check_1_4() {
  local evidence
  evidence=$(cassandra -v 2>/dev/null || echo "cassandra not found")
  if echo "$evidence" | grep -qE '^4\.'; then
    echo_check "1.4" "Ensure latest version of Cassandra is installed" \
      "PASS" "automated" "$SECTION1" "$evidence"
  else
    echo_check "1.4" "Ensure latest version of Cassandra is installed" \
      "FAIL" "automated" "$SECTION1" "$evidence" "true"
  fi
}

check_1_5() {
  local cass_pid proc_uid
  # Find PID of java process that looks like Cassandra
  cass_pid=$(pgrep -f "java.*cassandra" | head -1)
  
  if [ -n "$cass_pid" ]; then
    proc_uid=$(ps -o uid= -p "$cass_pid" | tr -d ' ')
    if [ "$proc_uid" = "0" ]; then
      echo_check "1.5" "Ensure Cassandra service is run as a non-root user" \
        "FAIL" "automated" "$SECTION1" "Running as root!" "true"
    else
      echo_check "1.5" "Ensure Cassandra service is run as a non-root user" \
        "PASS" "automated" "$SECTION1" "Running as UID: $proc_uid"
    fi
  else
    echo_check "1.5" "Ensure Cassandra service is run as a non-root user" \
      "FAIL" "automated" "$SECTION1" "Cassandra process not found" "true"
  fi
}

check_1_6() {
  local evidence
  evidence=$(timedatectl status 2>/dev/null | grep -E 'NTP|synchronized' | head -2 \
    || echo "NTP status unknown")
  if timedatectl status 2>/dev/null | grep -qi 'NTP service: active\|synchronized: yes'; then
    echo_check "1.6" "Ensure clocks are synchronized on all nodes" \
      "PASS" "manual" "$SECTION1" "$evidence"
  else
    echo_check "1.6" "Ensure clocks are synchronized on all nodes" \
      "NEEDS_REVIEW" "manual" "$SECTION1" "$evidence"
  fi
}

check_section_1() {
  check_1_1
  check_1_2
  check_1_3
  check_1_4
  check_1_5
  check_1_6
}
