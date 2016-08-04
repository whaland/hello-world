-----------------------------------------------------------------------------
-- (c) Copyright IBM Corp. 2013 All rights reserved.
--
-- The following sample of source code ("Sample") is owned by International
-- Business Machines Corporation or one of its subsidiaries ("IBM") and is
-- copyrighted and licensed, not sold. You may use, copy, modify, and
-- distribute the Sample in any form without payment to IBM, for the purpose of
-- assisting you in the development of your applications.
--
-- The Sample code is provided to you on an "AS IS" basis, without warranty of
-- any kind. IBM HEREBY EXPRESSLY DISCLAIMS ALL WARRANTIES, EITHER EXPRESS OR
-- IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
-- MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. Some jurisdictions do
-- not allow for the exclusion or limitation of implied warranties, so the above
-- limitations or exclusions may not apply to you. IBM shall not be liable for
-- any damages you suffer as a result of using, copying, modifying or
-- distributing the Sample, even if IBM has been advised of the possibility of
-- such damages.
-----------------------------------------------------------------------------
--
-- SOURCE FILE NAME: sqltrace.db2
--
-- SAMPLE: This script creates the a set of objects used to trace execution
--         of SQL statements by a particular application. The following
--         objects are created:
--         * Activity event monitor (TRACE_EVMON)
--         * Data table for traced statements (TRACE_DATA)
--         * View for traced statements (TRACE)
--         * A pair of procedures to enable/disable tracing (TRACE_ON/TRACE_OFF)
--
-- All objects are created in the SQLTRACE schema.
--
-- The SQL trace facility implemented by this script is described 
-- in the white paper "Monitoring in DB2: SQL Trace Using an Activity Event 
-- Monitor".  
--
-----------------------------------------------------------------------------
--
-- USAGE: 
--
--    1. Connect to your database. 
--
--    2. Use the following command to execute this script. This sample uses
--       @ as the delimiting character.
--
--          db2 -td@ -vf sqltrace.db2
--
--    3. Reset the connection.
--
-----------------------------------------------------------------------------


DROP PROCEDURE SQLTRACE.TRACE_OFF@
DROP PROCEDURE SQLTRACE.TRACE_ON@
DROP VIEW SQLTRACE.TRACE@
DROP TABLE SQLTRACE.TEMP_TRACE_DATA@
-- DROP TABLESPACE USERTEMP1@

SET EVENT MONITOR TRACE_EVMON STATE 0@
DROP EVENT MONITOR TRACE_EVMON@
DROP TABLE SQLTRACE.ACTIVITY_TRACE_EVMON@
DROP TABLE SQLTRACE.ACTIVITYSTMT_TRACE_EVMON@
DROP TABLE SQLTRACE.ACTIVITYVALS_TRACE_EVMON@
DROP TABLE SQLTRACE.ACTIVITYMETRICS_TRACE_EVMON@
DROP TABLE SQLTRACE.CONTROL_TRACE_EVMON@

CREATE EVENT MONITOR TRACE_EVMON
    FOR ACTIVITIES
    WRITE TO TABLE
    ACTIVITY (TABLE SQLTRACE.ACTIVITY_TRACE_EVMON
              IN USERSPACE1
              PCTDEACTIVATE 100),
    ACTIVITYSTMT (TABLE SQLTRACE.ACTIVITYSTMT_TRACE_EVMON
                  IN USERSPACE1
                  PCTDEACTIVATE 100),
    ACTIVITYVALS (TABLE SQLTRACE.ACTIVITYVALS_TRACE_EVMON
                  IN USERSPACE1
                  PCTDEACTIVATE 100),
    ACTIVITYMETRICS (TABLE SQLTRACE.ACTIVITYMETRICS_TRACE_EVMON
                  IN USERSPACE1
                  PCTDEACTIVATE 100),
    CONTROL (TABLE SQLTRACE.CONTROL_TRACE_EVMON
             IN USERSPACE1
             PCTDEACTIVATE 100)
    AUTOSTART@

-- Trace data is extracted into a created temporary table. 
-- The line below can be uncommented to create a user temporary
-- table space if none already exists. 
-- 
-- CREATE USER TEMPORARY TABLESPACE USERTEMP1 MANAGED BY AUTOMATIC STORAGE@


