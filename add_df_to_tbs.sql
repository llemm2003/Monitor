set serveroutput on
set linesize 300
DECLARE
/*Variable declaration part */
add_string varchar2(200);
stg_tbs dba_tablespaces.tablespace_name%type;
count_checker number(2);
count_x number(2);
db_files varchar2(10);
df_count number(10);
add_df_space_string varchar2(200);
storage_string varchar2(10) := ''''||'+DATA'||'''';
next_size varchar2(5) := '8M';
time_x timestamp;
threshold_val number(2) := 69;
df_not_autoextend number(3);
df_id dba_data_files.file_id%type;
bigfile number(3);
df_init_size number(7);
df_block_size number(5);
df_min_extenlen number(5);
disk_storage v$parameter.value%type;
maxbytes_val dba_data_files.maxbytes%type;
block_size_max_compute varchar2(20);
block_size_count_clearance number(1) := 4;
tbs_contents dba_tablespaces.contents%type;
cdb_name_current varchar2(20);

BEGIN
/*MAIN START*/

/*This script will add datafiles to tablespaces that needs more space and below threshold. But will need to make sure that the tablespace must be:
1. Small file
2. all tablespace is autoextensible and maxsize is unlimited(small or bigfile). 

The script will check first for any datafile not set to autoextend*
It will put all datafiles to autoextend if one datafile is not autoextend and maxsize unlimited;
If tablespaces are bigfile** -- The script will exit*** (Fixed already). It will fix bigfile tablespace by setting the autoextend and NEXT segment. 
It will look for bigfile tablespace that are not autoextend or the datafiles whose maxbytes are not in its theoretical maxsize or (2^32)-1*block_size. 
*/

/*Check important DB parameters*/
select value into db_files from v$parameter where name='db_files';
select value into disk_storage from v$parameter where name='db_create_file_dest';
select count(*) into df_count from dba_data_files;
select sys_context('USERENV','CON_NAME')  into cdb_name_current from dual;

count_checker := 0;
count_x := 0;

 BEGIN 
 dbms_output.put_line(' Working here: '||cdb_name_current);
  select count(*) into df_not_autoextend from dba_data_files where AUTOEXTENSIBLE='NO';
  --select count(*) into  bigfile from dba_tablespaces a join dba_data_files b on a.tablespace_name=b.tablespace_name where bigfile='YES' and AUTOEXTENSIBLE='NO';
  select count(*) into  bigfile from dba_tablespaces a join dba_data_files b on a.tablespace_name=b.tablespace_name where (a.bigfile='YES' and b.maxbytes <= (power(2,32)-block_size_count_clearance)*a.block_size) or (a.bigfile='YES' and b.autoextensible='NO');
  EXCEPTION
   WHEN NO_DATA_FOUND THEN 
    dbms_output.put_line('ALL datafiles are autoextensible.');
  END;	
  dbms_output.put_line('Number of DF not autoextend: '||df_not_autoextend);
  dbms_output.put_line('Number of BIGFILE: '||bigfile);
  
  IF df_not_autoextend > 0 THEN
   dbms_output.put_line('Extending any datafile that is not autoextend...');
   FOR df_id IN (select file_id from dba_data_files where autoextensible='NO')
   LOOP 
    dbms_output.put_line('ALTER DATABASE DATAFILE '||df_id.file_id||' autoextend on next 128M maxsize unlimited');
	execute immediate('ALTER DATABASE DATAFILE '||df_id.file_id||' autoextend on next 128M maxsize unlimited');
   END LOOP; 
  END IF;
  
  IF bigfile > 0 THEN
	dbms_output.put_line('BIGFILE CHECK');
   FOR df_id IN (select file_id from dba_data_files where tablespace_name IN (select tablespace_name from dba_tablespaces where bigfile='YES'))
   LOOP
    dbms_output.put_line('ALTER DATABASE DATAFILE '||df_id.file_id||' autoextend on next 128M maxsize unlimited');
	execute immediate('ALTER DATABASE DATAFILE '||df_id.file_id||' autoextend on next 128M maxsize unlimited');
   END LOOP;
  END IF;
 
 BEGIN
  --select count(*) into count_checker from (select tablespace_name TBS_NAME, sum(bytes/1048576) As CurrentUsage, sum(maxbytes/1048576) AS MAXIMUM_ALLOCATION  from dba_data_files group by tablespace_name) where CurrentUsage/MAXIMUM_ALLOCATION*100 > threshold_val;
  select count(*) into count_checker from (
 select * from (select tablespace_name TBS_NAME, sum(bytes/1048576) As CurrentUsage, sum(maxbytes/1048576) AS MAXIMUM_ALLOCATION  from dba_data_files group by tablespace_name)
 where CurrentUsage/MAXIMUM_ALLOCATION*100 > threshold_val
 union
 select * from (select tablespace_name TBS_NAME, sum(bytes/1048576) As CurrentUsage, sum(maxbytes/1048576) AS MAXIMUM_ALLOCATION  from dba_temp_files group by tablespace_name)
 where CurrentUsage/MAXIMUM_ALLOCATION*100 > threshold_val);
  EXCEPTION
   WHEN NO_DATA_FOUND THEN 
    dbms_output.put_line('No tablespace above threshold.');
   WHEN ZERO_DIVIDE THEN 
    dbms_output.put_line('A data or tempfile(s) is still not autoextend, additional investigation needed.');
 END;
 
