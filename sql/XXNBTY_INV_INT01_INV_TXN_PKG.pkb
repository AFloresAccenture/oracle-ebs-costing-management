create or replace PACKAGE BODY   XXNBTY_INVINT01_INV_TXN_PKG
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
10-Feb-2016                 Albert John Flores	    Initial Development
09-Mar-2016                 Albert John Flores	    Unit test changes
23-Mar-2016                 Albert John Flores	    Additional changes
29-Mar-2016                 Albert John Flores	    Added submission of standard program and sending of email
19-Apr-2016                 Albert John Flores	    delete_mark = 0 added on checking costs
19-Apr-2016                 Albert John Flores	    added fix to wait for the standard programs
27-Apr-2016					Albert John Flores		Fix to pass NULL to transfer org and transfer subinventory
30-Apr-2016					Albert John Flores		Producing Org from as400 added 
11-May-2016					Albert John Flores		Error trapping for negative transaction quantities
19-May-2016					Albert John Flores		Added the validation of cost for updated TI and TO transactions
							Albert John Flores		Added the default of 'Y' on batch_complete column if the accounting transaction type is 'BATCH_COMP'
05-Jul-2016		   			Albert John Flores		Accomodated 5 additional columns	
07-Oct-2016					Albert John Flores		changed the cost table CM_CMPT_DTL to GL_ITEM_CSTf	
27-Oct-2016					Albert John Flores		Added additional validation for producing org		
02-Nov-2016					Albert John Flores		added a condition for discreet org unit cost validation									
*/
----------------------------------------------------------------------------------------------------



IS 

  --Main Procedure that will call the 7 sub procedures
  PROCEDURE main_proc            ( x_errbuf         OUT VARCHAR2, 
                                   x_retcode        OUT VARCHAR2,
                                   p_process_err    VARCHAR2,
                                   p_recipients     VARCHAR2)
  IS
----------------------------------------------------------------------------------------------------
/*
Package Name: XXNBTY_INVINT01_INV_TXN_PKG
Author's Name: Albert John Flores
Date written: 29-Feb-2016
RICEFW Object: INT01
Description: Main Procedure that will call all subprocedures
Program Style: 

Maintenance History: 

Date            Issue#      Name                    Remarks 
-----------     ------      -----------             ------------------------------------------------
29-Feb-2016                 Albert Flores           Initial Development

*/
----------------------------------------------------------------------------------------------------  
    v_step          NUMBER;
    v_mess          VARCHAR2(500);
    l_error         EXCEPTION;
  BEGIN
  
        v_step := 1;
        
        --Purge 2nd Staging table and the Error Table
        --DELETE FROM xxnbty_inv_txn_stg2;
        EXECUTE IMMEDIATE 'TRUNCATE TABLE xxnbty.xxnbty_inv_txn_stg2'; --AFLORES 7/6/2016
		--COMMIT;
        --DELETE FROM xxnbty_inv_error_tbl;
        EXECUTE IMMEDIATE 'TRUNCATE TABLE xxnbty.xxnbty_inv_error_tbl'; --AFLORES 7/6/2016
		COMMIT; 
          
        --Start of changes 3/23/2016 AFlores
        IF UPPER(p_process_err) = 'YES' THEN
        --Update Records in Staging table 1 and Interface Table for reprocessing
                UPDATE xxnbty_inv_txn_stg1 stg1
                SET      stg1.status_flag       = 'NEW'
                        ,stg1.error_description = NULL
                WHERE stg1.status_flag          = 'ERROR';
                
                COMMIT;
                
                UPDATE mtl_transactions_interface mti
                SET     mti.process_flag        = 1
                WHERE   mti.process_flag        = 3;
                
                COMMIT;
        END IF;
        
        v_step := 2;
        
        --call procedure to validate item-org combination
        validate_item_org( x_errbuf, x_retcode );
        IF x_retcode = 2 THEN
            RAISE l_error;
        END IF;
        
        --End of changes 3/23/2016 AFlores
        
        v_step := 3;
        
        --call procedure to derive required fields
        derive_req_fields( x_errbuf, x_retcode );
        IF x_retcode = 2 THEN
            RAISE l_error;
        END IF;
      
        v_step := 4;
        
        --call procedure that will duplicate all gts transactions
        duplicate_gts_txn( x_errbuf, x_retcode );
        IF x_retcode = 2 THEN
            RAISE l_error;
        END IF;
        
        v_step := 5;
        
        --call procedure that will all records to the interface table
        insert_records( x_errbuf, x_retcode );
        IF x_retcode = 2 THEN
            RAISE l_error;
        END IF;
        
        v_step := 6;
        
        --call procedure that will archive all records from the 2nd staging table
        archive_records( x_errbuf, x_retcode );
        IF x_retcode = 2 THEN
            RAISE l_error;
        END IF;
        
        v_step := 7;
        
        --Added to submit the standard program AFLORES 3/29/2016
        --call procedure that will submit the standard program
        submit_standard_prog( x_errbuf, x_retcode );
        IF x_retcode = 2 THEN
            RAISE l_error;
        END IF;
      
        v_step := 8;
        
        --call procedure that will generate a summary report
        generate_report( x_errbuf, x_retcode, p_recipients);
        IF x_retcode = 2 THEN
            RAISE l_error;
        END IF;
      
        v_step := 9;
  
  EXCEPTION
  WHEN l_error THEN
        FND_FILE.PUT_LINE(FND_FILE.LOG, 'ERROR - [' || x_errbuf || ']' );
        x_retcode := x_retcode;

    WHEN OTHERS THEN
    x_retcode := 2;
    v_mess := 'At step ['||v_step||'] for procedure main_proc - SQLCODE [' ||SQLCODE|| '] - ' ||substr(SQLERRM,1,100);
    x_errbuf := v_mess; 
  
  END main_proc;
  
  --Start Changes 3/23/2016 AFlores
  --Sub Procedure that will validate if the item-org combinations are not existing on EBS
  PROCEDURE validate_item_org    ( x_errbuf     OUT VARCHAR2, 
                                   x_retcode    OUT VARCHAR2)
  IS