--------------------------------------------------------
--
-- Per-session temporary table used to hold trace data
-- extracted from the activity event monitor for a 
-- given connection that was traced. 
--
--------------------------------------------------------
CREATE GLOBAL TEMPORARY TABLE SQLTRACE.TEMP_TRACE_DATA ( 
         TIME_CREATED       TIMESTAMP, 
         STMT_TEXT          VARCHAR(50),
         STMT_CPU           BIGINT,
         STMT_ROWS_READ     BIGINT,
         AGG_CPU            BIGINT,
         AGG_ROWS_READ      BIGINT ) 
ON COMMIT PRESERVE ROWS@

CREATE VIEW SQLTRACE.TRACE AS 
   SELECT * FROM (SELECT STMT_TEXT,
                         STMT_CPU,
                         STMT_ROWS_READ,
                         AGG_CPU,
                         AGG_ROWS_READ
                  FROM SQLTRACE.TEMP_TRACE_DATA
                  ORDER BY TIME_CREATED ASC)@


--------------------------------------------------------
--
-- Turn on trace for a connection identified by the 
-- input application handle parameter. If no application
-- handle is provided trace is turned on for the current
-- connection. 
--
--------------------------------------------------------
CREATE PROCEDURE SQLTRACE.TRACE_ON( IN APPHANDLE BIGINT DEFAULT NULL )
LANGUAGE SQL
BEGIN
   DECLARE CONTINUE HANDLER FOR SQLEXCEPTION BEGIN END;

   --
   -- Cleanup temp table used to store trace info extracted
   -- from the event monitor. Also clean up any statements already
   -- captured in the event monitor for the input application 
   -- handle so that trace only reports statements issued AFTER
   -- the call to the TRACE_ON procedure
   --
   DELETE FROM SQLTRACE.TEMP_TRACE_DATA WHERE ;
   DELETE FROM SQLTRACE.ACTIVITYMETRICS_TRACE_EVMON A
      WHERE (A.APPL_ID, A.UOW_ID, A.ACTIVITY_ID) IN 
               (SELECT B.APPL_ID, B.UOW_ID, B.ACTIVITY_ID 
                FROM SQLTRACE.ACTIVITY_TRACE_EVMON B 
                WHERE ((APPHANDLE IS NULL AND B.AGENT_ID = SYSPROC.MON_GET_APPLICATION_HANDLE()) OR
                        APPHANDLE = B.AGENT_ID));
   DELETE FROM SQLTRACE.ACTIVITYSTMT_TRACE_EVMON A
      WHERE (A.APPL_ID, A.UOW_ID, A.ACTIVITY_ID) IN 
               (SELECT B.APPL_ID, B.UOW_ID, B.ACTIVITY_ID 
                FROM SQLTRACE.ACTIVITY_TRACE_EVMON B 
                WHERE ((APPHANDLE IS NULL AND B.AGENT_ID = SYSPROC.MON_GET_APPLICATION_HANDLE()) OR
                        APPHANDLE = B.AGENT_ID));
   DELETE FROM SQLTRACE.ACTIVITY_TRACE_EVMON A
      WHERE ((APPHANDLE IS NULL AND A.AGENT_ID = SYSPROC.MON_GET_APPLICATION_HANDLE()) OR 
             (APPHANDLE = A.AGENT_ID));

   --
   -- Make sure the event monitor has been activated
   --
   EXECUTE IMMEDIATE 'SET EVENT MONITOR TRACE_EVMON STATE 1';

   -- 
   -- Turn on collection of statements for the input
   -- application
   --
   CALL WLM_SET_CONN_ENV( APPHANDLE, 
                          '<collectactdata>WITH DETAILS, SECTION</collectactdata><collectactpartition>ALL</collectactpartition>'); 
END@


