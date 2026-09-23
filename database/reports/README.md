# GreenCare activity exports

These scripts are read-only reports. They do not update schema or business data.

## Recommended final-export procedure

1. Confirm the activity has ended.
2. Stop the production App Pool to freeze all writes.
3. Take and verify a full database backup.
4. Record the application artifact, Git commit, database name, and `SchemaVersions`.
5. Run the reports with a controlled DBA/reporting account.
6. Save each SSMS result grid as CSV and verify Traditional Chinese text, row counts, and totals.
7. Store exports in access-controlled storage and calculate SHA-256 for each file.
8. Restart the App Pool only if the site must remain available in read-only/result mode.

## Files

| File | Audience | Contents |
|---|---|---|
| `001_export_manifest.sql` | Internal/owner | Database identity, schema versions, record totals, generation time |
| `002_video_catalog.sql` | Owner | Complete official work catalog |
| `003_vote_summary.sql` | Owner/publication review | Per-work valid vote total, all status totals, rank, percentage |
| `004_vote_detail_controlled.sql` | Restricted internal audit | Vote-level records, device ID, hashes, qualification information |
| `005_risk_and_audit.sql` | Restricted internal audit | Risk events and audit log result sets |

## Security

- `004` and `005` contain pseudonymous identifiers and security signals. Do not send them as ordinary public result files.
- Never export SQL passwords, connection strings, CAPTCHA secrets, AppSecret, cookies, or raw IP addresses.
- The application stores IP/device signals as hashes; the report must not attempt to reverse or enrich them.
- Run final exports against `GreenCare_Production`, not `GreenCare_Development`.
- The final public result must be reviewed against `003_vote_summary.sql` and approved by the event owner.

The application ranking rule is reproduced by `003`: valid votes descending, then `VideoId` ascending. A tie therefore receives a deterministic sequential display rank rather than a shared competition rank.