----------------------------------------------------------------------------------------------------
/*
Package Name: XXNBTY_INVINT01_INV_TXN_PKG
Author's Name: Albert John Flores
Date written: 23-Mar-2016
RICEFW Object: INT01
Description: Validates the records if the item-org combination exists in EBS
Program Style: 

Maintenance History: 

Date            Issue#      Name                    Remarks 
-----------     ------      -----------             ------------------------------------------------
23-Mar-2016                 Albert Flores           Initial Development

*/
----------------------------------------------------------------------------------------------------
  
    CURSOR c_new_records IS
        SELECT   TRIM(stg1.source_code) source_code
                ,TRIM(stg1.source_line_id) source_line_id
                ,TRIM(stg1.source_header_id) source_header_id
                ,TRIM(stg1.process_flag) process_flag
                ,TRIM(stg1.transaction_mode) transaction_mode
                ,TRIM(stg1.item_segment1) item_segment1
                ,TRIM(stg1.transaction_quantity) transaction_quantity
                ,TRIM(stg1.transaction_uom) transaction_uom
                ,TRIM(stg1.transaction_date) transaction_date
                ,TRIM(stg1.transaction_reference) transaction_reference
                ,TRIM(stg1.vendor_lot_number) vendor_lot_number
                ,TRIM(stg1.shipment_number) shipment_number
                ,TRIM(stg1.lot_number) lot_number               
                ,TRIM(stg1.batch_complete) batch_complete           
                ,TRIM(stg1.batch_size) batch_size               
                ,TRIM(stg1.batch_completion_date) batch_completion_date 
                ,TRIM(stg1.reason_code) reason_code         
                ,TRIM(stg1.transaction_code) transaction_code       
                ,TRIM(stg1.status_code) status_code         
                ,TRIM(stg1.as400_source_warehouse) as400_source_warehouse   
                ,TRIM(stg1.as400_dest_warehouse) as400_dest_warehouse   
                ,TRIM(stg1.status_flag) status_flag
				,TRIM(stg1.dsp_segment3) producing_org --Added 4/30/2016 AFlores for producing_org
				,TRIM(stg1.dsp_segment4) legacy_reason_code		--Added 07/06/2016 AFlores for 5 additional columns
				,TRIM(stg1.dsp_segment1) legacy_txn_type_code   --Added 07/06/2016 AFlores for 5 additional columns
				,TRIM(stg1.dst_segment1) legacy_warehouse_snd   --Added 07/06/2016 AFlores for 5 additional columns
				,TRIM(stg1.dst_segment2) legacy_warehouse_rcv   --Added 07/06/2016 AFlores for 5 additional columns
				,TRIM(stg1.dst_segment5) legacy_pallet_num      --Added 07/06/2016 AFlores for 5 additional columns
                ,stg1.rowid
        FROM    xxnbty_inv_txn_stg1 stg1
        WHERE   UPPER(stg1.status_flag) = 'NEW';
        
    CURSOR c_dest_val IS
        SELECT   TRIM(stg1.source_code) source_code
                ,TRIM(stg1.source_line_id) source_line_id
                ,TRIM(stg1.source_header_id) source_header_id
                ,TRIM(stg1.process_flag) process_flag
                ,TRIM(stg1.transaction_mode) transaction_mode
                ,TRIM(stg1.item_segment1) item_segment1
                ,TRIM(stg1.transaction_quantity) transaction_quantity
                ,TRIM(stg1.transaction_uom) transaction_uom
                ,TRIM(stg1.transaction_date) transaction_date
                ,TRIM(stg1.transaction_reference) transaction_reference
                ,TRIM(stg1.vendor_lot_number) vendor_lot_number
                ,TRIM(stg1.shipment_number) shipment_number
                ,TRIM(stg1.lot_number) lot_number               
                ,TRIM(stg1.batch_complete) batch_complete           
                ,TRIM(stg1.batch_size) batch_size               
                ,TRIM(stg1.batch_completion_date) batch_completion_date 
                ,TRIM(stg1.reason_code) reason_code         
                ,TRIM(stg1.transaction_code) transaction_code       
                ,TRIM(stg1.status_code) status_code         
                ,TRIM(stg1.as400_source_warehouse) as400_source_warehouse   
                ,TRIM(stg1.as400_dest_warehouse) as400_dest_warehouse   
                ,TRIM(stg1.status_flag) status_flag
				,TRIM(stg1.dsp_segment3) producing_org --Added 4/30/2016 AFlores for producing_org
				,TRIM(stg1.dsp_segment4) legacy_reason_code		--Added 07/06/2016 AFlores for 5 additional columns
				,TRIM(stg1.dsp_segment1) legacy_txn_type_code   --Added 07/06/2016 AFlores for 5 additional columns
				,TRIM(stg1.dst_segment1) legacy_warehouse_snd   --Added 07/06/2016 AFlores for 5 additional columns
				,TRIM(stg1.dst_segment2) legacy_warehouse_rcv   --Added 07/06/2016 AFlores for 5 additional columns
				,TRIM(stg1.dst_segment5) legacy_pallet_num      --Added 07/06/2016 AFlores for 5 additional columns
                ,stg1.rowid
        FROM    xxnbty_inv_txn_stg1 stg1
        WHERE   UPPER(stg1.status_flag) = 'NEW'
        AND     stg1.reason_code = gts_reason_constant
        AND     stg1.transaction_code = gts_txn_constant;       
        
      l_org_id          NUMBER; 
      l_count_rec       NUMBER;
      
      v_step            NUMBER;
      v_mess            VARCHAR2(500); 
    BEGIN
        v_step := 1;

        FOR l_new_records IN c_new_records
        LOOP
        
            --Reset identifiers
            l_org_id        := NULL;
            l_count_rec     := 0;
        
            v_step := 2;
            
            --Derive Organization ID to be used in checking
            BEGIN
            
                SELECT mp.organization_id 
                INTO   l_org_id
                FROM   fnd_lookup_values flv
                      ,mtl_parameters mp
                WHERE  flv.lookup_type          = g_org_lookup
                AND    flv.description          = mp.organization_code
                AND    UPPER(flv.lookup_code)   = UPPER(l_new_records.as400_source_warehouse)   
                AND    UPPER(flv.meaning)       = UPPER(l_new_records.as400_source_warehouse);
                
            EXCEPTION
            WHEN NO_DATA_FOUND THEN
                l_org_id     := NULL;
                        
            END;
            
            v_step := 3;
            
            --If derivation of organization_id is successfull, check now if the ITEM-ORG is existing or not
            IF l_org_id IS NOT NULL THEN
            
                BEGIN
                
                    SELECT COUNT (msi.segment1)
                    INTO    l_count_rec
                    FROM    mtl_system_items msi
                    WHERE   msi.segment1        = l_new_records.item_segment1
                    AND     msi.organization_id = l_org_id;
                
                END;
            
            END IF;
            
            v_step := 4;
            
            --If the count is zero, it means it doesn't exists and should error out
            IF l_count_rec = 0 THEN
            
                UPDATE xxnbty_inv_txn_stg1 stg1
                SET    stg1.error_description = 'Item - Org Combination does not exist'
                      ,stg1.status_flag       = 'ERROR'
                      ,stg1.last_update_date  = SYSDATE
                      ,stg1.last_updated_by   = g_user_id
                      ,stg1.creation_date     = SYSDATE 
                      ,stg1.last_update_login = g_user_id   
                WHERE  l_new_records.rowid    = stg1.rowid; 
                
                COMMIT;
                
                --Insert Error records on the error table
                INSERT INTO xxnbty_inv_error_tbl ( source_code 
                                                   ,source_line_id 
                                                   ,source_header_id 
                                                   ,item_segment1 
                                                   ,transaction_quantity 
                                                   ,transaction_uom 
                                                   ,transaction_date 
                                                   ,transaction_reference 
                                                   ,vendor_lot_number 
                                                   ,shipment_number 
                                                   ,lot_number          
                                                   ,batch_complete      
                                                   ,batch_size          
                                                   ,batch_completion_date   
                                                   ,reason_code             
                                                   ,transaction_code        
                                                   ,status_code             
                                                   ,as400_source_warehouse 
                                                   ,as400_dest_warehouse    
                                                   ,status_flag 
                                                   ,error_description
                                                   ,last_update_date    
                                                   ,last_updated_by 
                                                   ,creation_date       
                                                   ,created_by          
                                                   ,last_update_login
												   ,producing_org --Added 4/30/2016 AFlores for producing_org
												   ,legacy_reason_code	    --Added 07/06/2016 AFlores for 5 additional columns
												   ,legacy_txn_type_code    --Added 07/06/2016 AFlores for 5 additional columns
												   ,legacy_warehouse_snd    --Added 07/06/2016 AFlores for 5 additional columns
												   ,legacy_warehouse_rcv    --Added 07/06/2016 AFlores for 5 additional columns
												   ,legacy_pallet_num   )   --Added 07/06/2016 AFlores for 5 additional columns 
                                                   
                VALUES(l_new_records.source_code 
                       ,l_new_records.source_line_id 
                       ,l_new_records.source_header_id 
                       ,l_new_records.item_segment1 
                       ,l_new_records.transaction_quantity 
                       ,l_new_records.transaction_uom 
                       ,l_new_records.transaction_date 
                       ,l_new_records.transaction_reference 
                       ,l_new_records.vendor_lot_number 
                       ,l_new_records.shipment_number 
                       ,l_new_records.lot_number            
                       ,l_new_records.batch_complete        
                       ,l_new_records.batch_size            
                       ,l_new_records.batch_completion_date     
                       ,l_new_records.reason_code           
                       ,l_new_records.transaction_code      
                       ,NVL(l_new_records.status_code, NULL)            
                       ,l_new_records.as400_source_warehouse 
                       ,l_new_records.as400_dest_warehouse  
                       ,'ERROR'
                       ,'Item - Org Combination does not exist'
                       ,SYSDATE 
                       ,g_user_id   
                       ,SYSDATE 
                       ,g_user_id   
                       ,g_user_id 
					   ,l_new_records.producing_org  --Added 4/30/2016 AFlores for producing_org
					   ,l_new_records.legacy_reason_code	     --Added 07/06/2016 AFlores for 5 additional columns 
					   ,l_new_records.legacy_txn_type_code       --Added 07/06/2016 AFlores for 5 additional columns 
					   ,TO_NUMBER(l_new_records.legacy_warehouse_snd)       --Added 07/06/2016 AFlores for 5 additional columns 
					   ,TO_NUMBER(l_new_records.legacy_warehouse_rcv)       --Added 07/06/2016 AFlores for 5 additional columns 
					   ,TO_NUMBER(l_new_records.legacy_pallet_num)          --Added 07/06/2016 AFlores for 5 additional columns 
					   );
                
                COMMIT;
                --add count of error and processed records      
                g_total_rec := g_total_rec + 1 ;
                g_err_rec   := g_err_rec + 1 ;
            
            END IF;
            
            v_step := 5;
    
        END LOOP;
        
        COMMIT;
        
        --Validate source-dest ORG comb in the staging 1
        FOR l_dest_val IN c_dest_val
        LOOP
        
            IF (l_dest_val.as400_dest_warehouse IS NULL OR l_dest_val.as400_dest_warehouse = NULL) THEN
            
                UPDATE xxnbty_inv_txn_stg1 stg1
                SET    stg1.error_description = 'Both AS400_SOURCE_WAREHOUSE - AS400_DEST_WAREHOUSE should have a value for this kind of transaction'
                      ,stg1.status_flag       = 'ERROR'
                      ,stg1.last_update_date  = SYSDATE
                      ,stg1.last_updated_by   = g_user_id
                      ,stg1.creation_date     = SYSDATE 
                      ,stg1.last_update_login = g_user_id   
                WHERE  l_dest_val.rowid       = stg1.rowid; 
                
                COMMIT;
                
                --Insert Error records on the error table
                INSERT INTO xxnbty_inv_error_tbl ( source_code 
                                                   ,source_line_id 
                                                   ,source_header_id 
                                                   ,item_segment1 
                                                   ,transaction_quantity 
                                                   ,transaction_uom 
                                                   ,transaction_date 
                                                   ,transaction_reference 
                                                   ,vendor_lot_number 
                                                   ,shipment_number 
                                                   ,lot_number          
                                                   ,batch_complete      
                                                   ,batch_size          
                                                   ,batch_completion_date   
                                                   ,reason_code             
                                                   ,transaction_code        
                                                   ,status_code             
                                                   ,as400_source_warehouse 
                                                   ,as400_dest_warehouse    
                                                   ,status_flag 
                                                   ,error_description
                                                   ,last_update_date    
                                                   ,last_updated_by 
                                                   ,creation_date       
                                                   ,created_by          
                                                   ,last_update_login
												   ,producing_org --Added 4/30/2016 AFlores for producing_org
												   ,legacy_reason_code	    --Added 07/06/2016 AFlores for 5 additional columns
												   ,legacy_txn_type_code    --Added 07/06/2016 AFlores for 5 additional columns
												   ,legacy_warehouse_snd    --Added 07/06/2016 AFlores for 5 additional columns
												   ,legacy_warehouse_rcv    --Added 07/06/2016 AFlores for 5 additional columns
												   ,legacy_pallet_num   )   --Added 07/06/2016 AFlores for 5 additional columns 
                                                   
                VALUES(l_dest_val.source_code 
                       ,l_dest_val.source_line_id 
                       ,l_dest_val.source_header_id 
                       ,l_dest_val.item_segment1 
                       ,l_dest_val.transaction_quantity 
                       ,l_dest_val.transaction_uom 
                       ,l_dest_val.transaction_date 
                       ,l_dest_val.transaction_reference 
                       ,l_dest_val.vendor_lot_number 
                       ,l_dest_val.shipment_number 
                       ,l_dest_val.lot_number           
                       ,l_dest_val.batch_complete       
                       ,l_dest_val.batch_size           
                       ,l_dest_val.batch_completion_date    
                       ,l_dest_val.reason_code          
                       ,l_dest_val.transaction_code         
                       ,NVL(l_dest_val.status_code, NULL)           
                       ,l_dest_val.as400_source_warehouse 
                       ,l_dest_val.as400_dest_warehouse     
                       ,'ERROR'
                       ,'Both AS400_SOURCE_WAREHOUSE - AS400_DEST_WAREHOUSE should have a value for this kind of transaction'
                       ,SYSDATE 
                       ,g_user_id   
                       ,SYSDATE 
                       ,g_user_id   
                       ,g_user_id 
					   ,l_dest_val.producing_org --Added 4/30/2016 AFlores for producing_org
					   ,l_dest_val.legacy_reason_code	    --Added 07/06/2016 AFlores for 5 additional columns
					   ,l_dest_val.legacy_txn_type_code    --Added 07/06/2016 AFlores for 5 additional columns
					   ,TO_NUMBER(l_dest_val.legacy_warehouse_snd)    --Added 07/06/2016 AFlores for 5 additional columns
					   ,TO_NUMBER(l_dest_val.legacy_warehouse_rcv)    --Added 07/06/2016 AFlores for 5 additional columns
					   ,TO_NUMBER(l_dest_val.legacy_pallet_num)      --Added 07/06/2016 AFlores for 5 additional columns 
					   );
                COMMIT;
                
                --add count of error and processed records      
                g_total_rec := g_total_rec + 1 ;
                g_err_rec   := g_err_rec + 1 ;
                
            END IF;
        
        END LOOP;
        
        COMMIT;
    
    EXCEPTION
    WHEN OTHERS THEN
    x_retcode := 2;
    v_mess := 'At step ['||v_step||'] for procedure validate_item_org - SQLCODE [' ||SQLCODE|| '] - ' ||substr(SQLERRM,1,100);
    x_errbuf := v_mess;  
    
    END validate_item_org;
    --End Changes 3/23/2016 AFlores

  --Sub Procedure that will derive required fields from new records on staging table 1 and inserts successfull records on staging table 2
  PROCEDURE derive_req_fields    ( x_errbuf     OUT VARCHAR2, 
                                   x_retcode    OUT VARCHAR2)
  IS
