----------------------------------------------------------------------------------------------------
/*
Table Name: xxnbty_cm_iccon_fl_stg
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

CREATE TABLE xxnbty.xxnbty_cm_iccon_fl_stg
(
AS400_NUMBER              NUMBER         
,ITEM_STATUS               VARCHAR2(32)   
,ITEM_NUMBER               VARCHAR2(32)   
,ORGANIZATION_CODE         VARCHAR2(3)    
,ORA_CATEGORY              VARCHAR2(240)  
,MATERIAL_COST             NUMBER         
,MAT_COST_OH_PCNT          NUMBER         
,RESOURCE_COST             NUMBER         
,OVERHEAD                  NUMBER         
,MAT_COST_OH               NUMBER         
,RES_COST_OH               NUMBER         
,YIELD_RES_COST            NUMBER         
,INVENTORY_ITEM_ID         NUMBER         
,COST_TYPE_ID              NUMBER         
,ORGANIZATION_ID           NUMBER         
,RESOURCE_ID               NUMBER         
,USAGE_RATE_OR_AMOUNT      NUMBER         
,COST_ELEMENT_ID           NUMBER         
,PROCESS_FLAG              NUMBER         
,CREATED_BY                NUMBER         
,CREATION_DATE             DATE           
,LAST_UPDATE_DATE          DATE           
,LAST_UPDATE_LOGIN         NUMBER         
,LAST_UPDATED_BY           NUMBER         
,REQUEST_ID                NUMBER         
,SOURCE_TYPE               VARCHAR2(32)   
,RECORD_STATUS             VARCHAR2(32)   
,ERROR_DESCRIPTION         VARCHAR2(1000) 
,RESOURCE_CODE             VARCHAR2(32)   
)

/

show errors;