----------------------------------------------------------------------------------------------------
/*
Table Name: Public Synonym for ego_catalog_groups_v
Author's Name: Khristine Austero
Date written: 23-Feb-2016
RICEFW Object: RCV-INT
Description: Public synonym for the Error table apps.ego_catalog_groups_v
Program Style: 

Maintenance History: 

Date			Issue#		Name					Remarks	
-----------		------		-----------				------------------------------------------------
23-Feb-2016					Khristine Austero		Initial Development

*/
----------------------------------------------------------------------------------------------------

--[PUBLIC SYNONYM ego_catalog_groups_v]
CREATE OR REPLACE PUBLIC SYNONYM ego_catalog_groups_v for apps.ego_catalog_groups_v;

/

show errors;