----------------------------------------------------------------------------------------------------
/*
Package Name: XXNBTY_INVINT01_INV_TXN_PKG
Author's Name: Albert John Flores
Date written: 19-Feb-2016
RICEFW Object: INT01
Description: Reads NEW records from the first staging table to derive all required fields and inserts them to the 2nd staging table 
Program Style: 

Maintenance History: 

Date            Issue#      Name                    Remarks 
-----------     ------      -----------             ------------------------------------------------
19-Feb-2016                 Albert Flores           Initial Development

*/
----------------------------------------------------------------------------------------------------
    CURSOR c_new_rec IS
    SELECT   TRIM(stg1.source_code) source_code
            ,TRIM(stg1.source_line_id) source_line_id
            ,TRIM(stg1.source_header_id) source_header_id
            ,TRIM(stg1.process_flag) process_flag
            ,TRIM(stg1.transaction_mode) transaction_mode
            ,TRIM(stg1.item_segment1) item_segment1
            ,TRIM(stg1.transaction_quantity) transaction_quantity
            ,TRIM(stg1.transaction_uom) transaction_uom
            ,TRIM(stg1.transaction_date) transaction_date
            ,TRIM(stg1.transaction_reference) transaction_reference
            ,TRIM(stg1.vendor_lot_number) vendor_lot_number
            ,TRIM(stg1.shipment_number) shipment_number
            ,TRIM(stg1.lot_number) lot_number               
            ,TRIM(stg1.batch_complete) batch_complete           
            ,TRIM(stg1.batch_size) batch_size               
            ,TRIM(stg1.batch_completion_date) batch_completion_date 
            ,TRIM(stg1.reason_code) reason_code         
            ,TRIM(stg1.transaction_code) transaction_code       
            ,TRIM(stg1.status_code) status_code         
            ,TRIM(stg1.as400_source_warehouse) as400_source_warehouse   
            ,TRIM(stg1.as400_dest_warehouse) as400_dest_warehouse   
            ,TRIM(stg1.status_flag) status_flag
			,TRIM(stg1.dsp_segment3) producing_org --Added 4/30/2016 AFlores for producing_org
            ,TRIM(stg1.dsp_segment4) legacy_reason_code	    --Added 07/06/2016 AFlores for 5 additional columns 
			,TRIM(stg1.dsp_segment1) legacy_txn_type_code   --Added 07/06/2016 AFlores for 5 additional columns 
			,TRIM(stg1.dst_segment1) legacy_warehouse_snd   --Added 07/06/2016 AFlores for 5 additional columns 
			,TRIM(stg1.dst_segment2) legacy_warehouse_rcv   --Added 07/06/2016 AFlores for 5 additional columns 
			,TRIM(stg1.dst_segment5) legacy_pallet_num      --Added 07/06/2016 AFlores for 5 additional columns 
			,stg1.rowid
    FROM    xxnbty_inv_txn_stg1 stg1
    WHERE   UPPER(stg1.status_flag) = 'NEW';

    
    l_source_org    NUMBER;
    l_dest_org      NUMBER;
    l_unit_cost     NUMBER;
	l_unit_cost_gts	NUMBER; -- added 5/19/2016 AFlores
    l_subinv_code   VARCHAR2(10);
    l_gl_comb1      VARCHAR2(40);
    l_gl_comb2      VARCHAR2(40);
    l_gl_comb3      VARCHAR2(40);
    l_gl_comb4      VARCHAR2(40);
    l_gl_comb5      VARCHAR2(40);
    l_gl_comb6      VARCHAR2(40);
    l_gl_comb7      VARCHAR2(40);
    l_gl_comb8      VARCHAR2(40);
    l_txn_typ_id    NUMBER;
    l_trans_sub     VARCHAR2(10);
    l_trans_org     NUMBER;
	l_val_attr4		VARCHAR2(100);--Added 4/30/2016 AFlores for producing_org
	l_batch_complete	VARCHAR2(10);--Added AFlores 5/19/2016
    l_val_attr1		VARCHAR2(100);--Added 10/27/2016 AFlores for producing_org addition
	l_val_attr2		VARCHAR2(100);--Added 10/27/2016 AFlores for producing_org addition
	
    v_step          NUMBER;
    v_mess          VARCHAR2(500);  
    
    l_status        VARCHAR2(10);
    l_error_msg     VARCHAR2(4000);
    l_err_flag      BOOLEAN;
  
  BEGIN
    v_step := 1;

    --Open Cursor to fetch new records from staging table 1
    FOR l_new_rec IN c_new_rec
    LOOP
    --Reset identifiers
    l_status         := NULL;
    l_error_msg      := NULL;
    l_err_flag       := FALSE;
    l_source_org     := NULL;
    l_dest_org       := NULL;
    l_unit_cost      := NULL;
	l_unit_cost_gts	 := NULL; -- added 5/19/2016 AFlores
    l_subinv_code    := NULL;
    l_gl_comb1       := NULL;
    l_gl_comb2       := NULL;
    l_gl_comb3       := NULL;
    l_gl_comb4       := NULL;
    l_gl_comb5       := NULL;
    l_gl_comb6       := NULL;
    l_gl_comb7       := NULL;
    l_gl_comb8       := NULL;
    l_txn_typ_id     := NULL;
    l_trans_sub      := NULL;
    l_trans_org      := NULL;
	l_val_attr4  	 := NULL; --Added 4/30/2016 AFlores
	l_batch_complete := NULL; --added AFlores 5/19/2016
	l_val_attr1  	 := NULL; --Added 10/27/2016 AFlores
	l_val_attr2  	 := NULL; --Added 10/27/2016 AFlores
    
        --Derive required fields based on the columns from AS400
    v_step := 2;    
		--Validate if producing org is mandatory or not
		--START Added 4/30/2016 AFlores for producing_org
		--Validate combination to check its attribute 4 for WIP COMP
		BEGIN

			SELECT mtt.attribute4, mtt.attribute1, mtt.attribute2
			INTO   l_val_attr4, l_val_attr1, l_val_attr2 --added attribute2 and attribute1 AFLORES 10/27/2016
			FROM   mtl_transaction_types mtt
			WHERE  mtt.attribute1           = l_new_rec.reason_code 
			AND    mtt.attribute2           = l_new_rec.transaction_code
			AND    ((mtt.attribute3         = l_new_rec.status_code AND TRIM(l_new_rec.status_code) IS NOT NULL) OR mtt.attribute3 IS NULL);
		
        EXCEPTION
        WHEN NO_DATA_FOUND THEN
            l_err_flag   := TRUE;
            l_error_msg  := l_error_msg || 'Reason Code - Transaction Code - Status Code Combination does not exist on Transaction Type Table; ';
            l_status     := 'ERROR';
            l_val_attr4  := NULL;
        	l_val_attr1  := NULL;
			l_val_attr2  := NULL;
		END;
		
	v_step := 2.1; 	
	 
		--Validate if the record has a negative transaction quantity
		--Added on 11May2016
		
		IF l_new_rec.transaction_quantity < 0 THEN
		
			l_err_flag   := TRUE;
			l_error_msg  := l_error_msg || 'Transaction Quantity must be Positive in order to be processed; ';
			l_status     := 'ERROR';
			
		END IF;
		
	v_step := 2.2; 	
	
		--Validate the producing org if the attribute 4 is WIP COMP
		--modified to add 'A' as attribute 2 and attribute1 is not PR
		IF --l_val_attr4 IS NOT NULL AND l_val_attr4 = 'WIP COMP' AND
			l_val_attr1 IS NOT NULL AND l_val_attr1 IN ('RB', 'RS', 'PA')
			AND l_val_attr2 IS NOT NULL AND l_val_attr2 = 'A' 
			AND l_new_rec.producing_org IS NULL THEN
				 
			l_err_flag   := TRUE;
			l_error_msg  := l_error_msg || 'Producing Org should be Mandatory on this Transaction; ';
			l_status     := 'ERROR';	
			
		END IF;
		
	v_step := 2.3; 	
		
		--Added AFlores 5/19/2016
		--Validate if attribute4 is BATCH COMP
		IF l_val_attr4 = 'BATCH COMP' THEN
		
			l_batch_complete := 'Y';
			
		ELSE
		
			l_batch_complete := l_new_rec.batch_complete;
		
		END IF;
		--End of changes AFlores 5/19/2016
	
	v_step := 2.4; 
	
        --Derive Source Organization ID 
        BEGIN
        
            SELECT mp.organization_id 
            INTO   l_source_org
            FROM   fnd_lookup_values flv
                  ,mtl_parameters mp
            WHERE  flv.lookup_type          = g_org_lookup
            AND    flv.description          = mp.organization_code
            AND    UPPER(flv.lookup_code)   = UPPER(l_new_rec.as400_source_warehouse)   
            AND    UPPER(flv.meaning)       = UPPER(l_new_rec.as400_source_warehouse);
            
        EXCEPTION
        WHEN NO_DATA_FOUND THEN
            l_err_flag   := TRUE;
            l_error_msg  := l_error_msg || 'Error on deriving Organization ID;';
            l_status     := 'ERROR';
            l_source_org := NULL;
                    
        END;
    v_step := 3;    
        --Derive Subinventory Code
        IF l_source_org IS NOT NULL THEN
            BEGIN   
                SELECT flv2.description
                INTO   l_subinv_code
                FROM   fnd_lookup_values flv2
                WHERE  flv2.lookup_type = g_subinv_lookup
                AND    UPPER(flv2.lookup_code) = (SELECT UPPER(ecg.catalog_group)
                                                        FROM mtl_system_items msi
                                                            , ego_catalog_groups_v ecg                                                          
                                                        WHERE ecg.catalog_group_id          = msi.item_catalog_group_id                                                     
                                                        AND   msi.organization_id           = l_source_org
                                                        AND   msi.segment1                  = l_new_rec.item_segment1)
                AND  UPPER(flv2.meaning)       = (SELECT UPPER(ecg.catalog_group)
                                                        FROM mtl_system_items msi
                                                            , ego_catalog_groups_v ecg                                                          
                                                        WHERE ecg.catalog_group_id          = msi.item_catalog_group_id                                                     
                                                        AND   msi.organization_id           = l_source_org
                                                        AND   msi.segment1                  = l_new_rec.item_segment1);
                                                    
            EXCEPTION
            WHEN NO_DATA_FOUND THEN
                l_err_flag    := TRUE;
                l_error_msg   := l_error_msg || 'Error on deriving Subinventory Code;';
                l_status      := 'ERROR';
                l_subinv_code := NULL;
            END;

        --Start of Changes Additional Validation for UNIT Cost 4/1/2016 AFLORES
        
            BEGIN
                SELECT (CASE WHEN mp.PROCESS_ENABLED_FLAG = 'N' THEN (select SUM(item_cost) 
                                                                                      from ( select distinct cicd.cost_element,cicd.Resource_code,cicd.usage_rate_or_amount,  cicd.item_cost, msi_disc.segment1, mp_disc.organization_code, cict.cost_type, msi_disc.inventory_item_id, mp_disc.organization_id 
                                                                                      from cst_item_cost_details_v cicd,
                                                                                      mtl_system_items msi_disc,
                                                                                      mtl_parameters mp_disc,
                                                                                      CST_ITEM_COST_TYPE_V cict
      
                                                                                      where cicd.inventory_item_id   =   msi_disc.inventory_item_id
                                                                                      and   cicd.organization_id     =   msi_disc.organization_id
                                                                                      and   cicd.organization_id     =   mp_disc.organization_id 
                                                                                      and   cicd.inventory_item_id   =   cict.inventory_item_id
                                                                                      and   cicd.organization_id     =   cict.organization_id
                                                                                      --Modified for discreet org cost validation AFLORES 11/2/2016
																					  and   UPPER(cict.cost_type)    = 'FROZEN' 
																					  AND   cicd.cost_type_id		 =	 cict.cost_type_id
                                                                                      ) disc_cost
                                                                                      WHERE disc_cost.inventory_item_id = msi.inventory_item_id
                                                                                      AND   disc_cost.organization_id   = msi.organization_id
                                                                                      AND   disc_cost.organization_id   = mp.organization_id
                                                                                       )
                                                  
										--modified the table for cost 	AFLORES 10/7/2016						
                                      WHEN mp.PROCESS_ENABLED_FLAG = 'Y' THEN (select SUM(acctg_cost)
                                                                              from (select distinct mp_proc.organization_id,msi_proc.segment1,a.inventory_item_id,a.acctg_cost,a.period_id
                                                                              from   
      
                                                                              --CM_CMPT_DTL  ccd,
                                                                              --CM_CMPT_MST ccm ,
																			  GL_ITEM_CST a,
                                                                              mtl_system_items msi_proc,
                                                                              mtl_parameters mp_proc
      
                                                                              where a.inventory_item_id   = msi_proc.inventory_item_id
                                                                              and a.organization_id       = msi_proc.organization_id
                                                                              --and ccd.cost_cmpntcls_id      = ccm.cost_cmpntcls_id
                                                                              and a.organization_id       = mp_proc.organization_id 
                                                                              and a.organization_id       = msi_proc.organization_id 
                                                                              --Added for delete mark AFLORES 4/19/2016
                                                                              and a.delete_mark = 0
                                                                              ) proc_cost
                                                                              where proc_cost.period_id = gps.period_id
                                                                                         AND    l_new_rec.transaction_date >= gps.START_DATE
                                                                                         AND    l_new_rec.transaction_date <  TO_DATE(TO_CHAR(gps.end_date,'DD-MON-YY')||' 11:59:59PM','DD-MON-YY HH:MI:SSAM')
                                                                              and   proc_cost.inventory_item_id = msi.inventory_item_id
                                                                              and   proc_cost.organization_id   = msi.organization_id 
                                                                              and   proc_cost.organization_id   = mp.organization_id 
                                                           ) 
                                                           END ) AS UNIT_COST
                INTO l_unit_cost                
                FROM     mtl_parameters mp
                       , gmf_period_statuses gps
                       , mtl_system_items msi
                       
                WHERE 
                --TO_CHAR(l_new_rec.transaction_date, 'DD-MON-YY') BETWEEN TO_CHAR(gps.start_date, 'DD-MON-YY') AND TO_CHAR(gps.end_date, 'DD-MON-YY')
                       (l_new_rec.transaction_date >= gps.start_date )
                AND    (l_new_rec.transaction_date < TO_DATE(TO_CHAR(gps.end_date,'DD-MON-YY')||' 11:59:59PM','DD-MON-YY HH:MI:SSAM')  )
                AND   mp.organization_id    = msi.organization_id
                AND   msi.segment1          = l_new_rec.item_segment1
                AND   msi.organization_id   = l_source_org;
            
            EXCEPTION
            WHEN NO_DATA_FOUND THEN
                l_err_flag    := TRUE;
                --l_error_msg   := l_error_msg || 'No Standard Unit Cost for this item;';
                l_status      := 'ERROR';
                l_unit_cost   := NULL;
            
            END;
            
            --Check if the Unit Cost is zero then Error this record out
            IF l_unit_cost = 0
            OR l_unit_cost IS NULL
            THEN
            
                l_err_flag    := TRUE;
                l_error_msg   := l_error_msg || 'No Unit Cost found for this record. ;';
                l_status      := 'ERROR';
                l_unit_cost   := NULL;  
            
            END IF;
            
        --End of Changes AFLORES    
        END IF; 
    v_step := 4;    
        --Derive GL Code Combinations
        BEGIN
            SELECT  REGEXP_SUBSTR(flv3.description, '[^.]+', 1,1 ) AS comb1
                   ,REGEXP_SUBSTR(flv3.description, '[^.]+', 1,2 ) AS comb2
                   ,REGEXP_SUBSTR(flv3.description, '[^.]+', 1,3 ) AS comb3
                   ,REGEXP_SUBSTR(flv3.description, '[^.]+', 1,4 ) AS comb4
                   ,REGEXP_SUBSTR(flv3.description, '[^.]+', 1,5 ) AS comb5
                   ,REGEXP_SUBSTR(flv3.description, '[^.]+', 1,6 ) AS comb6
                   ,REGEXP_SUBSTR(flv3.description, '[^.]+', 1,7 ) AS comb7
                   ,REGEXP_SUBSTR(flv3.description, '[^.]+', 1,8 ) AS comb8
            INTO    l_gl_comb1
                   ,l_gl_comb2
                   ,l_gl_comb3
                   ,l_gl_comb4
                   ,l_gl_comb5
                   ,l_gl_comb6
                   ,l_gl_comb7
                   ,l_gl_comb8
            FROM  fnd_lookup_values flv3
            WHERE flv3.lookup_type = g_glcomb_lookup
            AND   flv3.lookup_code = l_new_rec.reason_code
            AND   flv3.meaning     = l_new_rec.reason_code;
        
        EXCEPTION
        WHEN NO_DATA_FOUND THEN
            l_err_flag    := TRUE;
            l_error_msg   := l_error_msg || 'Error on deriving the GL code combinations;';  
            l_status      := 'ERROR';   
            l_gl_comb1    := NULL;
            l_gl_comb2    := NULL;
            l_gl_comb3    := NULL;
            l_gl_comb4    := NULL;
            l_gl_comb5    := NULL;
            l_gl_comb6    := NULL;
            l_gl_comb7    := NULL;
            l_gl_comb8    := NULL;
        END;
    v_step := 5;    
        --Derive Transfer Organization ID
        IF l_new_rec.as400_dest_warehouse IS NOT NULL THEN
            BEGIN
                SELECT mp.organization_id 
                INTO   l_dest_org
                FROM   fnd_lookup_values flv
                      ,mtl_parameters mp
                WHERE  flv.lookup_type          = g_org_lookup
                AND    flv.description          = mp.organization_code
                AND    UPPER(flv.lookup_code)   = UPPER(l_new_rec.as400_dest_warehouse) 
                AND    UPPER(flv.meaning)       = UPPER(l_new_rec.as400_dest_warehouse);
                
            EXCEPTION
            WHEN NO_DATA_FOUND THEN
                l_err_flag  := TRUE;
                l_error_msg := l_error_msg || 'Error on deriving the Transfer Organization;';   
                l_status    := 'ERROR'; 
                l_dest_org  := NULL;    
            END;
        END IF;
    v_step := 6;    
        --Derive Transfer Subinventory Code
        IF l_dest_org IS NOT NULL THEN
            BEGIN   
                SELECT flv2.description
                INTO   l_trans_sub
                FROM   fnd_lookup_values flv2
                WHERE  flv2.lookup_type = g_subinv_lookup
                AND    UPPER(flv2.lookup_code) = (SELECT UPPER(ecg.catalog_group)
                                                        FROM mtl_system_items msi
                                                            , ego_catalog_groups_v ecg                                                          
                                                        WHERE ecg.catalog_group_id          = msi.item_catalog_group_id                                                     
                                                        AND   msi.organization_id           = l_dest_org
                                                        AND   msi.segment1                  = l_new_rec.item_segment1)
                AND  UPPER(flv2.meaning)       = (SELECT UPPER(ecg.catalog_group)
                                                        FROM mtl_system_items msi
                                                            , ego_catalog_groups_v ecg                                                          
                                                        WHERE ecg.catalog_group_id          = msi.item_catalog_group_id                                                     
                                                        AND   msi.organization_id           = l_dest_org
                                                        AND   msi.segment1                  = l_new_rec.item_segment1);
                                                    
            EXCEPTION
            WHEN NO_DATA_FOUND THEN
                l_err_flag  := TRUE;
                l_error_msg := l_error_msg || 'Error on deriving Transfer Subinventory Code;';
                l_status    := 'ERROR';
                l_trans_sub := NULL;
            END;                                            
        END IF; 
		
		--Checking of Unit Cost for GTS Receipt
		--Start - Added changes 5/19/2016 AFlores
		IF l_dest_org IS NOT NULL AND (l_new_rec.reason_code = gts_reason_constant AND l_new_rec.transaction_code = gts_txn_constant) THEN

				BEGIN
					SELECT (CASE WHEN mp.PROCESS_ENABLED_FLAG = 'N' THEN (select SUM(item_cost) 
																						  from ( select distinct cicd.cost_element,cicd.Resource_code,cicd.usage_rate_or_amount,  cicd.item_cost, msi_disc.segment1, mp_disc.organization_code, cict.cost_type, msi_disc.inventory_item_id, mp_disc.organization_id 
																						  from cst_item_cost_details_v cicd,
																						  mtl_system_items msi_disc,
																						  mtl_parameters mp_disc,
																						  CST_ITEM_COST_TYPE_V cict

																						  where cicd.inventory_item_id   =   msi_disc.inventory_item_id
																						  and   cicd.organization_id     =   msi_disc.organization_id
																						  and   cicd.organization_id     =   mp_disc.organization_id 
																						  and   cicd.inventory_item_id   =   cict.inventory_item_id
																						  and   cicd.organization_id     =   cict.organization_id
																						  --Modified for discreet org cost validation AFLORES 11/2/2016
																						  and   UPPER(cict.cost_type)    = 'FROZEN' 
																						  AND   cicd.cost_type_id		 =	 cict.cost_type_id
																						  ) disc_cost
																						  WHERE disc_cost.inventory_item_id = msi.inventory_item_id
																						  AND   disc_cost.organization_id   = msi.organization_id
																						  AND   disc_cost.organization_id   = mp.organization_id
																						   )
													  
												--modified the table for cost 	AFLORES 10/7/2016	  
										  WHEN mp.PROCESS_ENABLED_FLAG = 'Y' THEN (select SUM(acctg_cost)
																				  from (select distinct mp_proc.organization_id,msi_proc.segment1,a.inventory_item_id,a.acctg_cost,a.period_id
																				  from   
		  
																				  --CM_CMPT_DTL  ccd,
																				  --CM_CMPT_MST ccm ,
																				  GL_ITEM_CST a,
																				  mtl_system_items msi_proc,
																				  mtl_parameters mp_proc
		  
																				  where a.inventory_item_id   = msi_proc.inventory_item_id
																				  and a.organization_id       = msi_proc.organization_id
																				  --and ccd.cost_cmpntcls_id      = ccm.cost_cmpntcls_id
																				  and a.organization_id       = mp_proc.organization_id 
																				  and a.organization_id       = msi_proc.organization_id 
																				  --Added for delete mark AFLORES 4/19/2016
																				  and a.delete_mark = 0
																				  ) proc_cost
																				  where proc_cost.period_id = gps.period_id
																							 AND    l_new_rec.transaction_date >= gps.START_DATE
																							 AND    l_new_rec.transaction_date <  TO_DATE(TO_CHAR(gps.end_date,'DD-MON-YY')||' 11:59:59PM','DD-MON-YY HH:MI:SSAM')
																				  and   proc_cost.inventory_item_id = msi.inventory_item_id
																				  and   proc_cost.organization_id   = msi.organization_id 
																				  and   proc_cost.organization_id   = mp.organization_id 
															   ) 
															   END ) AS UNIT_COST
					INTO l_unit_cost_gts                
					FROM     mtl_parameters mp
						   , gmf_period_statuses gps
						   , mtl_system_items msi
						   
					WHERE 
					--TO_CHAR(l_new_rec.transaction_date, 'DD-MON-YY') BETWEEN TO_CHAR(gps.start_date, 'DD-MON-YY') AND TO_CHAR(gps.end_date, 'DD-MON-YY')
						   (l_new_rec.transaction_date >= gps.start_date )
					AND    (l_new_rec.transaction_date < TO_DATE(TO_CHAR(gps.end_date,'DD-MON-YY')||' 11:59:59PM','DD-MON-YY HH:MI:SSAM')  )
					AND   mp.organization_id    = msi.organization_id
					AND   msi.segment1          = l_new_rec.item_segment1
					AND   msi.organization_id   = l_dest_org;

				EXCEPTION
				WHEN NO_DATA_FOUND THEN
					l_err_flag    	  := TRUE;
					--l_error_msg   := l_error_msg || 'No Standard Unit Cost for this item;';
					l_status      	  := 'ERROR';
					l_unit_cost_gts   := NULL;

				END;

				--Check if the Unit Cost is zero then Error this record out
				IF l_unit_cost_gts = 0
				OR l_unit_cost_gts IS NULL
				THEN

					l_err_flag    	  := TRUE;
					l_error_msg   	  := l_error_msg || 'No Unit Cost found for this GTS Receipt record. ;';
					l_status      	  := 'ERROR';
					l_unit_cost_gts   := NULL;  

				END IF;
				
		END IF;
		--For GTS Transfer
		IF l_dest_org IS NOT NULL AND (l_new_rec.reason_code = gtrans_reason_constant AND l_new_rec.transaction_code = gtrans_txn_constant) THEN

				BEGIN
					SELECT (CASE WHEN mp.PROCESS_ENABLED_FLAG = 'N' THEN (select SUM(item_cost) 
																						  from ( select distinct cicd.cost_element,cicd.Resource_code,cicd.usage_rate_or_amount,  cicd.item_cost, msi_disc.segment1, mp_disc.organization_code, cict.cost_type, msi_disc.inventory_item_id, mp_disc.organization_id 
																						  from cst_item_cost_details_v cicd,
																						  mtl_system_items msi_disc,
																						  mtl_parameters mp_disc,
																						  CST_ITEM_COST_TYPE_V cict

																						  where cicd.inventory_item_id   =   msi_disc.inventory_item_id
																						  and   cicd.organization_id     =   msi_disc.organization_id
																						  and   cicd.organization_id     =   mp_disc.organization_id 
																						  and   cicd.inventory_item_id   =   cict.inventory_item_id
																						  and   cicd.organization_id     =   cict.organization_id
																						  --Modified for discreet org cost validation AFLORES 11/2/2016
                                                                                          and   UPPER(cict.cost_type)    = 'FROZEN' 
																						  AND   cicd.cost_type_id		 =	 cict.cost_type_id
																						  ) disc_cost
																						  WHERE disc_cost.inventory_item_id = msi.inventory_item_id
																						  AND   disc_cost.organization_id   = msi.organization_id
																						  AND   disc_cost.organization_id   = mp.organization_id
																						   )
													  
												--modified the table for cost 	AFLORES 10/7/2016	  
										  WHEN mp.PROCESS_ENABLED_FLAG = 'Y' THEN (select SUM(acctg_cost)
																				  from (select distinct mp_proc.organization_id,msi_proc.segment1,a.inventory_item_id,a.acctg_cost,a.period_id
																					  from   
			  
																					  --CM_CMPT_DTL  ccd,
																					  --CM_CMPT_MST ccm ,
																					  GL_ITEM_CST a,
																					  mtl_system_items msi_proc,
																					  mtl_parameters mp_proc
			  
																					  where a.inventory_item_id   = msi_proc.inventory_item_id
																					  and a.organization_id       = msi_proc.organization_id
																					  --and ccd.cost_cmpntcls_id      = ccm.cost_cmpntcls_id
																					  and a.organization_id       = mp_proc.organization_id 
																					  and a.organization_id       = msi_proc.organization_id 
																					  --Added for delete mark AFLORES 4/19/2016
																					  and a.delete_mark = 0
																				  ) proc_cost
																				  where proc_cost.period_id = gps.period_id
																							 AND    l_new_rec.transaction_date >= gps.START_DATE
																							 AND    l_new_rec.transaction_date <  TO_DATE(TO_CHAR(gps.end_date,'DD-MON-YY')||' 11:59:59PM','DD-MON-YY HH:MI:SSAM')
																				  and   proc_cost.inventory_item_id = msi.inventory_item_id
																				  and   proc_cost.organization_id   = msi.organization_id 
																				  and   proc_cost.organization_id   = mp.organization_id 
															   ) 
															   END ) AS UNIT_COST
					INTO l_unit_cost_gts                
					FROM     mtl_parameters mp
						   , gmf_period_statuses gps
						   , mtl_system_items msi
						   
					WHERE 
					--TO_CHAR(l_new_rec.transaction_date, 'DD-MON-YY') BETWEEN TO_CHAR(gps.start_date, 'DD-MON-YY') AND TO_CHAR(gps.end_date, 'DD-MON-YY')
						   (l_new_rec.transaction_date >= gps.start_date )
					AND    (l_new_rec.transaction_date < TO_DATE(TO_CHAR(gps.end_date,'DD-MON-YY')||' 11:59:59PM','DD-MON-YY HH:MI:SSAM')  )
					AND   mp.organization_id    = msi.organization_id
					AND   msi.segment1          = l_new_rec.item_segment1
					AND   msi.organization_id   = l_dest_org;

				EXCEPTION
				WHEN NO_DATA_FOUND THEN
					l_err_flag    	  := TRUE;
					--l_error_msg   := l_error_msg || 'No Standard Unit Cost for this item;';
					l_status      	  := 'ERROR';
					l_unit_cost_gts   := NULL;

				END;

				--Check if the Unit Cost is zero then Error this record out
				IF l_unit_cost_gts = 0
				OR l_unit_cost_gts IS NULL
				THEN

					l_err_flag    	  := TRUE;
					l_error_msg   	  := l_error_msg || 'No Unit Cost found for this GTS Transfer record. ;';
					l_status      	  := 'ERROR';
					l_unit_cost_gts   := NULL;  

				END IF;
				
		END IF;
		--End - Added changes 5/19/2016 AFlores
		
    v_step := 7;    
        --Derive Transaction Type ID
        BEGIN       
            SELECT mtt.transaction_type_id
            INTO   l_txn_typ_id
            FROM   mtl_transaction_types mtt
            WHERE  mtt.attribute1           = l_new_rec.reason_code 
            AND    mtt.attribute2           = l_new_rec.transaction_code
            AND    ((mtt.attribute3         = l_new_rec.status_code AND TRIM(l_new_rec.status_code) IS NOT NULL) OR mtt.attribute3 IS NULL)
            ;
            
        EXCEPTION
        WHEN NO_DATA_FOUND THEN
            l_err_flag  := TRUE;
            l_error_msg := l_error_msg || 'Error on deriving Transaction type ID;'; 
            l_status    := 'ERROR'; 
                
        END;
    v_step := 8;    
        --Update Records on Stg1 for error records
        IF l_err_flag  = TRUE THEN
        
            UPDATE xxnbty_inv_txn_stg1 stg1
            SET    stg1.error_description = l_error_msg
                  ,stg1.status_flag       = l_status
                  ,stg1.last_update_date  = SYSDATE
                  ,stg1.last_updated_by   = g_user_id
                  ,stg1.creation_date     = SYSDATE 
                  ,stg1.created_by        = g_user_id   
                  ,stg1.last_update_login = g_user_id   
            WHERE  l_new_rec.rowid        = stg1.rowid; 
            
            COMMIT;         
            
            --Insert Error records on the error table
            INSERT INTO xxnbty_inv_error_tbl ( source_code 
                                               ,source_line_id 
                                               ,source_header_id 
                                               ,item_segment1 
                                               ,transaction_quantity 
                                               ,transaction_uom 
                                               ,transaction_date 
                                               ,transaction_reference 
                                               ,vendor_lot_number 
                                               ,shipment_number 
                                               ,lot_number          
                                               ,batch_complete      
                                               ,batch_size          
                                               ,batch_completion_date   
                                               ,reason_code             
                                               ,transaction_code        
                                               ,status_code             
                                               ,as400_source_warehouse 
                                               ,as400_dest_warehouse    
                                               ,status_flag 
                                               ,error_description
                                               ,last_update_date    
                                               ,last_updated_by 
                                               ,creation_date       
                                               ,created_by          
                                               ,last_update_login
											   ,producing_org --Added 4/30/2016 AFlores
                                               ,legacy_reason_code	  --Added 07/06/2016 AFlores for 5 additional columns 
											   ,legacy_txn_type_code  --Added 07/06/2016 AFlores for 5 additional columns 
											   ,legacy_warehouse_snd  --Added 07/06/2016 AFlores for 5 additional columns 
											   ,legacy_warehouse_rcv  --Added 07/06/2016 AFlores for 5 additional columns 
											   ,legacy_pallet_num 	  --Added 07/06/2016 AFlores for 5 additional columns 	   
											   )
											   
            VALUES(l_new_rec.source_code 
                   ,l_new_rec.source_line_id 
                   ,l_new_rec.source_header_id 
                   ,l_new_rec.item_segment1 
                   ,l_new_rec.transaction_quantity 
                   ,l_new_rec.transaction_uom 
                   ,l_new_rec.transaction_date 
                   ,l_new_rec.transaction_reference 
                   ,l_new_rec.vendor_lot_number 
                   ,l_new_rec.shipment_number 
                   ,l_new_rec.lot_number            
                   ,l_batch_complete --l_new_rec.batch_complete      --added by AFlores 5/19/2016  
                   ,l_new_rec.batch_size            
                   ,l_new_rec.batch_completion_date     
                   ,l_new_rec.reason_code           
                   ,l_new_rec.transaction_code      
                   ,NVL(l_new_rec.status_code, NULL)            
                   ,l_new_rec.as400_source_warehouse 
                   ,l_new_rec.as400_dest_warehouse  
                   ,l_status
                   ,l_error_msg
                   ,SYSDATE 
                   ,g_user_id   
                   ,SYSDATE 
                   ,g_user_id   
                   ,g_user_id 
				   ,l_new_rec.producing_org --Added 4/30/2016 AFlores
				   ,l_new_rec.legacy_reason_code	--Added 07/06/2016 AFlores for 5 additional columns 
				   ,l_new_rec.legacy_txn_type_code  --Added 07/06/2016 AFlores for 5 additional columns 
				   ,TO_NUMBER(l_new_rec.legacy_warehouse_snd)  --Added 07/06/2016 AFlores for 5 additional columns 
				   ,TO_NUMBER(l_new_rec.legacy_warehouse_rcv)  --Added 07/06/2016 AFlores for 5 additional columns 
				   ,TO_NUMBER(l_new_rec.legacy_pallet_num)     --Added 07/06/2016 AFlores for 5 additional columns 
				   );
            COMMIT;
            --add count of error and processed records          
            g_total_rec := g_total_rec + 1 ;
            g_err_rec   := g_err_rec + 1 ;
    v_step := 9;        
        --Update Records on stg1 for processed records and insert them on stg2
        ELSIF l_err_flag = FALSE THEN
            --Insert Success records to the staging table 2
            INSERT INTO xxnbty_inv_txn_stg2
            VALUES ( l_new_rec.source_code              
                    ,l_new_rec.source_line_id           
                    ,l_new_rec.source_header_id     
                    ,l_new_rec.process_flag         
                    ,l_new_rec.transaction_mode     
                    ,l_new_rec.item_segment1            
                    ,l_source_org       
                    ,l_new_rec.transaction_quantity 
                    ,l_new_rec.transaction_uom      
                    ,l_new_rec.transaction_date     
                    ,l_subinv_code      
                    ,l_gl_comb1         
                    ,l_gl_comb2         
                    ,l_gl_comb3         
                    ,l_gl_comb4         
                    ,l_gl_comb5         
                    ,l_gl_comb6         
                    ,l_gl_comb7         
                    ,l_gl_comb8         
                    ,l_gl_comb1         
                    ,l_gl_comb2         
                    ,l_gl_comb3         
                    ,l_gl_comb4         
                    ,l_gl_comb5         
                    ,l_gl_comb6         
                    ,l_gl_comb7         
                    ,l_gl_comb8         
                    ,l_txn_typ_id   
                    ,l_new_rec.transaction_reference    
                    ,l_new_rec.vendor_lot_number        
                    ,NVL(l_trans_sub, NULL)
                    ,NVL(l_dest_org, NULL)  
                    ,l_new_rec.shipment_number      
                    ,l_new_rec.lot_number               
                    ,l_batch_complete --l_new_rec.batch_complete       --added by AFlores 5/19/2016      
                    ,l_new_rec.batch_size               
                    ,TO_CHAR((TO_DATE(l_new_rec.batch_completion_date, 'YYYY-MM-DD')), 'DD-MON-YY')    --added by AFlores 5/19/2016
                    ,l_new_rec.reason_code          
                    ,l_new_rec.transaction_code     
                    ,NVL(l_new_rec.status_code, NULL)           
                    ,l_new_rec.as400_source_warehouse   
                    ,l_new_rec.as400_dest_warehouse 
                    ,'PROCESSED'            
                    ,NULL      
                    ,SYSDATE        
                    ,g_user_id      
                    ,SYSDATE            
                    ,g_user_id              
                    ,g_user_id 
					,l_new_rec.producing_org --Added 4/30/2016 AFlores
                    ,l_new_rec.legacy_reason_code	--Added 07/06/2016 AFlores for 5 additional columns 
					,l_new_rec.legacy_txn_type_code  --Added 07/06/2016 AFlores for 5 additional columns 
					,TO_NUMBER(l_new_rec.legacy_warehouse_snd)  --Added 07/06/2016 AFlores for 5 additional columns 
					,TO_NUMBER(l_new_rec.legacy_warehouse_rcv)  --Added 07/06/2016 AFlores for 5 additional columns 
					,TO_NUMBER(l_new_rec.legacy_pallet_num)     --Added 07/06/2016 AFlores for 5 additional columns 
					);
            COMMIT;
             
    v_step := 10;       

            --Update processed records on the staging table 1
            UPDATE xxnbty_inv_txn_stg1 stg1
            SET    stg1.status_flag       = 'PROCESSED'
                  ,stg1.last_update_date  = SYSDATE
                  ,stg1.last_updated_by   = g_user_id
                  ,stg1.creation_date     = SYSDATE 
                  ,stg1.created_by        = g_user_id   
                  ,stg1.last_update_login = g_user_id   
            WHERE  l_new_rec.rowid        = stg1.rowid; 
            
            COMMIT;
            --add count of valid and processed records 
            g_total_rec := g_total_rec + 1 ;
            g_valid_rec := g_valid_rec + 1 ;
            
        END IF;
        
    END LOOP;
    
    v_step := 11;
  
  EXCEPTION
  WHEN OTHERS THEN
  x_retcode := 2;
  v_mess := 'At step ['||v_step||'] for procedure derive_req_fields - SQLCODE [' ||SQLCODE|| '] - ' ||substr(SQLERRM,1,100);
  x_errbuf := v_mess; 
    
  END derive_req_fields;
  
  --Sub Procedure that will duplicate GTS receipt transactions on 2nd staging table
  PROCEDURE duplicate_gts_txn    ( x_errbuf     OUT VARCHAR2, 
                                   x_retcode    OUT VARCHAR2)  
  IS
