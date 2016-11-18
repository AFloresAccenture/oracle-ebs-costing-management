create or replace PACKAGE BODY XXNBTY_CONV01_ICOST_CONV_PKG AS
----------------------------------------------------------------------------------------------
/*
Package Name: XXNBTY_CONV01_ICOST_CONV
Author's Name: John Paul Aquino
Date written: 25-FEB-2016
RICEFW Object: CONV-01
Description: This package will validate records from the flat file and will create records in the
             OPM financials and Cost Management using Import program and API
Program Style:

Maintenance History:

Date            Issue#      Name                    Remarks
-----------     ------      -----------             ------------------------------------------------
25-FEB-2016                 John Paul Aquino        Initial Development
30-MAR-2016                 Khristine Austero       Add filtering in the validate_cm_rec and validate_opm_rec procedures [it should also be filtered by org code]
04-May-2016                 Khristine Austero       Add Procedure process_cm_to_opm_by_element,
                                                    cm_to_opm_by_element_main
*/
--------------------------------------------------------------------------------------------

PROCEDURE printlog_pr ( pi_message  IN  VARCHAR2
                      )
    IS
----------------------------------------------------------------------------------------------
/*
Procedure Name: printlog_pr
Author's Name: John Paul Aquino
Date written: 25-FEB-2016
RICEFW Object: CONV-01
Description:
Program Style:

Maintenance History:

Date            Issue#      Name                    Remarks
-----------     ------      -----------             ------------------------------------------------
25-FEB-2016                 John Paul Aquino        Initial Development
*/
--------------------------------------------------------------------------------------------
    BEGIN
        FND_FILE.PUT_LINE(FND_FILE.LOG, pi_message);

    EXCEPTION
       WHEN OTHERS THEN
          g_error   := SQLERRM;
          g_retcode := 2;
          FND_FILE.PUT_LINE(FND_FILE.LOG, 'Error in PRINTLOG_PR - ' || g_error);

    END printlog_pr;


PROCEDURE printoutput_pr( pi_message    IN  VARCHAR2
                        )
    IS
----------------------------------------------------------------------------------------------
/*
Procedure Name: printoutput_pr
Author's Name: John Paul Aquino
Date written: 25-FEB-2016
RICEFW Object: CONV-01
Description:
Program Style:

Maintenance History:

Date            Issue#      Name                    Remarks
-----------     ------      -----------             ------------------------------------------------
25-FEB-2016                 John Paul Aquino        Initial Development
*/
--------------------------------------------------------------------------------------------
    BEGIN
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT, pi_message);

    EXCEPTION
       WHEN OTHERS THEN
          g_error   := SQLERRM;
          g_retcode := 2;
          PRINTLOG_PR('Error in PRINTOUTPUT_PR - ' || g_error);
    END printoutput_pr;


PROCEDURE validate_opm_rec  ( x_errbuf      OUT VARCHAR2,
                            x_retcode       OUT VARCHAR2)
IS
----------------------------------------------------------------------------------------------
/*
Procedure Name: validate_opm_rec
Author's Name: John Paul Aquino
Date written: 25-FEB-2016
RICEFW Object: CONV-01
Description:
Program Style:

Maintenance History:

Date            Issue#      Name                    Remarks
-----------     ------      -----------             ------------------------------------------------
25-FEB-2016                 John Paul Aquino        Initial Development
*/
--------------------------------------------------------------------------------------------

    l_dup                      CONSTANT VARCHAR2(99)       := 'Duplicate Record';
    l_error_desc               VARCHAR2(2500)              := NULL;
    l_rec_stat                 VARCHAR2(10)                := NULL;
    l_rec_cnt                  NUMBER                      := 0;
    l_item_num                 VARCHAR2(30)                := NULL;
    l_mess                      VARCHAR2(500);
    l_location                  VARCHAR2(100)               := 'VALIDATE OPM RECORDS';


    CURSOR c_chk_new_pm
    IS
        SELECT *
        FROM xxnbty.xxnbty_opm_iccon_stg
        WHERE record_status = g_rec_stat_n
        AND error_description IS NULL;
/*
    CURSOR c_chk_dup_stg IS
    SELECT item_number
    FROM   xxnbty.xxnbty_opm_iccon_stg xois
    WHERE  record_status = g_rec_stat_n
    AND (EXISTS
            (SELECT   item_number
                FROM   xxnbty.xxnbty_opm_iccon_stg xois1
                WHERE   1 = 1
                AND xois1.item_number = xois.item_number
                AND xois1.record_status = g_rec_stat_n
                GROUP BY  item_number
                HAVING   COUNT (1) > 1
            )
        );
*/
    BEGIN
        FOR r_chk_new_pm IN c_chk_new_pm
        LOOP
            l_error_desc  := NULL;
            l_rec_stat    := NULL;
            BEGIN
                SELECT segment1  --check the items-org combination exists in EBS
                INTO l_item_num
                FROM org_organization_definitions ood
                    ,hr_all_organization_units haou
                    ,mtl_system_items msi
                WHERE ood.operating_unit = haou.organization_id
                AND ood.organization_id = msi.organization_id
                AND ood.organization_code = r_chk_new_pm.organization_code
                AND msi.segment1 = r_chk_new_pm.item_number;

                IF l_item_num IS NOT NULL
                    THEN

                    BEGIN
                        SELECT COUNT(*)  --to check that process items are Process Costing Enabled
                        INTO l_rec_cnt
                        FROM org_organization_definitions ood
                            ,hr_all_organization_units haou
                            ,mtl_system_items msi
                        WHERE ood.operating_unit = haou.organization_id
                        AND ood.organization_id = msi.organization_id
                        AND ood.organization_code = r_chk_new_pm.organization_code
                        AND msi.segment1 = r_chk_new_pm.item_number
                        AND msi.process_costing_enabled_flag = 'Y';

                            IF l_rec_cnt = 0
                            THEN
                                l_error_desc := 'The item-org combination is not process costing enabled';
                                l_rec_stat := g_rec_stat_e;
                            END IF;

                            UPDATE xxnbty.xxnbty_opm_iccon_stg
                            SET error_description = l_error_desc
                                ,record_status = l_rec_stat
                            WHERE /*r_chk_new_pm.organization_id = organization_id
                            AND  */ r_chk_new_pm.item_number = item_number
                            AND r_chk_new_pm.organization_code = organization_code; /*DEFECT # 3/30/2016*/
                        COMMIT;
                    END;

                    BEGIN
                        SELECT COUNT(*)  --to check that process Items are Recipe Enabled
                        INTO l_rec_cnt
                        FROM org_organization_definitions ood
                            ,hr_all_organization_units haou
                            ,mtl_system_items msi
                        WHERE ood.operating_unit = haou.organization_id
                        AND ood.organization_id = msi.organization_id
                        AND ood.organization_code = r_chk_new_pm.organization_code
                        AND msi.segment1 = r_chk_new_pm.item_number
                        AND msi.recipe_enabled_flag = 'Y';

                            IF l_rec_cnt = 0
                            THEN
                                l_error_desc := l_error_desc || 'The item-org combination is not Recipe Enabled';
                                l_rec_stat := g_rec_stat_e;
                            END IF;

                            UPDATE xxnbty.xxnbty_opm_iccon_stg
                            SET error_description = l_error_desc
                                ,record_status = l_rec_stat
                            WHERE /*r_chk_new_pm.organization_id = organization_id
                            AND */   r_chk_new_pm.item_number = item_number
                            AND r_chk_new_pm.organization_code = organization_code;/*DEFECT # 3/30/2016*/
                        COMMIT;
                    END;
                END IF;
            EXCEPTION
            WHEN NO_DATA_FOUND THEN
                    l_error_desc := 'The item-org combination does not exist in Oracle table';
                    l_rec_stat := g_rec_stat_e;

            UPDATE xxnbty.xxnbty_opm_iccon_stg
            SET error_description = l_error_desc
                ,record_status = l_rec_stat
            WHERE /*r_chk_new_pm.organization_id = organization_id
            AND */  r_chk_new_pm.item_number = item_number
            AND r_chk_new_pm.organization_code = organization_code;/*DEFECT # 3/30/2016*/
            COMMIT;

            END;
        END LOOP;
 /*
 * ======================================================================
 *                           UPDATE STAGING RECORD STATUS
 * ======================================================================*/
            BEGIN
                UPDATE xxnbty.xxnbty_opm_iccon_stg
                SET record_status = g_rec_stat_v
                WHERE  record_status IS NULL;
                COMMIT;
            END;

        EXCEPTION
        WHEN OTHERS THEN
          l_mess := 'Error on ['||l_location||'] - SQLCODE [' ||SQLCODE|| '] - ' ||substr(SQLERRM,1,100);
          x_errbuf  := l_mess;
          x_retcode := 2;

    END validate_opm_rec;


PROCEDURE validate_cm_rec ( x_errbuf        OUT VARCHAR2,
                            x_retcode       OUT VARCHAR2,
                            p_request_id    IN VARCHAR2)
IS
----------------------------------------------------------------------------------------------
/*
Procedure Name: validate_cm_rec
Author's Name: John Paul Aquino
Date written: 25-FEB-2016
RICEFW Object: CONV-01
Description:
Program Style:

Maintenance History:

Date            Issue#      Name                    Remarks
-----------     ------      -----------             ------------------------------------------------
25-FEB-2016                 John Paul Aquino        Initial Development
*/
--------------------------------------------------------------------------------------------

    l_dup                      CONSTANT VARCHAR2(99)   := 'Duplicate Record';
    l_error_desc               VARCHAR2(2500)          := NULL;
    l_rec_stat                 VARCHAR2(10)            := NULL;
    l_rec_cnt                  NUMBER                  := 0;
    l_item_num                 VARCHAR2(30)            := NULL;
    l_mess                     VARCHAR2(500);
    l_location                 VARCHAR2(100)           := 'VALIDATE CM RECORDS';


    CURSOR c_chk_new_pm
    IS
        SELECT *
        FROM xxnbty.xxnbty_cm_iccon_stg
        WHERE record_status = g_rec_stat_n
        AND error_description IS NULL;

    CURSOR cur_chk_dup_stg IS
    SELECT item_number
    FROM   xxnbty.xxnbty_cm_iccon_stg xois
    WHERE  record_status = g_rec_stat_n
    AND (EXISTS
            (SELECT   item_number
                FROM   xxnbty.xxnbty_cm_iccon_stg xois1
                WHERE   1 = 1
                AND xois1.item_number = xois.item_number
                AND xois1.record_status = g_rec_stat_n
                GROUP BY  item_number
                HAVING   COUNT (1) > 1
            )
        );

    BEGIN
        FOR r_chk_new_pm IN c_chk_new_pm
        LOOP
        l_error_desc  := NULL;
        l_rec_stat    := NULL;
            BEGIN
                SELECT segment1  --check the items-org combination exists in EBS
                INTO l_item_num
                FROM org_organization_definitions ood
                    ,hr_all_organization_units haou
                    ,mtl_system_items msi
                WHERE ood.operating_unit = haou.organization_id
                AND ood.organization_id = msi.organization_id
                AND ood.organization_code = r_chk_new_pm.organization_code
                AND msi.segment1 = r_chk_new_pm.item_number;

                IF l_item_num IS NOT NULL
                    THEN
                    BEGIN
                        SELECT COUNT(*)  --to check the item-org combination must be Costing Enabled
                        INTO l_rec_cnt
                        FROM org_organization_definitions ood
                            ,hr_all_organization_units haou
                            ,mtl_system_items msi
                        WHERE ood.operating_unit = haou.organization_id
                        AND ood.organization_id = msi.organization_id
                        AND ood.organization_code = r_chk_new_pm.organization_code
                        AND msi.segment1 = r_chk_new_pm.item_number
                        AND msi.costing_enabled_flag = 'Y';

                            IF l_rec_cnt = 0
                            THEN
                                l_error_desc := 'The item-org combination is not cost enabled';
                                l_rec_stat := g_rec_stat_e;
                            END IF;

                            UPDATE xxnbty.xxnbty_cm_iccon_stg
                            SET error_description = l_error_desc
                                ,record_status = l_rec_stat
                            WHERE /*r_chk_new_pm.organization_id = organization_id
                            AND  */ r_chk_new_pm.item_number = item_number
                            AND r_chk_new_pm.organization_code = organization_code /*DEFECT # 3/30/2016*/
                            AND REQUEST_ID = p_request_id;
                        COMMIT;
                    END;

                    BEGIN
                        SELECT COUNT(*)  --to check that discrete items Included in rollup
                        INTO l_rec_cnt
                        FROM org_organization_definitions ood
                            ,hr_all_organization_units haou
                            ,mtl_system_items msi
                        WHERE ood.operating_unit = haou.organization_id
                        AND ood.organization_id = msi.organization_id
                        AND ood.organization_code = r_chk_new_pm.organization_code
                        AND msi.segment1 = r_chk_new_pm.item_number
                        AND msi.default_include_in_rollup_flag = 'Y';

                            IF l_rec_cnt = 0
                            THEN
                                l_error_desc := l_error_desc || 'The item-org combination is not included in rollup';
                                l_rec_stat := g_rec_stat_e;
                            END IF;

                            UPDATE xxnbty.xxnbty_cm_iccon_stg
                            SET error_description = l_error_desc
                                ,record_status = l_rec_stat
                            WHERE /*r_chk_new_pm.organization_id = organization_id
                            AND */   r_chk_new_pm.item_number = item_number
                            AND r_chk_new_pm.organization_code = organization_code /*DEFECT # 3/30/2016*/
                            AND REQUEST_ID = p_request_id;
                        COMMIT;
                    END;

                    BEGIN
                        SELECT COUNT(*)  --to check that discrete items are included in Inventory Asset Value
                        INTO l_rec_cnt
                        FROM org_organization_definitions ood
                            ,hr_all_organization_units haou
                            ,mtl_system_items msi
                        WHERE ood.operating_unit = haou.organization_id
                        AND ood.organization_id = msi.organization_id
                        AND ood.organization_code = r_chk_new_pm.organization_code
                        AND msi.segment1 = r_chk_new_pm.item_number
                        AND msi.inventory_asset_flag = 'Y';

                            IF l_rec_cnt = 0
                            THEN
                                l_error_desc := l_error_desc || 'The item-org combination is not included in Inventory Asset Value ';
                                l_rec_stat := g_rec_stat_e;
                            END IF;

                            UPDATE xxnbty.xxnbty_cm_iccon_stg
                            SET error_description = l_error_desc
                                ,record_status = l_rec_stat
                            WHERE /*r_chk_new_pm.organization_id = organization_id
                            AND */   r_chk_new_pm.item_number = item_number
                            AND r_chk_new_pm.organization_code = organization_code /*DEFECT # 3/30/2016*/
                            AND request_id = p_request_id;
                        COMMIT;
                    END;
                END IF;
            EXCEPTION
            WHEN NO_DATA_FOUND THEN
                       l_error_desc := 'The item-org combination does not exist in Oracle table';
                       l_rec_stat := g_rec_stat_e;

                        UPDATE xxnbty.xxnbty_cm_iccon_stg
                        SET error_description = l_error_desc
                            ,record_status = l_rec_stat
                        WHERE /*r_chk_new_pm.organization_id = organization_id
                        AND */  r_chk_new_pm.item_number = item_number
                        AND r_chk_new_pm.organization_code = organization_code /*DEFECT # 3/30/2016*/
                        AND request_id = p_request_id;
                COMMIT;

            END;
        END LOOP;

            BEGIN
                UPDATE xxnbty.xxnbty_cm_iccon_stg
                SET record_status = g_rec_stat_v
                WHERE  record_status IS NULL
                AND request_id = p_request_id;
                COMMIT;
            END;
        EXCEPTION
        WHEN OTHERS THEN
          l_mess := 'Error on ['||l_location||'] - SQLCODE [' ||SQLCODE|| '] - ' ||substr(SQLERRM,1,100);
          x_errbuf  := l_mess;
          x_retcode := 2;
    END validate_cm_rec;

PROCEDURE process_cm_to_opm_by_element ( x_errbuf      OUT VARCHAR2,
                                         x_retcode     OUT VARCHAR2,
                                         p_org          IN VARCHAR2,
                                         p_item         IN VARCHAR2,
                                         p_request_id   IN VARCHAR2
                                        )
