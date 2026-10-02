-- Run on the SOURCE as an admin user.

-- 1. Verify binlog settings
SHOW VARIABLES WHERE Variable_name IN
  ('log_bin', 'binlog_format', 'binlog_row_image', 'binlog_checksum', 'server_id');
SHOW BINARY LOGS;

-- RDS MySQL source only: keep binlogs long enough for the full load
-- CALL mysql.rds_set_configuration('binlog retention hours', 24);
-- CALL mysql.rds_show_configuration;

-- 2. Create a dedicated DMS user (restrict the host to your DMS subnet if you can)
CREATE USER IF NOT EXISTS 'dms_user'@'%' IDENTIFIED BY 'CHANGE_ME_STRONG_PASSWORD';

GRANT SELECT ON *.* TO 'dms_user'@'%';
GRANT REPLICATION CLIENT, REPLICATION SLAVE ON *.* TO 'dms_user'@'%';
FLUSH PRIVILEGES;

-- 3. Find tables without a primary key (these replicate poorly under CDC)
SELECT t.table_schema, t.table_name
FROM information_schema.tables t
LEFT JOIN information_schema.table_constraints c
  ON c.table_schema = t.table_schema
 AND c.table_name = t.table_name
 AND c.constraint_type = 'PRIMARY KEY'
WHERE t.table_type = 'BASE TABLE'
  AND t.table_schema NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
  AND c.constraint_name IS NULL;

-- 4. Size check: largest tables
SELECT table_schema, table_name,
       ROUND((data_length + index_length) / 1024 / 1024, 1) AS size_mb,
       table_rows
FROM information_schema.tables
WHERE table_schema NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
ORDER BY size_mb DESC
LIMIT 20;