----------------------------------------------------------------------------------------------------
/*
Package Name: XXNBTY_INVINT01_INV_TXN_PKG
Author's Name: Albert John Flores
Date written: 19-Feb-2016
RICEFW Object: INT01
Description: Reads records from staging table 2 and duplicate GTS transactions receipt records and update some required fields
Program Style: 

Maintenance History: 

Date            Issue#      Name                    Remarks 
-----------     ------      -----------             ------------------------------------------------
19-Feb-2016                 Albert Flores           Initial Development

*/
----------------------------------------------------------------------------------------------------
    --Cursor for GTS Receipts
    CURSOR c_dup_rec IS 
    SELECT  stg2.source_code            source_code                 
           ,stg2.source_line_id         source_line_id              
           ,stg2.source_header_id       source_header_id            
           ,stg2.process_flag           process_flag                
           ,stg2.transaction_mode       transaction_mode            
           ,stg2.item_segment1          item_segment1               
           ,stg2.organization_id        organization_id         
           ,stg2.transaction_quantity   transaction_quantity        
           ,stg2.transaction_uom        transaction_uom         
           ,stg2.transaction_date       transaction_date            
           ,stg2.subinventory_code      subinventory_code           
           ,stg2.dsp_segment1           dsp_segment1                
           ,stg2.dsp_segment2           dsp_segment2                
           ,stg2.dsp_segment3           dsp_segment3                
           ,stg2.dsp_segment4           dsp_segment4                
           ,stg2.dsp_segment5           dsp_segment5                
           ,stg2.dsp_segment6           dsp_segment6                
           ,stg2.dsp_segment7           dsp_segment7                
           ,stg2.dsp_segment8           dsp_segment8                
           ,stg2.dst_segment1           dst_segment1                
           ,stg2.dst_segment2           dst_segment2                
           ,stg2.dst_segment3           dst_segment3                
           ,stg2.dst_segment4           dst_segment4                
           ,stg2.dst_segment5           dst_segment5                
           ,stg2.dst_segment6           dst_segment6                
           ,stg2.dst_segment7           dst_segment7                
           ,stg2.dst_segment8           dst_segment8                
           ,stg2.transaction_type_id    transaction_type_id     
           ,stg2.transaction_reference  transaction_reference       
           ,stg2.vendor_lot_number      vendor_lot_number           
           ,stg2.transfer_subinventory  transfer_subinventory       
           ,stg2.transfer_organization  transfer_organization       
           ,stg2.shipment_number        shipment_number         
           ,stg2.lot_number             lot_number                  
           ,stg2.batch_complete         batch_complete          
           ,stg2.batch_size             batch_size              
           ,stg2.batch_completion_date  batch_completion_date       
           ,stg2.reason_code            reason_code             
           ,stg2.transaction_code       transaction_code            
           ,stg2.status_code            status_code             
           ,stg2.as400_source_warehouse as400_source_warehouse      
           ,stg2.as400_dest_warehouse   as400_dest_warehouse        
           ,stg2.status_flag            status_flag             
           ,stg2.error_description      error_description          
           ,stg2.last_update_date       last_update_date            
           ,stg2.last_updated_by        last_updated_by         
           ,stg2.creation_date          creation_date               
           ,stg2.created_by             created_by              
           ,stg2.last_update_login      last_update_login   
           ,stg2.rowid
		   ,stg2.producing_org			producing_org  --Added 4/30/2016 AFlores
		   ,stg2.legacy_reason_code	    legacy_reason_code      --Added 07/06/2016 AFlores for 5 additional columns
		   ,stg2.legacy_txn_type_code   legacy_txn_type_code    --Added 07/06/2016 AFlores for 5 additional columns
		   ,stg2.legacy_warehouse_snd   legacy_warehouse_snd    --Added 07/06/2016 AFlores for 5 additional columns
		   ,stg2.legacy_warehouse_rcv   legacy_warehouse_rcv    --Added 07/06/2016 AFlores for 5 additional columns
		   ,stg2.legacy_pallet_num      legacy_pallet_num       --Added 07/06/2016 AFlores for 5 additional columns
    FROM xxnbty_inv_txn_stg2            stg2
    WHERE stg2.reason_code          = gts_reason_constant
    AND   stg2.transaction_code     = gts_txn_constant;
    
    
    --Cursor for GTS transfers
    CURSOR c_dup_rec_trans IS
    SELECT  stg2.source_code            source_code                 
           ,stg2.source_line_id         source_line_id              
           ,stg2.source_header_id       source_header_id            
           ,stg2.process_flag           process_flag                
           ,stg2.transaction_mode       transaction_mode            
           ,stg2.item_segment1          item_segment1               
           ,stg2.organization_id        organization_id         
           ,stg2.transaction_quantity   transaction_quantity        
           ,stg2.transaction_uom        transaction_uom         
           ,stg2.transaction_date       transaction_date            
           ,stg2.subinventory_code      subinventory_code           
           ,stg2.dsp_segment1           dsp_segment1                
           ,stg2.dsp_segment2           dsp_segment2                
           ,stg2.dsp_segment3           dsp_segment3                
           ,stg2.dsp_segment4           dsp_segment4                
           ,stg2.dsp_segment5           dsp_segment5                
           ,stg2.dsp_segment6           dsp_segment6                
           ,stg2.dsp_segment7           dsp_segment7                
           ,stg2.dsp_segment8           dsp_segment8                
           ,stg2.dst_segment1           dst_segment1                
           ,stg2.dst_segment2           dst_segment2                
           ,stg2.dst_segment3           dst_segment3                
           ,stg2.dst_segment4           dst_segment4                
           ,stg2.dst_segment5           dst_segment5                
           ,stg2.dst_segment6           dst_segment6                
           ,stg2.dst_segment7           dst_segment7                
           ,stg2.dst_segment8           dst_segment8                
           ,stg2.transaction_type_id    transaction_type_id     
           ,stg2.transaction_reference  transaction_reference       
           ,stg2.vendor_lot_number      vendor_lot_number           
           ,stg2.transfer_subinventory  transfer_subinventory       
           ,stg2.transfer_organization  transfer_organization       
           ,stg2.shipment_number        shipment_number         
           ,stg2.lot_number             lot_number                  
           ,stg2.batch_complete         batch_complete          
           ,stg2.batch_size             batch_size              
           ,stg2.batch_completion_date  batch_completion_date       
           ,stg2.reason_code            reason_code             
           ,stg2.transaction_code       transaction_code            
           ,stg2.status_code            status_code             
           ,stg2.as400_source_warehouse as400_source_warehouse      
           ,stg2.as400_dest_warehouse   as400_dest_warehouse        
           ,stg2.status_flag            status_flag             
           ,stg2.error_description      error_description          
           ,stg2.last_update_date       last_update_date            
           ,stg2.last_updated_by        last_updated_by         
           ,stg2.creation_date          creation_date               
           ,stg2.created_by             created_by              
           ,stg2.last_update_login      last_update_login   
           ,stg2.rowid
		   ,stg2.producing_org			producing_org  --Added 4/30/2016 AFlores
		   ,stg2.legacy_reason_code	    legacy_reason_code      --Added 07/06/2016 AFlores for 5 additional columns
		   ,stg2.legacy_txn_type_code   legacy_txn_type_code    --Added 07/06/2016 AFlores for 5 additional columns
		   ,stg2.legacy_warehouse_snd   legacy_warehouse_snd    --Added 07/06/2016 AFlores for 5 additional columns
		   ,stg2.legacy_warehouse_rcv   legacy_warehouse_rcv    --Added 07/06/2016 AFlores for 5 additional columns
		   ,stg2.legacy_pallet_num      legacy_pallet_num       --Added 07/06/2016 AFlores for 5 additional columns
    FROM xxnbty_inv_txn_stg2            stg2
    WHERE stg2.reason_code          = gtrans_reason_constant
    AND   stg2.transaction_code     = gtrans_txn_constant;
    
    --For GTS Receipts
    l_gts_reason        VARCHAR2(10);
    l_gts_txn           VARCHAR2(10);
    l_gts_status        VARCHAR2(10);
    l_gts_subinv        VARCHAR2(10);
    l_gts_txn_typ_id    NUMBER;  
    
    --For GTS Transfers
    l_gtrans_reason     VARCHAR2(10);
    l_gtrans_txn        VARCHAR2(10);
    l_gtrans_status     VARCHAR2(10);
    l_gtrans_subinv     VARCHAR2(10);
    l_gtrans_txn_typ_id NUMBER; 
    
    v_step              NUMBER;
    v_mess              VARCHAR2(500);
  
  BEGIN
    v_step := 1;
    
    --FOR GTS RECEIPTs
    FOR l_dup_rec IN c_dup_rec
    LOOP
    --Reset identifiers
    l_gts_reason       := NULL;
    l_gts_txn          := NULL;
    l_gts_status       := NULL;
    l_gts_subinv       := NULL;
    l_gts_txn_typ_id   := NULL; 
    
    v_step := 2;
    
        --derive reason code for the new record
        SELECT flv.description 
        INTO   l_gts_reason
        FROM   fnd_lookup_values flv
        WHERE  flv.lookup_type = g_gts_lookup
        AND    UPPER(flv.lookup_code)   = reason_code_constant
        AND    UPPER(flv.meaning)       = reason_code_constant;
        
    v_step := 3;    
    
        --derive transaction code for the new record
        SELECT flv.description 
        INTO   l_gts_txn
        FROM   fnd_lookup_values flv
        WHERE  flv.lookup_type = g_gts_lookup
        AND    UPPER(flv.lookup_code)   = txn_code_constant
        AND    UPPER(flv.meaning)       = txn_code_constant;
        
    v_step := 4;
    
        --derive status code for the new record
        SELECT flv.description 
        INTO   l_gts_status
        FROM   fnd_lookup_values flv
        WHERE  flv.lookup_type = g_gts_lookup
        AND    UPPER(flv.lookup_code)   = status_code_constant
        AND    UPPER(flv.meaning)       = status_code_constant;
        
    v_step := 5;
    
        --derive subinventory code for the new record
        SELECT flv.description 
        INTO   l_gts_subinv
        FROM   fnd_lookup_values flv
        WHERE  flv.lookup_type = g_gts_lookup
        AND    UPPER(flv.lookup_code)   = subinv_code_constant
        AND    UPPER(flv.meaning)       = subinv_code_constant;
        
    v_step := 6;
    
        --Derive Transaction Type ID        
        SELECT mtt.transaction_type_id
        INTO   l_gts_txn_typ_id
        FROM   mtl_transaction_types mtt
        WHERE  mtt.attribute1           = l_gts_reason  
        AND    mtt.attribute2           = l_gts_txn
        AND    ((mtt.attribute3         = l_gts_status AND TRIM(l_gts_status) IS NOT NULL) OR mtt.attribute3 IS NULL);
        
    v_step := 7;    
    
        --Insert Duplicate records with the updated value derived above
        INSERT INTO xxnbty_inv_txn_stg2( source_code            
                                        ,source_line_id         
                                        ,source_header_id       
                                        ,process_flag           
                                        ,transaction_mode       
                                        ,item_segment1          
                                        ,organization_id        
                                        ,transaction_quantity   
                                        ,transaction_uom        
                                        ,transaction_date       
                                        ,subinventory_code      
                                        ,dsp_segment1           
                                        ,dsp_segment2           
                                        ,dsp_segment3           
                                        ,dsp_segment4           
                                        ,dsp_segment5           
                                        ,dsp_segment6           
                                        ,dsp_segment7           
                                        ,dsp_segment8           
                                        ,dst_segment1           
                                        ,dst_segment2           
                                        ,dst_segment3           
                                        ,dst_segment4           
                                        ,dst_segment5           
                                        ,dst_segment6           
                                        ,dst_segment7           
                                        ,dst_segment8           
                                        ,transaction_type_id    
                                        ,transaction_reference  
                                        ,vendor_lot_number      
                                        ,transfer_subinventory  
                                        ,transfer_organization  
                                        ,shipment_number        
                                        ,lot_number             
                                        ,batch_complete         
                                        ,batch_size             
                                        ,batch_completion_date  
                                        ,reason_code            
                                        ,transaction_code       
                                        ,status_code            
                                        ,as400_source_warehouse 
                                        ,as400_dest_warehouse   
                                        ,status_flag            
                                        ,error_description      
                                        ,last_update_date       
                                        ,last_updated_by        
                                        ,creation_date          
                                        ,created_by             
                                        ,last_update_login 
										,producing_org  --Added 4/30/2016 AFlores
                                        ,legacy_reason_code	       --Added 07/06/2016 AFlores for 5 additional columns
										,legacy_txn_type_code      --Added 07/06/2016 AFlores for 5 additional columns
										,legacy_warehouse_snd      --Added 07/06/2016 AFlores for 5 additional columns
										,legacy_warehouse_rcv      --Added 07/06/2016 AFlores for 5 additional columns
										,legacy_pallet_num         --Added 07/06/2016 AFlores for 5 additional columns
										)
        VALUES (l_dup_rec.source_code           
               ,l_dup_rec.source_line_id        
               ,l_dup_rec.source_header_id      
               ,l_dup_rec.process_flag          
               ,l_dup_rec.transaction_mode      
               ,l_dup_rec.item_segment1
               ,l_dup_rec.organization_id   
               ,l_dup_rec.transaction_quantity                          
               ,l_dup_rec.transaction_uom                               
               ,l_dup_rec.transaction_date                              
               ,l_gts_subinv                                
               ,l_dup_rec.dsp_segment1                                  
               ,l_dup_rec.dsp_segment2                                  
               ,l_dup_rec.dsp_segment3                                  
               ,l_dup_rec.dsp_segment4                                  
               ,l_dup_rec.dsp_segment5                                  
               ,l_dup_rec.dsp_segment6                                  
               ,l_dup_rec.dsp_segment7                                  
               ,l_dup_rec.dsp_segment8                                  
               ,l_dup_rec.dst_segment1                                  
               ,l_dup_rec.dst_segment2                                  
               ,l_dup_rec.dst_segment3                                  
               ,l_dup_rec.dst_segment4                                  
               ,l_dup_rec.dst_segment5                                  
               ,l_dup_rec.dst_segment6                                  
               ,l_dup_rec.dst_segment7                                  
               ,l_dup_rec.dst_segment8                                  
               ,l_gts_txn_typ_id                            
               ,l_dup_rec.transaction_reference                             
               ,l_dup_rec.vendor_lot_number                                 
               ,l_dup_rec.transfer_subinventory                         
               ,l_dup_rec.transfer_organization                             
               ,l_dup_rec.shipment_number                               
               ,l_dup_rec.lot_number                                    
               ,l_dup_rec.batch_complete                                    
               ,l_dup_rec.batch_size                                        
               ,l_dup_rec.batch_completion_date                             
               ,l_gts_reason                                    
               ,l_gts_txn                           
               ,l_gts_status                                    
               ,l_dup_rec.as400_source_warehouse                        
               ,l_dup_rec.as400_dest_warehouse                          
               ,l_dup_rec.status_flag                                   
               ,l_dup_rec.error_description                                 
               ,SYSDATE                             
               ,g_user_id                               
               ,SYSDATE                                     
               ,g_user_id                                       
               ,g_user_id 
			   ,l_dup_rec.producing_org     --Added 4/30/2016 AFlores                           
			   ,l_dup_rec.legacy_reason_code	--Added 07/06/2016 AFlores for 5 additional columns
			   ,l_dup_rec.legacy_txn_type_code  --Added 07/06/2016 AFlores for 5 additional columns
			   ,l_dup_rec.legacy_warehouse_snd  --Added 07/06/2016 AFlores for 5 additional columns
			   ,l_dup_rec.legacy_warehouse_rcv  --Added 07/06/2016 AFlores for 5 additional columns
			   ,l_dup_rec.legacy_pallet_num     --Added 07/06/2016 AFlores for 5 additional columns
			   );
    v_step := 8;    
         
        COMMIT;
        
    v_step := 9;    
    
        --Start Changes 3/23/2016 AFlores
        --Update the org ID field of the original record( GTS RECEIPT ) with its transfer org value
        UPDATE xxnbty_inv_txn_stg2 stg2
        SET    stg2.organization_id   = l_dup_rec.transfer_organization
              ,stg2.last_update_date  = SYSDATE
              ,stg2.last_updated_by   = g_user_id
              ,stg2.last_update_login = g_user_id   
        WHERE  stg2.rowid             = l_dup_rec.rowid;    
        
        COMMIT; 
        
    v_step := 10;   
    
    END LOOP;
    
    v_step := 11;
    
    --FOR GTS TRANSFERS
    FOR l_dup_rec_trans IN c_dup_rec_trans
    LOOP
        --Reset identifiers
        l_gtrans_reason         := NULL;
        l_gtrans_txn            := NULL;
        l_gtrans_status         := NULL;
        l_gtrans_subinv         := NULL;
        l_gtrans_txn_typ_id     := NULL;    
        
    v_step := 12;
     
        --derive reason code for the new record
        SELECT flv.description 
        INTO   l_gtrans_reason
        FROM   fnd_lookup_values flv
        WHERE  flv.lookup_type = g_gtrans_lookup
        AND    UPPER(flv.lookup_code)   = reason_code_constant
        AND    UPPER(flv.meaning)       = reason_code_constant;
        
    v_step := 13;   
    
        --derive transaction code for the new record
        SELECT flv.description 
        INTO   l_gtrans_txn
        FROM   fnd_lookup_values flv
        WHERE  flv.lookup_type = g_gtrans_lookup
        AND    UPPER(flv.lookup_code)   = txn_code_constant
        AND    UPPER(flv.meaning)       = txn_code_constant;
        
    v_step := 14;
    
        --derive status code for the new record
        SELECT flv.description 
        INTO   l_gtrans_status
        FROM   fnd_lookup_values flv
        WHERE  flv.lookup_type = g_gtrans_lookup
        AND    UPPER(flv.lookup_code)   = status_code_constant
        AND    UPPER(flv.meaning)       = status_code_constant;
        
    v_step := 15;
    
        --derive subinventory code for the new record
        SELECT flv.description 
        INTO   l_gtrans_subinv
        FROM   fnd_lookup_values flv
        WHERE  flv.lookup_type = g_gtrans_lookup
        AND    UPPER(flv.lookup_code)   = subinv_code_constant
        AND    UPPER(flv.meaning)       = subinv_code_constant;
        
    v_step := 16;
    
        --Derive Transaction Type ID        
        SELECT mtt.transaction_type_id
        INTO   l_gtrans_txn_typ_id
        FROM   mtl_transaction_types mtt
        WHERE  mtt.attribute1           = l_gtrans_reason   
        AND    mtt.attribute2           = l_gtrans_txn
        AND    ((mtt.attribute3         = l_gtrans_status AND TRIM(l_gtrans_status) IS NOT NULL) OR mtt.attribute3 IS NULL);
        
    v_step := 17;
    
        --Insert Duplicate records with the updated value derived above
        INSERT INTO xxnbty_inv_txn_stg2( source_code            
                                        ,source_line_id         
                                        ,source_header_id       
                                        ,process_flag           
                                        ,transaction_mode       
                                        ,item_segment1          
                                        ,organization_id        
                                        ,transaction_quantity   
                                        ,transaction_uom        
                                        ,transaction_date       
                                        ,subinventory_code      
                                        ,dsp_segment1           
                                        ,dsp_segment2           
                                        ,dsp_segment3           
                                        ,dsp_segment4           
                                        ,dsp_segment5           
                                        ,dsp_segment6           
                                        ,dsp_segment7           
                                        ,dsp_segment8           
                                        ,dst_segment1           
                                        ,dst_segment2           
                                        ,dst_segment3           
                                        ,dst_segment4           
                                        ,dst_segment5           
                                        ,dst_segment6           
                                        ,dst_segment7           
                                        ,dst_segment8           
                                        ,transaction_type_id    
                                        ,transaction_reference  
                                        ,vendor_lot_number      
                                        ,transfer_subinventory  
                                        ,transfer_organization  
                                        ,shipment_number        
                                        ,lot_number             
                                        ,batch_complete         
                                        ,batch_size             
                                        ,batch_completion_date  
                                        ,reason_code            
                                        ,transaction_code       
                                        ,status_code            
                                        ,as400_source_warehouse 
                                        ,as400_dest_warehouse   
                                        ,status_flag            
                                        ,error_description      
                                        ,last_update_date       
                                        ,last_updated_by        
                                        ,creation_date          
                                        ,created_by             
                                        ,last_update_login 
										,producing_org
										,legacy_reason_code	       --Added 07/06/2016 AFlores for 5 additional columns
										,legacy_txn_type_code      --Added 07/06/2016 AFlores for 5 additional columns
										,legacy_warehouse_snd      --Added 07/06/2016 AFlores for 5 additional columns
										,legacy_warehouse_rcv      --Added 07/06/2016 AFlores for 5 additional columns
										,legacy_pallet_num         --Added 07/06/2016 AFlores for 5 additional columns
										)
                                        
        VALUES (l_dup_rec_trans.source_code             
               ,l_dup_rec_trans.source_line_id      
               ,l_dup_rec_trans.source_header_id        
               ,l_dup_rec_trans.process_flag            
               ,l_dup_rec_trans.transaction_mode        
               ,l_dup_rec_trans.item_segment1
               ,l_dup_rec_trans.organization_id     
               ,l_dup_rec_trans.transaction_quantity                            
               ,l_dup_rec_trans.transaction_uom                                 
               ,l_dup_rec_trans.transaction_date                                
               ,l_gtrans_subinv                             
               ,l_dup_rec_trans.dsp_segment1                                    
               ,l_dup_rec_trans.dsp_segment2                                    
               ,l_dup_rec_trans.dsp_segment3                                    
               ,l_dup_rec_trans.dsp_segment4                                    
               ,l_dup_rec_trans.dsp_segment5                                    
               ,l_dup_rec_trans.dsp_segment6                                    
               ,l_dup_rec_trans.dsp_segment7                                    
               ,l_dup_rec_trans.dsp_segment8                                    
               ,l_dup_rec_trans.dst_segment1                                    
               ,l_dup_rec_trans.dst_segment2                                    
               ,l_dup_rec_trans.dst_segment3                                    
               ,l_dup_rec_trans.dst_segment4                                    
               ,l_dup_rec_trans.dst_segment5                                    
               ,l_dup_rec_trans.dst_segment6                                    
               ,l_dup_rec_trans.dst_segment7                                    
               ,l_dup_rec_trans.dst_segment8                                    
               ,l_gtrans_txn_typ_id                         
               ,l_dup_rec_trans.transaction_reference                           
               ,l_dup_rec_trans.vendor_lot_number                               
               ,l_dup_rec_trans.transfer_subinventory                           
               ,l_dup_rec_trans.transfer_organization                           
               ,l_dup_rec_trans.shipment_number                                 
               ,l_dup_rec_trans.lot_number                                  
               ,l_dup_rec_trans.batch_complete                                  
               ,l_dup_rec_trans.batch_size                                      
               ,l_dup_rec_trans.batch_completion_date                           
               ,l_gtrans_reason                                 
               ,l_gtrans_txn                            
               ,l_gtrans_status                                     
               ,l_dup_rec_trans.as400_source_warehouse                      
               ,l_dup_rec_trans.as400_dest_warehouse                            
               ,l_dup_rec_trans.status_flag                                     
               ,l_dup_rec_trans.error_description                               
               ,SYSDATE                             
               ,g_user_id                               
               ,SYSDATE                                     
               ,g_user_id                                       
               ,g_user_id 
			   ,l_dup_rec_trans.producing_org     --Added 4/30/2016 AFlores                           
               ,l_dup_rec_trans.legacy_reason_code		--Added 07/06/2016 AFlores for 5 additional columns
			   ,l_dup_rec_trans.legacy_txn_type_code  	--Added 07/06/2016 AFlores for 5 additional columns
			   ,l_dup_rec_trans.legacy_warehouse_snd  	--Added 07/06/2016 AFlores for 5 additional columns
			   ,l_dup_rec_trans.legacy_warehouse_rcv	--Added 07/06/2016 AFlores for 5 additional columns
			   ,l_dup_rec_trans.legacy_pallet_num     	--Added 07/06/2016 AFlores for 5 additional columns
			   );
    v_step := 18;   
         
        COMMIT;
    
    v_step := 19;   
    
    END LOOP;   
    
    --Update subinventory of the records that has 'WC' or 'BC' 
    UPDATE xxnbty_inv_txn_stg2 stg2
    SET    stg2.subinventory_code = 'YIELD COMP'
    WHERE stg2.reason_code IN ('WC' , 'BC');
    
    COMMIT;
    
    --End of changes 3/23/2016 AFlores
    
    --Update records that has 'D' for the Transaction code
    UPDATE xxnbty_inv_txn_stg2 stg2
    SET stg2.transaction_quantity = (0 - ABS(stg2.transaction_quantity))
    WHERE stg2.transaction_code = 'D';
    
    COMMIT;
  
  EXCEPTION
  WHEN OTHERS THEN
  x_retcode := 2;
  v_mess := 'At step ['||v_step||'] for procedure duplicate_gts_txn - SQLCODE [' ||SQLCODE|| '] - ' ||substr(SQLERRM,1,100);
  x_errbuf := v_mess; 
  
  END duplicate_gts_txn;
  

  --Sub Procedure that will insert records from the staging table 2 to the interface table
  PROCEDURE insert_records      ( x_errbuf      OUT VARCHAR2, 
                                  x_retcode     OUT VARCHAR2)
  IS