IS
----------------------------------------------------------------------------------------------
/*
Procedure Name: process_cm_to_opm_by_element
Author's Name: Khristine Austero
Date written: 2-MAY-2016
RICEFW Object: CONV-01
Description:
Program Style:

Maintenance History:

Date            Issue#      Name                    Remarks
-----------     ------      -----------             ------------------------------------------------
2-MAY-2016                 Khristine Austero        Initial Development
*/
--------------------------------------------------------------------------------------------

     l_new_record                 CONSTANT VARCHAR2(10)   := g_rec_stat_n;
     l_inventory_item_id          cm_cmpt_dtl.inventory_item_id%TYPE;
     l_calendar_code              cm_cldr_hdr_b.calendar_code%TYPE;
     l_period_code                cm_cldr_dtl.period_code%TYPE;
     l_cost_type_id               cm_cmpt_dtl.cost_type_id%TYPE;
     l_organization_id            cm_cmpt_dtl.organization_id%TYPE;
     l_cost_analysis_code         cm_cmpt_dtl.cost_analysis_code%TYPE := 'DIR';
     l_cmpntcost_id               NUMBER                              := NULL;
     l_cost_cmpntcls_id           NUMBER;
     l_burden_ind                 NUMBER                              := 0;
     l_delete_mark                NUMBER                              := 0;
     l_source_type                CONSTANT VARCHAR2(10)               := g_source_ebs;
     l_mess                       VARCHAR2(500);
     l_location                   VARCHAR2(100)                       := 'PROCESSING CM TO OPM BY ELEMENT';
     l_request_id                 NUMBER;
     l_resource_code              VARCHAR2(50);
     --API variables
     l_status                     VARCHAR2 (11);
     l_return_status              VARCHAR2 (11)                       := FND_API.g_ret_sts_success;
     l_count                      NUMBER   (10);
     l_record_count               NUMBER   (10)                       := 0;
     l_loop_cnt                   NUMBER   (10)                       := 0;
     l_dummy_cnt                  NUMBER   (10)                       := 0;
     l_msg_index_out              NUMBER;
     l_data                       VARCHAR2 (3000);
     l_header_rec                 GMF_ITEMCOST_PUB.HEADER_REC_TYPE;
     l_this_lvl_tbl               GMF_ITEMCOST_PUB.THIS_LEVEL_DTL_TBL_TYPE;
     l_lower_lvl_tbl              GMF_ITEMCOST_PUB.LOWER_LEVEL_DTL_TBL_TYPE;
     l_costcmpnt_ids              GMF_ITEMCOST_PUB.COSTCMPNT_IDS_TBL_TYPE;

     l_temp_cmpntcost_id               NUMBER := null;
   CURSOR c_ins_cmopm_by_element_stg(p_org VARCHAR2, p_item VARCHAR2)
   IS
     SELECT item_number
      ,organization_code
      ,inventory_item_id
      ,calendar_code
      ,period_code
      ,cost_type_id
      ,organization_id
      ,SUM(NVL(max_item_cost,0)+ NVL(min_item_cost,0)) AS item_cost
      ,cost_element
      ,resource_code
      ,level_type
     FROM (
          SELECT a.item_number
          ,a.organization_code
          ,a.inventory_item_id
          ,a.calendar_code
          ,a.period_code
          ,a.cost_type_id
          ,a.organization_id
          ,(CASE WHEN a.level_type = 1 THEN
            MAX(a.item_cost)
            END)AS max_item_cost
          ,(CASE WHEN level_type = 2 THEN
            MIN(a.item_cost)
            END)AS min_item_cost
          ,a.cost_element
          ,a.resource_code
          ,a.level_type
          FROM (
               SELECT DISTINCT
                     msi.segment1 AS ITEM_NUMBER
                    ,mpa.organization_code AS organization_code
                    ,msi.inventory_item_id AS INVENTORY_ITEM_ID
                    ,gps.calendar_code AS CALENDAR_CODE
                    ,gps.period_code AS PERIOD_CODE
                    ,gps.cost_type_id AS COST_TYPE_ID
                    ,msi.organization_id AS ORGANIZATION_ID
                    ,cic.item_cost AS ITEM_COST
                    ,cic.cost_element AS COST_ELEMENT
                    ,cic.resource_code AS RESOURCE_CODE
                    ,cic.level_type AS LEVEL_TYPE
               FROM
                    cst_item_cost_details_v  cic
                   ,mtl_parameters mpa
                   ,mtl_system_items msi
                   ,gmf_period_statuses gps
                   ,cst_item_cost_type_v d
               WHERE msi.organization_id = mpa.organization_id
                  AND msi.process_costing_enabled_flag='Y'
                  AND mpa.process_enabled_flag = 'Y'
                  AND (SYSDATE >= gps.start_date AND SYSDATE < gps.end_date + 1)
                                AND cic.inventory_item_id=d.inventory_item_id
                  AND cic.inventory_item_id = msi.inventory_item_id
                  AND d.cost_type= 'Frozen'--'Pending' -- need to change to FROZEN once done testing
                  AND cic.item_cost != 0
                  AND cic.cost_type_id = d.cost_type_id
                  AND (msi.inventory_item_id ,  msi.organization_id ) IN ( SELECT inventory_item_id , organization_id
                                                                           FROM mtl_item_categories_v
                                                                           WHERE category_set_name = 'Process_Category'
                                                                           AND category_concat_segs LIKE '%Discrete_%' )

                  ---PARAMETER---------
                  AND (mpa.organization_code = p_org
                       OR p_org IS NULL)
                  AND (msi.segment1 = p_item
                       OR p_item IS NULL)
                  AND  ( EXISTS
                          (SELECT cmpnt_cost
                           FROM cm_cmpt_dtl q,
                                 cm_cmpt_mst r
                           WHERE
                               q.inventory_item_id=msi.inventory_item_id
                           AND q.organization_id = msi.organization_id
                           AND q.cost_cmpntcls_id=r.cost_cmpntcls_id
                           --AND r.cost_cmpntcls_code='FG_MTL'
                           )
                          OR
                          NOT EXISTS
                          (SELECT cmpnt_cost
                           FROM cm_cmpt_dtl q
                           WHERE
                               q.inventory_item_id=msi.inventory_item_id
                           AND q.organization_id = msi.organization_id)
                        )
             --testing only--
             -- AND cic.resource_code NOT IN ('CON_RES2')
             --ORDER BY ORGANIZATION_CODE,ITEM_NUMBER
          ) a
          GROUP BY a.item_number
          ,a.organization_code
          ,a.inventory_item_id
          ,a.calendar_code
          ,a.period_code
          ,a.cost_type_id
          ,a.organization_id
          ,a.cost_element
          ,a.resource_code
          ,a.level_type
     )
     GROUP BY item_number
     ,organization_code
     ,inventory_item_id
     ,calendar_code
     ,period_code
     ,cost_type_id
     ,organization_id
     ,cost_element
     ,resource_code
     ,level_type
     ORDER BY ORGANIZATION_CODE,ITEM_NUMBER;


   CURSOR c_ins_cmopm_by_element_fg_api
   IS
/*
      SELECT *
      FROM xxnbty.xxnbty_opm_iccon_fl_stg
      WHERE source_type = g_source_ebs
      AND request_id = p_request_id
      AND cost_cmpntcls_id IS NOT NULL;
      --AND fg_mtl_cost IS NOT NULL;
*/
      SELECT SUM(cmpnt_cost) AS cmpnt_cost
             ,calendar_code
             ,period_code
             ,cost_type_id
             ,organization_id
             ,item_number
             ,cmpntcost_id
             ,cost_cmpntcls_id
             ,cost_analysis_code
      FROM xxnbty.xxnbty_opm_iccon_fl_stg
      WHERE source_type = g_source_ebs
      AND request_id = p_request_id
      AND cost_cmpntcls_id IS NOT NULL
      GROUP BY calendar_code, period_code, cost_type_id, organization_id, item_number,
      cmpntcost_id, cost_cmpntcls_id, cost_analysis_code;

    BEGIN

    l_request_id :=  p_request_id;
    printlog_pr('FOR LOOP' || p_org);
    FOR r_ins_cmopm_by_element_stg IN c_ins_cmopm_by_element_stg(p_org,p_item)
    LOOP
/*
       SELECT ccm.cost_cmpntcls_id
       INTO l_cost_cmpntcls_id
       FROM cm_cmpt_mst ccm
       WHERE ccm.cost_cmpntcls_code = r_ins_cmopm_by_element_stg.resource_code;
*/
            IF r_ins_cmopm_by_element_stg.cost_element = 'Resource' AND (r_ins_cmopm_by_element_stg.resource_code = 'CON_RES' OR r_ins_cmopm_by_element_stg.resource_code IS NULL) THEN
                l_resource_code := 'RES_COST';
            ELSIF r_ins_cmopm_by_element_stg.cost_element = 'Material' AND (r_ins_cmopm_by_element_stg.resource_code = 'Item' OR r_ins_cmopm_by_element_stg.resource_code IS NULL) THEN
                l_resource_code := 'RMW';
            ELSIF r_ins_cmopm_by_element_stg.cost_element = 'Material Overhead' AND r_ins_cmopm_by_element_stg.resource_code IS NULL THEN
                l_resource_code := 'MAT_OH';
            ELSIF r_ins_cmopm_by_element_stg.cost_element = 'Overhead' AND (r_ins_cmopm_by_element_stg.resource_code = 'RES_OH' OR r_ins_cmopm_by_element_stg.resource_code IS NULL) THEN
                l_resource_code := 'RES_OH';
            ELSIF r_ins_cmopm_by_element_stg.resource_code = 'YIELD_RES' AND r_ins_cmopm_by_element_stg.cost_element = 'Resource' THEN
                l_resource_code := 'YIELD_RES';
            ELSE
                l_resource_code := r_ins_cmopm_by_element_stg.resource_code;
            END IF;
    printlog_pr('resource code' || l_resource_code);
    printlog_pr('cost_element' || r_ins_cmopm_by_element_stg.cost_element);
    printlog_pr('resource_code_orig' || r_ins_cmopm_by_element_stg.resource_code);
    BEGIN
           SELECT ccm.cost_cmpntcls_id
           INTO l_cost_cmpntcls_id
           FROM cm_cmpt_mst ccm
           WHERE ccm.cost_cmpntcls_code = l_resource_code;
       EXCEPTION
      WHEN NO_DATA_FOUND THEN
         l_cost_cmpntcls_id := NULL;
  END;
        BEGIN
            INSERT
            INTO xxnbty.xxnbty_opm_iccon_fl_stg
            (
             item_number
            ,organization_code
            ,inventory_item_id
            ,calendar_code
            ,period_code
            ,cost_type_id
            ,organization_id
            --,cmpntcost_id
            ,cost_cmpntcls_id
            ,cost_analysis_code
            ,cmpnt_cost
            ,burden_ind
            ,delete_mark
            ,created_by
            ,last_update_login
            ,last_updated_by
            ,request_id
            ,record_status
            ,source_type
                  ,resource_code
            )
            VALUES
             (r_ins_cmopm_by_element_stg.item_number
            ,r_ins_cmopm_by_element_stg.organization_code
            ,r_ins_cmopm_by_element_stg.inventory_item_id
            ,r_ins_cmopm_by_element_stg.calendar_code
            ,r_ins_cmopm_by_element_stg.period_code
            ,r_ins_cmopm_by_element_stg.cost_type_id
            ,r_ins_cmopm_by_element_stg.organization_id
            --,l_cmpntcost_id
            ,l_cost_cmpntcls_id
            ,l_cost_analysis_code
            ,r_ins_cmopm_by_element_stg.item_cost
            ,l_burden_ind
            ,l_delete_mark
            ,g_created_by
            ,g_last_update_login
            ,g_last_updated_by
            ,l_request_id
            ,l_new_record
            ,l_source_type
            ,l_resource_code
            );
            COMMIT;
        END;
    printlog_pr('INSERT' || l_cost_cmpntcls_id);
/*Update final Staging Table cost Component Class ID*/
/*
    UPDATE xxnbty.xxnbty_opm_iccon_fl_stg stg
    SET stg.cmpntcost_id = (
        SELECT cmpntcost_id
        FROM cm_cmpt_dtl ccd,
             gmf_period_statuses gps
        WHERE ccd.inventory_item_id = stg.inventory_item_id
            AND stg.period_code = gps.period_code
            AND ccd.cost_cmpntcls_id = l_cost_cmpntcls_id
            AND ccd.organization_id = stg.organization_id
            AND ccd.period_id = gps.period_id
            AND ccd.item_id is null
            AND ROWNUM = 1)
    WHERE EXISTS ( SELECT 1
                   FROM cm_cmpt_dtl ccd,
                    gmf_period_statuses gps
                WHERE ccd.inventory_item_id = stg.inventory_item_id
                AND stg.period_code = gps.period_code
                AND ccd.cost_cmpntcls_id = l_cost_cmpntcls_id
                AND ccd.organization_id = stg.organization_id
                AND ccd.period_id = gps.period_id
                   AND ccd.item_id is null
                   AND ROWNUM = 1); */
    COMMIT;
    END LOOP;

-- Added
begin
  for temp_rec in ( select rowid , stg.* from  xxnbty.xxnbty_opm_iccon_fl_stg stg
                    WHERE 1=1
                    AND cost_cmpntcls_id IS NOT NULL )
   Loop
      l_temp_cmpntcost_id := null;
       begin
          SELECT cmpntcost_id
           into l_temp_cmpntcost_id--l_cmpntcost_id
        FROM cm_cmpt_dtl ccd,
             gmf_period_statuses gps
        WHERE ccd.inventory_item_id = temp_rec.inventory_item_id
            AND temp_rec.period_code = gps.period_code
            AND ccd.cost_cmpntcls_id = temp_rec.cost_cmpntcls_id
            AND ccd.organization_id = temp_rec.organization_id
            AND ccd.period_id = gps.period_id
            AND ccd.item_id is null;
            --and ccd.delete_mark=0;
            Exception
              when NO_DATA_FOUND then
                 l_temp_cmpntcost_id := null;
       end;
      update xxnbty.xxnbty_opm_iccon_fl_stg set cmpntcost_id = l_temp_cmpntcost_id
      where rowid = temp_Rec.rowid;
   End Loop ;
  end ;

-- End of addition
printlog_pr('Start INSERT VIA API' );
 /*INSERT VIA API*/
--/*
    FOR r_ins_cmopm_by_element_fg_api IN c_ins_cmopm_by_element_fg_api
    LOOP
        IF r_ins_cmopm_by_element_fg_api.cmpntcost_id IS NULL THEN

            BEGIN
             FND_GLOBAL.APPS_INITIALIZE (user_id           => g_user_id,
                                         resp_id           => g_resp_id,
                                         resp_appl_id      => g_resp_appl_id
                                         );

                l_header_rec.calendar_code       := r_ins_cmopm_by_element_fg_api.calendar_code;
                l_header_rec.period_code         := r_ins_cmopm_by_element_fg_api.period_code;
                l_header_rec.cost_type_id        := r_ins_cmopm_by_element_fg_api.cost_type_id;
                l_header_rec.organization_id     := r_ins_cmopm_by_element_fg_api.organization_id;
                l_header_rec.item_number         := r_ins_cmopm_by_element_fg_api.item_number;
                l_header_rec.user_name           := g_user_name;

                l_this_lvl_tbl (1).cmpntcost_id          := r_ins_cmopm_by_element_fg_api.cmpntcost_id;--l_cmpntcost_id; -- for updating
                l_this_lvl_tbl (1).cost_cmpntcls_id      := r_ins_cmopm_by_element_fg_api.cost_cmpntcls_id;    -- l_cost_cmpntcls_id;  --req
                l_this_lvl_tbl (1).cost_analysis_code    := r_ins_cmopm_by_element_fg_api.cost_analysis_code; -- l_cost_analysis_code; --req
                l_this_lvl_tbl (1).cmpnt_cost            := r_ins_cmopm_by_element_fg_api.cmpnt_cost;
                l_this_lvl_tbl (1).burden_ind            := l_burden_ind;
                l_this_lvl_tbl (1).delete_mark           := l_delete_mark;

              printlog_pr('Start CREATE_ITEM_COST for ORG ' || r_ins_cmopm_by_element_fg_api.organization_id ||' Item number ' || r_ins_cmopm_by_element_fg_api.item_number );
                GMF_ITEMCOST_PUB.CREATE_ITEM_COST
                                                 (p_api_version              => 3.0,
                                                  p_init_msg_list            => FND_API.g_false,
                                                  p_commit                   => FND_API.g_false,
                                                  x_return_status            => l_status,
                                                  x_msg_count                => l_count,
                                                  x_msg_data                 => l_data,
                                                  p_header_rec               => l_header_rec,
                                                  p_this_level_dtl_tbl       => l_this_lvl_tbl,
                                                  p_lower_level_dtl_tbl      => l_lower_lvl_tbl,
                                                  x_costcmpnt_ids            => l_costcmpnt_ids
                                                 );

--              printlog_pr('Status:' || l_status);
--              printlog_pr('Debug:' || l_count);
/*
                IF l_status = 'S'
                THEN
                   COMMIT;
                   printlog_pr('SUCCESS!!');
                ELSE
                    IF l_count = 1
                       THEN
                          printlog_pr('Error 11111 ' || l_data);
                       ELSE
                          printlog_pr(   'status: '
                                                || l_status
                                                || ' Error Count '
                                                || l_count
                                               );

                          FOR I IN 1 .. l_count
                          LOOP
                             FND_MSG_PUB.GET (p_msg_index          => I,
                                              p_data               => l_data,
                                              p_encoded            => FND_API.g_false,
                                              p_msg_index_out      => l_msg_index_out
                                             );
                             printlog_pr('Error 2222: ' || SUBSTR (l_data, 1, 255));
                          END LOOP;
                    END IF;
                END IF;
                printlog_pr('END');
*/
            END;
            COMMIT;

        ELSE

            BEGIN
                FND_GLOBAL.APPS_INITIALIZE (user_id           => g_user_id,
                                            resp_id           => g_resp_id,
                                            resp_appl_id      => g_resp_appl_id
                                           );

                l_header_rec.calendar_code       := r_ins_cmopm_by_element_fg_api.calendar_code;
                l_header_rec.period_code         := r_ins_cmopm_by_element_fg_api.period_code;
                l_header_rec.cost_type_id        := r_ins_cmopm_by_element_fg_api.cost_type_id;
                l_header_rec.organization_id     := r_ins_cmopm_by_element_fg_api.organization_id;
                l_header_rec.item_number         := r_ins_cmopm_by_element_fg_api.item_number;
                l_header_rec.user_name           := g_user_name;

                l_this_lvl_tbl (1).cmpntcost_id          := r_ins_cmopm_by_element_fg_api.cmpntcost_id;--l_cmpntcost_id; -- for updating
                l_this_lvl_tbl (1).cost_cmpntcls_id      := r_ins_cmopm_by_element_fg_api.cost_cmpntcls_id;  --req
                l_this_lvl_tbl (1).cost_analysis_code    := r_ins_cmopm_by_element_fg_api.cost_analysis_code; --req
                l_this_lvl_tbl (1).cmpnt_cost            := r_ins_cmopm_by_element_fg_api.cmpnt_cost;
                l_this_lvl_tbl (1).burden_ind            := l_burden_ind;
                l_this_lvl_tbl (1).delete_mark           := l_delete_mark;

              printlog_pr('Start UPDATE_ITEM_COST for ORG ' || r_ins_cmopm_by_element_fg_api.organization_id ||' Item number ' || r_ins_cmopm_by_element_fg_api.item_number );
                GMF_ITEMCOST_PUB.UPDATE_ITEM_COST
                                                 (p_api_version              => 3.0,
                                                  p_init_msg_list            => FND_API.g_false,
                                                  p_commit                   => FND_API.g_false,
                                                  x_return_status            => l_status,
                                                  x_msg_count                => l_count,
                                                  x_msg_data                 => l_data,
                                                  p_header_rec               => l_header_rec,
                                                  p_this_level_dtl_tbl       => l_this_lvl_tbl,
                                                  p_lower_level_dtl_tbl      => l_lower_lvl_tbl
                                                 );
