create or replace PACKAGE BODY         XXNBTY_PO_RCV_IBI_FEEDER_PK

IS
   -- $Header: Exp $
   ----------------------------------------------------------------------
   /*

    Package Name: XXNBTY_PO_RCV_IBI_FEEDER_PK
    Author? name: Amit Kumar (NBTY ERP Implementation)
    Date written: 09-Nov-12
    RICEFW Object id: NBTY-PRC-I-013
    Description: NBTYT: PO Receipt interface Program
    Program Style: Subordinate

    Maintenance History:

    Date Issue# Name Remarks

    ----------- -------- ---------------- ------------------------------------------
    09-Nov-12 Amit Kumar Initial development.
    23-Jan-13 Amit Kumar Convert Transaction Type 'DELIVER' to 'RECEIVE'
                                          and for correction create two line for both
                                          'DELIVER' to 'RECEIVE'
    31-Jan-13 Amit Kumar Change code for Shipped date should be set to one day prior
                                          to EXPECTED_RECEIPT_DATE and program allow to receipt quantity
                                          can be greater than the PO quantity
    05-Feb-13 Amit Kumar Change code for If TRANSACTION_TYPE=?ECEIVE?or
                                          TRANSACTION_TYPE=?ELIVER?and ITEM_NUM is populated set value
                                          to ?NVENTORY? if TRANSACTION_TYPE=?ECEIVE?or TRANSACTION_TYPE=?ELIVER?
                                          and ITEM_NUM is not populated set value to ?XPENSE? else leave NULL
    07-Feb-13 Amit Kumar Change code for the interface to correct the first parent deliver
                                          transaction to 0 then, if correction quantity is still remaining,
                                          correct the next parent deliver transaction to 0. That logic should
                                          continue until the total correction quantity has been processed.
    08-May-2013 Jairaj Edalolu Post-production fixes to handle Receipt Interfaces
                                          Search for ""-- Post-Live Changes by Jairaj"" to list all the changes
    22-Oct-2013 Pavan M                   Modified proc validate_stage_tables for INC700224
    13-Jan-2014 Infosys                   Modified proc INF_ERR_INSERT_LOG for INC740356, re-processing attempts not incremented.
    19-Feb-2014 Infosys                   Modified as part of PRJ10456, to handle the duplicate records inserted into the interface table.
    24-Feb-2014 Infosys                   Modified as part of PRJ10475, to handle the corrections for the receipts.
    01-Jan-2014 Shyam B                   Modified the Package for NBTY Procurement Implementation
                                          The package is updated to handle receieving for PO Release and
                                          multipel shipment for PO Line.
   12-Jul-2014 INC828264 Infosys    When a receipt in the EBS staging tables refers to multiple PO lines, lines which interface successfully to EBS should be flagged with status 'I' (Interfaced). Only lines which did not interface should be flagged with status 'E' (Error).
                   When a receipt is in EBS staging tables refers to multiple PO lines, and some lines have status 'I' (Interfaced) or 'G' (Ignore), those lines should not be processed by the interface program. Only rows flagged 'U' (Un-Processed) or 'E' (Error) should be processed by the interface program.
   25-Feb-2015    Infosys            Code changes done for MERF PRJ10983
   03-Apr-2015      Infosys         Correction transactions are not getting processed.
   08-Mar-2016     Kenneth Palomera Modified Procedure:validate_rcv_trx_data--Derive the SubInventory value based on the ICC's
   08-Mar-2016	   Khristine Austero Added procedure on the error trapping
   23-Jun-2016    Infosys For handling duplicate receipt information.
   15-Jul-2016     Julian Trinidad  Modified code.
   21-Sep-2016		Albert Flores	Modified for cost validation issue
   28-Sep-2016		Albert Flores	Modified for subinventory issue/cost issue
   10-Oct-2016		Albert Flores	Modified for table change and logic change for standard cost check 
   03-Nov-2016		Albert Flores	Modified for the additional condition for discreet org cost validation
                                          */ 
   ----------------------------------------------------------------------



   g_hdr_cnt                          BINARY_INTEGER := 1;

   g_trx_cnt                          BINARY_INTEGER := 1;

   g_err_cnt                          BINARY_INTEGER := 1;

   g_user_id                          NUMBER;

   g_login_id                         NUMBER;

   g_resp_id                          NUMBER;

   g_resp_appl_id                     NUMBER;

   g_request_id                       NUMBER;

   g_org_id                           NUMBER;

   --retcode_warng_constant CONSTANT VARCHAR2 (1) := '1'; -- For Concurrent request

   retcde_failure_constant   CONSTANT VARCHAR2 (1) := '2'; -- For Concurrent request

   g_retcode_err                      NUMBER;

   g_sts_vld_constant        CONSTANT VARCHAR2 (1) := 'V';

   g_sts_vldErr_constant     CONSTANT VARCHAR2 (1) := 'R';

   g_sts_proc_constant       CONSTANT VARCHAR2 (1) := 'P';

   g_sts_err_constant        CONSTANT VARCHAR2 (1) := 'E';

   g_sts_int_constant        CONSTANT VARCHAR2 (1) := 'I';

   g_sts_partial_int         CONSTANT VARCHAR2 (1) := 'L';

   g_sts_new_constant        CONSTANT VARCHAR2 (1) := 'U';

   g_sts_ignore_constant     CONSTANT VARCHAR2 (1) := 'G';          --PRJ10456

   g_err_rec_Table                    BOLINF.XXNBTY_INT_ERRORS_PK.error_rec_tbl_type;

   g_interface_type                   VARCHAR2 (15) := 'RCV_IBI';

   g_event_id                         NUMBER := -1111;

   g_source_rec_id                    VARCHAR2 (360) := NULL;

   g_prn_check                        NUMBER := 1;

   g_debug_flag                       VARCHAR2 (10);



   ----------------------------------------------------------------------

   /*



    Pocedure Name: output_put_line

    Author? name: Amit Kumar (NBTY ERP Implementation)

    Date written: 09-Nov-12

    RICEFW Object id: NBTY-PRC-I-013

    Description: OutPut file print

    Program Style: Subordinate



    Maintenance History:



    Date Issue# Name Remarks

    ----------- -------- ---------------- ------------------------------------------

    09-Nov-12 Amit Kumar Initial development.



   */

   ----------------------------------------------------------------------

   PROCEDURE output_put_line (p_text VARCHAR2)

   IS

   BEGIN

      APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.OUTPUT, p_text);

   END;



   ----------------------------------------------------------------------

   /*



    Pocedure Name: log_put_line

    Author? name: Amit Kumar (NBTY ERP Implementation)

    Date written: 09-Nov-12

    RICEFW Object id: NBTY-PRC-I-013

    Description: LogPut file print

    Program Style: Subordinate



    Maintenance History:



    Date Issue# Name Remarks

    ----------- -------- ---------------- ------------------------------------------

    09-Nov-12 Amit Kumar Initial development.



   */

   ----------------------------------------------------------------------



   PROCEDURE log_put_line (p_text VARCHAR2)

   IS

   BEGIN

      IF g_debug_flag = 'Y'

      THEN

         APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG, '- ' || p_text);

      ELSE

         NULL;

      END IF;

   END;



   ----------------------------------------------------------------------

   /*

     Procedure Name: insert_error

     Author? name: Amit Kumar (NBTY ERP Implementation)

     Date written: 10-Dec-12

     RICEFW Object id: NBTY-FIN-I-028

     Description: Inserts errors into the common table.

                       Returns None

     Program Style: Subordinate



     Maintenance History:



     Date Issue# Name Remarks

     ----------- -------- --------------- ------------------------------------------

     10-Dec-12 Amit Kumar Initial development.



   */

   ----------------------------------------------------------------------



   PROCEDURE insert_error (p_log_event_id           IN NUMBER,

                           p_log_message_severity   IN VARCHAR2,

                           p_log_object_name        IN VARCHAR2,

                           p_log_error_message      IN VARCHAR2)

   IS

      -- Local Variables

      l_proc_name           VARCHAR (100)

                               := 'XXNBTY_PO_RCV_IBI_FEEDER_PK.insert_line_error';

      l_log_return_status   VARCHAR2 (10);

      l_log_msg_count       NUMBER;

      l_log_msg_data        VARCHAR2 (4000);

      l_log_error_id        NUMBER;

   BEGIN

      -- ----------------------------------------------------------------------

      -- Call to Log error API to report errors into XXNBTY_INT_ERRORS table

      -- ----------------------------------------------------------------------

      XXNBTY_INT_ERRORS_PK.log_error (

         x_return_status            => l_log_return_status,

         x_msg_count                => l_log_msg_count,

         x_msg_data                 => l_log_msg_data,

         x_ERROR_ID                 => l_log_error_id,

         p_INTERFACE_TYPE           => g_interface_type,

         p_EVENT_ID                 => p_log_event_id,

         p_REQUEST_ID               => g_request_id,

         p_SOURCE_TABLE_NAME        => NULL,

         p_SOURCE_TABLE_RECORD_ID   => g_source_rec_id,

         p_MESSAGE_SEVERITY         => p_log_message_severity,

         p_OBJECT_NAME              => p_log_object_name,

         p_MESSAGE_NAME             => NULL,

         p_ERROR_MESSAGE            => p_log_error_message);



      IF l_log_msg_data IS NOT NULL

      THEN

         log_put_line (

               'Error during insertion into common errors table'

            || l_log_msg_data);

      END IF;

   EXCEPTION

      WHEN OTHERS

      THEN

         log_put_line (

               'Unexpected Error in Procedure '

            || l_proc_name

            || '. Err='

            || TO_CHAR (SQLCODE)

            || ' '

            || SQLERRM);

   END insert_error;



   ----------------------------------------------------------------------

   /*



    Pocedure Name: insert_hdr_error

    Author? name: Amit Kumar (NBTY ERP Implementation)

    Date written: 09-Nov-12

    RICEFW Object id: NBTY-PRC-I-013

    Description: Insert header error record in error tbl

    Program Style: Subordinate



    Maintenance History:



    Date Issue# Name Remarks

    ----------- -------- ---------------- ------------------------------------------

    09-Nov-12 Amit Kumar Initial development.



   */

   ----------------------------------------------------------------------



   PROCEDURE insert_hdr_error (p_proc_name   IN VARCHAR2,

                               p_log_msg     IN VARCHAR2,

                               p_event_id    IN NUMBER,

                               p_record_id   IN NUMBER)

   IS

      l_proc_name   VARCHAR (100)

                       := 'XXNBTY_PO_RCV_IBI_FEEDER_PK.insert_hdr_error';

      l_log_msg     VARCHAR2 (500);

   BEGIN

      g_err_cnt := g_err_cnt + 1;

      g_err_rec_table (g_err_cnt).message_severity := 'ERROR';

      g_err_rec_table (g_err_cnt).object_name := p_proc_name;

      g_err_rec_table (g_err_cnt).error_message := p_log_msg;

      g_err_rec_table (g_err_cnt).interface_type := g_interface_type;

      g_err_rec_table (g_err_cnt).event_id := p_event_id;

      g_err_rec_table (g_err_cnt).request_id := g_request_id;

      g_err_rec_table (g_err_cnt).source_table_name :=

         'XXNBTY_RCV_HEADERS_STG';

      g_err_rec_table (g_err_cnt).source_table_record_id := p_record_id;

   EXCEPTION

      WHEN OTHERS

      THEN

         l_log_msg :=

               'Unexpected Error in Procedure '

            || l_proc_name

            || '. Err='

            || TO_CHAR (SQLCODE)

            || ' '

            || SQLERRM;

         log_put_line (l_log_msg);

         insert_error (g_event_id,

                       'ERROR',

                       l_proc_name,

                       l_log_msg);

   END insert_hdr_error;



   ----------------------------------------------------------------------

   /*



    Pocedure Name: insert_trx_error

    Author? name: Amit Kumar (NBTY ERP Implementation)

    Date written: 09-Nov-12

    RICEFW Object id: NBTY-PRC-I-013

    Description: Insert header error record in error tbl

    Program Style: Subordinate



    Maintenance History:



    Date Issue# Name Remarks

    ----------- -------- ---------------- ------------------------------------------

    09-Nov-12 Amit Kumar Initial development.



   */

   ----------------------------------------------------------------------



   PROCEDURE insert_trx_error (p_proc_name   IN VARCHAR2,

                               p_log_msg     IN VARCHAR2,

                               p_event_id    IN NUMBER,

                               p_record_id   IN NUMBER)

   IS

      l_proc_name   VARCHAR (100)

                       := 'XXNBTY_PO_RCV_IBI_FEEDER_PK.insert_trx_error';

      l_log_msg     VARCHAR2 (500);

   BEGIN

      g_err_cnt := g_err_cnt + 1;

      g_err_rec_table (g_err_cnt).message_severity := 'ERROR';

      g_err_rec_table (g_err_cnt).object_name := p_proc_name;

      g_err_rec_table (g_err_cnt).error_message := p_log_msg;

      g_err_rec_table (g_err_cnt).interface_type := g_interface_type;

      g_err_rec_table (g_err_cnt).event_id := p_event_id;

      g_err_rec_table (g_err_cnt).request_id := g_request_id;

      g_err_rec_table (g_err_cnt).source_table_name :=

         'XXNBTY_RCV_TRANSACTIONS_STG';

      g_err_rec_table (g_err_cnt).source_table_record_id := p_record_id;

   EXCEPTION

      WHEN OTHERS

      THEN

         l_log_msg :=

               'Unexpected Error in Procedure '

            || l_proc_name

            || '. Err='

            || TO_CHAR (SQLCODE)

            || ' '

            || SQLERRM;

         log_put_line (l_log_msg);

         insert_error (g_event_id,

                       'ERROR',

                       l_proc_name,

                       l_log_msg);

   END insert_trx_error;



   ----------------------------------------------------------------------

   /*



    Pocedure Name: write_audit_report_output

    Author? name: Amit Kumar (NBTY ERP Implementation)

    Date written: 09-Nov-12

    RICEFW Object id: NBTY-PRC-I-013

    Description: This Procedure will display output

    Program Style: Subordinate



    Maintenance History:



    Date Issue# Name Remarks

    ----------- -------- ---------------- ------------------------------------------

    09-Nov-12 Amit Kumar Initial development.



   */

   ----------------------------------------------------------------------



   PROCEDURE write_audit_report_output (p_error_type IN VARCHAR2)

   IS

      l_proc_name                  VARCHAR (100)

         := 'XXNBTY_PO_RCV_IBI_FEEDER_PK.write_audit_report_output';

      l_head_msg                   VARCHAR2 (1000);

      l_line                       VARCHAR2 (2000);

      l_line_msg                   VARCHAR2 (4000);

      l_hdr_cnt                    BINARY_INTEGER := 0;

      l_trx_cnt                    BINARY_INTEGER := 0;

      l_h_cnt_suss                 BINARY_INTEGER := 0;

      l_h_cnt_err                  BINARY_INTEGER := 0;

      l_t_cnt_suss                 BINARY_INTEGER := 0;

      l_t_cnt_err                  BINARY_INTEGER := 0;

      l_tot_hdr                    NUMBER := 0;

      l_tot_trx                    NUMBER := 0;

      l_vendor_num                 xxnbty_rcv_headers_stg.legacy_vendor_num%TYPE;

      l_receipt_num                xxnbty_rcv_headers_stg.receipt_num%TYPE;

      l_shipment_num               xxnbty_rcv_headers_stg.shipment_num%TYPE;

      l_source_unique_identifier   xxnbty_ibi_events.source_unique_identifier%TYPE;

      l_log_msg                    VARCHAR2 (500);





      CURSOR c_get_error_list

      IS

           SELECT error_message

             FROM xxnbty_int_errors

            WHERE     source_table_record_id = g_source_rec_id

                  AND request_id = g_request_id

                  AND message_severity = 'ERROR'

                  AND object_name <> 'validate_stage_tables'

         ORDER BY error_id;



      CURSOR c_hdr_error (

         cp_event_id NUMBER)

      IS

         SELECT xrhs.transaction_type,

                xrhs.vendor_site_code,

                xrhs.receipt_num,

                xrhs.shipment_num,

                xrhs.legacy_vendor_num,

                xrhs.stage_process_flag,

                xrhs.header_interface_id,

                TO_CHAR (xie1.processed_attempts) processed_attempts,

                xie.error_message,

                TO_CHAR (xie.event_id) event_id,

                xie1.source_unique_identifier

           FROM xxnbty_int_errors xie,

                xxnbty_rcv_headers_stg xrhs,

                xxnbty_ibi_events xie1

          WHERE     xie.event_id = cp_event_id

                AND xie.request_id = g_request_id

                AND xrhs.stage_event_id = xie.event_id

                AND xrhs.stage_request_id = xie.request_id

                AND xie.message_severity = 'ERROR'

                AND xrhs.stage_process_flag IN

                       (g_sts_err_constant, g_sts_partial_int)

                AND xrhs.stage_error_type = p_error_type

                AND xrhs.stage_event_id = xie1.event_id

                AND xie.source_table_record_id = xrhs.stage_record_id

                AND xie.source_table_name = 'XXNBTY_RCV_HEADERS_STG';



      CURSOR c_trx_error (

         cp_event_id NUMBER)

      IS

         SELECT xrts.transaction_type,

                xrts.document_num,

                xrts.document_line_num-- // added shipment and Release Num 31-Dec-2013 Shyam B - NBTY Procurement Implementation

                ,

                xrts.document_shipment_line_num,

                xrts.release_num-- //

                ,

                xrts.stage_process_flag,

                xrts.interface_transaction_id,

                TO_CHAR (xie1.processed_attempts) processed_attempts,

                xie.error_message,

                TO_CHAR (xie.event_id) event_id,

                xie1.event_type

           FROM xxnbty_int_errors xie,

                xxnbty_rcv_transactions_stg xrts,

                xxnbty_ibi_events xie1

          WHERE     xie.event_id = cp_event_id

                AND xie.request_id = g_request_id

                AND xrts.stage_event_id = xie.event_id

                AND xrts.stage_request_id = xie.request_id

                AND xie.message_severity = 'ERROR'

                AND xrts.stage_process_flag IN

                       (g_sts_err_constant, g_sts_partial_int)

                AND xrts.stage_error_type = p_error_type

                AND xrts.stage_event_id = xie1.event_id

                AND xie.source_table_record_id = xrts.stage_record_id

                AND xie.source_table_name = 'XXNBTY_RCV_TRANSACTIONS_STG';



      CURSOR c_hdr_sucess (

         cp_event_id NUMBER)

      IS

         SELECT xrhs.transaction_type,

                xrhs.vendor_site_code-- , xrhs.receipt_num -- Post-Live Changes by Jairaj, display system generated receipt number instead of legacy receipt number

                ,

                NVL (

                   (SELECT rsh.receipt_num

                      FROM rcv_shipment_headers rsh

                     WHERE     rsh.attribute1 = TO_CHAR (xrhs.receipt_num)

                           AND ROWNUM < 2),

                   '')

                   oracle_receipt_num,

                xrhs.receipt_num legacy_receipt_num,

                xrhs.shipment_num,

                xrhs.legacy_vendor_num,

                xrhs.stage_process_flag,

                xrhs.header_interface_id,

                TO_CHAR (xie1.processed_attempts) processed_attempts,

                TO_CHAR (xie1.event_id) event_id,

                xie1.source_unique_identifier

           FROM xxnbty_rcv_headers_stg xrhs, xxnbty_ibi_events xie1

          WHERE     xrhs.stage_event_id = cp_event_id

                AND xrhs.stage_request_id = g_request_id

                AND xrhs.stage_process_flag = g_sts_int_constant

                AND xrhs.stage_event_id = xie1.event_id;





      CURSOR c_trx_sucess (

         cp_event_id NUMBER)

      IS

         SELECT xrts.transaction_type,

                xrts.document_num,

                xrts.document_line_num-- // added shipment and Release Num 31-Dec-2013 Shyam B - NBTY Procurement Implementation

                ,

                xrts.document_shipment_line_num,

                xrts.release_num-- //

                ,

                xrts.stage_process_flag,

                TO_CHAR (xie1.processed_attempts) processed_attempts,

                TO_CHAR (xie1.event_id) event_id,

                xrts.interface_transaction_id,

                NVL (

                   (SELECT DISTINCT rsh.receipt_num

                      FROM rcv_transactions rt,

                           rcv_shipment_lines rsl,

                           rcv_shipment_headers rsh,

                           xxnbty_rcv_headers_stg xrhs

                     WHERE     rt.attribute1 = TO_CHAR (xrhs.receipt_num)

                           AND rt.po_header_id = rsl.po_header_id

                           AND rt.po_line_id = rsl.po_line_id

                           -- // added shipment join 31-Dec-2013 Shyam B - NBTY Procurement Implementation

                           AND rt.po_line_location_id =

                                  rsl.po_line_location_id

                           -- //

                           AND rt.shipment_header_id = rsl.shipment_header_id

                           AND rt.shipment_line_id = rsl.shipment_line_id

                           AND rsl.shipment_header_id =

                                  rsh.shipment_header_id

                           AND rsl.po_header_id = xrts.po_header_id

                           AND rsl.po_line_id = xrts.po_line_id

                           AND rt.transaction_type = xrts.transaction_type

                           AND xrts.stage_event_id = xrhs.stage_event_id

                           AND ROWNUM < 2),

                   '')

                   oracle_receipt_num

           FROM xxnbty_rcv_transactions_stg xrts, xxnbty_ibi_events xie1

          WHERE     xrts.stage_event_id = cp_event_id

                AND xrts.stage_request_id = g_request_id

                AND xrts.stage_process_flag = g_sts_int_constant

                AND xrts.stage_event_id = xie1.event_id;



   BEGIN

      log_put_line ('Procedure ' || l_proc_name || '. Begin');



      l_line := RPAD ('*', 70, '*');





      FOR error_rec IN c_get_error_list

      LOOP

         IF g_prn_check = 1

         THEN

            log_put_line ('Printing Errors');

            output_put_line (l_line);

            output_put_line (' ***** List of Errors: ***** ');

            output_put_line (l_line);

            g_prn_check := 2;

         END IF;



         output_put_line (error_rec.error_message);

      END LOOP;





      l_hdr_cnt := g_hdr_cnt;

      l_trx_cnt := g_trx_cnt;



      IF l_hdr_cnt = 1

      THEN

         l_hdr_cnt := 0;

      ELSE

         l_hdr_cnt := l_hdr_cnt - 1;

      END IF;



      IF l_trx_cnt = 1

      THEN

         l_trx_cnt := 0;

      ELSE

         l_trx_cnt := l_trx_cnt - 1;

      END IF;



      IF l_hdr_cnt >= 1

      THEN

         FOR disp_HDR_REC IN G_REC_HDR_Table.FIRST .. G_REC_HDR_Table.LAST

         LOOP

            IF     G_REC_HDR_Table (disp_HDR_REC).status IN

                      ('SUCCESS', 'PARTLY')

               AND NVL (G_REC_HDR_Table (disp_HDR_REC).stage_error_type,

                        p_error_type) = p_error_type

            THEN

               l_h_cnt_suss := l_h_cnt_suss + 1;

            END IF;



            IF     NVL (G_REC_HDR_Table (disp_HDR_REC).status, 'ERROR') =

                      'ERROR'

               AND G_REC_HDR_Table (disp_HDR_REC).stage_error_type =

                      p_error_type

            THEN

               l_h_cnt_err := l_h_cnt_err + 1;

            END IF;

         END LOOP;





         IF l_trx_cnt >= 1

         THEN

            FOR disp_HDR_REC IN G_Rec_Trx_Table.FIRST .. G_Rec_Trx_Table.LAST

            LOOP

               IF     G_Rec_Trx_Table (disp_HDR_REC).status IN

                         ('SUCCESS', 'PARTLY')

                  AND NVL (G_Rec_Trx_Table (disp_HDR_REC).stage_error_type,

                           p_error_type) = p_error_type

               THEN

                  l_t_cnt_suss := l_t_cnt_suss + 1;

               END IF;



               IF     NVL (G_Rec_Trx_Table (disp_HDR_REC).status, 'ERROR') IN

                         ('ERROR', 'PARTLY')

                  AND G_Rec_Trx_Table (disp_HDR_REC).stage_error_type =

                         p_error_type

               THEN

                  l_t_cnt_err := l_t_cnt_err + 1;

               END IF;

            END LOOP;

         END IF;



         l_tot_hdr := l_h_cnt_suss + l_h_cnt_err;

         l_tot_trx := l_t_cnt_suss + l_t_cnt_err;



         IF l_tot_hdr > 0

         THEN

            output_put_line (' ');

            output_put_line (INITCAP (p_error_type) || ' Statistics');

            output_put_line (' ');



            IF p_error_type = 'VALIDATION'

            THEN

               output_put_line (

                  'Total Number of Header records validated :: ' || l_tot_hdr);

               output_put_line (

                     'Total Number of Transaction records validated :: '

                  || l_tot_trx);

               output_put_line (

                     'Total Number of Header records passed validation :: '

                  || l_h_cnt_suss);

               output_put_line (

                     'Total Number of Transaction records passed validation :: '

                  || l_t_cnt_suss);

               output_put_line (

                     'Total Number of Header records failed validation :: '

                  || l_h_cnt_err);

               output_put_line (

                     'Total Number of Transaction records failed validation :: '

                  || l_t_cnt_err);

            ELSE

               output_put_line (

                  'Total Number of Header records Imported :: ' || l_tot_hdr);

               output_put_line (

                     'Total Number of Transaction records Imported :: '

                  || l_tot_trx);

               output_put_line (

                     'Total Number of Header records passed Import :: '

                  || l_h_cnt_suss);

               output_put_line (

                     'Total Number of Transaction records passed Import :: '

                  || l_t_cnt_suss);

               output_put_line (

                     'Total Number of Header records failed Import :: '

                  || l_h_cnt_err);

               output_put_line (

                     'Total Number of Transaction records failed Import :: '

                  || l_t_cnt_err);

            END IF;





            l_line := RPAD ('=', 150, '=') || CHR (10);

            output_put_line (l_line);

            output_put_line (' ');

            output_put_line (' ');

            output_put_line (INITCAP (p_error_type) || ' Error Details');

            output_put_line (l_line);



            l_head_msg :=

                  RPAD ('Event Id', 10, ' ')

               || RPAD ('Source Unique', 15, ' ')

               || RPAD ('Transaction', 13, ' ')

               || RPAD ('Legacy Vendor', 15, ' ')

               || RPAD ('Receipt', 15, ' ')

               || RPAD ('Shipment', 16, ' ')

               || RPAD ('Document', 12, ' ')

               || RPAD ('Document Line', 14, ' ')

               || -- // added shipment and Release num in o/p  31-Dec-2013 Shyam B - NBTY Procurement Implementation

                  RPAD ('Release', 12, ' ')

               || RPAD ('Document Ship', 14, ' ')

               || -- //

                  RPAD ('Reprocess', 10, ' ')

               || RPAD ('Error Message', 15, ' ');

            output_put_line (l_head_msg);



            l_head_msg :=

                  RPAD (' ', 10, ' ')

               || RPAD ('Identifier', 15, ' ')

               || RPAD ('Type', 13, ' ')

               || RPAD ('Number', 15, ' ')

               || RPAD ('Number ', 15, ' ')

               || RPAD ('Number ', 16, ' ')

               || RPAD ('Number', 12, ' ')

               || RPAD ('Number', 14, ' ')

               || -- // added shipment and Release num in o/p  31-Dec-2013 Shyam B - NBTY Procurement Implementation

                  RPAD ('Number', 12, ' ')

               || RPAD ('Number', 14, ' ')

               || -- //

                  RPAD ('Attempt', 10, ' ');

            output_put_line (l_head_msg);



            output_put_line (l_line);



            FOR disp_HDR_REC IN G_REC_HDR_Table.FIRST .. G_REC_HDR_Table.LAST

            LOOP

               l_vendor_num := NULL;

               l_source_unique_identifier := NULL;

               l_receipt_num := NULL;

               l_shipment_num := NULL;



               FOR r_hdr_error

                  IN c_hdr_error (

                        G_REC_HDR_Table (disp_HDR_REC).stage_event_id)

               LOOP

                  l_vendor_num := r_hdr_error.legacy_vendor_num;

                  l_receipt_num := r_hdr_error.receipt_num;

                  l_shipment_num := r_hdr_error.shipment_num;

                  l_source_unique_identifier :=

                     r_hdr_error.source_unique_identifier;

                  l_line_msg :=

                        RPAD (NVL (r_hdr_error.event_id, ' '), 10, ' ')

                     || RPAD (

                           NVL (r_hdr_error.source_unique_identifier, ' '),

                           15,

                           ' ')

                     || RPAD (NVL (r_hdr_error.transaction_type, ' '),

                              13,

                              ' ')

                     || RPAD (NVL (r_hdr_error.legacy_vendor_num, ' '),

                              15,

                              ' ')

                     || RPAD (NVL (r_hdr_error.receipt_num, ' '), 15, ' ')

                     || -- RPAD(NVL(r_hdr_error.shipment_num,' '),42,' ')|| -- // Commented on  31-Dec-2013 Shyam B - NBTY Procurement Implementation

                        RPAD (NVL (r_hdr_error.shipment_num, ' '), 68, ' ')

                     || -- // Added 68 to take care of release and shipment  31-Dec-2013 Shyam B - NBTY Procurement Implementation

                       RPAD (NVL (r_hdr_error.processed_attempts, ' '),

                             10,

                             ' ')

                     || r_hdr_error.error_message;

                  output_put_line (l_line_msg);

               END LOOP;



               FOR r_trx_error

                  IN c_trx_error (

                        G_REC_HDR_Table (disp_HDR_REC).stage_event_id)

               LOOP

                  l_line_msg :=

                        RPAD (NVL (r_trx_error.event_id, ' '), 10, ' ')

                     || RPAD (NVL (l_source_unique_identifier, ' '), 15, ' ')

                     || RPAD (NVL (r_trx_error.transaction_type, ' '),

                              13,

                              ' ')

                     || RPAD (NVL (l_vendor_num, ' '), 15, ' ')

                     || RPAD (NVL (l_receipt_num, ' '), 15, ' ')

                     || RPAD (NVL (l_shipment_num, ' '), 16, ' ')

                     || RPAD (NVL (r_trx_error.document_num, ' '), 12, ' ')

                     || RPAD (NVL (r_trx_error.document_line_num, ' '),

                              14,

                              ' ')

                     || -- // added shipment and Release num in o/p  31-Dec-2013 Shyam B - NBTY Procurement Implementation

                        RPAD (NVL (TO_CHAR (r_trx_error.release_num), ' '),

                              12,

                              ' ')

                     || RPAD (

                           NVL (

                              TO_CHAR (

                                 r_trx_error.document_shipment_line_num),

                              ' '),

                           14,

                           ' ')

                     || -- //

                        RPAD (NVL (r_trx_error.processed_attempts, ' '),

                              10,

                              ' ')

                     || r_trx_error.error_message;

                  output_put_line (l_line_msg);

               END LOOP;

            END LOOP;



            IF p_error_type = 'IMPORT'

            THEN

               output_put_line (l_line);

               output_put_line (' ');



               output_put_line ('Success Details');



               l_line := RPAD ('=', 150, '=') || CHR (10);

               output_put_line (l_line);



               l_head_msg :=

                     RPAD ('Event Id', 10, ' ')

                  || RPAD ('Source Unique', 15, ' ')

                  || RPAD ('Transaction', 13, ' ')

                  || RPAD ('Legacy Vendor', 15, ' ')

                  || RPAD ('Oracle Receipt', 15, ' ')

                  || RPAD ('Legacy Receipt', 15, ' ')

                  || RPAD ('Shipment', 16, ' ')

                  || RPAD ('Document', 12, ' ')

                  || RPAD ('Document Line', 14, ' ')

                  || -- // added shipment and Release num in o/p  31-Dec-2013 Shyam B - NBTY Procurement Implementation

                     RPAD ('Release', 12, ' ')

                  || RPAD ('Document Ship', 14, ' ')

                  || -- //

                     RPAD ('Reprocess', 10, ' ');

               output_put_line (l_head_msg);



               l_head_msg :=

                     RPAD (' ', 10, ' ')

                  || RPAD ('Identifier', 15, ' ')

                  || RPAD ('Type', 13, ' ')

                  || RPAD ('Number', 15, ' ')

                  || RPAD ('Number', 15, ' ')

                  || RPAD ('Number', 15, ' ')

                  || RPAD ('Number', 16, ' ')

                  || RPAD ('Number', 12, ' ')

                  || RPAD ('Number', 14, ' ')

                  || -- // added shipment and Release num in o/p  31-Dec-2013 Shyam B - NBTY Procurement Implementation

                     RPAD ('Number', 12, ' ')

                  || RPAD ('Number', 14, ' ')

                  || -- //

                     RPAD ('Attempt', 10, ' ');

               output_put_line (l_head_msg);



               output_put_line (l_line);



               IF l_hdr_cnt >= 1 AND l_trx_cnt >= 1

               THEN

                  FOR disp_HDR_REC IN G_REC_HDR_Table.FIRST ..

                                      G_REC_HDR_Table.LAST

                  LOOP

                     FOR r_hdr_sucess

                        IN c_hdr_sucess (

                              G_REC_HDR_Table (disp_HDR_REC).stage_event_id)

                     LOOP

                        FOR r_trx_sucess

                           IN c_trx_sucess (

                                 G_REC_HDR_Table (disp_HDR_REC).stage_event_id)

                        LOOP

                           l_line_msg :=

                                 RPAD (NVL (r_hdr_sucess.event_id, ' '),

                                       10,

                                       ' ')

                              || RPAD (

                                    NVL (

                                       r_hdr_sucess.source_unique_identifier,

                                       ' '),

                                    15,

                                    ' ')

                              || RPAD (

                                    NVL (r_trx_sucess.transaction_type, ' '),

                                    13,

                                    ' ')

                              || RPAD (

                                    NVL (r_hdr_sucess.legacy_vendor_num, ' '),

                                    15,

                                    ' ')

                              || RPAD (

                                    NVL (

                                       NVL (r_trx_sucess.oracle_receipt_num,

                                            r_hdr_sucess.oracle_receipt_num),

                                       ' '),

                                    15,

                                    ' ')

                              || RPAD (

                                    NVL (r_hdr_sucess.legacy_receipt_num,

                                         ' '),

                                    15,

                                    ' ')

                              || RPAD (NVL (r_hdr_sucess.shipment_num, ' '),

                                       16,

                                       ' ')

                              || RPAD (NVL (r_trx_sucess.document_num, ' '),

                                       12,

                                       ' ')

                              || RPAD (

                                    NVL (r_trx_sucess.document_line_num, ' '),

                                    14,

                                    ' ')

                              || -- // added shipment and Release num in o/p  31-Dec-2013 Shyam B - NBTY Procurement Implementation

                                 RPAD (

                                    NVL (TO_CHAR (r_trx_sucess.release_num),

                                         ' '),

                                    12,

                                    ' ')

                              || RPAD (

                                    NVL (

                                       TO_CHAR (

                                          r_trx_sucess.document_shipment_line_num),

                                       ' '),

                                    14,

                                    ' ')

                              || -- //

                                 RPAD (

                                    NVL (r_hdr_sucess.processed_attempts,

                                         ' '),

                                    10,

                                    ' ');

                           output_put_line (l_line_msg);

                        END LOOP;

                     END LOOP;

                  END LOOP;

               END IF;

            END IF;

         END IF;

      END IF;



      log_put_line ('Procedure ' || l_proc_name || '. End.');

   EXCEPTION

      WHEN OTHERS

      THEN

         l_log_msg :=

               'Unexpected Error in Procedure '

            || l_proc_name

            || '. Err='

            || TO_CHAR (SQLCODE)

            || ' '

            || SQLERRM;

         log_put_line (l_log_msg);

         insert_error (g_event_id,

                       'ERROR',

                       l_proc_name,

                       l_log_msg);

   END write_audit_report_output;



   ----------------------------------------------------------------------

   /*



    Pocedure Name: get_vendor_dtl

    Author? name: Amit Kumar (NBTY ERP Implementation)

    Date written: 09-Nov-12

    RICEFW Object id: NBTY-PRC-I-013

    Description: get_vendor_dtl procedure check legacy_vendor number and return vendor ID

                       according to Legacy Vendor Num

    Program Style: Subordinate



    Maintenance History:



    Date Issue# Name Remarks

    ----------- -------- ---------------- ------------------------------------------

    09-Nov-12 Amit Kumar Initial development.



   */

   ----------------------------------------------------------------------



   PROCEDURE get_vendor_dtl (

      p_le_vendor_num   IN            ap_suppliers.segment1%TYPE,

      p_event_id        IN            xxnbty_ibi_events.event_id%TYPE,

      p_record_id       IN            NUMBER,

      x_vendor_id          OUT NOCOPY ap_suppliers.vendor_id%TYPE,

      x_vendor_num         OUT NOCOPY ap_suppliers.segment1%TYPE,

      x_vendor_name        OUT NOCOPY ap_suppliers.vendor_name%TYPE,

      x_error_flag      IN OUT        VARCHAR2,

      x_error_msg       IN OUT        VARCHAR2)

   IS

      l_proc_name        VARCHAR2 (100)

                            := 'XXNBTY_PO_RCV_IBI_FEEDER_PK.get_vendor_dtl';

      l_vendor_id        ap_suppliers.vendor_id%TYPE;

      l_vendor_site_id   ap_supplier_sites_all.vendor_site_id%TYPE;

      l_terms_id         ap_suppliers.terms_id%TYPE;

      l_vendor_num       ap_suppliers.segment1%TYPE;

      l_vendor_name      ap_suppliers.vendor_name%TYPE;

      l_log_msg          VARCHAR2 (2000);

   BEGIN

      log_put_line ('Procedure ' || l_proc_name || '. Begin');



      BEGIN

         XXNBTY_INT_UTIL_PKG.validate_derive_vendor (

            p_vendor_num       => p_le_vendor_num,

            x_vendor_id        => l_vendor_id,

            x_vendor_site_id   => l_vendor_site_id,

            x_terms_id         => l_terms_id,

            x_errbuf           => l_log_msg);



         SELECT asu.segment1, asu.vendor_name

           INTO l_vendor_num, l_vendor_name

           FROM ap_suppliers asu

          WHERE 1 = 1 AND asu.vendor_id = l_vendor_id;



         x_vendor_id := l_vendor_id;

         x_vendor_num := l_vendor_num;

         x_vendor_name := l_vendor_name;

      EXCEPTION

         WHEN OTHERS

         THEN

            apps.fnd_message.set_name ('XBIL', 'NBTY_RCV_VENDOR_NOT_DEF');

            apps.fnd_message.set_token ('VEND_NUM', p_le_vendor_num);

            l_log_msg := apps.fnd_message.get || ' ' || SUBSTR (SQLERRM, 250);

            apps.fnd_msg_pub.delete_msg;

            insert_hdr_error (p_proc_name   => l_proc_name,

                              p_log_msg     => l_log_msg,

                              p_event_id    => p_event_id,

                              p_record_id   => p_record_id);



            log_put_line (l_log_msg);

            x_error_msg := x_error_msg || l_log_msg;

            x_error_flag := APPS.fnd_api.g_true;

      END;



      log_put_line ('Procedure ' || l_proc_name || '. End.');

   EXCEPTION

      WHEN OTHERS

      THEN

         l_log_msg :=

               'Unexpected Error in Procedure '

            || l_proc_name

            || '. Err='

            || TO_CHAR (SQLCODE)

            || ' '

            || SQLERRM;

         log_put_line (l_log_msg);

         insert_error (g_event_id,

                       'ERROR',

                       l_proc_name,

                       l_log_msg);

   END get_vendor_dtl;



   ----------------------------------------------------------------------

   /*



    Pocedure Name: get_supplier_site

    Author? name: Amit Kumar (NBTY ERP Implementation)

    Date written: 09-Nov-12

    RICEFW Object id: NBTY-PRC-I-013

    Description: get_supplier_site procedure check legacy_vendor site and return vendor site ID

    Program Style: Subordinate



    Maintenance History:



    Date Issue# Name Remarks

    ----------- -------- ---------------- ------------------------------------------

    09-Nov-12 Amit Kumar Initial development.



   */

   ----------------------------------------------------------------------



   PROCEDURE get_supplier_site (

      p_le_site_code          IN            VARCHAR2,

      p_event_id              IN            xxnbty_ibi_events.event_id%TYPE,

      p_record_id             IN            NUMBER,

      x_vendor_site_id           OUT NOCOPY ap_supplier_sites_all.vendor_site_id%TYPE,

      x_vendor_site_code         OUT NOCOPY ap_supplier_sites_all.vendor_site_code%TYPE,

      x_ship_to_location_id      OUT NOCOPY ap_supplier_sites_all.ship_to_location_id%TYPE,

      x_error_flag            IN OUT        VARCHAR2,

      x_error_msg             IN OUT        VARCHAR2)

   IS

      l_proc_name             VARCHAR2 (100)

                                 := 'XXNBTY_PO_RCV_IBI_FEEDER_PK.get_supplier_site';

      l_vendor_id             ap_suppliers.vendor_id%TYPE;

      l_terms_id              ap_suppliers.terms_id%TYPE;

      l_vendor_site_id        ap_supplier_sites_all.vendor_site_id%TYPE;

      l_vendor_site_code      ap_supplier_sites_all.vendor_site_code%TYPE;

      l_ship_to_location_id   ap_supplier_sites_all.ship_to_location_id%TYPE;

      l_log_msg               VARCHAR2 (2000);

   BEGIN

      log_put_line ('Procedure ' || l_proc_name || '. Begin');



      BEGIN

         XXNBTY_INT_UTIL_PKG.validate_derive_vendor (

            p_vendor_num       => p_le_site_code,

            x_vendor_id        => l_vendor_id,

            x_vendor_site_id   => l_vendor_site_id,

            x_terms_id         => l_terms_id,

            x_errbuf           => l_log_msg);



         SELECT ass.vendor_site_code, ass.ship_to_location_id

           INTO l_vendor_site_code, l_ship_to_location_id

           FROM ap_supplier_sites_all ass

          WHERE     1 = 1

                AND ass.vendor_site_id = l_vendor_site_id

                AND ass.org_id = g_org_id;



         x_vendor_site_id := l_vendor_site_id;

         x_vendor_site_code := l_vendor_site_code;

         x_ship_to_location_id := l_ship_to_location_id;

      EXCEPTION

         WHEN OTHERS

         THEN

            l_log_msg :=

                  'Error in Get Supplier Site code for Legacy Site Code '

               || p_le_site_code

               || ' '

               || SUBSTR (SQLERRM, 250);



            insert_hdr_error (p_proc_name   => l_proc_name,

                              p_log_msg     => l_log_msg,

                              p_event_id    => p_event_id,

                              p_record_id   => p_record_id);



            log_put_line (l_log_msg);

            x_error_msg := x_error_msg || 'Error in Get Supplier Site code ';

            x_error_flag := APPS.fnd_api.g_true;

      END;



      log_put_line ('Procedure ' || l_proc_name || '. End.');

   EXCEPTION

      WHEN OTHERS

      THEN

         l_log_msg :=

               'Unexpected Error in Procedure '

            || l_proc_name

            || '. Err='

            || TO_CHAR (SQLCODE)

            || ' '

            || SQLERRM;

         log_put_line (l_log_msg);

         insert_error (g_event_id,

                       'ERROR',

                       l_proc_name,

                       l_log_msg);

   END get_supplier_site;



   ----------------------------------------------------------------------

   /*



    Pocedure Name: get_item_dtl

    Author? name: Amit Kumar (NBTY ERP Implementation)

    Date written: 09-Nov-12

    RICEFW Object id: NBTY-PRC-I-013

    Description: get_item_dtl procedure check legacy item number and return item ID

    Program Style: Subordinate



    Maintenance History:



    Date Issue# Name Remarks

    ----------- -------- ---------------- ------------------------------------------

    09-Nov-12 Amit Kumar Initial development.



   */

   ----------------------------------------------------------------------



   PROCEDURE get_item_dtl (

      p_le_item_num   IN            mtl_system_items_b.segment1%TYPE,

      p_event_id      IN            xxnbty_ibi_events.event_id%TYPE,

      p_record_id     IN            NUMBER,

      x_item_id          OUT NOCOPY mtl_system_items_b.inventory_item_id%TYPE,

      x_item_num         OUT NOCOPY mtl_system_items_b.segment1%TYPE,

      x_error_flag    IN OUT        VARCHAR2,

      x_error_msg     IN OUT        VARCHAR2)

   IS

      l_proc_name   VARCHAR2 (100)

                       := 'XXNBTY_PO_RCV_IBI_FEEDER_PK.get_item_dtl';

      l_item_id     mtl_system_items_b.inventory_item_id%TYPE;

      l_item_num    mtl_system_items_b.segment1%TYPE;

      l_log_msg     VARCHAR2 (2000);

   BEGIN

      log_put_line ('Procedure ' || l_proc_name || '. Begin');



      x_item_id := NULL;

      x_item_num := NULL;



      BEGIN

         -- Post-Live Changes by Jairaj

         -- -------------------------------------------

         -- Check Activeness of the record

         -- -------------------------------------------

         SELECT msib.inventory_item_id, msib.segment1

           INTO l_item_id, l_item_num

           FROM mtl_system_items_b msib

          WHERE     msib.segment1 = p_le_item_num

                AND msib.organization_id =

                       (SELECT organization_id

                          FROM mtl_parameters

                         WHERE     organization_id = master_organization_id

                               AND ROWNUM = 1)

                AND msib.enabled_flag = 'Y'

                AND SYSDATE BETWEEN NVL (msib.start_date_active, SYSDATE - 1)

                                AND NVL (msib.end_date_active, SYSDATE + 1);



         x_item_id := l_item_id;

         x_item_num := l_item_num;

      EXCEPTION

         WHEN OTHERS

         THEN

            apps.fnd_message.set_name ('XBIL', 'NBTY_RCV_ITEM__NOT_DEF');

            apps.fnd_message.set_token ('ITEM_NUM', p_le_item_num);

            l_log_msg := apps.fnd_message.get || ' ' || SUBSTR (SQLERRM, 250);

            apps.fnd_msg_pub.delete_msg;



            insert_trx_error (p_proc_name   => l_proc_name,

                              p_log_msg     => l_log_msg,

                              p_event_id    => p_event_id,

                              p_record_id   => p_record_id);



            log_put_line (l_log_msg);

            x_error_msg := x_error_msg || l_log_msg;

            x_error_flag := APPS.fnd_api.g_true;

      END;



      log_put_line ('Procedure ' || l_proc_name || '. End.');

   EXCEPTION

      WHEN OTHERS

      THEN

         l_log_msg :=

               'Unexpected Error in Procedure '

            || l_proc_name

            || '. Err='

            || TO_CHAR (SQLCODE)

            || ' '

            || SQLERRM;

         log_put_line (l_log_msg);

         insert_error (g_event_id,

                       'ERROR',

                       l_proc_name,

                       l_log_msg);

   END get_item_dtl;



   ----------------------------------------------------------------------

   /*



    Pocedure Name: get_item_category

    Author? name: Amit Kumar (NBTY ERP Implementation)

    Date written: 09-Nov-12

    RICEFW Object id: NBTY-PRC-I-013

    Description: get_item_category procedure return category_id based on item id

    Program Style: Subordinate



    Maintenance History:



    Date Issue# Name Remarks

    ----------- -------- ---------------- ------------------------------------------

    09-Nov-12 Amit Kumar Initial development.



   */

   ----------------------------------------------------------------------



   PROCEDURE get_item_category (

      --changes start for 25-Feb-2015

      --p_category_name IN mtl_categories_kfv.concatenated_segments%TYPE

      p_po_line_id    IN            po_lines_all.po_line_id%TYPE--changes end for 25-Feb-2015

      ,

      p_event_id      IN            xxnbty_ibi_events.event_id%TYPE,

      p_record_id     IN            NUMBER,

      x_category_id      OUT NOCOPY mtl_categories_b.category_id%TYPE,

      x_error_flag    IN OUT        VARCHAR2,

      x_error_msg     IN OUT        VARCHAR2)

   IS

      l_proc_name     VARCHAR2 (100)

                         := 'XXNBTY_PO_RCV_IBI_FEEDER_PK.get_item_category';

      l_category_id   mtl_categories_b.category_id%TYPE;

      l_log_msg       VARCHAR2 (2000);

   BEGIN

      log_put_line ('Procedure ' || l_proc_name || '. Begin');



      x_category_id := NULL;



      BEGIN

         -- Post-Live Changes by Jairaj

         -- -------------------------------------------

         -- Check Activeness of the record

         -- -------------------------------------------

         --changes start for 25-Feb-2015

         /* SELECT category_id

           INTO l_category_id

           FROM mtl_categories_kfv mc

          WHERE mc.concatenated_segments = p_category_name

            AND enabled_flag = 'Y'

            AND NVL(disable_date,sysdate) >= sysdate

            AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE - 1)

                                              AND NVL (end_date_active, SYSDATE + 1);



       x_category_id := l_category_id;*/



         SELECT mc.category_id

           INTO l_category_id

           FROM mtl_categories_kfv mc, po_lines_all pol

          WHERE     mc.category_id = pol.category_id

                AND pol.po_line_id = p_po_line_id

                AND mc.enabled_flag = 'Y'

                AND NVL (mc.disable_date, SYSDATE) >= SYSDATE

                AND SYSDATE BETWEEN NVL (mc.start_date_active, SYSDATE - 1)

                                AND NVL (mc.end_date_active, SYSDATE + 1);



         x_category_id := l_category_id;

      --changes end for 25-Feb-2015

      EXCEPTION

         WHEN OTHERS

         THEN

            --changes start for 25-Feb-2015

            l_log_msg := 'Invalid Item category for PO line' || p_po_line_id;

            /*  l_log_msg := 'Invalid Item category'

                              || p_category_name;*/

            --changes end for 25-Feb-2015



            insert_trx_error (p_proc_name   => l_proc_name,

                              p_log_msg     => l_log_msg,

                              p_event_id    => p_event_id,

                              p_record_id   => p_record_id);



            log_put_line (l_log_msg);

            x_error_msg := x_error_msg || 'No Item Category found ';

            x_error_flag := APPS.fnd_api.g_true;

      END;



      log_put_line ('Procedure ' || l_proc_name || '. End.');

   EXCEPTION

      WHEN OTHERS

      THEN

         l_log_msg :=

               'Unexpected Error in Procedure '

            || l_proc_name

            || '. Err='

            || TO_CHAR (SQLCODE)

            || ' '

            || SQLERRM;

         log_put_line (l_log_msg);

         insert_error (g_event_id,

                       'ERROR',

                       l_proc_name,

                       l_log_msg);

   END get_item_category;



   ----------------------------------------------------------------------

   /*



    Pocedure Name: get_UOM

    Author? name: Amit Kumar (NBTY ERP Implementation)

    Date written: 09-Nov-12

    RICEFW Object id: NBTY-PRC-I-013

    Description: Procedure check document number and return po_herader_id

    Program Style: Subordinate



    Maintenance History:



    Date Issue# Name Remarks

    ----------- -------- ---------------- ------------------------------------------

    09-Nov-12 Amit Kumar Initial development.



   */

   ----------------------------------------------------------------------



   PROCEDURE get_uom (

      p_uom_code     IN            mtl_units_of_measure_tl.uom_code%TYPE,

      p_event_id     IN            xxnbty_ibi_events.event_id%TYPE,

      p_record_id    IN            NUMBER,

      x_uom_code        OUT NOCOPY mtl_units_of_measure_tl.unit_of_measure%TYPE,

      x_error_flag   IN OUT NOCOPY VARCHAR2,

      x_error_msg    IN OUT NOCOPY VARCHAR2)

   IS

      l_proc_name   VARCHAR2 (100) := 'XXNBTY_PO_RCV_IBI_FEEDER_PK.get_uom';

      l_uom         mtl_units_of_measure_tl.unit_of_measure%TYPE;

      l_log_msg     VARCHAR2 (2000);

   BEGIN

      log_put_line ('Procedure ' || l_proc_name || '. Begin');



      BEGIN

         SELECT muom.unit_of_measure

           INTO l_uom

           FROM mtl_units_of_measure_tl muom

          WHERE     UPPER (muom.uom_code) = UPPER (p_uom_code)

                AND NVL (disable_date, SYSDATE) >= SYSDATE

                AND muom.LANGUAGE = USERENV ('LANG');



         x_uom_code := l_uom;

      EXCEPTION

         WHEN NO_DATA_FOUND

         THEN

            BEGIN

               SELECT muom.unit_of_measure

                 INTO l_uom

                 FROM mtl_units_of_measure_tl muom

                WHERE     UPPER (muom.unit_of_measure) = UPPER (p_uom_code)

                      AND NVL (disable_date, SYSDATE) >= SYSDATE

                      AND muom.LANGUAGE = USERENV ('LANG');



               x_uom_code := l_uom;

            EXCEPTION

               WHEN OTHERS

               THEN

                  l_uom := NULL;

            END;

         WHEN OTHERS

         THEN

            l_uom := NULL;

      END;



      IF l_uom IS NULL

      THEN

         apps.fnd_message.set_name ('XBIL', 'NBTY_RCV_UOM_NOT_DEF');

         apps.fnd_message.set_token ('UOM_CODE', p_uom_code);

         l_log_msg := apps.fnd_message.get || ' ' || SUBSTR (SQLERRM, 250);

         apps.fnd_msg_pub.delete_msg;

         insert_trx_error (p_proc_name   => l_proc_name,

                           p_log_msg     => l_log_msg,

                           p_event_id    => p_event_id,

                           p_record_id   => p_record_id);



         log_put_line (l_log_msg);

         x_uom_code := p_uom_code;

         x_error_msg := x_error_msg || l_log_msg;

         x_error_flag := APPS.fnd_api.g_true;

      END IF;



      log_put_line ('Procedure ' || l_proc_name || '. End.');

   EXCEPTION

      WHEN OTHERS

      THEN

         l_log_msg :=

               'Unexpected Error in Procedure '

            || l_proc_name

            || '. Err='

            || TO_CHAR (SQLCODE)

            || ' '

            || SQLERRM;

         log_put_line (l_log_msg);

         insert_error (g_event_id,

                       'ERROR',

                       l_proc_name,

                       l_log_msg);

   END get_uom;







   ----------------------------------------------------------------------

   /*



    Pocedure Name: get_po_header_id

    Author? name: Amit Kumar (NBTY ERP Implementation)

    Date written: 09-Nov-12

    RICEFW Object id: NBTY-PRC-I-013

    Description: Procedure check document number and return po_herader_id

    Program Style: Subordinate



    Maintenance History:



    Date Issue# Name Remarks

    ----------- -------- ---------------- ------------------------------------------

    09-Nov-12 Amit Kumar Initial development.



   */

   ----------------------------------------------------------------------



   PROCEDURE get_po_header_id (

      p_doc_num        IN            po_headers_all.segment1%TYPE,

      p_event_id       IN            xxnbty_ibi_events.event_id%TYPE,

      p_record_id      IN            NUMBER,

      p_release_num    IN            po_releases_all.release_num%TYPE -- // Added on 31-Dec-2013 Procurement Implementation Shyam B

                                                                     ,

      x_po_header_id      OUT NOCOPY po_headers_all.po_header_id%TYPE,

      x_error_flag     IN OUT        VARCHAR2,

      x_error_msg      IN OUT        VARCHAR2)

   IS

      l_proc_name      VARCHAR2 (100)

                          := 'XXNBTY_PO_RCV_IBI_FEEDER_PK.get_po_header_id';

      l_po_header_id   po_headers_all.po_header_id%TYPE;

      l_log_msg        VARCHAR2 (2000);

      l_lookup_type    VARCHAR2 (30);

   BEGIN

      log_put_line ('Procedure ' || l_proc_name || '. Begin');



      BEGIN

         --

         -- Commented on 31-Dec-2013 for NBTY Procurement Implementation (Shyam B)

         -- Query to include Type Lookup Code for Blanket Releases

         /*

           SELECT po_header_id

             INTO l_po_header_id

             FROM po_headers_all ph

            WHERE ph.authorization_status = 'APPROVED'

              AND ph.org_id = g_org_id

              AND ph.segment1 = p_doc_num;

          */



         IF NVL (p_release_num, '0') <> '0'

         THEN

            l_lookup_type := 'BLANKET';

         ELSE

            l_lookup_type := 'STANDARD';

         END IF;



         SELECT po_header_id

           INTO l_po_header_id

           FROM po_headers_all ph

          WHERE     ph.authorization_status = 'APPROVED'

                AND ph.org_id = g_org_id

                AND ph.segment1 = p_doc_num

                AND ph.type_lookup_code = l_lookup_type;



         -- Change end



         x_po_header_id := l_po_header_id;

      EXCEPTION

         WHEN OTHERS

         THEN

            apps.fnd_message.set_name ('XBIL', 'NBTY_RCV_PO_NUM_NOT_DEF');

            apps.fnd_message.set_token ('DOC_NUM', p_doc_num);

            l_log_msg := apps.fnd_message.get || ' ' || SUBSTR (SQLERRM, 250);

            apps.fnd_msg_pub.delete_msg;



            insert_trx_error (p_proc_name   => l_proc_name,

                              p_log_msg     => l_log_msg,

                              p_event_id    => p_event_id,

                              p_record_id   => p_record_id);



            log_put_line (l_log_msg);

            x_error_msg := x_error_msg || l_log_msg;

            x_error_flag := APPS.fnd_api.g_true;

      END;



      log_put_line ('Procedure ' || l_proc_name || '. End.');

   EXCEPTION

      WHEN OTHERS

      THEN

         l_log_msg :=

               'Unexpected Error in Procedure '

            || l_proc_name

            || '. Err='

            || TO_CHAR (SQLCODE)

            || ' '

            || SQLERRM;

         log_put_line (l_log_msg);

         insert_error (g_event_id,

                       'ERROR',

                       l_proc_name,

                       l_log_msg);

   END get_po_header_id;



   ----------------------------------------------------------------------

   /*



    Pocedure Name: check_po_dtl

    Author? name: Amit Kumar (NBTY ERP Implementation)

    Date written: 09-Nov-12

    RICEFW Object id: NBTY-PRC-I-013

    Description: Procedure return all PO related values

    Program Style: Subordinate



    Maintenance History:



    Date Issue# Name Remarks

    ----------- -------- ---------------- ------------------------------------------

    09-Nov-12 Amit Kumar Initial development.

    31-Dec-13            Shyam Baishkiyar  Modified for Procurement Implementation



   */

   ----------------------------------------------------------------------



   PROCEDURE check_po_dtl (

      p_po_num         IN            ap_suppliers.segment1%TYPE,

      p_po_header_id   IN            po_headers_all.po_header_id%TYPE,

      p_po_line_num    IN            ap_suppliers.vendor_id%TYPE,

      p_event_id       IN            xxnbty_ibi_events.event_id%TYPE,

      p_record_id      IN            NUMBER-- Commented on 31-Dec-2013  Procurement Implementation Shyam B

                                           -- Separate Validation procedure created for shipment information

                                           -- , x_line_location_id    OUT NOCOPY  po_line_locations_all.line_location_id%TYPE

                                           -- , x_ship_to_org_id      OUT NOCOPY  po_line_locations_all.ship_to_organization_id%TYPE

                                           -- , x_ship_to_location_id OUT NOCOPY  po_line_locations_all.ship_to_location_id%TYPE

      ,

      x_po_header_id      OUT NOCOPY po_headers_all.po_header_id%TYPE,

      x_po_line_id        OUT NOCOPY po_lines_all.po_line_id%TYPE,

      x_item_id           OUT NOCOPY po_lines_all.item_id%TYPE-- , x_remaining_qty       OUT NOCOPY  NUMBER

      ,

      x_category_id       OUT NOCOPY po_lines_all.category_id%TYPE,

      x_error_flag     IN OUT        VARCHAR2,

      x_error_msg      IN OUT        VARCHAR2)

   IS

      l_proc_name             VARCHAR2 (100)

                                 := 'XXNBTY_PO_RCV_IBI_FEEDER_PK.check_po_dtl';

      l_line_location_id      po_line_locations_all.line_location_id%TYPE;

      l_ship_to_org_id        po_line_locations_all.ship_to_organization_id%TYPE;

      l_ship_to_location_id   po_line_locations_all.ship_to_location_id%TYPE;

      l_po_header_id          po_headers_all.po_header_id%TYPE;

      l_po_line_id            po_lines_all.po_line_id%TYPE;

      l_item_id               po_lines_all.item_id%TYPE;

      l_remaining_qty         NUMBER;

      l_category_id           po_lines_all.category_id%TYPE;

      l_chk                   VARCHAR2 (1);

      l_log_msg               VARCHAR2 (2000);

   BEGIN

      log_put_line ('Procedure ' || l_proc_name || '. Begin');



      BEGIN

         SELECT 'Y'

           INTO l_chk

           FROM po_headers_all ph, po_lines_all PL

          WHERE     ph.po_header_id = pl.po_header_id

                AND ph.authorization_status = 'APPROVED'

                AND ph.org_id = g_org_id

                AND ph.segment1 = p_po_num

                AND pl.line_num = p_po_line_num;

      EXCEPTION

         WHEN OTHERS

         THEN

            apps.fnd_message.set_name ('XBIL', 'NBTY_RCV_LINE_NUM_NOT_DEF');

            apps.fnd_message.set_token ('DOC_NUM', p_po_num);

            apps.fnd_message.set_token ('DOC_LINE', p_po_line_num);

            l_log_msg := apps.fnd_message.get || ' ' || SUBSTR (SQLERRM, 250);

            apps.fnd_msg_pub.delete_msg;



            insert_trx_error (p_proc_name   => l_proc_name,

                              p_log_msg     => l_log_msg,

                              p_event_id    => p_event_id,

                              p_record_id   => p_record_id);



            log_put_line (l_log_msg);

            l_chk := 'N';

            x_error_msg :=

               x_error_msg || 'Warning: No PO Num And Po Line found ';

            x_error_flag := APPS.fnd_api.g_true;

      END;



      IF l_chk = 'Y'

      THEN

         BEGIN

            --

            -- Commented on 31-Dec-2013 Procurement Implementation Shyam B

            -- Separate Procedure is created to send information from

            -- Ship to Line as one Line can have multiple shipment Line

            /*

              SELECT pll.ship_to_location_id

                   , ph.po_header_id

                   , pl.po_line_id

                   , pl.item_id

                   , (pll.quantity-pll.quantity_received) quantity_remaining

                   , pl.category_id

                   , pll.ship_to_organization_id

                   , pll.line_location_id

               INTO  l_ship_to_location_id

                   , l_po_header_id

                   , l_po_line_id

                   , l_item_id

                   , l_remaining_qty

                   , l_category_id

                   , l_ship_to_org_id

                   , l_line_location_id

               FROM  po_headers_all ph

                   , po_lines_all pl

                   , po_line_locations_all pll

              WHERE  ph.po_header_id = pl.po_header_id

                AND  ph.po_header_id = pll.po_header_id

                AND  pl.po_line_id = pll.po_line_id

                AND  ph.authorization_status = 'APPROVED'

                AND  ph.org_id = g_org_id

                AND  ph.segment1 = p_po_num

                AND  pl.line_num = p_po_line_num;

                */

            log_put_line (

               'Procedure ' || l_proc_name || '. Extract Line details');



            SELECT ph.po_header_id,

                   pl.po_line_id,

                   pl.item_id,

                   pl.category_id

              INTO l_po_header_id,

                   l_po_line_id,

                   l_item_id,

                   l_category_id

              FROM po_headers_all ph, po_lines_all pl

             WHERE     ph.po_header_id = pl.po_header_id

                   AND ph.authorization_status = 'APPROVED'

                   AND ph.org_id = g_org_id

                   AND ph.segment1 = p_po_num

                   AND pl.line_num = p_po_line_num;



            --x_ship_to_location_id := l_ship_to_location_id;

            x_po_header_id := l_po_header_id;

            x_po_line_id := l_po_line_id;

            x_item_id := l_item_id;

            --x_remaining_qty       := l_remaining_qty;

            x_category_id := l_category_id;

            --x_ship_to_org_id      := l_ship_to_org_id;

            --x_line_location_id    := l_line_location_id;



            log_put_line (

               'Procedure ' || l_proc_name || '. Extract Line details ends.');

         EXCEPTION

            WHEN OTHERS

            THEN

               l_log_msg :=

                     'Error in Checking PO Line Location And Po Qty for Doc Num '

                  || p_po_num

                  || ' And Doc Line Num '

                  || p_po_line_num

                  || ' '

                  || SUBSTR (SQLERRM, 250);



               insert_trx_error (p_proc_name   => l_proc_name,

                                 p_log_msg     => l_log_msg,

                                 p_event_id    => p_event_id,

                                 p_record_id   => p_record_id);



               log_put_line (l_log_msg);

               x_error_msg :=

                  x_error_msg || 'Warning: No PO Line Location found ';

               x_error_flag := APPS.fnd_api.g_true;

         END;

      END IF;



      log_put_line ('Procedure ' || l_proc_name || '. End.');

   EXCEPTION

      WHEN OTHERS

      THEN

         l_log_msg :=

               'Unexpected Error in Procedure '

            || l_proc_name

            || '. Err='

            || TO_CHAR (SQLCODE)

            || ' '

            || SQLERRM;

         log_put_line (l_log_msg);

         insert_error (g_event_id,

                       'ERROR',

                       l_proc_name,

                       l_log_msg);

   END check_po_dtl;



   ----------------------------------------------------------------------

   /*



    Pocedure Name:    check_po_ship_dtl

    Author' name:    Shyam Baishkiyar (NBTY ERP Implementation)

    Date written:     31-Dec-13

    RICEFW Object id: NBTY-PRC-I-013

    Description:      Procedure return all PO related values

    Program Style:    Subordinate



    Maintenance History:



    Date        Issue#   Name             Remarks

    ----------- -------- ---------------- ------------------------------------------

     31-Dec-13            Shyam Baishkiyar  Initial Development for Procurement Implementation



   */

   ----------------------------------------------------------------------





   PROCEDURE check_po_ship_dtl (

      p_po_num                     IN            ap_suppliers.segment1%TYPE,

      p_po_line_num                IN            po_lines_all.line_num%TYPE,

      p_po_header_id               IN            po_headers_all.po_header_id%TYPE,

      p_po_line_id                 IN            po_lines_all.po_line_id%TYPE,

      p_release_num                IN            po_releases_all.release_num%TYPE,

      p_shipment_num               IN            po_line_locations_all.shipment_num%TYPE,

      p_event_id                   IN            xxnbty_ibi_events.event_id%TYPE,

      p_record_id                  IN            NUMBER,

      x_line_location_id              OUT NOCOPY po_line_locations_all.line_location_id%TYPE,

      x_ship_to_org_id                OUT NOCOPY po_line_locations_all.ship_to_organization_id%TYPE,

      x_ship_to_location_id           OUT NOCOPY po_line_locations_all.ship_to_location_id%TYPE,

      x_remaining_qty                 OUT NOCOPY NUMBER,

      x_po_release_id                 OUT NOCOPY NUMBER -- po_releases_all.po_release_id%TYPE

                                                       ,

      x_ship_location_code            OUT NOCOPY hr_locations.location_code%TYPE,

      x_DESTINATION_SUBINVENTORY      OUT NOCOPY po_distributions_all.DESTINATION_SUBINVENTORY%TYPE,

      x_error_flag                 IN OUT        VARCHAR2,

      x_error_msg                  IN OUT        VARCHAR2)

   IS

      l_proc_name                   VARCHAR2 (100)

                                       := 'XXNBTY_PO_RCV_IBI_FEEDER_PK.check_po_ship_dtl';

      l_line_location_id            po_line_locations_all.line_location_id%TYPE;

      l_ship_to_org_id              po_line_locations_all.ship_to_organization_id%TYPE;

      l_ship_to_location_id         po_line_locations_all.ship_to_location_id%TYPE;

      l_po_header_id                po_headers_all.po_header_id%TYPE;

      l_po_release_id               po_releases_all.po_release_id%TYPE;

      l_item_id                     po_lines_all.item_id%TYPE;

      l_remaining_qty               NUMBER;

      l_category_id                 po_lines_all.category_id%TYPE;

      l_chk                         VARCHAR2 (1);

      l_log_msg                     VARCHAR2 (2000);

      lc_ship_location_code         hr_locations.location_code%TYPE;

      lc_DESTINATION_SUBINVENTORY   po_distributions_all.DESTINATION_SUBINVENTORY%TYPE;

   BEGIN

      log_put_line ('Procedure ' || l_proc_name || '. Begin');





      IF NVL (p_release_num, '0') <> '0'

      THEN

         BEGIN

            SELECT po_release_id

              INTO l_po_release_id

              FROM po_releases_all por, po_headers_all poh

             WHERE     por.authorization_status = 'APPROVED'

                   AND por.org_id = g_org_id

                   AND por.release_num = p_release_num

                   AND por.po_header_id = poh.po_header_id

                   AND poh.segment1 = p_po_num

                   AND poh.type_lookup_code = 'BLANKET';



            x_po_release_id := l_po_release_id;

            log_put_line ('x_po_release_id ==>' || x_po_release_id);



            BEGIN

               log_put_line (

                     ' p_po_header_id ==>'

                  || p_po_header_id

                  || ' p_po_line_id ==>'

                  || p_po_line_id);



               SELECT pll.ship_to_location_id,

                      (pll.quantity - pll.quantity_received)

                         quantity_remaining,

                      pll.ship_to_organization_id,

                      pll.line_location_id,

                      hr.location_code,

                      pda.DESTINATION_SUBINVENTORY

                 INTO l_ship_to_location_id,

                      l_remaining_qty,

                      l_ship_to_org_id,

                      l_line_location_id,

                      lc_ship_location_code,

                      lc_DESTINATION_SUBINVENTORY

                 FROM po_line_locations_all pll,

                      po_distributions_all pda,

                      hr_locations hr

                WHERE     hr.location_id = pll.ship_to_location_id

                      AND pll.po_header_id = p_po_header_id

                      AND pll.po_line_id = p_po_line_id

                      AND pll.shipment_num = p_shipment_num

                      AND pda.PO_HEADER_ID = pll.PO_HEADER_ID

                      AND pda.PO_LINE_ID = pll.PO_LINE_ID

                      AND pda.LINE_LOCATION_ID = pll.line_location_id --13-May-2014

                      AND pll.po_release_id = l_po_release_id;



               x_ship_to_location_id := l_ship_to_location_id;

               x_remaining_qty := l_remaining_qty;

               x_ship_to_org_id := l_ship_to_org_id;

               x_line_location_id := l_line_location_id;

               x_ship_location_code := lc_ship_location_code;

            EXCEPTION

               WHEN OTHERS

               THEN

                  l_log_msg :=

                        'Error in Checking PO Ship for Doc Num '

                     || p_po_num

                     || ' And Release Num '

                     || p_release_num

                     || ' And Ship Num '

                     || p_shipment_num

                     || ' '

                     || SUBSTR (SQLERRM, 250);



                  insert_trx_error (p_proc_name   => l_proc_name,

                                    p_log_msg     => l_log_msg,

                                    p_event_id    => p_event_id,

                                    p_record_id   => p_record_id);



                  log_put_line (l_log_msg);

                  x_error_msg := x_error_msg || 'Warning: No Ship Line found ';

                  x_error_flag := APPS.fnd_api.g_true;

            END;

         EXCEPTION

            WHEN OTHERS

            THEN

               apps.fnd_message.set_name ('XBIL', 'NBTY_RELEASE_NUM_NOT_DEF');

               apps.fnd_message.set_token ('DOC_NUM', p_po_num);

               apps.fnd_message.set_token ('REL_LINE', p_release_num);

               l_log_msg :=

                  apps.fnd_message.get || ' ' || SUBSTR (SQLERRM, 250);

               apps.fnd_msg_pub.delete_msg;



               insert_trx_error (p_proc_name   => l_proc_name,

                                 p_log_msg     => l_log_msg,

                                 p_event_id    => p_event_id,

                                 p_record_id   => p_record_id);



               log_put_line (l_log_msg);

               l_chk := 'N';

               x_error_msg := x_error_msg || 'Warning: No PO Release found ';

               x_error_flag := APPS.fnd_api.g_true;

         END;

      ELSE

         BEGIN

            SELECT pll.ship_to_location_id,

                   (pll.quantity - pll.quantity_received) quantity_remaining,

                   pll.ship_to_organization_id,

                   pll.line_location_id,

                   hr.location_code,

                   pda.DESTINATION_SUBINVENTORY

              INTO l_ship_to_location_id,

                   l_remaining_qty,

                   l_ship_to_org_id,

                   l_line_location_id,

                   lc_ship_location_code,

                   lc_DESTINATION_SUBINVENTORY

              FROM po_line_locations_all pll,

                   po_distributions_all pda,

                   hr_locations hr

             WHERE     hr.location_id = pll.ship_to_location_id

                   AND pll.po_header_id = p_po_header_id

                   AND pll.po_line_id = p_po_line_id

                   AND pll.shipment_num = p_shipment_num

                   AND pda.PO_HEADER_ID = pll.PO_HEADER_ID

                   AND pda.LINE_LOCATION_ID = pll.line_location_id --21-May-2014

                   AND pda.PO_LINE_ID = pll.PO_LINE_ID;





            x_ship_to_location_id := l_ship_to_location_id;

            x_remaining_qty := l_remaining_qty;

            x_ship_to_org_id := l_ship_to_org_id;

            x_line_location_id := l_line_location_id;

            x_ship_location_code := lc_ship_location_code;

            x_DESTINATION_SUBINVENTORY := lc_DESTINATION_SUBINVENTORY;

         EXCEPTION

            WHEN OTHERS

            THEN

               l_log_msg :=

                     'Error in Checking PO Ship Line for Doc Num '

                  || p_po_num

                  || ' And Doc Line Num '

                  || p_po_line_num

                  || ' '

                  || ' And Ship Num '

                  || p_shipment_num

                  || SUBSTR (SQLERRM, 250);



               insert_trx_error (p_proc_name   => l_proc_name,

                                 p_log_msg     => l_log_msg,

                                 p_event_id    => p_event_id,

                                 p_record_id   => p_record_id);



               log_put_line (l_log_msg);

               x_error_msg := x_error_msg || 'Warning: No PO Ship Line found ';

               x_error_flag := APPS.fnd_api.g_true;

         END;

      END IF;                           /*IF p_release_num IS NOT NULL THEN */





      log_put_line ('Procedure ' || l_proc_name || '. End.');

   EXCEPTION

      WHEN OTHERS

      THEN

         l_log_msg :=

               'Unexpected Error in Procedure '

            || l_proc_name

            || '. Err='

            || TO_CHAR (SQLCODE)

            || ' '

            || SQLERRM;

         log_put_line (l_log_msg);

         insert_error (g_event_id,

                       'ERROR',

                       l_proc_name,

                       l_log_msg);

   END check_po_ship_dtl;



   ----------------------------------------------------------------------

   /*



    Pocedure Name: check_trans_dt

    Author? name: Amit Kumar (NBTY ERP Implementation)

    Date written: 09-Nov-12

    RICEFW Object id: NBTY-PRC-I-013

    Description: Procedure check transaction date come in open period.

    Program Style: Subordinate



    Maintenance History:



    Date Issue# Name Remarks

    ----------- -------- ---------------- ------------------------------------------

    09-Nov-12 Amit Kumar Initial development.



   */

   ----------------------------------------------------------------------



   PROCEDURE check_trans_dt (

      p_trans_dt     IN            DATE,

      p_event_id     IN            xxnbty_ibi_events.event_id%TYPE,

      p_record_id    IN            NUMBER,

      x_chk             OUT NOCOPY VARCHAR2,

      x_error_flag   IN OUT NOCOPY VARCHAR2,

      x_error_msg    IN OUT NOCOPY VARCHAR2)

   IS

      l_proc_name   VARCHAR2 (100)

                       := 'XXNBTY_PO_RCV_IBI_FEEDER_PK.check_trans_dt';

      l_chk         VARCHAR2 (1);

      l_log_msg     VARCHAR2 (2000);

   BEGIN

      log_put_line ('Procedure ' || l_proc_name || '. Begin');



      BEGIN

         SELECT 'Y'

           INTO l_chk

           FROM gl_period_statuses gps, apps.fnd_application fav

          WHERE     1 = 1                              --period_name ='NOV-13'

                AND gps.application_id = fav.application_id

                AND fav.application_short_name = 'PO'

                AND gps.closing_status = 'O'

                AND TRUNC (p_trans_dt) BETWEEN gps.start_date

                                           AND gps.end_date

                AND gps.set_of_books_id =

                       (SELECT lgr.ledger_id

                          FROM gl_ledgers lgr

                         WHERE     lgr.object_type_code = g_sts_partial_int

                               AND NVL (lgr.complete_flag, 'Y') = 'Y'

                               AND lgr.ledger_id =

                                      apps.fnd_profile.VALUE (

                                         'GL_SET_OF_BKS_ID'));



         x_chk := l_chk;

      EXCEPTION

         WHEN OTHERS

         THEN

            apps.fnd_message.set_name ('PO', 'PO_PO_ENTER_OPEN_GL_DATE');

            l_log_msg :=

                  'Trans Date : '

               || TO_CHAR (p_trans_dt, 'DD-MON-YYYY')

               || ' '

               || apps.fnd_message.get

               || ' '

               || SUBSTR (SQLERRM, 250);

            apps.fnd_msg_pub.delete_msg;



            insert_trx_error (p_proc_name   => l_proc_name,

                              p_log_msg     => l_log_msg,

                              p_event_id    => p_event_id,

                              p_record_id   => p_record_id);



            log_put_line (l_log_msg);

            x_error_msg := x_error_msg || l_log_msg;

            x_error_flag := APPS.fnd_api.g_true;

      END;



      log_put_line ('Procedure ' || l_proc_name || '. End.');

   EXCEPTION

      WHEN OTHERS

      THEN

         l_log_msg :=

               'Unexpected Error in Procedure '

            || l_proc_name

            || '. Err='

            || TO_CHAR (SQLCODE)

            || ' '

            || SQLERRM;

         log_put_line (l_log_msg);

         insert_error (g_event_id,

                       'ERROR',

                       l_proc_name,

                       l_log_msg);

   END check_trans_dt;



   ----------------------------------------------------------------------

   /*



    Pocedure Name: get_parent_trans

    Author? name: Amit Kumar (NBTY ERP Implementation)

    Date written: 09-Nov-12

    RICEFW Object id: NBTY-PRC-I-013

    Description: procedure return transaction id for correction transactions

    Program Style: Subordinate



    Maintenance History:



    Date Issue# Name Remarks

    ----------- -------- ---------------- ------------------------------------------

    09-Nov-12 Amit Kumar Initial development.



   */

   ----------------------------------------------------------------------



   PROCEDURE get_parent_trans (

      p_po_header_id       IN            po_headers_all.po_header_id%TYPE,

      p_po_line_id         IN            po_lines_all.po_line_id%TYPE,

      p_line_location_id   IN            po_line_locations_all.line_location_id%TYPE,

      p_po_qty             IN            NUMBER,

      p_event_id           IN            xxnbty_ibi_events.event_id%TYPE,

      p_record_id          IN            NUMBER,

      x_error_flag         IN OUT NOCOPY VARCHAR2,

      x_error_msg          IN OUT NOCOPY VARCHAR2)

   IS

      l_proc_name   VARCHAR2 (100)

                       := 'XXNBTY_PO_RCV_IBI_FEEDER_PK.get_parent_trans';

      l_qty         NUMBER;

      l_log_msg     VARCHAR2 (2000);

   BEGIN

      log_put_line ('Procedure ' || l_proc_name || '. Begin');



      BEGIN

         SELECT SUM (rt.quantity)

           INTO l_qty

           FROM rcv_transactions rt,

                rcv_shipment_headers rsh,

                rcv_shipment_lines rsl

          WHERE     rt.po_header_id = p_po_header_id

                AND rt.po_line_id = p_po_line_id

                AND rsl.po_header_id = p_po_header_id

                AND rsl.po_line_id = p_po_line_id

                AND rsh.shipment_header_id = rsl.shipment_header_id

                AND rsl.shipment_line_id = rt.shipment_line_id

                AND rt.po_line_location_id = p_line_location_id -- // Added on 31-Dec-2013 Procurement Implementation Shyam B

                -- //

                AND rsh.shipment_header_id = rt.shipment_header_id

                AND rt.transaction_type IN ('CORRECT', 'DELIVER')

                AND rt.destination_type_code IN ('EXPENSE', 'INVENTORY');



         --AND rsl.quantity_received >= abs(p_po_qty);



         IF l_qty < ABS (p_po_qty)

         THEN

            l_log_msg :=

                  'Correction Quantity '

               || ABS (p_po_qty)

               || ' greater than sum of Received Quantity '

               || l_qty

               || ' , for the PO Header,Line and Shipment.'; -- // Added Shipment 31-Dec-2013 Procurement Implementation Shyam B

            insert_trx_error (p_proc_name   => l_proc_name,

                              p_log_msg     => l_log_msg,

                              p_event_id    => p_event_id,

                              p_record_id   => p_record_id);



            log_put_line (l_log_msg);

            x_error_msg := l_log_msg;

            x_error_flag := APPS.fnd_api.g_true;

         ELSIF l_qty IS NULL

         THEN -- Post-Live Changes by Jairaj, throw error if CORRECT line does not have RECEIVE OR DELIVER created in the system

            l_log_msg :=

               'No Parent transaction found for the PO Header and Line.';

            insert_trx_error (p_proc_name   => l_proc_name,

                              p_log_msg     => l_log_msg,

                              p_event_id    => p_event_id,

                              p_record_id   => p_record_id);



            log_put_line (l_log_msg);

            x_error_msg := l_log_msg;

            x_error_flag := APPS.fnd_api.g_true;

         END IF;



         log_put_line (

            'l_qty > abs(p_po_qty) ' || l_qty || ' ' || ABS (p_po_qty));

      EXCEPTION

         WHEN OTHERS

         THEN

            l_log_msg := 'Parent Transactions Qty not found.';

            insert_trx_error (p_proc_name   => l_proc_name,

                              p_log_msg     => l_log_msg,

                              p_event_id    => p_event_id,

                              p_record_id   => p_record_id);



            log_put_line (l_log_msg);

            x_error_msg := l_log_msg;

            x_error_flag := APPS.fnd_api.g_true;

      END;



      log_put_line ('Procedure ' || l_proc_name || '. End.');

   EXCEPTION

      WHEN OTHERS

      THEN

         l_log_msg :=

               'Unexpected Error in Procedure '

            || l_proc_name

            || '. Err='

            || TO_CHAR (SQLCODE)

            || ' '

            || SQLERRM;

         log_put_line (l_log_msg);

         insert_error (g_event_id,

                       'ERROR',

                       l_proc_name,

                       l_log_msg);

   END get_parent_trans;





   ----------------------------------------------------------------------

   /*



    Pocedure Name: load_correct_trx

    Author? name: Amit Kumar (NBTY ERP Implementation)

    Date written: 09-Nov-12

    RICEFW Object id: NBTY-PRC-I-013

    Description: This Procedure will load Correction Receipt records

                      into Receipt Interface

    Program Style: Subordinate



    Maintenance History:



    Date Issue# Name Remarks

    ----------- -------- ---------------- ------------------------------------------

    06-Feb-13 Amit Kumar Initial development.



   */

   ----------------------------------------------------------------------



   PROCEDURE load_correct_trx (p_event_id             NUMBER,

                               p_record_id            NUMBER -- Post-Live Changes by Jairaj

                                                            ,

                               p_rec_header_id        NUMBER,           --correction error 03-Apr-2015

                               p_receipt_num          VARCHAR2 -- Post-Live Changes by Jairaj

                                                              ,

                               p_error_flag    IN OUT VARCHAR2,

                               p_error_msg     IN OUT VARCHAR2)

   IS

      l_proc_name     VARCHAR (100)

                         := 'XXNBTY_PO_RCV_IBI_FEEDER_PK.load_correct_trx';

      l_log_msg       VARCHAR2 (2000);

      l_qty           NUMBER;

      l_chk_ins       NUMBER := 2;

      l_chk_num       NUMBER := 0;



      -- Post-Live Changes by Jairaj

      l_pass_qty      NUMBER;

      l_receipt_cnt   NUMBER := 0;



      CURSOR Recepit_LINE_C

      IS

           SELECT xrt.stage_group_id,

                  xrt.transaction_type,

                  xrt.auto_transact_code,

                  xrt.transaction_date,

                  xrt.processing_status_code,

                  xrt.processing_mode_code,

                  xrt.source_document_code,

                  xrt.transaction_status_code,

                  xrt.quantity,

                  xrt.legacy_item_num,

                  xrt.item_num,

                  xrt.item_id,

                  xrt.item_category_id,

                  xrt.unit_of_measure,

                  xrt.receipt_source_code,

                  xrt.parent_interface_txn_id,

                  xrt.to_organization_id,

                  xrt.validation_flag,

                  xrt.po_header_id,

                  xrt.po_line_id,

                  xrt.po_release_id,

                  xrt.po_revision_num,

                  xrt.po_line_location_id,

                  xrt.location_id,

                  xrt.org_id,

                  xrt.document_num,

                  xrt.document_line_num,

                  -- // added shipment and Release num in o/p  31-Dec-2013 Shyam B - NBTY Procurement Implementation

                  xrt.document_shipment_line_num,

                  xrt.release_num,

                  -- //

                  xrt.subinventory,

                  xrt.stage_record_id,

                  xrt.stage_event_id,

                  rt.vendor_id,

                  rt.vendor_site_id,

                  rt.destination_type_code,

                  rt.transaction_type trans_type,

                  rt.transaction_id,

                  rsl.quantity_received rcv_qty

             FROM rcv_transactions rt,

                  rcv_shipment_headers rsh,

                  rcv_shipment_lines rsl,

                  bolinf.xxnbty_rcv_transactions_stg xrt

            WHERE     rt.po_header_id = xrt.po_header_id

                  AND rt.po_line_id = xrt.po_line_id

                  -- // added shipment Join  31-Dec-2013 Shyam B - NBTY Procurement Implementation

                  AND rsl.po_line_location_id = xrt.po_line_location_id

                  -- //

                  AND rsl.po_header_id = xrt.po_header_id

                  AND rsl.po_line_id = xrt.po_line_id

                  AND rsh.shipment_header_id = rsl.shipment_header_id

                  AND rsl.shipment_line_id = rt.shipment_line_id

                  AND rsh.shipment_header_id = rt.shipment_header_id

                  AND rt.transaction_type IN ('RECEIVE', 'DELIVER')

                  AND rsl.quantity_received <> 0

                  AND xrt.stage_request_id = g_request_id

                  AND xrt.stage_event_id = p_event_id

                  AND xrt.stage_record_id = p_record_id -- Post-Live Changes by Jairaj,to avoid duplicates

                  AND rsh.attribute1 = NVL (xrt.attribute5, rsh.attribute1) --PRJ10475

         ORDER BY rt.transaction_id DESC, rt.transaction_type;



   BEGIN

      log_put_line ('Procedure ' || l_proc_name || '. Begin');



      l_receipt_cnt := 0;



      FOR Recepit_LINE_Rec IN Recepit_LINE_C

      LOOP

         BEGIN

            IF l_chk_num = 0

            THEN

               l_qty := ABS (Recepit_LINE_REC.quantity);

               l_chk_num := 1;

            END IF;



            IF Recepit_LINE_REC.trans_type = 'DELIVER'

            THEN

               log_put_line (

                  'transaction_id ' || Recepit_LINE_REC.transaction_id);

               log_put_line (

                  'l_qty ' || l_qty || ' ' || Recepit_LINE_REC.rcv_qty);



               IF l_qty >= Recepit_LINE_REC.rcv_qty

               THEN

                  l_chk_ins := 0;

                  l_qty := l_qty - Recepit_LINE_REC.rcv_qty;

                  l_pass_qty := Recepit_LINE_REC.rcv_qty * -1;

               ELSE

                  l_chk_ins := 1;

               END IF;



               IF l_chk_ins = 1 AND l_qty > 0

               THEN

                  l_chk_ins := 0;

                  l_pass_qty := l_qty * -1;

                  l_qty := 0;

               END IF;

            END IF;



            IF l_chk_ins = 0 AND l_pass_qty <> 0

            THEN

               log_put_line (

                     'Inserting Correction transaction in '

                  || l_proc_name

                  || '. Begin');



               -----------insert into transaction table

               INSERT

                 INTO rcv_transactions_interface (interface_transaction_id  --

                                                                          ,

                                                  GROUP_ID,

                                                  last_update_date          --

                                                                  ,

                                                  last_updated_by           --

                                                                 ,

                                                  creation_date             --

                                                               ,

                                                  created_by                --

                                                            ,

                                                  last_update_login         --

                                                                   ,

                                                  transaction_type          --

                                                                  ,

                                                  transaction_date          --

                                                                  ,

                                                  processing_status_code    --

                                                                        ,

                                                  processing_mode_code      --

                                                                      ,

                                                  transaction_status_code   --

                                                                         ,

                                                  destination_type_code     --

                                                                       ,

                                                  quantity                  --

                                                          ,

                                                  item_id                   --

                                                         ,

                                                  auto_transact_code        --

                                                                    ,

                                                  vendor_id                 --

                                                           ,

                                                  vendor_site_id            --

                                                                ,

                                                  receipt_source_code,

                                                  source_document_code,

                                                  parent_transaction_id,

                                                  parent_interface_txn_id,

                                                  to_organization_id,

                                                  unit_of_measure,

                                                  validation_flag,

                                                  header_interface_id       --

                                                                     ,

                                                  po_header_id              --

                                                              ,

                                                  po_line_id                --

                                                            ,

                                                  po_release_id             --

                                                               ,

                                                  po_revision_num           --

                                                                 ,

                                                  po_line_location_id       --

                                                                     ,

                                                  location_id               --

                                                             ,

                                                  subinventory,

                                                  category_id,

                                                  org_id,

                                                  attribute1 -- Post-Live Changes by Jairaj, maintain legacy receipt number at line level

                                                            )

               VALUES (rcv_transactions_interface_s.NEXTVAL,

                       Recepit_LINE_REC.stage_group_id,

                       SYSDATE,

                       g_user_id,

                       SYSDATE,

                       g_user_id,

                       g_login_id,

                       Recepit_LINE_REC.transaction_type    --transaction_type

                                                        ,
                       to_date(Recepit_LINE_REC.transaction_date,'DD-MON-RRRR') --Julian
                       --TO_DATE (SYSDATE, 'DD-MON-RRRR') -- , to_date(Recepit_LINE_REC.transaction_date,'DD-MON-RRRR')--transaction_date -- Post-Live Changes by Jairaj

                                                       ,

                       Recepit_LINE_REC.processing_status_code --processing_status_code

                                                              ,

                       Recepit_LINE_REC.processing_mode_code --processing_mode_code

                                                            ,

                       Recepit_LINE_REC.transaction_status_code --transaction_status_code

                                                               ,

                       Recepit_LINE_REC.destination_type_code --destination_type_code

                                                             ,

                       l_pass_qty                                   --quantity

                                 ,

                       Recepit_LINE_REC.item_id                      --item_id

                                               ,

                       Recepit_LINE_REC.auto_transact_code --auto_transact_code

                                                          ,

                       Recepit_LINE_REC.vendor_id                  --vendor_id

                                                 ,

                       Recepit_LINE_REC.vendor_site_id        --vendor_site_id

                                                      ,

                       Recepit_LINE_REC.receipt_source_code --receipt_source_code

                                                           ,

                       Recepit_LINE_REC.source_document_code --source_document_code

                                                            ,

                       Recepit_LINE_REC.transaction_id  --praent_transation_id

                                                      ,

                       Recepit_LINE_REC.parent_interface_txn_id --PARENT_INTERFACE_TXN_ID

                                                               ,

                       Recepit_LINE_REC.to_organization_id --to_organization_id

                                                          ,

                       Recepit_LINE_REC.unit_of_measure      --unit_of_measure

                                                       ,

                       Recepit_LINE_REC.validation_flag      --validation_flag

                                                       ,

                       NULL                              --header_interface_id

                           ,

                       Recepit_LINE_REC.po_header_id            --po_header_id

                                                    ,

                       Recepit_LINE_REC.po_line_id                --po_line_id

                                                  ,

                       Recepit_LINE_REC.po_release_id          --po_release_id

                                                     ,

                       NULL                                  --po_revision_num

                           ,

                       Recepit_LINE_REC.po_line_location_id --po_line_location_id

                                                           ,

                       Recepit_LINE_REC.location_id              --location_id

                                                   ,

                       Recepit_LINE_REC.subinventory            --subinventory

                                                    ,

                       Recepit_LINE_REC.item_category_id    --item_category_id

                                                        ,

                       Recepit_LINE_REC.org_id                        --org_id

                                              ,

                       p_receipt_num -- Post-Live Changes by Jairaj, maintain legacy receipt number at line level

                                    );



               -- Post-Live Changes by Jairaj

               -- -------------------------------------------------------------------

               -- Update transaction to P only if insertion has happened

               -- -------------------------------------------------------------------

               l_receipt_cnt := l_receipt_cnt + 1;



               UPDATE bolinf.xxnbty_rcv_transactions_stg xrt

                  SET interface_transaction_id =

                         rcv_transactions_interface_s.CURRVAL,

                      stage_process_flag = g_sts_proc_constant

                WHERE     xrt.stage_record_id =

                             Recepit_LINE_REC.stage_record_id

                      AND xrt.stage_event_id =

                             Recepit_LINE_REC.stage_event_id;

            END IF;

         -- Insert again data for CORRECTION FOR RECIEVE transaction line

         EXCEPTION

            WHEN OTHERS

            THEN

               l_log_msg :=

                     ' Error While Correction trx Inserting into rcv_transaction_interface'

                  || SUBSTR (SQLERRM, 250);

               insert_trx_error (

                  p_proc_name   => l_proc_name,

                  p_log_msg     => l_log_msg,

                  p_event_id    => Recepit_LINE_REC.stage_event_id,

                  p_record_id   => Recepit_LINE_REC.stage_record_id);



               log_put_line (

                     'Unexpected Error in Procedure '

                  || l_proc_name

                  || '. Err='

                  || TO_CHAR (SQLCODE)

                  || ' '

                  || SQLERRM);

               p_error_msg := p_error_msg || l_log_msg;

               p_error_flag := APPS.fnd_api.g_true;



               -- Post-Live Changes by Jairaj

               -- -------------------------------------------------------------------

               -- Update transaction to E if any error encountered

               -- -------------------------------------------------------------------

               UPDATE bolinf.xxnbty_rcv_transactions_stg xrt

                  SET interface_transaction_id = NULL,

                      stage_process_flag = g_sts_err_constant

                WHERE     xrt.stage_record_id =

                             Recepit_LINE_REC.stage_record_id

                      AND xrt.stage_event_id =

                             Recepit_LINE_REC.stage_event_id;

         END;

      -- Post-Live Changes by Jairaj

      -- -------------------------------------------------------------------

      -- Update transaction to P only if insertion has happened

      -- -------------------------------------------------------------------

      /*

      UPDATE bolinf.xxnbty_rcv_transactions_stg xrt

         SET interface_transaction_id = rcv_transactions_interface_s.currval

           , stage_process_flag = g_sts_proc_constant

       WHERE xrt.stage_record_id = Recepit_LINE_REC.stage_record_id

         AND xrt.stage_event_id = Recepit_LINE_REC.stage_event_id;

      */

      END LOOP;



      -- Post-Live Changes by Jairaj

      -- -------------------------------------------------------------------

      -- Raise an error if insertion has failed for the CORRECT transaction

      -- -------------------------------------------------------------------

      IF l_receipt_cnt = 0

      THEN

         UPDATE bolinf.xxnbty_rcv_transactions_stg xrt

            SET stage_process_flag = g_sts_err_constant,

                stage_error_type = 'IMPORT'

          WHERE     xrt.stage_record_id = p_record_id

                AND xrt.stage_event_id = p_event_id;



        log_put_line('p_record_id '||p_record_id||' p_event_id '||p_event_id||' p_rec_header_id '||p_rec_header_id);



         UPDATE bolinf.xxnbty_rcv_headers_stg xrh

            SET stage_process_flag = g_sts_err_constant,

                stage_error_type = 'IMPORT'

          WHERE     xrh.stage_record_id = p_rec_header_id --p_record_id --correction error 03-Apr-2015

                AND xrh.stage_event_id = p_event_id;



         l_log_msg := ' Parent Transaction not found to CORRECT';



         insert_trx_error (p_proc_name   => l_proc_name,

                           p_log_msg     => l_log_msg,

                           p_event_id    => p_event_id,

                           p_record_id   => p_record_id);



         log_put_line (

            l_log_msg || l_proc_name || '. Stage Event =' || p_event_id);



         p_error_msg := p_error_msg || l_log_msg;

         p_error_flag := APPS.fnd_api.g_true;

      END IF;



      --COMMIT;

      log_put_line ('Procedure ' || l_proc_name || '. End.');

   EXCEPTION

      WHEN OTHERS

      THEN

         l_log_msg :=

               'Unexpected Error in Procedure '

            || l_proc_name

            || '. Err='

            || TO_CHAR (SQLCODE)

            || ' '

            || SQLERRM;

         log_put_line (l_log_msg);

         insert_error (g_event_id,

                       'ERROR',

                       l_proc_name,

                       l_log_msg);

   END load_correct_trx;



   ----------------------------------------------------------------------

   /*



    Pocedure Name: load_receipt_data

    Author? name: Amit Kumar (NBTY ERP Implementation)

    Date written: 09-Nov-12

    RICEFW Object id: NBTY-PRC-I-013

    Description: This Procedure will load Receipt records into Receipt Interface

    Program Style: Subordinate



    Maintenance History:



    Date Issue# Name Remarks

    ----------- -------- ---------------- ------------------------------------------

    09-Nov-12 Amit Kumar Initial development.



   */

   ----------------------------------------------------------------------



   PROCEDURE load_receipt_data (p_group_id            NUMBER,

                                p_error_flag   IN OUT VARCHAR2,

                                p_error_msg    IN OUT VARCHAR2)

   IS

      l_proc_name             VARCHAR (100)

                                 := 'XXNBTY_PO_RCV_IBI_FEEDER_PK.load_receipt_data';

      l_log_msg               VARCHAR2 (2000);

      l_header_interface_id   NUMBER;



      -- Post-Live Changes by Jairaj

      l_line_interface_id     NUMBER;

      lc_legacy_receipt_num   VARCHAR2 (30);



      CURSOR Recepit_HDR_C

      IS

           SELECT processing_status_code,

                  receipt_source_code,

                  transaction_type,

                  shipped_date,

                  legacy_vendor_num,

                  vendor_name,

                  vendor_num,

                  vendor_id,

                  vendor_site_id,

                  validation_flag,

                  expected_receipt_date,

                  creation_date,

                  ship_to_location_code,

                  ship_to_location_id,

                  employee_name,

                  legacy_site_code,

                  vendor_site_code,

                  receipt_num,

                  shipment_num,

                  currency_code,

                  stage_record_id,

                  stage_event_id,

                  stage_group_id,

                  stage_process_flag,

                  stage_process_attempts,

                  stage_last_update_date,

                  stage_last_updated_by,

                  stage_creation_date,

                  stage_created_by,

                  stage_last_update_login,

                  stage_request_id

             FROM bolinf.xxnbty_rcv_headers_stg xrh

            WHERE     1 = 1

                  AND xrh.stage_process_flag = g_sts_vld_constant

                  AND xrh.stage_request_id = g_request_id

         ORDER BY xrh.stage_event_id

         FOR UPDATE;



      CURSOR Recepit_LINE_C (

         cp_event_id NUMBER)

      IS

         SELECT DECODE (xrt.transaction_type,

                        'DELIVER', 'RECEIVE',

                        xrt.transaction_type)

                   transaction_type,

                xrt.auto_transact_code,

                xrt.destination_type_code,

                xrt.transaction_date,

                xrt.processing_status_code,

                xrt.processing_mode_code,

                xrt.source_document_code,

                xrt.transaction_status_code,

                xrt.quantity,

                xrt.legacy_item_num,

                xrt.item_num,

                xrt.item_id,

                xrt.item_category_id,

                xrt.unit_of_measure,

                xrt.receipt_source_code,

                xrt.parent_rec_transaction_id,

                xrt.parent_del_transaction_id,

                xrt.parent_interface_txn_id,

                xrt.to_organization_id,

                xrt.validation_flag,

                xrt.po_header_id,

                xrt.po_line_id,

                xrt.po_release_id,

                xrt.po_revision_num,

                xrt.po_line_location_id,

                xrt.location_id,

                xrt.org_id,

                xrt.document_num,

                xrt.document_line_num,

                -- // added shipment and Release num   31-Dec-2013 Shyam B - NBTY Procurement Implementation

                xrt.document_shipment_line_num,

                xrt.release_num,

                xrt.attribute4, --            24-feb-2014   Ship To location is stored in attribute4

                -- //

                xrt.subinventory,

                xrt.stage_record_id,

                xrt.stage_event_id

           FROM bolinf.xxnbty_rcv_transactions_stg xrt

          WHERE     1 = 1

                AND xrt.stage_request_id = g_request_id

                AND xrt.stage_event_id = cp_event_id

                -- AND xrt.stage_process_flag != 'G'  --PRJ10456 --Commented as part of INC828264

                AND xrt.stage_process_flag NOT IN ('G', 'I') --Added as part of INC828264

         FOR UPDATE;



   BEGIN

      log_put_line ('Procedure ' || l_proc_name || '. Begin');



      lc_legacy_receipt_num := NULL;



      FOR Recepit_HDR_Rec IN Recepit_HDR_C

      LOOP

         -- Post-Live Changes by Jairaj

         l_header_interface_id := NULL;



         lc_legacy_receipt_num := Recepit_HDR_REC.receipt_num;



         SELECT rcv_headers_interface_s.NEXTVAL

           INTO l_header_interface_id

           FROM DUAL;



         BEGIN

            INSERT INTO rcv_headers_interface (header_interface_id,

                                               GROUP_ID,

                                               processing_status_code,

                                               receipt_source_code,

                                               transaction_type,

                                               last_update_date,

                                               last_updated_by,

                                               last_update_login,

                                               created_by,

                                               creation_date,

                                               shipped_date,

                                               vendor_name,

                                               vendor_num,

                                               vendor_id,

                                               vendor_site_id,

                                               employee_name,

                                               validation_flag,

                                               location_id,

                                               expected_receipt_date,

                                               attribute1 -- receipt_num -- Post-Live Changes by Jairaj, mapping missing as per FD

                                                         ,

                                               shipment_num -- Post-Live Changes by Jairaj, mapping missing as per FD

                                                           )

                 VALUES (

                           l_header_interface_id,

                           p_group_id,

                           Recepit_HDR_REC.processing_status_code --processing_status_code

                                                                 ,

                           Recepit_HDR_REC.receipt_source_code --receipt_source_code

                                                              ,

                           Recepit_HDR_REC.transaction_type --transaction_type

                                                           ,

                           SYSDATE                          --last_update_date

                                  ,

                           g_user_id                                 --user id

                                    ,

                           g_login_id                      --last_update_login

                                     ,

                           g_user_id                                 --user id

                                    ,

                           TO_DATE (Recepit_HDR_REC.creation_date,

                                    'DD-MON-RRRR')            -- creation date

                                                  ,

                           Recepit_HDR_REC.shipped_date         --shipped_date

                                                       ,

                           Recepit_HDR_REC.vendor_name           --vendor_name

                                                      ,

                           Recepit_HDR_REC.vendor_num             --vendor_num

                                                     ,

                           Recepit_HDR_REC.vendor_id               --vendor_id

                                                    ,

                           Recepit_HDR_REC.vendor_site_id     --vendor_site_id

                                                         ,

                           Recepit_HDR_REC.employee_name       --employee_name

                                                        ,

                           Recepit_HDR_REC.validation_flag   --validation_flag

                                                          ,

                           Recepit_HDR_REC.ship_to_location_id   --location_id

                                                              ,

                           TO_DATE (Recepit_HDR_REC.expected_receipt_date,

                                    'DD-MON-RRRR')     --expected_receipt_date

                                                  ,

                           lc_legacy_receipt_num -- Post-Live Changes by Jairaj, mapping missing as per FD

                                                ,

                           Recepit_HDR_REC.shipment_num -- Post-Live Changes by Jairaj, mapping missing as per FD

                                                       );



            -- Post-Live Changes by Jairaj

            -- -------------------------------------------------------------

            -- Update header to P if insertion has happened

            -- -------------------------------------------------------------

            UPDATE bolinf.xxnbty_rcv_headers_stg xrh

               SET header_interface_id = l_header_interface_id,

                   stage_process_flag = g_sts_proc_constant

             WHERE CURRENT OF Recepit_HDR_C;

         EXCEPTION

            WHEN OTHERS

            THEN

               l_log_msg :=

                     ' Error While Inserting into rcv_headers_interface '

                  || SUBSTR (SQLERRM, 250);

               insert_hdr_error (

                  p_proc_name   => l_proc_name,

                  p_log_msg     => l_log_msg,

                  p_event_id    => Recepit_HDR_REC.stage_event_id,

                  p_record_id   => Recepit_HDR_REC.stage_record_id);



               log_put_line (

                     'Unexpected Error in Procedure '

                  || l_proc_name

                  || '. Err='

                  || TO_CHAR (SQLCODE)

                  || ' '

                  || SQLERRM);

               p_error_msg := l_log_msg;

               p_error_flag := APPS.fnd_api.g_true;



               -- Post-Live Changes by Jairaj

               -- -------------------------------------------------------------------------

               -- Update Header to E if insertion has failed

               -- -------------------------------------------------------------------------

               UPDATE bolinf.xxnbty_rcv_headers_stg xrh

                  SET header_interface_id = l_header_interface_id,

                      stage_process_flag = g_sts_err_constant

                WHERE CURRENT OF Recepit_HDR_C;

         END;



         -- Post-Live Changes by Jairaj

         /*

         UPDATE bolinf.xxnbty_rcv_headers_stg xrh

            SET header_interface_id = l_header_interface_id

             , stage_process_flag = g_sts_proc_constant

          WHERE CURRENT OF Recepit_HDR_C;

         */



         FOR Recepit_LINE_Rec

            IN Recepit_LINE_C (Recepit_HDR_REC.stage_event_id)

         LOOP

            -----------insert into transaction table

            IF Recepit_LINE_REC.transaction_type = 'CORRECT'

            THEN

               -- Post-Live Changes by Jairaj

               -- ---------------------------------------------------------------------------------------------------

               -- Modified below because if there is one event with multiple lines and has a CORRECT

               -- for rest of the lines to get created, header record must be present

               -- ---------------------------------------------------------------------------------------------------

               DELETE FROM rcv_headers_interface

                     WHERE     header_interface_id = l_header_interface_id

                           AND NOT EXISTS

                                      (SELECT 'X'

                                         FROM bolinf.xxnbty_rcv_transactions_stg xrt

                                        WHERE     xrt.stage_request_id =

                                                     g_request_id

                                              AND xrt.stage_event_id =

                                                     Recepit_HDR_REC.stage_event_id

                                              AND xrt.transaction_type <>

                                                     'CORRECT');



               -- l_header_interface_id := NULL;



               load_correct_trx (

                  p_event_id      => Recepit_LINE_REC.stage_event_id,

                  p_record_id     => Recepit_LINE_REC.stage_record_id,

                  p_rec_header_id => Recepit_HDR_REC.stage_record_id, --correction error 03-Apr-2015

                  p_receipt_num   => lc_legacy_receipt_num,

                  p_error_flag    => p_error_flag,

                  p_error_msg     => p_error_msg -- Post-Live Changes by Jairaj

                                                );

            ELSE

               -- Post-Live Changes by Jairaj



               l_line_interface_id := NULL;



               SELECT rcv_transactions_interface_s.NEXTVAL

                 INTO l_line_interface_id

                 FROM DUAL;



               BEGIN

                  INSERT

                    INTO rcv_transactions_interface (interface_transaction_id --
                                                                             ,
                                                     GROUP_ID,
                                                     last_update_date       --
                                                                     ,
                                                     last_updated_by        --
                                                                    ,
                                                     creation_date          --
                                                                  ,
                                                     created_by             --
                                                               ,
                                                     last_update_login      --
                                                                      ,
                                                     transaction_type       --
                                                                     ,
                                                     transaction_date       --

                                                                     ,

                                                     processing_status_code --

                                                                           ,

                                                     processing_mode_code   --

                                                                         ,

                                                     transaction_status_code --

                                                                            ,

                                                     destination_type_code  --

                                                                          ,

                                                     quantity               --

                                                             ,

                                                     item_id                --

                                                            ,

                                                     auto_transact_code     --

                                                                       ,

                                                     ship_to_location_code  --

                                                                          ,

                                                     vendor_id              --

                                                              ,

                                                     vendor_site_id         --

                                                                   ,

                                                     receipt_source_code,

                                                     source_document_code,

                                                     parent_transaction_id,

                                                     parent_interface_txn_id,

                                                     to_organization_id,

                                                     unit_of_measure,

                                                     validation_flag,

                                                     header_interface_id    --

                                                                        ,

                                                     po_header_id           --

                                                                 ,

                                                     po_line_id             --

                                                               ,

                                                     po_release_id          --

                                                                  ,

                                                     po_revision_num        --

                                                                    ,

                                                     po_line_location_id    --

                                                                        ,

                                                     location_id            --

                                                                ,

                                                     subinventory,

                                                     category_id,

                                                     org_id,

                                                     attribute1 -- Post-Live Changes by Jairaj, maintain legacy receipt number at line level

                                                               )

                  VALUES (l_line_interface_id -- rcv_transactions_interface_s.NEXTVAL -- Post-Live Changes by Jairaj

                                             ,

                          p_group_id,

                          SYSDATE,

                          g_user_id,

                          SYSDATE,

                          g_user_id,

                          g_login_id,

                          Recepit_LINE_REC.transaction_type --transaction_type

                                                           ,
                          to_date(Recepit_LINE_REC.transaction_date,'DD-MON-RRRR') --Julian
                          --TO_DATE (SYSDATE, 'DD-MON-RRRR') -- , to_date(Recepit_LINE_REC.transaction_date,'DD-MON-RRRR')--transaction_date -- Post-Live Changes by Jairaj

                                                          ,

                          Recepit_LINE_REC.processing_status_code --processing_status_code

                                                                 ,

                          Recepit_LINE_REC.processing_mode_code --processing_mode_code

                                                               ,

                          Recepit_LINE_REC.transaction_status_code --transaction_status_code

                                                                  ,

                          Recepit_LINE_REC.destination_type_code --destination_type_code

                                                                ,

                          Recepit_LINE_REC.quantity                 --quantity

                                                   ,

                          Recepit_LINE_REC.item_id                   --item_id

                                                  ,

                          Recepit_LINE_REC.auto_transact_code --auto_transact_code

                                                             --// 24-Feb-2014 NBTY Procurment implementation

                                                             -- Ship to LOcation code to be defaulted from

                                                             -- PO shipment INformation

                                                             -- , Recepit_HDR_REC.ship_to_location_code             --ship_to_location_id

                          ,

                          Recepit_LINE_REC.attribute4 -- ship_to_location_code

                                                     --// 24-Feb-2014

                          ,

                          Recepit_HDR_REC.vendor_id                --vendor_id

                                                   ,

                          Recepit_HDR_REC.vendor_site_id      --vendor_site_id

                                                        ,

                          Recepit_LINE_REC.receipt_source_code --receipt_source_code

                                                              ,

                          Recepit_LINE_REC.source_document_code --source_document_code

                                                               ,

                          Recepit_LINE_REC.parent_del_transaction_id --praent_transation_id

                                                                    ,

                          Recepit_LINE_REC.parent_interface_txn_id --PARENT_INTERFACE_TXN_ID

                                                                  ,

                          Recepit_LINE_REC.to_organization_id --to_organization_id

                                                             ,

                          Recepit_LINE_REC.unit_of_measure   --unit_of_measure

                                                          ,

                          Recepit_LINE_REC.validation_flag   --validation_flag

                                                          ,

                          l_header_interface_id          --header_interface_id

                                               ,

                          Recepit_LINE_REC.po_header_id         --po_header_id

                                                       ,

                          Recepit_LINE_REC.po_line_id             --po_line_id

                                                     ,

                          Recepit_LINE_REC.po_release_id       --po_release_id

                                                        ,

                          NULL                               --po_revision_num

                              ,

                          Recepit_LINE_REC.po_line_location_id --po_line_location_id

                                                              ,

                          Recepit_LINE_REC.location_id           --location_id

                                                      ,

                          Recepit_LINE_REC.subinventory         --subinventory

                                                       ,

                          Recepit_LINE_REC.item_category_id --item_category_id

                                                           ,

                          Recepit_LINE_REC.org_id                     --org_id

                                                 ,

                          lc_legacy_receipt_num -- Post-Live Changes by Jairaj, maintain legacy receipt number at line level

                                               );





                  -- Post-Live Changes by Jairaj

                  -- -------------------------------------------------------------

                  -- Update line to P if insertion has happened

                  -- -------------------------------------------------------------

                  UPDATE bolinf.xxnbty_rcv_transactions_stg xrt

                     SET header_interface_id = l_header_interface_id,

                         interface_transaction_id = l_line_interface_id,

                         stage_process_flag = g_sts_proc_constant

                   WHERE CURRENT OF Recepit_LINE_C;

               EXCEPTION

                  WHEN OTHERS

                  THEN

                     l_log_msg :=

                           ' Error While Inserting into rcv_transaction_interface'

                        || SUBSTR (SQLERRM, 250);

                     insert_trx_error (

                        p_proc_name   => l_proc_name,

                        p_log_msg     => l_log_msg,

                        p_event_id    => Recepit_LINE_REC.stage_event_id,

                        p_record_id   => Recepit_LINE_REC.stage_record_id);



                     log_put_line (

                           'Unexpected Error in Procedure '

                        || l_proc_name

                        || '. Err='

                        || TO_CHAR (SQLCODE)

                        || ' '

                        || SQLERRM);

                     p_error_msg := p_error_msg || l_log_msg;

                     p_error_flag := APPS.fnd_api.g_true;



                     -- Post-Live Changes by Jairaj

                     -- -------------------------------------------------------------

                     -- Update line to E if insertion has failed

                     -- -------------------------------------------------------------

                     UPDATE bolinf.xxnbty_rcv_transactions_stg xrt

                        SET header_interface_id = l_header_interface_id,

                            interface_transaction_id = l_line_interface_id,

                            stage_process_flag = g_sts_err_constant

                      WHERE CURRENT OF Recepit_LINE_C;

               END;

            /*

            UPDATE bolinf.xxnbty_rcv_transactions_stg xrt

               SET header_interface_id = l_header_interface_id

                 , interface_transaction_id = rcv_transactions_interface_s.currval

                 , stage_process_flag = g_sts_proc_constant

             WHERE CURRENT OF Recepit_LINE_C;

           */

            END IF;     /* IF Recepit_LINE_REC.transaction_type = 'CORRECT' */

         END LOOP;

      END LOOP;



      COMMIT;

      log_put_line ('Procedure ' || l_proc_name || '. End.');

   EXCEPTION

      WHEN OTHERS

      THEN

         l_log_msg :=

               'Unexpected Error in Procedure '

            || l_proc_name

            || '. Err='

            || TO_CHAR (SQLCODE)

            || ' '

            || SQLERRM;

         log_put_line (l_log_msg);

         insert_error (g_event_id,

                       'ERROR',

                       l_proc_name,

                       l_log_msg);

   END load_receipt_data;



   ----------------------------------------------------------------------

   /*



    Pocedure Name: submit_receipt_request

    Author? name: Amit Kumar (NBTY ERP Implementation)

    Date written: 09-Nov-12

    RICEFW Object id: NBTY-PRC-I-013

    Description: This Procedure will Submitt the request from

    Program Style: Subordinate



    Maintenance History:



    Date Issue# Name Remarks

    ----------- -------- ---------------- ------------------------------------------

    09-Nov-12 Amit Kumar Initial development.



   */

   ----------------------------------------------------------------------



   PROCEDURE submit_receipt_request (

      p_group_id                        VARCHAR2,

      p_rept_request_id      OUT NOCOPY NUMBER,

      p_prog_status          OUT NOCOPY NUMBER,

      p_err_msg              OUT NOCOPY VARCHAR2)

   IS

      l_proc_name        VARCHAR (100)

         := 'XXNBTY_PO_RCV_IBI_FEEDER_PK.Submit Receipt Request';

      l_rept_req_id      NUMBER;

      l_phas_out         VARCHAR2 (60);

      l_status_out       VARCHAR2 (60);

      l_dev_phase_out    VARCHAR2 (60);

      l_dev_status_out   VARCHAR2 (60);

      l_message_out      VARCHAR2 (200);

      l_bflag            BOOLEAN;

      l_req_err_msg      VARCHAR2 (4000);

      l_rept_rec_found   NUMBER;

      l_log_msg          VARCHAR2 (500);

   BEGIN

      l_req_err_msg := NULL;

      l_rept_req_id := NULL;

      log_put_line ('Procedure ' || l_proc_name || '. Begin');



      SELECT COUNT (1)

        INTO l_rept_rec_found

        FROM rcv_headers_interface rhi, rcv_transactions_interface rti

       WHERE     rti.GROUP_ID = p_group_id

             AND rhi.header_interface_id(+) = rti.header_interface_id

             AND rti.processing_status_code = 'PENDING';



      log_put_line (

            'Submitting the Request : Records Found For Receipt :'

         || l_rept_rec_found);



      IF l_rept_rec_found > 0

      THEN

         log_put_line (

               'Submitting the Request : Records Found For Receipt :'

            || l_rept_rec_found);

         log_put_line ('Call Fnd_Request.submit_request');

         l_rept_req_id :=

            APPS.fnd_request.submit_request (application   => 'PO',

                                             program       => 'RVCTP',

                                             description   => ' ',

                                             start_time    => SYSDATE,

                                             sub_request   => FALSE,

                                             argument1     => 'BATCH',

                                             argument2     => p_group_id);

         log_put_line (

               'request is sumitted for Receiving Transaction Processor :'

            || l_rept_req_id);

         COMMIT;



         IF l_rept_req_id != 0

         THEN

            log_put_line ('Call fnd_concurrent.wait_FOR_request');

            l_dev_phase_out := 'Start';



            WHILE UPPER (NVL (l_dev_phase_out, 'XX')) != 'COMPLETE'

            LOOP

               l_bflag :=

                  APPS.fnd_concurrent.wait_for_request (l_rept_req_id,

                                                        5,

                                                        50,

                                                        l_phas_out,

                                                        l_status_out,

                                                        l_dev_phase_out,

                                                        l_dev_status_out,

                                                        l_message_out);

            END LOOP;

         END IF;



         log_put_line (

               'request is sumitted FOR Receiving Transaction Processor :'

            || l_rept_req_id);

         log_put_line (

            '...............................................................');



         IF l_rept_req_id != 0

         THEN

            NULL;

         ELSE

            log_put_line (

               'Problem in calling Receivibng Transaction Processor');

            l_req_err_msg :=

               'Problem in calling Receiving Transaction Processor';

         END IF;

      ELSE

         log_put_line ('NO Record Found for the Process Batch ID');

         l_req_err_msg := 'NO Record Found for the Process Batch ID';

      END IF;



      p_err_msg := l_req_err_msg;

      p_prog_status := NULL;

      p_rept_request_id := l_rept_req_id;

      log_put_line ('Procedure ' || l_proc_name || '. End.');

   EXCEPTION

      WHEN OTHERS

      THEN

         l_log_msg :=

               'Unexpected Error in Procedure '

            || l_proc_name

            || '. Err='

            || TO_CHAR (SQLCODE)

            || ' '

            || SQLERRM;

         log_put_line (l_log_msg);

         insert_error (g_event_id,

                       'ERROR',

                       l_proc_name,

                       l_log_msg);

         p_err_msg := l_req_err_msg;

         p_prog_status := 2;

         p_rept_request_id := l_rept_req_id;

   END submit_receipt_request;



   ----------------------------------------------------------------------

   /*



    Pocedure Name: inf_err_insert_log

    Author? name: Amit Kumar (NBTY ERP Implementation)

    Date written: 09-Nov-12

    RICEFW Object id: NBTY-PRC-I-013

    Description: inf_err_insert_log procedure check error in po error

                      table and update error in error table and pl/sql table.

    Program Style: Subordinate



    Maintenance History:



    Date Issue# Name Remarks

    ----------- -------- ---------------- ------------------------------------------

    09-Nov-12 Amit Kumar Initial development.



   */

   ----------------------------------------------------------------------



   PROCEDURE inf_err_insert_log (p_group_id IN NUMBER)

   IS

      l_proc_name      VARCHAR2 (100)

                          := 'XXNBTY_PO_RCV_IBI_FEEDER_PK.inf_err_insert_log';

      l_h_cnt          NUMBER := 1;

      l_t_cnt          NUMBER := 1;

      l_log_msg        VARCHAR2 (500);

      l_stg_event_id   NUMBER := 0;                 -- added for INC740356 fix



      CURSOR ins_hdr_c

      IS

         SELECT pie.column_name,

                pie.error_message,

                pie.error_message_name,

                rhs.stage_event_id,

                rhs.stage_record_id,

                rhs.stage_process_attempts,

                rhs.header_interface_id

           FROM po_interface_errors pie,

                rcv_headers_interface rhi,

                bolinf.xxnbty_rcv_headers_stg rhs

          WHERE     pie.table_name = 'RCV_HEADERS_INTERFACE'

                AND rhi.header_interface_id = pie.interface_header_id

                AND rhi.processing_status_code = 'ERROR'

                AND rhi.header_interface_id = rhs.header_interface_id

                AND rhi.GROUP_ID = p_group_id

                AND rhs.stage_request_id = g_request_id;



      CURSOR ins_line_c

      IS

           SELECT pie.column_name,

                  pie.error_message,

                  pie.error_message_name,

                  rts.stage_event_id,

                  rti.interface_transaction_id,

                  rts.stage_record_id

             FROM po_interface_errors pie,

                  rcv_transactions_interface rti,

                  bolinf.xxnbty_rcv_transactions_stg rts

            WHERE     pie.table_name = 'RCV_TRANSACTIONS_INTERFACE'

                  AND rti.interface_transaction_id = pie.interface_line_id

                  AND (   rti.processing_status_code = 'ERROR'

                       OR rti.transaction_status_code = 'ERROR')

                  AND rti.interface_transaction_id =

                         rts.interface_transaction_id

                  AND rti.GROUP_ID = p_group_id

                  AND rts.stage_request_id = g_request_id

         ORDER BY rts.stage_event_id;               -- added for INC740356 fix



   BEGIN

      log_put_line ('Procedure ' || l_proc_name || '. Begin');

      l_h_cnt := g_hdr_cnt;



      IF l_h_cnt = 1

      THEN

         l_h_cnt := 0;

      ELSE

         l_h_cnt := l_h_cnt - 1;

      END IF;



      l_t_cnt := g_trx_cnt;



      IF l_t_cnt = 1

      THEN

         l_t_cnt := 0;

      ELSE

         l_t_cnt := l_t_cnt - 1;

      END IF;





      FOR ins_hdr_rec IN ins_hdr_c

      LOOP

         -- Update staging Interface table status

         UPDATE bolinf.xxnbty_rcv_headers_stg

            SET stage_process_flag = g_sts_err_constant,

                stage_process_attempts = NVL (stage_process_attempts, 0) + 1,

                stage_error_type = 'IMPORT'

          WHERE stage_event_id = ins_hdr_rec.stage_event_id;



         UPDATE bolinf.xxnbty_rcv_transactions_stg

            SET stage_process_flag = g_sts_partial_int,

                stage_error_type = 'IMPORT'

          WHERE stage_event_id = ins_hdr_rec.stage_event_id;



         insert_hdr_error (p_proc_name   => l_proc_name,

                           p_log_msg     => ins_hdr_rec.error_message,

                           p_event_id    => ins_hdr_rec.stage_event_id,

                           p_record_id   => ins_hdr_rec.stage_record_id);



         IF l_h_cnt >= 1

         THEN

            FOR UPD_HDR_REC IN G_REC_HDR_Table.FIRST .. G_REC_HDR_Table.LAST

            LOOP

               IF     G_REC_HDR_Table (UPD_HDR_REC).stage_event_id =

                         ins_hdr_rec.stage_event_id

                  AND G_REC_HDR_Table (UPD_HDR_REC).stage_process_flag =

                         g_sts_proc_constant

               THEN

                  G_REC_HDR_Table (UPD_HDR_REC).stage_process_flag :=

                     g_sts_err_constant;

                  G_REC_HDR_Table (UPD_HDR_REC).status := 'ERROR';

                  G_REC_HDR_Table (UPD_HDR_REC).stage_error_type := 'IMPORT';

                  G_REC_HDR_Table (UPD_HDR_REC).Msg :=

                     ins_hdr_rec.error_message;

               END IF;

            END LOOP;

         END IF;



         IF l_t_cnt >= 1

         THEN

            FOR upd_line_rec IN G_Rec_Trx_Table.FIRST .. G_Rec_Trx_Table.LAST

            LOOP

               IF G_Rec_Trx_Table (upd_line_rec).stage_event_id =

                     ins_hdr_rec.stage_event_id

               THEN

                  G_Rec_Trx_Table (upd_line_rec).stage_process_flag :=

                     g_sts_err_constant;

                  G_Rec_Trx_Table (upd_line_rec).status := 'PARTLY';

                  G_Rec_Trx_Table (upd_line_rec).stage_error_type := 'IMPORT';

                  G_Rec_Trx_Table (upd_line_rec).Msg :=

                     ins_hdr_rec.error_message;

               END IF;

            END LOOP;

         END IF;



         g_retcode_err := retcde_failure_constant;

      END LOOP;



      FOR ins_line_rec IN ins_line_c

      LOOP

         -- Update staging Interface table status

         UPDATE bolinf.xxnbty_rcv_transactions_stg

            SET stage_process_flag = g_sts_err_constant --g_sts_partial_int --Commented/changed as part of INC828264

                                                       ,

                stage_error_type = 'IMPORT'

          WHERE interface_transaction_id =

                   ins_line_rec.interface_transaction_id;



         --Added as part of INC828264

         UPDATE bolinf.xxnbty_rcv_transactions_stg

            SET stage_process_flag = g_sts_err_constant --g_sts_partial_int --Commented/changed as part of INC828264

                                                       ,

                stage_error_type = 'IMPORT'

          WHERE     interface_transaction_id IN

                       (SELECT rti.interface_transaction_id

                          FROM rcv_transactions_interface rti,

                               bolinf.xxnbty_rcv_transactions_stg rts

                         WHERE     (   rti.processing_status_code = 'ERROR'

                                    OR rti.transaction_status_code = 'ERROR')

                               AND rti.interface_transaction_id =

                                      rts.interface_transaction_id

                               AND rti.GROUP_ID = p_group_id

                               AND rts.stage_request_id = g_request_id)

                AND stage_event_id = ins_line_rec.stage_event_id;





         IF l_stg_event_id != ins_line_rec.stage_event_id

         THEN                                       -- added for INC740356 fix

            l_stg_event_id := ins_line_rec.stage_event_id; -- added for INC740356 fix



            UPDATE bolinf.xxnbty_rcv_headers_stg

               SET stage_process_flag = g_sts_err_constant --g_sts_partial_int --Commented/changed as part of INC828264

                                                          ,

                   stage_error_type = 'IMPORT',

                   stage_process_attempts =

                      NVL (stage_process_attempts, 0) + 1 -- added for INC740356 fix

             WHERE stage_event_id = ins_line_rec.stage_event_id;

         END IF;                                    -- added for INC740356 fix



         insert_trx_error (p_proc_name   => l_proc_name,

                           p_log_msg     => ins_line_rec.error_message,

                           p_event_id    => ins_line_rec.stage_event_id,

                           p_record_id   => ins_line_rec.stage_record_id);



         -- update Trans status in pl/sql table

         IF l_h_cnt >= 1

         THEN

            FOR UPD_HDR_REC IN G_REC_HDR_Table.FIRST .. G_REC_HDR_Table.LAST

            LOOP

               IF     G_REC_HDR_Table (UPD_HDR_REC).stage_event_id =

                         ins_line_rec.stage_event_id

                  AND G_REC_HDR_Table (UPD_HDR_REC).stage_process_flag =

                         g_sts_proc_constant

               THEN

                  G_REC_HDR_Table (UPD_HDR_REC).stage_process_flag :=

                     g_sts_err_constant;

                  G_REC_HDR_Table (UPD_HDR_REC).status := 'PARTLY';

                  G_REC_HDR_Table (UPD_HDR_REC).stage_error_type := 'IMPORT';

                  G_REC_HDR_Table (UPD_HDR_REC).Msg :=

                     ins_line_rec.error_message;

               END IF;

            END LOOP;

         END IF;



         IF l_t_cnt >= 1

         THEN

            FOR upd_line_rec IN G_Rec_Trx_Table.FIRST .. G_Rec_Trx_Table.LAST

            LOOP

               IF     G_Rec_Trx_Table (upd_line_rec).stage_event_id =

                         ins_line_rec.stage_event_id

                  AND G_Rec_Trx_Table (upd_line_rec).stage_record_id =

                         ins_line_rec.stage_record_id

               THEN

                  G_Rec_Trx_Table (upd_line_rec).stage_process_flag :=

                     g_sts_err_constant;

                  G_Rec_Trx_Table (upd_line_rec).status := 'PARTLY';

                  G_Rec_Trx_Table (upd_line_rec).stage_error_type := 'IMPORT';

                  G_Rec_Trx_Table (upd_line_rec).Msg :=

                     ins_line_rec.error_message;

               END IF;

            END LOOP;

         END IF;



         g_retcode_err := retcde_failure_constant;

      END LOOP;



      COMMIT;

      log_put_line ('Procedure ' || l_proc_name || '. End.');

   EXCEPTION

      WHEN OTHERS

      THEN

         l_log_msg :=

               'Unexpected Error in Procedure '

            || l_proc_name

            || '. Err='

            || TO_CHAR (SQLCODE)

            || ' '

            || SQLERRM;

         log_put_line (l_log_msg);

         insert_error (g_event_id,

                       'ERROR',

                       l_proc_name,

                       l_log_msg);

   END inf_err_insert_log;



   ----------------------------------------------------------------------

   /*



    Pocedure Name: upd_event_tbl

    Author? name: Amit Kumar (NBTY ERP Implementation)

    Date written: 09-Nov-12

    RICEFW Object id: NBTY-PRC-I-013

    Description: upd_event_tbl procedure Update status of record in event table

    Program Style: Subordinate



    Maintenance History:



    Date Issue# Name Remarks

    ----------- -------- ---------------- ------------------------------------------

    09-Nov-12 Amit Kumar Initial development.



   */

   ----------------------------------------------------------------------



   PROCEDURE upd_event_tbl (p_group_id IN NUMBER)

   IS

      l_proc_name   VARCHAR2 (100)

                       := 'XXNBTY_PO_RCV_IBI_FEEDER_PK.upd_event_tbl';

      l_log_msg     VARCHAR2 (500);



      CURSOR upd_event_c

      IS

         SELECT rhs.stage_event_id,

                NVL (rhs.stage_process_attempts, 0) stage_process_attempts,

                DECODE (rhs.stage_process_flag,

                        g_sts_proc_constant, g_sts_int_constant,

                        g_sts_err_constant)

                   stage_process_flag

           FROM bolinf.xxnbty_rcv_headers_stg rhs

          WHERE     rhs.stage_group_id = p_group_id

                AND rhs.stage_request_id = g_request_id;



   BEGIN

      log_put_line ('Procedure ' || l_proc_name || '. Begin');



      FOR upd_event_rec IN upd_event_c

      LOOP

         log_put_line (

               'Updating stage process flag with '

            || upd_event_rec.stage_process_flag

            || ' for Event'

            || upd_event_rec.stage_event_id);



         -- Update Event table status

         UPDATE xxnbty_ibi_events

            SET event_status = upd_event_rec.stage_process_flag,

                processed_attempts = upd_event_rec.stage_process_attempts,

                request_id_feeder_program = g_request_id,

                last_updated_by = g_user_id,

                last_update_date = SYSDATE

          WHERE event_id = upd_event_rec.stage_event_id;



         -- updating ""P"" records to ""I""

         UPDATE xxnbty_rcv_headers_stg

            SET stage_process_flag = upd_event_rec.stage_process_flag

          WHERE stage_event_id = upd_event_rec.stage_event_id;



         -- updating ""P"" records to ""I""

         IF upd_event_rec.stage_process_flag = 'E'

         THEN                                       -- added for INC828264 fix

            -- updating ""L"" records to ""I""

            UPDATE xxnbty_rcv_transactions_stg      -- added for INC828264 fix

               SET stage_process_flag = g_sts_int_constant

             WHERE     stage_event_id = upd_event_rec.stage_event_id

                   AND stage_process_flag != g_sts_err_constant;



            -- updating remaining records with status as that of header

            UPDATE xxnbty_rcv_transactions_stg      -- added for INC828264 fix

               SET stage_process_flag = upd_event_rec.stage_process_flag

             WHERE     stage_event_id = upd_event_rec.stage_event_id

                   AND stage_process_flag != g_sts_int_constant;

         ELSE

            UPDATE xxnbty_rcv_transactions_stg

               SET stage_process_flag = upd_event_rec.stage_process_flag

             WHERE stage_event_id = upd_event_rec.stage_event_id;

         END IF;

      END LOOP;



      COMMIT;

      log_put_line ('Procedure ' || l_proc_name || '. End.');

   EXCEPTION

      WHEN OTHERS

      THEN

         l_log_msg :=

               'Unexpected Error in Procedure '

            || l_proc_name

            || '. Err='

            || TO_CHAR (SQLCODE)

            || ' '

            || SQLERRM;

         log_put_line (l_log_msg);

         insert_error (g_event_id,

                       'ERROR',

                       l_proc_name,

                       l_log_msg);

   END upd_event_tbl;



   ----------------------------------------------------------------------

   /*



    Pocedure Name: upd_hdr_staging

    Author? name: Amit Kumar (NBTY ERP Implementation)

    Date written: 09-Nov-12

    RICEFW Object id: NBTY-PRC-I-013

    Description: Update Header Staging table

    Program Style: Subordinate



    Maintenance History:



    Date Issue# Name Remarks

    ----------- -------- ---------------- ------------------------------------------

    09-Nov-12 Amit Kumar Initial development.



   */

   ----------------------------------------------------------------------



   PROCEDURE upd_hdr_staging

   IS

      l_proc_name   VARCHAR2 (100)

                       := 'XXNBTY_PO_RCV_IBI_FEEDER_PK.upd_hdr_staging';

      l_cnt         NUMBER := 0;

      l_log_msg     VARCHAR2 (500);

   BEGIN

      log_put_line ('Procedure ' || l_proc_name || '. Begin');

      l_cnt := g_hdr_cnt;



      IF l_cnt = 1

      THEN

         l_cnt := 0;

      ELSE

         l_cnt := l_cnt - 1;

      END IF;



      log_put_line ('l_cnt ' || l_cnt);

      log_put_line ('count ' || G_REC_HDR_Table.COUNT);



      IF l_cnt >= 1

      THEN

         FOR hdr_rec IN G_REC_HDR_Table.FIRST .. G_REC_HDR_Table.LAST

         LOOP

            -- Update staging Interface table

            BEGIN

               UPDATE bolinf.xxnbty_rcv_headers_stg

                  SET stage_group_id =

                         G_REC_HDR_Table (hdr_rec).stage_group_id,

                      processing_status_code =

                         G_REC_HDR_Table (hdr_rec).processing_status_code,

                      receipt_source_code =

                         G_REC_HDR_Table (hdr_rec).receipt_source_code,

                      transaction_type =

                         G_REC_HDR_Table (hdr_rec).transaction_type,

                      shipped_date = G_REC_HDR_Table (hdr_rec).shipped_date,

                      vendor_name = G_REC_HDR_Table (hdr_rec).vendor_name,

                      vendor_num = G_REC_HDR_Table (hdr_rec).vendor_num,

                      vendor_id = G_REC_HDR_Table (hdr_rec).vendor_id,

                      vendor_site_id =

                         G_REC_HDR_Table (hdr_rec).vendor_site_id,

                      validation_flag =

                         G_REC_HDR_Table (hdr_rec).validation_flag,

                      ship_to_location_code =

                         G_REC_HDR_Table (hdr_rec).ship_to_location_code,

                      employee_name = G_REC_HDR_Table (hdr_rec).employee_name,

                      vendor_site_code =

                         G_REC_HDR_Table (hdr_rec).vendor_site_code,

                      receipt_num = G_REC_HDR_Table (hdr_rec).receipt_num,

                      shipment_num = G_REC_HDR_Table (hdr_rec).shipment_num,

                      currency_code = G_REC_HDR_Table (hdr_rec).currency_code,

                      stage_process_flag =

                         G_REC_HDR_Table (hdr_rec).stage_process_flag,

                      stage_process_attempts =

                         G_REC_HDR_Table (hdr_rec).stage_process_attempts,

                      stage_error_type =

                         G_REC_HDR_Table (hdr_rec).stage_error_type,

                      stage_last_update_date =

                         G_REC_HDR_Table (hdr_rec).stage_last_update_date,

                      stage_last_updated_by =

                         G_REC_HDR_Table (hdr_rec).stage_last_updated_by,

                      stage_last_update_login =

                         G_REC_HDR_Table (hdr_rec).stage_last_update_login,

                      stage_request_id =

                         G_REC_HDR_Table (hdr_rec).stage_request_id,

                      ship_to_location_id =

                         G_REC_HDR_Table (hdr_rec).ship_to_location_id -- Post-Live Changes by Jairaj , ship to location id was being derived but not updated. Hence added

                WHERE stage_event_id =

                         G_REC_HDR_Table (hdr_rec).stage_event_id;

            EXCEPTION

               WHEN OTHERS

               THEN

                  insert_hdr_error (

                     p_proc_name   => l_proc_name,

                     p_log_msg     => 'Update HDR Table ' || SQLERRM,

                     p_event_id    => G_REC_HDR_Table (hdr_rec).stage_event_id,

                     p_record_id   => G_REC_HDR_Table (hdr_rec).stage_record_id);



                  log_put_line (

                        'Update HDR Table Procedure '

                     || l_proc_name

                     || '. Err='

                     || TO_CHAR (SQLCODE)

                     || ' '

                     || SQLERRM);

            END;

         END LOOP;

      END IF;



      COMMIT;

      log_put_line ('Procedure ' || l_proc_name || '. End.');

   EXCEPTION

      WHEN OTHERS

      THEN

         l_log_msg :=

               'Unexpected Error in Procedure '

            || l_proc_name

            || '. Err='

            || TO_CHAR (SQLCODE)

            || ' '

            || SQLERRM;

         log_put_line (l_log_msg);

         insert_error (g_event_id,

                       'ERROR',

                       l_proc_name,

                       l_log_msg);

   END upd_hdr_staging;



   ----------------------------------------------------------------------

   /*



    Pocedure Name: upd_trx_staging

    Author? name: Amit Kumar (NBTY ERP Implementation)

    Date written: 09-Nov-12

    RICEFW Object id: NBTY-PRC-I-013

    Description: Update column in Transaction staging table

    Program Style: Subordinate



    Maintenance History:



    Date Issue# Name Remarks

    ----------- -------- ---------------- ------------------------------------------

    09-Nov-12 Amit Kumar Initial development.



   */

   ----------------------------------------------------------------------



   PROCEDURE upd_trx_staging

   IS

      l_proc_name   VARCHAR2 (100)

                       := 'XXNBTY_PO_RCV_IBI_FEEDER_PK.upd_trx_staging';

      l_cnt         NUMBER := 0;

      l_log_msg     VARCHAR2 (500);

   BEGIN

      log_put_line ('Procedure ' || l_proc_name || '. Begin');

      l_cnt := g_trx_cnt;



      IF l_cnt = 1

      THEN

         l_cnt := 0;

      ELSE

         l_cnt := l_cnt - 1;

      END IF;



      log_put_line ('l_cnt ' || l_cnt);



      IF l_cnt >= 1

      THEN

         FOR line_rec IN G_Rec_Trx_Table.FIRST .. G_Rec_Trx_Table.LAST

         LOOP

            -- Update staging Interface table

            UPDATE bolinf.xxnbty_rcv_transactions_stg

               SET transaction_type =

                      G_Rec_Trx_Table (line_rec).transaction_type,

                   auto_transact_code =

                      G_Rec_Trx_Table (line_rec).auto_transact_code,

                   destination_type_code =

                      G_Rec_Trx_Table (line_rec).destination_type_code,

                   processing_status_code =

                      G_Rec_Trx_Table (line_rec).processing_status_code,

                   processing_mode_code =

                      G_Rec_Trx_Table (line_rec).processing_mode_code,

                   source_document_code =

                      G_Rec_Trx_Table (line_rec).source_document_code,

                   transaction_status_code =

                      G_Rec_Trx_Table (line_rec).transaction_status_code,

                   quantity = G_Rec_Trx_Table (line_rec).quantity,

                   item_num = G_Rec_Trx_Table (line_rec).item_num,

                   item_id = G_Rec_Trx_Table (line_rec).item_id,

                   item_category_id =

                      G_Rec_Trx_Table (line_rec).item_category_id,

                   unit_of_measure =

                      G_Rec_Trx_Table (line_rec).unit_of_measure,

                   receipt_source_code =

                      G_Rec_Trx_Table (line_rec).receipt_source_code,

                   parent_rec_transaction_id =

                      G_Rec_Trx_Table (line_rec).parent_rec_transaction_id,

                   parent_del_transaction_id =

                      G_Rec_Trx_Table (line_rec).parent_del_transaction_id,

                   parent_interface_txn_id =

                      G_Rec_Trx_Table (line_rec).parent_interface_txn_id,

                   to_organization_id =

                      G_Rec_Trx_Table (line_rec).to_organization_id,

                   validation_flag =

                      G_Rec_Trx_Table (line_rec).validation_flag,

                   po_header_id = G_Rec_Trx_Table (line_rec).po_header_id,

                   po_line_id = G_Rec_Trx_Table (line_rec).po_line_id,

                   po_release_id = G_Rec_Trx_Table (line_rec).po_release_id,

                   po_revision_num =

                      G_Rec_Trx_Table (line_rec).po_revision_num,

                   po_line_location_id =

                      G_Rec_Trx_Table (line_rec).po_line_location_id,

                   location_id = G_Rec_Trx_Table (line_rec).location_id,

                   org_id = G_Rec_Trx_Table (line_rec).org_id,

                   document_num = G_Rec_Trx_Table (line_rec).document_num,

                   document_line_num =

                      G_Rec_Trx_Table (line_rec).document_line_num,

                   subinventory = G_Rec_Trx_Table (line_rec).subinventory,

                   stage_process_flag =

                      G_Rec_Trx_Table (line_rec).stage_process_flag,

                   stage_error_type =

                      G_Rec_Trx_Table (line_rec).stage_error_type,

                   stage_last_update_date =

                      G_Rec_Trx_Table (line_rec).stage_last_update_date,

                   stage_last_updated_by =

                      G_Rec_Trx_Table (line_rec).stage_last_updated_by,

                   stage_last_update_login =

                      G_Rec_Trx_Table (line_rec).stage_last_update_login,

                   stage_request_id =

                      G_Rec_Trx_Table (line_rec).stage_request_id,

                   stage_group_id = G_Rec_Trx_Table (line_rec).stage_group_id,

                   --//24-FEB-2014 NBTY Procurement Implementation

                   -- ship to location code will be derived from po shipment Lines

                   attribute4 = G_Rec_Trx_Table (line_rec).attribute4

             -- // 24-FEB-2014

             WHERE     stage_event_id =

                          G_Rec_Trx_Table (line_rec).stage_event_id

                   AND stage_record_id =

                          G_Rec_Trx_Table (line_rec).stage_record_id;

         END LOOP;

      END IF;



      COMMIT;

      log_put_line ('Procedure ' || l_proc_name || '. End.');

   EXCEPTION

      WHEN OTHERS

      THEN

         l_log_msg :=

               'Unexpected Error in Procedure '

            || l_proc_name

            || '. Err='

            || TO_CHAR (SQLCODE)

            || ' '

            || SQLERRM;

         log_put_line (l_log_msg);

         insert_error (g_event_id,

                       'ERROR',

                       l_proc_name,

                       l_log_msg);

   END upd_trx_staging;



   ----------------------------------------------------------------------

   /*



    Pocedure Name: upd_status_staging

    Author? name: Amit Kumar (NBTY ERP Implementation)

    Date written: 09-Nov-12

    RICEFW Object id: NBTY-PRC-I-013

    Description: To update header and trans as error if one or more trans has error

    Program Style: Subordinate



    Maintenance History:



    Date Issue# Name Remarks

    ----------- -------- ---------------- ------------------------------------------

    09-Nov-12 Amit Kumar Initial development.



   */

   ----------------------------------------------------------------------



   PROCEDURE upd_status_staging

   IS

      l_proc_name   VARCHAR2 (100)

                       := 'XXNBTY_PO_RCV_IBI_FEEDER_PK.upd_status_staging';

      l_h_cnt       NUMBER := 1;

      l_t_cnt       NUMBER := 1;

      l_log_msg     VARCHAR2 (2000);



      CURSOR lc_upd_sts

      IS

           SELECT stage_event_id, COUNT (stage_process_flag)

             FROM (  SELECT stage_event_id, stage_process_flag

                       FROM bolinf.xxnbty_rcv_transactions_stg xrts

                      WHERE     xrts.stage_process_flag = g_sts_vlderr_constant

                            AND xrts.stage_request_id = g_request_id

                   GROUP BY stage_event_id, stage_process_flag)

         GROUP BY stage_event_id

           HAVING COUNT (stage_process_flag) >= 1;



   BEGIN

      log_put_line ('Procedure ' || l_proc_name || '. Begin');

      l_h_cnt := g_hdr_cnt;



      IF l_h_cnt = 1

      THEN

         l_h_cnt := 0;

      ELSE

         l_h_cnt := l_h_cnt - 1;

      END IF;



      l_t_cnt := g_trx_cnt;



      IF l_t_cnt = 1

      THEN

         l_t_cnt := 0;

      ELSE

         l_t_cnt := l_t_cnt - 1;

      END IF;



      FOR lr_upd_sts IN lc_upd_sts

      LOOP

         UPDATE bolinf.xxnbty_rcv_headers_stg

            SET stage_process_flag = g_sts_err_constant,

                stage_error_type = 'VALIDATION',

                stage_process_attempts = NVL (stage_process_attempts, 0) + 1

          WHERE stage_event_id = lr_upd_sts.stage_event_id;



         --update Line Staus

         UPDATE xxnbty_rcv_transactions_stg

            SET stage_process_flag = g_sts_err_constant,

                stage_error_type = 'VALIDATION'

          WHERE     stage_event_id = lr_upd_sts.stage_event_id

                AND stage_process_flag IN

                       (g_sts_vld_constant, g_sts_vldErr_constant);



         -- Update Event table status

         UPDATE xxnbty_ibi_events

            SET event_status = g_sts_err_constant,

                request_id_feeder_program = g_request_id,

                last_updated_by = g_user_id,

                last_update_date = SYSDATE

          WHERE event_id = lr_upd_sts.stage_event_id;



         apps.fnd_message.set_name ('XBIL', 'NBTY_RCV_HEADER_LEVEL_MSG');

         l_log_msg := apps.fnd_message.get;

         apps.fnd_msg_pub.delete_msg;



         -- update HDR status in pl/sql table

         IF l_h_cnt >= 1

         THEN

            FOR UPD_HDR_REC IN G_REC_HDR_Table.FIRST .. G_REC_HDR_Table.LAST

            LOOP

               IF     G_REC_HDR_Table (UPD_HDR_REC).stage_event_id =

                         lr_upd_sts.stage_event_id

                  AND G_REC_HDR_Table (UPD_HDR_REC).stage_process_flag =

                         g_sts_vld_constant

               THEN

                  insert_hdr_error (

                     p_proc_name   => l_proc_name,

                     p_log_msg     => l_log_msg,

                     p_event_id    => G_REC_HDR_Table (UPD_HDR_REC).stage_event_id,

                     p_record_id   => G_REC_HDR_Table (UPD_HDR_REC).stage_record_id);

                  G_REC_HDR_Table (UPD_HDR_REC).stage_process_flag :=

                     g_sts_err_constant;

                  G_REC_HDR_Table (UPD_HDR_REC).status := 'ERROR';

                  G_REC_HDR_Table (UPD_HDR_REC).stage_error_type :=

                     'VALIDATION';

                  G_REC_HDR_Table (UPD_HDR_REC).Msg := l_log_msg;

               END IF;

            END LOOP;

         END IF;



         apps.fnd_message.set_name ('XBIL', 'NBTY_RCV_TRANS_LEVEL_MSG');

         l_log_msg := apps.fnd_message.get;

         apps.fnd_msg_pub.delete_msg;



         -- update Trans status in pl/sql table

         IF l_t_cnt >= 1

         THEN

            FOR upd_line_rec IN G_Rec_Trx_Table.FIRST .. G_Rec_Trx_Table.LAST

            LOOP

               IF     G_Rec_Trx_Table (upd_line_rec).stage_event_id =

                         lr_upd_sts.stage_event_id

                  AND G_Rec_Trx_Table (upd_line_rec).stage_process_flag =

                         g_sts_vld_constant

               THEN

                  insert_trx_error (

                     p_proc_name   => l_proc_name,

                     p_log_msg     => l_log_msg,

                     p_event_id    => G_Rec_Trx_Table (upd_line_rec).stage_event_id,

                     p_record_id   => G_Rec_Trx_Table (upd_line_rec).stage_record_id);

                  G_Rec_Trx_Table (upd_line_rec).stage_process_flag :=

                     g_sts_err_constant;

                  G_Rec_Trx_Table (upd_line_rec).status := 'ERROR';

                  G_Rec_Trx_Table (upd_line_rec).stage_error_type :=

                     'VALIDATION';

                  G_Rec_Trx_Table (upd_line_rec).Msg := l_log_msg;

               END IF;

            END LOOP;

         END IF;



         g_retcode_err := retcde_failure_constant;

      END LOOP;



      COMMIT;

      log_put_line ('Procedure ' || l_proc_name || '. End.');

   EXCEPTION

      WHEN OTHERS

      THEN

         l_log_msg :=

               'Unexpected Error in Procedure '

            || l_proc_name

            || '. Err='

            || TO_CHAR (SQLCODE)

            || ' '

            || SQLERRM;

         log_put_line (l_log_msg);

         insert_error (g_event_id,

                       'ERROR',

                       l_proc_name,

                       l_log_msg);

   END upd_status_staging;

   ----------------------------------------------------------------------
   /*
    Pocedure Name: validate_rcv_trx_unit_cost
    Author name: Khristine Austero
    Date written: 05-Mar-16
    RICEFW Object id: NBTY-PRC-I-013
    Description: Receiving Transaction Error Trapping: checks if unit cost has value or none
    Program Style: Subordinate

    Maintenance History:
    Date Issue# Name Remarks
    ----------- -------- ---------------- ------------------------------------------
    05-Mar-16 Khristine Austero Receiving Transaction Error Trapping
   */
   ----------------------------------------------------------------------