----------------------------------------------------------------------------------------------------
/*
Package Name: XXNBTY_INVINT01_INV_TXN_PKG
Author's Name: Albert John Flores
Date written: 19-Feb-2016
RICEFW Object: INT01
Description: Inserts records from the staging table 2 XXNBTY_INV_TXN_STG2 to interface table MTL_TRANSACTIONS_INTERFACE 
Program Style: 

Maintenance History: 

Date            Issue#      Name                    Remarks 
-----------     ------      -----------             ------------------------------------------------
19-Feb-2016                 Albert Flores           Initial Development

*/
----------------------------------------------------------------------------------------------------
    v_step          NUMBER;
    v_mess          VARCHAR2(500);  
  
  BEGIN
  
    v_step := 1;
    --insert records from 2nd staging table to interface table
    INSERT INTO mtl_transactions_interface(source_code                      
                                            ,source_line_id                 
                                            ,source_header_id               
                                            ,process_flag                   
                                            ,transaction_mode               
                                            ,item_segment1                  
                                            ,organization_id                
                                            ,transaction_quantity           
                                            ,transaction_uom                
                                            ,transaction_date               
                                            ,subinventory_code              
                                            ,dsp_segment1                   
                                            ,dsp_segment2                   
                                            ,dsp_segment3                   
                                            ,dsp_segment4                   
                                            ,dsp_segment5                   
                                            ,dsp_segment6                   
                                            ,dsp_segment7                   
                                            ,dsp_segment8                   
                                            ,dst_segment1                   
                                            ,dst_segment2                   
                                            ,dst_segment3                   
                                            ,dst_segment4                   
                                            ,dst_segment5                   
                                            ,dst_segment6                   
                                            ,dst_segment7                   
                                            ,dst_segment8                   
                                            ,transaction_type_id            
                                            ,transaction_reference          
                                            ,vendor_lot_number              
                                            ,transfer_subinventory          
                                            ,transfer_organization          
                                            ,shipment_number                
                                            ,attribute1                     
                                            ,attribute2                     
                                            ,attribute3                     
                                            ,attribute4 
											,attribute5 --Added 4/30/2016 AFlores                           
                                            ,last_update_date
                                            ,last_updated_by
                                            ,creation_date
                                            ,created_by
											,attribute6     --Added 07/06/2016 AFlores for 5 additional columns
											,attribute7     --Added 07/06/2016 AFlores for 5 additional columns
											,attribute8     --Added 07/06/2016 AFlores for 5 additional columns
											,attribute9     --Added 07/06/2016 AFlores for 5 additional columns
											,attribute10    --Added 07/06/2016 AFlores for 5 additional columns
                                            )
    SELECT source_code                      
            ,source_line_id                 
            ,source_header_id               
            ,process_flag                   
            ,transaction_mode               
            ,item_segment1                  
            ,organization_id                
            ,transaction_quantity           
            ,transaction_uom                
            ,transaction_date               
            ,subinventory_code              
            ,dsp_segment1                   
            ,dsp_segment2                   
            ,dsp_segment3                   
            ,dsp_segment4                   
            ,dsp_segment5                   
            ,dsp_segment6                   
            ,dsp_segment7                   
            ,dsp_segment8                   
            ,dst_segment1                   
            ,dst_segment2                   
            ,dst_segment3                   
            ,dst_segment4                   
            ,dst_segment5                   
            ,dst_segment6                   
            ,dst_segment7                   
            ,dst_segment8                   
            ,transaction_type_id            
            ,transaction_reference          
            ,vendor_lot_number              
            ,NULL--transfer_subinventory     AFLORES 4/27/2016     
            ,NULL--transfer_organization     AFLORES 4/27/2016     
            ,shipment_number                
            ,lot_number                                 
            ,batch_complete                             
            ,batch_size                                 
            ,batch_completion_date 
			,producing_org --Added 4/30/2016 AFlores                           
            ,last_update_date
            ,last_updated_by
            ,creation_date
            ,created_by
			,legacy_reason_code	      --Added 07/06/2016 AFlores for 5 additional columns
			,legacy_txn_type_code     --Added 07/06/2016 AFlores for 5 additional columns
			,legacy_warehouse_snd     --Added 07/06/2016 AFlores for 5 additional columns
			,legacy_warehouse_rcv     --Added 07/06/2016 AFlores for 5 additional columns
			,legacy_pallet_num        --Added 07/06/2016 AFlores for 5 additional columns
			
    FROM xxnbty_inv_txn_stg2;
    
    v_step := 2;    
    
    COMMIT;
    
    v_step := 3;
 
  EXCEPTION
  WHEN OTHERS THEN
  x_retcode := 2;
  v_mess := 'At step ['||v_step||'] for procedure insert_records - SQLCODE [' ||SQLCODE|| '] - ' ||substr(SQLERRM,1,100);
  x_errbuf := v_mess; 
 
  END insert_records;

  --Start of changes 3/29/2016 AFLORES
  --Sub Procedure that will print a summary report via log file
  PROCEDURE generate_report     ( x_errbuf      OUT VARCHAR2, 
                                  x_retcode     OUT VARCHAR2,
                                  p_recipients      VARCHAR2)
  IS