--------------------------------------------------------
--
-- Turn off trace for a connection identified by the 
-- input application handle parameter. If no application
-- handle is provided trace is turned off for the current
-- connection. 
--
--------------------------------------------------------
CREATE PROCEDURE SQLTRACE.TRACE_OFF( IN APPHANDLE BIGINT DEFAULT NULL )
LANGUAGE SQL
BEGIN
   DECLARE CONTINUE HANDLER FOR SQLEXCEPTION BEGIN END;

   --
   -- Disable collection of statements for the input
   -- application
   --
   CALL WLM_SET_CONN_ENV( APPHANDLE, 
                          '<collectactdata>NONE</collectactdata>'); 

   -- 
   -- Extract information about all statements executed by
   -- the input application from the event monitor and store
   -- in the temporary trace data table. Information includes
   -- a few key processing metrics (reported per statement and
   -- aggregated by parent statement using recursive SQL).
   --
   INSERT INTO SQLTRACE.TEMP_TRACE_DATA 
      WITH ACT( APPL_ID, 
                UOW_ID, 
                ACTIVITY_ID, 
                AGENT_ID,
                PARENT_UOW_ID, 
                PARENT_ACTIVITY_ID, 
                CPU, 
                ROWS_READ,
                TIME_CREATED ) AS
      (SELECT A.APPL_ID, 
              A.UOW_ID, 
              A.ACTIVITY_ID,
              A.AGENT_ID,
              MAX(A.PARENT_UOW_ID),
              MAX(A.PARENT_ACTIVITY_ID), 
              SUM(B.TOTAL_CPU_TIME),
              SUM(B.ROWS_READ),
              MIN(TIME_CREATED)
       FROM SQLTRACE.ACTIVITY_TRACE_EVMON AS A,
            SQLTRACE.ACTIVITYMETRICS_TRACE_EVMON AS B
       WHERE A.APPL_ID = B.APPL_ID AND
             A.UOW_ID = B.UOW_ID AND
             A.ACTIVITY_ID = B.ACTIVITY_ID
       GROUP BY A.APPL_ID, A.UOW_ID, A.ACTIVITY_ID, A.AGENT_ID ),
           TMP( BASE_APPL_ID,
                BASE_UOW_ID, 
                BASE_ACTIVITY_ID, 
                APPL_ID, 
                UOW_ID, 
                ACTIVITY_ID, 
                PARENT_UOW_ID, 
                PARENT_ACTIVITY_ID, 
                CPU, 
                ROWS_READ, 
                LEVEL ) AS 
      (SELECT APPL_ID, 
              UOW_ID, 
              ACTIVITY_ID, 
              APPL_ID, 
              UOW_ID, 
              ACTIVITY_ID,
              PARENT_UOW_ID, 
              PARENT_ACTIVITY_ID, 
              CPU, 
              ROWS_READ,  
              1 
       FROM ACT 
      UNION ALL
       SELECT TMP.BASE_APPL_ID,
              TMP.BASE_UOW_ID, 
              TMP.BASE_ACTIVITY_ID, 
              ACT.APPL_ID, 
              ACT.UOW_ID, 
              ACT.ACTIVITY_ID, 
              ACT.PARENT_UOW_ID, 
              ACT.PARENT_ACTIVITY_ID, 
              ACT.CPU, 
              ACT.ROWS_READ,  
              LEVEL + 1
       FROM ACT, TMP 
       WHERE ACT.APPL_ID = TMP.APPL_ID AND 
             ACT.PARENT_UOW_ID = TMP.UOW_ID AND 
             ACT.PARENT_ACTIVITY_ID = TMP.ACTIVITY_ID AND 
             LEVEL < 128 ),
           AGG( APPL_ID, 
                UOW_ID, 
                ACTIVITY_ID,
                CPU, 
                ROWS_READ ) AS 
      (SELECT BASE_APPL_ID, 
              BASE_UOW_ID, 
              BASE_ACTIVITY_ID, 
              SUM(CPU), 
              SUM(ROWS_READ) 
       FROM TMP 
       GROUP BY BASE_APPL_ID, BASE_UOW_ID, BASE_ACTIVITY_ID)
      SELECT A.TIME_CREATED, 
             SUBSTR(CONCAT(REPEAT('  ', C.STMT_NEST_LEVEL), 
             SUBSTR(C.STMT_TEXT,1,50)),1,50) AS TEXT, 
             A.CPU AS STMT_CPU, 
             A.ROWS_READ AS STMT_ROWS_READ,
             B.CPU AS AGG_CPU,
             B.ROWS_READ AS AGG_ROWS_READ
      FROM ACT AS A, AGG AS B, SQLTRACE.ACTIVITYSTMT_TRACE_EVMON AS C
      WHERE A.APPL_ID = B.APPL_ID AND 
            A.UOW_ID = B.UOW_ID AND 
            A.ACTIVITY_ID = B.ACTIVITY_ID AND 
            A.APPL_ID = C.APPL_ID AND 
            A.UOW_ID = C.UOW_ID AND 
            A.ACTIVITY_ID = C.ACTIVITY_ID AND 
            ((APPHANDLE IS NULL AND A.AGENT_ID = SYSPROC.MON_GET_APPLICATION_HANDLE()) OR 
             (APPHANDLE = A.AGENT_ID));
END@

