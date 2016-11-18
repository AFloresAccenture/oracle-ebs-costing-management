----------------------------------------------------------------------------------------------------
/*
Table Name: GRANT for xxnbty_operations_stg_tbl
Author's Name: Albert John Flores
Date written: 07-Sept-2016
RICEFW Object: EXT02
Description: Define the grants for SELECT, INSERT, UPDATE on storage table.
Program Style: 

Maintenance History: 

Date			Issue#		Name					Remarks	
-----------		------		-----------				------------------------------------------------
07-Sept-2016					Albert Flores			Initial Development

*/
----------------------------------------------------------------------------------------------------

--[PUBLIC SYNONYM xxnbty_operations_stg_tbl]
	GRANT SELECT, INSERT, UPDATE ON xxnbty.xxnbty_operations_stg_tbl TO apps;

/

show errors;

