CREATE OR REPLACE PACKAGE   XXNBTY_OPMEXT01_OPEN_PERIOD_PK
----------------------------------------------------------------------------------------------------
/*
Package Name: XXNBTY_OPMEXT01_OPEN_PERIOD_PK
Author's Name: Albert John Flores
Date written: 30-July-2016
RICEFW Object: EXT01
Description: This program opens the entered period as parameter
Program Style: 

Maintenance History: 

Date            Issue#      Name                    Remarks 
-----------     ------      -----------             ------------------------------------------------
30-July-2016                Albert Flores           Initial Development

*/
----------------------------------------------------------------------------------------------------  
IS  
      g_proc_enabled_flag_y          CONSTANT VARCHAR2(1)   := 'Y';
      g_adj_period_flag_n            CONSTANT VARCHAR2(1)   := 'N';
      g_status_f                     CONSTANT VARCHAR2(6)   := 'Future';
      g_status_o                     CONSTANT VARCHAR2(4)   := 'Open';
      g_status_c                     CONSTANT VARCHAR2(6)   := 'Closed';
      g_process_y                    CONSTANT VARCHAR2(1)   := 'Y';
      g_process_n                    CONSTANT VARCHAR2(1)   := 'N';
  --Procedure to open inventory periods
  PROCEDURE open_period     ( o_errbuf      OUT VARCHAR2, 
                              o_retcode     OUT NUMBER,
                              p_period_name  IN VARCHAR2
                              );
                                
                                
END XXNBTY_OPMEXT01_OPEN_PERIOD_PK; 

/

show errors;
