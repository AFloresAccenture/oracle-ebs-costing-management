create or replace PACKAGE BODY PO_POXRCPPV_XMLP_PKG AS
/* $Header: POXRCPPVB.pls 120.1.12010000.4 2010/12/16 07:40:45 vlalwani ship $ */

function BeforeReport return boolean is
l_org     org_organization_definitions.organization_name%type;
l_sort     po_lookup_codes.displayed_field%type ;
l_cr_installed  boolean;
begin


if P_org_id is not null then

    select organization_name
    into l_org
    from org_organization_definitions
    where organization_id = P_org_id ;

    P_org_displayed := l_org;

else

    P_org_displayed := '' ;

end if;

if P_Trans_Date_to is not null then
    SELECT trunc(P_Trans_Date_to) +1 - .00001
    INTO P_Trans_Date_to
    FROM DUAL;
end if;
return (TRUE);
exception
when others then
	return(FALSE);
end;

function from_std_unitcost return character is
        wip_status    VARCHAR2(1);
begin
      if P_wip_status = 'I' then
         return (', wip_transactions wt');
      end if;

RETURN ' ';
end;

function where_std_unit_cost return character is
         wip_status  VARCHAR2(1);
begin
       if P_wip_status = 'I' then
     return('AND rct.transaction_id=wt.rcv_transaction_id AND wt.standard_rate_flag=1 '||
       'AND wt.transaction_type = 3 AND exists (select 1 from wip_transaction_accounts wta '||
       'where wta.transaction_id = wt.transaction_id and wta.accounting_line_type = 6)' );

       end if;

RETURN ' ';
end;

function get_std_unit_cost return character is
         wip_status    VARCHAR2(1);
begin
          if P_wip_status = 'I' then
             return(
               'wt.standard_resource_rate * decode(msi.outside_operation_uom_type,'||'''ASSEMBLY'''||', decode(wt.usage_rate_or_amount,0,1,wt.usage_rate_or_amount), 1)');
          end if;

RETURN null;
end;

function c_price_varianceformula(PO_Functional_Price in number, STD_UNIT_COST in number, moh_absorbed_per_unit in number, Quantity_received in number, c_precision in number) return number is
begin
 return ( round(( PO_Functional_Price - STD_UNIT_COST + moh_absorbed_per_unit ) * Quantity_received,c_precision));
end;

/* Support for landed cost management */
function c_price_varianceformula_lcm(functional_landed_cost in number, prior_landed_cost in number, quantity_received in number, c_precision in number) return number is
begin
 return ( round(( functional_landed_cost - prior_landed_cost) * Quantity_received,c_precision));
end;


function orderby_clauseFormula return VARCHAR2 is
begin

if P_ORDERBY = 'CATEGORY' then
    return(P_ORDERBY_CAT);
elsif P_ORDERBY = 'ITEM' then
    return(P_ORDERBY_ITEM);
elsif P_ORDERBY = 'VENDOR' then
    return('pov.vendor_name');
elsif P_ORDERBY = 'BUYER' then
return('papf.full_name');
end if;
RETURN NULL; end;

procedure get_precision is
begin
/*srw.attr.mask        :=  SRW.FORMATMASK_ATTR;*/null;

if P_qty_precision = 0 then /*srw.attr.formatmask  := '-NNN,NNN,NNN,NN0';*/null;

else
if P_qty_precision = 1 then /*srw.attr.formatmask  := '-NNN,NNN,NNN,NN0.0';*/null;

else
if P_qty_precision = 3 then /*srw.attr.formatmask  :=  '-NN,NNN,NNN,NN0.000';*/null;

else
if P_qty_precision = 4 then /*srw.attr.formatmask  :=   '-N,NNN,NNN,NN0.0000';*/null;

else
if P_qty_precision = 5 then /*srw.attr.formatmask  :=     '-NNN,NNN,NN0.00000';*/null;

else
if P_qty_precision = 6 then /*srw.attr.formatmask  :=      '-NN,NNN,NN0.000000';*/null;

else /*srw.attr.formatmask  :=  '-NNN,NNN,NNN,NN0.00';*/null;

end if; end if; end if; end if; end if; end if;
/*srw.set_attr(0,srw.attr);*/null;

end;

function c_price_variance1formula(PO_Functional_Price1 in number, STD_UNIT_COST1 in number, moh_absorbed_per_unit1 in number, Quantity_received1 in number, c_precision in number) return number is
begin
  return ( round(( PO_Functional_Price1 - STD_UNIT_COST1 + moh_absorbed_per_unit1 ) * Quantity_received1,c_precision));
