# 📜 Changelog

All notable changes to the Marketing DataLake Agent.

## v3.1.0 — 10 Nov 2026

New name: **Marketing DataLake Agent** (10 Nov 2026).

### ✨ New
- 🏷️ Renamed from "Marketing Database Agent" to **Marketing DataLake Agent**
- 🎨 Colourful README with banner, badges and a colour-coded diagram
- 🏗️ **ARCHITECTURE.md** with 7 colour-coded diagrams: big picture, request flow, data lake, no repeats, unmailable block, logs, optional MCP
- 🛡️ **Secrets check** in CI: blocks keys, secrets, real project IDs and real email addresses
- 🔒 Sample data only: the admin email preview now shows a made-up "Sample User"

### 🔜 Next
- 🔄 Weekly Salesforce unmailable sync (every Sunday)


## v3.0.0 — 9 Nov 2026

The big rules update (9–10 Nov 2026).

### ✨ New
- 🔁 **No repeats:** the same user never gets the same prospect twice for the same event (`delivered_records` log)
- 🚫 **Unmailable block:** opted-out, do-not-email and bounced contacts are always removed (`unmailable_records`)
- ✅ **Approve step:** the agent shows titles and the number of **new** prospects, and exports only after "Approve"
- 🧠 **~20 added job titles** from Event, Solution and Industry; your own titles first
- 🏭 **Industry** ranks matching companies first and never removes anyone
- 📝 **Only Event Name and Database Count are required**
- 🆔 Unique export IDs (`YYYYMMDDHHMMSS_xxxxxx`) and `overwrite=false`, so files are never replaced
- 📚 Worked examples and a troubleshooting guide

### 🐛 Fixed
- The hourly refresh no longer drops the unmailable filter
- Broken download links caused by the model inventing its own file ID
- CI now tests the log function in `csv-helper`


## v2.0.0 — 18 Oct 2026

First version on GitHub (18 Oct 2026).

### ✨ What's in it
- 🤖 **Gemini Enterprise agent** that turns a short form (event, count, titles, location) into a prospect CSV
- 🗄️ **BigQuery search** across the vendor tables, written straight to Cloud Storage with `EXPORT DATA` (no rows in the chat)
- 📥 **One-click download** named `Database - <Event Name>.csv`; files delete themselves after 7 days
- 📊 **Admin logs** in BigQuery: one row per download
- 📧 **Admin email** for every download, with a 7-day download link and monthly usage
- 🔒 **Tamper-proof identity** from BigQuery job history
- 🧪 Optional MCP server (built and tested; blocked by org policy, not in use)


---

🙌 nexoradev-stack · eneelkant · Claude · Cursor
