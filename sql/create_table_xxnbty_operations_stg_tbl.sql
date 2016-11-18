----------------------------------------------------------------------------------------------------
/*
Table Name: xxnbty_operations_stg_tbl
Author's Name: Albert John Flores
Date written: 06-Sept-2016
RICEFW Object: EXT02
Description: Staging table for create operations
Program Style: 

Maintenance History: 

Date            Issue#      Name                    Remarks 
-----------     ------      -----------             ------------------------------------------------
06-Sept-2016                Albert Flores           Initial Development

*/
----------------------------------------------------------------------------------------------------

CREATE TABLE xxnbty.xxnbty_operations_stg_tbl
(
	 oprn_no                   VARCHAR2(240)  
	,oprn_desc                 VARCHAR2(240) 
	,item_number			   VARCHAR2(240)
	,process_qty_uom           VARCHAR2(3)    
	,oprn_vers                 NUMBER           DEFAULT 1
	,delete_mark               NUMBER           DEFAULT 0
	,effective_start_date      DATE             
	,operation_status          VARCHAR2(30)     DEFAULT '700'
	,organization_code         VARCHAR2(100)  
	,activity                  VARCHAR2(240)  
	,activity_factor           NUMBER     		DEFAULT 1    
	,resources                 VARCHAR2(240)  
	,process_qty               NUMBER         
	,resource_process_uom      VARCHAR2(240)  
	,resource_usage            NUMBER         
	,resource_usage_uom        VARCHAR2(240)  
	,cost_cmpntcls_id          VARCHAR2(240)  
	,cost_analysis_code        VARCHAR2(240)  	DEFAULT 'DIR'
	,prim_rsrc_ind             VARCHAR2(240)  
	,resource_count            NUMBER    		DEFAULT 1     
	,scale_type                VARCHAR2(240)    DEFAULT '1'
	,offset_interval           NUMBER           DEFAULT 0
	,process_flag              VARCHAR2(240)    DEFAULT NULL
	,error_description         VARCHAR2(1000)
	,last_update_date          DATE
	,last_updated_by           NUMBER
	,creation_date             DATE
	,created_by                NUMBER
	,last_update_login         NUMBER 
)

/

show errors;