/*   
   PROCEDURE validate_rcv_trx_unit_cost (p_group_id     IN     NUMBER,
                                    p_error_flag   IN OUT VARCHAR2,
                                    p_error_msg    IN OUT VARCHAR2)

   IS

      --Local Variables
      l_proc_name                   VARCHAR (100)
                                       := 'XXNBTY_PO_RCV_IBI_FEEDER_PK.validate_rcv_trx_unit_cost';
      l_error_flag                  VARCHAR2 (10);
      l_error_msg                   VARCHAR2 (2000);
      l_log_msg                     VARCHAR2 (500);
      l_unit_cost                   NUMBER := 0; --Changed to number AFLORES 9/28/2016

      -- //

      CURSOR ReceTrxNum_C
      IS
         SELECT xrts.*, xrhs.stage_process_flag hdr_status
           FROM xxnbty_rcv_headers_stg xrhs, xxnbty_rcv_transactions_stg xrts
          WHERE     xrhs.stage_event_id = xrts.stage_event_id
                AND xrhs.stage_request_id = g_request_id
                AND xrhs.stage_group_id = p_group_id
                AND xrhs.stage_process_flag IN
                       (g_sts_vld_constant, g_sts_vldErr_constant)
                AND xrts.stage_process_flag NOT IN ('G', 'I');


   BEGIN
      log_put_line ('Procedure ' || l_proc_name || '. Begin');

      FOR ReceTrxNum_REC IN ReceTrxNum_C
      LOOP
         l_error_flag := APPS.fnd_api.g_false;
         l_error_msg := NULL;
		 l_unit_cost := 0; --added to initialize the variables AFLORES 9/28/2016
  --[START] Error Trapping
	IF ReceTrxNum_REC.item_num IS NOT NULL AND ReceTrxNum_REC.to_organization_id IS NOT NULL  THEN
			BEGIN
			
				l_unit_cost := 0;
				
				SELECT NVL((CASE WHEN mp.PROCESS_ENABLED_FLAG = 'N' THEN (SELECT SUM(item_cost)
																	FROM ( SELECT DISTINCT cicd.cost_element
																				  ,cicd.Resource_code
																				  ,cicd.usage_rate_or_amount
																				  ,cicd.item_cost
																				  ,msi_disc.segment1
																				  ,mp_disc.organization_code
																				  ,cict.cost_type
																				  ,msi_disc.inventory_item_id
																				  ,mp_disc.organization_id
																		   FROM apps.cst_item_cost_details_v cicd,
																		   mtl_system_items msi_disc,
																		   mtl_parameters mp_disc,
																		   apps.CST_ITEM_COST_TYPE_V cict
																		   WHERE cicd.inventory_item_id   =   msi_disc.inventory_item_id
																		   AND   cicd.organization_id     =   msi_disc.organization_id
																		   AND   cicd.organization_id     =   mp_disc.organization_id
																		   AND   cicd.inventory_item_id   =   cict.inventory_item_id
																		   AND   cicd.organization_id     =   cict.organization_id
																		   --Modified for discreet org cost validation AFLORES 11/3/2016
																		   and   UPPER(cict.cost_type)    = 'FROZEN' 
																		   AND   cicd.cost_type_id		 =	 cict.cost_type_id
																		   ) disc_cost
																		   WHERE disc_cost.inventory_item_id = msi.inventory_item_id
																		   AND   disc_cost.organization_id   = msi.organization_id
																		   AND   disc_cost.organization_id   = mp.organization_id
																	 )
						WHEN mp.PROCESS_ENABLED_FLAG = 'Y' THEN (SELECT SUM(cmpnt_cost)
																	FROM (SELECT DISTINCT mp_proc.organization_id
																						 ,msi_proc.segment1
																						 ,ccd.inventory_item_id
																						 ,ccd.cmpnt_cost
																						 ,ccm.cost_cmpntcls_code
																						 ,ccd.period_id
																		  FROM
																		  apps.CM_CMPT_DTL  ccd,
																		  apps.CM_CMPT_MST ccm ,
																		  mtl_system_items msi_proc,
																		  mtl_parameters mp_proc
																		  WHERE ccd.inventory_item_id   = msi_proc.inventory_item_id
																		  AND ccd.organization_id       = msi_proc.organization_id
																		  AND ccd.cost_cmpntcls_id      = ccm.cost_cmpntcls_id
																		  AND ccd.organization_id       = mp_proc.organization_id
																		  AND ccd.organization_id       = msi_proc.organization_id
																		  ) proc_cost
																	WHERE proc_cost.period_id = gps.period_id
																	AND   ReceTrxNum_REC.transaction_date >= gps.START_DATE
																	AND   ReceTrxNum_REC.transaction_date <  TO_DATE(TO_CHAR(gps.end_date,'DD-MON-YY')||' 11:59:59PM','DD-MON-YY HH:MI:SSAM')
																	AND   proc_cost.inventory_item_id = msi.inventory_item_id
																	AND   proc_cost.organization_id   = msi.organization_id
																	AND   proc_cost.organization_id   = mp.organization_id
						   )
						   END ), 0 ) AS UNIT_COST --made it NVL of zero AFLORES 9/21/2016
				INTO l_unit_cost
				FROM  mtl_parameters mp
				  , gmf_period_statuses gps
				  , mtl_system_items msi
				WHERE
					 (ReceTrxNum_REC.transaction_date >= gps.start_date )
				AND    (ReceTrxNum_REC.transaction_date < TO_DATE(TO_CHAR(gps.end_date,'DD-MON-YY')||' 11:59:59PM','DD-MON-YY HH:MI:SSAM')  )
				AND   mp.organization_id            = msi.organization_id
				AND   msi.segment1                  = ReceTrxNum_REC.item_num
				AND   msi.organization_id           = ReceTrxNum_REC.TO_ORGANIZATION_ID;

			EXCEPTION
			WHEN NO_DATA_FOUND THEN
			   l_unit_cost   := 0;--made it zero AFLORES 9/21/2016
			END;
	ELSE
			l_log_msg :=
					 'Either Item Number or Organization ID is NULL. Kindly Validate the Data in the Staging Table';
		    insert_trx_error (
			  p_proc_name   => l_proc_name,
			  p_log_msg     => l_log_msg,
			  p_event_id    => ReceTrxNum_REC.stage_event_id,
			  p_record_id   => ReceTrxNum_REC.stage_record_id);

		    log_put_line (l_log_msg);
		    l_error_flag := APPS.fnd_api.g_true;
		    l_error_msg  := l_error_msg || ' ' || l_log_msg;
	 END IF;


--[START] Check if the Unit Cost is zero then Error this record out

      IF l_unit_cost = 0 OR l_unit_cost IS NULL THEN
         l_log_msg :=
                 'No Unit Cost has been found for this Item Number '
                 || ReceTrxNum_REC.item_num
                 || ' OrgID '
                 || ReceTrxNum_REC.to_organization_id;

       insert_trx_error (
          p_proc_name   => l_proc_name,
          p_log_msg     => l_log_msg,
          p_event_id    => ReceTrxNum_REC.stage_event_id,
          p_record_id   => ReceTrxNum_REC.stage_record_id);

       log_put_line (l_log_msg);
       l_error_flag := APPS.fnd_api.g_true;
       l_error_msg  := l_error_msg || ' ' || l_log_msg;

     END IF;
   END LOOP;
   log_put_line ('Procedure ' || l_proc_name || '. End.');
   	EXCEPTION
      WHEN OTHERS
      THEN
         l_log_msg :=
               'Unexpected Error in Procedure '
            || l_proc_name
            || '. Err='
            || TO_CHAR (SQLCODE)
            || ' '
            || SQLERRM;

         log_put_line (l_log_msg);
         insert_error (g_event_id,
                       'ERROR',
                       l_proc_name,
                       l_log_msg);

         p_error_msg :=
            p_error_msg || ' Unexpected Error in Procedure' || SQLERRM;
         p_error_flag := APPS.fnd_api.g_true;

	--END validate_rcv_trx_unit_cost;
--
--[END] Check if the Unit Cost is zero then Error this record out
*/
   ----------------------------------------------------------------------
   /*

    Pocedure Name: validate_rcv_hdr_data
    Author? name: Amit Kumar (NBTY ERP Implementation)
    Date written: 09-Nov-12
    RICEFW Object id: NBTY-PRC-I-013
    Description: Validate data for Header level
    Program Style: Subordinate

    Maintenance History:

    Date Issue# Name Remarks
    ----------- -------- ---------------- ------------------------------------------
    09-Nov-12 Amit Kumar Initial development.
   */
   ----------------------------------------------------------------------


   PROCEDURE validate_rcv_hdr_data (p_group_id     IN     NUMBER,
                                    p_proc_type    IN     VARCHAR2,
                                    p_event_id     IN     NUMBER,
                                    p_re_attempt   IN     NUMBER,
                                    p_error_flag   IN OUT VARCHAR,
                                    p_error_msg    IN OUT VARCHAR2)
   IS

      --Local Variables

      l_proc_name             VARCHAR2 (100)

                                 := 'XXNBTY_PO_RCV_IBI_FEEDER_PK.validate_rcv_hdr_data';

      l_error_flag            VARCHAR2 (10);

      l_error_msg             VARCHAR2 (2000);

      l_log_msg               VARCHAR2 (2000);

      l_vendor_id             ap_suppliers.vendor_id%TYPE;

      l_vendor_num            ap_suppliers.segment1%TYPE;

      l_vendor_name           ap_suppliers.vendor_name%TYPE;

      l_vendor_site_id        ap_supplier_sites_all.vendor_site_id%TYPE;

      l_vendor_site_code      ap_supplier_sites_all.vendor_site_code%TYPE;

      l_ship_to_location_id   ap_supplier_sites_all.ship_to_location_id%TYPE;



      CURSOR ReceHDR_CUR

      IS

         --New records

         SELECT xrhs.*

           FROM xxnbty_rcv_headers_stg xrhs, xxnbty_ibi_events xie

          WHERE     xrhs.stage_event_id = xie.event_id

                AND XIE.event_status = xrhs.stage_process_flag

                AND XIE.event_status = g_sts_new_constant

                AND p_proc_type = g_sts_new_constant

         UNION

         --New and Error records in case of reprocessing

         SELECT xrhs.*

           FROM xxnbty_rcv_headers_stg xrhs, xxnbty_ibi_events xie

          WHERE     xrhs.stage_event_id = xie.event_id

                AND XIE.event_status = xrhs.stage_process_flag

                AND xrhs.stage_process_flag IN

                       (g_sts_new_constant, g_sts_err_constant)

                AND xie.event_status IN

                       (g_sts_new_constant, g_sts_err_constant)

                AND p_proc_type = 'B'

                AND p_event_id IS NULL

                AND NVL (xrhs.stage_process_attempts, 0) <

                       NVL (p_re_attempt, 5)

         UNION

         --Event specific records in case of reprocessing an event

         SELECT xrhs.*

           FROM xxnbty_rcv_headers_stg xrhs, xxnbty_ibi_events xie

          WHERE     xrhs.stage_event_id = xie.event_id

                AND xie.event_status IN

                       (g_sts_new_constant, g_sts_err_constant)

                AND p_proc_type = 'B'

                AND xie.event_id = p_event_id

                AND NVL (xrhs.stage_process_attempts, 0) <

                       NVL (p_re_attempt, 5);



   BEGIN

      log_put_line ('Procedure ' || l_proc_name || '. Begin');



      G_REC_HDR_Table.DELETE;

      g_hdr_cnt := 1;

      log_put_line ('p_proc_type ' || p_proc_type);



      FOR ReceHDR_Rec IN ReceHDR_CUR

      LOOP

         l_error_flag := APPS.fnd_api.g_false;

         l_error_msg := NULL;

         log_put_line (

               'Starting Validations for Receipt for event id and Receipt Num '

            || ReceHDR_Rec.stage_event_id

            || ' '

            || ReceHDR_Rec.receipt_num);



         IF ReceHDR_Rec.stage_record_id IS NULL

         THEN

            l_log_msg := 'stage_record_id is NULL ';



            insert_hdr_error (p_proc_name   => l_proc_name,

                              p_log_msg     => l_log_msg,

                              p_event_id    => ReceHDR_Rec.stage_event_id,

                              p_record_id   => ReceHDR_Rec.stage_record_id);



            log_put_line (l_log_msg);

            l_error_flag := APPS.fnd_api.g_true;

            l_error_msg := l_error_msg || ' ' || l_log_msg;

         ELSE

            G_REC_HDR_Table (g_hdr_cnt).stage_record_id :=

               ReceHDR_Rec.stage_record_id;

         END IF;



         G_REC_HDR_Table (g_hdr_cnt).stage_event_id :=

            ReceHDR_Rec.stage_event_id;

         G_REC_HDR_Table (g_hdr_cnt).stage_process_attempts :=

            NVL (ReceHDR_Rec.stage_process_attempts, 0);

         G_REC_HDR_Table (g_hdr_cnt).processing_status_code := 'PENDING';

         G_REC_HDR_Table (g_hdr_cnt).receipt_source_code := 'VENDOR';

         G_REC_HDR_Table (g_hdr_cnt).transaction_type := 'NEW';

         G_REC_HDR_Table (g_hdr_cnt).validation_flag := 'Y';



         IF ReceHDR_Rec.expected_receipt_date IS NULL

         THEN

            apps.fnd_message.set_name ('XBIL', 'NBTY_RCV_EXPED_RECE_DT_NULL');

            l_log_msg := apps.fnd_message.get;

            apps.fnd_msg_pub.delete_msg;



            insert_hdr_error (p_proc_name   => l_proc_name,

                              p_log_msg     => l_log_msg,

                              p_event_id    => ReceHDR_Rec.stage_event_id,

                              p_record_id   => ReceHDR_Rec.stage_record_id);



            l_error_flag := APPS.fnd_api.g_true;

            l_error_msg := l_error_msg || ' ' || l_log_msg;

         ELSE

            G_REC_HDR_Table (g_hdr_cnt).expected_receipt_date :=

               TO_DATE (ReceHDR_Rec.expected_receipt_date, 'DD-MON-RRRR');

            --// Added for change requirement as on 31-Jan-2013

            G_REC_HDR_Table (g_hdr_cnt).shipped_date :=

               G_REC_HDR_Table (g_hdr_cnt).expected_receipt_date - 1;

         END IF;



         IF TO_DATE (ReceHDR_Rec.expected_receipt_date, 'DD-MON-RRRR') <

               G_REC_HDR_Table (g_hdr_cnt).shipped_date

         THEN

            apps.fnd_message.set_name ('PO', 'RCV_DELIV_DATE_INVALID');

            apps.fnd_message.set_token ('DELIVERY DATE',

                                        ReceHDR_Rec.expected_receipt_date);

            l_log_msg := apps.fnd_message.get;

            apps.fnd_msg_pub.delete_msg;



            insert_hdr_error (p_proc_name   => l_proc_name,

                              p_log_msg     => l_log_msg,

                              p_event_id    => ReceHDR_Rec.stage_event_id,

                              p_record_id   => ReceHDR_Rec.stage_record_id);



            log_put_line (l_log_msg);

            l_error_flag := APPS.fnd_api.g_true;

            l_error_msg := l_error_msg || ' ' || l_log_msg;

         END IF;



         IF ReceHDR_Rec.creation_date IS NULL

         THEN

            apps.fnd_message.set_name ('XBIL', 'NBTY_RCV_CREA_DT_NULL');

            l_log_msg := apps.fnd_message.get;

            apps.fnd_msg_pub.delete_msg;



            insert_hdr_error (p_proc_name   => l_proc_name,

                              p_log_msg     => l_log_msg,

                              p_event_id    => ReceHDR_Rec.stage_event_id,

                              p_record_id   => ReceHDR_Rec.stage_record_id);



            l_error_flag := APPS.fnd_api.g_true;

            l_error_msg := l_error_msg || ' ' || l_log_msg;

         ELSE

            G_REC_HDR_Table (g_hdr_cnt).creation_date :=

               TO_DATE (ReceHDR_Rec.creation_date, 'DD-MON-RRRR');

         END IF;



         G_REC_HDR_Table (g_hdr_cnt).employee_name :=

            ReceHDR_Rec.employee_name;

         G_REC_HDR_Table (g_hdr_cnt).receipt_num := ReceHDR_Rec.receipt_num;

         G_REC_HDR_Table (g_hdr_cnt).shipment_num := ReceHDR_Rec.shipment_num;

         G_REC_HDR_Table (g_hdr_cnt).currency_code :=

            ReceHDR_Rec.currency_code;



         G_REC_HDR_Table (g_hdr_cnt).stage_group_id := p_group_id;



         G_REC_HDR_Table (g_hdr_cnt).stage_last_update_date := SYSDATE;

         G_REC_HDR_Table (g_hdr_cnt).stage_last_updated_by := g_user_id;

         G_REC_HDR_Table (g_hdr_cnt).stage_request_id := g_request_id;

         G_REC_HDR_Table (g_hdr_cnt).stage_creation_date :=

            ReceHDR_Rec.stage_creation_date;

         G_REC_HDR_Table (g_hdr_cnt).stage_created_by :=

            ReceHDR_Rec.stage_created_by;

         G_REC_HDR_Table (g_hdr_cnt).stage_last_update_login := g_login_id;



         --Get supplier details

         get_vendor_dtl (p_le_vendor_num   => ReceHDR_Rec.legacy_vendor_num,

                         p_event_id        => ReceHDR_Rec.stage_event_id,

                         p_record_id       => ReceHDR_Rec.stage_record_id,

                         x_vendor_id       => l_vendor_id,

                         x_vendor_num      => l_vendor_num,

                         x_vendor_name     => l_vendor_name,

                         x_error_flag      => l_error_flag,

                         x_error_msg       => l_error_msg);



         log_put_line ('get vendor num ' || l_vendor_id);



         IF l_vendor_id IS NOT NULL

         THEN

            G_REC_HDR_Table (g_hdr_cnt).vendor_id := l_vendor_id;

            G_REC_HDR_Table (g_hdr_cnt).vendor_num := l_vendor_num;

            G_REC_HDR_Table (g_hdr_cnt).vendor_name := l_vendor_name;

         END IF;



         --Get supplier site details

         get_supplier_site (p_le_site_code          => ReceHDR_Rec.legacy_site_code,

                            p_event_id              => ReceHDR_Rec.stage_event_id,

                            p_record_id             => ReceHDR_Rec.stage_record_id,

                            x_vendor_site_id        => l_vendor_site_id,

                            x_vendor_site_code      => l_vendor_site_code,

                            x_ship_to_location_id   => l_ship_to_location_id,

                            x_error_flag            => l_error_flag,

                            x_error_msg             => l_error_msg);



         log_put_line ('get vendor Site Dtl ' || l_vendor_id);



         IF l_vendor_site_id IS NOT NULL

         THEN

            G_REC_HDR_Table (g_hdr_cnt).vendor_site_id := l_vendor_site_id;

            G_REC_HDR_Table (g_hdr_cnt).vendor_site_code := l_vendor_site_code;

         END IF;



         /* IF ReceHDR_Rec.ship_to_location_code IS NULL

          THEN

            G_REC_HDR_Table(g_hdr_cnt).ship_to_location_id := l_ship_to_location_id;

          ELSE

            l_ship_to_location_id := NULL;

            G_REC_HDR_Table(g_hdr_cnt).ship_to_location_code := ReceHDR_Rec.ship_to_location_code;

            XXNBTY_INT_UTIL_PKG.validate_ship_to_location(

                                                p_ship_to => ReceHDR_Rec.ship_to_location_code

                                              , x_location_id => l_ship_to_location_id

                                              , x_errbuf => l_error_msg

                                              );

           IF l_ship_to_location_id IS NULL

            THEN

              l_log_msg := 'Invalid Ship To Location code : '

                             ||ReceHDR_Rec.ship_to_location_code;



              insert_hdr_error (p_proc_name => l_proc_name

                              , p_log_msg => l_log_msg

                              , p_event_id => ReceHDR_Rec.stage_event_id

                              , p_record_id => ReceHDR_Rec.stage_record_id);



              l_error_flag := APPS.fnd_api.g_true;

              l_error_msg := l_error_msg

                               || ' '

                               ||l_log_msg ;

            ELSE

            G_REC_HDR_Table(g_hdr_cnt).ship_to_location_id := l_ship_to_location_id;

            END IF;

          END IF;*/



         G_REC_HDR_Table (g_hdr_cnt).currency_code :=

            ReceHDR_Rec.currency_code;



         XXNBTY_INT_UTIL_PKG.validate_currency (

            x_currency_code   => G_REC_HDR_Table (g_hdr_cnt).currency_code,

            x_errbuf          => l_log_msg);



         IF G_REC_HDR_Table (g_hdr_cnt).currency_code IS NULL

         THEN

            apps.fnd_message.set_name ('XBIL', 'NBTY_RCV_CURR_NOT_DEF');

            apps.fnd_message.set_token ('CURR_CODE',

                                        ReceHDR_Rec.currency_code);

            l_log_msg := apps.fnd_message.get || ' ' || SUBSTR (SQLERRM, 250);

            apps.fnd_msg_pub.delete_msg;



            insert_hdr_error (p_proc_name   => l_proc_name,

                              p_log_msg     => l_log_msg,

                              p_event_id    => ReceHDR_Rec.stage_event_id,

                              p_record_id   => ReceHDR_Rec.stage_record_id);



            log_put_line (l_log_msg);

            l_error_flag := APPS.fnd_api.g_true;

            l_error_msg := l_error_msg || ' ' || l_log_msg;

         END IF;





         G_REC_HDR_Table (g_hdr_cnt).msg := l_error_msg;



         -- Update Flag in Custom Interface table

         IF l_error_flag = APPS.fnd_api.g_false

         THEN

            G_REC_HDR_Table (g_hdr_cnt).stage_process_flag :=

               g_sts_vld_constant;

            G_REC_HDR_Table (g_hdr_cnt).status := 'SUCCESS';

         ELSE

            G_REC_HDR_Table (g_hdr_cnt).status := 'ERROR';

            G_REC_HDR_Table (g_hdr_cnt).stage_process_flag :=

               g_sts_vlderr_constant;

            G_REC_HDR_Table (g_hdr_cnt).stage_error_type := 'VALIDATION';

         END IF;



         g_hdr_cnt := g_hdr_cnt + 1;

      END LOOP;



      log_put_line ('Procedure ' || l_proc_name || '. End.');

   EXCEPTION

      WHEN OTHERS

      THEN

         l_log_msg :=

               'Unexpected Error in Procedure '

            || l_proc_name

            || '. Err='

            || TO_CHAR (SQLCODE)

            || ' '

            || SQLERRM;

         log_put_line (l_log_msg);

         insert_error (g_event_id,

                       'ERROR',

                       l_proc_name,

                       l_log_msg);

         p_error_msg :=

            p_error_msg || ' Unexpected Error in Procedure' || SQLERRM;

         p_error_flag := APPS.fnd_api.g_true;

   END validate_rcv_hdr_data;


   ----------------------------------------------------------------------
   /*

    Pocedure Name: validate_rcv_trx_data
    Author? name: Amit Kumar (NBTY ERP Implementation)
    Date written: 09-Nov-12
    RICEFW Object id: NBTY-PRC-I-013
    Description: Validate date for transaction level
    Program Style: Subordinate

    Maintenance History:

    Date Issue# Name Remarks
    ----------- -------- ---------------- ------------------------------------------

    09-Nov-12 Amit Kumar Initial development.
    08-Mar-16 Kenneth Palomera Derive the SubInventory value based on the ICC's
	28-Sep-16 Albert Flores	Added the unit cost validation

   */

   ----------------------------------------------------------------------



   PROCEDURE validate_rcv_trx_data (p_group_id     IN     NUMBER,
                                    p_error_flag   IN OUT VARCHAR2,
                                    p_error_msg    IN OUT VARCHAR2)

   IS

      --Local Variables
      l_proc_name                   VARCHAR (100)
                                       := 'XXNBTY_PO_RCV_IBI_FEEDER_PK.validate_rcv_trx_data';
      l_error_flag                  VARCHAR2 (10);
      l_error_msg                   VARCHAR2 (2000);
      l_log_msg                     VARCHAR2 (500);
      l_item_id                     mtl_system_items_b.inventory_item_id%TYPE;
      l_item_num                    mtl_system_items_b.segment1%TYPE;
      l_line_location_id            po_line_locations_all.line_location_id%TYPE;
      l_ship_to_org_id              po_line_locations_all.ship_to_organization_id%TYPE;
      l_ship_to_location_id         po_line_locations_all.ship_to_location_id%TYPE;
      l_po_header_id                po_headers_all.po_header_id%TYPE;
      l_po_line_id                  po_lines_all.po_line_id%TYPE;
      l_remaining_qty               NUMBER;
      l_category_id                 po_lines_all.category_id%TYPE;
      l_trans_chk                   VARCHAR2 (1);
      -- // added 31-Dec-2013  Shyam B NBTY Procurement Implementation
      l_release_id                  NUMBER;
      lc_ship_location_code         hr_locations.location_code%TYPE;
      lc_DESTINATION_SUBINVENTORY   po_distributions_all.DESTINATION_SUBINVENTORY%TYPE;
      lv_subinventory 				VARCHAR2(100); --added variable 03/08/2016 Ken
	  l_unit_cost                   NUMBER := 0; --Changed to number AFLORES 9/28/2016
	  l_inventory_item_flag			VARCHAR2(10);--Added variable for inventory flag AFLORES 10/12/2016
      -- //

      CURSOR ReceLine_C

      IS

         SELECT xrts.*, xrhs.stage_process_flag hdr_status
           FROM xxnbty_rcv_headers_stg xrhs, xxnbty_rcv_transactions_stg xrts
          WHERE     xrhs.stage_event_id = xrts.stage_event_id
                AND xrhs.stage_request_id = g_request_id
                AND xrhs.stage_group_id = p_group_id
                AND xrhs.stage_process_flag IN
                       (g_sts_vld_constant, g_sts_vldErr_constant)
                --AND xrts.stage_process_flag != 'G';   --PRJ10456 --Commented as part of INC828264
                AND xrts.stage_process_flag NOT IN ('G', 'I'); -- Part of INC828264


   BEGIN
      log_put_line ('Procedure ' || l_proc_name || '. Begin');
      G_Rec_Trx_Table.DELETE;
      g_trx_cnt := 1;

      FOR ReceLine_REC IN ReceLine_C
      LOOP
         l_error_flag := APPS.fnd_api.g_false;
         l_error_msg := NULL;