--              printlog_pr('Status:' || l_status);
--              printlog_pr('Debug:' || l_count);
/*
                IF l_status = 'S'
                THEN
                   COMMIT;
                   printlog_pr('SUCCESS!!');
                ELSE
                   IF l_count = 1
                   THEN
                      printlog_pr('Error 11111 ' || l_data);
                   ELSE
                      printlog_pr(   'status: '
                                            || l_status
                                            || ' Error Count '
                                            || l_count
                                           );

                      FOR I IN 1 .. l_count
                      LOOP
                         FND_MSG_PUB.GET (p_msg_index          => I,
                                          p_data               => l_data,
                                          p_encoded            => FND_API.g_false,
                                          p_msg_index_out      => l_msg_index_out
                                         );
                         printlog_pr('Error 2222: ' || SUBSTR (l_data, 1, 255));
                      END LOOP;
                   END IF;
                END IF;
                printlog_pr('END');
*/
            END;
        COMMIT;
        END IF;
    END LOOP;
--*/

/*UPDATE RECORD STATUS*/
      UPDATE xxnbty.xxnbty_opm_iccon_fl_stg stg
      SET stg.record_status = g_rec_stat_i
      WHERE source_type = g_source_ebs
      AND request_id = p_request_id
        AND cost_cmpntcls_id IS NOT NULL;
      COMMIT;
/*END UPDATE*/


    EXCEPTION
        WHEN OTHERS THEN
          l_mess := 'Error on ['||l_location||'] - SQLCODE [' ||SQLCODE|| '] - ' ||substr(SQLERRM,1,100);
          x_errbuf  := l_mess;
          x_retcode := 2;

     END process_cm_to_opm_by_element;

PROCEDURE process_opm_records ( x_errbuf    OUT VARCHAR2,
                            x_retcode   OUT VARCHAR2)
IS
----------------------------------------------------------------------------------------------
/*
Procedure Name: process_opm_records
Author's Name: John Paul Aquino
Date written: 25-FEB-2016
RICEFW Object: CONV-01
Description:
Program Style:

Maintenance History:

Date            Issue#      Name                    Remarks
-----------     ------      -----------             ------------------------------------------------
25-FEB-2016                 John Paul Aquino        Initial Development
*/
--------------------------------------------------------------------------------------------
     l_inventory_item_id          cm_cmpt_dtl.inventory_item_id%TYPE;
     l_calendar_code              cm_cldr_hdr_b.calendar_code%TYPE;
     l_period_code                cm_cldr_dtl.period_code%TYPE;
     l_cost_type_id               cm_cmpt_dtl.cost_type_id%TYPE;
     l_organization_id            cm_cmpt_dtl.organization_id%TYPE;
     l_cost_analysis_code         cm_cmpt_dtl.cost_analysis_code%TYPE := 'DIR';
     l_cmpntcost_id               NUMBER;
     l_cost_cmpntcls_id           NUMBER;
     l_burden_ind                 NUMBER                              := 0;
     l_delete_mark                NUMBER                              := 0;
     l_data_count                 NUMBER                              := 0;
     l_mess                       VARCHAR2(500);
     l_location                   VARCHAR2(100) := 'PROCESSING OPM RECORDS';

     --API variables
     l_status          VARCHAR2 (11);
     l_return_status   VARCHAR2 (11)                               := FND_API.g_ret_sts_success;
     l_count           NUMBER   (10);
     l_record_count    NUMBER   (10)                               := 0;
     l_loop_cnt        NUMBER   (10)                               := 0;
     l_dummy_cnt       NUMBER   (10)                               := 0;
     l_msg_index_out   NUMBER;
     l_data            VARCHAR2 (3000);
     l_header_rec      GMF_ITEMCOST_PUB.HEADER_REC_TYPE;
     l_this_lvl_tbl    GMF_ITEMCOST_PUB.THIS_LEVEL_DTL_TBL_TYPE;
     l_lower_lvl_tbl   GMF_ITEMCOST_PUB.LOWER_LEVEL_DTL_TBL_TYPE;
     l_costcmpnt_ids   GMF_ITEMCOST_PUB.COSTCMPNT_IDS_TBL_TYPE;

-- cursor that will derived required fields to final staging
   CURSOR c_ins_val
   IS
       SELECT xois.as400_number
             ,xois.item_status
             ,xois.item_number
             ,xois.organization_code
             ,xois.ora_category
             ,xois.material_cost
             ,xois.mat_cost_oh_pcnt
             ,xois.resource_cost
             ,xois.res_cost_oh
             ,xois.request_id
             ,xois.record_status
             ,mpa.organization_id
             ,msi.inventory_item_id
             ,gps.calendar_code
             ,gps.cost_type_id
             ,gps.period_code
             ,gps.period_id
             ,xois.source_type
       FROM xxnbty.xxnbty_opm_iccon_stg xois
           ,mtl_parameters mpa
           ,mtl_system_items msi
           ,gmf_period_statuses gps
       WHERE xois.record_status = g_rec_stat_v
       AND xois.source_type = g_source_as
       AND mpa.organization_code = xois.organization_code
       AND mpa.organization_id = msi.organization_id
       AND msi.segment1 = xois.item_number
       AND xois.creation_date BETWEEN gps.start_date AND gps.end_date;

   CURSOR c_proc_raw
   IS
       SELECT *
       FROM xxnbty.xxnbty_opm_iccon_fl_stg
       WHERE material_cost IS NOT NULL
       AND source_type = g_source_as
       AND record_status = g_rec_stat_v;
       --AND mat_cost_oh_pcnt IS NOT NULL;

   /*CURSOR cur_proc_bulk --pending pa to
   IS
       SELECT *
       FROM xxnbty.xxnbty_opm_iccon_fl_stg
       WHERE resource_cost IS NOT NULL
       AND res_cost_oh IS NOT NULL; */

   BEGIN
    --Changed for the cmpntcls_id
    SELECT ccm.cost_cmpntcls_id
    INTO l_cost_cmpntcls_id
    FROM cm_cmpt_mst ccm
    WHERE ccm.cost_cmpntcls_code = g_mat_rmw;


        FOR  r_ins_val IN c_ins_val
        LOOP
            l_cmpntcost_id := NULL; -- Added By Sanjay
                BEGIN
                    SELECT COUNT(1)
                    INTO l_data_count
                    FROM cm_cmpt_dtl
                    WHERE inventory_item_id = r_ins_val.inventory_item_id
                    AND cost_cmpntcls_id = l_cost_cmpntcls_id -- ALBERT ON CMPNTCLS ID
                    AND organization_id = r_ins_val.organization_id;

                        IF (l_data_count > 0) THEN
                            BEGIN
                                SELECT cmpntcost_id
                                INTO l_cmpntcost_id
                                FROM cm_cmpt_dtl
                                WHERE inventory_item_id = r_ins_val.inventory_item_id
                                AND cost_cmpntcls_id = l_cost_cmpntcls_id -- ALBERT ON CMPNTCLS ID
                                AND organization_id = r_ins_val.organization_id
                                AND period_id = r_ins_val.period_id
                                AND item_id is null
                                AND cost_level =0 ;   -- Added by sanjay
                            EXCEPTION
                                WHEN NO_DATA_FOUND THEN
                                   l_cmpntcost_id := NULL;
                            END;
                        END IF;
                END;

            BEGIN
                INSERT
                INTO xxnbty.xxnbty_opm_iccon_fl_stg
                (as400_number
                ,item_status
                ,item_number
                ,organization_code
                ,ora_category
                ,material_cost
                ,mat_cost_oh_pcnt
                ,resource_cost
                ,res_cost_oh
                ,inventory_item_id
                ,calendar_code
                ,period_code
                ,cost_type_id
                ,organization_id
                ,cmpntcost_id
                ,cost_cmpntcls_id
                ,cost_analysis_code
                ,cmpnt_cost
                ,burden_ind
                ,delete_mark
                ,created_by
                ,last_update_login
                ,last_updated_by
                ,request_id
                ,record_status
                ,source_type
                )
                VALUES
                (r_ins_val.as400_number
                ,r_ins_val.item_status
                ,r_ins_val.item_number
                ,r_ins_val.organization_code
                ,r_ins_val.ora_category
                ,r_ins_val.material_cost
                ,r_ins_val.mat_cost_oh_pcnt
                ,r_ins_val.resource_cost
                ,r_ins_val.res_cost_oh
                ,r_ins_val.inventory_item_id
                ,r_ins_val.calendar_code
                ,r_ins_val.period_code
                ,r_ins_val.cost_type_id
                ,r_ins_val.organization_id
                ,l_cmpntcost_id
                ,l_cost_cmpntcls_id -- ALBERT ON CMPNTCLS ID
                ,l_cost_analysis_code
                ,r_ins_val.material_cost
                ,l_burden_ind
                ,l_delete_mark
                ,g_created_by
                ,g_last_update_login
                ,g_last_updated_by
                ,r_ins_val.request_id
                ,r_ins_val.record_status
                ,r_ins_val.source_type
                );
                COMMIT;
            END;

    END LOOP;

        FOR r_proc_raw IN c_proc_raw
        LOOP
            IF r_proc_raw.cmpntcost_id IS NULL THEN -- CALL API CREATE_ITEM_COST

                BEGIN --load raw material cost
                    FND_GLOBAL.APPS_INITIALIZE (user_id           => g_user_id,
                                                resp_id           => g_resp_id,
                                                resp_appl_id      => g_resp_appl_id
                                               );

                    l_header_rec.calendar_code       := r_proc_raw.calendar_code;
                    l_header_rec.period_code         := r_proc_raw.period_code;
                    l_header_rec.cost_type_id        := r_proc_raw.cost_type_id;
                    l_header_rec.organization_id     := r_proc_raw.organization_id;
                    l_header_rec.item_number         := r_proc_raw.item_number;
                    l_header_rec.user_name           := g_user_name;

                    l_this_lvl_tbl (1).cost_cmpntcls_id      := l_cost_cmpntcls_id;  --req
                    l_this_lvl_tbl (1).cost_analysis_code    := l_cost_analysis_code; --req
                    l_this_lvl_tbl (1).cmpnt_cost            := r_proc_raw.material_cost;
                    l_this_lvl_tbl (1).burden_ind            := l_burden_ind;
                    l_this_lvl_tbl (1).delete_mark           := l_delete_mark;

                    printlog_pr('Start CREATE_ITEM_COST for ORG ' || r_proc_raw.organization_id ||' Item number ' || r_proc_raw.item_number );
                    GMF_ITEMCOST_PUB.CREATE_ITEM_COST
                                                     (p_api_version              => 3.0,
                                                      p_init_msg_list            => FND_API.g_false,
                                                      p_commit                   => FND_API.g_false,
                                                      x_return_status            => l_status,
                                                      x_msg_count                => l_count,
                                                      x_msg_data                 => l_data,
                                                      p_header_rec               => l_header_rec,
                                                      p_this_level_dtl_tbl       => l_this_lvl_tbl,
                                                      p_lower_level_dtl_tbl      => l_lower_lvl_tbl,
                                                      x_costcmpnt_ids            => l_costcmpnt_ids
                                                     );
                    printlog_pr('Status:' || l_status);
                    printlog_pr('Debug:' || l_count);

                    IF l_status = 'S'
                    THEN
                       COMMIT;
                       printlog_pr ('SUCCESS!!');
                    ELSE
                       IF l_count = 1
                       THEN
                          printlog_pr('Error 11111 ' || l_data);
                       ELSE
                          printlog_pr (   'status: '
                                                || l_status
                                                || ' Error Count '
                                                || l_count
                                               );

                          FOR I IN 1 .. l_count
                          LOOP
                             FND_MSG_PUB.GET (p_msg_index          => I,
                                              p_data               => l_data,
                                              p_encoded            => FND_API.g_false,
                                              p_msg_index_out      => l_msg_index_out
                                             );
                             printlog_pr ('Error 2222: ' || SUBSTR (l_data, 1, 255));
                          END LOOP;
                       END IF;
                    END IF;

                    printlog_pr('END');
                END;
                COMMIT;
            ELSE
            -- CALL API UPDATE_ITEM_COST
                    BEGIN
                        FND_GLOBAL.APPS_INITIALIZE (user_id           => g_user_id,
                                                    resp_id           => g_resp_id,
                                                    resp_appl_id      => g_resp_appl_id
                                                   );

                        l_header_rec.calendar_code       := r_proc_raw.calendar_code;
                        l_header_rec.period_code         := r_proc_raw.period_code;
                        l_header_rec.cost_type_id        := r_proc_raw.cost_type_id;
                        l_header_rec.organization_id     := r_proc_raw.organization_id;
                        l_header_rec.item_number         := r_proc_raw.item_number;
                        l_header_rec.user_name           := g_user_name;

                        L_THIS_LVL_TBL (1).CMPNTCOST_ID          := r_proc_raw.cmpntcost_id; -- for updating
                        l_this_lvl_tbl (1).cost_cmpntcls_id      := l_cost_cmpntcls_id;  --req
                        l_this_lvl_tbl (1).cost_analysis_code    := l_cost_analysis_code; --req
                        l_this_lvl_tbl (1).cmpnt_cost            := r_proc_raw.material_cost;
                        l_this_lvl_tbl (1).burden_ind            := l_burden_ind;
                        l_this_lvl_tbl (1).delete_mark           := l_delete_mark;

                        printlog_pr('Start UPDATE_ITEM_COST for ORG ' || r_proc_raw.organization_id ||' Item number ' || r_proc_raw.item_number );
                        GMF_ITEMCOST_PUB.UPDATE_ITEM_COST
                                                         (p_api_version              => 3.0,
                                                          p_init_msg_list            => FND_API.g_false,
                                                          p_commit                   => FND_API.g_false,
                                                          x_return_status            => l_status,
                                                          x_msg_count                => l_count,
                                                          x_msg_data                 => l_data,
                                                          p_header_rec               => l_header_rec,
                                                          p_this_level_dtl_tbl       => l_this_lvl_tbl,
                                                          p_lower_level_dtl_tbl      => l_lower_lvl_tbl
                                                         );
                        printlog_pr('Status:' || l_status);
                        printlog_pr('Debug:' || l_count);

                            IF l_status = 'S'
                            THEN
                               COMMIT;
                               printlog_pr('SUCCESS!!');
                            ELSE
                                   IF l_count = 1
                                   THEN
                                      printlog_pr('Error 11111 ' || l_data);
                                   ELSE
                                      printlog_pr(   'status: '
                                                            || l_status
                                                            || ' Error Count '
                                                            || l_count
                                                           );

                                      FOR I IN 1 .. l_count
                                      LOOP
                                         FND_MSG_PUB.GET (p_msg_index          => I,
                                                          p_data               => l_data,
                                                          p_encoded            => FND_API.g_false,
                                                          p_msg_index_out      => l_msg_index_out
                                                         );
                                         printlog_pr('Error 2222: ' || SUBSTR (l_data, 1, 255));
                                      END LOOP;
                                   END IF;
                            END IF;
                        printlog_pr('END');
                    END;
                COMMIT;
            END IF;
    END LOOP;

    EXCEPTION
        WHEN OTHERS THEN
          l_mess := 'Error on ['||l_location||'] - SQLCODE [' ||SQLCODE|| '] - ' ||substr(SQLERRM,1,100);
          x_errbuf  := l_mess;
          x_retcode := 2;
   END process_opm_records;

PROCEDURE process_cm_records    ( x_errbuf      OUT VARCHAR2,
                                x_retcode       OUT VARCHAR2,
                                p_request_id    IN VARCHAR2)
   IS
--------------------------------------------------------------------------------------------
/*
Procedure Name: process_cm_records
Author's Name: John Paul Aquino
Date written: 25-FEB-2016
RICEFW Object: CONV-01
Description:
Program Style:

Maintenance History:

Date            Issue#      Name                    Remarks
-----------     ------      -----------             ----------------------------------------
25-FEB-2016                 John Paul Aquino        Initial Development
*/
--------------------------------------------------------------------------------------------

    l_inventory_item_id     cm_cmpt_dtl.inventory_item_id%TYPE;
    l_cost_type_id          cst_item_cst_dtls_interface.cost_type_id%TYPE   := 3;
    l_resouce_id            cst_item_cst_dtls_interface.resource_id%TYPE;
    l_cost_element_id       cst_item_cst_dtls_interface.cost_element_id%TYPE;
    l_process_flag          cst_item_cst_dtls_interface.process_flag%TYPE   := 1;
    l_mess                  VARCHAR2(500);
    l_location              VARCHAR2(100)                                   := 'PROCESSING CM RECORDS';
    l_request_id            NUMBER;

    CURSOR c_ins_fl_int
    IS
        SELECT inventory_item_id
              ,organization_id
              ,cost_type_id
              ,resource_id
              ,usage_rate_or_amount
              ,cost_element_id
              ,process_flag
              ,resource_code
        FROM xxnbty.xxnbty_cm_iccon_fl_stg
        WHERE record_status = g_rec_stat_p
        AND source_type = g_source_as;

    CURSOR c_ins_disc_raw
    IS
        SELECT xcis.as400_number
              ,xcis.item_status
              ,xcis.item_number
              ,xcis.organization_code
              ,xcis.ora_category
              ,xcis.material_cost
              ,xcis.mat_cost_oh_pcnt
              ,xcis.resource_cost
              ,xcis.overhead
              ,xcis.request_id
              ,xcis.record_status
              ,xcis.source_type
              ,ood.organization_id
              ,msi.inventory_item_id
              ,brv.resource_id
              ,brv.cost_element_id
        FROM xxnbty.xxnbty_cm_iccon_stg xcis
            ,org_organization_definitions ood
            ,hr_all_organization_units haou
            ,mtl_system_items msi
            ,bom_resources_v brv
        WHERE xcis.record_status = g_rec_stat_v
        AND ood.operating_unit = haou.organization_id
        AND ood.organization_code = xcis.organization_code
        AND msi.segment1 = xcis.item_number
        AND msi.organization_id = ood.organization_id
        AND brv.organization_id = ood.organization_id
        AND brv.resource_code = g_item
        AND xcis.resource_cost IS NULL
        AND xcis.overhead IS NULL
        AND xcis.material_cost IS NOT NULL
        AND xcis.mat_cost_oh_pcnt IS NOT NULL
        AND xcis.source_type = g_source_as
        AND xcis.request_id = p_request_id;

    CURSOR cur_ins_disc_bulk
    IS
        SELECT xcis.as400_number
              ,xcis.item_status
              ,xcis.item_number
              ,xcis.organization_code
              ,xcis.ora_category
              ,xcis.material_cost
              ,xcis.mat_cost_oh_pcnt
              ,xcis.resource_cost
              ,xcis.overhead
              ,xcis.request_id
              ,xcis.record_status
              ,xcis.source_type
              ,ood.organization_id
              ,msi.inventory_item_id
              ,brv.resource_id
              ,brv.cost_element_id
        FROM xxnbty.xxnbty_cm_iccon_stg xcis
            ,org_organization_definitions ood
            ,hr_all_organization_units haou
            ,mtl_system_items msi
            ,bom_resources_v brv
        WHERE xcis.record_status = g_rec_stat_v
        AND ood.operating_unit = haou.organization_id
        AND ood.organization_code = xcis.organization_code
        AND msi.segment1 = xcis.item_number
        AND msi.organization_id = ood.organization_id
        AND brv.organization_id = ood.organization_id
        AND brv.resource_code = g_con_res--'CON_RES1'
        AND xcis.material_cost IS NULL
        AND xcis.mat_cost_oh_pcnt IS NULL
        AND xcis.resource_cost IS NOT NULL
        AND xcis.overhead IS NOT NULL
        AND xcis.source_type = g_source_as
        AND xcis.request_id = p_request_id;

    CURSOR c_ins_yield_res
    IS
        SELECT xcis.as400_number
              ,xcis.item_status
              ,xcis.item_number
              ,xcis.organization_code
              ,xcis.ora_category
              ,xcis.material_cost
              ,xcis.mat_cost_oh_pcnt
              ,xcis.resource_cost
              ,xcis.OVERHEAD
              ,xcis.yield_res_cost
              ,xcis.request_id
              ,xcis.record_status
              ,xcis.source_type
              ,ood.organization_id
              ,msi.inventory_item_id
              ,brv.resource_id
              ,brv.cost_element_id
        FROM xxnbty.xxnbty_cm_iccon_stg xcis
            ,org_organization_definitions ood
            ,hr_all_organization_units haou
            ,mtl_system_items msi
            ,bom_resources_v brv
        WHERE xcis.record_status = g_rec_stat_v
        AND ood.operating_unit = haou.organization_id
        AND ood.organization_code = xcis.organization_code
        AND msi.segment1 = xcis.item_number
        AND msi.organization_id = ood.organization_id
        AND brv.organization_id = ood.organization_id
        AND brv.resource_code = g_yield_res
        AND xcis.resource_cost IS NULL
        AND xcis.overhead IS NULL
        AND xcis.yield_res_cost IS NOT NULL
        AND xcis.material_cost IS NULL
        AND xcis.mat_cost_oh_pcnt IS  NULL
        AND xcis.source_type = g_source_as
        AND xcis.request_id = p_request_id;

