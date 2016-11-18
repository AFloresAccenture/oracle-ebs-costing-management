create or replace PACKAGE body      XXNBTY_SLA_SOURCE
AS

   FUNCTION GET_SUBINV_ACCOUNT(
      p_trx_id IN mtl_material_transactions.transaction_id%TYPE)
    RETURN NUMBER
  IS
    v_trx_id mtl_material_transactions.transaction_id%TYPE;
    v_subinv_dist_id   NUMBER;
  BEGIN
   -- v_related_item_dist_id := RELATED_ITEM_LINE(p_invoice_dist_id);
   
   v_trx_id := p_trx_id;
   
 --  fnd_file.put_line (fnd_file.LOG, 'Inside XXNBTY_SLA_SOURCE.GEt_SUBINV_ACCOUNT' );
   
  -- fnd_file.put_line (fnd_file.LOG, 'Trx_id: '||v_trx_id );
   
   SELECT gcc.code_combination_id
   INTO v_subinv_dist_id
   FROM mtl_material_transactions mtl
        ,APPS.MTL_SUBINVENTORIES_ALL_V msa
        ,apps.gl_code_combinations gcc
  where mtl.ORGANIZATION_ID = msa.ORGANIZATION_ID
  and mtl.transaction_id = v_trx_id
  and msa.MATERIAL_ACCOUNT = gcc.code_combination_id
  and msa.secondary_inventory_name = mtl.SUBINVENTORY_CODE;
   
    --  fnd_file.put_line (fnd_file.LOG, 'Material Account is: '||v_subinv_dist_id );
    
    RETURN(v_subinv_dist_id);
  EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN (0);
     fnd_file.put_line (fnd_file.LOG, 'EXCEPTION NO_DATA_FOUND: '||SQLERRM );
  WHEN OTHERS THEN
    RETURN (0);
     fnd_file.put_line (fnd_file.LOG, 'EXCEPTION WHEN OTHERS: '||SQLERRM );
  END GET_SUBINV_ACCOUNT;
  
   FUNCTION GET_TRX_TYPE(
      p_trx_id IN mtl_material_transactions.transaction_id%TYPE)
    RETURN VARCHAR2
  IS
    v_trx_id mtl_material_transactions.transaction_id%TYPE;
    v_trx_type   VARCHAR2(250);
  BEGIN
   -- v_related_item_dist_id := RELATED_ITEM_LINE(p_invoice_dist_id);
   
   v_trx_id := p_trx_id;
   
  -- fnd_file.put_line (fnd_file.LOG, 'Inside XXNBTY_SLA_SOURCE.GET_TRX_TYPE' );
   
  -- fnd_file.put_line (fnd_file.LOG, 'Trx_id: '||v_trx_id );
   
   SELECT mtt.ATTRIBUTE4 
   INTO v_trx_type
   FROM mtl_material_transactions mmt,
        MTL_TRANSACTION_TYPES mtt
   WHERE TRANSACTION_id = v_trx_id
   AND mmt.TRANSACTION_TYPE_ID = mtt.TRANSACTION_TYPE_ID;
     
    --  fnd_file.put_line (fnd_file.LOG, 'Trx Type: '||v_trx_type );
    
    RETURN(v_trx_type);
  EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN NULL;
     fnd_file.put_line (fnd_file.LOG, 'EXCEPTION NO_DATA_FOUND: '||SQLERRM );
  WHEN OTHERS THEN
    RETURN NULL;
     fnd_file.put_line (fnd_file.LOG, 'EXCEPTION WHEN OTHERS: '||SQLERRM );
  END GET_TRX_TYPE;
  
     FUNCTION GET_ITEM_FORM(
      p_trx_id IN mtl_material_transactions.transaction_id%TYPE)
    RETURN VARCHAR2
  IS
    v_trx_id mtl_material_transactions.transaction_id%TYPE;
    v_item_form   VARCHAR2(250);
  BEGIN
   -- v_related_item_dist_id := RELATED_ITEM_LINE(p_invoice_dist_id);
   
   v_trx_id := p_trx_id;
   
   --fnd_file.put_line (fnd_file.LOG, 'Inside XXNBTY_SLA_SOURCE.GET_ITEM_FORM' );
   
  -- fnd_file.put_line (fnd_file.LOG, 'Trx_id: '||v_trx_id );
   
   SELECT C_EXT_ATTR2
    INTO v_item_form
    FROM apps.ego_mtl_sy_items_ext_b emi,
         apps.ego_attr_groups_v eag,
         apps.MTL_SYSTEM_ITEMS_B msi,
         mtl_material_transactions mmt
    WHERE mmt.TRANSACTION_id = v_trx_id
    AND msi.organization_id = 122
    AND emi.inventory_item_id = msi.inventory_item_id
    AND emi.attr_group_id = eag.attr_group_id
    AND eag.attr_group_name = 'NBTY_BULK_MFG'
    AND mmt.INVENTORY_ITEM_ID = msi.INVENTORY_ITEM_ID;
        
    --  fnd_file.put_line (fnd_file.LOG, 'Item Form: '||v_item_form );
    
    RETURN(v_item_form);
  EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN NULL;
     fnd_file.put_line (fnd_file.LOG, 'EXCEPTION NO_DATA_FOUND: '||SQLERRM );
  WHEN OTHERS THEN
    RETURN NULL;
     fnd_file.put_line (fnd_file.LOG, 'EXCEPTION WHEN OTHERS: '||SQLERRM );
  END GET_ITEM_FORM;
  
     FUNCTION GET_SUBINV_ACCOUNT_REVAL(
      p_trx_id IN gmf_xla_extract_headers.transaction_id%TYPE)
    RETURN NUMBER
  IS
    v_trx_id gmf_xla_extract_headers.transaction_id%TYPE;
    v_subinv_dist_id   NUMBER;
  BEGIN
   -- v_related_item_dist_id := RELATED_ITEM_LINE(p_invoice_dist_id);
   
   v_trx_id := p_trx_id;
   
   --fnd_file.put_line (fnd_file.LOG, 'Inside XXNBTY_SLA_SOURCE.GET_SUBINV_ACCOUNT_REVAL' );
   
   --fnd_file.put_line (fnd_file.LOG, 'Trx_id: '||v_trx_id );
   
   SELECT distinct gcc.code_combination_id
   INTO v_subinv_dist_id
   FROM gmf_xla_extract_lines gxel
   ,gmf_xla_extract_headers gxeh
        ,APPS.MTL_SUBINVENTORIES_ALL_V msa
        ,apps.gl_code_combinations gcc
  where gxel.ORGANIZATION_ID = msa.ORGANIZATION_ID
  and gxeh.transaction_id = v_trx_id
  and gxeh.header_id = gxel.header_id
  and msa.MATERIAL_ACCOUNT = gcc.code_combination_id
  and msa.secondary_inventory_name = gxel.SUBINVENTORY_CODE
  and gxel.journal_line_type = 'INV';
   
     -- fnd_file.put_line (fnd_file.LOG, 'Material Account is: '||v_subinv_dist_id );
    
    RETURN(v_subinv_dist_id);
  EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN (0);
     fnd_file.put_line (fnd_file.LOG, 'EXCEPTION NO_DATA_FOUND: '||SQLERRM );
  WHEN OTHERS THEN
    RETURN (0);
     fnd_file.put_line (fnd_file.LOG, 'EXCEPTION WHEN OTHERS: '||SQLERRM );
  END GET_SUBINV_ACCOUNT_REVAL;
  
     FUNCTION GET_SUBINV_ACCOUNT_ABS(
      p_trx_id IN mtl_material_transactions.transaction_id%TYPE)
    RETURN NUMBER
  IS
    v_trx_id mtl_material_transactions.transaction_id%TYPE;
    v_subinv_dist_id   NUMBER;
  BEGIN
   -- v_related_item_dist_id := RELATED_ITEM_LINE(p_invoice_dist_id);
   
   v_trx_id := p_trx_id;
   
   --fnd_file.put_line (fnd_file.LOG, 'Inside XXNBTY_SLA_SOURCE.GEt_SUBINV_ACCOUNT_ABS' );
   
  -- fnd_file.put_line (fnd_file.LOG, 'Trx_id: '||v_trx_id );
   
  SELECT gcc.code_combination_id
   INTO v_subinv_dist_id
   FROM mtl_material_transactions mtl
        ,APPS.MTL_SUBINVENTORIES_ALL_V msa
        ,apps.gl_code_combinations gcc
        ,apps.mtl_parameters mp
  where mp.ORGANIZATION_ID = msa.ORGANIZATION_ID
  and mtl.transaction_id = v_trx_id
  and msa.MATERIAL_ACCOUNT = gcc.code_combination_id
  and mp.organization_code = mtl.attribute5
  and msa.secondary_inventory_name = 'RAW MTL';
   
    --  fnd_file.put_line (fnd_file.LOG, 'Material Account is: '||v_subinv_dist_id );
    
    RETURN(v_subinv_dist_id);
  EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN (0);
     fnd_file.put_line (fnd_file.LOG, 'EXCEPTION NO_DATA_FOUND: '||SQLERRM );
  WHEN OTHERS THEN
    RETURN (0);
     fnd_file.put_line (fnd_file.LOG, 'EXCEPTION WHEN OTHERS: '||SQLERRM );
  END GET_SUBINV_ACCOUNT_ABS;

   FUNCTION GET_PRODUCING_ORG(
      p_trx_id IN mtl_material_transactions.transaction_id%TYPE)
    RETURN VARCHAR2
  IS
    v_trx_id mtl_material_transactions.transaction_id%TYPE;
    v_producing_org   VARCHAR2(250);
  BEGIN
   -- v_related_item_dist_id := RELATED_ITEM_LINE(p_invoice_dist_id);
   
   v_trx_id := p_trx_id;
   
   --fnd_file.put_line (fnd_file.LOG, 'Inside XXNBTY_SLA_SOURCE.GET_PRODUCING_ORG' );
   
   --fnd_file.put_line (fnd_file.LOG, 'Trx_id: '||v_trx_id );
   
   SELECT mmt.ATTRIBUTE5 
   INTO v_producing_org
   FROM mtl_material_transactions mmt,
        MTL_TRANSACTION_TYPES mtt
   WHERE TRANSACTION_id = v_trx_id
   AND mmt.TRANSACTION_TYPE_ID = mtt.TRANSACTION_TYPE_ID;
     
     -- fnd_file.put_line (fnd_file.LOG, 'Trx Type: '||v_producing_org );
    
    RETURN(v_producing_org);
  EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN NULL;
     fnd_file.put_line (fnd_file.LOG, 'EXCEPTION NO_DATA_FOUND: '||SQLERRM );
  WHEN OTHERS THEN
    RETURN NULL;
     fnd_file.put_line (fnd_file.LOG, 'EXCEPTION WHEN OTHERS: '||SQLERRM );
  END GET_PRODUCING_ORG;

  FUNCTION IS_NELLSON_SUPPLIER(
      p_trx_id IN mtl_material_transactions.transaction_id%TYPE,
      p_trx_date IN mtl_material_transactions.transaction_date%TYPE)
    RETURN VARCHAR2
  IS
    v_trx_id mtl_material_transactions.transaction_id%TYPE;
    v_trx_date mtl_material_transactions.transaction_date%TYPE;
    v_supplier_num ap_suppliers.segment1%TYPE;
    v_nellson_supplier   VARCHAR2(1);
  BEGIN
   -- v_related_item_dist_id := RELATED_ITEM_LINE(p_invoice_dist_id);
   
   v_trx_id := p_trx_id;
   v_trx_date := p_trx_date;
   
   --fnd_file.put_line (fnd_file.LOG, 'Inside XXNBTY_SLA_SOURCE.GET_PRODUCING_ORG' );
   
  -- fnd_file.put_line (fnd_file.LOG, 'Trx_id: '||v_trx_id );
   --fnd_file.put_line (fnd_file.LOG, 'Trx Type: '||v_trx_date );
   
   SELECT asp.SEGMENT1 
   INTO v_supplier_num
   FROM  mtl_material_transactions mmt,
         po_headers_all pha,
         mtl_transaction_types mtt,
         ap_suppliers asp
   WHERE TRANSACTION_id = v_trx_id
           AND mmt.transaction_type_id = mtt.TRANSACTION_TYPE_ID
         AND mmt.transaction_source_id = pha.po_header_id
         AND pha.vendor_id = asp.vendor_id
         AND mmt.TRANSACTION_TYPE_ID = mtt.TRANSACTION_TYPE_ID;
    BEGIN     
       SELECT 'Y' into v_nellson_supplier
       FROM fnd_lookup_values
       WHERE LOOKUP_TYPE = 'XXNBTY_NELLSON_SUPPLIERS'
       AND view_application_id = 700
       AND lookup_code = v_supplier_num
       AND trunc(nvl(end_date_active,sysdate+1)) >= trunc(v_trx_date);  
     
    EXCEPTION
       WHEN NO_DATA_FOUND THEN
       v_nellson_supplier := 'N';
       RETURN v_nellson_supplier;
    END;
     -- fnd_file.put_line (fnd_file.LOG, 'Trx Type: '||v_producing_org );
    
    RETURN(v_nellson_supplier);
  EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN NULL;
     fnd_file.put_line (fnd_file.LOG, 'EXCEPTION NO_DATA_FOUND: '||SQLERRM );
  WHEN OTHERS THEN
    RETURN NULL;
     fnd_file.put_line (fnd_file.LOG, 'EXCEPTION WHEN OTHERS: '||SQLERRM );
  END IS_NELLSON_SUPPLIER;
 
 END XXNBTY_SLA_SOURCE;
 
 /
 
 show errors;
 