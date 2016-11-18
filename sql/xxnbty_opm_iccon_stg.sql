----------------------------------------------------------------------------------------------------
/*
Table Name: xxnbty_opm_iccon_stg
Author's Name: Khristine Austero
Date written: 23-Feb-2016
RICEFW Object: CONV01
Description: 
Program Style: 

Maintenance History: 

Date			Issue#		Name					Remarks	
-----------		------		-----------				------------------------------------------------
23-Feb-2016					Khristine Austero		Initial Development

*/
----------------------------------------------------------------------------------------------------
CREATE TABLE xxnbty.xxnbty_opm_iccon_stg
(
AS400_NUMBER           NUMBER         
,ITEM_STATUS            VARCHAR2(32)   
,ITEM_NUMBER            VARCHAR2(32)   
,ORGANIZATION_CODE      VARCHAR2(3)    
,ORA_CATEGORY           VARCHAR2(240)  
,MATERIAL_COST          NUMBER         
,MAT_COST_OH_PCNT       NUMBER         
,RESOURCE_COST          NUMBER         
,RES_COST_OH            NUMBER         
,CREATED_BY             NUMBER         
,CREATION_DATE          DATE           
,LAST_UPDATE_DATE       DATE           
,LAST_UPDATE_LOGIN      NUMBER         
,LAST_UPDATED_BY        NUMBER         
,REQUEST_ID             NUMBER         
,RECORD_STATUS          VARCHAR2(32)   
,ERROR_DESCRIPTION      VARCHAR2(1000) 
,SOURCE_TYPE            VARCHAR2(32)   
,FG_MTL_COST            NUMBER         
)

/

show errors;
