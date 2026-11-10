#!/usr/bin/env bash
# Sets up the prospect views, the unmailable block list and the hourly refresh.
#
# Result:
#   raw_marketing_vendor_database   <- your source tables (Marketing_Database_0001, 0002, ... any future ones)
#     v_prospects_clean             <- what the agent reads = all prospects MINUS unmailable
#     refresh_prospect_view()       <- procedure, run every hour
#   Unmailable_Records
#     unmailable_records            <- block list (filled by the Salesforce sync)
#     v_prospects_all               <- every source table, cleaned and de-duplicated (rebuilt hourly)
#     v_unmailable_matches          <- report: prospects that are blocked, and why
#
# Safe to re-run. Does NOT delete data in unmailable_records.
# Run from Cloud Shell:
#   bash setup_auto_view.sh
set -euo pipefail

P="your-gcp-project-id"
D="raw_marketing_vendor_database"
U="Unmailable_Records"
PROJECT_NUMBER="YOUR_PROJECT_NUMBER"
RUNTIME_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

echo "==> 1/6 Creating the ${U} dataset and the block list table (skipped if they exist)"
if ! bq --location=US show --dataset "${P}:${U}" >/dev/null 2>&1; then
  bq --location=US mk --dataset \
    --description "Salesforce unmailable contacts and the views built on them" \
    "${P}:${U}"
