----------------------------------------------------------------------------------------------------
/*
Table Name: XXNBTY_INV_TXN_STG1
Author's Name: Albert John Flores
Date written: 10-Feb-2016
RICEFW Object: INT01
Description: Staging table for Inventory Transactions Interface
Program Style: 

Maintenance History: 

Date            Issue#      Name                    Remarks 
-----------     ------      -----------             ------------------------------------------------
10-Feb-2016                 Albert Flores           Initial Development

*/
----------------------------------------------------------------------------------------------------

CREATE TABLE xxnbty.xxnbty_inv_txn_stg1
(
        source_code                             VARCHAR2(30)
        ,source_line_id                         NUMBER
        ,source_header_id                       NUMBER
        ,process_flag                           NUMBER          DEFAULT (1)
        ,transaction_mode                       NUMBER          DEFAULT (3)
        ,item_segment1                          VARCHAR2(40) 
        ,organization_id                        NUMBER
        ,transaction_quantity                   NUMBER          NOT NULL
        ,transaction_uom                        VARCHAR2(3)     NOT NULL
        ,transaction_date                       DATE            NOT NULL
        ,subinventory_code                      VARCHAR2(10) 
        ,dsp_segment1                           VARCHAR2(40) 
        ,dsp_segment2                           VARCHAR2(40) 
        ,dsp_segment3                           VARCHAR2(40) 
        ,dsp_segment4                           VARCHAR2(40) 
        ,dsp_segment5                           VARCHAR2(40) 
        ,dsp_segment6                           VARCHAR2(40) 
        ,dsp_segment7                           VARCHAR2(40) 
        ,dsp_segment8                           VARCHAR2(40) 
        ,dst_segment1                           VARCHAR2(40) 
        ,dst_segment2                           VARCHAR2(40) 
        ,dst_segment3                           VARCHAR2(40) 
        ,dst_segment4                           VARCHAR2(40) 
        ,dst_segment5                           VARCHAR2(40) 
        ,dst_segment6                           VARCHAR2(40) 
        ,dst_segment7                           VARCHAR2(40) 
        ,dst_segment8                           VARCHAR2(40) 
        ,transaction_type_id                    NUMBER
        ,transaction_reference                  VARCHAR2(240) 
        ,vendor_lot_number                      VARCHAR2(30) 
        ,transfer_subinventory                  VARCHAR2(10) 
        ,transfer_organization                  NUMBER 
        ,shipment_number                        VARCHAR2(30) 
        ,lot_number                             VARCHAR2(150)
        ,batch_complete                         VARCHAR2(150)
        ,batch_size                             VARCHAR2(150) 
        ,batch_completion_date                  VARCHAR2(150)
        ,reason_code                            VARCHAR2(10)    DEFAULT ('BLANK')
        ,transaction_code                       VARCHAR2(10)    NOT NULL
        ,status_code                            VARCHAR2(10) 
        ,as400_source_warehouse                 VARCHAR2(30)    NOT NULL
        ,as400_dest_warehouse                   VARCHAR2(30)
        ,status_flag                            VARCHAR2(10)    DEFAULT ('NEW')
        ,error_description                      VARCHAR2 (1000)
        ,last_update_date                       DATE
        ,last_updated_by                        NUMBER
        ,creation_date                          DATE
        ,created_by                             NUMBER
        ,last_update_login                      NUMBER 
		,CONSTRAINT source_header_pk PRIMARY KEY (source_header_id)
)

/

show errors;
