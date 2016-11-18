create or replace PACKAGE      XXNBTY_SLA_SOURCE
AS

   FUNCTION GET_SUBINV_ACCOUNT(
      p_trx_id IN mtl_material_transactions.transaction_id%TYPE)
    RETURN NUMBER;
    
    FUNCTION GET_TRX_TYPE(
      p_trx_id IN mtl_material_transactions.transaction_id%TYPE)
    RETURN VARCHAR2;

   FUNCTION GET_PRODUCING_ORG(
      p_trx_id IN mtl_material_transactions.transaction_id%TYPE)
    RETURN VARCHAR2;

    FUNCTION GET_ITEM_FORM(
      p_trx_id IN mtl_material_transactions.transaction_id%TYPE)
    RETURN VARCHAR2;
     
    FUNCTION GET_SUBINV_ACCOUNT_REVAL(
      p_trx_id IN gmf_xla_extract_headers.transaction_id%TYPE)
    RETURN NUMBER;
  
 FUNCTION GET_SUBINV_ACCOUNT_ABS(
      p_trx_id IN mtl_material_transactions.transaction_id%TYPE)
    RETURN NUMBER;
    
    FUNCTION IS_NELLSON_SUPPLIER(
      p_trx_id IN mtl_material_transactions.transaction_id%TYPE,
      p_trx_date IN mtl_material_transactions.transaction_date%TYPE)
    RETURN VARCHAR2;
END XXNBTY_SLA_SOURCE;

/

show errors;
