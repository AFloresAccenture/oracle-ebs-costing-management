----------------------------------------------------------------------------------------------------
/*
Table Name: GRANT for XXNBTY_INV_TXN_STG1
Author's Name: Albert John Flores
Date written: 17-Feb-2016
RICEFW Object: INT01
Description: Define the grants for SELECT, INSERT, UPDATE on storage table.
Program Style: 

Maintenance History: 

Date			Issue#		Name					Remarks	
-----------		------		-----------				------------------------------------------------
17-Feb-2016					Albert Flores			Initial Development

*/
----------------------------------------------------------------------------------------------------

--[PUBLIC SYNONYM xxnbty_inv_txn_stg1]
	GRANT SELECT, INSERT, UPDATE ON xxnbty.xxnbty_inv_txn_stg1 TO apps;

/

show errors;

