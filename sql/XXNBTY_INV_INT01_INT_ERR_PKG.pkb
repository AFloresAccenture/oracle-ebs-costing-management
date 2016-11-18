create or replace PACKAGE BODY       XXNBTY_INVINT01_INT_ERR_PKG 
 ---------------------------------------------------------------------------------------------
  /*
  Package Name  : XXNBTY_INVINT01_INT_ERR_PKG
  Author's Name: Albert John Flores
  Date written: 29-Mar-2016
  RICEFW Object: INT01
  Description: Package that will generate detailed error log for Inventory interface table using FND_FILE. 
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
                       ,x_errbuf    OUT VARCHAR2
                       ,p_request_id    NUMBER )
  IS
   
    l_header            VARCHAR2(32000);    
    
        CURSOR c_gen_error (p_request_id NUMBER)
        IS
        SELECT  '"'||error_explanation
                ||'","'||error_code
                ||'","'||transaction_interface_id
                ||'","'||source_code                        
                ||'","'||source_line_id                 
                ||'","'||source_header_id               
                ||'","'||process_flag                   
                ||'","'||transaction_mode               
                ||'","'||item_segment1                  
                ||'","'||organization_id                
                ||'","'||transaction_quantity   
                ||'","'||primary_quantity       
                ||'","'||transaction_uom                
                ||'","'||transaction_date               
                ||'","'||subinventory_code              
                ||'","'||transaction_type_id            
                ||'","'||transaction_reference          
                ||'","'||vendor_lot_number              
                ||'","'||transfer_subinventory          
                ||'","'||transfer_organization          
                ||'","'||shipment_number                
                ||'","'||attribute1                     
                ||'","'||attribute2                     
                ||'","'||attribute3                     
                ||'","'||attribute4 
				||'","'||attribute5 
                ||'","'||dsp_segment1                   
                ||'","'||dsp_segment2                   
                ||'","'||dsp_segment3                   
                ||'","'||dsp_segment4                   
                ||'","'||dsp_segment5                   
                ||'","'||dsp_segment6                   
                ||'","'||dsp_segment7                   
                ||'","'||dsp_segment8                   
                ||'","'||dst_segment1                   
                ||'","'||dst_segment2                   
                ||'","'||dst_segment3                   
                ||'","'||dst_segment4                   
                ||'","'||dst_segment5                   
                ||'","'||dst_segment6                   
                ||'","'||dst_segment7                   
                ||'","'||dst_segment8 
				||'","'||attribute6	                      --Added 07/05/2016 AFlores for 5 additional columns
				||'","'||attribute7	                  --Added 07/05/2016 AFlores for 5 additional columns
				||'","'||attribute8	                  --Added 07/05/2016 AFlores for 5 additional columns
				||'","'||attribute9	                  --Added 07/05/2016 AFlores for 5 additional columns
				||'","'||attribute10 		                  --Added 07/05/2016 AFlores for 5 additional columns
				||'"'   INVENTORY_INTERFACE_TBL           
                FROM mtl_transactions_interface 
                WHERE request_id > p_request_id;
                
    TYPE err_tab_type          IS TABLE OF c_gen_error%ROWTYPE;
      
    l_detailed_error_tab       err_tab_type;                
                        

    v_step                     NUMBER;
    v_mess                     VARCHAR2(500);
    
   BEGIN
    v_step := 1;

     l_header := null;
     
        l_header := ' error_explanation ,error_code,transaction_interface_id,source_code,source_line_id,source_header_id,process_flag,transaction_mode,item_segment1,organization_id,transaction_quantity,primary_quantity,transaction_uom,transaction_date,subinventory_code,transaction_type_id,transaction_reference,vendor_lot_number,transfer_subinventory,transfer_organization,shipment_number,lot_number,batch_complete,batch_size,batch_completion_date,producing_org,dsp_segment1,dsp_segment2,dsp_segment3,dsp_segment4,dsp_segment5,dsp_segment6,dsp_segment7,dsp_segment8,dst_segment1,dst_segment2,dst_segment3,dst_segment4,dst_segment5,dst_segment6,dst_segment7,dst_segment8,legacy_reason_code,legacy_txn_type_code,legacy_warehouse_snd,legacy_warehouse_rcv,legacy_pallet_num ';

    v_step := 2;
    
     FND_FILE.PUT_LINE(FND_FILE.OUTPUT,l_header);       

        OPEN c_gen_error(p_request_id); 
        
        FETCH c_gen_error BULK COLLECT INTO l_detailed_error_tab;
        
        FOR i in 1..l_detailed_error_tab.COUNT
        
            LOOP
            
                FND_FILE.PUT_LINE(FND_FILE.OUTPUT, l_detailed_error_tab(i).INVENTORY_INTERFACE_TBL );
                
            END LOOP;
            
        CLOSE c_gen_error;
        
    v_step := 3;
    
    EXCEPTION
        WHEN OTHERS THEN
          v_mess := 'At step ['||v_step||'] - SQLCODE [' ||SQLCODE|| '] - ' ||substr(SQLERRM,1,100);
          x_errbuf  := v_mess;
          x_retcode := 2; 

   END main_proc;
        
END XXNBTY_INVINT01_INT_ERR_PKG;

/

show errors;