BEGIN
    BEGIN
    l_request_id := p_request_id;

                FOR r_ins_disc_raw IN c_ins_disc_raw
                LOOP
                /*LOAD DATA to FINAL STAGING ITEM*/
                    BEGIN
                        INSERT
                        INTO xxnbty.xxnbty_cm_iccon_fl_stg
                        (as400_number
                        ,item_status
                        ,item_number
                        ,organization_code
                        ,ora_category
                        ,material_cost
                        ,inventory_item_id
                        ,cost_type_id
                        ,organization_id
                        ,resource_id
                        ,usage_rate_or_amount
                        ,cost_element_id
                        ,process_flag
                        ,resource_code
                        ,created_by
                        ,last_update_login
                        ,last_updated_by
                        ,request_id
                        ,record_status
                        ,source_type
                        )
                        VALUES
                        (r_ins_disc_raw.as400_number
                        ,r_ins_disc_raw.item_status
                        ,r_ins_disc_raw.item_number
                        ,r_ins_disc_raw.organization_code
                        ,r_ins_disc_raw.ora_category
                        ,r_ins_disc_raw.material_cost
                        ,r_ins_disc_raw.inventory_item_id
                        ,l_cost_type_id
                        ,r_ins_disc_raw.organization_id
                        ,r_ins_disc_raw.resource_id
                        ,r_ins_disc_raw.material_cost
                        ,r_ins_disc_raw.cost_element_id
                        ,l_process_flag
                        ,g_item
                        ,g_created_by
                        ,g_last_update_login
                        ,g_last_updated_by
                        ,l_request_id--r_ins_disc_raw.request_id
                        ,g_rec_stat_p
                        ,r_ins_disc_raw.source_type
                        );
                    COMMIT;
                    END;

                        BEGIN
                            SELECT resource_id
                            INTO l_resouce_id
                            FROM BOM_RESOURCES_V
                            WHERE organization_id = r_ins_disc_raw.organization_id
                            AND RESOURCE_CODE = g_mat_oh;

                            EXCEPTION
                            WHEN NO_DATA_FOUND THEN
                                l_resouce_id := null;
                        END;

                        BEGIN
                            SELECT cost_element_id
                            INTO l_cost_element_id
                            FROM BOM_RESOURCES_V
                            WHERE organization_id = r_ins_disc_raw.organization_id
                            AND resource_id = l_resouce_id;

                            EXCEPTION
                            WHEN NO_DATA_FOUND THEN
                              l_cost_element_id := null;
                        END;

                /*LOAD DATA to FINAL STAGING MAT_OH*/
                    BEGIN
                        INSERT
                        INTO xxnbty.xxnbty_cm_iccon_fl_stg
                        (as400_number
                        ,item_status
                        ,item_number
                        ,organization_code
                        ,ora_category
                        ,material_cost
                        ,mat_cost_oh_pcnt
                        ,mat_cost_oh
                        ,inventory_item_id
                        ,cost_type_id
                        ,organization_id
                        ,resource_id
                        ,usage_rate_or_amount
                        ,cost_element_id
                        ,process_flag
                        ,resource_code
                        ,created_by
                        ,last_update_login
                        ,last_updated_by
                        ,request_id
                        ,record_status
                        ,source_type
                        )
                        VALUES
                        (r_ins_disc_raw.as400_number
                        ,r_ins_disc_raw.item_status
                        ,r_ins_disc_raw.item_number
                        ,r_ins_disc_raw.organization_code
                        ,r_ins_disc_raw.ora_category
                        ,r_ins_disc_raw.material_cost
                        ,r_ins_disc_raw.mat_cost_oh_pcnt
                        ,r_ins_disc_raw.material_cost * r_ins_disc_raw.mat_cost_oh_pcnt /100
                        ,r_ins_disc_raw.inventory_item_id
                        ,l_cost_type_id
                        ,r_ins_disc_raw.organization_id
                        ,l_resouce_id
                        ,r_ins_disc_raw.material_cost * r_ins_disc_raw.mat_cost_oh_pcnt /100
                        ,l_cost_element_id
                        ,l_process_flag
                        ,g_mat_oh
                        ,g_created_by
                        ,g_last_update_login
                        ,g_last_updated_by
                        ,l_request_id--r_ins_disc_raw.request_id
                        ,g_rec_stat_p
                        ,r_ins_disc_raw.source_type
                        );
                        COMMIT;
                    END;
                END LOOP;

                FOR rec_ins_disc_bulk IN cur_ins_disc_bulk
                LOOP
                    BEGIN
                        INSERT
                        INTO xxnbty.xxnbty_cm_iccon_fl_stg
                        (as400_number
                        ,item_status
                        ,item_number
                        ,organization_code
                        ,ora_category
                        ,resource_cost
                        ,inventory_item_id
                        ,cost_type_id
                        ,organization_id
                        ,resource_id
                        ,usage_rate_or_amount
                        ,cost_element_id
                        ,process_flag
                        ,resource_code
                        ,created_by
                        ,last_update_login
                        ,last_updated_by
                        ,request_id
                        ,record_status
                        ,source_type
                        )
                        VALUES
                        (rec_ins_disc_bulk.as400_number
                        ,rec_ins_disc_bulk.item_status
                        ,rec_ins_disc_bulk.item_number
                        ,rec_ins_disc_bulk.organization_code
                        ,rec_ins_disc_bulk.ora_category
                        ,rec_ins_disc_bulk.resource_cost
                        ,rec_ins_disc_bulk.inventory_item_id
                        ,l_cost_type_id
                        ,rec_ins_disc_bulk.organization_id
                        ,rec_ins_disc_bulk.resource_id
                        ,rec_ins_disc_bulk.resource_cost
                        ,rec_ins_disc_bulk.cost_element_id
                        ,l_process_flag
                        ,g_con_res
                        ,g_created_by
                        ,g_last_update_login
                        ,g_last_updated_by
                        ,l_request_id
                        ,g_rec_stat_p
                        ,rec_ins_disc_bulk.source_type
                        );
                        COMMIT;
                    END;

                        BEGIN
                            SELECT resource_id
                            INTO l_resouce_id
                            FROM BOM_RESOURCES_V
                            WHERE organization_id = rec_ins_disc_bulk.organization_id
                            AND RESOURCE_CODE = g_res_oh;

                            EXCEPTION
                            WHEN NO_DATA_FOUND THEN
                              l_resouce_id := null;
                        END;

                        BEGIN
                            SELECT cost_element_id
                            INTO l_cost_element_id
                            FROM BOM_RESOURCES_V
                            WHERE organization_id = rec_ins_disc_bulk.organization_id
                            AND resource_id = l_resouce_id;

                            EXCEPTION
                            WHEN NO_DATA_FOUND THEN
                              l_cost_element_id := null;
                        END;

                    BEGIN
                        INSERT
                        INTO xxnbty.xxnbty_cm_iccon_fl_stg
                        (as400_number
                        ,item_status
                        ,item_number
                        ,organization_code
                        ,ora_category
                        ,resource_cost
                        ,overhead
                        ,res_cost_oh
                        ,inventory_item_id
                        ,cost_type_id
                        ,organization_id
                        ,resource_id
                        ,usage_rate_or_amount
                        ,cost_element_id
                        ,process_flag
                        ,resource_code
                        ,created_by
                        ,last_update_login
                        ,last_updated_by
                        ,request_id
                        ,record_status
                        ,source_type
                        )
                        VALUES
                        (rec_ins_disc_bulk.as400_number
                        ,rec_ins_disc_bulk.item_status
                        ,rec_ins_disc_bulk.item_number
                        ,rec_ins_disc_bulk.organization_code
                        ,rec_ins_disc_bulk.ora_category
                        ,rec_ins_disc_bulk.resource_cost
                        ,rec_ins_disc_bulk.overhead
                        ,rec_ins_disc_bulk.resource_cost * rec_ins_disc_bulk.overhead
                        ,rec_ins_disc_bulk.inventory_item_id
                        ,l_cost_type_id
                        ,rec_ins_disc_bulk.organization_id
                        ,l_resouce_id
                        ,rec_ins_disc_bulk.resource_cost * rec_ins_disc_bulk.overhead
                        ,l_cost_element_id
                        ,l_process_flag
                        ,g_res_oh
                        ,g_created_by
                        ,g_last_update_login
                        ,g_last_updated_by
                        ,l_request_id
                        ,g_rec_stat_p
                        ,rec_ins_disc_bulk.source_type
                        );
                        COMMIT;
                    END;
                END LOOP; --RES_OH

                FOR     r_ins_yield_res IN c_ins_yield_res
                LOOP
                    BEGIN
                        INSERT
                        INTO xxnbty.xxnbty_cm_iccon_fl_stg
                        (as400_number
                        ,item_status
                        ,item_number
                        ,organization_code
                        ,ora_category
                        ,yield_res_cost
                        ,inventory_item_id
                        ,cost_type_id
                        ,organization_id
                        ,resource_id
                        ,usage_rate_or_amount
                        ,cost_element_id
                        ,process_flag
                        ,resource_code
                        ,created_by
                        ,last_update_login
                        ,last_updated_by
                        ,request_id
                        ,record_status
                        ,source_type
                        )
                        VALUES
                        (r_ins_yield_res.as400_number
                        ,r_ins_yield_res.item_status
                        ,r_ins_yield_res.item_number
                        ,r_ins_yield_res.organization_code
                        ,r_ins_yield_res.ora_category
                        ,r_ins_yield_res.yield_res_cost
                        ,r_ins_yield_res.inventory_item_id
                        ,l_cost_type_id
                        ,r_ins_yield_res.organization_id
                        ,r_ins_yield_res.resource_id
                        ,r_ins_yield_res.yield_res_cost
                        ,r_ins_yield_res.cost_element_id
                        ,l_process_flag
                        ,g_yield_res
                        ,g_created_by
                        ,g_last_update_login
                        ,g_last_updated_by
                        ,l_request_id--r_ins_yield_res.request_id
                        ,g_rec_stat_p
                        ,r_ins_yield_res.source_type
                        );
                        COMMIT;
                    END;
                END LOOP; -- YIELD_RES_COST
 --           END IF;
  --      END LOOP; --AS400
    END;

    /*LOAD DATA TO INTERFACE TABLE*/
    BEGIN
        FOR r_ins_fl_int IN c_ins_fl_int
        LOOP
            BEGIN
                INSERT INTO cst_item_cst_dtls_interface
                (inventory_item_id
                ,organization_id
                ,cost_type_id
                ,resource_id
                ,usage_rate_or_amount
                ,cost_element_id
                ,process_flag
                ,Resource_code
                ,last_update_date
                ,last_updated_by
                ,creation_date
                ,created_by
                ,last_update_login
                )
                values
                (r_ins_fl_int.inventory_item_id
                ,r_ins_fl_int.organization_id
                ,r_ins_fl_int.cost_type_id
                ,r_ins_fl_int.resource_id
                ,r_ins_fl_int.usage_rate_or_amount
                ,r_ins_fl_int.cost_element_id
                ,r_ins_fl_int.process_flag
                ,r_ins_fl_int.resource_code
                ,SYSDATE
                ,g_last_updated_by
                ,SYSDATE
                ,g_created_by
                ,g_last_update_login
                );
                COMMIT;
            END;
        END LOOP;

    END;

    --Update STAGING record status value to "PROCESSED"
         UPDATE  xxnbty.xxnbty_cm_iccon_stg
            SET record_status = g_rec_stat_p
          WHERE record_status = g_rec_stat_v
          AND source_type = g_source_as
          AND request_id = l_request_id
          AND error_description IS NULL;
        COMMIT;

    --Update FINAL STAGING record status value to "IMPORTED"
         UPDATE  xxnbty.xxnbty_cm_iccon_fl_stg
            SET record_status = g_rec_stat_i
          WHERE record_status = g_rec_stat_p
          AND source_type = g_source_as
          AND request_id = l_request_id;
        COMMIT;

  /*CALL STANDARD PROGRAM IMPORT PROCESS*/
        call_import_process(x_retcode, x_errbuf);


    EXCEPTION
        WHEN OTHERS THEN
          l_mess := 'Error on ['||l_location||'] - SQLCODE [' ||SQLCODE|| '] - ' ||substr(SQLERRM,1,100);
          x_errbuf  := l_mess;
          x_retcode := 2;


END process_cm_records;

PROCEDURE copy_opm_to_cmstg ( x_errbuf      OUT VARCHAR2,
                              x_retcode     OUT VARCHAR2)
   IS
----------------------------------------------------------------------------------------------
/*
Procedure Name: copy_opm_to_cmstg
Author's Name: John Paul Aquino
Date written: 25-FEB-2016
RICEFW Object: CONV-01
Description:
Program Style:

Maintenance History:

Date            Issue#      Name                    Remarks
-----------     ------      -----------             ------------------------------------------------
25-FEB-2016                 John Paul Aquino        Initial Development
13-MAR-2016                 Khristine Austero       Added Table and filtering in getting data from OPM to DISCRETE
16-APR-2016                 Khristine Austero       Added condition and filtering in getting data from OPM Base Tables
*/
--------------------------------------------------------------------------------------------

   l_source_type      CONSTANT VARCHAR2(10)   := g_source_ebs;
   l_new_record       CONSTANT VARCHAR2(10)   := g_rec_stat_n;
   l_mess                     VARCHAR2(500);
   l_location                 VARCHAR2(100) := 'COPYING OPM TO CM STG';

  CURSOR c_get_opm_cost
  IS

  /*Changed for the ID not consistent*/
  /*
    SELECT DISTINCT ccm.cost_cmpntcls_code cost_cmpntcls_code
          , max(ccd.cmpnt_cost) cmpnt_cost
          , msi.segment1 segment1
          , mpa.organization_code organization_code
    FROM cm_cmpt_dtl ccd
        ,mtl_parameters mpa
        ,mtl_system_items msi
        ,gmf_period_statuses gps
        ,cm_cmpt_mst ccm
        --/*[TIN] 04/13/2016*
        ,mtl_item_categories_v micv
    WHERE mpa.organization_id = msi.organization_id
      AND ccm.cost_cmpntcls_id = ccd.cost_cmpntcls_id
      AND ccd.inventory_item_id = msi.inventory_item_id
      AND mpa.process_enabled_flag = 'N'
      AND mpa.organization_code NOT IN ('LEG', 'ZZZ')
      AND ccd.period_id = GPS.PERIOD_ID
 --     /*[TIN] 04/13/2016*
      AND ccd.inventory_item_id = micv.inventory_item_id
      AND micv.category_set_name='Process_Category'
      AND micv.segment1 LIKE '%_Bulk_%'
 --      /*[TIN] 04/13/2016*
      AND SYSDATE BETWEEN gps.start_date AND gps.end_date
      GROUP BY ccm.cost_cmpntcls_code , msi.segment1 ,mpa.organization_code;
      -- Added by Sanjay
*/

  SELECT cost_cmpntcls_code
      , SUM((NVL(max_cmpnt_cost,0) + NVL(min_cmpnt_cost,0))) AS cmpnt_cost
      , segment1
      , organization_code
  FROM (
        SELECT a.cost_cmpntcls_code
                , (CASE WHEN a.COST_LEVEL = 0 THEN
                  MAX(a.cmpnt_cost)
                END)AS max_cmpnt_cost
                ,(CASE WHEN a.COST_LEVEL = 1 THEN
                  MIN(a.cmpnt_cost)
                END)AS min_cmpnt_cost
                , a.segment1
                , a.organization_code
        FROM (
               SELECT DISTINCT ccm.cost_cmpntcls_code cost_cmpntcls_code
                      , ccd.cmpnt_cost cmpnt_cost
                      , msi.segment1 segment1
                      , mpa.organization_code organization_code
                      , ccd.cost_level cost_level
                FROM cm_cmpt_dtl ccd
                    ,mtl_parameters mpa
                    ,mtl_system_items msi
                    ,gmf_period_statuses gps
                    ,cm_cmpt_mst ccm
                    ,mtl_item_categories_v micv /*[TIN] 04/13/2016*/
                WHERE mpa.organization_id = msi.organization_id
                  AND ccm.cost_cmpntcls_id = ccd.cost_cmpntcls_id
                  AND ccd.inventory_item_id = msi.inventory_item_id
                  AND mpa.process_enabled_flag = 'N'
                  AND mpa.organization_code NOT IN ('LEG', 'ZZZ')
                  AND ccd.period_id = GPS.PERIOD_ID
                  /*[TIN] 04/13/2016*/
                  AND ccd.inventory_item_id = micv.inventory_item_id
                  AND micv.category_set_name = 'Process_Category'
                  AND micv.segment1 LIKE '%_Bulk_%'
                   /*[TIN] 04/13/2016*/
                  AND SYSDATE BETWEEN gps.start_date AND gps.end_date
                 -- GROUP BY ccm.cost_cmpntcls_code , msi.segment1 ,mpa.organization_code
               )a
        GROUP BY a.cost_cmpntcls_code, a.segment1, a.organization_code , a.cost_level
      )
      GROUP BY cost_cmpntcls_code, segment1, organization_code;  -- Added by Sanjay


