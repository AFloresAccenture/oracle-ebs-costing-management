create or replace PACKAGE BODY   XXNBTY_OPMEXT01_OPEN_PERIOD_PK
IS
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
02-Nov-2016                 Khristine Austero       Update logic validation of Period_Name (Oct start of fiscal year)
                                                    instead of P_PERIOD_NAME will use START_DATE as validation column
*/
----------------------------------------------------------------------------------------------------  
PROCEDURE open_period(o_errbuf      OUT VARCHAR2, 
                      o_retcode     OUT NUMBER,
                      p_period_name  IN VARCHAR2)

IS
----------------------------------------------------------------------------------------------------
/*
Package Name: XXNBTY_OPMEXT01_OPEN_PERIOD_PK
Author's Name: Albert John Flores
Date written: 30-July-2016
RICEFW Object: EXT01
Description: Procedure to open inventory periods
Program Style: 

Maintenance History: 

Date            Issue#      Name                    Remarks 
-----------     ------      -----------             ------------------------------------------------
30-July-2016                Albert Flores           Initial Development

*/
----------------------------------------------------------------------------------------------------  
    CURSOR c_opm_orgs
    IS
      SELECT organization_id
            ,organization_code
      FROM   mtl_parameters
      WHERE 1 = 1
      AND process_enabled_flag      = g_proc_enabled_flag_y  --'Y'
      ORDER BY organization_code;
      --AND ood.organization_id          = 203;

/*
    SELECT organization_id, organization_code 
    FROM mtl_parameters 
    WHERE organization_code IN ('011','064','042','001','056',
                              '007','085','045','046','047','048',
                              '049','053','057','061','062','076',
                              '078','079','080','082','083','084',
                              '091','099','002','003','006','014',
                              '022','044','038');
*/
    is_found_rec BOOLEAN := FALSE; 
    
    CURSOR c_acct_period_list( p_period_set_name IN VARCHAR2
                              ,p_acctperiodtype  IN VARCHAR2
                              ,p_period_name     IN VARCHAR2
                              --,p_close_date          IN DATE
                              ,p_org_id          IN VARCHAR2)
    IS
    SELECT glp.period_set_name period_set_name
          ,glp.period_name period_name
          ,glp.start_date start_date
          ,glp.end_date end_date
          ,glp.period_type accounted_period_type
          ,glp.period_year period_year
          ,glp.period_num period_number
          ,apv.status period_status
          ,apv.organization_id organization_id
    FROM gl_periods glp
        ,org_acct_periods_v apv
    WHERE glp.adjustment_period_flag        = g_adj_period_flag_n  --'N' 
    AND   glp.period_set_name               = p_period_set_name
    AND   glp.period_type                   = p_acctperiodtype
    AND   apv.period_name                   = glp.period_name
    AND   apv.period_name                   = p_period_name
    --AND   glp.end_date                      >= p_close_date
    AND   apv.organization_id               = p_org_id;

    CURSOR c_acct_period_list_f( p_period_set_name IN VARCHAR2
                              ,p_acctperiodtype  IN VARCHAR2
                              ,p_period_name     IN VARCHAR2
                              --,p_close_date          IN DATE
                              ,p_org_id          IN VARCHAR2)
    IS
    SELECT glp.period_set_name period_set_name
          ,glp.period_name period_name
          ,glp.start_date start_date
          ,glp.end_date end_date
          ,glp.period_type accounted_period_type
          ,glp.period_year period_year
          ,glp.period_num period_number
          ,apv.status period_status
          ,apv.organization_id organization_id
    FROM gl_periods glp
        ,apps.org_acct_periods_v apv
    WHERE glp.adjustment_period_flag        = g_adj_period_flag_n  --'N' 
    AND   glp.period_set_name               = p_period_set_name
    AND   glp.period_type                   = p_acctperiodtype
    AND   apv.period_name                   = glp.period_name
    AND   apv.period_name                   = p_period_name
    --AND   glp.end_date                      >= p_close_date
    AND   UPPER(apv.status)                 = 'FUTURE';
    
    num_total_rows                NUMBER;
    l_organization_id             NUMBER;
    l_period_set_name             VARCHAR2(50);
    l_accounted_period_type       VARCHAR2(50);
    l_last_scheduled_close_date   DATE;
    l_prior_period_open           BOOLEAN;   
    l_new_acct_period_id          NUMBER;     
    l_duplicate_open_period       BOOLEAN;
    l_commit_complete             BOOLEAN:=TRUE;  
    l_return_status               VARCHAR2(1);
    l_last_period_end_date        DATE;
    l_set_of_books_id             NUMBER;
    l_app_id                      NUMBER;
    l_organization_code           VARCHAR2(50);
    v_step                        NUMBER;
    v_mess                        VARCHAR2(1000);   
    
