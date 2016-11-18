create or replace PACKAGE BODY        "XXNBTY_INV_REP04_ABS_PKG" 
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
  --subprocedure that will generate error output file. 
  PROCEDURE generate_report (x_retcode  	OUT VARCHAR2, 
                             x_errbuf   	OUT VARCHAR2
							 ,p_date_from	DATE
							 ,p_date_to		DATE
							 ,p_org			VARCHAR2
							 ,p_item_num	VARCHAR2
							 ,p_recipients	VARCHAR2)
							 
  IS					
							  
	l_old_filename			   VARCHAR2(1000);
	l_new_filename			   VARCHAR2(200);
	l_subject				   VARCHAR2(100);
	l_message				   VARCHAR2(240);
	l_recipient				   VARCHAR2(1000);
	l_cc					   VARCHAR2(240);
	l_bcc					   VARCHAR2(240);
	l_submit_rep_id			   NUMBER;
	l_submit_email_id		   NUMBER;
	v_step          		   NUMBER;
	v_mess          		   VARCHAR2(500);
	l_instance				   VARCHAR2(30);
	l_layout				   BOOLEAN;
	l_wait             BOOLEAN;
	l_phase            VARCHAR2(100)   := NULL;
	l_status           VARCHAR2(30)    := NULL;
	l_devphase         VARCHAR2(100)   := NULL;
	l_devstatus        VARCHAR2(100)   := NULL;
	l_mesg             VARCHAR2(50)    := NULL;
	
   BEGIN
	v_step := 1;
		l_recipient := p_recipients;
		--Call the concurrent program to generate the report
		
		l_layout := FND_REQUEST.ADD_LAYOUT('XXNBTY',
											   'XXNBTY_INV_LOH_YLD_RPT',
											   'en',
											   00,
											   'EXCEL');		
		
		l_submit_rep_id := FND_REQUEST.SUBMIT_REQUEST(application  => 'XXNBTY'
											   ,program      => 'XXNBTY_INV_LOH_YLD_RPT'
											   ,start_time   => NULL
											   ,sub_request  => FALSE
											   ,argument1    => 'US_LE'
											   ,argument2    => p_date_from
											   ,argument3    => p_date_to
											   ,argument4    => p_org
											   ,argument5    => p_item_num);
											   
		COMMIT;
	v_step := 2;	
		
		IF l_submit_rep_id >0 THEN
		LOOP
			l_wait := fnd_concurrent.wait_for_request( request_id       => l_submit_rep_id
													  , interval        => 10
													  , max_wait        => ''
													  , phase           => l_phase
													  , status          => l_status
													  , dev_phase       => l_devphase
													  , dev_status      => l_devstatus
													  , message         => l_mesg
													  );
			EXIT WHEN ((UPPER(l_devstatus) = 'NORMAL' AND UPPER(l_devphase) = 'COMPLETE')
                      OR (UPPER(l_devstatus) IN ('WARNING', 'ERROR') ));	
		END LOOP;
		
		COMMIT;
		
		END IF;
		
	v_step := 3;
	
		--check for the report completion
		IF (l_devphase = 'COMPLETE' AND l_devstatus = 'NORMAL') THEN
		
		  FND_FILE.PUT_LINE(FND_FILE.LOG,'XXNBTY Labor, Overhead and Yield Loss Absorption Report has completed successfully');
		  FND_FILE.PUT_LINE(FND_FILE.LOG,'Request ID of XXNBTY Labor, Overhead and Yield Loss Absorption Report is ' || l_submit_rep_id);
		  FND_FILE.PUT_LINE(FND_FILE.LOG,'Calling the EBS Send Email Program to send the output file of the report');
				
				v_step := 4;
			BEGIN	
				--get the output of the report using its request id
				SELECT 	fcr.file_name
				INTO 	l_old_filename
				FROM 	fnd_conc_req_outputs fcr
				WHERE 	fcr.concurrent_request_id = l_submit_rep_id;
				FND_FILE.PUT_LINE(FND_FILE.LOG,'old file name ' || l_old_filename);
				v_step := 5;
			EXCEPTION
			WHEN NO_DATA_FOUND THEN
			FND_FILE.PUT_LINE(FND_FILE.LOG,'NO DATA FOUND FOR REPORT');
			
			END;	
				--EMAIL CONTENTS
				SELECT DECODE(NAME,'NBTYPP01','Production Instance ' , 'Non Production Instance') INTO l_instance FROM v$database;
				
				v_step := 6;
				
				--File Name to be used
				l_new_filename := 'XXNBTY_LABOR_OVERHEAD_YIELDLOSS_' || TO_CHAR(SYSDATE, 'YYYYMMDD') || '.xls';
				
				v_step := 7;
				
				--Email Message
				l_message	   := 'Hi,\n\nAttached is the XXNBTY Labor, Overhead and Yield Loss Absorption Report\n\n*****This is an auto-generated e-mail. Please do not reply.*****';
				
				v_step := 8;
				
				--Email Subject
				l_subject	   := 'Costing Management Reports';
				
				v_step := 9;
				
				--Receipients
				l_cc		   := '';
				l_bcc		   := '';
				
				v_step := 10;
				FND_FILE.PUT_LINE(FND_FILE.LOG,'Calling the EBS Send Email Program right now');
				--Call the concurrent program to send email notification
				l_submit_email_id := FND_REQUEST.SUBMIT_REQUEST(application  => 'XXNBTY'
													   ,program      => 'XXNBTY_EBS_SEND_EMAIL_LOG'
													   ,start_time   => NULL
													   ,sub_request  => FALSE
													   ,argument1    => l_new_filename
													   ,argument2    => l_old_filename
													   ,argument3    => l_recipient
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
		
		  FND_FILE.PUT_LINE(FND_FILE.LOG,'Error has been encountered when running the XXNBTY Labor, Overhead and Yield Loss Absorption Report.' );
		
		END IF;
		
	v_step := 12;										   
		
	EXCEPTION
		WHEN OTHERS THEN
		  x_retcode := 2;
		  v_mess := 'At step ['||v_step||'] - SQLCODE [' ||SQLCODE|| '] - ' ||substr(SQLERRM,1,100);
		  x_errbuf  := v_mess;
 
  END generate_report;

END XXNBTY_INV_REP04_ABS_PKG;

/

show errors;