BEGIN
        FOR r_get_opm_cost IN c_get_opm_cost
        LOOP
              IF r_get_opm_cost.cost_cmpntcls_code = g_mat_rmw--1 --RMW
              THEN
                    BEGIN
                          INSERT
                          INTO xxnbty.xxnbty_cm_iccon_stg
                          (ITEM_NUMBER
                          ,ORGANIZATION_CODE
                          ,MATERIAL_COST
                          ,SOURCE_TYPE
                          ,RECORD_STATUS
                          ,last_update_date
                          ,last_updated_by
                          ,creation_date
                          ,created_by
                          ,last_update_login
                          ,request_id
                          )
                          VALUES
                          (r_get_opm_cost.segment1
                          ,r_get_opm_cost.organization_code
                          ,r_get_opm_cost.cmpnt_cost
                          ,l_source_type
                          ,l_new_record
                          ,SYSDATE
                          ,g_last_updated_by
                          ,SYSDATE
                          ,g_created_by
                          ,g_last_update_login
                          ,g_request_id
                          );
                          COMMIT;
                    END;
              ELSIF r_get_opm_cost.cost_cmpntcls_code = g_mat_oh--16 --MAT_OH
              THEN
                    BEGIN
                          INSERT
                          INTO xxnbty.xxnbty_cm_iccon_stg
                          (item_number
                          ,organization_code
                          ,mat_cost_oh
                          ,source_type
                          ,record_status
                          ,last_update_date
                          ,last_updated_by
                          ,creation_date
                          ,created_by
                          ,last_update_login
                          ,request_id
                          )
                          VALUES
                          (r_get_opm_cost.segment1
                          ,r_get_opm_cost.organization_code
                          ,r_get_opm_cost.cmpnt_cost
                          ,l_source_type
                          ,l_new_record
                          ,SYSDATE
                          ,g_last_updated_by
                          ,SYSDATE
                          ,g_created_by
                          ,g_last_update_login
                          ,g_request_id
                          );
                          COMMIT;
                    END;
              ELSIF r_get_opm_cost.cost_cmpntcls_code = g_res_cost--14 --RES_COST
              THEN
                    BEGIN
                          INSERT
                          INTO xxnbty.xxnbty_cm_iccon_stg
                          (item_number
                          ,organization_code
                          ,resource_cost
                          ,source_type
                          ,record_status
                          ,last_update_date
                          ,last_updated_by
                          ,creation_date
                          ,created_by
                          ,last_update_login
                          ,request_id
                          )
                          VALUES
                          (r_get_opm_cost.segment1
                          ,r_get_opm_cost.organization_code
                          ,r_get_opm_cost.cmpnt_cost
                          ,l_source_type
                          ,l_new_record
                          ,SYSDATE
                          ,g_last_updated_by
                          ,SYSDATE
                          ,g_created_by
                          ,g_last_update_login
                          ,g_request_id
                          );
                          COMMIT;
                    END;
              ELSIF r_get_opm_cost.cost_cmpntcls_code = g_res_oh--20 --RES_OH
              THEN
                    BEGIN
                          INSERT
                          INTO xxnbty.xxnbty_cm_iccon_stg
                          (item_number
                          ,organization_code
                          ,res_cost_oh
                          ,source_type
                          ,record_status
                          ,last_update_date
                          ,last_updated_by
                          ,creation_date
                          ,created_by
                          ,last_update_login
                          ,request_id
                          )
                          VALUES
                          (r_get_opm_cost.segment1
                          ,r_get_opm_cost.organization_code
                          ,r_get_opm_cost.cmpnt_cost
                          ,l_source_type
                          ,l_new_record
                          ,SYSDATE
                          ,g_last_updated_by
                          ,SYSDATE
                          ,g_created_by
                          ,g_last_update_login
                          ,g_request_id
                          );
                        COMMIT;
                    END;
              ELSIF r_get_opm_cost.cost_cmpntcls_code = g_yield_res --25 --YIELD_RES
              THEN
                    BEGIN
                          INSERT
                          INTO xxnbty.xxnbty_cm_iccon_stg
                          (item_number
                          ,organization_code
                          ,yield_res_cost
                          ,source_type
                          ,record_status
                          ,last_update_date
                          ,last_updated_by
                          ,creation_date
                          ,created_by
                          ,last_update_login
                          ,request_id
                          )
                          VALUES
                          (r_get_opm_cost.segment1
                          ,r_get_opm_cost.organization_code
                          ,r_get_opm_cost.cmpnt_cost
                          ,l_source_type
                          ,l_new_record
                          ,SYSDATE
                          ,g_last_updated_by
                          ,SYSDATE
                          ,g_created_by
                          ,g_last_update_login
                          ,g_request_id
                          );
                        COMMIT;
                    END;
              END IF;
        END LOOP;
    COMMIT;

    EXCEPTION
        WHEN OTHERS THEN
          l_mess := 'Error on ['||l_location||'] - SQLCODE [' ||SQLCODE|| '] - ' ||substr(SQLERRM,1,100);
          x_errbuf  := l_mess;
          x_retcode := 2;

   END copy_opm_to_cmstg;

PROCEDURE process_opm_to_cm ( x_errbuf      OUT VARCHAR2,
                              x_retcode     OUT VARCHAR2)
   IS
----------------------------------------------------------------------------------------------
/*
Procedure Name: process_opm_to_cm
Author's Name: John Paul Aquino
Date written: 25-FEB-2016
RICEFW Object: CONV-01
Description:
Program Style:

Maintenance History:

Date            Issue#      Name                    Remarks
-----------     ------      -----------             ------------------------------------------------
25-FEB-2016                 John Paul Aquino        Initial Development
*/
--------------------------------------------------------------------------------------------


  l_cost_type_id                   cst_item_cst_dtls_interface.cost_type_id%TYPE := 3;
  l_cost_element_id                cst_item_cst_dtls_interface.cost_element_id%TYPE;
  l_process_flag                   cst_item_cst_dtls_interface.process_flag%TYPE := 1;
  l_mess                           VARCHAR2(500);
  l_location                       VARCHAR2(100) := 'PROCESSING OPM TO CM';

 /*ITEM*/
CURSOR c_ins_opmcm_rmw_fl
IS
    SELECT xcis.*
          ,mpa.organization_id
          ,msi.inventory_item_id
          ,brv.resource_id
          ,brv.cost_element_id
          ,brv.resource_code
    FROM xxnbty.xxnbty_cm_iccon_stg xcis
          ,mtl_parameters mpa
          ,mtl_system_items msi
          ,bom_resources_v brv
    WHERE xcis.record_status = g_rec_stat_v
    AND mpa.organization_code = xcis.organization_code
    AND mpa.organization_id = msi.organization_id
    AND msi.segment1 = xcis.item_number
    AND brv.organization_id = msi.organization_id
    AND brv.resource_code = g_item--'Item'
    AND xcis.source_type = g_source_ebs
    AND xcis.material_cost IS NOT NULL;

/*mat overhead*/
CURSOR c_ins_opmcm_matoh_fl
IS
    SELECT xcis.*
          ,mpa.organization_id
          ,msi.inventory_item_id
          ,brv.resource_id
          ,brv.cost_element_id
          ,brv.resource_code
    FROM xxnbty.xxnbty_cm_iccon_stg xcis
          ,mtl_parameters mpa
          ,mtl_system_items msi
          ,bom_resources_v brv
    WHERE xcis.record_status = g_rec_stat_v
    AND mpa.organization_code = xcis.organization_code
    AND mpa.organization_id = msi.organization_id
    AND msi.segment1 = xcis.item_number
    AND brv.organization_id = msi.organization_id
    AND brv.resource_code = g_mat_oh --'MAT_OH'
    AND xcis.source_type = g_source_ebs
    AND xcis.mat_cost_oh IS NOT NULL;

/*resource cost*/
CURSOR c_ins_opmcm_res_fl --cursor ng
IS
    SELECT xcis.*
          ,mpa.organization_id
          ,msi.inventory_item_id
          ,brv.resource_id
          ,brv.cost_element_id
          ,brv.resource_code
    FROM xxnbty.xxnbty_cm_iccon_stg xcis
          ,mtl_parameters mpa
          ,mtl_system_items msi
          ,bom_resources_v brv
    WHERE xcis.record_status = g_rec_stat_v
    AND mpa.organization_code = xcis.organization_code
    AND mpa.organization_id = msi.organization_id
    AND msi.segment1 = xcis.item_number
    AND brv.organization_id = msi.organization_id
    AND brv.resource_code = g_con_res--'CON_RES1'
    AND xcis.source_type = g_source_ebs
    AND xcis.resource_cost IS NOT NULL;

/*resource overhead*/
CURSOR c_ins_opmcm_resoh_fl
IS
    SELECT xcis.*
          ,mpa.organization_id
          ,msi.inventory_item_id
          ,brv.resource_id
          ,brv.cost_element_id
          ,brv.resource_code
    FROM xxnbty.xxnbty_cm_iccon_stg xcis
          ,mtl_parameters mpa
          ,mtl_system_items msi
          ,bom_resources_v brv
    WHERE xcis.record_status = g_rec_stat_v
    AND mpa.organization_code = xcis.organization_code
    AND mpa.organization_id = msi.organization_id
    AND msi.segment1 = xcis.item_number
    AND brv.organization_id = msi.organization_id
    AND brv.resource_code = g_res_oh--'RES_OH'
    AND xcis.source_type = g_source_ebs
    AND xcis.res_cost_oh IS NOT NULL;
/*yield resource*/
CURSOR c_ins_opmcm_yield_fl
IS
    SELECT xcis.*
          ,mpa.organization_id
          ,msi.inventory_item_id
          ,brv.resource_id
          ,brv.cost_element_id
          ,brv.resource_code
    FROM xxnbty.xxnbty_cm_iccon_stg xcis
          ,mtl_parameters mpa
          ,mtl_system_items msi
          ,bom_resources_v brv
    WHERE xcis.record_status = g_rec_stat_v
    AND mpa.organization_code = xcis.organization_code
    AND mpa.organization_id = msi.organization_id
    AND msi.segment1 = xcis.item_number
    AND brv.organization_id = msi.organization_id
    AND brv.resource_code = g_yield_res--'YIELD_RES1'
    AND xcis.source_type = g_source_ebs
    AND xcis.yield_res_cost IS NOT NULL;

CURSOR c_ins_opm_cm_fl_int
IS
    SELECT inventory_item_id
          ,organization_id
          ,cost_type_id
          ,resource_id
          ,usage_rate_or_amount
          ,cost_element_id
          ,process_flag
          ,resource_code
    FROM xxnbty.xxnbty_cm_iccon_fl_stg
    WHERE record_status = g_rec_stat_v
    AND source_type = g_source_ebs;

BEGIN
    FOR r_ins_opmcm_rmw_fl IN c_ins_opmcm_rmw_fl
    LOOP
        BEGIN
            INSERT
            INTO xxnbty.xxnbty_cm_iccon_fl_stg
            (item_number
            ,organization_code
            ,material_cost
            ,inventory_item_id
            ,cost_type_id
            ,organization_id
            ,resource_id
            ,usage_rate_or_amount
            ,cost_element_id
            ,process_flag
            ,resource_code
            ,created_by
            ,last_update_login
            ,last_updated_by
            ,request_id
            ,record_status
            ,source_type
            )
            VALUES
            (r_ins_opmcm_rmw_fl.item_number
            ,r_ins_opmcm_rmw_fl.organization_code
            ,r_ins_opmcm_rmw_fl.material_cost
            ,r_ins_opmcm_rmw_fl.inventory_item_id
            ,l_cost_type_id
            ,r_ins_opmcm_rmw_fl.organization_id
            ,r_ins_opmcm_rmw_fl.resource_id
            ,r_ins_opmcm_rmw_fl.material_cost
            ,r_ins_opmcm_rmw_fl.cost_element_id
            ,l_process_flag
            ,r_ins_opmcm_rmw_fl.resource_code
            ,g_created_by
            ,g_last_update_login
            ,g_last_updated_by
            ,g_request_id
            ,r_ins_opmcm_rmw_fl.record_status
            ,r_ins_opmcm_rmw_fl.source_type
            );
            COMMIT;
        END;
    END LOOP;

    BEGIN
        FOR r_ins_opmcm_matoh_fl IN c_ins_opmcm_matoh_fl
        LOOP
            BEGIN
                INSERT
                INTO xxnbty.xxnbty_cm_iccon_fl_stg
                (item_number
                ,organization_code
                ,mat_cost_oh
                ,inventory_item_id
                ,cost_type_id
                ,organization_id
                ,resource_id
                ,usage_rate_or_amount
                ,cost_element_id
                ,process_flag
                ,resource_code
                ,created_by
                ,last_update_login
                ,last_updated_by
                ,request_id
                ,record_status
                ,source_type
                )
                VALUES
                (r_ins_opmcm_matoh_fl.item_number
                ,r_ins_opmcm_matoh_fl.organization_code
                ,r_ins_opmcm_matoh_fl.mat_cost_oh
                ,r_ins_opmcm_matoh_fl.inventory_item_id
                ,l_cost_type_id
                ,r_ins_opmcm_matoh_fl.organization_id
                ,r_ins_opmcm_matoh_fl.resource_id
                ,r_ins_opmcm_matoh_fl.mat_cost_oh
                ,r_ins_opmcm_matoh_fl.cost_element_id
                ,l_process_flag
                ,r_ins_opmcm_matoh_fl.resource_code
                ,g_created_by
                ,g_last_update_login
                ,g_last_updated_by
                ,g_request_id
                ,r_ins_opmcm_matoh_fl.record_status
                ,r_ins_opmcm_matoh_fl.source_type
                );
                COMMIT;
            END;
        END LOOP;
    END;

    BEGIN
        FOR r_ins_opmcm_res_fl IN c_ins_opmcm_res_fl
        LOOP
            BEGIN
                INSERT
                INTO xxnbty.xxnbty_cm_iccon_fl_stg
                (item_number
                ,organization_code
                ,resource_cost
                ,inventory_item_id
                ,cost_type_id
                ,organization_id
                ,resource_id
                ,usage_rate_or_amount
                ,cost_element_id
                ,process_flag
                ,resource_code
                ,created_by
                ,last_update_login
                ,last_updated_by
                ,request_id
                ,record_status
                ,source_type
                )
                VALUES
                (r_ins_opmcm_res_fl.item_number
                ,r_ins_opmcm_res_fl.organization_code
                ,r_ins_opmcm_res_fl.resource_cost
                ,r_ins_opmcm_res_fl.inventory_item_id
                ,l_cost_type_id
                ,r_ins_opmcm_res_fl.organization_id
                ,r_ins_opmcm_res_fl.resource_id
                ,r_ins_opmcm_res_fl.resource_cost
                ,r_ins_opmcm_res_fl.cost_element_id
                ,l_process_flag
                ,r_ins_opmcm_res_fl.resource_code
                ,g_created_by
                ,g_last_update_login
                ,g_last_updated_by
                ,g_request_id
                ,r_ins_opmcm_res_fl.record_status
                ,r_ins_opmcm_res_fl.source_type
                );
              COMMIT;
            END;
        END LOOP;
    END;

    BEGIN
        FOR r_ins_opmcm_resoh_fl IN c_ins_opmcm_resoh_fl
        LOOP
            BEGIN
                INSERT
                INTO xxnbty.xxnbty_cm_iccon_fl_stg
                (item_number
                ,organization_code
                ,res_cost_oh
                ,inventory_item_id
                ,cost_type_id
                ,organization_id
                ,resource_id
                ,usage_rate_or_amount
                ,cost_element_id
                ,process_flag
                ,resource_code
                ,created_by
                ,last_update_login
                ,last_updated_by
                ,request_id
                ,record_status
                ,source_type
                )
                VALUES
                (r_ins_opmcm_resoh_fl.item_number
                ,r_ins_opmcm_resoh_fl.organization_code
                ,r_ins_opmcm_resoh_fl.res_cost_oh
                ,r_ins_opmcm_resoh_fl.inventory_item_id
                ,l_cost_type_id
                ,r_ins_opmcm_resoh_fl.organization_id
                ,r_ins_opmcm_resoh_fl.resource_id
                ,r_ins_opmcm_resoh_fl.res_cost_oh
                ,r_ins_opmcm_resoh_fl.cost_element_id
                ,l_process_flag
                ,r_ins_opmcm_resoh_fl.resource_code
                ,g_created_by
                ,g_last_update_login
                ,g_last_updated_by
                ,g_request_id
                ,r_ins_opmcm_resoh_fl.record_status
                ,r_ins_opmcm_resoh_fl.source_type
                );
               COMMIT;
            END;
        END LOOP;
    END;
    BEGIN
        FOR r_ins_opmcm_yield_fl IN c_ins_opmcm_yield_fl
        LOOP
            BEGIN
                INSERT
                INTO xxnbty.xxnbty_cm_iccon_fl_stg
                (item_number
                ,organization_code
                ,yield_res_cost
                ,inventory_item_id
                ,cost_type_id
                ,organization_id
                ,resource_id
                ,usage_rate_or_amount
                ,cost_element_id
                ,process_flag
                ,resource_code
                ,created_by
                ,last_update_login
                ,last_updated_by
                ,request_id
                ,record_status
                ,source_type
                )
                VALUES
                (r_ins_opmcm_yield_fl.item_number
                ,r_ins_opmcm_yield_fl.organization_code
                ,r_ins_opmcm_yield_fl.yield_res_cost
                ,r_ins_opmcm_yield_fl.inventory_item_id
                ,l_cost_type_id
                ,r_ins_opmcm_yield_fl.organization_id
                ,r_ins_opmcm_yield_fl.resource_id
                ,r_ins_opmcm_yield_fl.yield_res_cost
                ,r_ins_opmcm_yield_fl.cost_element_id
                ,l_process_flag
                ,r_ins_opmcm_yield_fl.resource_code
                ,g_created_by
                ,g_last_update_login
                ,g_last_updated_by
                ,g_request_id
                ,r_ins_opmcm_yield_fl.record_status
                ,r_ins_opmcm_yield_fl.source_type
                );
               COMMIT;
            END;
        END LOOP;
    END;

    BEGIN
        FOR r_ins_opm_cm_fl_int IN c_ins_opm_cm_fl_int
        LOOP

            BEGIN
                INSERT INTO cst_item_cst_dtls_interface
                (inventory_item_id
                 ,organization_id
                 ,cost_type_id
                 ,resource_id
                 ,usage_rate_or_amount
                 ,cost_element_id
                 ,process_flag
                 ,resource_code
                 ,last_update_date
                 ,last_updated_by
                 ,creation_date
                 ,created_by
                 ,last_update_login
                 )
                VALUES
                (r_ins_opm_cm_fl_int.inventory_item_id
                ,r_ins_opm_cm_fl_int.organization_id
                ,r_ins_opm_cm_fl_int.cost_type_id
                ,r_ins_opm_cm_fl_int.resource_id
                ,r_ins_opm_cm_fl_int.usage_rate_or_amount
                ,r_ins_opm_cm_fl_int.cost_element_id
                ,r_ins_opm_cm_fl_int.process_flag
                ,r_ins_opm_cm_fl_int.resource_code
                ,SYSDATE
                ,g_last_updated_by
                ,SYSDATE
                ,g_created_by
                ,g_last_update_login
                );
              COMMIT;
            END;
        END LOOP;

    END;

        /*CALL IMPORT PROCESS*/
        call_import_process(x_retcode, x_errbuf);

        EXCEPTION
        WHEN OTHERS THEN
          l_mess := 'Error on ['||l_location||'] - SQLCODE [' ||SQLCODE|| '] - ' ||substr(SQLERRM,1,100);
          x_errbuf  := l_mess;
          x_retcode := 2;


   END process_opm_to_cm;

