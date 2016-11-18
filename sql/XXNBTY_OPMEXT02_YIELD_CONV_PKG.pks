CREATE OR REPLACE PACKAGE   XXNBTY_OPMEXT02_YIELD_CONV_PKG
----------------------------------------------------------------------------------------------------
/*
Package Name: XXNBTY_OPMEXT02_YIELD_CONV_PKG
Author's Name: Albert John Flores
Date written: 26-Aug-2016
RICEFW Object: EXT02
Description: This program creates process operations, routings and automates yield costs load
Program Style: 
 
Maintenance History: 

Date            Issue#      Name                    Remarks 
-----------     ------      -----------             ------------------------------------------------
26-Aug-2016                 Albert Flores           Initial Development
30-Sep-2016					Albert Flores			Added Yield Res Update

*/
----------------------------------------------------------------------------------------------------  
IS  

	  
	  g_user			NUMBER 						:= fnd_global.user_id; 
	  g_resp_id		    NUMBER						:= fnd_global.resp_id;
	  g_resp_appl_id	NUMBER						:= fnd_global.resp_appl_id;
	  
  --Main procedure
  PROCEDURE main_proc(o_errbuf      OUT VARCHAR2, 
						  o_retcode     OUT NUMBER);
						  
  --Procedure to open inventory periods
  PROCEDURE create_oprt_rsrc     ( 	  o_errbuf      OUT VARCHAR2, 
									  o_retcode     OUT NUMBER
									  );
                                
  --Procedure to update resource
  PROCEDURE update_resource		( 	  o_errbuf      OUT VARCHAR2, 
									  o_retcode     OUT NUMBER
									  ); 

  --Procedure to update yield resource
  PROCEDURE calculate_yield_upd		( 	  o_errbuf      OUT VARCHAR2, 
									  o_retcode     OUT NUMBER
									  );       									  
END XXNBTY_OPMEXT02_YIELD_CONV_PKG; 

/

show errors;
