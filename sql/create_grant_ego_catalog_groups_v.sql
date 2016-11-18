----------------------------------------------------------------------------------------------------
/*
Table Name: GRANT for ego_catalog_groups_v
Author's Name: Khristine Austero
Date written: 23-Feb-2016
RICEFW Object: RCV-INT
Description: Define the grants for SELECT on storage table.
Program Style: 

Maintenance History: 

Date			Issue#		Name					Remarks	
-----------		------		-----------				------------------------------------------------
23-Feb-2016					Khristine Austero		Initial Development

*/
----------------------------------------------------------------------------------------------------

--[PUBLIC GRANT ego_catalog_groups_v]
	GRANT SELECT ON ego_catalog_groups_v TO bolinf;
/

show errors;