/*
	--start of changes 03/08/2016 Ken

		 BEGIN
		 lv_subinventory :=NULL;

			SELECT flv2.description
			INTO lv_subinventory
			FROM   fnd_lookup_values flv2
			WHERE  flv2.lookup_type = 'XXNBTY_SUBINVCODE_LOOKUP'
			AND UPPER(flv2.lookup_code) = (SELECT UPPER(ecg.catalog_group)
										   FROM mtl_system_items 	  msi
										      , apps.ego_catalog_groups_v  ecg
										   WHERE ecg.catalog_group_id	= msi.item_catalog_group_id
										   AND   msi.organization_id	= receline_rec.to_organization_id --receline_rec.org_id
										   AND   msi.segment1			= receline_rec.item_num)
			AND UPPER(flv2.meaning)  = (SELECT UPPER(ecg.catalog_group)
										FROM mtl_system_items msi
										   , apps.ego_catalog_groups_v ecg
										WHERE ecg.catalog_group_id  = msi.item_catalog_group_id
										AND   msi.organization_id	= receline_rec.to_organization_id --receline_rec.org_id
										AND   msi.segment1          = receline_rec.item_num);
				EXCEPTION

					WHEN NO_DATA_FOUND THEN
									      lv_subinventory :=NULL;

		 END;

	--end of changes 03/08/2016 Ken
*/

		
         log_put_line (

               'Starting Validations for Receipt for Event id, document_num and document_line_num '

            || ReceLine_REC.stage_event_id

            || ' '

            || ReceLine_REC.document_num

            || ' '

            || ReceLine_REC.document_line_num);

         log_put_line ('stage_record_id ' || ReceLine_REC.stage_record_id);



         IF ReceLine_REC.stage_record_id IS NULL

         THEN

            l_log_msg := 'Record Id is NULL ';



            insert_trx_error (p_proc_name   => l_proc_name,

                              p_log_msg     => l_log_msg,

                              p_event_id    => ReceLine_REC.stage_event_id,

                              p_record_id   => ReceLine_REC.stage_record_id);



            log_put_line (l_log_msg);

            l_error_flag := APPS.fnd_api.g_true;

            l_error_msg := l_error_msg || ' ' || l_log_msg;

         ELSE

            G_Rec_Trx_Table (g_trx_cnt).stage_record_id :=

               ReceLine_REC.stage_record_id;

         END IF;



         IF ReceLine_REC.transaction_type IS NULL

         THEN

            l_log_msg := 'Transaction Type is NULL ';



            insert_trx_error (p_proc_name   => l_proc_name,

                              p_log_msg     => l_log_msg,

                              p_event_id    => ReceLine_REC.stage_event_id,

                              p_record_id   => ReceLine_REC.stage_record_id);



            log_put_line (l_log_msg);

            l_error_flag := APPS.fnd_api.g_true;

            l_error_msg := l_error_msg || ' ' || l_log_msg;

         ELSE

            G_Rec_Trx_Table (g_trx_cnt).transaction_type :=

               ReceLine_REC.transaction_type;

         END IF;



         check_trans_dt (p_trans_dt     => to_date(ReceLine_REC.transaction_date,'DD-MON-RRRR')--Julian--TO_DATE (SYSDATE, 'DD-MON-RRRR') --to_date(ReceLine_REC.transaction_date,'DD-MON-RRRR') -- Post-Live Changes by Jairaj

                                                                           ,

                         p_event_id     => ReceLine_REC.stage_event_id,

                         p_record_id    => ReceLine_REC.stage_record_id,

                         x_chk          => l_trans_chk,

                         x_error_flag   => l_error_flag,

                         x_error_msg    => l_error_msg);



         G_Rec_Trx_Table (g_trx_cnt).transaction_date :=

            TO_DATE (ReceLine_REC.transaction_date, 'DD-MON-RRRR');

         --Commented by Satyashree for NBTY Procurement Implementation start--

         /*IF ReceLine_REC.transaction_type IN ('RECEIVE' , 'DELIVER')

         THEN



           G_Rec_Trx_Table(g_trx_cnt).auto_transact_code := 'DELIVER';

             --// Added for change requirement as on 05-Feb-2013

           IF ReceLine_REC.legacy_item_num IS NULL

           THEN

             G_Rec_Trx_Table(g_trx_cnt).destination_type_code := 'EXPENSE';

             G_Rec_Trx_Table(g_trx_cnt).subinventory := NULL;

           ELSE

             G_Rec_Trx_Table(g_trx_cnt).destination_type_code := 'INVENTORY';

             G_Rec_Trx_Table(g_trx_cnt).subinventory := 'STAGE';

           END IF;



           --// Check transaction Quantity should not be Negative and Null for receive

           IF ReceLine_REC.quantity <= 0 OR ReceLine_REC.quantity IS NULL

           THEN

             l_log_msg := 'Receipt Quantity Should not be negative or blank value '

                            ||ReceLine_REC.quantity

                            ||'. Check Transaction Type';



             insert_trx_error (p_proc_name => l_proc_name

                             , p_log_msg => l_log_msg

                             , p_event_id => ReceLine_REC.stage_event_id

                             , p_record_id => ReceLine_REC.stage_record_id);



             log_put_line (l_log_msg );

             l_error_flag := APPS.fnd_api.g_true;

             l_error_msg := l_error_msg

                              || ' '

                              ||l_log_msg ;



           END IF;

         ELSE

           G_Rec_Trx_Table(g_trx_cnt).auto_transact_code := NULL;

           G_Rec_Trx_Table(g_trx_cnt).destination_type_code := NULL;

           G_Rec_Trx_Table(g_trx_cnt).subinventory := NULL;

         END IF;*/

         --END--



         G_Rec_Trx_Table (g_trx_cnt).processing_status_code := 'PENDING';

         G_Rec_Trx_Table (g_trx_cnt).processing_mode_code := 'BATCH';

         G_Rec_Trx_Table (g_trx_cnt).source_document_code := 'PO';

         G_Rec_Trx_Table (g_trx_cnt).transaction_status_code := 'PENDING';

         G_Rec_Trx_Table (g_trx_cnt).receipt_source_code := 'VENDOR';



         G_Rec_Trx_Table (g_trx_cnt).po_release_id :=

            ReceLine_REC.po_release_id;

         G_Rec_Trx_Table (g_trx_cnt).po_revision_num :=

            ReceLine_REC.po_revision_num;



         G_Rec_Trx_Table (g_trx_cnt).validation_flag := 'Y';



         G_Rec_Trx_Table (g_trx_cnt).org_id := g_org_id;

         G_Rec_Trx_Table (g_trx_cnt).document_num := ReceLine_REC.document_num;

         G_Rec_Trx_Table (g_trx_cnt).document_line_num :=

            ReceLine_REC.document_line_num;

         G_Rec_Trx_Table (g_trx_cnt).stage_group_id := p_group_id;

         G_Rec_Trx_Table (g_trx_cnt).stage_event_id :=

            ReceLine_REC.stage_event_id;

         G_Rec_Trx_Table (g_trx_cnt).stage_last_update_date := SYSDATE;

         G_Rec_Trx_Table (g_trx_cnt).stage_last_updated_by := g_user_id;

         G_Rec_Trx_Table (g_trx_cnt).stage_request_id := g_request_id;

         G_Rec_Trx_Table (g_trx_cnt).stage_last_update_login := g_login_id;



         IF ReceLine_REC.legacy_item_num IS NOT NULL

         THEN

            l_item_id := NULL;

            l_item_num := NULL;



            -- Get item details

            get_item_dtl (p_le_item_num   => ReceLine_REC.legacy_item_num,

                          p_event_id      => ReceLine_REC.stage_event_id,

                          p_record_id     => ReceLine_REC.stage_record_id,

                          x_item_id       => l_item_id,

                          x_item_num      => l_item_num,

                          x_error_flag    => l_error_flag,

                          x_error_msg     => l_error_msg);



            G_Rec_Trx_Table (g_trx_cnt).item_id := l_item_id;

            G_Rec_Trx_Table (g_trx_cnt).item_num := l_item_num;



            log_put_line ('get Item Number ' || l_item_num);



            IF l_item_id IS NULL OR l_item_num IS NULL

            THEN

               l_log_msg :=

                     'Invalid Item Number Provided. '

                  || ReceLine_REC.legacy_item_num

                  || ' Item does not exist.';



               insert_trx_error (

                  p_proc_name   => l_proc_name,

                  p_log_msg     => l_log_msg,

                  p_event_id    => ReceLine_REC.stage_event_id,

                  p_record_id   => ReceLine_REC.stage_record_id);



               log_put_line (l_log_msg);

               l_error_flag := APPS.fnd_api.g_true;

               l_error_msg := l_error_msg || ' ' || l_log_msg;

            END IF;      /* IF l_item_id IS NULL OR l_item_num IS NULL THEN */

         ELSE

            l_category_id := NULL;

            -- changes start for 25-Feb-2015

            /*       get_item_category (

                                 p_category_name => ReceLine_REC.item_category

                               , p_event_id => ReceLine_REC.stage_event_id

                               , p_record_id => ReceLine_REC.stage_record_id

                               , x_category_id => l_category_id

                               , x_error_flag => l_error_flag

                               , x_error_msg => l_error_msg);*/

            get_item_category (p_po_line_id    => ReceLine_REC.po_line_id,

                               p_event_id      => ReceLine_REC.stage_event_id,

                               p_record_id     => ReceLine_REC.stage_record_id,

                               x_category_id   => l_category_id,

                               x_error_flag    => l_error_flag,

                               x_error_msg     => l_error_msg);

            -- changes end for 25-Feb-2015

            G_Rec_Trx_Table (g_trx_cnt).item_category_id := l_category_id;

            log_put_line ('get Category Number ' || l_category_id);



            IF l_category_id IS NULL

            THEN

               l_log_msg :=

                     'Invalid Category Provided. '

                  || ReceLine_REC.item_category

                  || ' Category does not exist.';



               insert_trx_error (

                  p_proc_name   => l_proc_name,

                  p_log_msg     => l_log_msg,

                  p_event_id    => ReceLine_REC.stage_event_id,

                  p_record_id   => ReceLine_REC.stage_record_id);



               log_put_line (l_log_msg);

               l_error_flag := APPS.fnd_api.g_true;

               l_error_msg := l_error_msg || ' ' || l_log_msg;

            END IF;                        /* IF l_category_id IS NULL THEN */

         END IF;



         G_Rec_Trx_Table (g_trx_cnt).unit_of_measure :=

            ReceLine_REC.unit_of_measure;

         --Get item details

         get_uom (

            p_uom_code     => G_Rec_Trx_Table (g_trx_cnt).unit_of_measure,

            p_event_id     => ReceLine_REC.stage_event_id,

            p_record_id    => ReceLine_REC.stage_record_id,

            x_uom_code     => G_Rec_Trx_Table (g_trx_cnt).unit_of_measure,

            x_error_flag   => l_error_flag,

            x_error_msg    => l_error_msg);





         get_po_header_id (p_doc_num        => ReceLine_REC.document_num,

                           p_event_id       => ReceLine_REC.stage_event_id,

                           p_record_id      => ReceLine_REC.stage_record_id,

                           p_release_num    => ReceLine_REC.release_num -- // Added on 31-Dec-2013 Procurement Implementation Shyam B

                                                                       ,

                           x_po_header_id   => l_po_header_id,

                           x_error_flag     => l_error_flag,

                           x_error_msg      => l_error_msg);

         -- check po header and lines and qty

         log_put_line ('l_po_header_id==>' || l_po_header_id);



         IF l_po_header_id IS NOT NULL

         THEN

            check_po_dtl (p_po_num         => ReceLine_REC.document_num,

                          p_po_header_id   => l_po_header_id -- // added po_header_id Parameter on 31-Dec-2013 Procurement Implementation Shyam B                                            --

                                                            ,

                          p_po_line_num    => ReceLine_REC.document_line_num,

                          p_event_id       => ReceLine_REC.stage_event_id,

                          p_record_id      => ReceLine_REC.stage_record_id--, x_line_location_id    => l_line_location_id      -- // Commented on 31-Dec-2013 Procurement Implementation Shyam B

                                                                          --, x_ship_to_org_id      => l_ship_to_org_id        -- // Commented on 31-Dec-2013 Procurement Implementation Shyam B

                                                                          --, x_ship_to_location_id => l_ship_to_location_id   -- // Commented on 31-Dec-2013 Procurement Implementation Shyam B

                          ,

                          x_po_header_id   => l_po_header_id,

                          x_po_line_id     => l_po_line_id,

                          x_item_id        => l_item_id--, x_remaining_qty       => l_remaining_qty         -- Commented on 31-Dec-2013 Procurement Implementation Shyam B

                          ,

                          x_category_id    => l_category_id,

                          x_error_flag     => l_error_flag,

                          x_error_msg      => l_error_msg);



            -- //

            -- // Added on 31-Dec-2013 Procurement Implementation Shyam B

            -- // Added the below procedure call to check release

            -- // and shipment information

            -- check po relase shipment and qty

            IF l_po_line_id IS NOT NULL

            THEN

               l_release_id := NULL;

               check_po_ship_dtl (

                  p_po_num                     => ReceLine_REC.document_num,

                  p_po_line_num                => ReceLine_REC.document_line_num,

                  p_po_header_id               => l_po_header_id,

                  p_po_line_id                 => l_po_line_id,

                  p_release_num                => ReceLine_REC.release_num,

                  p_shipment_num               => ReceLine_REC.document_shipment_line_num,

                  p_event_id                   => ReceLine_REC.stage_event_id,

                  p_record_id                  => ReceLine_REC.stage_record_id,

                  x_line_location_id           => l_line_location_id,

                  x_ship_to_org_id             => l_ship_to_org_id,

                  x_ship_to_location_id        => l_ship_to_location_id,

                  x_remaining_qty              => l_remaining_qty,

                  x_po_release_id              => l_release_id,

                  x_ship_location_code         => lc_ship_location_code,

                  x_DESTINATION_SUBINVENTORY   => lc_DESTINATION_SUBINVENTORY,

                  x_error_flag                 => l_error_flag,

                  x_error_msg                  => l_error_msg);

            END IF;



            IF l_line_location_id IS NOT NULL

            THEN

               G_Rec_Trx_Table (g_trx_cnt).po_header_id := l_po_header_id;

               G_Rec_Trx_Table (g_trx_cnt).po_line_id := l_po_line_id;

               G_Rec_Trx_Table (g_trx_cnt).po_line_location_id :=

                  l_line_location_id;

               G_Rec_Trx_Table (g_trx_cnt).location_id :=

                  ReceLine_REC.location_id;

               G_Rec_Trx_Table (g_trx_cnt).to_organization_id :=

                  l_ship_to_org_id;

               G_Rec_Trx_Table (g_trx_cnt).quantity := ReceLine_REC.quantity;

               G_Rec_Trx_Table (g_trx_cnt).po_release_id := l_release_id;

               G_Rec_Trx_Table (g_trx_cnt).attribute4 := lc_ship_location_code;



               -- G_Rec_Trx_Table(g_trx_cnt).subinventory                := lc_DESTINATION_SUBINVENTORY;

               IF ReceLine_REC.transaction_type IN ('RECEIVE', 'DELIVER')

               THEN

                  G_Rec_Trx_Table (g_trx_cnt).auto_transact_code := 'DELIVER';



                  --// Added for change requirement as on 05-Feb-2013

                  IF ReceLine_REC.legacy_item_num IS NULL

                  THEN

                     G_Rec_Trx_Table (g_trx_cnt).destination_type_code := 'EXPENSE';

                     G_Rec_Trx_Table (g_trx_cnt).subinventory := NULL;

                  ELSE
					--Start of Changes AFLORES 9/28/2016

							 BEGIN
							 
							 lv_subinventory := NULL;

								SELECT flv2.description
								INTO lv_subinventory
								FROM   fnd_lookup_values flv2
								WHERE  flv2.lookup_type = 'XXNBTY_SUBINVCODE_LOOKUP'
								AND UPPER(flv2.lookup_code) = (SELECT DISTINCT UPPER(ecg.catalog_group)
															   FROM mtl_system_items 	  msi
																  , apps.ego_catalog_groups_v  ecg
															   WHERE ecg.catalog_group_id	= msi.item_catalog_group_id
															   --AND   msi.organization_id	= receline_rec.to_organization_id --receline_rec.org_id
															   AND   msi.segment1			= ReceLine_REC.item_num)
								AND UPPER(flv2.meaning)  = (SELECT DISTINCT UPPER(ecg.catalog_group)
															FROM mtl_system_items msi
															   , apps.ego_catalog_groups_v ecg
															WHERE ecg.catalog_group_id  = msi.item_catalog_group_id
															--AND   msi.organization_id	= receline_rec.to_organization_id --receline_rec.org_id
															AND   msi.segment1          = ReceLine_REC.item_num);
									EXCEPTION

										WHEN NO_DATA_FOUND THEN
										
															  lv_subinventory := 'RAW MTL';

							 END;

					--End of Changes AFLORES 9/28/2016

                     G_Rec_Trx_Table (g_trx_cnt).destination_type_code :=  'INVENTORY';

                     G_Rec_Trx_Table (g_trx_cnt).subinventory := lv_subinventory; --AFLORES 9/28/2016
                        --NVL (lc_DESTINATION_SUBINVENTORY, 'STAGE');
                        --NVL(lv_subinventory,'RAW MTL'); --change request 03/08/2016 Ken
                  END IF;



                  --// Check transaction Quantity should not be Negative and Null for receive

                  IF    ReceLine_REC.quantity <= 0

                     OR ReceLine_REC.quantity IS NULL

                  THEN

                     l_log_msg :=

                           'Receipt Quantity Should not be negative or blank value '

                        || ReceLine_REC.quantity

                        || '. Check Transaction Type';



                     insert_trx_error (

                        p_proc_name   => l_proc_name,

                        p_log_msg     => l_log_msg,

                        p_event_id    => ReceLine_REC.stage_event_id,

                        p_record_id   => ReceLine_REC.stage_record_id);



                     log_put_line (l_log_msg);

                     l_error_flag := APPS.fnd_api.g_true;

                     l_error_msg := l_error_msg || ' ' || l_log_msg;

                  END IF;

               ELSE

                  G_Rec_Trx_Table (g_trx_cnt).auto_transact_code := NULL;

                  G_Rec_Trx_Table (g_trx_cnt).destination_type_code := NULL;

                  G_Rec_Trx_Table (g_trx_cnt).subinventory := NULL;

               END IF;

            ----

            END IF;

         END IF;



         --// Commented After receive mail form jamal date 31-Jan-2013

         --// Ben wrote this 2.        The feeder program validation should allow

         --// records whose interfaced receipt quantity is greater than the

         --// PO quantity. The program should allow over-receipts and not mark

         --// the record as error.

         /*

         IF l_remaining_qty < nvl(ReceLine_REC.quantity,0)

         THEN

           l_log_msg := 'PO line Qty less '||l_remaining_qty

                          || ' then Interfaced Qty '

                          || ReceLine_REC.quantity;



           insert_trx_error (p_proc_name => l_proc_name

                           , p_log_msg => l_log_msg

                           , p_event_id => ReceLine_REC.stage_event_id

                           , p_record_id => ReceLine_REC.stage_record_id);



           log_put_line (l_log_msg );

           l_error_flag := APPS.fnd_api.g_true;

           l_error_msg := l_error_msg

                            || ' '

                            ||l_log_msg ;

         END IF;

         */

         IF ReceLine_REC.transaction_type IN ('CORRECT')

         THEN

            get_parent_trans (

               p_po_header_id       => l_po_header_id,

               p_po_line_id         => l_po_line_id,

               p_line_location_id   => l_line_location_id -- // Added on 31-Dec-2013 Procurement Implementation Shyam B

                                                         ,

               p_po_qty             => NVL (ReceLine_REC.quantity, 0),

               p_event_id           => ReceLine_REC.stage_event_id,

               p_record_id          => ReceLine_REC.stage_record_id,

               x_error_flag         => l_error_flag,

               x_error_msg          => l_error_msg);

         END IF;

		 
		--Added for Costing validation 
		--Start of changes AFLORES 10/12/2016
		log_put_line ('Starting Validation of unit cost for item - [ ' || ReceLine_REC.item_num || ' ] and org - [ ' || l_ship_to_org_id || ' ] ');
		
		--initiate variable for unit cost and inv item flag AFLORES 10/12/2016
		l_unit_cost 			:= NULL;
		l_inventory_item_flag	:= NULL;
		
		IF ReceLine_REC.item_num IS NOT NULL AND l_ship_to_org_id IS NOT NULL  THEN
			
			--Added for validation of unit cost for Inventory type items only
			BEGIN
			
				SELECT DISTINCT inventory_item_flag
				INTO	l_inventory_item_flag
				FROM mtl_system_items
				WHERE segment1 = ReceLine_REC.item_num
				AND   organization_id = l_ship_to_org_id;
			
			EXCEPTION
			
				WHEN NO_DATA_FOUND THEN
					l_log_msg :=
					 'Item - Org Combination not found in mtl_system_items for derivation of inventory_item_flag. Item Number [ ' || ReceLine_REC.item_num || ' ] - OrgID [ '|| l_ship_to_org_id || ' ] ';

					insert_trx_error (
					  p_proc_name   => l_proc_name,
					  p_log_msg     => l_log_msg,
					  p_event_id    => ReceLine_REC.stage_event_id,
					  p_record_id   => ReceLine_REC.stage_record_id);

				   log_put_line (l_log_msg);
				   l_error_flag := APPS.fnd_api.g_true;
				   l_error_msg  := l_error_msg || ' ' || l_log_msg;
			END; 
			
			IF l_inventory_item_flag = 'Y' THEN 
			--Standard unit cost validation for inventory items	
				BEGIN
												
					SELECT NVL((CASE WHEN mp.PROCESS_ENABLED_FLAG = 'N' THEN (SELECT SUM(item_cost)
																		FROM ( SELECT DISTINCT cicd.cost_element
																					  ,cicd.Resource_code
																					  ,cicd.usage_rate_or_amount
																					  ,cicd.item_cost
																					  ,msi_disc.segment1
																					  ,mp_disc.organization_code
																					  ,cict.cost_type
																					  ,msi_disc.inventory_item_id
																					  ,mp_disc.organization_id
																			   FROM apps.cst_item_cost_details_v cicd,
																			   mtl_system_items msi_disc,
																			   mtl_parameters mp_disc,
																			   apps.CST_ITEM_COST_TYPE_V cict
																			   WHERE cicd.inventory_item_id   =   msi_disc.inventory_item_id
																			   AND   cicd.organization_id     =   msi_disc.organization_id
																			   AND   cicd.organization_id     =   mp_disc.organization_id
																			   AND   cicd.inventory_item_id   =   cict.inventory_item_id
																			   AND   cicd.organization_id     =   cict.organization_id
																			   --Modified for discreet org cost validation AFLORES 11/3/2016
																			   and   UPPER(cict.cost_type)    = 'FROZEN' 
																			   AND   cicd.cost_type_id		 =	 cict.cost_type_id
																			   ) disc_cost
																			   WHERE disc_cost.inventory_item_id = msi.inventory_item_id
																			   AND   disc_cost.organization_id   = msi.organization_id
																			   AND   disc_cost.organization_id   = mp.organization_id
																		 )
							 --Modified to change the cost table to gl_item_cst aflores 10/12/2016
							WHEN mp.PROCESS_ENABLED_FLAG = 'Y' THEN (SELECT SUM(acctg_cost)
																		FROM (SELECT DISTINCT mp_proc.organization_id
																							 ,msi_proc.segment1
																							 ,a.inventory_item_id
																							 ,a.acctg_cost
																							 --,ccm.cost_cmpntcls_code
																							 ,a.period_id
																			  FROM
																			  --apps.CM_CMPT_DTL  ccd,
																			  --apps.CM_CMPT_MST ccm ,
																			  apps.gl_item_cst a,
																			  mtl_system_items msi_proc,
																			  mtl_parameters mp_proc
																			  WHERE a.inventory_item_id   = msi_proc.inventory_item_id
																			  AND a.organization_id       = msi_proc.organization_id
																			  --AND ccd.cost_cmpntcls_id      = ccm.cost_cmpntcls_id
																			  AND a.organization_id       = mp_proc.organization_id
																			  AND a.organization_id       = msi_proc.organization_id
																			  AND a.delete_mark = 0
																			  ) proc_cost
																		WHERE proc_cost.period_id = gps.period_id
																		AND   ReceLine_REC.transaction_date >= gps.START_DATE
																		AND   ReceLine_REC.transaction_date <  TO_DATE(TO_CHAR(gps.end_date,'DD-MON-YY')||' 11:59:59PM','DD-MON-YY HH:MI:SSAM')
																		AND   proc_cost.inventory_item_id = msi.inventory_item_id
																		AND   proc_cost.organization_id   = msi.organization_id
																		AND   proc_cost.organization_id   = mp.organization_id
							   )
							   END ), 0 ) AS UNIT_COST --made it NVL of zero AFLORES 9/21/2016
					INTO l_unit_cost
					FROM  mtl_parameters mp
					  , gmf_period_statuses gps
					  , mtl_system_items msi
					WHERE
						 (ReceLine_REC.transaction_date >= gps.start_date )
					AND    (ReceLine_REC.transaction_date < TO_DATE(TO_CHAR(gps.end_date,'DD-MON-YY')||' 11:59:59PM','DD-MON-YY HH:MI:SSAM')  )
					AND   mp.organization_id            = msi.organization_id
					AND   msi.segment1                  = ReceLine_REC.item_num
					AND   msi.organization_id           = ReceLine_REC.to_organization_id;

				EXCEPTION
				WHEN NO_DATA_FOUND THEN
				
				   l_unit_cost   := 0;--made it zero AFLORES 9/21/2016
				   
				END;
			
			END IF;
			
		ELSE
		/*
				l_log_msg := 'Either Item Number or Organization ID is NULL. Kindly Validate the Data in the Staging Table';
				
				insert_trx_error (
				  p_proc_name   => l_proc_name,
				  p_log_msg     => l_log_msg,
				  p_event_id    => ReceLine_REC.stage_event_id,
				  p_record_id   => ReceLine_REC.stage_record_id);

				log_put_line (l_log_msg);
				l_error_flag := APPS.fnd_api.g_true;
				l_error_msg  := l_error_msg || ' ' || l_log_msg;
		*/		
		
			--As discussed with onshore team, if the item number is blanked then we will ignore validation for unit cost
			--AFLORES 10/12/2016
			NULL;
		
		END IF;

	--[START] Check if the Unit Cost is zero then Error this record out

		IF l_unit_cost = 0 THEN
         
			l_log_msg :=
					 'No Unit Cost has been found for this Item Number [ ' || ReceLine_REC.item_num || ' ] - OrgID [ '|| l_ship_to_org_id || ' ] ';

		    insert_trx_error (
			  p_proc_name   => l_proc_name,
			  p_log_msg     => l_log_msg,
			  p_event_id    => ReceLine_REC.stage_event_id,
			  p_record_id   => ReceLine_REC.stage_record_id);

		   log_put_line (l_log_msg);
		   l_error_flag := APPS.fnd_api.g_true;
		   l_error_msg  := l_error_msg || ' ' || l_log_msg;

		END IF;
		
		--End of changes AFLORES 9/28/2016


         G_Rec_Trx_Table (g_trx_cnt).msg := l_error_msg;



         IF l_error_flag = APPS.fnd_api.g_false

         THEN

            IF ReceLine_REC.hdr_status = g_sts_vlderr_constant

            THEN

               G_Rec_Trx_Table (g_trx_cnt).stage_process_flag :=

                  g_sts_vlderr_constant;

               G_Rec_Trx_Table (g_trx_cnt).status := 'ERROR';

               G_Rec_Trx_Table (g_trx_cnt).stage_error_type := 'VALIDATION';

            ELSE

               G_Rec_Trx_Table (g_trx_cnt).stage_process_flag :=

                  g_sts_vld_constant;

               G_Rec_Trx_Table (g_trx_cnt).status := 'SUCCESS';

            END IF;

         ELSE

            G_Rec_Trx_Table (g_trx_cnt).status := 'ERROR';

            G_Rec_Trx_Table (g_trx_cnt).stage_process_flag :=

               g_sts_vlderr_constant;

            G_Rec_Trx_Table (g_trx_cnt).stage_error_type := 'VALIDATION';

         END IF;


         --
         --
         -- Post-Live Changes by Jairaj

         -- ------------------------------------------------------------------

         -- Reset the quantity back to ORIGINAL instead of NULL in some cases

         -- ------------------------------------------------------------------

         G_Rec_Trx_Table (g_trx_cnt).quantity := ReceLine_REC.quantity;



         g_trx_cnt := g_trx_cnt + 1;

      END LOOP;



      log_put_line ('End Receipt Transaction...');

      log_put_line (' ');



      log_put_line ('Procedure ' || l_proc_name || '. End.');

   EXCEPTION

      WHEN OTHERS

      THEN

         l_log_msg :=

               'Unexpected Error in Procedure '

            || l_proc_name

            || '. Err='

            || TO_CHAR (SQLCODE)

            || ' '

            || SQLERRM;

         log_put_line (l_log_msg);

         insert_error (g_event_id,

                       'ERROR',

                       l_proc_name,

                       l_log_msg);

         p_error_msg :=

            p_error_msg || ' Unexpected Error in Procedure' || SQLERRM;

         p_error_flag := APPS.fnd_api.g_true;

   END validate_rcv_trx_data;



   ----------------------------------------------------------------------

   /*



    Pocedure Name: validate_stage_tables

    Author? name: Amit Kumar (NBTY ERP Implementation)

    Date written: 09-Nov-12

    RICEFW Object id: NBTY-PRC-I-013

    Description: Validate and Update Staging table

    Program Style: Subordinate



    Maintenance History:



    Date Issue# Name Remarks

    ----------- -------- ---------------- ------------------------------------------

    31-Jan-12 Amit Kumar Initial development.



   */

   ----------------------------------------------------------------------



   PROCEDURE validate_stage_tables

   IS

      l_proc_name   VARCHAR2 (100) := 'validate_stage_tables';

      l_log_msg     VARCHAR2 (500);

      l_line        VARCHAR2 (100) := RPAD ('*', 70, '*');



      --// Checking Header table not corresponds records in event table

      CURSOR HDR_EVENT_CUR

      IS

         SELECT *

           FROM xxnbty_rcv_headers_stg xrhs

          WHERE     xrhs.stage_process_flag != g_sts_err_constant -- New Condition Added by Pavan

                AND NOT EXISTS

                           (SELECT event_id

                              FROM xxnbty_ibi_events xie

                             WHERE     xie.event_id = xrhs.stage_event_id

                                   AND xie.event_type = 'RCV_IBI');



      --// Checking Transaction table not corresponds records in event table

      CURSOR TRX_EVENT_CUR

      IS

         SELECT *

           FROM xxnbty_rcv_transactions_stg xrts

          WHERE     xrts.stage_process_flag != g_sts_err_constant -- New Condition Added by Pavan

                AND NOT EXISTS

                           (SELECT event_id

                              FROM xxnbty_ibi_events xie

                             WHERE     xie.event_id = xrts.stage_event_id

                                   AND xie.event_type = 'RCV_IBI');



      --// Checking Event table not corresponds records in Header table

      CURSOR EVENT_HDR_CUR

      IS

         SELECT *

           FROM xxnbty_ibi_events xie

          WHERE     xie.event_type = 'RCV_IBI'

                AND xie.event_status != g_sts_err_constant -- New Condition Added by Pavan

                AND NOT EXISTS

                       (SELECT event_id

                          FROM xxnbty_rcv_headers_stg xrhs

                         WHERE xie.event_id = xrhs.stage_event_id);



      --// Checking Event table not corresponds records in Trans table

      CURSOR EVENT_TRX_CUR

      IS

         SELECT *

           FROM xxnbty_ibi_events xie

          WHERE     xie.event_type = 'RCV_IBI'

                AND xie.event_status != g_sts_err_constant -- New Condition Added by Pavan

                AND NOT EXISTS

                       (SELECT event_id

                          FROM xxnbty_rcv_transactions_stg xrts

                         WHERE xie.event_id = xrts.stage_event_id);



      CURSOR c_get_error_list

      IS

           SELECT error_message

             FROM xxnbty_int_errors

            WHERE     source_table_record_id = g_source_rec_id

                  AND request_id = g_request_id

                  AND interface_type = g_interface_type

                  AND message_severity = 'ERROR'

         ORDER BY error_id;



   BEGIN

      log_put_line ('Procedure ' || l_proc_name || '. Begin');



      FOR event_hdr_rec IN event_hdr_cur

      LOOP

         UPDATE bolinf.xxnbty_ibi_events

            SET event_status = g_sts_err_constant,

                processed_attempts = 1,

                request_id_feeder_program = g_request_id,

                last_updated_by = g_user_id,

                last_update_date = SYSDATE

          WHERE event_id = event_hdr_rec.event_id;



         l_log_msg :=

               'Event ID '

            || event_hdr_rec.event_id

            || ' does not have corresponding record in receipts header staging table.';



         insert_error (g_event_id,

                       'ERROR',

                       l_proc_name,

                       l_log_msg);

      END LOOP;



      FOR event_trx_rec IN event_trx_cur

      LOOP

         UPDATE bolinf.xxnbty_ibi_events

            SET event_status = g_sts_err_constant,

                processed_attempts = 1,

                request_id_feeder_program = g_request_id,

                last_updated_by = g_user_id,

                last_update_date = SYSDATE

          WHERE event_id = event_trx_rec.event_id;



         l_log_msg :=

               'Event ID '

            || event_trx_rec.event_id

            || ' does not have corresponding record in receipts Trans staging table.';



         insert_error (g_event_id,

                       'ERROR',

                       l_proc_name,

                       l_log_msg);

      END LOOP;



      FOR hdr_event_rec IN hdr_event_cur

      LOOP

         UPDATE bolinf.xxnbty_rcv_headers_stg

            SET stage_process_flag = g_sts_err_constant,

                stage_request_id = g_request_id,

                stage_last_updated_by = g_user_id,

                stage_last_update_date = SYSDATE

          WHERE stage_event_id = hdr_event_rec.stage_event_id;



         l_log_msg :=

               'Event ID '

            || hdr_event_rec.stage_event_id

            || ' does not have corresponding record in Event table.';



         insert_error (g_event_id,

                       'ERROR',

                       l_proc_name,

                       l_log_msg);

      END LOOP;



      FOR trx_event_rec IN trx_event_cur

      LOOP

         UPDATE bolinf.xxnbty_rcv_transactions_stg

            SET stage_process_flag = g_sts_err_constant,

                stage_request_id = g_request_id,

                stage_last_updated_by = g_user_id,

                stage_last_update_date = SYSDATE

          WHERE stage_event_id = trx_event_rec.stage_event_id;



         l_log_msg :=

               'Event ID '

            || trx_event_rec.stage_event_id

            || ' does not have corresponding record in Event table.';



         insert_error (g_event_id,

                       'ERROR',

                       l_proc_name,

                       l_log_msg);

      END LOOP;



      COMMIT;



      FOR error_rec IN c_get_error_list

      LOOP

         IF g_prn_check = 1

         THEN

            log_put_line ('Printing Errors');

            output_put_line (l_line);

            output_put_line (' ***** List of Errors: ***** ');

            output_put_line (l_line);

            g_prn_check := 2;

         END IF;



         output_put_line (error_rec.error_message);

      END LOOP;



      log_put_line ('Procedure ' || l_proc_name || '. End.');

   EXCEPTION

      WHEN OTHERS

      THEN

         l_log_msg :=

               'Unexpected Error in Procedure '

            || l_proc_name

            || '. Err='

            || TO_CHAR (SQLCODE)

            || ' '

            || SQLERRM;

         log_put_line (l_log_msg);

         insert_error (g_event_id,

                       'ERROR',

                       l_proc_name,

                       l_log_msg);

   END validate_stage_tables;


   ----------------------------------------------------------------------
   /*

    Pocedure Name: validate_duplicate_records
    Author? name: Infosys
    Date written: 19-Feb-14
    RICEFW Object id: NBTY-PRC-I-013
    Description: Validate duplicate records and Update Staging table
    Program Style: Subordinate

    Maintenance History:

    Date Issue#   Name      Remarks
    ------------------------------------------------------------------------------
    19-Feb-14     Infosys   Initial development, new procedure created as part of PRJ10456.
   */
   ----------------------------------------------------------------------

   PROCEDURE validate_duplicate_records
   IS
      l_proc_name      VARCHAR2 (100) := 'validate_duplicate_records';
      l_log_msg        VARCHAR2 (5000);
      l_line           VARCHAR2 (100) := RPAD ('*', 70, '*');
      lv_receipt_num   VARCHAR2 (30) := 'NULL';

      --// Finding duplicate records by grouping the RECEIPT_NUM, DOCUMENT_NUM and DOCUMENT_LINE_NUM
      CURSOR DUP_REC_CUR
      IS
           SELECT MAX (a.stage_event_id) max_stage_event_id,
                  a.receipt_num,
                  b.document_num,
                  b.document_line_num,
                  b.document_shipment_line_num
             FROM xxnbty_rcv_headers_stg a, xxnbty_rcv_transactions_stg b
            WHERE     a.stage_event_id = b.stage_event_id
                  AND a.stage_process_flag = g_sts_new_constant
         --AND b.stage_process_flag = g_sts_new_constant
         GROUP BY a.receipt_num, b.document_num, b.document_line_num, b.document_shipment_line_num
           HAVING COUNT (a.receipt_num) > 1
         ORDER BY 2;

      CURSOR GET_EVENT_ID_CUR (
         p_receipt_num    VARCHAR2,
         p_event_id       NUMBER)
      IS
         SELECT stage_event_id
           FROM xxnbty_rcv_headers_stg
          WHERE     receipt_num = p_receipt_num
                AND stage_process_flag = g_sts_ignore_constant
                AND stage_request_id = g_request_id
                AND stage_event_id != p_event_id;

   BEGIN
      log_put_line ('Procedure ' || l_proc_name || '. Begin');

      FOR dup_rec IN dup_rec_cur                                           --1
      LOOP
         IF lv_receipt_num != dup_rec.receipt_num
         THEN
            lv_receipt_num := dup_rec.receipt_num;

            --//Updating xxnbty_rcv_headers_stg for duplicate records
            UPDATE xxnbty_rcv_headers_stg
               SET stage_process_flag = g_sts_ignore_constant,
                   stage_last_update_date = SYSDATE,
                   stage_last_updated_by = g_user_id,
                   stage_request_id = g_request_id
             WHERE     receipt_num = dup_rec.receipt_num
                   AND stage_event_id != dup_rec.max_stage_event_id
                   AND stage_process_flag = g_sts_new_constant;

            FOR get_event_id
               IN get_event_id_cur (dup_rec.receipt_num,
                                    dup_rec.max_stage_event_id)            --2
            LOOP
               l_log_msg :=
                     'Event ID: '
                  || get_event_id.stage_event_id
                  || ' is duplicate event for receipt number: '
                  || dup_rec.receipt_num;

               insert_error (get_event_id.stage_event_id,
                             'ERROR',
                             l_proc_name,
                             l_log_msg);
            END LOOP;                                                      --2
         END IF;

         --//Updating xxnbty_rcv_transactions_stg for duplicate records
         UPDATE xxnbty_rcv_transactions_stg
            SET stage_process_flag = g_sts_ignore_constant,
                attribute10 = 'Duplicate receipt (1st validation).',
                stage_last_update_date = SYSDATE,
                stage_last_updated_by = g_user_id,
                stage_request_id = g_request_id
          WHERE     stage_event_id != dup_rec.max_stage_event_id
                AND document_num = dup_rec.document_num
                AND document_line_num = dup_rec.document_line_num
                AND (   stage_process_flag = g_sts_new_constant
                     OR stage_process_flag NOT IN
                           (g_sts_err_constant, g_sts_int_constant))
                AND stage_event_id IN 	--added on 01-Jun-2016.
                      		(SELECT stage_event_id
                      		   FROM xxnbty_rcv_headers_stg
                      		  WHERE     receipt_num = dup_rec.receipt_num)     ;


         --//Updating xxnbty_ibi_events for duplicate records
         UPDATE xxnbty_ibi_events
            SET event_status = g_sts_ignore_constant,
                last_update_date = SYSDATE,
                last_updated_by = g_user_id,
                request_id_feeder_program = g_request_id
          WHERE     event_id != dup_rec.max_stage_event_id
                AND event_status = g_sts_new_constant
                AND event_id IN
                       (SELECT stage_event_id
                          FROM xxnbty_rcv_headers_stg
                         WHERE     receipt_num = dup_rec.receipt_num
                               AND stage_process_flag = g_sts_ignore_constant
                               AND stage_request_id = g_request_id
                               AND stage_event_id !=
                                      dup_rec.max_stage_event_id);
      END LOOP;                                                            --1

      COMMIT;

      log_put_line ('Procedure ' || l_proc_name || '. End.');
   EXCEPTION
      WHEN OTHERS
      THEN
         l_log_msg :=
               'Unexpected Error in Procedure '
            || l_proc_name
            || '. Err='
            || TO_CHAR (SQLCODE)
            || ' '
            || SQLERRM;
         log_put_line (l_log_msg);
         insert_error (g_event_id,
                       'ERROR',
                       l_proc_name,
                       l_log_msg);
   END validate_duplicate_records;


   ----------------------------------------------------------------------
      /*

       Pocedure Name: validate_duplicate_records2
       Author? name: Infosys
       Date written: 01-Jun-2016
       RICEFW Object id: NBTY-PRC-I-013
       Description: Validate duplicate records and Update Staging table
       Program Style: Subordinate

       Maintenance History:

       Date Issue#   Name      Remarks
       ------------------------------------------------------------------------------
       01-Jun-2016     Infosys   Initial development, new procedure created as part of XXXXX.
	   28-Sep-2016	   Albert Flores	Shortened attribute10 values to 30 characters. error messages are too long.
      */
      ----------------------------------------------------------------------

      PROCEDURE validate_duplicate_records2
      IS
         l_proc_name      VARCHAR2 (100) := 'validate_duplicate_records2';
         l_log_msg        VARCHAR2 (5000);
         l_line           VARCHAR2 (100) := RPAD ('*', 70, '*');
         lv_receipt_num   VARCHAR2 (30) := 'NULL';
         ln_success       NUMBER := 0;

         --// Finding duplicate records by grouping the RECEIPT_NUM, DOCUMENT_NUM and DOCUMENT_LINE_NUM
         CURSOR dup_rec_cur
         IS
              SELECT MAX (a.stage_event_id) max_stage_event_id,
                     a.receipt_num,
                     b.document_num,
                     b.document_line_num,
                     b.document_shipment_line_num,
                     COUNT (a.stage_event_id) rec_count
                FROM xxnbty_rcv_headers_stg a,
                     xxnbty_rcv_transactions_stg b,
                     xxnbty_ibi_events c
               WHERE     a.stage_event_id = b.stage_event_id
                     AND b.stage_event_id = c.event_id
                     AND c.event_status IN ('U', 'E', 'I')
                     AND b.stage_process_flag IN ('U', 'E', 'I')
                     AND EXISTS -- This condition will remove the possibility of pulling all the processed duplicate records.
                            (SELECT 1
                               FROM xxnbty_rcv_headers_stg aa,
                                    xxnbty_rcv_transactions_stg bb,
                                    xxnbty_ibi_events cc
                              WHERE     aa.stage_event_id = bb.stage_event_id
                                    AND bb.stage_event_id = cc.event_id
                                    AND aa.receipt_num = a.receipt_num
                                    AND bb.document_num = b.document_num
                                    AND bb.document_line_num = b.document_line_num
                                    AND bb.document_shipment_line_num =
                                           b.document_shipment_line_num
                                    AND bb.stage_process_flag IN ('E', 'U')
                                    AND aa.stage_process_flag IN ('E', 'U')
                                    AND cc.event_status IN ('E', 'U'))
            GROUP BY a.receipt_num,
                     b.document_num,
                     b.document_line_num,
                     document_shipment_line_num
              HAVING COUNT (a.receipt_num) > 1
            ORDER BY 2;
      BEGIN
         log_put_line ('Procedure ' || l_proc_name || '. Begin');

         FOR dup_rec IN dup_rec_cur                                              --1
         LOOP
            ln_success := 0;

            -- Finding if the receipt was processed successfully earlier.

            SELECT COUNT (cc.event_status)
              INTO ln_success
              FROM xxnbty_rcv_headers_stg aa,
                   xxnbty_rcv_transactions_stg bb,
                   xxnbty_ibi_events cc
             WHERE     aa.stage_event_id = bb.stage_event_id
                   AND bb.stage_event_id = cc.event_id
                   AND aa.receipt_num = dup_rec.receipt_num
                   AND bb.document_num = dup_rec.document_num
                   AND bb.document_line_num = dup_rec.document_line_num
                   AND bb.document_shipment_line_num =
                          dup_rec.document_shipment_line_num
                   AND bb.stage_process_flag = 'I'
                   AND aa.stage_process_flag = 'I'
                   AND cc.event_status = 'I';

            IF ln_success > 0
            THEN                                                        --ln_success

               --//Updating xxnbty_rcv_headers_stg for duplicate records
               UPDATE xxnbty_rcv_headers_stg
                  SET stage_process_flag = g_sts_ignore_constant,
                      stage_last_update_date = SYSDATE,
                      stage_last_updated_by = g_user_id,
                      stage_request_id = g_request_id
                WHERE receipt_num = dup_rec.receipt_num
                      AND stage_process_flag NOT IN ('I', 'G');


               --//Updating xxnbty_rcv_transactions_stg for duplicate records
               UPDATE xxnbty_rcv_transactions_stg
                  SET stage_process_flag = g_sts_ignore_constant,
                      attribute10 = 'Duplicate receipt (2nd val).', --AFLORES shortened the error message val - validation
                      stage_last_update_date = SYSDATE,
                      stage_last_updated_by = g_user_id,
                      stage_request_id = g_request_id
                WHERE document_num = dup_rec.document_num
                      AND document_line_num = dup_rec.document_line_num
                      AND document_shipment_line_num =
                             dup_rec.document_shipment_line_num
                      AND stage_event_id IN
                      			(SELECT stage_event_id
                      		          FROM xxnbty_rcv_headers_stg
                      		         WHERE     receipt_num = dup_rec.receipt_num)
                      AND stage_process_flag NOT IN ('I', 'G');


               --//Updating xxnbty_ibi_events for duplicate records
               UPDATE xxnbty_ibi_events
                  SET event_status = g_sts_ignore_constant,
                      last_update_date = SYSDATE,
                      last_updated_by = g_user_id,
                      request_id_feeder_program = g_request_id
                WHERE event_status NOT IN ('I', 'G')
                      AND event_id IN
                             (SELECT stage_event_id
                                FROM xxnbty_rcv_headers_stg
                               WHERE     receipt_num = dup_rec.receipt_num
                                     AND stage_process_flag = g_sts_ignore_constant
                                     AND stage_request_id = g_request_id);

            ELSIF ln_success = 0
            THEN    --All unprocessed records will be in U or E status. --ln_success

               --//Updating xxnbty_rcv_headers_stg for duplicate records
               UPDATE xxnbty_rcv_headers_stg
                  SET stage_process_flag = g_sts_ignore_constant,
                      stage_last_update_date = SYSDATE,
                      stage_last_updated_by = g_user_id,
                      stage_request_id = g_request_id
                WHERE     receipt_num = dup_rec.receipt_num
                      AND stage_event_id != dup_rec.max_stage_event_id
                      AND stage_process_flag NOT IN ('I', 'G');


               --//Updating xxnbty_rcv_transactions_stg for duplicate records
               UPDATE xxnbty_rcv_transactions_stg
                  SET stage_process_flag = g_sts_ignore_constant,
                      attribute10 = 'Duplicate receipt (3rd val).', --AFLORES shortened the error message val - validation
                      stage_last_update_date = SYSDATE,
                      stage_last_updated_by = g_user_id,
                      stage_request_id = g_request_id
                WHERE     stage_event_id != dup_rec.max_stage_event_id
                      AND document_num = dup_rec.document_num
                      AND document_line_num = dup_rec.document_line_num
                      AND document_shipment_line_num =
                             dup_rec.document_shipment_line_num
                      AND stage_event_id IN
                      			(SELECT stage_event_id
                      		          FROM xxnbty_rcv_headers_stg
                      		         WHERE     receipt_num = dup_rec.receipt_num)
                      AND stage_process_flag NOT IN ('I', 'G');

               --//Updating xxnbty_ibi_events for duplicate records
               UPDATE xxnbty_ibi_events
                  SET event_status = g_sts_ignore_constant,
                      last_update_date = SYSDATE,
                      last_updated_by = g_user_id,
                      request_id_feeder_program = g_request_id
                WHERE event_id != dup_rec.max_stage_event_id
                      AND event_status NOT IN ('I', 'G')
                      AND event_id IN
                             (SELECT stage_event_id
                                FROM xxnbty_rcv_headers_stg
                               WHERE     receipt_num = dup_rec.receipt_num
                                     AND stage_process_flag = g_sts_ignore_constant
                                     AND stage_request_id = g_request_id
                                     AND stage_event_id !=
                                            dup_rec.max_stage_event_id);
            END IF;                                                     --ln_success
         END LOOP;                                                               --1

         COMMIT;

         log_put_line ('Procedure ' || l_proc_name || '. End.');
      EXCEPTION
         WHEN OTHERS
         THEN
            l_log_msg :=
                  'Unexpected Error in Procedure '
               || l_proc_name
               || '. Err='
               || TO_CHAR (SQLCODE)
               || ' '
               || SQLERRM;
            log_put_line (l_log_msg);
            insert_error (g_event_id,
                          'ERROR',
                          l_proc_name,
                          l_log_msg);