BEGIN

v_step := 1;

 --get the application_id for INVENTORY
 SELECT application_id 
 INTO l_app_id
 FROM fnd_application_vl
 WHERE application_name = 'Inventory'; 

 FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'Org Code                Period Name             Period Status(Before)               Processed(Y/N)              Period Status(After)');  

v_step := 2;
 
 FOR opm_rec IN c_opm_orgs
 
    LOOP

v_step := 3;
    --FND_FILE.PUT_LINE(FND_FILE.LOG, 'Org '||opm_rec.organization_code);

        --derive period set name and period type to be used for the API
        BEGIN
            
            SELECT glsob.period_set_name
                  ,glsob.accounted_period_type
            INTO l_period_set_name
                ,l_accounted_period_type
            FROM cst_organization_definitions cod
                ,gl_sets_of_books             glsob
            WHERE glsob.set_of_books_id     = cod.set_of_books_id
            AND cod.organization_id         = opm_rec.organization_id;

        EXCEPTION
        WHEN NO_DATA_FOUND THEN 
          o_retcode := 2;
          v_mess := 'At step ['||v_step||'] for procedure open_period - SQLCODE [' ||SQLCODE|| '] - ' ||substr(SQLERRM,1,100);
          o_errbuf := v_mess;
        
        END;
    --FND_FILE.PUT_LINE(FND_FILE.LOG, 'Derive period settings '||l_period_set_name || ' ' || l_accounted_period_type);

v_step := 3.1;
    --FND_FILE.PUT_LINE(FND_FILE.LOG, 'Org '||opm_rec.organization_code);

        --derive schedule_close_date to be used for the API
        BEGIN

                SELECT Max(schedule_close_date)
                INTO l_last_scheduled_close_date
                FROM org_acct_periods
                WHERE organization_id         = opm_rec.organization_id;

        EXCEPTION
        WHEN NO_DATA_FOUND THEN 
          o_retcode := 2;
          v_mess := 'At step ['||v_step||'] for procedure open_period - SQLCODE [' ||SQLCODE|| '] - ' ||SUBSTR(SQLERRM,1,100);
          o_errbuf := v_mess;
        END;
    --FND_FILE.PUT_LINE(FND_FILE.LOG, 'Derive period settings '||l_last_scheduled_close_date);

v_step := 4;

 --derive account period details
        BEGIN 

        
        FOR rec_period IN c_acct_period_list(l_period_set_name,l_accounted_period_type,p_period_name,opm_rec.organization_id) --,l_last_scheduled_close_date 
        LOOP
v_step := 5;
            is_found_rec := TRUE;