fi
bq query --project_id="${P}" --location=US --use_legacy_sql=false <<SQL
CREATE TABLE IF NOT EXISTS \`${P}.${U}.unmailable_records\` (
  email          STRING NOT NULL,   -- lowercased, trimmed
  opted_out      BOOL,
  do_not_email   BOOL,
  hard_bounce    BOOL,
  soft_bounce    BOOL,
  crm_contact_id STRING,
  source         STRING,            -- e.g. 'account_engagement_api'
  loaded_at      TIMESTAMP
)
OPTIONS (description = 'Contacts that must never be exported: opted out, do not email, hard bounce or soft bounce.');
SQL

echo "==> 2/6 Creating the refresh procedure"
bq query --project_id="${P}" --location=US --use_legacy_sql=false <<SQL
CREATE OR REPLACE PROCEDURE \`${P}.${D}.refresh_prospect_view\`()
BEGIN
  DECLARE union_sql STRING;
  DECLARE table_count INT64;

  -- Every base table in the source dataset that has an Email and a Company column.
  -- Missing optional columns are filled with NULL, so new tables never break the view.
  SET (union_sql, table_count) = (
    WITH cols AS (
      SELECT table_name, ARRAY_AGG(LOWER(column_name)) AS lnames
      FROM \`${P}.${D}\`.INFORMATION_SCHEMA.COLUMNS
      GROUP BY table_name
    ),
    tbls AS (
      SELECT t.table_name, c.lnames
      FROM \`${P}.${D}\`.INFORMATION_SCHEMA.TABLES AS t
      JOIN cols AS c USING (table_name)
      WHERE t.table_type = 'BASE TABLE'
        AND 'email' IN UNNEST(c.lnames)
        AND 'company' IN UNNEST(c.lnames)
    ),
    per_table AS (
      SELECT
        t.table_name,
        (
          SELECT STRING_AGG(
            IF(LOWER(col) IN UNNEST(t.lnames),
               FORMAT('CAST(\`%s\` AS STRING) AS %s', col, col),
               FORMAT('CAST(NULL AS STRING) AS %s', col)),
            ', ' ORDER BY pos)
          FROM UNNEST([
            'Company', 'Website', 'First_Name', 'Last_Name', 'Job_Title', 'Email', 'Industry',
            'Prospect_Linkedin', 'City', 'Person_City', 'Company_City', 'State', 'Person_State',
            'Company_State', 'Country', 'Person_Country', 'Company_Country', 'Do_Not_Email', 'Opted_Out'
          ]) AS col WITH OFFSET AS pos
        ) AS sel
      FROM tbls AS t
    )
    SELECT AS STRUCT
      STRING_AGG(
        FORMAT("SELECT %s, '%s' AS Source_Table FROM \`${P}.${D}.%s\`", sel, table_name, table_name),
        '\nUNION ALL\n' ORDER BY table_name),
      COUNT(*)
    FROM per_table
  );

  IF table_count = 0 OR union_sql IS NULL THEN
    RAISE USING MESSAGE = 'No prospect tables (with Email and Company columns) found in the dataset.';
  END IF;

  -- Rebuilds ONLY v_prospects_all. v_prospects_clean (with the unmailable filter) is never touched.
  EXECUTE IMMEDIATE CONCAT(
    'CREATE OR REPLACE VIEW \`${P}.${U}.v_prospects_all\` AS WITH src AS (', union_sql, ')',
    r"""
,
base AS (
  SELECT
    TRIM(Company) AS Company_Name,
    TRIM(Website) AS Website,
    TRIM(First_Name) AS First_Name,
    TRIM(Last_Name) AS Last_Name,
    TRIM(Job_Title) AS Job_Title,
    LOWER(TRIM(Email)) AS Email_ID,
    TRIM(Industry) AS Industry,
    TRIM(Prospect_Linkedin) AS Prospect_LinkedIn,
    COALESCE(NULLIF(TRIM(City), ''), NULLIF(TRIM(Person_City), ''), NULLIF(TRIM(Company_City), '')) AS City,
    COALESCE(NULLIF(TRIM(State), ''), NULLIF(TRIM(Person_State), ''), NULLIF(TRIM(Company_State), '')) AS State,
    COALESCE(NULLIF(TRIM(Country), ''), NULLIF(TRIM(Person_Country), ''), NULLIF(TRIM(Company_Country), '')) AS Country,
    Source_Table
  FROM src
  WHERE Email IS NOT NULL
    AND TRIM(Email) != ''
    AND LOWER(TRIM(Email)) != 'email'
    AND REGEXP_CONTAINS(TRIM(Email), r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
    AND Company IS NOT NULL AND TRIM(Company) != ''
    AND Job_Title IS NOT NULL AND TRIM(Job_Title) != ''
    AND LOWER(IFNULL(Do_Not_Email, '')) NOT IN ('true', '1', 'yes')
    AND LOWER(IFNULL(Opted_Out, '')) NOT IN ('true', '1', 'yes')
)
SELECT * EXCEPT (Source_Table)
FROM base
QUALIFY ROW_NUMBER() OVER (PARTITION BY Email_ID ORDER BY Company_Name, Source_Table) = 1
""");

  SELECT table_count AS tables_included_in_view;
END;
SQL

echo "==> 3/6 Running it now (builds ${U}.v_prospects_all)"
bq query --project_id="${P}" --location=US --use_legacy_sql=false --format=pretty \
  "CALL \`${P}.${D}.refresh_prospect_view\`()"

echo "==> 4/6 Creating the agent view and the blocked-prospects report"
bq query --project_id="${P}" --location=US --use_legacy_sql=false <<SQL
-- What the agent reads: all prospects MINUS unmailable. Same name and columns as before.
CREATE OR REPLACE VIEW \`${P}.${D}.v_prospects_clean\` AS
SELECT p.*
FROM \`${P}.${U}.v_prospects_all\` p
WHERE NOT EXISTS (
  SELECT 1
  FROM \`${P}.${U}.unmailable_records\` u
  WHERE u.email = p.Email_ID
);

-- Report for admins: prospects in BigQuery that are blocked, and why.
CREATE OR REPLACE VIEW \`${P}.${U}.v_unmailable_matches\` AS
SELECT
  p.*,
  u.opted_out,
  u.do_not_email,
  u.hard_bounce,
  u.soft_bounce,
  u.crm_contact_id,
  u.source    AS flagged_source,
  u.loaded_at AS flagged_at
FROM \`${P}.${U}.v_prospects_all\` p
JOIN \`${P}.${U}.unmailable_records\` u
  ON u.email = p.Email_ID;
SQL

echo "==> 5/6 Allowing scheduled queries to run as the project service account"
gcloud services enable bigquerydatatransfer.googleapis.com
DTS_SA="service-${PROJECT_NUMBER}@gcp-sa-bigquerydatatransfer.iam.gserviceaccount.com"
gcloud beta services identity create --service=bigquerydatatransfer.googleapis.com --project="${P}" >/dev/null 2>&1 || true
for i in $(seq 1 12); do
  if gcloud iam service-accounts add-iam-policy-binding "${RUNTIME_SA}" \
      --member="serviceAccount:${DTS_SA}" \
      --role="roles/iam.serviceAccountTokenCreator" >/dev/null 2>&1; then
    echo "    permission added"; break
  fi
  echo "    service account not ready yet (attempt $i/12), waiting 30 seconds..."; sleep 30
done

echo "==> 6/6 Scheduling the refresh every hour"
if bq ls --transfer_config --transfer_location=us --project_id="${P}" 2>/dev/null | grep -q "Refresh prospect view"; then
  echo "    schedule already exists, skipping"
else
  bq mk --transfer_config \
    --project_id="${P}" \
    --location=US \
    --data_source=scheduled_query \
    --display_name="Refresh prospect view" \
    --schedule="every 1 hours" \
    --service_account_name="${RUNTIME_SA}" \
    --params="{\"query\":\"CALL \`${P}.${D}.refresh_prospect_view\`()\"}"
fi

echo ""
echo "==> Check (block_is_active should be true; the first two counts match while the block list is empty)"
bq query --project_id="${P}" --location=US --use_legacy_sql=false --format=pretty "
SELECT
  (SELECT CONTAINS_SUBSTR(view_definition, 'unmailable_records')
     FROM \`${P}.${D}\`.INFORMATION_SCHEMA.VIEWS WHERE table_name = 'v_prospects_clean') AS block_is_active,
  (SELECT COUNT(*) FROM \`${P}.${U}.v_prospects_all\`)       AS all_prospects,
  (SELECT COUNT(*) FROM \`${P}.${D}.v_prospects_clean\`)     AS agent_can_export,
  (SELECT COUNT(*) FROM \`${P}.${U}.unmailable_records\`)    AS unmailable_loaded"

echo ""
echo "DONE: every table in ${D} is included (refreshed hourly) and unmailable contacts are always excluded."
