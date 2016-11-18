-- *****************************************************************************************************
--                                                                                                     *
-- Name         : opm_ext02_a.ctl                                                                      * 
-- Object Type  : SQL Loader Script                                                                    *
-- Title        : Control File                                                                         *
-- Description  : load data to the operations staging table                                            *
-- Calls        : None                                                                                 *
-- Source       :                                                                                      *
-- Parameters   : File Name                                                                            *
-- Return Values: None                                                                                 *
--                                                                                                     *
-- VERSION   DATE(DD.MM.YYYY)         AUTHOR               DESCRIPTION                                 *
--  1.0         06.09.2016            Albert Flores        Initial Draft                               *
--                                                                                                     *
-- *****************************************************************************************************
OPTIONS (SKIP=1)
LOAD DATA
INFILE '$1'
TRUNCATE
INTO TABLE xxnbty.xxnbty_operations_stg_tbl
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
TRAILING NULLCOLS
(       
        OPRN_NO                             "TRIM (:OPRN_NO)"
        ,OPRN_DESC                          "TRIM (:OPRN_DESC)"
        ,ITEM_NUMBER                        "TRIM (:ITEM_NUMBER)"
        ,EFFECTIVE_START_DATE               "TRIM (:EFFECTIVE_START_DATE)"
        ,ORGANIZATION_CODE                  "TRIM (:ORGANIZATION_CODE)"
        ,ACTIVITY                           "TRIM (:ACTIVITY)"
        ,RESOURCES                          "TRIM (:RESOURCES)"
        ,PROCESS_QTY                        "TRIM (:PROCESS_QTY)"
        ,RESOURCE_USAGE                     "TRIM (:RESOURCE_USAGE)"
        ,CREATION_DATE                      SYSDATE
        ,LAST_UPDATE_DATE                   SYSDATE
        ,CREATED_BY                         CONSTANT '-1'
        ,LAST_UPDATED_BY                    CONSTANT '-1'
        ,LAST_UPDATE_LOGIN                  CONSTANT '-1'
)