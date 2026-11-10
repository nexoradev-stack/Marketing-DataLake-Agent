# Examples

Worked examples of how the Marketing Database Agent behaves, end to end.
All names, companies, numbers and emails on this page are **fictional**.

---

## 1. First message: the agent asks for the details

If the user hasn't given both an Event Name and a Database Count, the agent replies only with the form.

**User:**
```
hi
```

**Agent:**
```
👋 Welcome! Please fill in the details below to generate your prospect database:

Event Name: (required)
Database Count: (required, maximum 5000)
Solution:
Industry:
Job Title(s):
City:
State:
Country:
```

A partial request keeps what the user already gave and asks only for what's missing.
If the user's first message already has an Event Name and a Database Count, the agent skips the form.

---

## 2. Standard request: summary, then Approve

**User:**
```
Event Name: Cloud Leaders Summit – Texas
Database Count: 300
Solution: Data & AI
Industry: Healthcare
Job Title(s): CIO, CTO
City:
State: Texas
Country: United States
```

**Agent (summary):**
```
Cloud Leaders Summit – Texas

Your titles: CIO, CTO
Titles I added: CDO, CAIO, Chief Digital Officer, Chief Analytics Officer, VP of Data, VP of Analytics,
VP of AI, VP of IT, VP of Technology, Head of Data, Head of Analytics, Head of AI, Head of IT,
Director of Data, Director of Analytics, Director of AI, Director of Data Science,
Director of Business Intelligence, Director of IT, Director of Data Engineering
Industry: Healthcare, prioritised
Location: Texas, United States

✅ 2,140 new prospects available (612 from your titles)

Reply Approve to export 300, or tell me which titles to add or remove.
```

**User:** `Approve`

**Agent:**
```
✅ Prospect database ready — Cloud Leaders Summit – Texas
Records: 300 of 300 requested
Job titles: CIO, CTO; added: CDO, CAIO, …
Industry: Healthcare
Location: Texas, United States
📥 Download CSV
✅ All set! Your prospect database is ready. Download your CSV and start prospecting!
```

The file downloads as **`Database - Cloud Leaders Summit Texas.csv`**.
All 300 come from the user's own titles first (612 available). Healthcare companies are picked first
and listed at the top of the file.

**What the numbers mean:** 2,140 = everyone new who matches the user's titles **or** the added titles.
612 = how many of those match the user's own titles. The added titles are only used once the user's
own titles run out.

---

## 3. Same event again: no repeats

