----------------------------------------------------------------------------------------------------
/*
Table Name: GRANT for xxnbty_upd_res_stg
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

--[PUBLIC SYNONYM xxnbty_upd_res_stg]
	GRANT SELECT, INSERT, UPDATE ON xxnbty.xxnbty_upd_res_stg TO apps;

/

show errors;

