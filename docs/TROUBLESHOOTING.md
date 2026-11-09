# Troubleshooting

Real issues hit while building this, and their fixes.

| Symptom | Cause | Fix |
|---|---|---|
| Agent shows a table but no file / says "query results were truncated" | Gemini Enterprise tools don't share data; the file tool can't read BigQuery results | Solved by design: the agent uses BigQuery `EXPORT DATA` so BigQuery writes the CSV itself |
| `EXPORT DATA statement cannot reference meta tables in the queries` | `EXPORT DATA` can't read wildcard tables (`Marketing_Database_*`) | The hourly procedure builds `v_prospects_all` as a `UNION ALL` of named tables (see `bigquery/setup_auto_view.sh`). Don't replace it with a wildcard view |
| New table not appearing in results | The view refreshes hourly | Run `CALL ...refresh_prospect_view()` or wait up to an hour |
| Unmailable filter disappears after an hour | Old setup: the hourly procedure rebuilt `v_prospects_clean` and dropped the filter | Fixed: the procedure now rebuilds `Unmailable_Records.v_prospects_all` only. Never run an older `setup_auto_view.sh`. Check with the `block_is_active` query in the README |
| Same user gets the same prospects every time | No delivery memory (old version) | Fixed: `delivered_records` + agent excludes prospects this user already received for this event |
| Repeats when re-running the same event within ~1 minute | The delivery log is written by the function after the file lands | Wait a minute between runs of the same event |
| Download link broken / odd file ID (e.g. a date in the past) | The model wrote its own run ID instead of copying it | Fixed: run ID comes from Query 1 (`YYYYMMDDHHMMSS_xxxxxx`) and must be copied exactly; exports use `overwrite=false` |
| `WidgetService.WidgetCreateSession … caller does not have permission` | User lacks the Gemini Enterprise IAM role | Grant `roles/discoveryengine.user` and a license in the app's location; wait 5–10 minutes; retry in an incognito window |
| `storage.objects.create` denied during export | Export runs as the user, who has no access to the export bucket | Grant `roles/storage.objectCreator` + `roles/storage.objectViewer` on the export bucket only |
| Colleague gets "permission denied" on tables | They lack BigQuery access | Grant BigQuery Job User + Data Viewer |
| `gcloud` says the project doesn't exist / no permission | Using the console display name instead of the project ID | Use the real project ID (shown in the Cloud Shell prompt) |
| Agent writes "I will check…" or shows empty code boxes | Model narrating its tool use | Instructions forbid it; mostly cosmetic. Start a new chat after updating instructions |
| Custom MCP data store: `Operation denied by org policy ... disableCustomMcpServerConnector` | Org policy blocks Custom MCP connectors | Needs an org admin override. The live solution doesn't use MCP |
| `Permission 'orgpolicy.policies.create' denied` | Project Owner can't change org policies | Ask a Google Cloud org admin |
| `Service account service-…@gs-project-accounts… does not exist` | Cloud Storage service agent not created yet | `gsutil kms serviceaccount -p <project>`, then retry for a few minutes |
| `--set-env-vars: Bad syntax for dict arg` | A custom delimiter clashed with `@` in email addresses | Use `--env-vars-file=env.yaml` (current `deploy_logging.sh`) |
| `bq`: `Unknown command line flag ' META | event'` | `bq` treats a query starting with `--` as a flag | Pass the SQL through stdin (heredoc), as in `test_logging.sh` |
| Log row has `generated_at = NULL` | Timestamp parameter type mismatch (older helper version) | Fixed: helper inserts `TIMESTAMP(@generated_at)` |
| Download needs 2–3 clicks (old flow) | Gemini's built-in file card | Solved: users now get a direct Cloud Storage link |
| Email looks bold/heavy in Gmail | Gmail can't load the Lexend web font | Expected. Lighter weights are used so the fallback font looks clean |
| No admin email | Apps Script URL/secret mismatch, or web app not set to "Anyone" | Check `MAIL_WEBHOOK_URL` / `MAIL_SECRET` in the function's env vars and the `SHARED_SECRET` in `Code.gs`. See function logs: `gcloud functions logs read prospect-csv-rename --region=us-central1` |
| Uploaded file shows up as `index .js` in Cloud Shell | Browser renamed the download | `mv ~/"index .js" ~/csv-helper-v3/index.js` |
