#!/usr/bin/env bash
# Demo 2: "Fix-it-Fast" Hardening
# Applies --harden and verifies the transition from FAIL to PASS.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
export PATH="$DIR/demo/bin:$PATH"
export CIS_MOCK=1
export CASSANDRA_YAML="$DIR/demo/assets/cassandra_vulnerable.yaml"

# Ensure we start with no users (FAIL state)
rm -f /tmp/mock_cassandra_user_exists /tmp/mock_cassandra_group_exists

echo "--------------------------------------------------"
echo "DEMO 2: Starting Hardening Demonstration"
echo "Phase 1: Initial Audit (Expecting FAIL)"
echo "--------------------------------------------------"
bash "$DIR/cis-tool.sh" --audit --section 1 > /dev/null

echo "Phase 2: Applying Hardening..."
bash "$DIR/cis-tool.sh" --harden --section 1

echo "Phase 3: Final Audit (Expecting PASS)"
bash "$DIR/cis-tool.sh" --audit --section 1

echo ""
echo "Demo 2 Finished. Notice how the status changed to PASS."