PROCEDURE copy_cm_to_opmstg ( x_errbuf        OUT VARCHAR2,
                              x_retcode       OUT VARCHAR2,
                              p_request_id    IN VARCHAR2
                            )
  IS

----------------------------------------------------------------------------------------------
/*
Procedure Name: copy_cm_to_opmstg
Author's Name: John Paul Aquino
Date written: 25-FEB-2016
RICEFW Object: CONV-01
Description:
Program Style:

Maintenance History:

Date            Issue#      Name                    Remarks
-----------     ------      -----------             ------------------------------------------------
25-FEB-2016                 John Paul Aquino        Initial Development
*/
--------------------------------------------------------------------------------------------

  l_source_type             CONSTANT VARCHAR2(10)   := g_source_ebs;
  l_new_record              CONSTANT VARCHAR2(10)   := g_rec_stat_n;
  l_mess                    VARCHAR2(500);
  l_location                VARCHAR2(100)           := 'COPYING CM TO OPM STG';
  l_request_id              NUMBER;


   CURSOR c_get_item_cost
   IS
/*
    SELECT cic.inventory_item_id
          ,cic.item_cost
          ,msi.segment1
          ,mpa.organization_code
          ,mpa.organization_id
    FROM cst_item_costs cic
        ,mtl_parameters mpa
        ,mtl_system_items msi
    WHERE mpa.organization_id = msi.organization_id
    AND cic.inventory_item_id = msi.inventory_item_id
    AND cic.item_cost <> 0
    AND mpa.process_enabled_flag = 'Y'
    AND msi.process_costing_enabled_flag = 'Y' --eto ung mga tatanggalin if gusto makita lahat ng records kahit invalid
    AND msi.recipe_enabled_flag = 'Y'
    AND cic.cost_type_id = 3;  -- 1 for freeze 3 for pending costs;[this should be pending]
*/
    SELECT --cic.inventory_item_id
           cic.item_cost
          ,msi.segment1
          --,mpa.organization_code
          --,mpa.organization_id
          --,cic.organization_id
    FROM cst_item_costs cic
        --,mtl_parameters mpa
        ,mtl_system_items msi
    WHERE --mpa.organization_id = msi.organization_id
          --AND
          cic.inventory_item_id = msi.inventory_item_id
          --AND cic.organization_id = mpa.organization_id
          --AND
          --AND msi.segment1 = '100018644'--for testing purpose--
         AND cic.item_cost >= 0
         AND cic.cost_type_id = 3
    -- Added By Sanjay
         AND (msi.inventory_item_id ,  msi.organization_id ) IN ( SELECT inventory_item_id , organization_id
                                                                  FROM mtl_item_categories_v
                                                                  WHERE category_set_name = 'Process_Category'
                                                                  AND category_concat_segs LIKE '%Discrete_%' );


    BEGIN

      l_request_id :=  p_request_id;
        FOR r_get_item_cost IN c_get_item_cost
        LOOP
            BEGIN
                INSERT
                    INTO xxnbty.xxnbty_opm_iccon_stg
                    (
                     ITEM_NUMBER
                    --,ORGANIZATION_CODE
                    --,ORGANIZATION_ID
                    ,FG_MTL_COST
                    ,SOURCE_TYPE
                    ,RECORD_STATUS
                    ,REQUEST_ID
                    ,CREATED_BY
                    ,CREATION_DATE
                    ,LAST_UPDATE_DATE
                    ,LAST_UPDATE_LOGIN
                    ,LAST_UPDATED_BY
                    )
                    VALUES
                    (r_get_item_cost.segment1
                    --,r_get_item_cost.organization_code
                    --,r_get_item_cost.organization_id
                    ,r_get_item_cost.item_cost
                    ,l_source_type
                    ,l_new_record
                    ,l_request_id
                    ,g_created_by
                    ,SYSDATE
                    ,SYSDATE
                    ,g_last_update_login
                    ,g_last_updated_by
                    );
                COMMIT;
            END;
        END LOOP;

        EXCEPTION
        WHEN OTHERS THEN
          l_mess := 'Error on ['||l_location||'] - SQLCODE [' ||SQLCODE|| '] - ' ||substr(SQLERRM,1,100);
          x_errbuf  := l_mess;
          x_retcode := 2;
    END copy_cm_to_opmstg;


PROCEDURE process_cm_to_opm ( x_errbuf      OUT VARCHAR2,
                              x_retcode     OUT VARCHAR2
                            )
IS
----------------------------------------------------------------------------------------------
/*
Procedure Name: process_cm_to_opm
Author's Name: John Paul Aquino
Date written: 25-FEB-2016
RICEFW Object: CONV-01
Description:
Program Style:

Maintenance History:

Date            Issue#      Name                    Remarks
-----------     ------      -----------             ------------------------------------------------
25-FEB-2016                 John Paul Aquino        Initial Development
*/
--------------------------------------------------------------------------------------------


     l_inventory_item_id          cm_cmpt_dtl.inventory_item_id%TYPE;
     l_calendar_code              cm_cldr_hdr_b.calendar_code%TYPE;
     l_period_code                cm_cldr_dtl.period_code%TYPE;
     l_cost_type_id               cm_cmpt_dtl.cost_type_id%TYPE;
     l_organization_id            cm_cmpt_dtl.organization_id%TYPE;
     l_cost_analysis_code         cm_cmpt_dtl.cost_analysis_code%TYPE := 'DIR';
     l_cmpntcost_id               NUMBER                              := NULL;
     l_cost_cmpntcls_id           NUMBER;
     l_burden_ind                 NUMBER                              := 0;
     l_delete_mark                NUMBER                              := 0;
     l_source_type               CONSTANT VARCHAR2(10)               := g_source_ebs;
     l_mess                       VARCHAR2(500);
     l_location                   VARCHAR2(100)                       := 'PROCESSING CM TO OPM';

     --API variables
     l_status                     VARCHAR2 (11);
     l_return_status              VARCHAR2 (11)                       := FND_API.g_ret_sts_success;
     l_count                      NUMBER   (10);
     l_record_count               NUMBER   (10)                       := 0;
     l_loop_cnt                   NUMBER   (10)                       := 0;
     l_dummy_cnt                  NUMBER   (10)                       := 0;
     l_msg_index_out              NUMBER;
     l_data                       VARCHAR2 (3000);
     l_header_rec                 GMF_ITEMCOST_PUB.HEADER_REC_TYPE;
     l_this_lvl_tbl               GMF_ITEMCOST_PUB.THIS_LEVEL_DTL_TBL_TYPE;
     l_lower_lvl_tbl              GMF_ITEMCOST_PUB.LOWER_LEVEL_DTL_TBL_TYPE;
     l_costcmpnt_ids              GMF_ITEMCOST_PUB.COSTCMPNT_IDS_TBL_TYPE;
--l_request_id NUMBER;
/*
CURSOR cur_ins_cmopm_fg_fl
IS

SELECT distinct xois.item_number
                ,xois.FG_MTL_COST
                ,xois.record_status
        ,xois.request_id
          ,msi.organization_id organization_id1
          ,mpa.organization_code organization_code1
          ,msi.inventory_item_id
          ,gps.calendar_code
          ,gps.cost_type_id
          ,gps.period_code
    FROM xxnbty.xxnbty_opm_iccon_stg xois
        ,mtl_parameters mpa
        ,mtl_system_items msi
        ,gmf_period_statuses gps
    WHERE
        xois.source_type = g_source_ebs
    and xois.FG_MTL_COST!=0
    and msi.organization_id = mpa.ORGANIZATION_ID
    AND msi.process_costing_enabled_flag='Y'
    AND msi.segment1 = xois.item_number
    AND xois.creation_date BETWEEN gps.start_date AND gps.end_date
    AND  ( EXISTS
          (SELECT CMPNT_COST
            FROM CM_CMPT_DTL q,
                  CM_CMPT_MST r
              where
               q.inventory_item_id=msi.inventory_item_id
           AND q.ORGANIZATION_ID = MSI.ORGANIZATION_ID
           AND q.cost_cmpntcls_id=r.cost_cmpntcls_id
           AND r.cost_cmpntcls_code='FG_MTL')
          OR
          NOT EXISTS
          (SELECT CMPNT_COST
            FROM CM_CMPT_DTL q
              where
               q.inventory_item_id=msi.inventory_item_id
           AND q.ORGANIZATION_ID = MSI.ORGANIZATION_ID)
        );

    */

   CURSOR c_ins_cmopm_fg_api
   IS
      SELECT *
      FROM xxnbty.xxnbty_opm_iccon_fl_stg
      WHERE source_type = g_source_ebs
      AND fg_mtl_cost IS NOT NULL;

    BEGIN

       SELECT ccm.cost_cmpntcls_id
       INTO l_cost_cmpntcls_id
       FROM cm_cmpt_mst ccm
       WHERE ccm.cost_cmpntcls_code = g_fg_mtl;

   /*
    FOR   rec_ins_cmopm_fg_fl IN cur_ins_cmopm_fg_fl
    LOOP
    */
        BEGIN
            INSERT
            INTO xxnbty.xxnbty_opm_iccon_fl_stg
            (
            item_number
            ,organization_code
            ,inventory_item_id
            ,calendar_code
            ,period_code
            ,cost_type_id
            ,organization_id
            --,cmpntcost_id
            ,cost_cmpntcls_id
            ,cost_analysis_code
            ,cmpnt_cost
            ,burden_ind
            ,delete_mark
            ,created_by
            ,last_update_login
            ,last_updated_by
            ,request_id
            ,record_status
            ,source_type
            ,fg_mtl_cost

            )

            SELECT DISTINCT
            xois.item_number
            ,mpa.organization_code organization_code1
            ,msi.inventory_item_id
            ,gps.calendar_code
            ,gps.period_code
            ,gps.cost_type_id
            ,msi.organization_id organization_id1
            --,l_cmpntcost_id
            ,l_cost_cmpntcls_id
            ,l_cost_analysis_code
            ,xois.fg_mtl_cost
            ,l_burden_ind
            ,l_delete_mark
            ,g_created_by
            ,g_last_update_login
            ,g_last_updated_by
            ,xois.request_id
            ,xois.record_status
            ,l_source_type
            ,xois.fg_mtl_cost
            FROM xxnbty.xxnbty_opm_iccon_stg xois
                ,mtl_parameters mpa
                ,mtl_system_items msi
                ,gmf_period_statuses gps
            WHERE
                xois.source_type = g_source_ebs
            AND xois.fg_mtl_cost!=0
            AND msi.organization_id = mpa.organization_id
            AND msi.process_costing_enabled_flag='Y'
            AND mpa.process_enabled_flag = 'Y'
            AND msi.segment1 = xois.item_number
      AND (SYSDATE >= gps.start_date AND SYSDATE < gps.end_date + 1)
      AND ((xois.creation_date >= gps.start_date AND  xois.creation_date < gps.end_date +1) AND xois.creation_date IS NOT NULL)
            --AND xois.creation_date BETWEEN gps.start_date AND gps.end_date
            AND  ( EXISTS
                  (SELECT cmpnt_cost
                   FROM cm_cmpt_dtl q,
                         cm_cmpt_mst r
                   WHERE
                       q.inventory_item_id=msi.inventory_item_id
                   AND q.organization_id = msi.organization_id
                   AND q.cost_cmpntcls_id=r.cost_cmpntcls_id
                   AND r.cost_cmpntcls_code='FG_MTL')
                  OR
                  NOT EXISTS
                  (SELECT cmpnt_cost
                   FROM cm_cmpt_dtl q
                   WHERE
                       q.inventory_item_id=msi.inventory_item_id
                   AND q.organization_id = msi.organization_id)
                )
            ;
        COMMIT;
        END;

    /*
    END LOOP;
    */
    UPDATE xxnbty.xxnbty_opm_iccon_fl_stg stg
    SET stg.cmpntcost_id = (
        SELECT cmpntcost_id
        FROM cm_cmpt_dtl ccd,
             gmf_period_statuses gps
        WHERE ccd.inventory_item_id = stg.inventory_item_id
            AND stg.period_code = gps.period_code
            AND ccd.cost_cmpntcls_id = l_cost_cmpntcls_id
            AND ccd.organization_id = stg.organization_id
            AND ccd.period_id = gps.period_id
            AND ccd.item_id is null
            AND ROWNUM = 1)
    WHERE EXISTS ( SELECT 1
                   FROM cm_cmpt_dtl ccd,
                    gmf_period_statuses gps
                WHERE ccd.inventory_item_id = stg.inventory_item_id
                AND stg.period_code = gps.period_code
                AND ccd.cost_cmpntcls_id = l_cost_cmpntcls_id
                AND ccd.organization_id = stg.organization_id
                AND ccd.period_id = gps.period_id
                   AND ccd.item_id is null
                   AND ROWNUM = 1);
    COMMIT;

    FOR r_ins_cmopm_fg_api IN c_ins_cmopm_fg_api
    LOOP
        IF r_ins_cmopm_fg_api.cmpntcost_id IS NULL THEN

            BEGIN
             FND_GLOBAL.APPS_INITIALIZE (user_id           => g_user_id,
                                         resp_id           => g_resp_id,
                                         resp_appl_id      => g_resp_appl_id
                                         );

                l_header_rec.calendar_code       := r_ins_cmopm_fg_api.calendar_code;
                l_header_rec.period_code         := r_ins_cmopm_fg_api.period_code;
                l_header_rec.cost_type_id        := r_ins_cmopm_fg_api.cost_type_id;
                l_header_rec.organization_id     := r_ins_cmopm_fg_api.organization_id;
                l_header_rec.item_number         := r_ins_cmopm_fg_api.item_number;
                l_header_rec.user_name           := g_user_name;

                l_this_lvl_tbl (1).cmpntcost_id          := r_ins_cmopm_fg_api.cmpntcost_id;--l_cmpntcost_id; -- for updating
                l_this_lvl_tbl (1).cost_cmpntcls_id      := l_cost_cmpntcls_id;  --req
                l_this_lvl_tbl (1).cost_analysis_code    := l_cost_analysis_code; --req
                l_this_lvl_tbl (1).cmpnt_cost            := r_ins_cmopm_fg_api.cmpnt_cost;
                l_this_lvl_tbl (1).burden_ind            := l_burden_ind;
                l_this_lvl_tbl (1).delete_mark           := l_delete_mark;

              printlog_pr('Start CREATE_ITEM_COST for ORG ' || r_ins_cmopm_fg_api.organization_id ||' Item number ' || r_ins_cmopm_fg_api.item_number );
                GMF_ITEMCOST_PUB.CREATE_ITEM_COST
                                                 (p_api_version              => 3.0,
                                                  p_init_msg_list            => FND_API.g_false,
                                                  p_commit                   => FND_API.g_false,
                                                  x_return_status            => l_status,
                                                  x_msg_count                => l_count,
                                                  x_msg_data                 => l_data,
                                                  p_header_rec               => l_header_rec,
                                                  p_this_level_dtl_tbl       => l_this_lvl_tbl,
                                                  p_lower_level_dtl_tbl      => l_lower_lvl_tbl,
                                                  x_costcmpnt_ids            => l_costcmpnt_ids
                                                 );
