set serveroutput on
set linesize 300
DECLARE
/*Variable declaration part */
add_string varchar2(200);
stg_tbs dba_tablespaces.tablespace_name%type;
count_checker number(2);
count_x number(1);
db_files varchar2(10);
df_count number(10);
add_df_space_string varchar2(200);
storage_string varchar2(10) := ''''||'+DATA'||'''';
next_size varchar2(5) := '8M';
time_x timestamp;
threshold_val number(2) := 90;

BEGIN
/*MAIN*/
/*Check the db important db parameter db_file if it can handle another datafile*/
select value into db_files from v$parameter where name='db_files';
select count(*) into df_count from dba_data_files;
count_checker := 0;
count_x := 0;


 BEGIN
  select count(*) into count_checker from (select tablespace_name TBS_NAME, sum(bytes/1048576) As CurrentUsage, sum(maxbytes/1048576) AS MAXIMUM_ALLOCATION  from dba_data_files group by tablespace_name) where CurrentUsage/MAXIMUM_ALLOCATION*100 > threshold_val;
  EXCEPTION
   WHEN NO_DATA_FOUND THEN 
   dbms_output.put_line('No tablespace above threshold.');
 END;
 
LOOP 
 select sysdate into time_x from dual;
 dbms_output.put_line(time_x);
 EXIT WHEN count_checker = 0;
 
 BEGIN
  select count(*) into count_checker from (select tablespace_name TBS_NAME, sum(bytes/1048576) As CurrentUsage, sum(maxbytes/1048576) AS MAXIMUM_ALLOCATION  from dba_data_files group by tablespace_name) where CurrentUsage/MAXIMUM_ALLOCATION*100 > threshold_val;
  EXCEPTION
   WHEN NO_DATA_FOUND THEN 
   dbms_output.put_line('No tablespace above threshold.');
   EXIT;
 END;
 
 dbms_output.put_line('Tablespace count found: '||count_checker);
 
 BEGIN
 select TBS_NAME into stg_tbs from (select tablespace_name TBS_NAME, sum(bytes/1048576) As CurrentUsage, sum(maxbytes/1048576) AS MAXIMUM_ALLOCATION  from dba_data_files group by tablespace_name) where CurrentUsage/MAXIMUM_ALLOCATION*100 > threshold_val and rownum=1;
   EXCEPTION
   WHEN NO_DATA_FOUND THEN 
   dbms_output.put_line('No tablespace above threshold.');
 END;
 
 dbms_output.put_line('Tablespace name-found: '||stg_tbs);
 IF count_checker > 0 THEN
 dbms_output.put_line('Adding 1 datafile to: '||stg_tbs);
  add_df_space_string := 'alter tablespace '||stg_tbs||' add datafile ' || storage_string ||' size 8m autoextend on next '||next_size||'  maxsize unlimited';
  dbms_output.put_line(add_df_space_string);
  dbms_lock.sleep(10);
  count_checker := 0;
 END IF;
 
 BEGIN
  select count(*) into count_checker from (select tablespace_name TBS_NAME, sum(bytes/1048576) As CurrentUsage, sum(maxbytes/1048576) AS MAXIMUM_ALLOCATION  from dba_data_files group by tablespace_name) where CurrentUsage/MAXIMUM_ALLOCATION*100 > threshold_val;
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
