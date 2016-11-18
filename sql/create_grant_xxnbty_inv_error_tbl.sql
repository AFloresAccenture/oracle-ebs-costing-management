----------------------------------------------------------------------------------------------------
/*
Table Name: GRANT for xxnbty_inv_error_tbl
Author's Name: Albert John Flores
Date written: 23-Feb-2016
RICEFW Object: INT01
Description: Define the grants for SELECT, INSERT, UPDATE on storage table.
Program Style: 

Maintenance History: 

Date			Issue#		Name					Remarks	
-----------		------		-----------				------------------------------------------------
23-Feb-2016					Albert Flores			Initial Development

*/
----------------------------------------------------------------------------------------------------

--[PUBLIC SYNONYM xxnbty_inv_error_tbl]
	GRANT SELECT, INSERT, UPDATE ON xxnbty.xxnbty_inv_error_tbl TO apps;

/

show errors;