--              printlog_pr('Status:' || l_status);
--              printlog_pr('Debug:' || l_count);
/*
                IF l_status = 'S'
                THEN
                   COMMIT;
                   printlog_pr('SUCCESS!!');
                ELSE
                    IF l_count = 1
                       THEN
                          printlog_pr('Error 11111 ' || l_data);
                       ELSE
                          printlog_pr(   'status: '
                                                || l_status
                                                || ' Error Count '
                                                || l_count
                                               );

                          FOR I IN 1 .. l_count
                          LOOP
                             FND_MSG_PUB.GET (p_msg_index          => I,
                                              p_data               => l_data,
                                              p_encoded            => FND_API.g_false,
                                              p_msg_index_out      => l_msg_index_out
                                             );
                             printlog_pr('Error 2222: ' || SUBSTR (l_data, 1, 255));
                          END LOOP;
                    END IF;
                END IF;
                printlog_pr('END');
*/
            END;
            COMMIT;

        ELSE

            BEGIN
                FND_GLOBAL.APPS_INITIALIZE (user_id           => g_user_id,
                                            resp_id           => g_resp_id,
                                            resp_appl_id      => g_resp_appl_id
                                           );

                l_header_rec.calendar_code       := r_ins_cmopm_fg_api.calendar_code;
                l_header_rec.period_code         := r_ins_cmopm_fg_api.period_code;
                l_header_rec.cost_type_id        := r_ins_cmopm_fg_api.cost_type_id;
                l_header_rec.organization_id     := r_ins_cmopm_fg_api.organization_id;
                l_header_rec.item_number         := r_ins_cmopm_fg_api.item_number;
                l_header_rec.user_name           := g_user_name;

                l_this_lvl_tbl (1).cmpntcost_id          := r_ins_cmopm_fg_api.cmpntcost_id;--l_cmpntcost_id; -- for updating
                l_this_lvl_tbl (1).cost_cmpntcls_id      := l_cost_cmpntcls_id;  --req
                l_this_lvl_tbl (1).cost_analysis_code    := l_cost_analysis_code; --req
                l_this_lvl_tbl (1).cmpnt_cost            := r_ins_cmopm_fg_api.cmpnt_cost;
                l_this_lvl_tbl (1).burden_ind            := l_burden_ind;
                l_this_lvl_tbl (1).delete_mark           := l_delete_mark;

              printlog_pr('Start UPDATE_ITEM_COST for ORG ' || r_ins_cmopm_fg_api.organization_id ||' Item number ' || r_ins_cmopm_fg_api.item_number );
                GMF_ITEMCOST_PUB.UPDATE_ITEM_COST
                                                 (p_api_version              => 3.0,
                                                  p_init_msg_list            => FND_API.g_false,
                                                  p_commit                   => FND_API.g_false,
                                                  x_return_status            => l_status,
                                                  x_msg_count                => l_count,
                                                  x_msg_data                 => l_data,
                                                  p_header_rec               => l_header_rec,
                                                  p_this_level_dtl_tbl       => l_this_lvl_tbl,
                                                  p_lower_level_dtl_tbl      => l_lower_lvl_tbl
                                                 );
--              printlog_pr('Status:' || l_status);
--              printlog_pr('Debug:' || l_count);
/*
                IF l_status = 'S'
                THEN
                   COMMIT;
                   printlog_pr('SUCCESS!!');
                ELSE
                   IF l_count = 1
                   THEN
                      printlog_pr('Error 11111 ' || l_data);
                   ELSE
                      printlog_pr(   'status: '
                                            || l_status
                                            || ' Error Count '
                                            || l_count
                                           );

                      FOR I IN 1 .. l_count
                      LOOP
                         FND_MSG_PUB.GET (p_msg_index          => I,
                                          p_data               => l_data,
                                          p_encoded            => FND_API.g_false,
                                          p_msg_index_out      => l_msg_index_out
                                         );
                         printlog_pr('Error 2222: ' || SUBSTR (l_data, 1, 255));
                      END LOOP;
                   END IF;
                END IF;
                printlog_pr('END');
*/
            END;
        COMMIT;
        END IF;
    END LOOP;

    EXCEPTION
        WHEN OTHERS THEN
          l_mess := 'Error on ['||l_location||'] - SQLCODE [' ||SQLCODE|| '] - ' ||substr(SQLERRM,1,100);
          x_errbuf  := l_mess;
          x_retcode := 2;

  END;

PROCEDURE call_import_process ( x_errbuf    OUT VARCHAR2,
                                x_retcode   OUT VARCHAR2
                                )
  IS
----------------------------------------------------------------------------------------------
/*
Procedure Name: call_import_process
Author's Name: John Paul Aquino
Date written: 25-FEB-2016
RICEFW Object: CONV-01
Description:
Program Style:

Maintenance History:

Date            Issue#      Name                    Remarks
-----------     ------      -----------             ------------------------------------------------
25-FEB-2016                 John Paul Aquino        Initial Development
*/
--------------------------------------------------------------------------------------------
    l_responsibility_id     NUMBER := g_resp_id;
    l_application_id        NUMBER := g_resp_appl_id;
    l_user_id               NUMBER := g_user_id;
    l_request_id            NUMBER;
    l_mess                  VARCHAR2(500);
    l_location              VARCHAR2(100) := 'CALLING IMPORT PROCESS PROGRAM';

    BEGIN
      --
      --To set environment context.
      --
      apps.fnd_global.apps_initialize (l_user_id,l_responsibility_id,l_application_id);
      --
      --Submitting Concurrent Request
      --
            l_request_id := fnd_request.submit_request (
                             application   => 'BOM'
                            ,program       => 'CSTPCIMP'
                            ,description   => 'Cost Import Process'
                            ,start_time    => sysdate
                            ,sub_request   => FALSE
                            ,argument1     => '4'
                            ,argument2     => '2'
                            ,argument3     => '2'
                            ,argument4     => NULL
                            ,argument5     => NULL
                            ,argument6     => 'Pending'
                            ,argument7     => '2'
                            --4, 2, 2, , , Pending, 2
                            );
  --
            COMMIT;
  --
              IF l_request_id = 0
              THEN
                 printlog_pr('Concurrent request failed to submit');
              ELSE
                 printlog_pr('Successfully Submitted the Concurrent Request -Cost Import Process Request ID: ' || l_request_id);
              END IF;
  --
      EXCEPTION
        WHEN OTHERS THEN
          l_mess := 'Error on ['||l_location||'] - SQLCODE [' ||SQLCODE|| '] - ' ||substr(SQLERRM,1,100);
          x_errbuf  := l_mess;
          x_retcode := 2;

  END call_import_process;

PROCEDURE opm_main       (x_errbuf              OUT VARCHAR2,
                          x_retcode             OUT VARCHAR2,
                          p_filename            IN  VARCHAR2,
                          p_sourcedirectory     IN  VARCHAR2,
                          p_archive             IN  VARCHAR2
                          )
  IS
----------------------------------------------------------------------------------------------
/*
Procedure Name: opm_main
Author's Name: John Paul Aquino
Date written: 25-FEB-2016
RICEFW Object: CONV-01
Description:
Program Style:

Maintenance History:

Date            Issue#      Name                    Remarks
-----------     ------      -----------             ------------------------------------------------
25-FEB-2016                 John Paul Aquino        Initial Development
*/
--------------------------------------------------------------------------------------------
    v_step              NUMBER;
    l_mess              VARCHAR2(500);
    e_error             EXCEPTION;
    l_numbering         NUMBER:= 0;
    l_count_rec         NUMBER;
    l_count_vrec        NUMBER;
    l_count_erec        NUMBER;
    l_request_id        NUMBER;
    l_return            BOOLEAN;
    l_filename          VARCHAR2(250);
    l_sourcedirectory   VARCHAR2(250);
    l_archive           VARCHAR2(250);
    l_dev_status        VARCHAR2(50);
    l_dev_phase         VARCHAR2(50);
    l_phase             VARCHAR2(50);
    l_status            VARCHAR2(50);
    l_message           VARCHAR2(500);


     CURSOR c_get_opm_error
     IS
        SELECT *
        FROM xxnbty.xxnbty_opm_iccon_stg
        WHERE record_status = g_rec_stat_e
        AND source_type = g_source_as
        AND request_id = l_request_id;


  BEGIN

   -- /*DELETE ALL DATA FROM THE OPM STAGING TABLES*/ --
   DELETE FROM xxnbty.xxnbty_opm_iccon_stg;
   COMMIT;
   DELETE FROM xxnbty.xxnbty_opm_iccon_fl_stg;
   COMMIT;
   -- /*DELETE ALL DATA FROM THE CM STAGING TABLES*/ --
   DELETE FROM xxnbty.xxnbty_cm_iccon_stg;
   COMMIT;
   DELETE FROM xxnbty.xxnbty_cm_iccon_fl_stg;
   COMMIT;
   /*---------------------------------------------------*/

    -- cAPTURE THE DIRECTORY PATH FROM ALL_DIRECTORIES--
  /*
       SELECT DIRECTORY_PATH
       INTO l_sourcedirectory
       FROM ALL_DIRECTORIES
       WHERE DIRECTORY_NAME = 'XXNBTY_CONV_DIR';
     */
        /*OPM SQLOADER*/
    l_filename              := p_filename;
    l_sourcedirectory       := p_sourcedirectory;
    l_archive               := p_archive;

        l_request_id:= FND_REQUEST.SUBMIT_REQUEST
        (   application   =>  'XXNBTY'
           ,program       =>  'XXNBTY_OPM_PROC_IC_SQLLOAD'
           ,description   =>  'XXNBTY Load OPM PROCESS Cost Data'
           ,start_time    =>  TO_CHAR(SYSDATE,'DD-MON-YY HH24:MI:SS')
           ,sub_request   =>  NULL
           ,argument1     =>  l_filename
           ,argument2     =>  l_sourcedirectory  --directory path
           ,argument3     =>  l_archive
       );

       COMMIT;

       IF l_request_id > 0 THEN
          LOOP
             l_return := fnd_concurrent.wait_for_request
                 ( request_id  => l_request_id
                  ,interval    => 1
                  ,max_wait    => 1
                  ,phase       => l_phase
                  ,status      => l_status
                  ,dev_phase   => l_dev_phase
                  ,dev_status  => l_dev_status
                  ,message     => l_message );
             EXIT WHEN (UPPER(l_dev_status) = 'NORMAL' AND UPPER(l_dev_phase) = 'COMPLETE')
                    OR (UPPER(l_dev_status) IN ('WARNING', 'ERROR') ) ;
          END LOOP;
    /* ======================================================================
     *                     UPDATE REQUEST_ID  COLUMN
     * ======================================================================
   */

        UPDATE xxnbty.xxnbty_opm_iccon_stg
            SET   request_id             = l_request_id
                , last_update_date       = SYSDATE
                , last_updated_by        = g_last_updated_by
                , creation_date          = SYSDATE
                , created_by             = g_created_by
                , last_update_login      = g_last_update_login
            WHERE record_status          = g_rec_stat_n
            AND error_description IS NULL;

            COMMIT;

       END IF;

      l_filename := REPLACE(l_filename, '.csv','');

        IF l_dev_status = 'NORMAL' AND l_dev_phase = 'COMPLETE' THEN
--*/
          v_step := 1;
            printlog_pr('VALIDATE OPM RECORDS FROM THE STAGING TABLE');
            /*CALL PROCEDURE TO VALIDATE DATA FROM STAGING TABLE*/
            validate_opm_rec(x_retcode, x_errbuf);

            IF x_retcode = 2 THEN
                RAISE e_error;
            ELSE

                SELECT COUNT(1)
                INTO l_count_rec
                FROM xxnbty.xxnbty_opm_iccon_stg
                WHERE source_type = g_source_as
                AND request_id = l_request_id;

                SELECT COUNT(1)
                INTO l_count_vrec
                FROM xxnbty.xxnbty_opm_iccon_stg
                WHERE record_status = g_rec_stat_v
                AND source_type = g_source_as
                AND request_id = l_request_id;


                SELECT COUNT(1)
                INTO l_count_erec
                FROM xxnbty.xxnbty_opm_iccon_stg
                WHERE record_status = g_rec_stat_e
                AND source_type = g_source_as
                AND request_id = l_request_id;

                printoutput_pr ('--------------------------------------------------------------------------');
                printoutput_pr ('-----------------OPM RECORDS STAGING VALIDATION SUMMARY-------------------');
                printoutput_pr ('--------------------------------------------------------------------------');
                printoutput_pr ('REQUEST ID                                   : ' || g_request_id);
                printoutput_pr ('--------------------------------------------------------------------------');
                printoutput_pr ('Number of Records                            : ' || l_count_rec);
                printoutput_pr ('Number of Records VALIDATED                  : ' || l_count_vrec);
                printoutput_pr ('Number of Records with ERROR                 : ' || l_count_erec);
                printoutput_pr ('--------------------------------------------------------------------------');
                printoutput_pr ('--------------------------------------------------------------------------');
                printoutput_pr ('-------------------------RECORD ERROR DETAILS-----------------------------');
                printoutput_pr ('--------------------------------------------------------------------------');

                FOR r_get_opm_error IN c_get_opm_error
                LOOP
                  l_numbering := l_numbering + 1;
                  printoutput_pr ('(' || l_numbering || ') '|| r_get_opm_error.organization_code || '-' || r_get_opm_error.item_number || ' = ' || r_get_opm_error.error_description);
                END LOOP;
                printoutput_pr('--------------------------------------------------------------------------');

            END IF;

          v_step := 2;
            printlog_pr('INSERT VALID RECORDS FROM STAGING TO BASE TABLE USING API');

            /*CALL PROCEDURE TO INSERT VALID RECORDS FROM STAGING TO BASE TABLE USING API*/
            process_opm_records(x_retcode, x_errbuf);

            IF x_retcode = 2 THEN
                RAISE e_error;
            END IF;
--/*
        ELSIF l_dev_status = 'ERROR' AND l_dev_phase = 'COMPLETE' THEN

        printoutput_pr('File name Invalid or does not exist ( ' || l_filename || ' )- Enter a valid parameter and rerun the program.');
        x_retcode := 2;

        ELSE
         RAISE e_error;
       END IF;
--*/
     v_step := 3;

      EXCEPTION
      WHEN e_error THEN
            printlog_pr('Return errbuf [' || x_errbuf || ']' );
            x_retcode := x_retcode;
      WHEN OTHERS THEN
        x_retcode := 2;
        l_mess := 'At step ['||v_step||'] for procedure opm_main - SQLCODE [' ||SQLCODE|| '] - ' ||substr(SQLERRM,1,100);
        x_errbuf := l_mess;

  END opm_main;


 PROCEDURE cm_main    (x_errbuf                 OUT VARCHAR2,
                       x_retcode                OUT VARCHAR2,
                       p_filename               IN  VARCHAR2,
                       p_sourcedirectory        IN  VARCHAR2,
                       p_archive                IN  VARCHAR2
                       )
  IS
 ----------------------------------------------------------------------------------------------
/*
Procedure Name: cm_main
Author's Name: John Paul Aquino
Date written: 25-FEB-2016
RICEFW Object: CONV-01
Description:
Program Style:

Maintenance History:

Date            Issue#      Name                    Remarks
-----------     ------      -----------             ------------------------------------------------
25-FEB-2016                 John Paul Aquino        Initial Development
*/
--------------------------------------------------------------------------------------------
    v_step              NUMBER;
    l_mess              VARCHAR2(500);
    e_error             EXCEPTION;
    l_numbering         NUMBER:= 0;
    l_count_rec         NUMBER;
    l_count_vrec        NUMBER;
    l_count_erec        NUMBER;
    l_request_id        NUMBER;
    l_return            BOOLEAN;
    l_filename          VARCHAR2(250);
    l_sourcedirectory   VARCHAR2(250);
    l_archive           VARCHAR2(250);
    l_dev_status        VARCHAR2(50);
    l_dev_phase         VARCHAR2(50);
    l_phase             VARCHAR2(50);
    l_status            VARCHAR2(50);
    l_message           VARCHAR2(500);

CURSOR c_get_cm_error
IS
        SELECT *
        FROM xxnbty.xxnbty_cm_iccon_stg
        WHERE record_status = g_rec_stat_e
        AND source_type = g_source_as
        AND request_id = l_request_id;

  BEGIN
--  /*
    -- capture the directory path from all_directories--
       /*
     SELECT DIRECTORY_PATH
       INTO l_sourcedirectory
       FROM ALL_DIRECTORIES
       WHERE DIRECTORY_NAME = 'XXNBTY_CONV_DIR';
     */

    l_filename              := p_filename;
    l_sourcedirectory       := p_sourcedirectory;
    l_archive               := p_archive;
    --insert data using sqloader
       l_request_id:= FND_REQUEST.SUBMIT_REQUEST
       ( application     =>  'XXNBTY'
           ,program      =>  'XXNBTY_CM_DISC_IC_SQLLOAD'
           ,description  =>  'XXNBTY Load DISCRETE Cost Data'
           ,start_time   =>  TO_CHAR(SYSDATE,'DD-MON-YY HH24:MI:SS')
           ,sub_request  =>  NULL
           ,argument1    =>  l_filename
           ,argument2    =>  l_sourcedirectory  --directory path
           ,argument3    =>  l_archive
       );

       COMMIT;

       IF l_request_id > 0 THEN
          LOOP
             l_return := fnd_concurrent.wait_for_request
                 ( request_id  => l_request_id
                  ,interval    => 1
                  ,max_wait    => 1
                  ,phase       => l_phase
                  ,status      => l_status
                  ,dev_phase   => l_dev_phase
                  ,dev_status  => l_dev_status
                  ,message     => l_message );
             EXIT WHEN (UPPER(l_dev_status) = 'NORMAL' AND UPPER(l_dev_phase) = 'COMPLETE')
                    OR (UPPER(l_dev_status) IN ('WARNING', 'ERROR') ) ;
          END LOOP;
    /* ======================================================================
     *                     UPDATE REQUEST_ID  COLUMN
     * ======================================================================
   */

        UPDATE xxnbty.xxnbty_cm_iccon_stg
            SET   request_id               = l_request_id
                , last_update_date         = SYSDATE
                , last_updated_by          = g_last_updated_by
                , creation_date            = SYSDATE
                , created_by               = g_created_by
                , last_update_login        = g_last_update_login
            WHERE record_status            = g_rec_stat_n
            AND error_description IS NULL;

            COMMIT;

       END IF;

    l_filename := REPLACE(l_filename, '.csv','');

       IF l_dev_status = 'NORMAL' AND l_dev_phase = 'COMPLETE' THEN
