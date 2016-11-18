CREATE OR REPLACE PACKAGE   XXNBTY_INVINT01_INV_TXN_PKG
----------------------------------------------------------------------------------------------------
/* 
Package Name: XXNBTY_INVINT01_INV_TXN_PKG
Author's Name: Albert John Flores
Date written: 10-Feb-2016
RICEFW Object: INT01
Description: This program derives required fields on the staging table for the new records to be inserted to the interface table
Program Style: 

Maintenance History: 

Date            Issue#      Name                    Remarks 
-----------     ------      -----------             ------------------------------------------------
10-Feb-2016                 Albert Flores           Initial Development
23-Mar-2016                 Albert Flores           Additional changes
29-Mar-2016                 Albert Flores           Added submission of standard program and sending of email
*/
----------------------------------------------------------------------------------------------------
IS  
    g_user_id               NUMBER       := fnd_global.user_id; 

    g_request_id            NUMBER       := fnd_global.conc_request_id;
    g_stndrd_prog_id        NUMBER; 
    g_total_rec             NUMBER       := 0;
    g_valid_rec             NUMBER       := 0;
    g_err_rec               NUMBER       := 0;
    
    --For GTS Receipt
    gts_reason_constant     VARCHAR2(10) := 'TI';
    gts_txn_constant        VARCHAR2(10) := 'A';    
    --For GTS Transfer
    gtrans_reason_constant  VARCHAR2(10) := 'TO';
    gtrans_txn_constant     VARCHAR2(10) := 'D';    
    
    reason_code_constant    VARCHAR2(30) := 'REASON_CODE';
    txn_code_constant       VARCHAR2(30) := 'TRANSACTION_CODE';
    status_code_constant    VARCHAR2(30) := 'STATUS_CODE';
    subinv_code_constant    VARCHAR2(30) := 'SUBINVENTORY_CODE';
    
    g_org_lookup            VARCHAR2(30) := 'XXNBTY_ORG_ID_LOOKUP';
    g_subinv_lookup         VARCHAR2(30) := 'XXNBTY_SUBINVCODE_LOOKUP';
    g_glcomb_lookup         VARCHAR2(30) := 'XXNBTY_GL_CODE_COMBO_LOOKUP';
    g_gts_lookup            VARCHAR2(30) := 'XXNBTY_GTSRECEIPTS_LOOKUP';
    g_gtrans_lookup         VARCHAR2(30) := 'XXNBTY_GTSTRANSFERS_LOOKUP';
    --g_recipients_lookup       VARCHAR2(30) := 'XXNBTY_INV_TXN_EMAIL_LIST';
    
  --Main Procedure that will call the 7 sub procedures
  PROCEDURE main_proc            ( x_errbuf         OUT VARCHAR2, 
                                   x_retcode        OUT VARCHAR2,
                                   p_process_err    VARCHAR2,
                                   p_recipients     VARCHAR2);
            
  --Sub Procedure that will validate if the item-org combinations are not existing on EBS
  PROCEDURE validate_item_org    ( x_errbuf     OUT VARCHAR2, 
                                   x_retcode    OUT VARCHAR2);
            
  --Sub Procedure that will derive required fields from new records on staging table 1 and inserts successfull records on staging table 2
  PROCEDURE derive_req_fields    ( x_errbuf     OUT VARCHAR2, 
                                   x_retcode    OUT VARCHAR2);  

  --Sub Procedure that will duplicate GTS receipt transactions on 2nd staging table
  PROCEDURE duplicate_gts_txn    ( x_errbuf     OUT VARCHAR2, 
                                   x_retcode    OUT VARCHAR2);                                     
                                   
  --Sub Procedure that will insert records from the staging table 2 to the interface table
  PROCEDURE insert_records      ( x_errbuf      OUT VARCHAR2, 
                                  x_retcode     OUT VARCHAR2);

  --Sub Procedure that will print a summary report via log file
  PROCEDURE generate_report     ( x_errbuf      OUT VARCHAR2, 
                                  x_retcode     OUT VARCHAR2,
                                  p_recipients      VARCHAR2);                                

  --Sub Procedure that will archive records from the staging table 2 to the archive table
  PROCEDURE archive_records     ( x_errbuf      OUT VARCHAR2, 
                                  x_retcode     OUT VARCHAR2);      
                                  
  --Sub Procedure that will submit the standard program to process records on the interface table
  PROCEDURE submit_standard_prog      ( x_retcode     OUT VARCHAR2,
                                        x_errbuf      OUT VARCHAR2);                                  
                                                    
END XXNBTY_INVINT01_INV_TXN_PKG; 

/

show errors;
