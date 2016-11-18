create or replace PACKAGE BODY   XXNBTY_OPMEXT02_YIELD_CONV_PKG
IS
----------------------------------------------------------------------------------------------------
/*
Package Name: XXNBTY_OPMEXT02_YIELD_CONV_PKG
Author's Name: Albert John Flores
Date written: 26-Aug-2016
RICEFW Object: EXT02
Description: This program creates process operations, routings and automates yield costs load
Program Style: 

Maintenance History: 

Date            Issue#      Name                    Remarks 
-----------     ------      -----------             ------------------------------------------------
26-Aug-2016                 Albert Flores           Initial Development
30-Sep-2016					Albert Flores			Added Yield Res Update

*/
----------------------------------------------------------------------------------------------------  
PROCEDURE main_proc(o_errbuf      OUT VARCHAR2, 
						  o_retcode     OUT NUMBER)

IS
----------------------------------------------------------------------------------------------------
/*
Package Name: XXNBTY_OPMEXT02_YIELD_CONV_PKG
Author's Name: Albert John Flores
Date written: 26-Aug-2016
RICEFW Object: EXT02
Description: this procedure updates resource_usage on existing resources
Program Style: 

Maintenance History: 

Date            Issue#      Name                    Remarks 
-----------     ------      -----------             ------------------------------------------------
26-Aug-2016                 Albert Flores           Initial Development

*/
----------------------------------------------------------------------------------------------------  

	v_step                     NUMBER;
    v_mess                     VARCHAR2(500);
	l_error         		   EXCEPTION;

BEGIN

	v_step := 1;
	--call create operations/resources
	create_oprt_rsrc(o_errbuf, o_retcode);
	IF o_retcode = 2 THEN
		RAISE l_error;
	END IF;
	
	--call update resources
	update_resource(o_errbuf, o_retcode);
	IF o_retcode = 2 THEN
		RAISE l_error;
	END IF;	

	
EXCEPTION
  WHEN l_error THEN
        FND_FILE.PUT_LINE(FND_FILE.LOG, 'ERROR - [' || o_errbuf || ']' );
        o_retcode := o_retcode;
		
  WHEN OTHERS THEN
  o_retcode := 2;
  v_mess := 'At step ['||v_step||'] for procedure open_period - SQLCODE [' ||SQLCODE|| '] - ' ||substr(SQLERRM,1,100);
  o_errbuf := v_mess;
  
END main_proc;

PROCEDURE create_oprt_rsrc(o_errbuf      OUT VARCHAR2, 
						   o_retcode     OUT NUMBER)

IS
----------------------------------------------------------------------------------------------------
/*
Package Name: XXNBTY_OPMEXT02_YIELD_CONV_PKG
Author's Name: Albert John Flores
Date written: 26-Aug-2016
RICEFW Object: EXT02
Description: this procedure creates process operations and resources
Program Style: 

Maintenance History: 

Date            Issue#      Name                    Remarks 
-----------     ------      -----------             ------------------------------------------------
26-Aug-2016                 Albert Flores           Initial Development

*/
----------------------------------------------------------------------------------------------------  

	CURSOR c_operation 
	IS
	   SELECT DISTINCT oprn_no
			  , oprn_desc
			  , item_number
			  , process_qty_uom
			  , oprn_vers
			  , delete_mark
			  , effective_start_date
			  , operation_status
			  , organization_code
			  , activity
			  , offset_interval
			  , activity_factor
			  , resources
			  , process_qty
			  , resource_process_uom
			  , resource_usage
			  , resource_usage_uom
			  , cost_cmpntcls_id
			  , cost_analysis_code
			  , resource_count
			  , scale_type
			  , rowid
		 FROM xxnbty.xxnbty_operations_stg_tbl
		WHERE process_flag IS NULL;

   l_operations      			gmd_operations%ROWTYPE;
   l_oprn_actv_tbl   			gmd_operations_pub.gmd_oprn_activities_tbl_type;
   l_oprn_rsrc_tbl   			gmd_operation_resources_pub.gmd_oprn_resources_tbl_type;
   
   l_init_msg_list   			BOOLEAN;
   l_commit          			BOOLEAN;
   l_count						NUMBER;
   l_return_status   		    VARCHAR2 (1);
   l_data						VARCHAR2(2000);
   l_error_flag					BOOLEAN := FALSE;
   l_error_msg					VARCHAR2(2000);
   l_gen_uom					VARCHAR2(5);
   
   v_org_id						NUMBER;
   v_count           			NUMBER;
   v_resources                  VARCHAR2(100);
   v_process_qty                NUMBER;
   v_resource_process_uom       VARCHAR2(5);
   v_resource_usage             NUMBER;
   v_resource_usage_uom         VARCHAR2(5);
   v_cost_cmpntcls_id           NUMBER;
   v_cost_analysis_code         VARCHAR2(5);
   v_prim_rsrc_ind              NUMBER;
   v_resource_count             NUMBER;
   v_scale_type                 NUMBER;
   v_offset_interval            NUMBER;
   v_oprn_line_id				NUMBER;
    
	v_step                     NUMBER;
    v_mess                     VARCHAR2(500);
	