LOOP 
 select sysdate into time_x from dual;
 dbms_output.put_line(time_x);
 EXIT WHEN count_checker = 0;
 
 BEGIN
  --select count(*) into count_checker from (select tablespace_name TBS_NAME, sum(bytes/1048576) As CurrentUsage, sum(maxbytes/1048576) AS MAXIMUM_ALLOCATION  from dba_data_files group by tablespace_name) where CurrentUsage/MAXIMUM_ALLOCATION*100 > threshold_val;
 select count(*) into count_checker from (
 select * from (select tablespace_name TBS_NAME, sum(bytes/1048576) As CurrentUsage, sum(maxbytes/1048576) AS MAXIMUM_ALLOCATION  from dba_data_files group by tablespace_name)
 where CurrentUsage/MAXIMUM_ALLOCATION*100 > threshold_val
 union
 select * from (select tablespace_name TBS_NAME, sum(bytes/1048576) As CurrentUsage, sum(maxbytes/1048576) AS MAXIMUM_ALLOCATION  from dba_temp_files group by tablespace_name)
 where CurrentUsage/MAXIMUM_ALLOCATION*100 > threshold_val);
  EXCEPTION
   WHEN NO_DATA_FOUND THEN 
   dbms_output.put_line('No tablespace above threshold.');
   EXIT;
 END;
 
 dbms_output.put_line('Tablespace count found: '||count_checker);
 
 BEGIN
 --select TBS_NAME into stg_tbs from (select tablespace_name TBS_NAME, sum(bytes/1048576) As CurrentUsage, sum(maxbytes/1048576) AS MAXIMUM_ALLOCATION  from dba_data_files group by tablespace_name) where CurrentUsage/MAXIMUM_ALLOCATION*100 > threshold_val and rownum=1;
 select TBS_NAME into stg_tbs from (select tablespace_name TBS_NAME, sum(bytes/1048576) As CurrentUsage, sum(maxbytes/1048576) AS MAXIMUM_ALLOCATION  from dba_data_files group by tablespace_name
 union
 select tablespace_name TBS_NAME, sum(bytes/1048576) As CurrentUsage, sum(maxbytes/1048576) AS MAXIMUM_ALLOCATION  from dba_temp_files group by tablespace_name) 
 where CurrentUsage/MAXIMUM_ALLOCATION*100 > threshold_val and rownum=1;
   EXCEPTION
   WHEN NO_DATA_FOUND THEN 
   dbms_output.put_line('No tablespace above threshold.');
 END;
 
 dbms_output.put_line('Tablespace name-found: '||stg_tbs);
 IF count_checker > 0 THEN
 dbms_output.put_line('Adding 1 datafile to: '||stg_tbs);
  /* minimum extent size is 64KB+(blocksize *3) */
  --select (block_size*3)+MIN_EXTLEN into df_init_size from dba_tablespaces where tablespace_name=stg_tbs;
  SELECT (block_size*3)+MIN_EXTLEN,  
  CASE contents 
  WHEN 'TEMPORARY' THEN 'TEMP'
  WHEN 'PERMANENT' THEN 'DATA'
  ELSE 'DATA' END
  INTO df_init_size,tbs_contents
  FROM dba_tablespaces where tablespace_name=stg_tbs;
  
  dbms_output.put_line('Extent size: '||df_init_size);
  add_df_space_string := 'alter tablespace '||stg_tbs||' add '|| tbs_contents ||'file ''' || disk_storage ||''' size '||df_init_size||' autoextend on next '||next_size||'  maxsize unlimited';
  dbms_output.put_line(add_df_space_string);
  execute immediate(add_df_space_string);
  count_checker := 0;
 END IF;
 
 BEGIN
  --select count(*) into count_checker from (select tablespace_name TBS_NAME, sum(bytes/1048576) As CurrentUsage, sum(maxbytes/1048576) AS MAXIMUM_ALLOCATION  from dba_data_files group by tablespace_name) where CurrentUsage/MAXIMUM_ALLOCATION*100 > threshold_val;
  select count(*) into count_checker from (
  select * from (select tablespace_name TBS_NAME, sum(bytes/1048576) As CurrentUsage, sum(maxbytes/1048576) AS MAXIMUM_ALLOCATION  from dba_data_files group by tablespace_name)
  where CurrentUsage/MAXIMUM_ALLOCATION*100 > threshold_val
  union
  select * from (select tablespace_name TBS_NAME, sum(bytes/1048576) As CurrentUsage, sum(maxbytes/1048576) AS MAXIMUM_ALLOCATION  from dba_temp_files group by tablespace_name)
  where CurrentUsage/MAXIMUM_ALLOCATION*100 > threshold_val);
 
  EXCEPTION
   WHEN NO_DATA_FOUND THEN 
   dbms_output.put_line('No tablespace above threshold.');
 END;
  
 BEGIN
  count_x := count_x + 1;
  EXCEPTION
   WHEN OTHERS THEN
   dbms_output.put_line('Error received:' ||sqlerrm);
  EXIT;
 END;
 dbms_output.put_line('counter: ' ||count_x);
END LOOP;
END;
