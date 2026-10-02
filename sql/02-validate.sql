-- Run on BOTH source and target after CDC has caught up and writes are stopped.
-- Compare the output side by side.

SET @db = 'your_database';

-- 1. Exact row counts per table (generates the statements to run)
SELECT CONCAT('SELECT ''', table_name, ''' AS tbl, COUNT(*) AS row_count FROM `',
              table_schema, '`.`', table_name, '`;') AS run_this
FROM information_schema.tables
WHERE table_schema = @db AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- 2. Table checksums (same result on both sides = same data; can be slow on big tables)
-- CHECKSUM TABLE your_database.table1, your_database.table2;

-- 3. AUTO_INCREMENT values to carry over at cutover
SELECT table_name, auto_increment
FROM information_schema.tables
WHERE table_schema = @db AND auto_increment IS NOT NULL
ORDER BY table_name;

-- 4. Objects DMS does not migrate: confirm they exist on the target
SELECT routine_type, routine_name FROM information_schema.routines WHERE routine_schema = @db;
SELECT trigger_name, event_object_table FROM information_schema.triggers WHERE trigger_schema = @db;
SELECT table_name FROM information_schema.views WHERE table_schema = @db;
