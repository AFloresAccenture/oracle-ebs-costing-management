create or replace PACKAGE BODY       XXNBTY_INVREP02_YLD_USAGE_PKG 
 ---------------------------------------------------------------------------------------------
  /*
  Package Name  : XXNBTY_INVREP02_YLD_USAGE_PKG
  Author's Name: Albert John Flores
  Date written: 12-May-2016
  RICEFW Object: INT01
  Description: Package that will generate Yield and Mtl. Usage Variance Report in CSV file
  Program Style:
  Maintenance History:
  Date         Issue#  Name                         Remarks
  -----------  ------  -------------------      ------------------------------------------------
  12-May-2016          Albert John Flores       Initial Development
  02-Jun-2016          Khristine Austero        Change formula in getting the MTL Usage Variance Amount and Total Difference
                                                Get latest Batch ID based on last update date
  07-Jun-2016          Khristine Austero        Index 2 and 3 (wiwc) comment "ccd.cost_level = 0"
  14-Jun-2016          Khristine Austero        Add filtering opm sum(cost_level=1) and discrete sum(level_type=2)
                                                comment the filtering ccm.cost_cmpntcls_code IN ('RMW','MAT_OH') and cicd.cost_element IN ('Material','Material Overhead')
  27-Jun-2016          Khristine Austero        Batches with multiple values and different mmt.attribute1 should be summed up (yield qty  and the theoretical quantity)
  14-Jul-2016          Khristine Austero        [change request]Add GCC code combination and PRODUCING_ORG (mmt.attribute5) from MTL_MATERIAL_TRANSACTIONS
  15-Aug-2016          Khristine Austero        Update p_batch_comp filtering 
  03-Nov-2016          Khristine Austero        [PROD] Modified for discreet org cost validation 
  
  */
  ----------------------------------------------------------------------------------------------
 IS 
  PROCEDURE main_proc ( x_retcode       OUT VARCHAR2
                       ,x_errbuf        OUT VARCHAR2
                       ,p_date_from     IN  DATE
                       ,p_date_to       IN  DATE
                       ,p_batch_id      IN  VARCHAR2
                       ,p_trn_type      IN  VARCHAR2
                       ,p_item_num      IN  VARCHAR2
                       ,p_batch_comp   IN  VARCHAR2 )
  IS
    
        CURSOR c_gen_rep (p_date_from       DATE
                         ,p_date_to         DATE
                         ,p_batch_id        VARCHAR2
                         ,p_trn_type        VARCHAR2
                         ,p_item_num        VARCHAR2
                         ,p_batch_comp     VARCHAR2)
        IS
        WITH wiwc_sql AS
            (SELECT hou.name            AS OPERATING_UNIT ,
              ood.organization_code     AS ORGANIZATION_CODE,
              xep.name                  AS LEGAL_ENTITY ,
              mmt.transaction_date      AS TRANSACTION_DATE,
              mmt.transaction_reference AS TRANSACTION_REFERENCE,
              mmt.transaction_id        AS TRANSACTION_ID,
              mmt.transaction_type_id   AS TRANSACTION_TYPE_ID,
              mtt.transaction_type_name AS TRANSACTION_TYPE_NAME,
              mmt.subinventory_code     AS SUBINVENTORY_CODE,
              mmt.inventory_item_id     AS INVENTORY_ITEM_ID,
              msib.segment1             AS ITEM_NUMBER ,
              mmt.transaction_reference AS BATCH_ID_NUMBER ,
              msib.item_type            AS ITEM_TYPE,
              mmt.transaction_uom       AS TRANSACTION_UOM ,
              (
              CASE
                WHEN mtt.attribute4 = 'WIP COMP'
                THEN mmt.transaction_quantity
              END) AS TRANSACTION_QUANTITY ,
              -----------------Producing_Org
              (
              CASE
                WHEN mtt.attribute4 = 'WIP COMP'
                THEN mmt.attribute5
              END) AS PRODUCING_ORG
              ---------- Total Value
              ,
              (
              CASE
                WHEN mtt.attribute4 = 'WIP ISSUE'
                THEN (
                  CASE
                    WHEN gxeh.header_id IS NOT NULL
                    THEN
                      (SELECT SUM(gxel.base_amount)
                      FROM gmf_xla_extract_lines gxel
                      WHERE 1                   =1
                      AND gxel.journal_line_type= 'INV'
                      AND gxel.header_id        = gxeh.header_id
                      )
                    ELSE 0
                  END)
                WHEN mtt.ATTRIBUTE4 = 'WIP COMP'
                THEN (
                  (SELECT NVL(SUM(cmpnt_cost),0)
                  FROM
                    (SELECT DISTINCT mp_proc.organization_id ,
                      msi_proc.segment1 ,
                      ccd.inventory_item_id ,
                      ccd.cmpnt_cost ,
                      ccm.cost_cmpntcls_code ,
                      ccd.period_id
                    FROM CM_CMPT_DTL ccd,
                      CM_CMPT_MST ccm ,
                      mtl_system_items_b msi_proc,
                      mtl_parameters mp_proc
                    WHERE 1                   =1
                    AND ccd.inventory_item_id = msi_proc.inventory_item_id
                    AND ccd.organization_id   = msi_proc.organization_id
                    AND ccd.cost_cmpntcls_id  = ccm.cost_cmpntcls_id
                    AND ccd.organization_id   = mp_proc.organization_id
                    AND ccd.organization_id   = msi_proc.organization_id
                      --AND ccm.cost_cmpntcls_code   IN ('RMW','MAT_OH')
                    AND ccd.delete_mark = 0
                    AND ccd.cost_level  = 1
                    ) proc_cost
                  WHERE 1                         =1
                  AND proc_cost.period_id         = gps.period_id
                  AND mmt.TRANSACTION_DATE       >= gps.START_DATE
                  AND mmt.TRANSACTION_DATE        < gps.END_DATE + 1
                  AND proc_cost.inventory_item_id = msib.inventory_item_id
                  AND proc_cost.organization_id   = msib.organization_id
                  AND proc_cost.organization_id   = mp.organization_id
                  ) )
              END) AS TOTAL_VALUE
              -------
              --, 0 AS UNIT_COST
              ,
              mmt.reason_id       AS REASON_ID ,
              mtt.attribute1      AS REASON_CODE ,
              mmt.attribute1      AS LOT_NUMBER ,
              mmt.attribute2      AS BATCH_COMPLETE ,
              mmt.attribute3      AS BATCH_SIZE ,
              mtt.attribute4      AS ATTRIBUTE4 ,
              mmt.organization_id AS ORGANIZATION_ID
            FROM mtl_material_transactions mmt ,
              mtl_system_items_b msib ,
              mtl_transaction_types mtt ,
              hr_operating_units hou ,
              org_organization_definitions ood ,
              xle_entity_profiles xep ,
              mtl_parameters mp ,
              gmf_xla_extract_headers gxeh ,
              gmf_period_statuses gps ,
              (SELECT mmt_sub.TRANSACTION_REFERENCE AS TRANSACTION_REFERENCE
              FROM MTL_MATERIAL_TRANSACTIONS mmt_sub ,
                MTL_TRANSACTION_TYPES mtt_sub
              WHERE 1                                            =1
              AND mtt_sub.ATTRIBUTE4                             = 'BATCH COMP'
              AND mmt_sub.TRANSACTION_TYPE_ID                    = mtt_sub.TRANSACTION_TYPE_ID
              AND ((mmt_sub.TRANSACTION_DATE                    >= TO_DATE(p_date_from,'DD-MON-YY'))
              OR p_date_from                                   IS NULL)
              AND ((mmt_sub.TRANSACTION_DATE                     < (TO_DATE(p_date_to,'DD-MON-YY') + 1))
              OR p_date_to                                     IS NULL)
              --AND (NVL(mmt_sub.ATTRIBUTE2, 'NULL')               = DECODE(p_batch_comp,'N','NULL',p_batch_comp)
              --OR DECODE(p_batch_comp,'N','NULL',p_batch_comp) IS NULL)
              AND (p_batch_comp   IS NULL OR (p_batch_comp   IS NOT NULL  
                                              AND (NVL(mmt_sub.ATTRIBUTE2, 'NULL') = DECODE(p_batch_comp,'N','NULL',p_batch_comp))
                                              )
                )
              )AA
            WHERE 1                          =1
            AND mmt.transaction_reference   IN(AA.transaction_reference)
            AND mp.process_enabled_flag      = 'Y'
            AND ((gxeh.valuation_cost_type   = 'STD')
            OR gxeh.header_id               IS NULL)
            AND mtt.attribute4              IN ('WIP ISSUE','WIP COMP')
            AND mmt.transaction_reference   IS NOT NULL
            AND mmt.inventory_item_id        = msib.inventory_item_id
            AND hou.default_legal_context_id = ood.legal_entity
            AND mmt.organization_id          = ood.organization_id
            AND mmt.organization_id          = msib.organization_id
            AND ood.legal_entity             = xep.legal_entity_id
            AND mtt.transaction_type_id      = mmt.transaction_type_id
            AND mp.organization_id           = mmt.organization_id
            AND gxeh.transaction_id (+)      = mmt.transaction_id
            AND gxeh.organization_id (+)     = mmt.organization_id
            AND gxeh.inventory_item_id (+)   = mmt.inventory_item_id
              ----------------------------------------------------------------------
              -- PARAMETERS ---
            AND (P_BATCH_ID             IS NULL
            OR (P_BATCH_ID              IS NOT NULL
            AND mmt.transaction_reference = P_BATCH_ID))
            AND (mtt.attribute4           = P_TRN_TYPE
            OR P_TRN_TYPE               IS NULL)
            AND (msib.segment1            = P_ITEM_NUM
            OR P_ITEM_NUM               IS NULL)
            -------------
            UNION ALL
            -------------
            SELECT hou.name             AS OPERATING_UNIT ,
              ood.organization_code     AS ORGANIZATION_CODE ,
              xep.name                  AS LEGAL_ENTITY ,
              mmt.transaction_date      AS TRANSACTION_DATE,
              mmt.transaction_reference AS TRANSACTION_REFERENCE ,
              mmt.transaction_id        AS TRANSACTION_ID ,
              mmt.transaction_type_id   AS TRANSACTION_TYPE_ID ,
              mtt.transaction_type_name AS TRANSACTION_TYPE_NAME ,
              mmt.subinventory_code     AS SUBINVENTORY_CODE ,
              mmt.inventory_item_id     AS INVENTORY_ITEM_ID ,
              msib.segment1             AS ITEM_NUMBER ,
              mmt.transaction_reference AS BATCH_ID_NUMBER ,
              msib.item_type            AS ITEM_TYPE ,
              mmt.transaction_uom       AS TRANSACTION_UOM ,
              (
              CASE
                WHEN mtt.attribute4 = 'WIP COMP'
                THEN mmt.transaction_quantity
                  --ELSE 0
              END) AS TRANSACTION_QUANTITY ,
              -----------------Producing_Org
              (
              CASE
                WHEN mtt.ATTRIBUTE4 = 'WIP COMP'
                THEN mmt.Attribute5
                  --ELSE 0
              END) AS PRODUCING_ORG
              ---------- Total Value
              ,
              (
              CASE
                WHEN mtt.attribute4 = 'WIP ISSUE'
                THEN (mta.base_transaction_value)
                WHEN mtt.attribute4 = 'WIP COMP'
                THEN (
                  (SELECT NVL(SUM(item_cost),0)
                  FROM
                    (SELECT DISTINCT cicd.cost_element ,
                      cicd.Resource_code ,
                      cicd.usage_rate_or_amount ,
                      cicd.item_cost ,
                      msi_disc.segment1 ,
                      mp_disc.organization_code ,
                      cict.cost_type ,
                      msi_disc.inventory_item_id ,
                      mp_disc.organization_id
                    FROM cst_item_cost_details_v cicd,
                      mtl_system_items_b msi_disc,
                      mtl_parameters mp_disc,
                      cst_item_cost_type_v cict
                    WHERE 1                    =1
                    AND cicd.inventory_item_id = msi_disc.inventory_item_id
                    AND cicd.organization_id   = msi_disc.organization_id
                    AND cicd.organization_id   = mp_disc.organization_id
                    AND cicd.inventory_item_id = cict.inventory_item_id
                    AND cicd.organization_id   = cict.organization_id
                    --Modified for discreet org cost validation Khristine Austero 11/3/2016
                    AND UPPER(cict.cost_type)  = 'FROZEN' 
                    AND cicd.cost_type_id      = cict.cost_type_id
                    --AND   cicd.cost_element       IN ('Material','Material Overhead')
                    AND cicd.level_type = 2
                    ) disc_cost
                  WHERE 1                         =1
                  AND disc_cost.inventory_item_id = msib.inventory_item_id
                  AND disc_cost.organization_id   = msib.organization_id
                  AND disc_cost.organization_id   = mp.organization_id
                  ) )
              END) AS TOTAL_VALUE
              -------
              --, 0 AS UNIT_COST
              ,
              mmt.reason_id       AS REASON_ID,
              mtt.attribute1      AS REASON_CODE ,
              mmt.attribute1      AS LOT_NUMBER ,
              mmt.attribute2      AS BATCH_COMPLETE ,
              mmt.attribute3      AS BATCH_SIZE ,
              mtt.attribute4      AS ATTRIBUTE4,
              mmt.organization_id AS ORGANIZATION_ID
            FROM mtl_material_transactions mmt ,
              mtl_system_items_b msib ,
              mtl_transaction_accounts mta ,
              mtl_transaction_types mtt ,
              hr_operating_units hou ,
              org_organization_definitions ood ,
              xle_entity_profiles xep ,
              mtl_parameters mp ,
              (SELECT mmt_sub.transaction_reference AS TRANSACTION_REFERENCE
                --, mtt_sub.TRANSACTION_TYPE_ID AS TRANSACTION_TYPE_ID
              FROM mtl_material_transactions mmt_sub ,
                mtl_transaction_types mtt_sub
              WHERE 1                                            =1
              AND mtt_sub.attribute4                             = 'BATCH COMP'
              AND mmt_sub.transaction_type_id                    = mtt_sub.transaction_type_id
              AND ((mmt_sub.transaction_date                    >= TO_DATE(p_date_from,'DD-MON-YY'))
              OR p_date_from                                   IS NULL)
              AND ((mmt_sub.transaction_date                     < (TO_DATE(p_date_to,'DD-MON-YY') + 1))
              OR p_date_to                                     IS NULL)
              --AND (NVL(mmt_sub.ATTRIBUTE2, 'NULL')               = DECODE(p_batch_comp,'N','NULL',p_batch_comp)
              --OR DECODE(p_batch_comp,'N','NULL',p_batch_comp) IS NULL)
              AND (p_batch_comp   IS NULL OR (p_batch_comp   IS NOT NULL  
                                              AND (NVL(mmt_sub.ATTRIBUTE2, 'NULL') = DECODE(p_batch_comp,'N','NULL',p_batch_comp))
                                              )
                )
              )AA
              --------------------------------------------------------------------
              --------------------------------------------------------------------
            WHERE 1                        =1
            AND mmt.transaction_reference IN(AA.transaction_reference)
              --AND    mmt.transaction_type_id = AA.transaction_type_id
            AND mp.process_enabled_flag        = 'N'
            AND mtt.attribute4                IN ('WIP ISSUE','WIP COMP')
            AND mmt.transaction_id             = mta.transaction_id (+)
            AND mmt.inventory_item_id          = mta.inventory_item_id(+)
            AND mmt.organization_id            = mta.organization_id (+)
            AND (mta.accounting_line_type NOT IN ('2')
            OR mta.transaction_id             IS NULL)
            AND mmt.inventory_item_id          = msib.inventory_item_id
            AND hou.default_legal_context_id   = ood.legal_entity
            AND mmt.organization_id            = ood.organization_id
            AND mmt.organization_id            = msib.organization_id
            AND ood.legal_entity               = xep.legal_entity_id
            AND mtt.transaction_type_id        = mmt.transaction_type_id
            AND mp.organization_id             = mmt.organization_id
            AND mmt.transaction_reference     IS NOT NULL
              ---------------------------------------------------------------
              ---------------------------------------------------------------
              -- PARAMETERS ---
            AND (p_batch_id             IS NULL
            OR (p_batch_id              IS NOT NULL
            AND mmt.transaction_reference = p_batch_id))
            AND (mtt.attribute4           = p_trn_type
            OR p_trn_type               IS NULL)
            AND (msib.segment1            = p_item_num
            OR p_item_num               IS NULL)
            ),
            wiwc_gcc_sql AS
            (SELECT TRANSACTION_ID,
              GCC
            FROM
              (SELECT mmt.transaction_id AS TRANSACTION_ID,
                (SELECT gcc.segment1
                  ||'.'
                  ||gcc.segment2
                  ||'.'
                  ||gcc.segment3
                  ||'.'
                  ||gcc.segment4
                  ||'.'
                  ||gcc.segment5
                  ||'.'
                  ||gcc.segment6
                  ||'.'
                  ||gcc.segment7
                  ||'.'
                  ||gcc. segment8
                FROM xla_distribution_links dl ,
                  xla_ae_lines al ,
                  xla_ae_headers ah ,
                  gl_code_combinations gcc
                WHERE 1                             =1
                AND dl.source_distribution_id_num_1 = gxel.line_id
                  --
                  --AND ah.ae_header_id = gxel1.header_id
                AND ah.event_id                     = gxel.event_id
                AND gcc.segment4                    = 13921
                AND dl.source_distribution_type     = gxeh.entity_code
                AND al.ae_header_id                 = dl.ae_header_id
                AND ah.application_id               = dl.application_id
                AND al.ae_line_num                  = dl.ae_line_num
                AND ah.ae_header_id                 = al.ae_header_id
                AND gcc.code_combination_id         = al.code_combination_id
                AND al.accounting_class_code        = 'IVA'
                AND ah.accounting_entry_status_code = 'F'
                ) AS GCC
              FROM mtl_material_transactions mmt ,
                mtl_system_items_b msib ,
                mtl_transaction_types mtt ,
                hr_operating_units hou ,
                org_organization_definitions ood ,
                xle_entity_profiles xep ,
                mtl_parameters mp ,
                gmf_xla_extract_headers gxeh ,
                gmf_period_statuses gps ,
                gmf_xla_extract_lines gxel,
                (SELECT mmt_sub.TRANSACTION_REFERENCE AS TRANSACTION_REFERENCE
                FROM MTL_MATERIAL_TRANSACTIONS mmt_sub ,
                  MTL_TRANSACTION_TYPES mtt_sub
                WHERE 1                                            =1
                AND mtt_sub.ATTRIBUTE4                             = 'BATCH COMP'
                AND mmt_sub.TRANSACTION_TYPE_ID                    = mtt_sub.TRANSACTION_TYPE_ID
                AND ((mmt_sub.TRANSACTION_DATE                    >= TO_DATE(p_date_from,'DD-MON-YY'))
                OR p_date_from                                   IS NULL)
                AND ((mmt_sub.TRANSACTION_DATE                     < (TO_DATE(p_date_to,'DD-MON-YY') + 1))
                OR p_date_to                                     IS NULL)
                --AND (NVL(mmt_sub.ATTRIBUTE2, 'NULL')               = DECODE(p_batch_comp,'N','NULL',p_batch_comp)
                --OR DECODE(p_batch_comp,'N','NULL',p_batch_comp) IS NULL)
                AND (p_batch_comp   IS NULL OR (p_batch_comp   IS NOT NULL  
                                                AND (NVL(mmt_sub.ATTRIBUTE2, 'NULL') = DECODE(p_batch_comp,'N','NULL',p_batch_comp))
                                                )
                  )
                )AA
              WHERE 1                          =1
              AND mmt.transaction_reference   IN(AA.transaction_reference)
              AND mp.process_enabled_flag      = 'Y'
              AND ((gxeh.valuation_cost_type   = 'STD')
              OR gxeh.header_id               IS NULL)
              AND mtt.attribute4              IN ('WIP ISSUE','WIP COMP')
              AND mmt.transaction_reference   IS NOT NULL
              AND mmt.inventory_item_id        = msib.inventory_item_id
              AND hou.default_legal_context_id = ood.legal_entity
              AND mmt.organization_id          = ood.organization_id
              AND mmt.organization_id          = msib.organization_id
              AND ood.legal_entity             = xep.legal_entity_id
              AND mtt.transaction_type_id      = mmt.transaction_type_id
              AND mp.organization_id           = mmt.organization_id
              AND gxeh.transaction_id (+)      = mmt.transaction_id
              AND gxeh.organization_id (+)     = mmt.organization_id
              AND gxeh.inventory_item_id (+)   = mmt.inventory_item_id
                ----------------------------------------------------------------------
              AND gxel.header_id      = gxeh.header_id       --
              AND mmt.organization_id = gxel.organization_id --
              AND gxeh.event_id       = gxel.event_id        --
                ----------------------------------------------------------------------
                -- PARAMETERS ---
              AND (p_batch_id             IS NULL
              OR (p_batch_id              IS NOT NULL
              AND mmt.transaction_reference = p_batch_id))
              AND (mtt.attribute4           = p_trn_type
              OR p_trn_type               IS NULL)
              AND (msib.segment1            = p_item_num
              OR p_item_num               IS NULL)
              ---------------------
              UNION ALL
              ---------------------
              SELECT mmt.transaction_id AS TRANSACTION_ID ,
                -----------------------------------------------------
                (
                SELECT gcc.segment1
                  ||'.'
                  ||gcc.segment2
                  ||'.'
                  ||gcc.segment3
                  ||'.'
                  ||gcc.segment4
                  ||'.'
                  ||gcc.segment5
                  ||'.'
                  ||gcc.segment6
                  ||'.'
                  ||gcc.segment7
                  ||'.'
                  ||gcc. segment8
                FROM xla_distribution_links b ,
                  xla_ae_lines l ,
                  gl_code_combinations gcc ,
                  xla_ae_headers xah
                WHERE 1                              =1
                AND b.source_distribution_type       = 'MTL_TRANSACTION_ACCOUNTS'
                AND b.application_id                 = l.application_id
                AND b.source_distribution_id_num_1   = mta.inv_sub_ledger_id
                AND xah.ae_header_id                 = l.ae_header_id
                AND gcc.code_combination_id          = l.code_combination_id
                AND l.ae_header_id                   = b.ae_header_id
                AND l.ae_line_num                    = b.ae_line_num
                AND xah.accounting_entry_status_code = 'F'
                AND l.accounting_class_code          = 'OFFSET'
                AND gcc.segment4                     = 13921
                )
                -------------------------------------------------------
                AS GCC
              FROM mtl_material_transactions mmt ,
                mtl_system_items_b msib ,
                mtl_transaction_accounts mta ,
                mtl_transaction_types mtt ,
                hr_operating_units hou ,
                org_organization_definitions ood ,
                xle_entity_profiles xep ,
                mtl_parameters mp ,
                (SELECT mmt_sub.transaction_reference AS TRANSACTION_REFERENCE
                  --, mtt_sub.TRANSACTION_TYPE_ID AS TRANSACTION_TYPE_ID
                FROM mtl_material_transactions mmt_sub ,
                  mtl_transaction_types mtt_sub
                WHERE 1                                            =1
                AND mtt_sub.attribute4                             = 'BATCH COMP'
                AND mmt_sub.transaction_type_id                    = mtt_sub.transaction_type_id
                AND ((mmt_sub.transaction_date                    >= TO_DATE(p_date_from,'DD-MON-YY'))
                OR p_date_from                                   IS NULL)
                AND ((mmt_sub.transaction_date                     < (TO_DATE(p_date_to,'DD-MON-YY') + 1))
                OR p_date_to                                     IS NULL)
                --AND (NVL(mmt_sub.ATTRIBUTE2, 'NULL')               = DECODE(p_batch_comp,'N','NULL',p_batch_comp)
                --OR DECODE(p_batch_comp,'N','NULL',p_batch_comp) IS NULL)
                AND (p_batch_comp   IS NULL OR (p_batch_comp   IS NOT NULL  
                                                AND (NVL(mmt_sub.ATTRIBUTE2, 'NULL') = DECODE(p_batch_comp,'N','NULL',p_batch_comp))
                                                )
                  )
                )AA
              WHERE 1                        =1
              AND mmt.transaction_reference IN(AA.transaction_reference)
                --AND    mmt.transaction_type_id = AA.transaction_type_id
              AND mp.process_enabled_flag        = 'N'
              AND mtt.attribute4                IN ('WIP ISSUE','WIP COMP')
              AND mmt.transaction_id             = mta.transaction_id (+)
              AND mmt.inventory_item_id          = mta.inventory_item_id(+)
              AND mmt.organization_id            = mta.organization_id (+)
              AND (mta.accounting_line_type NOT IN ('2')
              OR mta.transaction_id             IS NULL)
              AND mmt.inventory_item_id          = msib.inventory_item_id
              AND hou.default_legal_context_id   = ood.legal_entity
              AND mmt.organization_id            = ood.organization_id
              AND mmt.organization_id            = msib.organization_id
              AND ood.legal_entity               = xep.legal_entity_id
              AND mtt.transaction_type_id        = mmt.transaction_type_id
              AND mp.organization_id             = mmt.organization_id
              AND mmt.transaction_reference     IS NOT NULL
                -- PARAMETERS ---
              AND (p_batch_id             IS NULL
              OR (p_batch_id              IS NOT NULL
              AND mmt.transaction_reference = p_batch_id))
              AND (mtt.attribute4           = p_trn_type
              OR p_trn_type               IS NULL)
              AND (msib.segment1            = p_item_num
              OR p_item_num               IS NULL)
              ) wc_gcc1
            WHERE wc_gcc1.GCC IS NOT NULL
            ) ,
          bc_sql AS
          (SELECT ORGANIZATION_CODE            AS ORGANIZATION_CODE ,
            TRANSACTION_DATE                   AS TRANSACTION_DATE ,
            TRANSACTION_REFERENCE              AS TRANSACTION_REFERENCE ,
            TRANSACTION_TYPE_NAME              AS TRANSACTION_TYPE_NAME ,
            INVENTORY_ITEM_ID                  AS INVENTORY_ITEM_ID ,
            ITEM_NUMBER                        AS ITEM_NUMBER ,
            BATCH_ID_NUMBER                    AS BATCH_ID_NUMBER ,
            TRANSACTION_UOM                    AS TRANSACTION_UOM ,
            SUM(TRANSACTION_QUANTITY)          AS TRANSACTION_QUANTITY ,
            UNIT_COST                          AS UNIT_COST ,
            BATCH_COMPLETE                     AS BATCH_COMPLETE ,
            SUM(BATCH_SIZE)                    AS BATCH_SIZE ,
            ATTRIBUTE4                         AS ATTRIBUTE4 
          FROM
            ( SELECT DISTINCT A.ORGANIZATION_CODE     AS ORGANIZATION_CODE ,
              A.TRANSACTION_DATE                      AS TRANSACTION_DATE ,
              A.TRANSACTION_ID                        AS TRANSACTION_ID ,
              A.TRANSACTION_REFERENCE                 AS TRANSACTION_REFERENCE ,
              A.TRANSACTION_TYPE_NAME                 AS TRANSACTION_TYPE_NAME ,
              A.INVENTORY_ITEM_ID                     AS INVENTORY_ITEM_ID ,
              A.ITEM_NUMBER                           AS ITEM_NUMBER ,
              A.BATCH_ID_NUMBER                       AS BATCH_ID_NUMBER ,
              A.TRANSACTION_UOM                       AS TRANSACTION_UOM ,
              A.TRANSACTION_QUANTITY                  AS TRANSACTION_QUANTITY ,
              SUM(A.UNIT_COST)                        AS UNIT_COST ,
              A.BATCH_COMPLETE                        AS BATCH_COMPLETE ,
              A.BATCH_SIZE                            AS BATCH_SIZE ,
              A.ATTRIBUTE4                            AS ATTRIBUTE4 
            FROM
              (SELECT DISTINCT hou.name   AS OPERATING_UNIT ,
                ood.organization_code     AS ORGANIZATION_CODE,
                xep.name                  AS LEGAL_ENTITY ,
                mmt.transaction_date      AS TRANSACTION_DATE ,
                mmt.transaction_reference AS TRANSACTION_REFERENCE ,
                mmt.transaction_id        AS TRANSACTION_ID ,
                mmt.transaction_type_id   AS TRANSACTION_TYPE_ID ,
                mtt.transaction_type_name AS TRANSACTION_TYPE_NAME ,
                mmt.subinventory_code     AS SUBINVENTORY_CODE ,
                mmt.inventory_item_id     AS INVENTORY_ITEM_ID ,
                msib.segment1             AS ITEM_NUMBER ,
                mmt.transaction_reference AS BATCH_ID_NUMBER ,
                msib.item_type            AS ITEM_TYPE,
                mmt.transaction_uom       AS TRANSACTION_UOM,
                mmt.transaction_quantity  AS TRANSACTION_QUANTITY,
                (SELECT NVL(SUM(cmpnt_cost),0)
                FROM
                  (SELECT DISTINCT mp_proc.organization_id ,
                    msi_proc.segment1 ,
                    ccd.inventory_item_id ,
                    ccd.cmpnt_cost ,
                    ccm.cost_cmpntcls_code ,
                    ccd.period_id
                  FROM cm_cmpt_dtl ccd,
                    cm_cmpt_mst ccm ,
                    mtl_system_items_b msi_proc,
                    mtl_parameters mp_proc
                  WHERE 1                   =1
                  AND ccd.inventory_item_id = msi_proc.inventory_item_id
                  AND ccd.organization_id   = msi_proc.organization_id
                  AND ccd.cost_cmpntcls_id  = ccm.cost_cmpntcls_id
                  AND ccd.organization_id   = mp_proc.organization_id
                  AND ccd.organization_id   = msi_proc.organization_id
                    --AND ccm.cost_cmpntcls_code IN ('RMW','MAT_OH')
                  AND ccd.delete_mark = 0
                  AND ccd.cost_level  = 1
                  ) proc_cost
                WHERE 1                         =1
                AND proc_cost.period_id         = gps.period_id
                AND mmt.transaction_date       >= gps.start_date
                AND mmt.transaction_date        < gps.end_date + 1
                AND proc_cost.inventory_item_id = msib.inventory_item_id
                AND proc_cost.organization_id   = msib.organization_id
                AND proc_cost.organization_id   = mp.organization_id
                )                         AS UNIT_COST
                ---------- Total Value
                ,
                0                         AS TOTAL_VALUE
                -------
                ,
                mmt.reason_id             AS REASON_ID ,
                mtt.attribute1            AS REASON_CODE ,
                mmt.attribute1            AS LOT_NUMBER ,
                mmt.attribute2            AS BATCH_COMPLETE ,
                mmt.attribute3            AS BATCH_SIZE ,
                mtt.attribute4            AS ATTRIBUTE4,
                mmt.last_update_date      AS LAST_UPDATE_DATE
              FROM mtl_material_transactions mmt ,
                mtl_system_items_b msib ,
                mtl_transaction_types mtt ,
                hr_operating_units hou ,
                org_organization_definitions ood ,
                xle_entity_profiles xep ,
                mtl_parameters mp ,
                gmf_xla_extract_headers gxeh
                --, gmf_xla_extract_lines gxel
                ,
                gmf_period_statuses gps ,
                (SELECT mmt_sub.transaction_reference AS TRANSACTION_REFERENCE ,
                  mmt_sub.inventory_item_id           AS INVENTORY_ITEM_ID
                FROM mtl_material_transactions mmt_sub ,
                  mtl_transaction_types mtt_sub
                WHERE 1                                          =1
                AND mtt_sub.attribute4                           = 'BATCH COMP'
                AND mmt_sub.transaction_type_id                  = mtt_sub.transaction_type_id
                AND ((mmt_sub.transaction_date                  >= TO_DATE(p_date_from,'DD-MON-YY'))
                OR p_date_from                                  IS NULL)
                AND ((mmt_sub.transaction_date                   < (TO_DATE(p_date_to,'DD-MON-YY') + 1))
                OR p_date_to                                    IS NULL)
                --AND (NVL(mmt_sub.ATTRIBUTE2, 'NULL')             = DECODE(p_batch_comp,'N','NULL',p_batch_comp)
                --OR DECODE(p_batch_comp,'N','NULL',p_batch_comp) IS NULL)
                AND (p_batch_comp   IS NULL OR (p_batch_comp   IS NOT NULL  
                                                AND (NVL(mmt_sub.ATTRIBUTE2, 'NULL') = DECODE(p_batch_comp,'N','NULL',p_batch_comp))
                                                )
                  )
                )AA
              WHERE 1                          =1
              AND mmt.transaction_reference   IN(AA.transaction_reference)
              AND mmt.inventory_item_id        = AA.inventory_item_id
              AND mp.process_enabled_flag      = 'Y'
              AND ((gxeh.valuation_cost_type   = 'STD')
              OR gxeh.header_id               IS NULL)
              AND mtt.attribute4              IN ('BATCH COMP')
              AND mmt.transaction_reference   IS NOT NULL
              AND mmt.inventory_item_id        = msib.inventory_item_id
              AND hou.default_legal_context_id = ood.legal_entity
              AND mmt.organization_id          = ood.organization_id
              AND mmt.organization_id          = msib.organization_id
              AND ood.legal_entity             = xep.legal_entity_id
              AND mtt.transaction_type_id      = mmt.transaction_type_id
              AND mp.organization_id           = mmt.organization_id
              AND gxeh.transaction_id (+)      = mmt.transaction_id
              AND gxeh.organization_id (+)     = mmt.organization_id
              AND gxeh.inventory_item_id (+)   = mmt.inventory_item_id
                -- AND    msib.SEGMENT1 = '100018028'
                -- PARAMETERS ---
              AND ((mmt.transaction_date    >= TO_DATE(p_date_from,'DD-MON-YY'))
              OR p_date_from                IS NULL)
              AND ((mmt.transaction_date     < (TO_DATE(p_date_to,'DD-MON-YY') + 1))
              OR p_date_to                  IS NULL)
              AND (mmt.transaction_reference = p_batch_id
              OR p_batch_id                 IS NULL)
              AND (mtt.attribute4            = p_trn_type
              OR p_trn_type                 IS NULL)
              AND (msib.segment1             = p_item_num
              OR p_item_num                 IS NULL)
              UNION ALL
              SELECT DISTINCT hou.name      AS OPERATING_UNIT ,
                ood.organization_code       AS ORGANIZATION_CODE,
                xep.name                    AS LEGAL_ENTITY ,
                mmt.transaction_date        AS TRANSACTION_DATE ,
                mmt.transaction_reference   AS TRANSACTION_REFERENCE ,
                mmt.transaction_id          AS TRANSACTION_ID ,
                mmt.transaction_type_id     AS TRANSACTION_TYPE_ID ,
                mtt.transaction_type_name   AS TRANSACTION_TYPE_NAME ,
                mmt.subinventory_code       AS SUBINVENTORY_CODE
                ---------------
                ,
                mmt.inventory_item_id       AS INVENTORY_ITEM_ID ,
                msib.segment1               AS ITEM_NUMBER ,
                mmt.transaction_reference   AS BATCH_ID_NUMBER ,
                msib.item_type              AS ITEM_TYPE,
                mmt.transaction_uom         AS TRANSACTION_UOM,
                mmt.transaction_quantity    AS TRANSACTION_QUANTITY, 
                (SELECT NVL(SUM(item_cost),0)
                FROM
                  (SELECT DISTINCT cicd.cost_element ,
                    cicd.Resource_code ,
                    cicd.usage_rate_or_amount ,
                    cicd.item_cost ,
                    msi_disc.segment1 ,
                    mp_disc.organization_code ,
                    cict.cost_type ,
                    msi_disc.inventory_item_id ,
                    mp_disc.organization_id
                  FROM cst_item_cost_details_v cicd,
                    mtl_system_items_b msi_disc,
                    mtl_parameters mp_disc,
                    cst_item_cost_type_v cict
                  WHERE 1                    =1
                  AND cicd.inventory_item_id = msi_disc.inventory_item_id
                  AND cicd.organization_id   = msi_disc.organization_id
                  AND cicd.organization_id   = mp_disc.organization_id
                  AND cicd.inventory_item_id = cict.inventory_item_id
                  AND cicd.organization_id   = cict.organization_id
                  --Modified for discreet org cost validation Khristine Austero 11/3/2016
                  AND UPPER(cict.cost_type)  = 'FROZEN' 
                  AND cicd.cost_type_id      = cict.cost_type_id
                  --AND   cicd.cost_element IN ('Material','Material Overhead')
                  AND cicd.level_type = 2
                  ) disc_cost
                WHERE 1                         =1
                AND disc_cost.inventory_item_id = msib.inventory_item_id
                AND disc_cost.organization_id   = msib.organization_id
                AND disc_cost.organization_id   = mp.organization_id
                )                           AS UNIT_COST
                ---------- Total Value
                --,mta.BASE_TRANSACTION_VALUE
                ,
                0                           AS TOTAL_VALUE
                -------
                ,
                mmt.reason_id               AS REASON_ID,
                mtt.attribute1              AS REASON_CODE ,
                mmt.attribute1              AS LOT_NUMBER ,
                mmt.attribute2              AS BATCH_COMPLETE ,
                mmt.attribute3              AS BATCH_SIZE ,
                mtt.attribute4              AS ATTRIBUTE4,
                mmt.last_update_date        AS LAST_UPDATE_DATE
              FROM mtl_material_transactions mmt ,
                mtl_system_items_b msib ,
                mtl_transaction_accounts mta ,
                mtl_transaction_types mtt ,
                hr_operating_units hou ,
                org_organization_definitions ood ,
                xle_entity_profiles xep ,
                mtl_parameters mp ,
                (SELECT mmt_sub.transaction_reference AS TRANSACTION_REFERENCE ,
                  mmt_sub.inventory_item_id           AS INVENTORY_ITEM_ID
                FROM mtl_material_transactions mmt_sub ,
                  mtl_transaction_types mtt_sub
                WHERE 1                                          =1
                AND mtt_sub.attribute4                           = 'BATCH COMP'
                AND mmt_sub.transaction_type_id                  = mtt_sub.transaction_type_id
                AND ((mmt_sub.transaction_date                  >= TO_DATE(p_date_from,'DD-MON-YY'))
                OR p_date_from                                  IS NULL)
                AND ((mmt_sub.transaction_date                   < (TO_DATE(p_date_to,'DD-MON-YY') + 1))
                OR p_date_to                                    IS NULL)
                --AND (NVL(mmt_sub.ATTRIBUTE2, 'NULL')            = DECODE(p_batch_comp,'N','NULL',p_batch_comp)
                --OR DECODE(p_batch_comp,'N','NULL',p_batch_comp) IS NULL)
                AND (p_batch_comp   IS NULL OR (p_batch_comp   IS NOT NULL  
                                                AND (NVL(mmt_sub.ATTRIBUTE2, 'NULL') = DECODE(p_batch_comp,'N','NULL',p_batch_comp))
                                                )
                  )
                )AA
              WHERE 1                            =1
              AND mmt.transaction_reference     IN(AA.transaction_reference)
              AND mmt.inventory_item_id          = AA.inventory_item_id
              AND mp.process_enabled_flag        = 'N'
              AND mtt.attribute4                IN ('BATCH COMP')
              AND mmt.transaction_id             = mta.transaction_id (+)
              AND mmt.inventory_item_id          = mta.inventory_item_id(+)
              AND mmt.organization_id            = mta.organization_id (+)
              AND (mta.accounting_line_type NOT IN ('2')
              OR mta.transaction_id             IS NULL)
              AND mmt.inventory_item_id          = msib.inventory_item_id
              AND hou.default_legal_context_id   = ood.legal_entity
              AND mmt.organization_id            = ood.organization_id
              AND mmt.organization_id            = msib.organization_id
              AND ood.legal_entity               = xep.legal_entity_id
              AND mtt.transaction_type_id        = mmt.transaction_type_id
              AND mp.organization_id             = mmt.organization_id
              AND mmt.transaction_reference     IS NOT NULL
                -- AND    msib.SEGMENT1 = '100018028'
                -- PARAMETERS ---
              AND ((mmt.transaction_date    >= TO_DATE(p_date_from,'DD-MON-YY'))
              OR p_date_from                IS NULL)
              AND ((mmt.transaction_date     < (TO_DATE(p_date_to,'DD-MON-YY') + 1))
              OR p_date_to                  IS NULL)
              AND (mmt.transaction_reference = p_batch_id
              OR p_batch_id                 IS NULL)
              AND (mtt.attribute4            = p_trn_type
              OR p_trn_type                 IS NULL)
              AND (msib.segment1             = p_item_num
              OR p_item_num                 IS NULL)
              )A ,
              (SELECT msib.segment1       AS ITEM_NUMBER ,
                mmt.transaction_reference AS BATCH_ID_NUMBER ,
                MAX(mmt.last_update_date) AS LAST_UPDATE_DATE ,
                mmt.attribute1            AS LOT_NUMBER
              FROM mtl_material_transactions mmt ,
                mtl_system_items_b msib ,
                mtl_transaction_types mtt ,
                hr_operating_units hou ,
                org_organization_definitions ood ,
                xle_entity_profiles xep ,
                mtl_parameters mp ,
                gmf_xla_extract_headers gxeh
                --, gmf_xla_extract_lines gxel
                ,
                gmf_period_statuses gps ,
                (SELECT mmt_sub.transaction_reference AS TRANSACTION_REFERENCE ,
                  mmt_sub.inventory_item_id           AS INVENTORY_ITEM_ID
                FROM mtl_material_transactions mmt_sub ,
                  mtl_transaction_types mtt_sub
                WHERE 1                                          =1
                AND mtt_sub.attribute4                           = 'BATCH COMP'
                AND mmt_sub.transaction_type_id                  = mtt_sub.transaction_type_id
                AND ((mmt_sub.transaction_date                  >= TO_DATE(p_date_from,'DD-MON-YY'))
                OR p_date_from                                  IS NULL)
                AND ((mmt_sub.transaction_date                   < (TO_DATE(p_date_to,'DD-MON-YY') + 1))
                OR p_date_to                                    IS NULL)
                --AND (NVL(mmt_sub.ATTRIBUTE2, 'NULL')             = DECODE(p_batch_comp,'N','NULL',p_batch_comp)
                --OR DECODE(p_batch_comp,'N','NULL',p_batch_comp) IS NULL)
                AND (p_batch_comp   IS NULL OR (p_batch_comp   IS NOT NULL  
                                                AND (NVL(mmt_sub.ATTRIBUTE2, 'NULL') = DECODE(p_batch_comp,'N','NULL',p_batch_comp))
                                                )
                  )
                )AA
              WHERE 1                          =1
              AND mmt.transaction_reference   IN(AA.transaction_reference)
              AND mmt.inventory_item_id        = AA.inventory_item_id
              AND mp.process_enabled_flag      = 'Y'
              AND ((gxeh.valuation_cost_type   = 'STD')
              OR gxeh.header_id               IS NULL)
              AND mtt.attribute4              IN ('BATCH COMP')
              AND mmt.transaction_reference   IS NOT NULL
              AND mmt.inventory_item_id        = msib.inventory_item_id
              AND hou.default_legal_context_id = ood.legal_entity
              AND mmt.organization_id          = ood.organization_id
              AND mmt.organization_id          = msib.organization_id
              AND ood.legal_entity             = xep.legal_entity_id
              AND mtt.transaction_type_id      = mmt.transaction_type_id
              AND mp.organization_id           = mmt.organization_id
              AND gxeh.transaction_id (+)      = mmt.transaction_id
              AND gxeh.organization_id (+)     = mmt.organization_id
              AND gxeh.inventory_item_id (+)   = mmt.inventory_item_id
                -- AND    msib.SEGMENT1 = '100018028'
                -- PARAMETERS ---
              AND ((mmt.transaction_date    >= TO_DATE(p_date_from,'DD-MON-YY'))
              OR p_date_from                IS NULL)
              AND ((mmt.transaction_date     < (TO_DATE(p_date_to,'DD-MON-YY') + 1))
              OR p_date_to                  IS NULL)
              AND (mmt.transaction_reference = p_batch_id
              OR p_batch_id                 IS NULL)
              AND (mtt.attribute4            = p_trn_type
              OR p_trn_type                 IS NULL)
              AND (msib.segment1             = p_item_num
              OR p_item_num                 IS NULL)
              GROUP BY msib.segment1,
                mmt.transaction_reference,
                mmt.attribute1
              UNION ALL
              SELECT msib.segment1        AS ITEM_NUMBER ,
                mmt.transaction_reference AS BATCH_ID_NUMBER ,
                MAX(mmt.last_update_date) AS LAST_UPDATE_DATE ,
                mmt.attribute1            AS LOT_NUMBER
              FROM mtl_material_transactions mmt ,
                mtl_system_items_b msib ,
                mtl_transaction_accounts mta ,
                mtl_transaction_types mtt ,
                hr_operating_units hou ,
                org_organization_definitions ood ,
                xle_entity_profiles xep ,
                mtl_parameters mp ,
                (SELECT mmt_sub.transaction_reference AS TRANSACTION_REFERENCE ,
                  mmt_sub.inventory_item_id           AS INVENTORY_ITEM_ID
                FROM mtl_material_transactions mmt_sub ,
                  mtl_transaction_types mtt_sub
                WHERE 1                                          =1
                AND mtt_sub.attribute4                           = 'BATCH COMP'
                AND mmt_sub.transaction_type_id                  = mtt_sub.transaction_type_id
                AND ((mmt_sub.transaction_date                  >= TO_DATE(p_date_from,'DD-MON-YY'))
                OR p_date_from                                  IS NULL)
                AND ((mmt_sub.transaction_date                   < (TO_DATE(p_date_to,'DD-MON-YY') + 1))
                OR p_date_to                                    IS NULL)
                --AND (NVL(mmt_sub.ATTRIBUTE2, 'NULL')             = DECODE(p_batch_comp,'N','NULL',p_batch_comp)
                --OR DECODE(p_batch_comp,'N','NULL',p_batch_comp) IS NULL)
                AND (p_batch_comp   IS NULL OR (p_batch_comp   IS NOT NULL  
                                                AND (NVL(mmt_sub.ATTRIBUTE2, 'NULL') = DECODE(p_batch_comp,'N','NULL',p_batch_comp))
                                                )
                  )
                )AA
              WHERE 1                            =1
              AND mmt.transaction_reference     IN(AA.transaction_reference)
              AND mmt.inventory_item_id          = AA.inventory_item_id
              AND mp.process_enabled_flag        = 'N'
              AND mtt.attribute4                IN ('BATCH COMP')
              AND mmt.transaction_id             = mta.transaction_id (+)
              AND mmt.inventory_item_id          = mta.inventory_item_id(+)
              AND mmt.organization_id            = mta.organization_id (+)
              AND (mta.accounting_line_type     NOT IN ('2')
              OR mta.transaction_id             IS NULL)
              AND mmt.inventory_item_id          = msib.inventory_item_id
              AND hou.default_legal_context_id   = ood.legal_entity
              AND mmt.organization_id            = ood.organization_id
              AND mmt.organization_id            = msib.organization_id
              AND ood.legal_entity               = xep.legal_entity_id
              AND mtt.transaction_type_id        = mmt.transaction_type_id
              AND mp.organization_id             = mmt.organization_id
              AND mmt.transaction_reference     IS NOT NULL
                -- AND    msib.SEGMENT1 = '100018028'
                -- PARAMETERS ---
              AND ((mmt.transaction_date    >= TO_DATE(p_date_from,'DD-MON-YY'))
              OR p_date_from                IS NULL)
              AND ((mmt.transaction_date     < (TO_DATE(p_date_to,'DD-MON-YY') + 1))
              OR p_date_to                  IS NULL)
              AND (mmt.transaction_reference = p_batch_id
              OR p_batch_id                 IS NULL)
              AND (mtt.attribute4            = p_trn_type
              OR p_trn_type                 IS NULL)
              AND (msib.segment1             = p_item_num
              OR p_item_num                 IS NULL)
              GROUP BY msib.segment1,
                mmt.transaction_reference,
                mmt.attribute1
              )B
            WHERE A.BATCH_ID_NUMBER = B.BATCH_ID_NUMBER
            AND A.ITEM_NUMBER       = B.ITEM_NUMBER
            AND A.LAST_UPDATE_DATE  = B.LAST_UPDATE_DATE
            AND A.LOT_NUMBER        = B.LOT_NUMBER
            GROUP BY A.ORGANIZATION_CODE,
              A.TRANSACTION_DATE,
              A.TRANSACTION_ID,
              A.TRANSACTION_REFERENCE,
              A.TRANSACTION_TYPE_NAME,
              A.INVENTORY_ITEM_ID,
              A.ITEM_NUMBER,
              A.BATCH_ID_NUMBER,
              A.TRANSACTION_UOM,
              A.TRANSACTION_QUANTITY,
              A.BATCH_COMPLETE,
              A.BATCH_SIZE,
              A.ATTRIBUTE4
            )
          GROUP BY ORGANIZATION_CODE ,
            TRANSACTION_DATE ,
            TRANSACTION_REFERENCE ,
            TRANSACTION_TYPE_NAME ,
            INVENTORY_ITEM_ID ,
            ITEM_NUMBER ,
            BATCH_ID_NUMBER ,
            TRANSACTION_UOM ,
            UNIT_COST ,
            BATCH_COMPLETE ,
            ATTRIBUTE4
          )
        SELECT '"'
          || (
          CASE
            WHEN TRANSACTION_DATE IS NOT NULL
            THEN TO_CHAR(TRANSACTION_DATE,'DD-Mon-YY')
            ELSE NULL
          END )
          ||'",=" '
          || TRANSACTION_TYPE_NAME
          ||'",=" '
          || BATCH_ID_NUMBER
          ||'",=" '
          || ORGANIZATION_CODE
          ||'",=" '
          || PRODUCING_ORG
          ||'",=" '
          || GCC
          ||'",=" '
          || ITEM_NUMBER
          ||'",=" '
          || TRANSACTION_UOM
          ||'",'
          || QUANTITY_COMPLETED
          ||','
          || QUANTITY_YIELD
          ||','
          || THEORETICAL_QUANTITY
          ||',"'
          || TRANSACTION_AMOUNT
          ||'",=" '
          || BATCH_COMPLETE
          ||'",=" '
          || (DECODE(UNIT_COST, NULL, NULL, ' $'
          ||TRIM(TO_CHAR(UNIT_COST,'999G999G999G999D00000')) ) )
          ||'"," '
          || (DECODE(TOTAL_DIFFERENCE, NULL, NULL, 1, 'ERROR', 2, 'N/A', '$'
          ||TRIM(TO_CHAR(TOTAL_DIFFERENCE,'999G999G999G999D00'))) )
          ||'"," '
          || (DECODE(YIELD_VAR, NULL, NULL, 1, 'ERROR', 2, 'N/A', '$'
          ||TRIM(TO_CHAR(YIELD_VAR,'999G999G999G999D00'))) )
          ||'"," '
          || (DECODE(USAGE_VAR, NULL, NULL, 1, 'ERROR', 2, 'N/A', '$'
          ||TRIM(TO_CHAR(USAGE_VAR,'999G999G999G999D00'))) )
          ||'"," '
          || ERROR_CODE
          || ' " ' YIELD_REP
        FROM
          (SELECT INDEX_ID ,
            TRANSACTION_ID ,
            TRANSACTION_DATE ,
            TRANSACTION_TYPE_NAME ,
            BATCH_ID_NUMBER ,
            ORGANIZATION_CODE ,
            ITEM_NUMBER ,
            TRANSACTION_UOM ,
            QUANTITY_COMPLETED ,
            QUANTITY_YIELD ,
            THEORETICAL_QUANTITY ,
            SUM(TRANSACTION_AMOUNT) TRANSACTION_AMOUNT ,
            BATCH_COMPLETE ,
            UNIT_COST ,
            TOTAL_DIFFERENCE ,
            YIELD_VAR ,
            USAGE_VAR ,
            ATTRIBUTE4 ,
            ERROR_CODE ,
            PRODUCING_ORG ,
            GCC
          FROM
            ( SELECT DISTINCT 1              AS INDEX_ID ,
              wiwc_ttl.transaction_id        AS TRANSACTION_ID,
              wiwc_ttl.transaction_date      AS TRANSACTION_DATE,
              wiwc_ttl.transaction_type_name AS TRANSACTION_TYPE_NAME ,
              wiwc_ttl.batch_id_number       AS BATCH_ID_NUMBER,
              wiwc_ttl.organization_code     AS ORGANIZATION_CODE,
              wiwc_ttl.item_number           AS ITEM_NUMBER ,
              wiwc_ttl.transaction_uom       AS TRANSACTION_UOM ,
              wiwc_ttl.transaction_quantity  AS QUANTITY_COMPLETED ,
              NULL                           AS QUANTITY_YIELD ,
              NULL                           AS THEORETICAL_QUANTITY ,
              (CASE
                WHEN wiwc_ttl.attribute4 = 'WIP ISSUE'
                THEN ABS(wiwc_ttl.total_value)
                WHEN wiwc_ttl.attribute4 = 'WIP COMP'
                THEN 0-ABS(bc.unit_cost * wiwc_ttl.transaction_quantity)
              END)                           AS TRANSACTION_AMOUNT ,
              NULL                           AS BATCH_COMPLETE ,
              NULL                           AS UNIT_COST ,
              NULL                           AS TOTAL_DIFFERENCE ,
              NULL                           AS YIELD_VAR ,
              NULL                           AS USAGE_VAR ,
              wiwc_ttl.attribute4            AS ATTRIBUTE4 ,
              NULL                           AS ERROR_CODE ,
              wiwc_ttl.producing_org         AS PRODUCING_ORG ,
              wiwc_ttl.gcc                   AS GCC
            FROM
              (SELECT wiwc.transaction_id    AS TRANSACTION_ID,
                wiwc.transaction_date        AS TRANSACTION_DATE,
                wiwc.transaction_type_name   AS TRANSACTION_TYPE_NAME,
                wiwc.batch_id_number         AS BATCH_ID_NUMBER,
                wiwc.organization_code       AS ORGANIZATION_CODE,
                wiwc.item_number             AS ITEM_NUMBER ,
                wiwc.transaction_uom         AS TRANSACTION_UOM ,
                wiwc.transaction_quantity    AS TRANSACTION_QUANTITY ,
                wiwc.total_value             AS TOTAL_VALUE ,
                wiwc.attribute4              AS ATTRIBUTE4 ,
                wiwc.producing_org           AS PRODUCING_ORG ,
                wiwc.gcc                     AS GCC
              FROM  (SELECT wc.OPERATING_UNIT ,
                      wc.ORGANIZATION_CODE ,
                      wc.LEGAL_ENTITY ,
                      wc.TRANSACTION_DATE,
                      wc.TRANSACTION_REFERENCE ,
                      wc.TRANSACTION_ID ,
                      wc.TRANSACTION_TYPE_ID ,
                      wc.TRANSACTION_TYPE_NAME ,
                      wc.SUBINVENTORY_CODE ,
                      wc.INVENTORY_ITEM_ID ,
                      wc.ITEM_NUMBER ,
                      wc.BATCH_ID_NUMBER ,
                      wc.ITEM_TYPE ,
                      wc.TRANSACTION_UOM ,
                      wc.TRANSACTION_QUANTITY ,
                      wc.PRODUCING_ORG ,
                      wc.TOTAL_VALUE ,
                      wc.REASON_ID,
                      wc.REASON_CODE ,
                      wc.LOT_NUMBER ,
                      wc.BATCH_COMPLETE ,
                      wc.BATCH_SIZE ,
                      wc.ATTRIBUTE4,
                      wc.ORGANIZATION_ID,
                      wc_gcc.GCC
                    FROM(wiwc_sql) wc ,
                      (wiwc_gcc_sql) wc_gcc
                    WHERE wc.transaction_id = wc_gcc.transaction_id (+)
                    ) wiwc
              )Wiwc_ttl ,
              ( bc_sql ) bc
            WHERE wiwc_ttl.batch_id_number = bc.batch_id_number (+)
            AND wiwc_ttl.item_number       = bc.item_number (+)
            )
          GROUP BY INDEX_ID ,
            TRANSACTION_ID ,
            TRANSACTION_DATE ,
            TRANSACTION_TYPE_NAME ,
            BATCH_ID_NUMBER ,
            ORGANIZATION_CODE ,
            ITEM_NUMBER ,
            TRANSACTION_UOM ,
            QUANTITY_COMPLETED ,
            QUANTITY_YIELD ,
            THEORETICAL_QUANTITY ,
            UNIT_COST ,
            ATTRIBUTE4 ,
            NULL ,
            BATCH_COMPLETE ,
            TOTAL_DIFFERENCE ,
            YIELD_VAR ,
            USAGE_VAR ,
            ERROR_CODE ,
            PRODUCING_ORG ,
            GCC
          UNION ALL
          ------------------------
          -- TOTAL PER BATCH ID --
          ------------------------
          SELECT INDEX_ID ,
            TRANSACTION_ID ,
            TRANSACTION_DATE ,
            TRANSACTION_TYPE_NAME ,
            BATCH_ID_NUMBER ,
            ORGANIZATION_CODE ,
            ITEM_NUMBER ,
            TRANSACTION_UOM ,
            QUANTITY_COMPLETED ,
            QUANTITY_YIELD ,
            THEORETICAL_QUANTITY ,
            TRANSACTION_AMOUNT ,
            BATCH_COMPLETE
            --,SUM(UNIT_COST)
            ,
            UNIT_COST ,
            TOTAL_DIFFERENCE ,
            YIELD_VAR ,
            USAGE_VAR ,
            ATTRIBUTE4 ,
            ERROR_CODE , 
            PRODUCING_ORG ,
            GCC
          FROM
            ( SELECT DISTINCT 2            AS INDEX_ID ,
              NULL                         AS TRANSACTION_ID ,
              bc.transaction_date          AS TRANSACTION_DATE,
              bc.transaction_type_name     AS TRANSACTION_TYPE_NAME
              --, '="' ||  bc.batch_id_number  || '"' AS BATCH_ID_NUMBER
              ,
              bc.batch_id_number           AS BATCH_ID_NUMBER,
              bc.organization_code         AS ORGANIZATION_CODE,
              bc.item_number               AS ITEM_NUMBER ,
              bc.transaction_uom           AS TRANSACTION_UOM,
              NULL                         AS QUANTITY_COMPLETED ,
              bc.transaction_quantity      AS QUANTITY_YIELD ,
              bc.batch_size                AS THEORETICAL_QUANTITY ,
              NULL                         AS TRANSACTION_AMOUNT ,
              bc.batch_complete            AS BATCH_COMPLETE,
              bc.unit_cost                 AS UNIT_COST
              --  , wiwc_ttl.TRANSACTION_QUANTITY_TTL TRANSACTION_QUANTITY_TTL
              ,
              (
              CASE
                WHEN NVL(wiwc_ttl.transaction_quantity_ttl,0) <> NVL(abc.transaction_quantity,0)
                AND bc.batch_id_number                        IS NOT NULL
                THEN 1
                WHEN bc.batch_complete != 'Y'
                THEN 2
                ELSE wiwc_ttl.total_value1
              END )                        AS TOTAL_DIFFERENCE ,
              (
              CASE
                WHEN NVL(wiwc_ttl.transaction_quantity_ttl,0) <> NVL(abc.transaction_quantity,0)
                AND bc.batch_id_number                        IS NOT NULL
                THEN 1
                WHEN bc.batch_complete != 'Y'
                THEN 2
                ELSE (bc.BATCH_SIZE - bc.transaction_quantity)*bc.unit_cost
              END )                        AS YIELD_VAR ,
              (
              CASE
                WHEN NVL(wiwc_ttl.transaction_quantity_ttl,0) <> NVL(abc.transaction_quantity,0)
                AND bc.batch_id_number                        IS NOT NULL
                THEN 1
                WHEN bc.batch_complete != 'Y'
                THEN 2
                ELSE
                  --(NVL(wiwc_ttl.TOTAL_VALUE1,0))-((bc.BATCH_SIZE - bc.TRANSACTION_QUANTITY)*bc.UNIT_COST)
                  DECODE(abc.ttl_bs,0,0,(( NVL(wiwc_ttl.total_value1,0) - abc.ttl_yld_var) / abc.ttl_bs )* bc.batch_size )
              END)                         AS USAGE_VAR ,
              bc.attribute4                AS ATTRIBUTE4 ,
              (CASE
                WHEN NVL(wiwc_ttl.transaction_quantity_ttl,0) <> NVL(abc.transaction_quantity,0)
                AND bc.batch_id_number                        IS NOT NULL
                THEN 'Yield qty does not match total qty completed'
                WHEN bc.batch_complete != 'Y'
                THEN 'The Batch is not complete'
              END)                         AS ERROR_CODE ,
              NULL                         AS PRODUCING_ORG ,
              NULL                         AS GCC
            FROM
              (SELECT wiwc_b.operating_unit            AS OPERATING_UNIT ,
                wiwc_b.legal_entity                    AS LEGAL_ENTITY ,
                wiwc_b.batch_id_number                 AS BATCH_ID_NUMBER ,
                SUM(wiwc_b.transaction_quantity_ttl)   AS TRANSACTION_QUANTITY_TTL ,
                SUM(wiwc_b.total_value1)               AS TOTAL_VALUE1
              FROM
                (SELECT wiwc_a.operating_unit          AS OPERATING_UNIT ,
                  wiwc_a.legal_entity                  AS LEGAL_ENTITY ,
                  wiwc_a.batch_id_number               AS BATCH_ID_NUMBER ,
                  wiwc_a.transaction_id                AS TRANSACTION_ID ,
                  wiwc_a.item_number                   AS ITEM_NUMBER ,
                  (NVL(wiwc_a.transaction_quantity,0)) AS TRANSACTION_QUANTITY_TTL ,
                  SUM(wiwc_a.total_value2)             AS TOTAL_VALUE1
                FROM
                  ( SELECT DISTINCT wiwc_ttl.operating_unit     AS OPERATING_UNIT ,
                    wiwc_ttl.legal_entity                       AS LEGAL_ENTITY ,
                    wiwc_ttl.transaction_id                     AS TRANSACTION_ID ,
                    wiwc_ttl.batch_id_number                    AS BATCH_ID_NUMBER ,
                    wiwc_ttl.organization_code                  AS ORGANIZATION_CODE ,
                    wiwc_ttl.item_number                        AS ITEM_NUMBER ,
                    wiwc_ttl.transaction_quantity               AS TRANSACTION_QUANTITY,
                    (CASE
                      WHEN wiwc_ttl.attribute4 = 'WIP ISSUE'
                      THEN ABS(wiwc_ttl.total_value)
                      WHEN wiwc_ttl.attribute4 = 'WIP COMP'
                      THEN 0-ABS(bc.unit_cost * wiwc_ttl.transaction_quantity)
                    END)                                        AS TOTAL_VALUE2
                  FROM
                    (SELECT wc.OPERATING_UNIT       AS OPERATING_UNIT ,
                            wc.LEGAL_ENTITY         AS LEGAL_ENTITY ,
                            wc.TRANSACTION_ID       AS TRANSACTION_ID ,
                            wc.BATCH_ID_NUMBER      AS BATCH_ID_NUMBER ,
                            wc.ORGANIZATION_CODE    AS ORGANIZATION_CODE ,
                            wc.ITEM_NUMBER          AS ITEM_NUMBER ,
                            wc.TRANSACTION_QUANTITY AS TRANSACTION_QUANTITY ,
                            wc.TOTAL_VALUE          AS TOTAL_VALUE ,
                            wc.ATTRIBUTE4           AS ATTRIBUTE4 ,
                            wc_gcc.GCC              AS GCC
                    FROM(wiwc_sql) wc ,
                      (wiwc_gcc_sql) wc_gcc
                    WHERE wc.transaction_id = wc_gcc.transaction_id (+)
                    )Wiwc_ttl ,
                    ( bc_sql )bc
                  WHERE wiwc_ttl.batch_id_number = bc.batch_id_number (+)
                  AND wiwc_ttl.item_number       = bc.item_number (+)
                  ) wiwc_a
                GROUP BY wiwc_a.OPERATING_UNIT,
                  wiwc_a.LEGAL_ENTITY,
                  wiwc_a.BATCH_ID_NUMBER,
                  wiwc_a.ITEM_NUMBER,
                  wiwc_a.TRANSACTION_QUANTITY,
                  wiwc_a.TRANSACTION_ID,
                  (NVL(wiwc_a.TRANSACTION_QUANTITY,0))
                ) wiwc_b
              GROUP BY wiwc_b.OPERATING_UNIT,
                wiwc_b.LEGAL_ENTITY,
                wiwc_b.BATCH_ID_NUMBER
              ) wiwc_ttl ,
              ( bc_sql )bc,
              (SELECT batch_id_number                               AS BATCH_ID_NUMBER ,
                SUM(transaction_quantity)                           AS TRANSACTION_QUANTITY ,
                SUM((batch_size - transaction_quantity)* unit_cost) AS TTL_YLD_VAR ,
                SUM(batch_size)                                     AS TTL_BS
              FROM
                (SELECT A.batch_id_number                           AS BATCH_ID_NUMBER ,
                  A.transaction_quantity                            AS TRANSACTION_QUANTITY,
                  A.batch_size                                      AS BATCH_SIZE,
                  SUM(A.unit_cost)                                  AS UNIT_COST
                FROM
                  ( SELECT DISTINCT hou.name                        AS OPERATING_UNIT ,
                    ood.organization_code                           AS ORGANIZATION_CODE,
                    xep.name                                        AS LEGAL_ENTITY ,
                    mmt.transaction_date                            AS TRANSACTION_DATE ,
                    mmt.transaction_reference                       AS TRANSACTION_REFERENCE ,
                    mmt.transaction_id                              AS TRANSACTION_ID ,
                    mmt.transaction_type_id                         AS TRANSACTION_TYPE_ID ,
                    mtt.transaction_type_name                       AS TRANSACTION_TYPE_NAME ,
                    mmt.subinventory_code                           AS SUBINVENTORY_CODE ,
                    mmt.inventory_item_id                           AS INVENTORY_ITEM_ID ,
                    msib.segment1                                   AS ITEM_NUMBER ,
                    mmt.transaction_reference                       AS BATCH_ID_NUMBER ,
                    msib.item_type                                  AS ITEM_TYPE,
                    mmt.transaction_uom                             AS TRANSACTION_UOM ,
                    mmt.transaction_quantity                        AS TRANSACTION_QUANTITY,
                    (SELECT NVL(SUM(cmpnt_cost),0)
                    FROM
                      (SELECT DISTINCT mp_proc.organization_id ,
                        msi_proc.segment1 ,
                        ccd.inventory_item_id ,
                        ccd.cmpnt_cost ,
                        ccm.cost_cmpntcls_code ,
                        ccd.period_id
                      FROM CM_CMPT_DTL ccd,
                        CM_CMPT_MST ccm ,
                        mtl_system_items_b msi_proc,
                        mtl_parameters mp_proc
                      WHERE 1                   =1
                      AND ccd.inventory_item_id = msi_proc.inventory_item_id
                      AND ccd.organization_id   = msi_proc.organization_id
                      AND ccd.cost_cmpntcls_id  = ccm.cost_cmpntcls_id
                      AND ccd.organization_id   = mp_proc.organization_id
                      AND ccd.organization_id   = msi_proc.organization_id
                        --AND ccm.cost_cmpntcls_code IN ('RMW','MAT_OH')
                      AND ccd.delete_mark = 0
                      AND ccd.cost_level  = 1
                      ) proc_cost
                    WHERE 1                         =1
                    AND proc_cost.period_id         = gps.period_id
                    AND mmt.TRANSACTION_DATE       >= gps.START_DATE
                    AND mmt.TRANSACTION_DATE        < gps.END_DATE + 1
                    AND proc_cost.inventory_item_id = msib.inventory_item_id
                    AND proc_cost.organization_id   = msib.organization_id
                    AND proc_cost.organization_id   = mp.organization_id
                    )                                               AS UNIT_COST
                    ---------- Total Value
                    ,
                    0                                               AS TOTAL_VALUE
                    -------
                    ,
                    mmt.reason_id                                   AS REASON_ID,
                    mtt.attribute1                                  AS REASON_CODE ,
                    mmt.attribute1                                  AS LOT_NUMBER ,
                    mmt.attribute2                                  AS BATCH_COMPLETE ,
                    mmt.attribute3                                  AS BATCH_SIZE ,
                    mtt.attribute4                                  AS ATTRIBUTE4,
                    mmt.last_update_date                            AS LAST_UPDATE_DATE
                  FROM mtl_material_transactions mmt ,
                    mtl_system_items_b msib ,
                    mtl_transaction_types mtt ,
                    hr_operating_units hou ,
                    org_organization_definitions ood ,
                    xle_entity_profiles xep ,
                    mtl_parameters mp ,
                    gmf_xla_extract_headers gxeh
                    --, gmf_xla_extract_lines gxel
                    ,
                    gmf_period_statuses gps ,
                    (SELECT mmt_sub.transaction_reference           AS TRANSACTION_REFERENCE
                      --, mtt_sub.transaction_type_id AS TRANSACTION_TYPE_ID
                    FROM mtl_material_transactions mmt_sub ,
                      mtl_transaction_types mtt_sub
                    WHERE 1                                          =1
                    AND mtt_sub.attribute4                           = 'BATCH COMP'
                    AND mmt_sub.transaction_type_id                  = mtt_sub.transaction_type_id
                    AND ((mmt_sub.transaction_date                  >= TO_DATE(p_date_from,'DD-MON-YY'))
                    OR p_date_from                                  IS NULL)
                    AND ((mmt_sub.transaction_date                   < (TO_DATE(p_date_to,'DD-MON-YY') + 1))
                    OR p_date_to                                    IS NULL)
                    --AND (NVL(mmt_sub.ATTRIBUTE2, 'NULL')            = DECODE(p_batch_comp,'N','NULL',p_batch_comp)
                    --OR DECODE(p_batch_comp,'N','NULL',p_batch_comp) IS NULL)
                    AND (p_batch_comp   IS NULL OR (p_batch_comp   IS NOT NULL  
                                                    AND (NVL(mmt_sub.ATTRIBUTE2, 'NULL') = DECODE(p_batch_comp,'N','NULL',p_batch_comp))
                                                    )
                    )
                    )AA
                  WHERE 1                        =1
                  AND mmt.transaction_reference IN(AA.transaction_reference)
                    --AND    mmt.transaction_type_id = AA.transaction_type_id
                  AND mp.process_enabled_flag      = 'Y'
                  AND ((gxeh.valuation_cost_type   = 'STD')
                  OR gxeh.header_id               IS NULL)
                  AND mtt.attribute4              IN ('BATCH COMP')
                  AND mmt.transaction_reference   IS NOT NULL
                  AND mmt.inventory_item_id        = msib.inventory_item_id
                  AND hou.default_legal_context_id = ood.legal_entity
                  AND mmt.organization_id          = ood.organization_id
                  AND mmt.organization_id          = msib.organization_id
                  AND ood.legal_entity             = xep.legal_entity_id
                  AND mtt.transaction_type_id      = mmt.transaction_type_id
                  AND mp.organization_id           = mmt.organization_id
                  AND gxeh.transaction_id (+)      = mmt.transaction_id
                  AND gxeh.organization_id (+)     = mmt.organization_id
                  AND gxeh.inventory_item_id (+)   = mmt.inventory_item_id
                    -- AND    msib.SEGMENT1 = '100018028'
                    -- PARAMETERS ---
                  AND ((mmt.transaction_date    >= TO_DATE(p_date_from,'DD-MON-YY'))
                  OR p_date_from                IS NULL)
                  AND ((mmt.transaction_date     < (TO_DATE(p_date_to,'DD-MON-YY') + 1))
                  OR p_date_to                  IS NULL)
                  AND (mmt.transaction_reference = p_batch_id
                  OR p_batch_id                 IS NULL)
                  AND (mtt.attribute4            = p_trn_type
                  OR p_trn_type                 IS NULL)
                  AND (msib.segment1             = p_item_num
                  OR p_item_num                 IS NULL)
                  UNION ALL
                  SELECT DISTINCT hou.name                  AS OPERATING_UNIT ,
                    ood.organization_code                   AS ORGANIZATION_CODE,
                    xep.name                                AS LEGAL_ENTITY ,
                    mmt.transaction_date                    AS TRANSACTION_DATE,
                    mmt.transaction_reference               AS TRANSACTION_REFERENCE,
                    mmt.transaction_id                      AS TRANSACTION_ID,
                    mmt.transaction_type_id                 AS TRANSACTION_TYPE_ID,
                    mtt.transaction_type_name               AS TRANSACTION_TYPE_NAME,
                    mmt.subinventory_code                   AS SUBINVENTORY_CODE ,
                    mmt.inventory_item_id                   AS INVENTORY_ITEM_ID,
                    msib.segment1                           AS ITEM_NUMBER ,
                    mmt.transaction_reference               AS BATCH_ID_NUMBER ,
                    msib.item_type                          AS ITEM_TYPE,
                    mmt.transaction_uom                     AS TRANSACTION_UOM,
                    mmt.transaction_quantity                AS TRANSACTION_QUANTITY,
                    (SELECT NVL(SUM(item_cost),0)
                    FROM
                      (SELECT DISTINCT cicd.cost_element ,
                        cicd.Resource_code ,
                        cicd.usage_rate_or_amount ,
                        cicd.item_cost ,
                        msi_disc.segment1 ,
                        mp_disc.organization_code ,
                        cict.cost_type ,
                        msi_disc.inventory_item_id ,
                        mp_disc.organization_id
                      FROM cst_item_cost_details_v cicd,
                        mtl_system_items_b msi_disc,
                        mtl_parameters mp_disc,
                        cst_item_cost_type_v cict
                      WHERE 1                    =1
                      AND cicd.inventory_item_id = msi_disc.inventory_item_id
                      AND cicd.organization_id   = msi_disc.organization_id
                      AND cicd.organization_id   = mp_disc.organization_id
                      AND cicd.inventory_item_id = cict.inventory_item_id
                      AND cicd.organization_id   = cict.organization_id
                      --Modified for discreet org cost validation Khristine Austero 11/3/2016
                      AND UPPER(cict.cost_type)  = 'FROZEN' 
                      AND cicd.cost_type_id      = cict.cost_type_id
                        --AND    cicd.cost_element IN ('Material','Material Overhead')
                      AND cicd.level_type = 2
                      ) disc_cost
                    WHERE 1                         =1
                    AND disc_cost.inventory_item_id = msib.inventory_item_id
                    AND disc_cost.organization_id   = msib.organization_id
                    AND disc_cost.organization_id   = mp.organization_id
                    )                                       AS UNIT_COST
                    ---------- Total Value
                    --,mta.BASE_TRANSACTION_VALUE
                    ,
                    0                                       AS TOTAL_VALUE
                    -------
                    ,
                    mmt.reason_id                           AS REASON_ID,
                    mtt.attribute1                          AS REASON_CODE ,
                    mmt.attribute1                          AS LOT_NUMBER ,
                    mmt.attribute2                          AS BATCH_COMPLETE ,
                    mmt.attribute3                          AS BATCH_SIZE ,
                    mtt.attribute4                          AS ATTRIBUTE4,
                    mmt.last_update_date                    AS LAST_UPDATE_DATE
                  FROM mtl_material_transactions mmt ,
                    mtl_system_items_b msib ,
                    mtl_transaction_accounts mta ,
                    mtl_transaction_types mtt ,
                    hr_operating_units hou ,
                    org_organization_definitions ood ,
                    xle_entity_profiles xep ,
                    mtl_parameters mp ,
                    (SELECT mmt_sub.transaction_reference   AS TRANSACTION_REFERENCE
                      --, mtt_sub.TRANSACTION_TYPE_ID AS TRANSACTION_TYPE_ID
                    FROM mtl_material_transactions mmt_sub ,
                      mtl_transaction_types mtt_sub
                    WHERE 1                                          =1
                    AND mtt_sub.attribute4                           = 'BATCH COMP'
                    AND mmt_sub.transaction_type_id                  = mtt_sub.transaction_type_id
                    AND ((mmt_sub.transaction_date                  >= TO_DATE(p_date_from,'DD-MON-YY'))
                    OR p_date_from                                  IS NULL)
                    AND ((mmt_sub.transaction_date                   < (TO_DATE(p_date_to,'DD-MON-YY') + 1))
                    OR p_date_to                                    IS NULL)
                    --AND (NVL(mmt_sub.ATTRIBUTE2, 'NULL')             = DECODE(p_batch_comp,'N','NULL',p_batch_comp)
                    --OR DECODE(p_batch_comp,'N','NULL',p_batch_comp) IS NULL)
                    AND (p_batch_comp   IS NULL OR (p_batch_comp   IS NOT NULL  
                                                    AND (NVL(mmt_sub.ATTRIBUTE2, 'NULL') = DECODE(p_batch_comp,'N','NULL',p_batch_comp))
                                                    )
                         )
                    )AA
                  WHERE 1                        =1
                  AND mmt.transaction_reference IN(AA.transaction_reference)
                    --AND    mmt.transaction_type_id = AA.transaction_type_id
                  AND mp.process_enabled_flag        = 'N'
                  AND mtt.attribute4                IN ('BATCH COMP')
                  AND mmt.transaction_id             = mta.transaction_id (+)
                  AND mmt.inventory_item_id          = mta.inventory_item_id(+)
                  AND mmt.organization_id            = mta.organization_id (+)
                  AND (mta.accounting_line_type NOT IN ('2')
                  OR mta.transaction_id             IS NULL)
                  AND mmt.inventory_item_id          = msib.inventory_item_id
                  AND hou.default_legal_context_id   = ood.legal_entity
                  AND mmt.organization_id            = ood.organization_id
                  AND mmt.organization_id            = msib.organization_id
                  AND ood.legal_entity               = xep.legal_entity_id
                  AND mtt.transaction_type_id        = mmt.transaction_type_id
                  AND mp.organization_id             = mmt.organization_id
                  AND mmt.transaction_reference     IS NOT NULL
                    -- AND    msib.segment1 = '100018028'
                    -- PARAMETERS ---
                  AND (mmt.transaction_reference = p_batch_id
                  OR p_batch_id                 IS NULL)
                  AND (mtt.attribute4            = p_trn_type
                  OR p_trn_type                 IS NULL)
                  AND (msib.segment1             = p_item_num
                  OR p_item_num                 IS NULL)
                  )A ,
                  (SELECT msib.segment1                     AS ITEM_NUMBER ,
                    mmt.transaction_reference               AS BATCH_ID_NUMBER ,
                    MAX(mmt.last_update_date)               AS LAST_UPDATE_DATE
                  FROM mtl_material_transactions mmt ,
                    mtl_system_items_b msib ,
                    mtl_transaction_types mtt ,
                    hr_operating_units hou ,
                    org_organization_definitions ood ,
                    xle_entity_profiles xep ,
                    mtl_parameters mp ,
                    gmf_xla_extract_headers gxeh
                    --, gmf_xla_extract_lines gxel
                    ,
                    gmf_period_statuses gps ,
                    (SELECT mmt_sub.transaction_reference   AS TRANSACTION_REFERENCE
                      --, mtt_sub.transaction_type_id AS TRANSACTION_TYPE_ID
                    FROM mtl_material_transactions mmt_sub ,
                      mtl_transaction_types mtt_sub
                    WHERE 1                                          =1
                    AND mtt_sub.attribute4                           = 'BATCH COMP'
                    AND mmt_sub.transaction_type_id                  = mtt_sub.transaction_type_id
                    AND ((mmt_sub.transaction_date                  >= TO_DATE(p_date_from,'DD-MON-YY'))
                    OR p_date_from                                  IS NULL)
                    AND ((mmt_sub.transaction_date                   < (TO_DATE(p_date_to,'DD-MON-YY') + 1))
                    OR p_date_to                                    IS NULL)
                    --AND (NVL(mmt_sub.ATTRIBUTE2, 'NULL')             = DECODE(p_batch_comp,'N','NULL',p_batch_comp)
                    --OR DECODE(p_batch_comp,'N','NULL',p_batch_comp) IS NULL)
                    AND (p_batch_comp   IS NULL OR (p_batch_comp   IS NOT NULL  
                                                    AND (NVL(mmt_sub.ATTRIBUTE2, 'NULL') = DECODE(p_batch_comp,'N','NULL',p_batch_comp))
                                                    )
                      )
                    )AA
                  WHERE 1                        =1
                  AND mmt.transaction_reference IN(AA.transaction_reference)
                    --AND    mmt.transaction_type_id = AA.transaction_type_id
                  AND mp.process_enabled_flag      = 'Y'
                  AND ((gxeh.valuation_cost_type   = 'STD')
                  OR gxeh.header_id               IS NULL)
                  AND mtt.attribute4              IN ('BATCH COMP')
                  AND mmt.transaction_reference   IS NOT NULL
                  AND mmt.inventory_item_id        = msib.inventory_item_id
                  AND hou.default_legal_context_id = ood.legal_entity
                  AND mmt.organization_id          = ood.organization_id
                  AND mmt.organization_id          = msib.organization_id
                  AND ood.legal_entity             = xep.legal_entity_id
                  AND mtt.transaction_type_id      = mmt.transaction_type_id
                  AND mp.organization_id           = mmt.organization_id
                  AND gxeh.transaction_id (+)      = mmt.transaction_id
                  AND gxeh.organization_id (+)     = mmt.organization_id
                  AND gxeh.inventory_item_id (+)   = mmt.inventory_item_id
                    -- AND    msib.segment1 = '100018028'
                    -- PARAMETERS ---
                  AND ((mmt.transaction_date    >= TO_DATE(p_date_from,'DD-MON-YY'))
                  OR p_date_from                IS NULL)
                  AND ((mmt.transaction_date     < (TO_DATE(p_date_to,'DD-MON-YY') + 1))
                  OR p_date_to                  IS NULL)
                  AND (mmt.transaction_reference = p_batch_id
                  OR p_batch_id                 IS NULL)
                  AND (mtt.attribute4            = p_trn_type
                  OR p_trn_type                 IS NULL)
                  AND (msib.segment1             = p_item_num
                  OR p_item_num                 IS NULL)
                  GROUP BY msib.SEGMENT1,
                    mmt.TRANSACTION_REFERENCE
                  UNION ALL
                  SELECT msib.segment1                    AS ITEM_NUMBER ,
                    mmt.transaction_reference             AS BATCH_ID_NUMBER ,
                    MAX(mmt.last_update_date)             AS LAST_UPDATE_DATE
                  FROM mtl_material_transactions mmt ,
                    mtl_system_items_b msib ,
                    mtl_transaction_accounts mta ,
                    mtl_transaction_types mtt ,
                    hr_operating_units hou ,
                    org_organization_definitions ood ,
                    xle_entity_profiles xep ,
                    mtl_parameters mp ,
                    (SELECT mmt_sub.transaction_reference AS TRANSACTION_REFERENCE
                      --, mtt_sub.transaction_type_id AS TRANSACTION_TYPE_ID
                    FROM mtl_material_transactions mmt_sub ,
                      mtl_transaction_types mtt_sub
                    WHERE 1                                          =1
                    AND mtt_sub.attribute4                           = 'BATCH COMP'
                    AND mmt_sub.transaction_type_id                  = mtt_sub.transaction_type_id
                    AND ((mmt_sub.transaction_date                  >= TO_DATE(p_date_from,'DD-MON-YY'))
                    OR p_date_from                                  IS NULL)
                    AND ((mmt_sub.transaction_date                   < (TO_DATE(p_date_to,'DD-MON-YY') + 1))
                    OR p_date_to                                    IS NULL)
                    --AND (NVL(mmt_sub.ATTRIBUTE2, 'NULL')            = DECODE(p_batch_comp,'N','NULL',p_batch_comp)
                    --OR DECODE(p_batch_comp,'N','NULL',p_batch_comp) IS NULL)
                    AND (p_batch_comp   IS NULL OR (p_batch_comp   IS NOT NULL  
                                                    AND (NVL(mmt_sub.ATTRIBUTE2, 'NULL') = DECODE(p_batch_comp,'N','NULL',p_batch_comp))
                                                    )
                      )
                    )AA
                  WHERE 1                        =1
                  AND mmt.transaction_reference IN(AA.transaction_reference)
                    --AND    mmt.TRANSACTION_TYPE_ID = AA.TRANSACTION_TYPE_ID
                  AND mp.process_enabled_flag        = 'N'
                  AND mtt.attribute4                IN ('BATCH COMP')
                  AND mmt.transaction_id             = mta.transaction_id (+)
                  AND mmt.inventory_item_id          = mta.inventory_item_id(+)
                  AND mmt.organization_id            = mta.organization_id (+)
                  AND (mta.accounting_line_type     NOT IN ('2')
                  OR mta.transaction_id             IS NULL)
                  AND mmt.inventory_item_id          = msib.inventory_item_id
                  AND hou.default_legal_context_id   = ood.legal_entity
                  AND mmt.organization_id            = ood.organization_id
                  AND mmt.organization_id            = msib.organization_id
                  AND ood.legal_entity               = xep.legal_entity_id
                  AND mtt.transaction_type_id        = mmt.transaction_type_id
                  AND mp.organization_id             = mmt.organization_id
                  AND mmt.transaction_reference     IS NOT NULL
                    -- AND    msib.SEGMENT1 = '100018028'
                    -- PARAMETERS ---
                  AND ((mmt.transaction_date    >= TO_DATE(p_date_from,'DD-MON-YY'))
                  OR p_date_from                IS NULL)
                  AND ((mmt.transaction_date     < (TO_DATE(p_date_to,'DD-MON-YY') + 1))
                  OR p_date_to                  IS NULL)
                  AND (mmt.transaction_reference = p_batch_id
                  OR p_batch_id                 IS NULL)
                  AND (mtt.attribute4            = p_trn_type
                  OR p_trn_type                 IS NULL)
                  AND (msib.segment1             = p_item_num
                  OR p_item_num                 IS NULL)
                  GROUP BY msib.SEGMENT1,
                    mmt.TRANSACTION_REFERENCE
                  )B
                WHERE A.BATCH_ID_NUMBER = B.BATCH_ID_NUMBER
                AND A.ITEM_NUMBER       = B.ITEM_NUMBER
                AND A.LAST_UPDATE_DATE  = B.LAST_UPDATE_DATE
                GROUP BY A.BATCH_ID_NUMBER,
                  A.TRANSACTION_QUANTITY,
                  A.BATCH_SIZE
                )
              GROUP BY BATCH_ID_NUMBER
              )abc
            WHERE wiwc_ttl.BATCH_ID_NUMBER(+) = bc.BATCH_ID_NUMBER
            AND bc.BATCH_ID_NUMBER            = abc.BATCH_ID_NUMBER
            )
          )
        ORDER BY BATCH_ID_NUMBER ASC NULLS LAST,
          INDEX_ID ,
          ITEM_NUMBER ASC NULLS FIRST;
                
    TYPE rep_tab_type          IS TABLE OF c_gen_rep%ROWTYPE;
      
    l_rep_tab       rep_tab_type;    
    l_header            VARCHAR2(32000);        
                        
    v_step                     NUMBER;
    v_mess                     VARCHAR2(1000);
    
   BEGIN
    v_step := 1;
    --Print Report Header
    
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,' , , , , , ,  NBTY Yield and Material Variance Report');   
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,' , , , , INPUT PARAMETERS');  
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,' , , , , Date From: ,' || p_date_from ||' , , , , , , Report Creation Date : ' || TO_CHAR(SYSDATE, 'DD-MON-YY'));  
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,' , , , , Date To: ,' || p_date_to || ' ');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,' , , , , Input Batch ID Number: ,' || p_batch_id || ' ');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,' , , , , Input Item Number: ,' || p_item_num || ' ');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,' , , , , Batch Completed(Y/N/ALL): ,' || p_batch_comp || ' ');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,' ');
        
        l_header := 'Transaction Date,Transaction Type,Batch ID Number,Org Unit,Producing Org Unit,WIP Valuation Account ,Item Number,Unit of Measure (UOM),Qty Completed,Qty Yield,Theoretical Qty,Transaction Amount,Batch Completed (Y/N),MTL and MTL OH Unit Cost,Total Difference,Yield Variance Amount,Mtl Usage Variance Amount,Error ';

    v_step := 2;
    
     FND_FILE.PUT_LINE(FND_FILE.OUTPUT,l_header);       

        OPEN c_gen_rep(p_date_from 
                      ,p_date_to    
                      ,p_batch_id  
                      ,p_trn_type  
                      ,p_item_num  
                      ,p_batch_comp);
        
        FETCH c_gen_rep BULK COLLECT INTO l_rep_tab;
        
        FOR i in 1..l_rep_tab.COUNT
        
            LOOP
            
                FND_FILE.PUT_LINE(FND_FILE.OUTPUT, l_rep_tab(i).YIELD_REP );
                
            END LOOP;
            
        CLOSE c_gen_rep;
        
    v_step := 3;
    
    EXCEPTION
        WHEN OTHERS THEN
          v_mess := 'At step ['||v_step||'] - SQLCODE [' ||SQLCODE|| '] - ' ||substr(SQLERRM,1,100);
          x_errbuf  := v_mess;
          x_retcode := 2; 

   END main_proc;
        
END XXNBTY_INVREP02_YLD_USAGE_PKG;

/

show errors;
