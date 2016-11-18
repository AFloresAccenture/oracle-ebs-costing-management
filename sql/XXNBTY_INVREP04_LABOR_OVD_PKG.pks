create or replace PACKAGE XXNBTY_INVREP04_LABOR_OVD_PKG
--------------------------------------------------------------------------------------------
/*
Package Name : XXNBTY_INVREP04_LABOR_OVD_PKG
Author's Name: Jan Michael C. Cuales
Date written: 13-May-2016
RICEFW Object: INVREP04
Description: Package that will generate Labor Overhead and Yield Loss Absorption Report in CSV file
Program Style:
Maintenance History:
Date         Issue#  Name                      Remarks
-----------  ------  -------------------      ------------------------------------------------
13-May-2016          Jan Michael C. Cuales    Initial Development

*/
----------------------------------------------------------------------------------------------
 IS
 
 --Procedure that will generate a .out file for Yield and Mtl. Usage Variance Report
 PROCEDURE main_proc ( x_retcode      OUT VARCHAR2
                     , x_errbuf       OUT VARCHAR2
                     , p_entity       VARCHAR2
                     , p_date_from    DATE
                     , p_date_to      DATE
                     , p_org          VARCHAR2
                     , p_item_num     VARCHAR2 ) ;
               
END XXNBTY_INVREP04_LABOR_OVD_PKG;

/

show errors;
