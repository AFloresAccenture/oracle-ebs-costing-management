----------------------------------------------------------------------------------------------------
/*
Table Name: GRANT for xxnbty_cm_iccon_fl_stg
Author's Name: Khristine Austero
Date written: 23-Feb-2016
RICEFW Object: CNV01
Description: Define the grants for SELECT, INSERT, UPDATE on storage table.
Program Style: 

Maintenance History: 

Date			Issue#		Name					Remarks	
-----------		------		-----------				------------------------------------------------
23-Feb-2016					Khristine Austero			Initial Development

*/
----------------------------------------------------------------------------------------------------

--[PUBLIC SYNONYM xxnbty_cm_iccon_fl_stg]
	GRANT SELECT, INSERT, UPDATE ON xxnbty.xxnbty_cm_iccon_fl_stg TO apps;

/

show errors;
