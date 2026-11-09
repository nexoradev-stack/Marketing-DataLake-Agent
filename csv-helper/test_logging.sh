#!/usr/bin/env bash
# Runs a small export exactly like the agent does, then shows the new log rows.
# Checks: generation_log row, delivered_records rows (25), and an admin email.
#   bash test_logging.sh
set -euo pipefail

PROJECT_ID="your-gcp-project-id"
BUCKET="${PROJECT_ID}-prospect-exports"
RUN_ID="$(date -u +%Y%m%d%H%M%S)_$(head -c 3 /dev/urandom | od -An -tx1 | tr -d ' \n')"
SLUG="Logging_Test_Event"

echo "==> Exporting 25 test rows (run id ${RUN_ID})"
bq query --location=US --use_legacy_sql=false >/dev/null <<SQL
-- META | event=Logging Test Event | solution=Agentic AI | industry=Any | titles=CMO | location=Any, Any, United States | requested=25
EXPORT DATA OPTIONS(
  uri='gs://${BUCKET}/exports/${RUN_ID}/${SLUG}_*.csv',
  format='CSV', overwrite=false, header=true
) AS
SELECT Company_Name AS \`Company Name\`, Email_ID AS \`Email ID\`, Job_Title AS \`Job Title\`
FROM \`${PROJECT_ID}.raw_marketing_vendor_database.v_prospects_clean\`
WHERE REGEXP_CONTAINS(LOWER(Job_Title), r'\b(cmo|chief marketing officer)\b')
LIMIT 25
SQL

echo "==> Waiting 45 seconds for the helper to log and email"
sleep 45

echo "==> Latest generation log rows:"
bq query --location=US --use_legacy_sql=false --format=pretty "
SELECT FORMAT_TIMESTAMP('%d %b %Y %I:%M %p', generated_at, 'Asia/Kolkata') AS time_ist,
       user_email, event_name, solution, requested_count, delivered_count, file_name
FROM \`${PROJECT_ID}.prospect_agent_logs.generation_log\`
ORDER BY generated_at DESC
LIMIT 5"

echo "==> Delivery log for this test (should show 25 emails):"
bq query --location=US --use_legacy_sql=false --format=pretty "
SELECT user_email, event_name, event_key, COUNT(*) AS emails_saved
FROM \`${PROJECT_ID}.prospect_agent_logs.delivered_records\`
WHERE gcs_uri LIKE '%/${RUN_ID}/%'
GROUP BY user_email, event_name, event_key"

echo ""
echo "Now check your inbox for: Prospect Database Generated — ... — 25 records"
