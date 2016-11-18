-- *************************************************************************************
--                                                                                     *
-- Name         : opm_cnv01.ctl                                                        * 
-- Object Type  : SQL Loader Script                                                    *
-- Title        : Control File                                                         *
-- Description  : This script will load the data into the Staging table from data file *
-- Calls        : None                                                                 *
-- Source       :                                                                      *
-- Parameters   : File Name                                                            *
-- Return Values: None                                                                 *
--                                                                                     *
-- VERSION   DATE(DD.MM.YYYY)         AUTHOR               DESCRIPTION                 *
--  1.0         02.25.2016             KLDA     This script will load the data into    *
--                                                 the Staging table from data file    *
-- *************************************************************************************
-- /* $Header: opm_cnv01.ctl 120.1 2016/25/02 12:00:00 Austero, Khristine$*/
OPTIONS (SKIP=1)
LOAD DATA
CHARACTERSET AL32UTF8
INFILE '&1'
APPEND
INTO TABLE XXNBTY.XXNBTY_OPM_ICCON_STG
FIELDS TERMINATED BY "," OPTIONALLY ENCLOSED BY '"'
TRAILING NULLCOLS
(
AS400_NUMBER        "TRIM(:AS400_NUMBER)"   
,ITEM_STATUS        "TRIM(:ITEM_STATUS)"
,ITEM_NUMBER        "TRIM(:ITEM_NUMBER)"
,ORGANIZATION_CODE  "TRIM(:ORGANIZATION_CODE)"
,ORA_CATEGORY       "TRIM(:ORA_CATEGORY)"
,MATERIAL_COST      "TRIM(:MATERIAL_COST)"
,MAT_COST_OH_PCNT   "TRIM(:MAT_COST_OH_PCNT)"
,RESOURCE_COST      "TRIM(:RESOURCE_COST)"
,RES_COST_OH        "TRIM(:RES_COST_OH)"
,CREATED_BY         "NULL"
,CREATION_DATE      "NULL"
,LAST_UPDATE_DATE   "NULL"
,LAST_UPDATE_LOGIN  "NULL"
,LAST_UPDATED_BY    "NULL"
,REQUEST_ID         "NULL"
,RECORD_STATUS      CONSTANT 'NEW'
,ERROR_DESCRIPTION  "NULL"
,SOURCE_TYPE        CONSTANT 'AS400'
,FG_MTL_COST        "NULL"
)