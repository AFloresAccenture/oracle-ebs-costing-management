create or replace PACKAGE        "XXNBTY_INV_REP04_ABS_PKG" 
--------------------------------------------------------------------------------------------
/*
Package Name: XXNBTY_INV_REP04_ABS_PKG
Author's Name: Albert John Flores
Date written: 29-Mar-2016
RICEFW Object: REP04
Description: This program will submit the concurrent program that will generate XXNBTY Labor, Overhead and Yield Loss Absorption Report and send email to the recipients
Program Style: 

Maintenance History: 

Date			Issue#		Name					Remarks	
-----------		------		-----------				------------------------------------------------
29-Mar-2016					Albert Flores			Initial Development

*/
--------------------------------------------------------------------------------------------
IS
							   
  --subprocedure that will generate error output file and send to recipients. 
  PROCEDURE generate_report (x_retcode  	OUT VARCHAR2, 
                             x_errbuf   	OUT VARCHAR2
							 ,p_date_from	DATE
							 ,p_date_to		DATE
							 ,p_org			VARCHAR2
							 ,p_item_num	VARCHAR2
							 ,p_recipients	VARCHAR2);
                              
END XXNBTY_INV_REP04_ABS_PKG; 

/

show errors;
