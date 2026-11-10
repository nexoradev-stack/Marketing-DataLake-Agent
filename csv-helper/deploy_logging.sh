#!/usr/bin/env bash
# Deploys the prospect-csv-rename helper: rename + delivery log + generation log + admin email.
# Run from Cloud Shell inside the folder with index.js and package.json:
#   bash deploy_logging.sh "<APPS_SCRIPT_WEB_APP_URL>" "<SECRET>"
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: bash deploy_logging.sh \"<APPS_SCRIPT_WEB_APP_URL>\" \"<SECRET>\""
  exit 1
fi
MAIL_WEBHOOK_URL="$1"
MAIL_SECRET="$2"

PROJECT_ID="your-gcp-project-id"
REGION="us-central1"
BUCKET="${PROJECT_ID}-prospect-exports"
FUNCTION="prospect-csv-rename"
RUNTIME_SA="YOUR_PROJECT_NUMBER-compute@developer.gserviceaccount.com"
DATASET="prospect_agent_logs"
TABLE="generation_log"
DELIVERED="delivered_records"
ADMIN_EMAILS="admin-one@example.com,admin-two@example.com"

echo "==> 1/5 Creating log dataset and generation log table (skipped if they exist)"
if ! bq --location=US show --dataset "${PROJECT_ID}:${DATASET}" >/dev/null 2>&1; then
  bq --location=US mk --dataset \
    --description "Admin logs for the Marketing Database Agent" \
    "${PROJECT_ID}:${DATASET}"
fi
if ! bq show "${PROJECT_ID}:${DATASET}.${TABLE}" >/dev/null 2>&1; then
  bq mk --table \
    --description "One row per prospect CSV generated" \
    --time_partitioning_field generated_at \
    --time_partitioning_type MONTH \
    "${PROJECT_ID}:${DATASET}.${TABLE}" \
    generated_at:TIMESTAMP,user_email:STRING,user_name:STRING,event_name:STRING,solution:STRING,job_titles:STRING,location:STRING,requested_count:INTEGER,delivered_count:INTEGER,file_name:STRING,gcs_uri:STRING,bq_job_id:STRING
fi

echo "==> 2/5 Creating the delivery log table (skipped if it exists)"
bq query --project_id="${PROJECT_ID}" --location=US --use_legacy_sql=false <<SQL
CREATE TABLE IF NOT EXISTS \`${PROJECT_ID}.${DATASET}.${DELIVERED}\` (
  delivered_at TIMESTAMP,   -- when the export happened
  user_email   STRING,      -- who received the prospect
  event_name   STRING,      -- event name as the user typed it
  event_key    STRING,      -- event name lowercased, letters and digits only
  email        STRING,      -- the prospect's email
  gcs_uri      STRING,      -- the CSV file it came from
  bq_job_id    STRING       -- links to generation_log
)
PARTITION BY DATE(delivered_at)
CLUSTER BY user_email, event_key
OPTIONS (description = 'One row per prospect delivered. Used so the same user never gets the same prospect twice for the same event.');
SQL

echo "==> 3/5 Allowing the helper to see who ran each export"
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${RUNTIME_SA}" \
  --role="roles/bigquery.resourceViewer" \
  --condition=None >/dev/null

echo "==> 4/5 Deploying the helper (2-4 minutes)"
cat > env.yaml <<EOF
PROJECT_ID: "${PROJECT_ID}"
BQ_LOCATION: "US"
LOG_TABLE: "${PROJECT_ID}.${DATASET}.${TABLE}"
DELIVERED_TABLE: "${PROJECT_ID}.${DATASET}.${DELIVERED}"
ADMIN_EMAILS: "${ADMIN_EMAILS}"
MAIL_WEBHOOK_URL: "${MAIL_WEBHOOK_URL}"
MAIL_SECRET: "${MAIL_SECRET}"
EOF
gcloud functions deploy "${FUNCTION}" \
  --gen2 \
  --region="${REGION}" \
  --runtime=nodejs22 \
  --source=. \
  --entry-point=setDownloadName \
  --trigger-bucket="${BUCKET}" \
  --service-account="${RUNTIME_SA}" \
  --trigger-service-account="${RUNTIME_SA}" \
  --memory=512Mi \
  --timeout=120s \
  --max-instances=5 \
  --env-vars-file=env.yaml

echo "==> 5/5 Allowing the trigger to call the helper"
gcloud functions add-invoker-policy-binding "${FUNCTION}" \
  --region="${REGION}" \
  --member="serviceAccount:${RUNTIME_SA}" >/dev/null

echo ""
echo "DONE: rename + delivery log + generation log + email helper deployed"
echo ""
echo "Updating code only (keeps all existing settings):"
echo "  gcloud functions deploy ${FUNCTION} --gen2 --region=${REGION} --runtime=nodejs22 --source=. --entry-point=setDownloadName"
