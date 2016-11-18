-- *****************************************************************************************************
--                                                                                                     *
-- Name         : opm_ext02_b.ctl                                                                      * 
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
INTO TABLE xxnbty.xxnbty_upd_res_stg
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
TRAILING NULLCOLS
(       
        ITEM_NUMBER         "TRIM (:ITEM_NUMBER)"
        ,RESOURCES          "TRIM (:RESOURCES)"
        ,NEW_VALUE          "TRIM (:NEW_VALUE)"
        ,CREATION_DATE      SYSDATE
        ,LAST_UPDATE_DATE   SYSDATE
        ,CREATED_BY         CONSTANT '-1'
        ,LAST_UPDATED_BY    CONSTANT '-1'
        ,LAST_UPDATE_LOGIN  CONSTANT '-1'
)