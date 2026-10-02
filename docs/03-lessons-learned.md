# Lessons learned

| # | Lesson | What to do |
| --- | --- | --- |
| 1 | The replication instance does not need to be public | Private subnet + VPN / Direct Connect / peering to the source; public only when no private path exists |
| 2 | Security groups are the usual blocker | Allow DMS SG → source 3306 and DMS SG → RDS SG 3306; reference SGs, not CIDRs |
| 3 | Binlog retention can silently break CDC | Retention longer than the full load + buffer; on RDS MySQL use `mysql.rds_set_configuration` |
| 4 | DMS creates tables, not your full schema | Pre-create schema; use target prep mode *Do nothing* or *Truncate* |
| 5 | Indexes slow the full load | Load without secondary indexes / FKs; add them before CDC catch-up ends |
| 6 | "It finished" is not proof | Enable DMS data validation and run `sql/02-validate.sql` |
| 7 | Cut over on metrics, not on feel | Wait for `CDCLatencySource` / `CDCLatencyTarget` near zero |
| 8 | A two-AZ subnet group is not Multi-AZ | Turn Multi-AZ on explicitly before go-live |
| 9 | Tables without primary keys hurt CDC | Add a PK/unique key or exclude the table |
| 10 | LOBs need sizing | Check max LOB size; limited LOB mode with a cap that covers it |
| 11 | Users, grants, procedures and triggers are not migrated | Script them separately; enable triggers only after cutover |
| 12 | Credentials in endpoint settings drift and leak | Store them in Secrets Manager and reference the secret |

## Note on the diagram

The original architecture diagram labelled both zones "Availability Zone 1". The second zone is a different AZ (b). Worth checking diagrams before you publish them; interviewers notice.