BEGIN

	v_step := 1;

	--Initialize Instance
	fnd_global.apps_initialize (user_id           => g_user,
                               resp_id            => g_resp_id,
                               resp_appl_id       => g_resp_appl_id
							    );

								
	l_init_msg_list := TRUE;
    l_commit := TRUE;							
	
    v_step := 2;
	
	FOR l_oprn IN c_operation
	LOOP 
	
	v_step := 3;
	
		--Initialize variables
		l_gen_uom							:= NULL;
		v_org_id 							:= NULL;
		l_operations.oprn_no 				:= NULL;
		l_operations.oprn_desc 				:= NULL;
		l_operations.process_qty_uom 		:= NULL;
		l_operations.oprn_vers 				:= NULL;
		l_operations.delete_mark 			:= NULL;
		l_operations.effective_start_date 	:= NULL;
		l_operations.operation_status 		:= NULL;
		l_operations.owner_organization_id 	:= NULL;
		l_oprn_actv_tbl.DELETE;
		--Initialize variables
		v_resources                		    := NULL;
		v_process_qty              		    := NULL;
		v_resource_process_uom     		    := NULL;
		v_resource_usage           		    := NULL;
		v_resource_usage_uom       		    := NULL;
		v_cost_cmpntcls_id         		    := NULL;
		v_cost_analysis_code       		    := NULL;
		v_resource_count           		    := NULL;
		v_scale_type               		    := NULL;
		v_offset_interval          		    := NULL;
		v_prim_rsrc_ind            		    := NULL;
		v_oprn_line_id             		    := NULL;
		
		l_oprn_rsrc_tbl.DELETE;
		l_error_flag			   		    := FALSE;
		l_error_msg				   			:= NULL;
		l_count						        := NULL;
		l_return_status   		   			:= NULL;
		v_count								:= NULL;
		
		--Derive organization id from organization code
		BEGIN
		
			SELECT mp.organization_id
			INTO	v_org_id
			FROM 	mtl_parameters mp
			WHERE  mp.organization_code = l_oprn.organization_code;
			
		EXCEPTION
			WHEN OTHERS THEN
			l_error_flag := TRUE;
			l_error_msg	 := l_error_msg ||'Error in deriving organization_id;';
		
		END;
						 
		 --Derive uom code
		BEGIN
		 
			SELECT DISTINCT primary_uom_Code
			INTO l_gen_uom
			FROM mtl_system_items
			WHERE segment1 = l_oprn.item_number; 
			
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					l_error_flag := TRUE;
					l_error_msg	 := l_error_msg ||'Error in deriving UOM code;';
		 
		END;	
	
	v_step := 4;
	
		l_operations.oprn_no 				:= l_oprn.oprn_no;
		l_operations.oprn_desc 				:= l_oprn.oprn_desc;
		l_operations.process_qty_uom 		:= l_gen_uom;
		l_operations.oprn_vers 				:= l_oprn.oprn_vers;
		l_operations.delete_mark 			:= l_oprn.delete_mark;
		l_operations.effective_start_date 	:= l_oprn.effective_start_date;
		l_operations.operation_status 		:= l_oprn.operation_status;
		l_operations.owner_organization_id 	:= v_org_id;
		
		l_oprn_actv_tbl(1).activity 		:= l_oprn.activity;
		l_oprn_actv_tbl(1).offset_interval 	:= l_oprn.offset_interval;
		l_oprn_actv_tbl(1).activity_factor 	:= l_oprn.activity_factor;
		l_oprn_actv_tbl(1).delete_mark 		:= l_oprn.delete_mark;
		
		 --Derive for primary resource indicator 1 = Primary , 0 = Secondary
		 --If an operation has a primary resource, indicator will be 0
		 BEGIN
		 
			SELECT DISTINCT 0 , act.oprn_line_id
			INTO v_prim_rsrc_ind, v_oprn_line_id
			FROM apps.gmd_operations_vl po, gmd_operation_activities act, gmd_operation_resources pr, mtl_parameters mp
			WHERE po.oprn_id = act.oprn_id 
			AND	  act.oprn_line_id = pr.oprn_line_id 
			AND	  po.owner_organization_id = mp.organization_id
			AND   po.oprn_no = l_oprn.oprn_no; 
			
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
				v_prim_rsrc_ind := 1;
			
		 END;
		 
		 --derive cost_cmpntcls_id 
		 BEGIN
		 
			SELECT DISTINCT pr.cost_cmpntcls_id
			INTO v_cost_cmpntcls_id
			FROM gmd_operation_resources pr
			WHERE pr.resources = l_oprn.resources; 
			
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					l_error_flag := TRUE;
					l_error_msg	 := l_error_msg ||'Error in deriving cost_cmpntcls_id;';
			
		 END;
				 
	v_step := 8;
	
			 l_oprn_rsrc_tbl (1).activity 				:= l_oprn.activity;
			 l_oprn_rsrc_tbl (1).resources 				:= l_oprn.resources;
			 l_oprn_rsrc_tbl (1).process_qty 			:= l_oprn.process_qty;
			 l_oprn_rsrc_tbl (1).resource_process_uom 	:= l_gen_uom;
			 l_oprn_rsrc_tbl (1).resource_usage 		:= l_oprn.resource_usage;
			 l_oprn_rsrc_tbl (1).resource_usage_uom 	:= l_gen_uom;
			 l_oprn_rsrc_tbl (1).cost_cmpntcls_id 		:= v_cost_cmpntcls_id;
			 l_oprn_rsrc_tbl (1).cost_analysis_code 	:= l_oprn.cost_analysis_code;
			 l_oprn_rsrc_tbl (1).prim_rsrc_ind 			:= v_prim_rsrc_ind;
			 l_oprn_rsrc_tbl (1).resource_count 		:= l_oprn.resource_count;
			 l_oprn_rsrc_tbl (1).scale_type 			:= l_oprn.scale_type;
			 l_oprn_rsrc_tbl (1).offset_interval 		:= l_oprn.offset_interval;
	
	v_step := 10;
	IF l_error_flag = TRUE THEN 
	
		NULL;
		
	ELSE 
	
		IF v_prim_rsrc_ind = 1 THEN
		
			gmd_operations_pub.insert_operation (
								p_api_version        => 1.0,
								p_init_msg_list      => l_init_msg_list,
								p_commit             => l_commit,
								p_operations         => l_operations,
								p_oprn_actv_tbl      => l_oprn_actv_tbl,
								p_oprn_rsrc_tbl      => l_oprn_rsrc_tbl,
								x_message_count      => l_count,
								x_return_status      => l_return_status,
								x_message_list       => l_data
							   ); 
		    
			UPDATE gmd_operations_b
			SET operation_status = 700
			WHERE operation_status = 100
			AND   oprn_no = l_oprn.oprn_no; 
			
			IF l_return_status = 'E' OR l_return_status = 'U' THEN
	
				l_error_flag := TRUE;
				l_error_msg	 := l_error_msg ||l_data || ';';
		
			END IF;
		
		ELSIF v_prim_rsrc_ind = 0 THEN
	
	v_step := 11;
	
			gmd_operation_resources_pub.insert_operation_resources (
								p_api_version 		=> 1.0,
								p_init_msg_list	 	=> l_init_msg_list,
								p_commit			=> l_commit,
								p_oprn_line_id		=> v_oprn_line_id,
								p_oprn_rsrc_tbl		=> l_oprn_rsrc_tbl,
								x_message_count 	=> l_count,
								x_message_list 		=> l_return_status,
								x_return_status		=> l_data
                                       );  
		
			IF l_return_status = 'E' OR l_return_status = 'U' THEN
	
				l_error_flag := TRUE;
				l_error_msg	 := l_error_msg ||l_data || ';';
		
			END IF;
		
		END IF;
	
	END IF;

	IF l_error_flag = TRUE THEN	
		--tag records from staging table as processed
		UPDATE xxnbty.xxnbty_operations_stg_tbl
		SET process_flag = 'Y'
			,error_description = l_error_msg
			,last_update_date  = SYSDATE
			,last_updated_by   = fnd_global.user_id
		WHERE rowid = l_oprn.rowid;
	
	ELSE
		
		--tag records from staging table as processed
		UPDATE xxnbty.xxnbty_operations_stg_tbl
		SET process_flag = 'Y'
			,last_update_date  = SYSDATE
			,last_updated_by   = fnd_global.user_id
		WHERE rowid = l_oprn.rowid;
		
	END IF;
	
	COMMIT;
	
	v_step := 12;	
	
	END LOOP;
    
