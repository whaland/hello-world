--This query returns the table schema, table name, index name, index full key cardinality, table 
--cardinality, and the index cardinality percentage of the table's cardinality, for indexes where the 
--cardinality percentage is less than 60% (excluding the catalog tables which we can't do anything about).
--75% or higher is an admirable goal. Unique indexes will have a 100% ratio. The higher the ratio, the 
--less expensive the index will be to maintain on Inserts, Updates, and Deletes, and the more useful the 
--index might be for quickly and efficiently retrieving result sets. Said another way, high quality indexes 
--with a high cardinality percentage can help improve Index Read Efficiency (IREF).
--This is not to say that indexes with a very low cardinality as a percentage of the table's cardinality
--will not be useful, or will not be used by the optimizer as part of the access plan. To my surprise, in 
--one of my test workloads, the optimizer chooses to use an index with a cardinality of < 1% of the table's 
--cardinality. Apparently when you are extremely thirsty even dirty pond water has some appeal, 
--and so it is true with DB2 deciding that a crummy index is better than none. Still, the performance 
--attributes are horrific compared to the results obtained with a better physical design.
 


select char(a.tabschema,8 ) as schema, 
       char(a.tabname,18 ) as table, 
       char(a.indname,18 ) as index, 
       a.fullkeycard as IXFULLKEYCARD, 
       b.card as TBCARD, 
       int((float(a.fullkeycard)/float(b.card)) * 100) as ratio 
from syscat.indexes a inner join syscat.tables b 
                    on a.tabschema = b.tabschema and a.tabname = b.tabname 
where a.tabname in ('ACCTHIST','ADDRESS','CEMTEX','CERTIFICATE','CERTIFICATE_ASSOC','CLIENT',
                 'CODE_DESCRIPTION','CONTRIBUTION','DB_BENFACTORS','INV_ACCOUNTS','INV_PROFILE_DETAIL',
                 'INVESTMENT_ELECT','INVESTMENT_PROFILE','INVESTMENT_RULE','JOB','NOTES','PASTHIST',
                 'PENSION_GROSSAMT','PENSION_PAYMENT','RELATIONSHIP','RETURN_DETAIL','TRANS_HISTORY_ALL',
                 'XREF_MEMBER_MATCH','ZAM_TRX_DETAIL','ZDB_CONT_RATE','ZDB_LEAVE','ZDB_SALARY','ZGS_MEMBER',
                 'ZMF_ACCOUNTING_TRX','ZMF_EVENT','ZMF_EVENT_DETAIL','ZMF_MEMBER_ACTION','ZMF_REPORT_EVENT',
                 'ZMF_REVIEW_DET','ZUP_PENSIONER','ZUP_TAXCOMP')
and a.fullkeycard > 0
and b.card > 0
--and a.tabschema <> 'SYSIBM' 
--and b.card > 100 
--and a.uniquerule <> 'U' 
--and int((float(a.fullkeycard)/float(b.card)) * 100) < 90 
order by 1, 2, 3
with ur;