----------------------------------------------------------------------------------------------------
/*
Package Name: XXNBTY_INVINT01_INV_TXN_PKG
Author's Name: Albert John Flores
Date written: 23-Feb-2016
RICEFW Object: INT01
Description: Print a summary report for the current run
Program Style: 

Maintenance History: 

Date            Issue#      Name                    Remarks 
-----------     ------      -----------             ------------------------------------------------
23-Feb-2016                 Albert Flores           Initial Development

*/
----------------------------------------------------------------------------------------------------
        
    l_request_id            NUMBER := fnd_global.conc_request_id;
    l_stg_req_id            NUMBER;
    l_int_req_id            NUMBER;
    l_interface_count       NUMBER := 0;
    l_submit_email_id       NUMBER;
            
    l_wait                  BOOLEAN;
    l_phase                 VARCHAR2(100)   := NULL;
    l_status                VARCHAR2(30)    := NULL;
    l_devphase              VARCHAR2(100)   := NULL;
    l_devstatus             VARCHAR2(100)   := NULL;
    l_mesg                  VARCHAR2(50)    := NULL;
    
    l_subject               VARCHAR2(100);
    l_message               VARCHAR2(240);
    l_recipient             VARCHAR2(1000);
    l_cc                    VARCHAR2(240);
    l_bcc                   VARCHAR2(240);
    
    l_stg_old_filename      VARCHAR2(1000);
    l_int_old_filename      VARCHAR2(1000);
    
    l_stg_new_filename      VARCHAR2(1000);
    l_int_new_filename      VARCHAR2(1000);
    
    v_step                  NUMBER;
    v_mess                  VARCHAR2(500);

  BEGIN

        v_step := 1;
        
        IF g_err_rec > 0 THEN
        
                --call detailed error report for the staging errors
                l_stg_req_id := FND_REQUEST.SUBMIT_REQUEST(  application  => 'XXNBTY'
                                                            ,program      => 'XXNBTY_INV_INTERFACE_STG_ERR'
                                                            ,start_time   => NULL
                                                            ,sub_request  => FALSE
                                                          );
                COMMIT;
        
        v_step := 2;
        
                l_wait := fnd_concurrent.wait_for_request( request_id      => l_stg_req_id
                                                          , interval        => 60
                                                          , max_wait        => ''
                                                          , phase           => l_phase
                                                          , status          => l_status
                                                          , dev_phase       => l_devphase
                                                          , dev_status      => l_devstatus
                                                          , message         => l_mesg
                                                          );
                COMMIT;
                
        v_step := 3;        
                
                --check for the report completion
                IF (l_devphase = 'COMPLETE' AND l_devstatus = 'NORMAL') THEN
                
                  FND_FILE.PUT_LINE(FND_FILE.LOG,'XXNBTY Inventory Interface Error Report on Staging table has completed successfully');
                  FND_FILE.PUT_LINE(FND_FILE.LOG,'Request ID of XXNBTY Inventory Interface Error Report on Staging table is ' || l_stg_req_id);
                  FND_FILE.PUT_LINE(FND_FILE.LOG,'Calling the EBS Send Email Program to send the output file of the report');
                        
        v_step := 4;
        
                    BEGIN   
                    
                        --get the output of the report using its request id
                        SELECT  fcr.outfile_name
                        INTO    l_stg_old_filename
                        FROM    fnd_concurrent_requests fcr
                        WHERE   fcr.request_id = l_stg_req_id;
                        FND_FILE.PUT_LINE(FND_FILE.LOG,'old file name ' || l_stg_old_filename);
                        
        v_step := 5;
                        
                    EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                    FND_FILE.PUT_LINE(FND_FILE.LOG,'NO DATA FOUND FOR STAGING ERROR REPORT');
                    
                    END;    
                        
        v_step := 6;
                        
                        --File Name to be used
                        l_stg_new_filename := 'XXNBTY_INVENTORY_STAGING_ERRORS_' || TO_CHAR(SYSDATE, 'YYYYMMDD') || '.csv';
                        
        v_step := 7;
                        
                        --Email Message
                        l_message      := 'Hi,\n\nAttached is the XXNBTY Inventory Interface Error Report on Staging Table 1 \n\n*****This is an auto-generated e-mail. Please do not reply.*****';
                        
        v_step := 8;
                        
                        --Email Subject
                        l_subject      := 'XXNBTY Inventory Interface Staging Table Errors';
                        
        v_step := 9;
                        
                        --Recipients
                        
                        
                        l_cc           := '';
                        l_bcc          := '';
                        
        v_step := 10;
                        FND_FILE.PUT_LINE(FND_FILE.LOG,'Calling the EBS Send Email Program right now');
                        --Call the concurrent program to send email notification
                        l_submit_email_id := FND_REQUEST.SUBMIT_REQUEST(application  => 'XXNBTY'
                                                               ,program      => 'XXNBTY_EBS_SEND_EMAIL_LOG'
                                                               ,start_time   => NULL
                                                               ,sub_request  => FALSE
                                                               ,argument1    => l_stg_new_filename
                                                               ,argument2    => l_stg_old_filename
                                                               ,argument3    => p_recipients
                                                               ,argument4    => l_cc
                                                               ,argument5    => l_bcc
                                                               ,argument6    => l_subject
                                                               ,argument7    => l_message
                                                               ,argument8    => 'NONE'
                                                               ,argument9    => 'NONE'
                                                               ,argument10    => 'NONE'
                                                               ,argument11    => 'NONE'
                                                               ,argument12    => 'NONE'
                                                               ,argument13    => 'NONE'
                                                               ,argument14    => 'NONE'
                                                               ,argument15    => 'NONE'
                                                               ,argument16    => 'NONE'
                                                               ,argument17    => 'NONE'
                                                               );         
                    
        v_step := 11;
            
                ELSE
                
                  FND_FILE.PUT_LINE(FND_FILE.LOG,'Error has been encountered when running the XXNBTY Inventory Interface Error Report on Staging table.' );
                
                END IF;
        
        v_step := 12;
        
        ELSE
        
            FND_FILE.PUT_LINE(FND_FILE.LOG,'There were no records found on Staging Table 1' );
        
        END IF;
        
        v_step := 13;
        
        --start of error program for interface table
        SELECT COUNT(*) 
        INTO   l_interface_count
        FROM    mtl_transactions_interface
        where   request_id > g_stndrd_prog_id;
    
        IF l_interface_count > 0 THEN
        
                --call detailed error report for the interface errors
                l_int_req_id := FND_REQUEST.SUBMIT_REQUEST(  application  => 'XXNBTY'
                                                            ,program      => 'XXNBTY_INV_INTERFACE_INT_ERR'
                                                            ,start_time   => NULL
                                                            ,sub_request  => FALSE
                                                            ,argument1    => g_stndrd_prog_id
                                                          );
                COMMIT;
        
        v_step := 14;
        
                l_wait := fnd_concurrent.wait_for_request( request_id      => l_int_req_id
                                                          , interval        => 50
                                                          , max_wait        => ''
                                                          , phase           => l_phase
                                                          , status          => l_status
                                                          , dev_phase       => l_devphase
                                                          , dev_status      => l_devstatus
                                                          , message         => l_mesg
                                                          );
                COMMIT;
                
        v_step := 15;       
                
                --check for the report completion
                IF (l_devphase = 'COMPLETE' AND l_devstatus = 'NORMAL') THEN
                
                  FND_FILE.PUT_LINE(FND_FILE.LOG,'XXNBTY Inventory Interface Error Report on Interface table has completed successfully');
                  FND_FILE.PUT_LINE(FND_FILE.LOG,'Request ID of XXNBTY Inventory Interface Error Report on Interface table is ' || l_int_req_id);
                  FND_FILE.PUT_LINE(FND_FILE.LOG,'Calling the EBS Send Email Program to send the output file of the report');
                        
        v_step := 16;
        
                    BEGIN   
                    
                        --get the output of the report using its request id
                        SELECT  fcr.outfile_name
                        INTO    l_int_old_filename
                        FROM    fnd_concurrent_requests fcr
                        WHERE   fcr.request_id = l_int_req_id;
                        FND_FILE.PUT_LINE(FND_FILE.LOG,'old file name ' || l_int_old_filename);
                        
        v_step := 17;
                        
                    EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                    FND_FILE.PUT_LINE(FND_FILE.LOG,'NO DATA FOUND FOR INTERFACE TABLE ERROR REPORT');
                    
                    END;
                        
        v_step := 18;
                        
                        --File Name to be used
                        l_int_new_filename := 'XXNBTY_INVENTORY_INTERFACE_ERRORS_' || TO_CHAR(SYSDATE, 'YYYYMMDD') || '.csv';
                        
        v_step := 19;
                        
                        --Email Message
                        l_message      := 'Hi,\n\nAttached is the XXNBTY Inventory Interface Error Report on Interface table \n\n*****This is an auto-generated e-mail. Please do not reply.*****';
                        
        v_step := 20;
                        
                        --Email Subject
                        l_subject      := 'XXNBTY Inventory Interface Interface Table Errors';
                        
        v_step := 21;
                        
                        --Recipients
                        
                        
                        l_cc           := '';
                        l_bcc          := '';
                        
        v_step := 22;
                        FND_FILE.PUT_LINE(FND_FILE.LOG,'Calling the EBS Send Email Program right now');
                        --Call the concurrent program to send email notification
                        l_submit_email_id := FND_REQUEST.SUBMIT_REQUEST(application  => 'XXNBTY'
                                                               ,program      => 'XXNBTY_EBS_SEND_EMAIL_LOG'
                                                               ,start_time   => NULL
                                                               ,sub_request  => FALSE
                                                               ,argument1    => l_int_new_filename
                                                               ,argument2    => l_int_old_filename
                                                               ,argument3    => p_recipients
                                                               ,argument4    => l_cc
                                                               ,argument5    => l_bcc
                                                               ,argument6    => l_subject
                                                               ,argument7    => l_message
                                                               ,argument8    => 'NONE'
                                                               ,argument9    => 'NONE'
                                                               ,argument10    => 'NONE'
                                                               ,argument11    => 'NONE'
                                                               ,argument12    => 'NONE'
                                                               ,argument13    => 'NONE'
                                                               ,argument14    => 'NONE'
                                                               ,argument15    => 'NONE'
                                                               ,argument16    => 'NONE'
                                                               ,argument17    => 'NONE'
                                                               );         
                    
        v_step := 23;
            
                ELSE
                
                  FND_FILE.PUT_LINE(FND_FILE.LOG,'Error has been encountered when running the XXNBTY Inventory Interface Error Report on Interface table.' );
                
                END IF;
        
        v_step := 24;
        
        ELSE
        
            FND_FILE.PUT_LINE(FND_FILE.LOG,'There were no records found on Interface Table' );
        
        END IF;
    
        v_step := 25;
  EXCEPTION  
    WHEN OTHERS THEN
    x_retcode := 2;
    v_mess := 'At step ['||v_step||'] for procedure generate_report - SQLCODE [' ||SQLCODE|| '] - ' ||substr(SQLERRM,1,100);
    x_errbuf := v_mess;
  
  END generate_report;
  
  --Sub Procedure that will archive records from the staging table 2 to the archive table
  PROCEDURE archive_records   (x_errbuf                 OUT VARCHAR2,
                               x_retcode                OUT VARCHAR2)
  IS
