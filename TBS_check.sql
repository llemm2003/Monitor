DECLARE
pdb_name varchar2(30);
tblspace_name varchar2(50);
t_space number(20);
u_space number(20);
f_space number(20);
pct_used number(10);
pct_free number(10);
found_tbs number(3);
BEGIN

Select
count(*) into found_tbs
from (select round(sum(d.bytes)/(1048576)) as totalspace
, d.tablespace_name tablespace
, c.name as pdb_name
from cdb_data_files d
, v$pdbs c
where c.con_id=d.con_id
group by d.tablespace_name, c.name) t
, (select round(sum(f.bytes)/(1048576)) as freespace
, f.tablespace_name tablespace
, c.name as pdb_name
from cdb_free_space f
, v$pdbs c
where f.con_id=c.con_id
group by f.tablespace_name, c.name
) fs
where t.tablespace=fs.tablespace
and t.pdb_name=fs.pdb_name
and round(((t.totalspace-fs.freespace)/t.totalspace)*100,2) > 80;


dbms_output.put_line('There are '||found_tbs||' above threshold');

IF found_tbs > 0 THEN

END;
/