v_step := 8;
                
            IF rec_period.period_status = g_status_o THEN
                SELECT organization_code
                INTO   l_organization_code
                FROM   mtl_parameters
                WHERE 1 = 1
                AND process_enabled_flag      = g_proc_enabled_flag_y  --'Y'
                AND organization_id          = rec_period.organization_id;

                FND_FILE.PUT_LINE(FND_FILE.OUTPUT,LPAD(l_organization_code, 3, ' ')||LPAD(p_period_name, 30, ' ')|| LPAD(rec_period.period_status, 22, ' ')||LPAD(g_process_n, 33, ' ')||LPAD(rec_period.period_status,31 ,' '));  
                    --FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'     '|| l_organization_code||'                      '||p_period_name||'                 '||rec_period.period_status||'                      N                           '||rec_period.period_status);  
            
            ELSIF rec_period.period_status =  g_status_c  THEN
               SELECT organization_code
                INTO   l_organization_code
                FROM   mtl_parameters
                WHERE 1 = 1
                AND process_enabled_flag      = g_proc_enabled_flag_y  --'Y'
                AND organization_id          = opm_rec.organization_id;

                FND_FILE.PUT_LINE(FND_FILE.OUTPUT,LPAD(l_organization_code, 3, ' ')||LPAD(p_period_name, 30, ' ')|| LPAD(g_status_c, 22, ' ')||LPAD(g_process_n, 33, ' ')||LPAD(g_status_c,31 ,' '));  
                    --FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'     '|| l_organization_code||'                      '||p_period_name||'                 '||rec_period.period_status||'                      N                           '||rec_period.period_status);  
            
            END IF;
v_step := 9;

        END LOOP;

         IF NOT is_found_rec THEN
         FOR rec_period_f IN c_acct_period_list_f(  l_period_set_name
                                                    ,l_accounted_period_type
                                                    ,p_period_name
                                                    ,opm_rec.organization_id)
         LOOP
         
            
            FND_FILE.PUT_LINE(FND_FILE.LOG, 'Derive account period details');
            FND_FILE.PUT_LINE(FND_FILE.LOG, 'ACCOUNTED_PERIOD_TYPE : '||rec_period_f.ACCOUNTED_PERIOD_TYPE);
            FND_FILE.PUT_LINE(FND_FILE.LOG, 'PERIOD_SET_NAME : '||rec_period_f.PERIOD_SET_NAME);
            FND_FILE.PUT_LINE(FND_FILE.LOG, 'PERIOD_NAME : '||rec_period_f.PERIOD_NAME);
            FND_FILE.PUT_LINE(FND_FILE.LOG, 'PERIOD_YEAR : '||rec_period_f.PERIOD_YEAR);
            FND_FILE.PUT_LINE(FND_FILE.LOG, 'PERIOD_NUMBER : '||rec_period_f.PERIOD_NUMBER);
            FND_FILE.PUT_LINE(FND_FILE.LOG, 'Organization_id : '||opm_rec.organization_id);
            FND_FILE.PUT_LINE(FND_FILE.LOG, 'Status : '||rec_period_f.period_status);
            FND_FILE.PUT_LINE(FND_FILE.LOG, 'l_last_scheduled_close_date : '||l_last_scheduled_close_date);

            --IF (TO_DATE(l_last_scheduled_close_date,'DD-MON-YY') + 1) >= (TO_DATE('01-'||p_period_name, 'DD-MON-YY')) THEN
            IF (TO_DATE(l_last_scheduled_close_date,'DD-MON-YY') + 1) >= rec_period_f.start_date THEN /*02-Nov-2016*/
            --IF rec_period_f.period_status = g_status_f THEN
            --IF UPPER(rec_period_f.period_status) = 'FUTURE' THEN
                CST_AccountingPeriod_PUB.open_period
                    (  p_api_version                => 1.0
                    ,  p_org_id                     => opm_rec.organization_id  
                    ,  p_user_id                    => -1  
                    ,  p_login_id                   => -1  
                    ,  p_acct_period_type           => rec_period_f.accounted_period_type
                    ,  p_org_period_set_name        => rec_period_f.period_set_name 
                    ,  p_open_period_name           => rec_period_f.period_name
                    ,  p_open_period_year           => rec_period_f.period_year
                    ,  p_open_period_num            => rec_period_f.period_number
                    ,  x_last_scheduled_close_date  => l_last_scheduled_close_date
                    ,  p_period_end_date            => rec_period_f.end_date                   
                    ,  x_prior_period_open          => l_prior_period_open           
                    ,  x_new_acct_period_id         => l_new_acct_period_id          
                    ,  x_duplicate_open_period      => l_duplicate_open_period     
                    ,  x_commit_complete            => l_commit_complete  
                    ,  x_return_status              => l_return_status            
                    ) ;

            FND_FILE.PUT_LINE(FND_FILE.LOG, 'rec_period.period_status = Future');
            FND_FILE.PUT_LINE(FND_FILE.LOG, 'ACCOUNTED_PERIOD_TYPE : '||rec_period_f.ACCOUNTED_PERIOD_TYPE);
            FND_FILE.PUT_LINE(FND_FILE.LOG, 'PERIOD_SET_NAME : '||rec_period_f.PERIOD_SET_NAME);
            FND_FILE.PUT_LINE(FND_FILE.LOG, 'PERIOD_NAME : '||rec_period_f.PERIOD_NAME);
            FND_FILE.PUT_LINE(FND_FILE.LOG, 'PERIOD_YEAR : '||rec_period_f.PERIOD_YEAR);
            FND_FILE.PUT_LINE(FND_FILE.LOG, 'PERIOD_NUMBER : '||rec_period_f.PERIOD_NUMBER);
            FND_FILE.PUT_LINE(FND_FILE.LOG, 'organization_id : '||opm_rec.organization_id);
            FND_FILE.PUT_LINE(FND_FILE.LOG, 'Status : '||rec_period_f.period_status);
            FND_FILE.PUT_LINE(FND_FILE.LOG, 'l_last_scheduled_close_date : '||l_last_scheduled_close_date);