END validate_duplicate_records2;


   --25-Feb-2015

/* This procedure will update/overide the item and category information (on XXNBTY_RCV_TRANSACTIONS_STG table) to the actual value as exists in Oracle PO line */

PROCEDURE update_trx_lines (p_group_id     IN     NUMBER,

                            p_error_flag   IN OUT VARCHAR2,

                            p_error_msg    IN OUT VARCHAR2)

IS

   l_proc_name    VARCHAR (100)

                     := 'XXNBTY_PO_RCV_IBI_FEEDER_PK.update_trx_lines';

   l_error_flag   VARCHAR2 (10);

   l_error_msg    VARCHAR2 (2000);

   l_log_msg      VARCHAR2 (500);



   lv_dest_type   VARCHAR2 (500);

   lv_item        VARCHAR2 (500);

   lv_category    VARCHAR2 (500);



   CURSOR ReceLine_C

   IS

      SELECT xrts.*, xrhs.stage_process_flag hdr_status

        FROM xxnbty_rcv_headers_stg xrhs, xxnbty_rcv_transactions_stg xrts

       WHERE     xrhs.stage_event_id = xrts.stage_event_id

             AND xrhs.stage_request_id = g_request_id

             AND xrhs.stage_group_id = p_group_id

             AND xrhs.stage_process_flag IN

                    (g_sts_vld_constant, g_sts_vldErr_constant)

             AND xrts.stage_process_flag NOT IN ('G', 'I');

