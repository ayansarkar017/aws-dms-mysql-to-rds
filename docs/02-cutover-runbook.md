# Cutover runbook

Goal: switch the application from the source MySQL to RDS with a short, controlled write freeze and a clear rollback path.

## T-1 day

- [ ] Task status is *Load complete, replication ongoing* for at least 24 hours with no errors.
- [ ] Table statistics: every table shows **Validated** (or known, explained mismatches).
- [ ] Secondary indexes, foreign keys, triggers, stored procedures and views exist on the target.
- [ ] Application users and grants recreated on RDS (DMS does not copy users).
- [ ] Application config ready to point at the RDS endpoint (or a DNS CNAME you control).
- [ ] RDS automated backups on; Multi-AZ decided; parameter group reviewed.
- [ ] Rollback owner and decision deadline agreed.

## Cutover window

1. [ ] Announce the start; stop scheduled jobs that write to the source.
2. [ ] Put the application in maintenance / read-only mode (stop writes to the source).
3. [ ] Confirm no new writes: `SHOW MASTER STATUS;` on the source; the position should stop moving.
4. [ ] Wait for `CDCLatencySource` and `CDCLatencyTarget` to reach ~0 (`scripts/06-monitor.sh`).
5. [ ] Run `sql/02-validate.sql` on both sides; row counts and checksums match.
6. [ ] Reset `AUTO_INCREMENT` values on the target if needed (`ALTER TABLE t AUTO_INCREMENT = <max+1>`).
7. [ ] Stop the DMS task.
8. [ ] Repoint the application to RDS (config change or DNS switch); bring it back up.
9. [ ] Smoke test: logins, a write, a read, a background job.
10. [ ] Announce completion.

## Rollback (before the decision deadline)

- Keep the source **read-only and intact** for an agreed period.
- If RDS has a blocking problem: stop the app, repoint to the source, re-enable writes.
- Writes made on RDS after cutover are lost on rollback unless you set up reverse replication (a second DMS task, RDS → source) before going live.

## After cutover

- [ ] Watch RDS CloudWatch metrics (CPU, connections, read/write latency, free storage) for a few days.
- [ ] Delete the DMS task, endpoints and replication instance (`scripts/99-cleanup.sh` removes the lab resources).
- [ ] Decommission the source after the rollback period.
