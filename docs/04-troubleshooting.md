# Troubleshooting

| Symptom | Likely cause | Where to look / fix |
| --- | --- | --- |
| Endpoint **Test connection** times out | Security group, NACL or route missing | DMS SG egress, source/RDS SG inbound 3306, route tables, VPN/peering |
| Test connection: access denied | Wrong user/password or host restriction | `CREATE USER 'dms_user'@'%'` (or the DMS subnet range), grants in `sql/01-source-prereqs.sql` |
| Task fails at start: binlog not enabled / wrong format | `log_bin` off or `binlog_format` not ROW | `config/source-mysql-binlog.cnf`; on RDS use a parameter group + backups on |
| CDC stops: "could not find first log file" | Binlogs purged before DMS read them | Increase binlog retention; restart task (may need a fresh full load) |
| Full load very slow | Small instance, indexes on target, LOBs in full LOB mode | Bigger class, drop secondary indexes, limited LOB mode, parallel load settings |
| Validation mismatches | Writes during load, type/collation differences, no PK | Re-validate after catch-up; check charset/collation; add PKs |
| Updates/deletes slow on target | Table has no primary key | Add a PK or unique index |
| High `CDCLatencyTarget` | Target under-sized or batch apply off | Scale RDS, enable `BatchApplyEnabled` for high-volume tables |
| Task errors on LOB truncation | LOB larger than `LobMaxSize` | Raise `LobMaxSize` or use inline/full LOB mode for that table |

Logs: enable CloudWatch logging in `dms/task-settings.json`, then check log group `dms-tasks-<replication-instance-name>`.
