create or replace PACKAGE       XXNBTY_INVREP02_YLD_USAGE_PKG 
 ---------------------------------------------------------------------------------------------
  /*
  Package Name  : XXNBTY_INVREP02_YLD_USAGE_PKG
  Author's Name: Albert John Flores
  Date written: 12-May-2016
  RICEFW Object: INT01
  Description: Package that will generate Yield and Mtl. Usage Variance Report in CSV file
  Program Style:
  Maintenance History:
  Date         Issue#  Name                         Remarks
  -----------  ------  -------------------      ------------------------------------------------
  12-May-2016          Albert John Flores       Initial Development

  */
  ----------------------------------------------------------------------------------------------
 IS
 
 --Procedure that will generate a .out file for Yield and Mtl. Usage Variance Report
 PROCEDURE main_proc ( x_retcode   OUT VARCHAR2
                      ,x_errbuf    OUT VARCHAR2
                      ,p_date_from      DATE
                      ,p_date_to        DATE
                      ,p_batch_id       VARCHAR2
                      ,p_trn_type       VARCHAR2
                      ,p_item_num       VARCHAR2 
                      ,p_batch_comp     VARCHAR2 ) ;
                    
END XXNBTY_INVREP02_YLD_USAGE_PKG;

/

show errors;
