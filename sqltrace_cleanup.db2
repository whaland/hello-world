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
-- SOURCE FILE NAME: sqltrace_cleanup.db2
--
-- SAMPLE: This script drops the set of objects created by the sqltrace.db2
--         script. 
--
-- The SQL trace facility implemented by this script is described in the white paper
-- "Monitoring in DB2: SQL Trace Using an Activity Event Monitor".  
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
--          db2 -td@ -vf sqltrace_cleanup.db2
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