-- */
         v_step := 1;
            printlog_pr('VALIDATE CM RECORDS FROM THE STAGING TABLE');
            /*CALL PROCEDURE TO VALIDATE DATA FROM STAGING TABLE*/
            validate_cm_rec(x_retcode, x_errbuf, l_request_id);

            IF x_retcode = 2 THEN
                RAISE e_error;
            ELSE

                SELECT COUNT(1)
                INTO l_count_rec
                FROM xxnbty.xxnbty_cm_iccon_stg
                WHERE source_type = g_source_as
                AND request_id = l_request_id;

                SELECT COUNT(1)
                INTO l_count_vrec
                FROM xxnbty.xxnbty_cm_iccon_stg
                WHERE record_status = g_rec_stat_v
                AND source_type = g_source_as
                AND request_id = l_request_id;


                SELECT COUNT(1)
                INTO l_count_erec
                FROM xxnbty.xxnbty_cm_iccon_stg
                WHERE record_status = g_rec_stat_e
                AND source_type = g_source_as
                AND request_id = l_request_id;

                printoutput_pr ('--------------------------------------------------------------------------');
                printoutput_pr ('----------------CM RECORDS STAGING SUMMARY-------------------');
                printoutput_pr ('--------------------------------------------------------------------------');
                printoutput_pr ('REQUEST ID                                   : ' || g_request_id);
                printoutput_pr ('--------------------------------------------------------------------------');
                printoutput_pr ('Number of Records                            : ' || l_count_rec);
                printoutput_pr ('Number of Records LOADED                     : ' || l_count_vrec);
                printoutput_pr ('Number of Records with ERROR                 : ' || l_count_erec);
                printoutput_pr ('--------------------------------------------------------------------------');
                printoutput_pr ('--------------------------------------------------------------------------');
                printoutput_pr ('-------------------------RECORD ERROR DETAILS-----------------------------');
                printoutput_pr ('--------------------------------------------------------------------------');

                FOR r_get_cm_error IN c_get_cm_error
                LOOP
                  l_numbering := l_numbering + 1;
                  printoutput_pr ('(' || l_numbering || ') '|| r_get_cm_error.organization_code || '-' || r_get_cm_error.item_number || ' = ' || r_get_cm_error.error_description);
                END LOOP;
                printoutput_pr('--------------------------------------------------------------------------');
            END IF;

          v_step := 2;
            printlog_pr('INSERT VALID RECORDS FROM STAGING TO BASE TABLE');

            /*CALL PROCEDURE TO INSERT VALID RECORDS FROM STAGING TO BASE TABLE*/
            process_cm_records(x_retcode, x_errbuf, l_request_id);

            IF x_retcode = 2 THEN
                RAISE e_error;
            END IF;
--/*
        ELSIF l_dev_status = 'ERROR' AND l_dev_phase = 'COMPLETE' THEN

        printoutput_pr('File name Invalid or does not exist ( ' || l_filename || ' )- Enter a valid parameter and rerun the program.');
        x_retcode := 2;

        ELSE
           RAISE e_error;
        END IF;
--*/
    v_step := 3;

    EXCEPTION
    WHEN e_error THEN
            printlog_pr('Return errbuf [' || x_errbuf || ']' );
            x_retcode := x_retcode;
    WHEN OTHERS THEN
        x_retcode := 2;
        l_mess := 'At step ['||v_step||'] for procedure cm_main - SQLCODE [' ||SQLCODE|| '] - ' ||substr(SQLERRM,1,100);
        x_errbuf := l_mess;

  END cm_main;


PROCEDURE opm_to_cm_main     (x_errbuf                 OUT VARCHAR2,
                              x_retcode                OUT VARCHAR2
                             )
  IS
 ----------------------------------------------------------------------------------------------
/*
Procedure Name: opm_to_cm_main
Author's Name: John Paul Aquino
Date written: 25-FEB-2016
RICEFW Object: CONV-01
Description:
Program Style:

Maintenance History:

Date            Issue#      Name                    Remarks
-----------     ------      -----------             ------------------------------------------------
25-FEB-2016                 John Paul Aquino        Initial Development
*/
--------------------------------------------------------------------------------------------
    v_step          NUMBER;
    l_mess          VARCHAR2(500);
    e_error         EXCEPTION;
    l_numbering     NUMBER:= 0;
    l_count_rec     NUMBER;
    l_count_vrec    NUMBER;
    l_count_erec    NUMBER;
    l_request_id    NUMBER;

     CURSOR c_get_opm_to_cm_error
     IS
        SELECT *
        FROM xxnbty.xxnbty_cm_iccon_stg
        WHERE record_status = g_rec_stat_e
        AND source_type = g_source_ebs--;
        AND request_id = g_request_id;

  BEGIN
  l_request_id := g_request_id;
  /*CLEAN UP DISCRETE STAGING TABLES*/
  DELETE FROM xxnbty.xxnbty_cm_iccon_stg
  WHERE source_type = g_source_ebs;
  COMMIT;

  DELETE FROM xxnbty.xxnbty_cm_iccon_fl_stg
  WHERE source_type = g_source_ebs;
  COMMIT;
  --------------------------------------

  v_step := 1;
    printlog_pr('COPY OPM RECORDS TO CM STG');
    /*CALL PROCEDURE TO COPY RECORDS FROM OPM TO CM STG*/
    copy_opm_to_cmstg(x_retcode, x_errbuf);

    IF x_retcode = 2 THEN
        RAISE e_error;
    END IF;

  v_step := 2;
    printlog_pr('VALIDATE COPIED OPM RECORDS IN THE CM STG');
    /*CALL PROCEDURE TO VALIDATE COPIED RECORDS*/
    validate_cm_rec(x_retcode, x_errbuf, l_request_id);

    IF x_retcode = 2 THEN
        RAISE e_error;
    END IF;

  v_step := 3;

    printlog_pr('INSERT VALID RECORDS FROM STAGING TO BASE TABLE');
    /*CALL PROCEDURE TO INSERT VALID RECORDS FROM STAGING TO BASE TABLE*/
    process_opm_to_cm(x_retcode, x_errbuf);

    IF x_retcode = 2 THEN
        RAISE e_error;
    ELSE

        SELECT COUNT(1)
        INTO l_count_rec
        FROM xxnbty.xxnbty_cm_iccon_stg
        WHERE source_type = g_source_ebs
        AND request_id = l_request_id;

        SELECT COUNT(1)
        INTO l_count_vrec
        FROM xxnbty.xxnbty_cm_iccon_stg
        WHERE record_status = g_rec_stat_v
        AND source_type = g_source_ebs
        AND request_id = l_request_id;


        SELECT COUNT(1)
        INTO l_count_erec
        FROM xxnbty.xxnbty_cm_iccon_stg
        WHERE record_status = g_rec_stat_e
        AND source_type = g_source_ebs
        AND request_id = l_request_id;

        printoutput_pr ('--------------------------------------------------------------------------');
        printoutput_pr ('------------------CM RECORDS STAGING VALIDATION SUMMARY-------------------');
        printoutput_pr ('--------------------------------------------------------------------------');
        printoutput_pr ('REQUEST ID                                   : ' || g_request_id);
        printoutput_pr ('--------------------------------------------------------------------------');
        printoutput_pr ('Number of Records                            : ' || l_count_rec);
        printoutput_pr ('Number of Records VALIDATED                  : ' || l_count_vrec);
        printoutput_pr ('Number of Records with ERROR                 : ' || l_count_erec);
        printoutput_pr ('--------------------------------------------------------------------------');
        printoutput_pr ('--------------------------------------------------------------------------');
        printoutput_pr ('-------------------------RECORD ERROR DETAILS-----------------------------');
        printoutput_pr ('--------------------------------------------------------------------------');
        FOR r_get_opm_to_cm_error IN c_get_opm_to_cm_error
        LOOP
          l_numbering := l_numbering + 1;
          printoutput_pr ('(' || l_numbering || ') '|| r_get_opm_to_cm_error.organization_code || '-' || r_get_opm_to_cm_error.item_number || ' = ' || r_get_opm_to_cm_error.error_description);
        END LOOP;
        printoutput_pr('--------------------------------------------------------------------------');
        printlog_pr('CHECK THE COST IMPORT PROGRAM');

    END IF;
  v_step := 4;

  EXCEPTION
  WHEN e_error THEN
        printlog_pr('Return errbuf [' || x_errbuf || ']' );
        x_retcode := x_retcode;
  WHEN OTHERS THEN
    x_retcode := 2;
    l_mess := 'At step ['||v_step||'] for procedure opm_to_cm_main - SQLCODE [' ||SQLCODE|| '] - ' ||substr(SQLERRM,1,100);
    x_errbuf := l_mess;

  END opm_to_cm_main;


PROCEDURE cm_to_opm_main     (x_errbuf                 OUT VARCHAR2,
                              x_retcode                OUT VARCHAR2
                             )
  IS
---------------------------------------------------------------------------------------------
/*
Procedure Name: cm_to_opm_main
Author's Name: John Paul Aquino
Date written: 25-FEB-2016
RICEFW Object: CONV-01
Description:
Program Style:

Maintenance History:

Date            Issue#      Name                    Remarks
-----------     ------      -----------             -----------------------------------------
25-FEB-2016                 John Paul Aquino        Initial Development
*/
---------------------------------------------------------------------------------------------
    v_step          NUMBER;
    l_mess          VARCHAR2(500);
    e_error         EXCEPTION;
    l_numbering     NUMBER:= 0;
    l_count_rec     NUMBER;
    l_count_vrec    NUMBER;
    l_count_erec    NUMBER;
    l_request_id    NUMBER;

     CURSOR c_get_cm_to_opm_error
     IS
        SELECT *
        FROM xxnbty.xxnbty_opm_iccon_stg
        WHERE record_status = g_rec_stat_e
        AND source_type = g_source_ebs
        AND request_id = g_request_id;


  BEGIN

  -- l_request_id := p_request_id;
  /*CLEAN UP STAGING TABLE*/
  DELETE FROM xxnbty.xxnbty_opm_iccon_stg
    WHERE source_type = g_source_ebs;
  COMMIT;

  DELETE FROM xxnbty.xxnbty_opm_iccon_fl_stg
    WHERE source_type = g_source_ebs;
  COMMIT;
  ------------------------------------------
  v_step := 1;
    printlog_pr('COPY CM RECORDS TO OPM STG');
    /*CALL PROCEDURE TO COPY RECORDS FROM CM TO OPM STG*/
    copy_cm_to_opmstg(x_retcode, x_errbuf,g_request_id);
    IF x_retcode = 2 THEN
        RAISE e_error;
    END IF;
  /* as per parth we don't need to do the validation for the processed OPM data
  v_step := 2;
    printlog_pr('VALIDATE COPIED OPM RECORDS IN THE CM STG');
    --call procedure to validate copied records
    validate_opm_rec(x_retcode, x_errbuf);
    IF x_retcode = 2 THEN
        RAISE e_error;
    END IF;
  */
  v_step := 3;
    printlog_pr('INSERT VALID RECORDS FROM STAGING TO BASE TABLE USING API');
    /*CALL PROCEDURE TO INSERT VALID RECORDS FROM STAGING TO BASE TABLE USING API*/
    process_cm_to_opm( x_retcode
                     , x_errbuf
                    );

    IF x_retcode = 2 THEN
        RAISE e_error;
    ELSE

        SELECT COUNT(1)
        INTO l_count_rec
        FROM xxnbty.xxnbty_opm_iccon_fl_stg
        WHERE source_type = g_source_ebs
        AND request_id = g_request_id;

        SELECT COUNT(1)
        INTO l_count_vrec
        FROM xxnbty.xxnbty_opm_iccon_fl_stg
        WHERE record_status = g_rec_stat_n
        AND source_type = g_source_ebs
        AND request_id = g_request_id;

        SELECT COUNT(1)
        INTO l_count_erec
        FROM xxnbty.xxnbty_opm_iccon_fl_stg
        WHERE record_status = g_rec_stat_e
        AND source_type = g_source_ebs
        AND request_id = g_request_id;

        printoutput_pr ('--------------------------------------------------------------------------');
        printoutput_pr ('------------------CM RECORDS STAGING VALIDATION SUMMARY-------------------');
        printoutput_pr ('--------------------------------------------------------------------------');
        printoutput_pr ('REQUEST ID                                   : ' || g_request_id);
        printoutput_pr ('--------------------------------------------------------------------------');
        printoutput_pr ('Number of Records                            : ' || l_count_rec);
        printoutput_pr ('Number of Records VALIDATED                  : ' || l_count_vrec);
        printoutput_pr ('Number of Records with ERROR                 : ' || l_count_erec);
        printoutput_pr ('--------------------------------------------------------------------------');
        printoutput_pr ('--------------------------------------------------------------------------');
        printoutput_pr ('-------------------------RECORD ERROR DETAILS-----------------------------');
        printoutput_pr ('--------------------------------------------------------------------------');

        FOR r_get_cm_to_opm_error IN c_get_cm_to_opm_error
        LOOP
          l_numbering := l_numbering + 1;
          printoutput_pr ('(' || l_numbering || ') '|| r_get_cm_to_opm_error.organization_code || '-' || r_get_cm_to_opm_error.item_number || ' = ' || r_get_cm_to_opm_error.error_description);
        END LOOP;
        printoutput_pr('--------------------------------------------------------------------------');
    END IF;

  v_step := 4;

  EXCEPTION
  WHEN e_error THEN
        printlog_pr('Return errbuf [' || x_errbuf || ']' );
        x_retcode := x_retcode;
  WHEN OTHERS THEN
    x_retcode := 2;
    l_mess := 'At step ['||v_step||'] for procedure cm_to_opm_main - SQLCODE [' ||SQLCODE|| '] - ' ||substr(SQLERRM,1,100);
    x_errbuf := l_mess;

  END cm_to_opm_main;

PROCEDURE cm_to_opm_by_element_main     (x_errbuf                 OUT VARCHAR2,
                                         x_retcode                OUT VARCHAR2,
                                         p_org                     IN VARCHAR2,
                                         p_item                    IN VARCHAR2
                                         )
  IS
---------------------------------------------------------------------------------------------
/*
Procedure Name: cm_to_opm_by_element_main
Author's Name: Khristine Austero
Date written: 2-MAY-2016
RICEFW Object: CONV-01
Description:
Program Style:

Maintenance History:

Date            Issue#      Name                    Remarks
-----------     ------      -----------             ------------------------------------------------
2-MAY-2016                 Khristine Austero        Initial Development
*/
---------------------------------------------------------------------------------------------
    v_step          NUMBER;
    l_mess          VARCHAR2(500);
    e_error         EXCEPTION;
    l_numbering     NUMBER:= 0;
    l_count_rec     NUMBER;
    l_count_vrec    NUMBER;
    l_count_erec    NUMBER;
    l_count_nrec     NUMBER;
    l_request_id    NUMBER;

     CURSOR c_get_cm_to_opm_error
     IS
        SELECT *
        FROM xxnbty.xxnbty_opm_iccon_stg
        WHERE record_status = g_rec_stat_e
        AND source_type = g_source_ebs
        AND request_id = g_request_id;


  BEGIN

  -- l_request_id := p_request_id;
  /*CLEAN UP STAGING TABLE*/
  DELETE FROM xxnbty.xxnbty_opm_iccon_stg
    WHERE source_type = g_source_ebs;
  COMMIT;

  DELETE FROM xxnbty.xxnbty_opm_iccon_fl_stg
    WHERE source_type = g_source_ebs;
  COMMIT;
  ------------------------------------------
  v_step := 1;
    printlog_pr('INSERT VALID RECORDS FROM STAGING TO BASE TABLE USING API');
    /*CALL PROCEDURE TO COPY RECORDS FROM CM TO OPM THEN INSERT VALID RECORDS FROM STAGING TO BASE TABLE USING API*/
    process_cm_to_opm_by_element(x_retcode, x_errbuf,p_org,p_item,g_request_id
                    );

    IF x_retcode = 2 THEN
        RAISE e_error;
    ELSE

        SELECT COUNT(1)
        INTO l_count_rec
        FROM xxnbty.xxnbty_opm_iccon_fl_stg
        WHERE source_type = g_source_ebs
        AND request_id = g_request_id;

        SELECT COUNT(1)
        INTO l_count_vrec
        FROM xxnbty.xxnbty_opm_iccon_fl_stg
        WHERE record_status = g_rec_stat_i
        AND source_type = g_source_ebs
        AND request_id = g_request_id;

        SELECT COUNT(1)
        INTO l_count_erec
        FROM xxnbty.xxnbty_opm_iccon_fl_stg
        WHERE record_status = g_rec_stat_e
        AND source_type = g_source_ebs
        AND request_id = g_request_id;

        SELECT COUNT(1)
        INTO l_count_nrec
        FROM xxnbty.xxnbty_opm_iccon_fl_stg
        WHERE record_status = g_rec_stat_n
        AND source_type = g_source_ebs
        AND request_id = g_request_id;

        printoutput_pr ('--------------------------------------------------------------------------');
        printoutput_pr ('-----------CM RECORDS BY ELEMENT STAGING VALIDATION SUMMARY---------------');
        printoutput_pr ('--------------------------------------------------------------------------');
        printoutput_pr ('REQUEST ID                                   : ' || g_request_id);
        printoutput_pr ('--------------------------------------------------------------------------');
        printoutput_pr ('Number of Records                            : ' || l_count_rec);
        printoutput_pr ('Number of Records IMPORTED                   : ' || l_count_vrec);
        printoutput_pr ('Number of Records with ERROR                 : ' || l_count_erec);
        printoutput_pr ('Number of Records with NOT PROCESSED         : ' || l_count_nrec);
        printoutput_pr ('--------------------------------------------------------------------------');
        printoutput_pr ('--------------------------------------------------------------------------');
        printoutput_pr ('-------------------------RECORD ERROR DETAILS-----------------------------');
        printoutput_pr ('--------------------------------------------------------------------------');

        FOR r_get_cm_to_opm_error IN c_get_cm_to_opm_error
        LOOP
          l_numbering := l_numbering + 1;
          printoutput_pr ('(' || l_numbering || ') '|| r_get_cm_to_opm_error.organization_code || '-' || r_get_cm_to_opm_error.item_number || ' = ' || r_get_cm_to_opm_error.error_description);
        END LOOP;
        printoutput_pr('--------------------------------------------------------------------------');
    END IF;

  v_step := 4;

  EXCEPTION
  WHEN e_error THEN
        printlog_pr('Return errbuf [' || x_errbuf || ']' );
        x_retcode := x_retcode;
  WHEN OTHERS THEN
    x_retcode := 2;
    l_mess := 'At step ['||v_step||'] for procedure cm_to_opm_by_element_main - SQLCODE [' ||SQLCODE|| '] - ' ||substr(SQLERRM,1,100);
    x_errbuf := l_mess;

  END cm_to_opm_by_element_main;

END XXNBTY_CONV01_ICOST_CONV_PKG;

/

show errors;
