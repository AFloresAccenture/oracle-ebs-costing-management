create or replace PACKAGE PO_POXRCPPV_XMLP_PKG AUTHID CURRENT_USER AS
/* $Header: POXRCPPVS.pls 120.1.12010000.3 2010/10/28 17:30:18 vlalwani ship $ */
    P_title varchar2(50);
    P_CONC_REQUEST_ID   number;
    P_VENDOR_FROM   varchar2(240);
    P_VENDOR_TO varchar2(240);
    P_FLEX_CAT  varchar2(31000);
    P_FLEX_ITEM varchar2(800);
    P_TRANS_DATE_FROM   date;
    P_TRANS_DATE_TO date;
    P_DESTINATION_TYPE  varchar2(40);
    P_orderby   varchar2(40);
    P_ORDERBY_CAT   varchar2(298);
    P_ORDERBY_ITEM  varchar2(298);
    P_qty_precision varchar2(40);
    P_CATEGORY_FROM varchar2(900);
    P_CATEGORY_TO   varchar2(900);
    P_STRUCT_NUM    number;
    P_WHERE_CAT varchar2(2000);
    P_wip_status    varchar2(32767);
    P_ORG_ID    varchar2(40);
    P_org_displayed varchar2(240);
    P_TX_DATE_WHERE varchar2(500);
    P_select_wip varchar2(2000);
    P_from_wip varchar2(500);
    P_where_wip varchar2(2000);
    P_MTL_TX_DATE_WHERE varchar2(1000);
    P_VENDOR_NAME_WHERE varchar2(1000);
    P_ITEM_TYPE varchar2(100);
    function BeforeReport return boolean  ;
    function from_std_unitcost return character  ;
    function where_std_unit_cost return character  ;
    function get_std_unit_cost return character  ;
    function c_price_varianceformula(PO_Functional_Price in number, STD_UNIT_COST in number, moh_absorbed_per_unit in number, Quantity_received in number, c_precision in number) return number  ;
    function orderby_clauseFormula return VARCHAR2  ;
    procedure get_precision  ;
    function c_price_variance1formula(PO_Functional_Price1 in number, STD_UNIT_COST1 in number, moh_absorbed_per_unit1 in number, Quantity_received1 in number, c_precision in number) return number  ;
    function AfterPForm return boolean  ;
    function std_unit_cost_fformula(inventory_item_id in number, organization_id in varchar2, receipt_date in date, process_enabled_flag in varchar2, std_unit_cost in number, c_ext_precision in number) return number  ;
    function AfterReport return boolean  ;
        /* Support for landed cost management */
        function c_price_varianceformula_lcm(functional_landed_cost in number, prior_landed_cost in number, quantity_received in number, c_precision in number) return number;

END PO_POXRCPPV_XMLP_PKG;

/

show errors;
