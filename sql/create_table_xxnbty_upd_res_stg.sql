----------------------------------------------------------------------------------------------------
/*
Table Name: xxnbty_upd_res_stg
Author's Name: Albert John Flores
Date written: 06-Sept-2016
RICEFW Object: EXT02
Description: Staging table for update resources
Program Style: 

Maintenance History: 

Date            Issue#      Name                    Remarks 
-----------     ------      -----------             ------------------------------------------------
06-Sept-2016                Albert Flores           Initial Development

*/
----------------------------------------------------------------------------------------------------

CREATE TABLE xxnbty.xxnbty_upd_res_stg
(
        item_number                             VARCHAR2(100)
		,resources								VARCHAR2(100)
        ,column_to_upd                          VARCHAR2(100) DEFAULT ('RESOURCE_USAGE')
		,new_value								NUMBER
		,process_flag							VARCHAR2(10)
		,error_description                      VARCHAR2 (1000)
		,last_update_date          DATE
		,last_updated_by           NUMBER
		,creation_date             DATE
		,created_by                NUMBER
		,last_update_login         NUMBER 
)

/

show errors;
