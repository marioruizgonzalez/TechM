SET LINES 156
SET PAGES 1024
COL owner FOR A20
COL object_name FOR a32
COL object_type FOR a15
COL database FOR a10
COL instance_name FOR a13
COL fecha FOR a18

ALTER session SET nls_date_format = 'DD-MON-YYYY HH24:MI:SS';

SET ECHO ON

SELECT global_name database, instance_name, sysdate AS fecha FROM global_name CROSS JOIN v$instance;
SELECT status, count(1) total_objetos FROM dba_objects GROUP BY status order by 1;
SELECT status, count(1) total_constraints FROM dba_constraints GROUP BY status order by 1;
SELECT status, count(1) total_indices FROM dba_indexes GROUP BY status order by 1;
SELECT status, count(1) total_ind_parts FROM dba_ind_partitions GROUP BY status order by 1;
SELECT status, count(1) total_ind_subparts FROM dba_ind_subpartitions GROUP BY status order by 1;
-- lista total de objetos invalidos
SELECT owner, object_type, count(1) FROM dba_objects where status = 'INVALID' GROUP BY owner, object_type order by 1,2;
-- lista detalle de objetos invalidos
SELECT owner, object_type, object_name, last_ddl_time FROM dba_objects where status = 'INVALID' order by 4, 1, 2, 3;
