#!/usr/bin/env bash
# Demo 1: Compliance Baseline Audit
# Scans a mock system, identifies common vulnerabilities.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
export PATH="$DIR/demo/bin:$PATH"
export CIS_MOCK=1
export CASSANDRA_YAML="$DIR/demo/assets/cassandra_vulnerable.yaml"

# Cleanup mock state
rm -f /tmp/mock_cassandra_user_exists /tmp/mock_cassandra_group_exists

echo "--------------------------------------------------"
echo "DEMO 1: Starting Compliance Baseline Audit"
echo "Targeting Mock Vulnerable Config..."
echo "--------------------------------------------------"

# Run audit for Section 1 only to keep it simple
bash "$DIR/cis-tool.sh" --audit --section 1

echo ""
echo "Demo 1 Finished. Notice the FAIL results for User/Group existence."
