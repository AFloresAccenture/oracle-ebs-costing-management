create or replace PACKAGE       XXNBTY_INVINT01_INT_ERR_PKG 
 ---------------------------------------------------------------------------------------------
  /*
  Package Name	: XXNBTY_INVINT01_INT_ERR_PKG
  Author's Name: Albert John Flores
  Date written: 29-Mar-2016
  RICEFW Object: INT01
  Description: Package that will generate detailed error log for Inventory interface table using FND_FILE. 
  Program Style:
  Maintenance History:
  Date         Issue#  Name         			    Remarks
  -----------  ------  -------------------		------------------------------------------------
  29-Mar-2016          Albert John Flores	  	Initial Development

  */
  ----------------------------------------------------------------------------------------------
 IS
 
 --Procedure that will generate a .out file for the detailed error report
 PROCEDURE main_proc ( x_retcode   OUT VARCHAR2
				      ,x_errbuf    OUT VARCHAR2
					  ,p_request_id		NUMBER);
					
END XXNBTY_INVINT01_INT_ERR_PKG;

/

show errors;
					