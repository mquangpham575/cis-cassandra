#!/usr/bin/env bash
# Demo 3: Analytics & Reporting
# Aggregates results into JSON and CSV formats.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
export CIS_MOCK=1
source "$DIR/scripts/lib/common.sh"

MOCK_RESULTS="/tmp/demo_results.json"

cat <<EOF > "$MOCK_RESULTS"
{"check_id":"1.1","title":"Separate user/group","status":"PASS","severity":"MEDIUM","current_value":"cassandra exists","expected_value":"cassandra:cassandra","remediation":"","section":"1 Installation","node":"192.168.1.100","timestamp":"2024-05-16T12:00:00Z"}
{"check_id":"2.1","title":"Insecure Authenticator","status":"FAIL","severity":"CRITICAL","current_value":"AllowAllAuthenticator","expected_value":"PasswordAuthenticator","remediation":"Enable PasswordAuthenticator","section":"2 Auth","node":"192.168.1.100","timestamp":"2024-05-16T12:00:01Z"}
EOF

echo "--------------------------------------------------"
echo "DEMO 3: Generating Analytics Reports"
echo "--------------------------------------------------"

echo ">>> Generating JSON Report..."
build_report "192.168.1.100" "$MOCK_RESULTS" > "$DIR/demo/reports/final_report.json"
echo "Report saved to demo/reports/final_report.json"
head -n 10 "$DIR/demo/reports/final_report.json"

echo -e "\n>>> Generating CSV Report..."
build_csv_report "$MOCK_RESULTS" > "$DIR/demo/reports/final_report.csv"
echo "Report saved to demo/reports/final_report.csv"
cat "$DIR/demo/reports/final_report.csv"

echo "--------------------------------------------------"
echo "Demo 3 Finished."