----------------------------------------------------------------------------------------------------
/*
Package Name: XXNBTY_INVINT01_INV_TXN_PKG
Author's Name: Albert John Flores
Date written: 19-Feb-2016
RICEFW Object: INT01
Description: Archives records from the staging table 2 XXNBTY_INV_TXN_STG2 to archive table XXNBTY_INV_TXN_ARCH 
             deletes 7 days old records from the archive table
Program Style: 

Maintenance History: 

Date            Issue#      Name                    Remarks 
-----------     ------      -----------             ------------------------------------------------
19-Feb-2016                 Albert Flores           Initial Development

*/
----------------------------------------------------------------------------------------------------
    v_step          NUMBER;
    v_mess          VARCHAR2(500);
     
  BEGIN
  
      v_step := 1;
      --delete 7 days old records from archive table XXNBTY_INV_TXN_ARCH
      DELETE FROM xxnbty_inv_txn_arch
      WHERE (TRUNC(SYSDATE) - TO_DATE(creation_date)) > 7;
      COMMIT;
      
      v_step :=2;
      --insert records from 2nd staging table to the archive table
      INSERT INTO xxnbty_inv_txn_arch
      SELECT * FROM xxnbty_inv_txn_stg2;
      COMMIT;
      
      v_step :=3;
  
  EXCEPTION  
    WHEN OTHERS THEN
    x_retcode := 2;
    v_mess := 'At step ['||v_step||'] for procedure archive_records - SQLCODE [' ||SQLCODE|| '] - ' ||substr(SQLERRM,1,100);
    x_errbuf := v_mess;
    
  END archive_records;
  
