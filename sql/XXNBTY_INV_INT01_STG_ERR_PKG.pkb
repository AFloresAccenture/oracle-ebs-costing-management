create or replace PACKAGE BODY       XXNBTY_INVINT01_STG_ERR_PKG 
 ---------------------------------------------------------------------------------------------
  /*
  Package Name  : XXNBTY_INVINT01_STG_ERR_PKG
  Author's Name: Albert John Flores
  Date written: 29-Mar-2016
  RICEFW Object: REP02
  Description: Package that will generate detailed error log for Inventory Interface using FND_FILE. 
  Program Style:
  Maintenance History:
  Date         Issue#  Name                         Remarks
  -----------  ------  -------------------      ------------------------------------------------
  29-Mar-2016          Albert John Flores       Initial Development
  03-May-2016		   Albert John Flores		Accomodated producing_org changes
  05-Jul-2016		   Albert John Flores		Accomodated 5 additional columns
  */
  ----------------------------------------------------------------------------------------------
 IS 
  PROCEDURE main_proc ( x_retcode   OUT VARCHAR2
                       ,x_errbuf    OUT VARCHAR2)
  IS
        
        CURSOR c_gen_error 
        IS
        SELECT '"'||status_flag
                ||'","'||error_description            
                ||'","'||source_code      
                ||'","'||source_line_id                 
                ||'","'||source_header_id       
                ||'","'||item_segment1                 
                ||'","'||transaction_quantity               
                ||'","'||transaction_uom               
                ||'","'||transaction_date         
                ||'","'||transaction_reference                      
                ||'","'||vendor_lot_number                      
                ||'","'||shipment_number                      
                ||'","'||lot_number                      
                ||'","'||batch_complete                      
                ||'","'||batch_size                          
                ||'","'||batch_completion_date                         
                ||'","'||reason_code                   
                ||'","'||transaction_code                       
                ||'","'||status_code        
				||'","'||producing_org 
                ||'","'||as400_source_warehouse                      
                ||'","'||as400_dest_warehouse                        
                ||'","'||last_update_date                        
                ||'","'||last_updated_by                     
                ||'","'||creation_date                 
                ||'","'||created_by              
                ||'","'||last_update_login 
				||'","'||legacy_reason_code	           --Added 07/05/2016 AFlores for 5 additional columns
				||'","'||legacy_txn_type_code	       --Added 07/05/2016 AFlores for 5 additional columns
				||'","'||legacy_warehouse_snd	       --Added 07/05/2016 AFlores for 5 additional columns
				||'","'||legacy_warehouse_rcv	       --Added 07/05/2016 AFlores for 5 additional columns
				||'","'||legacy_pallet_num 			   --Added 07/05/2016 AFlores for 5 additional columns	
				||'"'    INV_STG_TBL
                FROM xxnbty_inv_error_tbl;
                        
    
    v_step                     NUMBER;
    v_mess                     VARCHAR2(500);
    
   BEGIN
    v_step := 1;

        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'STATUS_FLAG,ERROR_DESCRIPTION,SOURCE_CODE,SOURCE_LINE_ID,SOURCE_HEADER_ID,ITEM_SEGMENT1,TRANSACTION_QUANTITY,TRANSACTION_UOM,TRANSACTION_DATE,TRANSACTION_REFERENCE,VENDOR_LOT_NUMBER,SHIPMENT_NUMBER,LOT_NUMBER,BATCH_COMPLETE,BATCH_SIZE,BATCH_COMPLETION_DATE,REASON_CODE,TRANSACTION_CODE,STATUS_CODE,PRODUCING_ORG,AS400_SOURCE_WAREHOUSE,AS400_DEST_WAREHOUSE,LAST_UPDATE_DATE,LAST_UPDATED_BY,CREATION_DATE,CREATED_BY,LAST_UPDATE_LOGIN,LEGACY_REASON_CODE,LEGACY_TXN_TYPE_CODE,LEGACY_WAREHOUSE_SND,LEGACY_WAREHOUSE_RCV,LEGACY_PALLET_NUM');
        
    v_step := 2;

        FOR l_err_rec IN c_gen_error
        
            LOOP
            
                FND_FILE.PUT_LINE(FND_FILE.OUTPUT, l_err_rec.INV_STG_TBL);
                
            END LOOP;
            
    v_step := 3;
    
    EXCEPTION
        WHEN OTHERS THEN
          v_mess := 'At step ['||v_step||'] - SQLCODE [' ||SQLCODE|| '] - ' ||substr(SQLERRM,1,100);
          x_errbuf  := v_mess;
          x_retcode := 2; 

   END main_proc;
        
END XXNBTY_INVINT01_STG_ERR_PKG;

/

show errors;
                    