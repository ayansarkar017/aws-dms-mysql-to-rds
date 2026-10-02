# MySQL to Amazon RDS with AWS DMS (full load + CDC)

Step-by-step scripts, configs and a cutover runbook for migrating a MySQL database into Amazon RDS using AWS Database Migration Service, with ongoing replication so the source keeps serving traffic until cutover.

Companion to my LinkedIn article: *Migrating a Database to Amazon RDS with AWS DMS: What I Learned* (https://www.linkedin.com/pulse/migrating-database-amazon-rds-aws-dms-what-i-learned-ayan-sarkar-ncm3e).

## Architecture

```
                 Source MySQL (binlog ROW / FULL)
                          │  full load + CDC
                          ▼
┌──────────────────────── TargetVPC ─────────────────────────┐
│  AZ a                              AZ b                    │
│  ┌ Public subnet a ─────────────┐  ┌ Public subnet b ─────┐ │
│  │ DMS replication instance     │  │ NAT gateway          │ │
│  │ NAT gateway                  │  └──────────────────────┘ │
│  └──────────────┬───────────────┘                           │
│                 │ 3306                                      │
│  ┌ Private DB subnet a ─────────┐  ┌ Private DB subnet b ─┐ │
│  │ RDS database-1               │  │ (standby if Multi-AZ)│ │
│  └──────────────────────────────┘  └──────────────────────┘ │
│        └──────── DB subnet group spans both AZs ───────┘    │
└────────────────────────────────────────────────────────────┘
```

## Repository layout

| Path | What it is |
| --- | --- |
| `docs/01-migration-steps.md` | The full walkthrough, console and CLI |
| `docs/02-cutover-runbook.md` | Checklist for switching the application to RDS |
| `docs/03-lessons-learned.md` | What went wrong or surprised me, and the fix |
| `docs/04-troubleshooting.md` | Common DMS errors and where to look |
| `config/source-mysql-binlog.cnf` | `my.cnf` settings the source needs for CDC |
| `sql/01-source-prereqs.sql` | DMS user, grants and binlog checks on the source |
| `sql/02-validate.sql` | Row-count and checksum queries to run on both sides |
| `dms/table-mappings.json` | Which schemas/tables to migrate |
| `dms/task-settings.json` | Task settings (target prep, LOBs, validation, logging) |
| `scripts/00-env.example.sh` | Variables every script reads; copy to `00-env.sh` |
| `scripts/01-iam-dms-vpc-role.sh` | One-time IAM role DMS needs when using the CLI |
| `scripts/02-create-rds.sh` | DB subnet group + target RDS instance |
| `scripts/03-create-replication-instance.sh` | DMS subnet group + replication instance |
| `scripts/04-create-endpoints.sh` | Source/target endpoints + connection tests |
| `scripts/05-create-and-start-task.sh` | Full load + CDC replication task |
| `scripts/06-monitor.sh` | Table statistics and CDC latency |
| `scripts/99-cleanup.sh` | Tears everything down |

## Quick start

```bash
cp scripts/00-env.example.sh scripts/00-env.sh   # fill in your IDs
# On the source: apply config/source-mysql-binlog.cnf, restart, run sql/01-source-prereqs.sql
bash scripts/01-iam-dms-vpc-role.sh
bash scripts/02-create-rds.sh
bash scripts/03-create-replication-instance.sh
bash scripts/04-create-endpoints.sh
bash scripts/05-create-and-start-task.sh
bash scripts/06-monitor.sh
# When CDC latency is near zero, follow docs/02-cutover-runbook.md
```

## Prerequisites

- AWS CLI v2, configured for the target account and region
- A VPC with private DB subnets in at least two AZs (see diagram)
- Network path from the DMS replication instance to the source on port 3306
- Source MySQL 5.7+ or 8.x with admin access to change binlog settings

## Cost note

The replication instance, RDS instance and NAT gateways bill hourly. Run `scripts/99-cleanup.sh` when you are done experimenting.

## Disclaimer

Lab and learning material. Review security groups, instance sizes and credentials handling before using any of this in production.