EXCEPTION  
  WHEN OTHERS THEN
  o_retcode := 2;
  v_mess := 'At step ['||v_step||'] for procedure open_period - SQLCODE [' ||SQLCODE|| '] - ' ||substr(SQLERRM,1,100);
  o_errbuf := v_mess;

END create_oprt_rsrc;

PROCEDURE update_resource(o_errbuf      OUT VARCHAR2, 
						  o_retcode     OUT NUMBER)

IS
----------------------------------------------------------------------------------------------------
/*
Package Name: XXNBTY_OPMEXT02_YIELD_CONV_PKG
Author's Name: Albert John Flores
Date written: 26-Aug-2016
RICEFW Object: EXT02
Description: this procedure updates resource_usage on existing resources
Program Style: 

Maintenance History: 

Date            Issue#      Name                    Remarks 
-----------     ------      -----------             ------------------------------------------------
26-Aug-2016                 Albert Flores           Initial Development

*/
----------------------------------------------------------------------------------------------------  

CURSOR c_upd_res
IS
SELECT  rowid,
		item_number,
		resources,
		column_to_upd,
		new_value,
		error_description
FROM xxnbty.xxnbty_upd_res_stg
WHERE process_flag IS NULL;

   c_get_operations	  		   SYS_REFCURSOR;
   l_api_version     		   NUMBER := 1;
   l_init_msg_list   		   BOOLEAN;
   l_commit          		   BOOLEAN;
   l_oprn_line_id	 		   NUMBER;
   l_resources		 		   VARCHAR2(100);
   l_activity		 		   VARCHAR2(100);
   l_item_num		 		   VARCHAR2(100);
   l_update_table    		   gmd_operation_resources_pub.update_tbl_type;
   l_count           		   NUMBER;
   l_return_status   		   VARCHAR2 (1);
   l_data            		   VARCHAR2 (2000);
   l_status          		   VARCHAR2 (1);
   l_query					   VARCHAR2(2000);
   l_error_flag				   BOOLEAN := FALSE;
   
   TYPE oprn_typ   	   IS RECORD(oprn_line_id NUMBER,	activity VARCHAR2(100));
   TYPE oprn_tbl	   IS TABLE OF oprn_typ;
   
   l_oprn_ids					   oprn_tbl;

	v_step                     NUMBER;
    v_mess                     VARCHAR2(500);
	