v_step := 6;
                
                IF l_return_status <> FND_API.g_ret_sts_success THEN
                
                      o_retcode := 2;
                      v_mess := 'At step ['||v_step||'] for procedure open_period - SQLCODE [' ||SQLCODE|| '] - ' ||SUBSTR(SQLERRM,1,100);
                      o_errbuf := v_mess;
                      
                ELSE
    
v_step := 7;
                    FND_FILE.PUT_LINE(FND_FILE.LOG, 'Status' || l_return_status);
                    FND_FILE.PUT_LINE(FND_FILE.LOG, 'Period '||p_period_name||' for Org '||opm_rec.organization_code||' has been opened successfully!' );
                    FND_FILE.PUT_LINE(FND_FILE.OUTPUT,LPAD(opm_rec.organization_code,3,' ')||LPAD(p_period_name, 30, ' ')|| LPAD(rec_period_f.period_status, 22, ' ')||LPAD(g_process_y, 33, ' ')||LPAD(g_status_o,31 ,' '));  
                  --FND_FILE.PUT_LINE(FND_FILE.OUTPUT,LPAD(l_organization_code, 3, ' ')||LPAD(p_period_name, 30, ' ')|| LPAD(g_status_c, 22, ' ')||LPAD(g_process_n, 33, ' ')||LPAD(g_status_c,31 ,' '));  
                END IF;
                COMMIT;
            ELSE
--/*
               SELECT organization_code
                INTO   l_organization_code
                FROM   mtl_parameters
                WHERE 1 = 1
                AND process_enabled_flag      = g_proc_enabled_flag_y  --'Y'
                AND organization_id           = opm_rec.organization_id;

                FND_FILE.PUT_LINE(FND_FILE.OUTPUT,LPAD(l_organization_code, 3, ' ')||LPAD(p_period_name, 30, ' ')|| LPAD(g_status_f, 22, ' ')||LPAD(g_process_n, 33, ' ')||LPAD(g_status_f,31 ,' '));  
--*/
            END IF;
        END LOOP;
        END IF;
         
         is_found_rec := FALSE;
         
        END;

    END LOOP;

    
v_step := 10;   
    
EXCEPTION  
  WHEN OTHERS THEN
  o_retcode := 2;
  v_mess := 'At step ['||v_step||'] for procedure open_period - SQLCODE [' ||SQLCODE|| '] - ' ||substr(SQLERRM,1,100);
  o_errbuf := v_mess;

END open_period;

END XXNBTY_OPMEXT01_OPEN_PERIOD_PK;

/

show errors;