BEGIN

   FOR ReceLine_REC IN ReceLine_C

   LOOP

      lv_dest_type := NULL;

      lv_item := NULL;

      lv_category := NULL;



      BEGIN

         SELECT DISTINCT

                destination_type_code,

                c.segment1,

                   d.segment1

                || '.'

                || d.segment2

                || '.'

                || d.segment3

                || '.'

                || d.segment4

           INTO lv_dest_type, lv_item, lv_category

           FROM po_headers_all a,

                po_lines_all b,

                mtl_system_items_b c,

                mtl_categories d,

                po_line_locations_all e,

                po_distributions_all f

          WHERE     a.po_header_id = b.po_header_id

                AND b.po_line_id = e.po_line_id

                AND e.po_line_id = f.po_line_id

                AND e.line_location_id = f.line_location_id

                AND b.item_id = c.inventory_item_id(+)

                AND c.organization_id(+) = 122

                AND b.category_id = d.category_id(+)

                AND a.segment1 = ReceLine_REC.document_num

                AND b.line_num = ReceLine_REC.document_line_num

                AND e.shipment_num = ReceLine_REC.document_shipment_line_num;

      EXCEPTION

         WHEN OTHERS

         THEN

            lv_dest_type := NULL;

            lv_item := NULL;

            lv_category := NULL;

      END;



      IF lv_dest_type IS NOT NULL and ReceLine_REC.transaction_type != 'CORRECT'

      THEN

         BEGIN

            UPDATE XXNBTY_RCV_TRANSACTIONS_STG

               SET destination_type_code = lv_dest_type,

                   legacy_item_num = lv_item,

                   item_num = lv_item,

                   item_category = lv_category

             WHERE     stage_event_id = ReceLine_REC.stage_event_id

                   AND document_num = ReceLine_REC.document_num

                   AND document_line_num = ReceLine_REC.document_line_num

                   AND document_shipment_line_num = ReceLine_REC.document_shipment_line_num;

         EXCEPTION

            WHEN OTHERS

            THEN

               NULL;

         END;

         ELSIF lv_dest_type IS NOT NULL and ReceLine_REC.transaction_type = 'CORRECT'

        THEN

         BEGIN

                 UPDATE XXNBTY_RCV_TRANSACTIONS_STG

                    SET item_category = lv_category,

                        legacy_item_num = lv_item,

                            item_num = lv_item

                  WHERE     stage_event_id = ReceLine_REC.stage_event_id

                        AND document_num = ReceLine_REC.document_num

                        AND document_line_num = ReceLine_REC.document_line_num

                        AND document_shipment_line_num = ReceLine_REC.document_shipment_line_num;

              EXCEPTION

                 WHEN OTHERS

                 THEN

                    NULL;

         END;



      END IF;

   END LOOP;



   COMMIT;

