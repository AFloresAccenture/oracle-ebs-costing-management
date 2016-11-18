----------------------------------------------------------------------------------------------------
/*
Table Name: XXNBTY_INV_ERROR_TBL
Author's Name: Albert John Flores
Date written: 30-Apr-2016
RICEFW Object: INT01
Description: alter table query for error table
Program Style: 

Maintenance History: 

Date            Issue#      Name                    Remarks 
-----------     ------      -----------             ------------------------------------------------
30-Apr-2016                 Albert Flores           Initial Development

*/
----------------------------------------------------------------------------------------------------

ALTER TABLE xxnbty.xxnbty_inv_error_tbl
	ADD PRODUCING_ORG		VARCHAR2(50)

/

show errors;