The same user runs **Cloud Leaders Summit – Texas** again (or `cloud leaders summit texas` — capitals,
dashes and spaces don't matter).

**Agent:**
```
✅ 1,840 new prospects available (312 from your titles)
↩️ 300 you already received for this event are excluded.
```

The new file contains 300 **different** people.

A **different user**, or the same user with a **different event** (e.g. *Gemini Product Updates – Texas*),
can receive the same people again. Unmailable contacts are never included for anyone.

---

## 4. Similar event name

The user previously ran **Webinar: Google Gemini Updates – Atlanta** and now types
**Google Gemini Updates Atlanta**.

**Agent:**
```
You've used a similar event name before: "Webinar: Google Gemini Updates – Atlanta". Is this the same event?
- Yes — you'll only get new people, no repeats.
- No — it will be treated as a new event.
```

Names with different words that describe different events (e.g. *Engineering the Agentic Enterprise –
Atlanta* and *Gemini Product Updates – Atlanta*) are never mixed up and the agent doesn't ask.

---

## 5. Not enough new prospects

**Agent:**
```
Idaho IT Roundtable

Your titles: Director of IT
Titles I added: …
Industry: Any
Location: Boise, Idaho, United States

⚠️ Only 186 new prospects available (you asked for 2000).

What would you like to do?
1. Approve 186
2. Add more titles: Head of Infrastructure, IT Manager, Director of Cloud, … → 412 new prospects in total
3. Add or remove titles yourself
```

- `1` → exports 186.
- `2` → moves the extra titles in, recounts and shows a new summary.
- `remove Head of AI` / `add CISO` → recounts and shows a new summary.

---

## 6. No matches

**Agent:**
```
No new matching prospects were found for these criteria.
Job titles: Chief Happiness Officer · Industry: Any · Location: Vermont, United States
```
No file is created and no email is sent.

---

## 7. Job title matching

Titles use word-boundary matching, so short titles never match inside other words.

| Requested | ✅ Matches | ❌ Does not match |
|---|---|---|
| CTO | Chief Technology Officer, CTO & Co-founder | **Director** (contains "cto") |
| CMO | Chief Marketing Officer, CMO | Director of Marketing |
| VP Marketing | Vice President of Marketing, SVP Marketing, VP, Product Marketing | Director of Marketing |
| Director of IT | Director of Information Technology, IT Director | Director of Finance, Director of Digital Marketing |
| Director of Marketing | Senior Director, Product Marketing; Marketing Director | Director of Finance |

If the user gives **no titles**, the agent picks 2–3 "Suggested titles" plus ~20 added titles.

---

## 8. The CSV

11 columns, always in this order. Sample with fictional data:
[`sample_output.csv`](sample_output.csv)

| Company Name | Website | First Name | Last Name | Job Title | Email ID | Industry | Prospect LinkedIn | City | State | Country |
|---|---|---|---|---|---|---|---|---|---|---|
| Acme Analytics | http://www.acme-analytics.example | Jordan | Lee | Chief Marketing Officer | jordan.lee@acme-analytics.example | computer software | http://www.linkedin.com/in/example-jordan-lee | Atlanta | Georgia | United States |

Rules applied before export:
- valid email format only, one row per email (duplicates across tables removed),
- vendor `Do_Not_Email` and `Opted_Out` contacts excluded,
- Salesforce unmailable contacts (opted out, do not email, hard bounce, soft bounce) excluded,
- prospects this user already received for this event excluded,
- City / State / Country fall back to the Person, then Company, columns when blank,
- matching-industry companies listed first, then the rest, each sorted by company name,
- values are copied exactly from the source (State may appear as "GA" or "Georgia").

---

## 9. The SQL the agent runs (filled-in example)

For `Event: Cloud Leaders Summit – Texas`, `Job Title(s): CIO, CTO`, `State: Texas`,
`Country: United States`, `Industry: Healthcare`, `Count: 300` (added titles shortened for readability):

**Query 1 — count new prospects**
```sql
SELECT
  COUNTIF(t1 AND NOT received) AS your_titles_new,
  COUNTIF((t1 OR t2) AND NOT received) AS with_added_new,
  COUNTIF((t1 OR t2 OR t3) AND NOT received) AS with_backup_new,
  COUNTIF((t1 OR t2) AND received) AS already_received,
  CONCAT(FORMAT_TIMESTAMP('%Y%m%d%H%M%S', CURRENT_TIMESTAMP()), '_', SUBSTR(REPLACE(GENERATE_UUID(), '-', ''), 1, 6)) AS run_id
FROM (
  SELECT
    IFNULL(REGEXP_CONTAINS(LOWER(Job_Title), r'\b(cio|chief information officer)\b')
        OR REGEXP_CONTAINS(LOWER(Job_Title), r'\b(cto|chief technology officer|chief technical officer)\b'), FALSE) AS t1,
    IFNULL(REGEXP_CONTAINS(LOWER(Job_Title), r'\b(cdo|chief data officer)\b')
        OR (REGEXP_CONTAINS(LOWER(Job_Title), r'\b(vp|vice president|svp|evp|avp)\b') AND REGEXP_CONTAINS(LOWER(Job_Title), r'\bdata\b')), FALSE) AS t2,
    IFNULL(REGEXP_CONTAINS(LOWER(Job_Title), r'\bdirector\b') AND REGEXP_CONTAINS(LOWER(Job_Title), r'\binsights\b'), FALSE) AS t3,
    EXISTS (SELECT 1 FROM `your-gcp-project-id.prospect_agent_logs.delivered_records` d
            WHERE d.user_email = SESSION_USER()
              AND d.event_key = REGEXP_REPLACE(LOWER('Cloud Leaders Summit – Texas'), r'[^a-z0-9]', '')
              AND d.email = Email_ID) AS received
  FROM `your-gcp-project-id.raw_marketing_vendor_database.v_prospects_clean`
  WHERE LOWER(State) IN ('texas', 'tx')
    AND LOWER(Country) IN ('united states', 'united states of america', 'usa', 'us')
)
```

**Query 2 — export (only after Approve)**
```sql
-- META | event=Cloud Leaders Summit – Texas | solution=Data & AI | industry=Healthcare | titles=CIO, CTO; added: CDO, VP of Data | location=Any, Texas, United States | requested=300
EXPORT DATA OPTIONS(
  uri='gs://your-gcp-project-id-prospect-exports/exports/20261106060222_8236a5/Cloud_Leaders_Summit_Texas_*.csv',
  format='CSV', overwrite=false, header=true
) AS
SELECT Company_Name AS `Company Name`, Website, First_Name AS `First Name`, Last_Name AS `Last Name`,
       Job_Title AS `Job Title`, Email_ID AS `Email ID`, Industry, Prospect_LinkedIn AS `Prospect LinkedIn`,
       City, State, Country
FROM (
  SELECT *,
    IFNULL(REGEXP_CONTAINS(LOWER(Job_Title), r'\b(cio|chief information officer)\b')
        OR REGEXP_CONTAINS(LOWER(Job_Title), r'\b(cto|chief technology officer|chief technical officer)\b'), FALSE) AS t1,
    IFNULL(REGEXP_CONTAINS(LOWER(IFNULL(Industry, '')), r'\b(healthcare|health care|hospital|hospitals|medical|health)\b'), FALSE) AS industry_match
  FROM `your-gcp-project-id.raw_marketing_vendor_database.v_prospects_clean`
  WHERE LOWER(State) IN ('texas', 'tx')
    AND LOWER(Country) IN ('united states', 'united states of america', 'usa', 'us')
    AND ( IFNULL(REGEXP_CONTAINS(LOWER(Job_Title), r'\b(cio|chief information officer)\b')
              OR REGEXP_CONTAINS(LOWER(Job_Title), r'\b(cto|chief technology officer|chief technical officer)\b'), FALSE)
          OR IFNULL(REGEXP_CONTAINS(LOWER(Job_Title), r'\b(cdo|chief data officer)\b')
              OR (REGEXP_CONTAINS(LOWER(Job_Title), r'\b(vp|vice president|svp|evp|avp)\b') AND REGEXP_CONTAINS(LOWER(Job_Title), r'\bdata\b')), FALSE) )
    AND NOT EXISTS (SELECT 1 FROM `your-gcp-project-id.prospect_agent_logs.delivered_records` d
                    WHERE d.user_email = SESSION_USER()
                      AND d.event_key = REGEXP_REPLACE(LOWER('Cloud Leaders Summit – Texas'), r'[^a-z0-9]', '')
                      AND d.email = Email_ID)
  ORDER BY IF(t1, 0, 1), IF(industry_match, 0, 1), FARM_FINGERPRINT(Email_ID)
  LIMIT 300
)
ORDER BY IF(industry_match, 0, 1), `Company Name`, `Last Name`, `First Name`
```

The `-- META` line is read by the helper to fill the admin email and logs. It is never shown to users.

---

## 10. The log tables

**`prospect_agent_logs.generation_log`** — one row per generation:

| generated_at (IST) | user_email | event_name | solution | job_titles | location | requested | delivered | file_name |
|---|---|---|---|---|---|---|---|---|
| 18 Oct 2026 10:28 AM | jordan.lee@example.com | Engineering the Agentic Enterprise – Atlanta | Agentic AI | CMO; added: … | Any, Any, United States | 2500 | 2500 | Database - Engineering the Agentic Enterprise Atlanta.csv |
| 18 Oct 2026 12:02 PM | priya.shah@example.com | Cloud Leaders Summit – Texas | Data & AI | CIO, CTO; added: … | Any, Texas, United States | 300 | 300 | Database - Cloud Leaders Summit Texas.csv |

**`prospect_agent_logs.delivered_records`** — one row per delivered prospect:

| delivered_at | user_email | event_name | event_key | email | gcs_uri |
|---|---|---|---|---|---|
| 2026-10-18 06:58 UTC | priya.shah@example.com | Cloud Leaders Summit – Texas | cloudleaderssummittexas | jordan.lee@acme-analytics.example | gs://…/exports/20261018065812_a3f9c1/Cloud_Leaders_Summit_Texas_000000000000.csv |

### Admin questions you can answer with SQL

How much did each user take this month?
```sql
SELECT user_email, COUNT(*) AS downloads, SUM(delivered_count) AS records
FROM `your-gcp-project-id.prospect_agent_logs.generation_log`
WHERE DATE(generated_at, 'Asia/Kolkata') >= DATE_TRUNC(CURRENT_DATE('Asia/Kolkata'), MONTH)
GROUP BY user_email ORDER BY records DESC;
```

Which events pulled the most data?
```sql
SELECT event_name, COUNT(*) AS downloads, SUM(delivered_count) AS records
FROM `your-gcp-project-id.prospect_agent_logs.generation_log`
GROUP BY event_name ORDER BY records DESC;
```

How many prospects has each user received per event?
```sql
SELECT user_email, ANY_VALUE(event_name) AS event_name, COUNT(DISTINCT email) AS prospects
FROM `your-gcp-project-id.prospect_agent_logs.delivered_records`
GROUP BY user_email, event_key
ORDER BY prospects DESC;
```

Any repeats? (should return no rows)
```sql
SELECT user_email, event_key, email, COUNT(DISTINCT gcs_uri) AS times
FROM `your-gcp-project-id.prospect_agent_logs.delivered_records`
GROUP BY user_email, event_key, email
HAVING COUNT(DISTINCT gcs_uri) > 1;
```

Requests where the database could not fill the count:
```sql
SELECT generated_at, user_email, event_name, requested_count, delivered_count
FROM `your-gcp-project-id.prospect_agent_logs.generation_log`
WHERE delivered_count < requested_count
ORDER BY generated_at DESC;
```

Which prospects are blocked as unmailable?
```sql
SELECT Email_ID, Company_Name, Job_Title, opted_out, do_not_email, hard_bounce, soft_bounce, flagged_at
FROM `your-gcp-project-id.Unmailable_Records.v_unmailable_matches`
ORDER BY flagged_at DESC;
```

---

## 11. The admin email

Sent to both admins about 30 seconds after every generation. See
[`../docs/admin-email-preview.png`](../docs/admin-email-preview.png).

**Subject:** `🔔 Prospect Database Generated — Jordan Lee — 2,500 records`

Contents: records delivered / requested / generated time, user name and email, event,
solution, job titles, location, file name, a **Download a copy** button (7-day link) and the
user's **monthly usage** (adds a review note above 10,000 records in a month).

---

## 12. Adding a new source table

1. Load the new table into `raw_marketing_vendor_database` as `Marketing_Database_00XX`, with the same
   column names as the existing tables and every column as STRING. It needs at least `Email` and
   `Company` columns; other columns are optional (missing ones become blank).
2. Wait up to an hour, or rebuild now:
   ```sql
   CALL `your-gcp-project-id.raw_marketing_vendor_database.refresh_prospect_view`();
   ```
3. The agent searches the new table automatically. No change to the agent is needed.