EXCEPTION

   WHEN OTHERS

   THEN

      l_log_msg :=

            'Unexpected Error in Procedure '

         || l_proc_name

         || '. Err='

         || TO_CHAR (SQLCODE)

         || ' '

         || SQLERRM;

      log_put_line (l_log_msg);

      insert_error (g_event_id,

                    'ERROR',

                    l_proc_name,

                    l_log_msg);

      p_error_msg :=

         p_error_msg || ' Unexpected Error in Procedure' || SQLERRM;

      p_error_flag := APPS.fnd_api.g_true;

END update_trx_lines;





/* This procedure will update the process attempts on event and header tables */

PROCEDURE reset_processing_count (p_error_flag   IN OUT VARCHAR2,

                                  p_error_msg    IN OUT VARCHAR2)

IS

   l_proc_name    VARCHAR (100)

                     := 'XXNBTY_PO_RCV_IBI_FEEDER_PK.reset_processing_count';

   l_error_flag   VARCHAR2 (10);

   l_error_msg    VARCHAR2 (2000);

   l_log_msg      VARCHAR2 (500);

 BEGIN



UPDATE xxnbty_rcv_headers_stg

   SET STAGE_PROCESS_ATTEMPTS = 1

 WHERE stage_event_id IN

          (SELECT event_id

             FROM xxnbty_ibi_events

            WHERE     event_type = 'RCV_IBI'

                  AND TRUNC (creation_date) >= '27-APR-2014'

                  AND event_status NOT IN ('I', 'G')

                  AND processed_attempts >= 98);