BEGIN

	v_step := 1;

	--Initialize Instance
	fnd_global.apps_initialize (user_id           => g_user,
                               resp_id            => g_resp_id,
                               resp_appl_id       => g_resp_appl_id
							    );

								
	l_init_msg_list := TRUE;
    l_commit := TRUE;							
	
    v_step := 2;
	
	FOR l_upd_res IN c_upd_res
	LOOP
	
	v_step := 3;
	
		--Initiate variables
		l_update_table.DELETE;
		l_query 							:= NULL;
		l_error_flag			   		    := FALSE;
		l_data					   			:= NULL;
		l_count						        := NULL;
		l_return_status   		   			:= NULL;
		
	
	v_step := 4;
	
		--assign values to the l_update_table for API
		l_update_table (1).p_col_to_update 	:= l_upd_res.column_to_upd;
		l_update_table (1).p_value 			:= l_upd_res.new_value;
	
		--dynamic query to get all operations related to the given item number
		l_query := 'SELECT DISTINCT pr.OPRN_LINE_ID, act.activity
					FROM apps.GMD_OPERATIONS_VL po, GMD_OPERATION_ACTIVITIES act, GMD_OPERATION_RESOURCES pr, mtl_parameters mp
					WHERE
					po.oprn_id = act.oprn_id 
					AND act.oprn_line_id = pr.oprn_line_id 
					AND po.owner_organization_id = mp.organization_id
					AND po.oprn_no LIKE ''%'|| l_upd_res.item_number ||'%''';
	
	v_step := 5;
	
		OPEN c_get_operations FOR l_query;
		FETCH c_get_operations BULK COLLECT INTO l_oprn_ids;
		FOR i IN 1..l_oprn_ids.COUNT
		LOOP
	
	v_step := 6;
	
			--Initiate variables
			l_oprn_line_id  := NULL;
			l_count			:= NULL;
			l_data			:= NULL;
			l_return_status := NULL;
			
			
			l_oprn_line_id:= l_oprn_ids(i).oprn_line_id;	
	
	v_step := 7;
	
			--Call API to update resource
			GMD_OPERATION_RESOURCES_PUB.update_operation_resources (
						  p_api_version 		=> l_api_version
						, p_init_msg_list 	    => l_init_msg_list
						, p_commit			    => l_commit
						, p_oprn_line_id	    => l_oprn_line_id
						, p_resources		    => l_upd_res.resources
						, p_update_table	    => l_update_table
						, x_message_count 	    => l_count
						, x_message_list 	    => l_data
						, x_return_status	    => l_return_status
                                       );
	
	v_step := 8;
	
			IF l_return_status = 'E' OR l_return_status = 'U' THEN
			
				l_error_flag := TRUE;
				l_data := 'ERROR - ' || l_data;

			END IF;
	
	v_step := 9;
	
		END LOOP;
		
		CLOSE c_get_operations;		
	
	IF l_error_flag = TRUE THEN 
	
		UPDATE xxnbty.xxnbty_upd_res_stg
	    SET process_flag = 'Y'
	    	,error_description = l_data
	    	,last_update_date  = SYSDATE
	        ,last_updated_by   = fnd_global.user_id
	    WHERE rowid = l_upd_res.rowid;
		
	ELSE
	
		UPDATE xxnbty.xxnbty_upd_res_stg
		SET process_flag = 'Y'
		,last_update_date  = SYSDATE
		,last_updated_by   = fnd_global.user_id
		WHERE rowid = l_upd_res.rowid;
	
	END IF;
	
	COMMIT;	
	
	v_step := 10;
	
	END LOOP;	
	
EXCEPTION
  WHEN OTHERS THEN
  o_retcode := 2;
  v_mess := 'At step ['||v_step||'] for procedure open_period - SQLCODE [' ||SQLCODE|| '] - ' ||substr(SQLERRM,1,100);
  o_errbuf := v_mess;
  
END update_resource;

PROCEDURE calculate_yield_upd(o_errbuf      OUT VARCHAR2, 
						  o_retcode     OUT NUMBER)

IS
----------------------------------------------------------------------------------------------------
/*
Package Name: XXNBTY_OPMEXT02_YIELD_CONV_PKG
Author's Name: Albert John Flores
Date written: 30-Sep-2016
RICEFW Object: EXT02
Description: this procedure calculates and updates yield costs based on the lookup table
Program Style: 

Maintenance History: 

Date            Issue#      Name                    Remarks 
-----------     ------      -----------             ------------------------------------------------
30-Sep-2016                 Albert Flores           Initial Development

*/
----------------------------------------------------------------------------------------------------  

CURSOR c_get_yields
IS
SELECT lookup_code,
		tag
FROM fnd_lookup_values_vl
WHERE lookup_type='XXNBTY_YIELD_PERCENTAGES';

   c_get_operations	  		   SYS_REFCURSOR;
   l_api_version     		   NUMBER := 1;
   l_init_msg_list   		   BOOLEAN;
   l_commit          		   BOOLEAN;
   l_oprn_line_id	 		   NUMBER;
   l_resources		 		   VARCHAR2(100);
   l_activity		 		   VARCHAR2(100);
   l_item_num		 		   VARCHAR2(100);
   l_update_table    		   gmd_operation_resources_pub.update_tbl_type;
   l_count           		   NUMBER;
   l_return_status   		   VARCHAR2 (1);
   l_data            		   VARCHAR2 (2000);
   l_status          		   VARCHAR2 (1);
   l_query					   VARCHAR2(2000);
   l_error_flag				   BOOLEAN := FALSE;
   l_raw_cost				   NUMBER;
   
   TYPE oprn_typ   	   IS RECORD(oprn_line_id NUMBER,	activity VARCHAR2(100));
   TYPE oprn_tbl	   IS TABLE OF oprn_typ;
   
   l_oprn_ids					   oprn_tbl;

	v_step                     NUMBER;
    v_mess                     VARCHAR2(500);
	
BEGIN

	v_step := 1;

	--Initialize Instance
	fnd_global.apps_initialize (user_id           => g_user,
                               resp_id            => g_resp_id,
                               resp_appl_id       => g_resp_appl_id
							    );

								
	l_init_msg_list := TRUE;
    l_commit 		:= TRUE;							
	
    v_step := 2;
	
	FOR l_get_yields IN c_get_yields
	LOOP
	
	v_step := 3;
	
		--Initiate variables
		l_update_table.DELETE;
		l_query 							:= NULL;
		l_error_flag			   		    := FALSE;
		l_data					   			:= NULL;
		l_count						        := NULL;
		l_return_status   		   			:= NULL;
		l_raw_cost							:= NULL;
		
		--derive the value to be multiplied using the item number from the lookup table
		BEGIN
		SELECT DISTINCT a.cmpnt_cost
		INTO l_raw_cost
		FROM   cm_cmpt_dtl  a,
				cm_cmpt_mst b ,
				mtl_system_items c,
				mtl_parameters d,
				mtl_item_categories_v e, 
				gmf_period_statuses f

		WHERE a.inventory_item_id			=c.inventory_item_id
		AND	  a.cost_cmpntcls_id			=b.cost_cmpntcls_id
		AND	  a.organization_id				=d.organization_id 
		AND   UPPER(e.category_set_name)	='PROCESS_CATEGORY'
		AND   e.inventory_item_id			=a.inventory_item_id 
		AND   e.organization_id				=a.organization_id
		AND   a.delete_mark					=0
		AND   cost_level					=1
		AND   UPPER(b.cost_cmpntcls_code)	='RMW'
		AND   c.segment1					=l_get_yields.lookup_code
		AND   (SYSDATE >= f.start_date )
			AND    (SYSDATE < TO_DATE(TO_CHAR(f.end_date,'DD-MON-YY')||' 11:59:59PM','DD-MON-YY HH:MI:SSAM')  )
		AND	  a.period_id					= f.period_id;

		EXCEPTION
		WHEN NO_DATA_FOUND THEN
			
			l_raw_cost := 0;
			
		END;
	
	v_step := 4;
	
		--assign values to the l_update_table for API
		l_update_table (1).p_col_to_update 	:= 'RESOURCE_USAGE';
		l_update_table (1).p_value 			:= ROUND((l_raw_cost*l_get_yields.tag),5);
	FND_FILE.PUT_LINE(FND_FILE.LOG, 'Multiply new value for item below - [' || l_raw_cost || '] * ' ||l_get_yields.tag);
	FND_FILE.PUT_LINE(FND_FILE.LOG, 'Calculated new value for item - [' || l_get_yields.lookup_code || '] is ' ||l_update_table (1).p_value);
	
		--dynamic query to get all operations related to the given item number
		l_query := 'SELECT DISTINCT pr.OPRN_LINE_ID, act.activity
					FROM apps.GMD_OPERATIONS_VL po, GMD_OPERATION_ACTIVITIES act, GMD_OPERATION_RESOURCES pr, mtl_parameters mp
					WHERE
					po.oprn_id = act.oprn_id 
					AND act.oprn_line_id = pr.oprn_line_id 
					AND po.owner_organization_id = mp.organization_id
					AND po.oprn_no LIKE ''%'|| l_get_yields.lookup_code ||'%''';
	
	v_step := 5;
	
		OPEN c_get_operations FOR l_query;
		FETCH c_get_operations BULK COLLECT INTO l_oprn_ids;
		FOR i IN 1..l_oprn_ids.COUNT
		LOOP
	
	v_step := 6;
	
			--Initiate variables
			l_oprn_line_id  := NULL;
			l_count			:= NULL;
			l_data			:= NULL;
			l_return_status := NULL;
			
			
			l_oprn_line_id:= l_oprn_ids(i).oprn_line_id;	
	
	v_step := 7;
	
			--Call API to update resource
			GMD_OPERATION_RESOURCES_PUB.update_operation_resources (
						  p_api_version 		=> l_api_version
						, p_init_msg_list 	    => l_init_msg_list
						, p_commit			    => l_commit
						, p_oprn_line_id	    => l_oprn_line_id
						, p_resources		    => 'YIELD_RES'
						, p_update_table	    => l_update_table
						, x_message_count 	    => l_count
						, x_message_list 	    => l_data
						, x_return_status	    => l_return_status
                                       );
	
	v_step := 8;
	
			IF l_return_status = 'E' OR l_return_status = 'U' THEN
			
				l_error_flag := TRUE;
				l_data := 'ERROR - ' || l_data;

			END IF;
	
	v_step := 9;
	
		END LOOP;
		
		CLOSE c_get_operations;		
	
	COMMIT;	
	
	v_step := 10;
	
	END LOOP;	
	
EXCEPTION
  WHEN OTHERS THEN
  o_retcode := 2;
  v_mess := 'At step ['||v_step||'] for procedure calculate_yield_upd - SQLCODE [' ||SQLCODE|| '] - ' ||substr(SQLERRM,1,100);
  o_errbuf := v_mess;
  
END calculate_yield_upd;

END XXNBTY_OPMEXT02_YIELD_CONV_PKG;

/

show errors;