--Start of changes for standard program submission AFLORES 3/29/2016
  PROCEDURE submit_standard_prog      ( x_retcode     OUT VARCHAR2,
                                        x_errbuf      OUT VARCHAR2)
  IS
  --------------------------------------------------------------------------------------------
  /*
  Procedure Name: submit_standard_prog
  Author's Name: Albert John Flores
  Date written: 29-MAR-2016
  RICEFW Object: INT01
  Description: Procedure that will call the standard program to process the interface table records
  Program Style:
  Maintenance History:
  Date         Issue#  Name                         Remarks
  -----------  ------  -------------------      ------------------------------------------------
  29-MAR-2016          Albert John Flores       Initial Development

  */
  --------------------------------------------------------------------------------------------
    l_wait             BOOLEAN;
    l_resp_appl_id     NUMBER;
    l_resp_id          NUMBER;
    
    l_phase            VARCHAR2(100)   := NULL;
    l_status           VARCHAR2(30)    := NULL;
    l_devphase         VARCHAR2(100)   := NULL;
    l_devstatus        VARCHAR2(100)   := NULL;
    l_mesg             VARCHAR2(50)    := NULL;
    l_count1           NUMBER;
    v_step             NUMBER;
    v_mess             VARCHAR2(500);

  BEGIN
    v_step := 1;
    FND_FILE.PUT_LINE(FND_FILE.LOG,'Entered Procedure to call the standard program ' );
    
        SELECT responsibility_id,application_id
        INTO l_resp_id,l_resp_appl_id
        FROM fnd_responsibility
        WHERE responsibility_key = 'INVENTORY';
        
        apps.fnd_global.apps_initialize (g_user_id,l_resp_id,l_resp_appl_id);
        
        g_stndrd_prog_id := FND_REQUEST.SUBMIT_REQUEST(application  => 'INV'
                                                    ,program      => 'INCTCM'
                                                    ,start_time   => NULL
                                                    ,sub_request  => FALSE
                                                    );

        COMMIT;
    v_step := 2;
    
        IF g_stndrd_prog_id > 0 THEN
        LOOP
        
			SELECT COUNT(*) 
			INTO l_count1
			FROM fnd_concurrent_requests
			WHERE parent_request_id = g_stndrd_prog_id
			AND status_code NOT IN ( 'C','E' );
		
				l_wait := fnd_concurrent.wait_for_request( request_id       => g_stndrd_prog_id
														  , interval        => 50
														  , max_wait        => 60
														  , phase           => l_phase
														  , status          => l_status
														  , dev_phase       => l_devphase
														  , dev_status      => l_devstatus
														  , message         => l_mesg
														  );
														  
				EXIT WHEN ((UPPER(l_devstatus) = 'NORMAL' AND UPPER(l_devphase) = 'COMPLETE')
						  OR (UPPER(l_devstatus) IN ('WARNING', 'ERROR') ))
					AND l_count1 = 0;                                         
            
        END LOOP;
        
        COMMIT; 

        END IF;
    v_step := 3;
        --check for the report completion
        IF (UPPER(l_devstatus) = 'NORMAL' AND UPPER(l_devphase) = 'COMPLETE')
                      OR (UPPER(l_devstatus) IN ('WARNING', 'ERROR') ) THEN
          FND_FILE.PUT_LINE(FND_FILE.LOG,'Process transactions interface has completed successfully');
          FND_FILE.PUT_LINE(FND_FILE.LOG,'Request ID of Process transactions interface is ' || g_stndrd_prog_id);
    v_step := 4;
        ELSE
          FND_FILE.PUT_LINE(FND_FILE.LOG,'Request ID of Process transactions interface is ' || g_stndrd_prog_id);
          FND_FILE.PUT_LINE(FND_FILE.LOG,'Error encountered upon submitting standard program');
        END IF;
    v_step := 5;

  EXCEPTION  
    WHEN OTHERS THEN
    x_retcode := 2;
    v_mess := 'At step ['||v_step||'] for procedure submit_standard_prog - SQLCODE [' ||SQLCODE|| '] - ' ||substr(SQLERRM,1,100);
    x_errbuf := v_mess;
    
  END submit_standard_prog;
--End of changes for standard program submission  AFLORES 3/29/2016
  
END XXNBTY_INVINT01_INV_TXN_PKG;

/

show errors;