end;

function AfterPForm return boolean is
begin

   if (P_TRANS_DATE_FROM is null and P_TRANS_DATE_TO is null) then
     P_TX_DATE_WHERE := 'AND 1=1';
     P_MTL_TX_DATE_WHERE := 'AND 1=1';

  elsif (P_TRANS_DATE_FROM is not null and P_TRANS_DATE_TO is null) then
     P_TX_DATE_WHERE := 'AND rct.transaction_date >= :P_TRANS_DATE_FROM';
     P_MTL_TX_DATE_WHERE := 'AND mmt.transaction_date >= :P_TRANS_DATE_FROM';

  elsif (P_TRANS_DATE_FROM is null and  P_TRANS_DATE_TO is not null) then
      P_TX_DATE_WHERE := 'AND rct.transaction_date <= :P_TRANS_DATE_TO ';
      P_MTL_TX_DATE_WHERE := 'AND mmt.transaction_date <= :P_TRANS_DATE_TO';

  elsif(P_TRANS_DATE_FROM is not null and P_TRANS_DATE_TO is not null) then
      P_TX_DATE_WHERE := 'AND rct.transaction_date between :P_TRANS_DATE_FROM and :P_TRANS_DATE_TO';
      P_MTL_TX_DATE_WHERE := 'AND mmt.transaction_date between :P_TRANS_DATE_FROM and :P_TRANS_DATE_TO';
  end if;

 If (P_VENDOR_FROM is null and P_VENDOR_TO is null) then
     P_VENDOR_NAME_WHERE := 'AND 1=1';
  elsif (P_VENDOR_FROM is not null and P_VENDOR_TO is null) then
     P_VENDOR_NAME_WHERE := 'AND pov.vendor_name >= :P_VENDOR_FROM';
  elsif (P_VENDOR_FROM is null and P_VENDOR_TO is not null) then
     P_VENDOR_NAME_WHERE := 'AND pov.vendor_name <= :P_VENDOR_TO';
  elsif (P_VENDOR_FROM is not null and P_VENDOR_TO is not null) then
     P_VENDOR_NAME_WHERE := 'AND pov.vendor_name between :P_VENDOR_FROM and :P_VENDOR_TO';
 end if;

begin
	select status
	into   P_wip_status
	from   fnd_product_installations
	where  application_id = 706;

	P_select_wip := get_std_unit_cost;
	P_from_wip := from_std_unitcost;
	P_where_wip := where_std_unit_cost;
exception
	when no_data_found then
		P_wip_status := '';
		P_select_wip := null;
		P_from_wip := ' ';
		P_where_wip := ' ';

end;
return (TRUE);
end;

function std_unit_cost_fformula(inventory_item_id in number, organization_id in varchar2, receipt_date in date, process_enabled_flag in varchar2, std_unit_cost in number, c_ext_precision in number) return number is
   l_result_code       VARCHAR2(30);
   l_return_status     VARCHAR2(30);
   l_msg_count         NUMBER;
   l_msg_data          VARCHAR2(2000);
   l_inventory_item_id NUMBER := inventory_item_id;
   l_organization_id   NUMBER := organization_id;
   l_transaction_date  DATE   := receipt_date;
   l_cost_mthd         VARCHAR2(15);
   l_cmpntcls          NUMBER;
   l_analysis_code     VARCHAR2(15);
   l_item_cost         NUMBER;
   l_no_of_rows        NUMBER;
begin
  IF process_enabled_flag = 'Y' THEN
  	  l_result_code := GMF_CMCOMMON.Get_Process_Item_Cost
        (    p_api_version        => 1
           , p_init_msg_list      => 'F'
           , x_return_status      => l_return_status
           , x_msg_count          => l_msg_count
           , x_msg_data           => l_msg_data
           , p_inventory_item_id  => l_inventory_item_id
           , p_organization_id    => l_organization_id
           , p_transaction_date   => l_transaction_date
           , p_detail_flag        => 1
           , p_cost_method        => l_cost_mthd
           , p_cost_component_class_id => l_cmpntcls
           , p_cost_analysis_code => l_analysis_code
           , x_total_cost         => l_item_cost
           , x_no_of_rows         => l_no_of_rows
        );

      IF l_result_code <> 1 THEN
    	  l_item_cost := 0;
      END IF;
  ELSE
      l_item_cost := std_unit_cost;
  END IF;

  return round(l_item_cost, c_ext_precision);
end;

function AfterReport return boolean is
begin

  return (TRUE);
end;


END PO_POXRCPPV_XMLP_PKG ;

/

show errors;