UPDATE xxnbty_ibi_events

   SET processed_attempts = 1

 WHERE event_id IN

          (SELECT event_id

             FROM xxnbty_ibi_events

            WHERE     event_type = 'RCV_IBI'

                  AND TRUNC (creation_date) >= '27-APR-2014'

                  AND event_status NOT IN ('I', 'G')

                  AND processed_attempts >= 98);



COMMIT;



 EXCEPTION

    WHEN OTHERS

    THEN

       l_log_msg :=

             'Unexpected Error in Procedure '

          || l_proc_name

          || '. Err='

          || TO_CHAR (SQLCODE)

          || ' '

          || SQLERRM;

       log_put_line (l_log_msg);

       insert_error (g_event_id,

                     'ERROR',

                     l_proc_name,

                     l_log_msg);

       p_error_msg :=

          p_error_msg || ' Unexpected Error in Procedure' || SQLERRM;

       p_error_flag := APPS.fnd_api.g_true;

END reset_processing_count;







   ----------------------------------------------------------------------

   /*



    Pocedure Name: main

    Author? name: Amit Kumar (NBTY ERP Implementation)

    Date written: 09-Nov-12

    RICEFW Object id: NBTY-PRC-I-013

    Description: This Procedure will call all procedure

    Program Style: Subordinate



    Maintenance History:



    Date Issue# Name Remarks

    ----------- -------- ---------------- ------------------------------------------

    09-Nov-12 Amit Kumar Initial development.



   */

   ----------------------------------------------------------------------



   PROCEDURE main_prc (x_errbuf          OUT VARCHAR2,

                       x_retcode         OUT VARCHAR2,

                       p_process      IN     VARCHAR2,

                       p_re_attempt   IN     NUMBER,

                       p_event_id     IN     NUMBER,

                       p_debug        IN     VARCHAR2 DEFAULT 'N')

   IS

      --Local Variables

      l_proc_name            VARCHAR (100) := 'XXNBTY_PO_RCV_IBI_FEEDER_PK.Main_prc';

      l_group_id             NUMBER;

      l_error_flag           VARCHAR2 (10);

      l_error_msg            VARCHAR2 (2000);

      l_receipt_request_id   NUMBER;

      l_return_status        VARCHAR2 (2000);

      l_msg_data             VARCHAR2 (2000);

      l_msg_count            NUMBER;

      l_line                 VARCHAR2 (255);

      l_log_msg              VARCHAR2 (500);

   BEGIN

      g_user_id := APPS.FND_GLOBAL.USER_ID;

      g_login_id := APPS.FND_GLOBAL.LOGIN_ID;

      g_resp_id := APPS.FND_GLOBAL.RESP_ID;

      g_resp_appl_id := APPS.FND_GLOBAL.RESP_APPL_ID;

      g_request_id := APPS.FND_GLOBAL.CONC_REQUEST_ID;

      g_org_id := APPS.FND_PROFILE.VALUE ('ORG_ID');

      g_debug_flag := p_debug;



      APPS.FND_GLOBAL.APPS_INITIALIZE (g_user_id, g_resp_id, g_resp_appl_id);

      log_put_line ('Procedure ' || l_proc_name || '. Begin');



      l_line := RPAD ('*', 70, '*');

      output_put_line (l_line);

      output_put_line (' Program :: NBTY Receipt Inbound Interface ');

      output_put_line (' Date :: ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY'));

      output_put_line (' Time :: ' || TO_CHAR (SYSDATE, 'HH:MI:SS AM'));

      output_put_line (' Request :: ' || g_request_id);

      output_put_line (' ');

      output_put_line ('**** Input Parameters ****');

      output_put_line (' Event ID :: ' || p_event_id);

      output_put_line (' Process :: ' || p_process);

      output_put_line (' Reprocess Attempts :: ' || p_re_attempt);

      output_put_line (' ');

      output_put_line (l_line);



      l_group_id := NULL;

      g_event_id := NVL (p_event_id, -1111);

      g_source_rec_id := g_event_id || SYSDATE;



      --// get the interface group sequence

      SELECT rcv_interface_groups_s.NEXTVAL INTO l_group_id FROM DUAL;



      --// Call validate Correspondent records avilable in staging tables

      --// mismatch records mark as 'E' and display in output file



      IF p_process = g_sts_new_constant
      THEN
         validate_stage_tables;
         output_put_line ('validate_stage_tables Sucess');
         validate_duplicate_records;                                --PRJ10456

      --      output_put_line('validate_duplicate_records Sucess');

      END IF;

      -- For duplicate receipt validation.
      validate_duplicate_records;
      validate_duplicate_records2;


      --// call header level validation and populate required value

      validate_rcv_hdr_data (p_group_id     => l_group_id,
                             p_proc_type    => p_process,
                             p_event_id     => p_event_id,
                             p_re_attempt   => p_re_attempt,
                             p_error_flag   => l_error_flag,
                             p_error_msg    => l_error_msg);

      --output_put_line('validate_rcv_hdr_data Sucess');
      --// update data in header staging table from PL/SQL table.



      upd_hdr_staging;

      --output_put_line('upd_hdr_staging Sucess');



      update_trx_lines(p_group_id     => l_group_id,

                             p_error_flag   => l_error_flag,

                             p_error_msg    => l_error_msg);


      --// call Trancation level validation and populate required value



      validate_rcv_trx_data (p_group_id     => l_group_id,

                             p_error_flag   => l_error_flag,

                             p_error_msg    => l_error_msg);


      --// update data in Transaction staging table from PL/SQL table.

      --output_put_line('validate_rcv_trx_data Sucess');

      upd_trx_staging;

      --output_put_line('upd_trx_staging Sucess');

      --// update status 'E' if any transaction line having error and

      --// increase count for attemts_count.
      upd_status_staging;
      --output_put_line('upd_status_staging Sucess');

	  --//Khristine Austero
