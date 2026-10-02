# Migration steps

Each step lists the console path and the matching script. Run the scripts in order after filling in `scripts/00-env.sh`.

## Step 0: Plan

- [ ] Inventory the source: engine/version, database size, largest tables, tables without primary keys, LOB columns, triggers, stored procedures, users.
- [ ] Decide migration type: **full load + CDC** (minimal downtime) vs full load only (accept an outage).
- [ ] Agree a downtime window for cutover and a rollback plan.
- [ ] Confirm network path: DMS replication instance → source (3306) and → target (3306).

> Tables without a primary key or unique index replicate poorly under CDC (updates/deletes become full scans on the target). Add a key or exclude them.

## Step 1: Create the target RDS instance

Console: **RDS → Subnet groups → Create**, then **RDS → Create database**.

- Subnet group: both private DB subnets (`TargetVPC-private-a-db`, `TargetVPC-private-b-db`).
- Public access: **No**.
- Security group: inbound 3306 **only from the DMS replication instance's security group**.
- Same major engine version as the source (or newer, after testing).
- Consider Multi-AZ before cutover; the subnet group allows it but does not enable it.

Script: `scripts/02-create-rds.sh`

Then create the schema on the target **without secondary indexes and foreign keys** (export with `mysqldump --no-data`, strip them, apply). Add them back before CDC catch-up finishes.

## Step 2: Create the DMS replication instance

Console: **DMS → Subnet groups → Create**, then **DMS → Replication instances → Create**.

- Instance class: size for the full load (e.g. `dms.t3.medium` for labs, `dms.r5.*` for large/LOB-heavy loads).
- Storage: holds cached changes and logs; 50 GB is a reasonable start.
- Publicly accessible: **No**, unless the source is only reachable over the internet.
- Same VPC as the target.

Script: `scripts/03-create-replication-instance.sh`

## Step 3: Create source and target endpoints

Console: **DMS → Endpoints → Create endpoint** (once as source, once as target).

- Engine: MySQL (target: the RDS endpoint address).
- Credentials: prefer **AWS Secrets Manager** over a typed password.
- Run **Test connection** for each against the replication instance. Fix failures before moving on (almost always security groups, routing or DNS).

Script: `scripts/04-create-endpoints.sh`

## Step 4: Enable binary logging on the source (for CDC)

CDC reads the MySQL binary log, so the source needs:

| Setting | Value | Why |
| --- | --- | --- |
| `log_bin` | on | CDC has nothing to read without it |
| `binlog_format` | `ROW` | DMS needs row-level changes |
| `binlog_row_image` | `FULL` | Full before/after images for updates |
| `binlog_checksum` | `NONE` (older DMS engine versions) | Older DMS versions do not read CRC32 checksums |
| `server_id` | any unique non-zero value | Required for binlogging |
| binlog retention | longer than the full load + buffer | If logs rotate away, CDC cannot resume |

- **Self-managed MySQL (EC2/on-prem):** apply `config/source-mysql-binlog.cnf` and restart.
- **RDS MySQL as the source:** use a custom DB parameter group, enable automated backups (this turns on binlogging), then run
  `CALL mysql.rds_set_configuration('binlog retention hours', 24);`

Then create the DMS user and verify settings with `sql/01-source-prereqs.sql`.

## Step 5: Create and start the replication task

Console: **DMS → Database migration tasks → Create task**.

- Migration type: **Migrate existing data and replicate ongoing changes**.
- Target table preparation mode: **Do nothing** (schema pre-created) or **Truncate**.
- LOB mode: limited LOB mode with a max size that covers your largest LOB.
- Enable **data validation** and **CloudWatch logs**.
- Table mappings: `dms/table-mappings.json`.

Script: `scripts/05-create-and-start-task.sh`

## Step 6: Monitor until caught up

- Task status moves from *Full load* to *Load complete, replication ongoing*.
- **Table statistics** show rows loaded, inserts/updates/deletes applied and validation state per table.
- CloudWatch `CDCLatencySource` and `CDCLatencyTarget` should trend toward zero.

Script: `scripts/06-monitor.sh`

## Step 7: Cut over

Follow `docs/02-cutover-runbook.md`.
