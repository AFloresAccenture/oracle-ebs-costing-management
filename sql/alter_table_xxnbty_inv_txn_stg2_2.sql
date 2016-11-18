----------------------------------------------------------------------------------------------------
/*
Table Name: XXNBTY_INV_TXN_STG2
Author's Name: Albert John Flores
Date written: 05-July-2016
RICEFW Object: INT01
Description: alter table query for staging table 2 for additional columns
Program Style: 

Maintenance History: 

Date            Issue#      Name                    Remarks 
-----------     ------      -----------             ------------------------------------------------
05-July-2016                 Albert Flores           Initial Development

*/
----------------------------------------------------------------------------------------------------

ALTER TABLE xxnbty.xxnbty_inv_txn_stg2
	ADD (
		  LEGACY_REASON_CODE		VARCHAR2(10)
		 ,LEGACY_TXN_TYPE_CODE		VARCHAR2(10)
		 ,LEGACY_WAREHOUSE_SND		NUMBER
		 ,LEGACY_WAREHOUSE_RCV		NUMBER
		 ,LEGACY_PALLET_NUM 		NUMBER
		)

/

show errors;