/*
      validate_rcv_trx_unit_cost (p_group_id     => l_group_id,
                                  p_error_flag   => l_error_flag,
                                  p_error_msg    => l_error_msg);
*/
	  --//
      --// insert record in error table(XXNBTY_INT_ERRORS)

      IF g_err_rec_Table.COUNT > 0

      THEN

         log_put_line ('Start Calling Create_Error_Details_Tbl Procedure');

         xxnbty_int_errors_pk.create_error_details_tbl (

            p_Error_Tbl       => g_err_rec_Table,

            x_return_status   => l_return_status,

            x_msg_count       => l_msg_count,

            x_msg_data        => l_msg_data);

         log_put_line (' End of Calling Create_Error_Details_Tbl Procedure');

         g_err_rec_Table.delete;

         g_err_cnt := 0;

      END IF;



      --// Call summary report all validation records

      write_audit_report_output (p_error_type => 'VALIDATION');



      --// Load data in interface table



      load_receipt_data (p_group_id     => l_group_id,

                         p_error_flag   => l_error_flag,

                         p_error_msg    => l_error_msg);



      --// Submitt the request id for receipt it is independent on po request

      IF G_REC_HDR_Table.COUNT >= 1

      THEN

         log_put_line ('*************Start Submitt Receipt Progam*******');

         submit_receipt_request (p_group_id          => l_group_id,

                                 p_rept_request_id   => l_receipt_request_id,

                                 p_prog_status       => l_error_flag,

                                 p_err_msg           => l_error_msg);

         log_put_line ('Receipt Request ID' || l_receipt_request_id);

         log_put_line ('*************END Submitt Receipt Progam*******');

      END IF;



      --// Upadte status and attemsts in staging table



      inf_err_insert_log (l_group_id);



      --// Upadte status and attemsts in event table



      upd_event_tbl (l_group_id);



      --// insert record in error table(XXNBTY_INT_ERRORS)

      IF g_err_rec_Table.COUNT > 0

      THEN

         log_put_line ('Start Calling Create_Error_Details_Tbl Procedure');

         xxnbty_int_errors_pk.create_error_details_tbl (

            p_Error_Tbl       => g_err_rec_Table,

            x_return_status   => l_return_status,

            x_msg_count       => l_msg_count,

            x_msg_data        => l_msg_data);

         log_put_line (' End of Calling Create_Error_Details_Tbl Procedure');

         g_err_rec_Table.delete;

         g_err_cnt := 0;

      END IF;



      IF g_hdr_cnt = 1

      THEN

         l_log_msg := '*************No Record Processed*************';

         log_put_line (l_log_msg);

         insert_error (g_event_id,

                       'ERROR',

                       l_proc_name,

                       l_log_msg);

      END IF;



      --// Print output file



      write_audit_report_output (p_error_type => 'IMPORT');



      reset_processing_count(l_error_flag,

                            l_error_msg);



      COMMIT;



      x_retcode := g_retcode_err;



      log_put_line ('Procedure ' || l_proc_name || '. End.');

   EXCEPTION

      WHEN OTHERS

      THEN

         x_retcode := retcde_failure_constant;

         x_errbuf := SQLERRM;

         l_log_msg :=

               'Unexpected Error in Procedure '

            || l_proc_name

            || '. Err='

            || TO_CHAR (SQLCODE)

            || ' '

            || SQLERRM;

         log_put_line (l_log_msg);

         insert_error (g_event_id,

                       'ERROR',

                       l_proc_name,

                       l_log_msg);

   END main_prc;

END XXNBTY_PO_RCV_IBI_FEEDER_PK;

/

show errors;
