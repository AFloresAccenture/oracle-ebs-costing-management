create or replace PACKAGE XXNBTY_CONV01_ICOST_CONV_PKG AS
 ---------------------------------------------------------------------------------------------
  /*
  Package Name  : XXNBTY_CONV01_ICOST_CONV_PKG
  Author's Name: Khristine Austero
  Date written: 25-Feb-2016
  RICEFW Object: CNV01
  Description: This package will validate records from the flat file and will create records in the
             OPM financials and Cost Management using Import program and API
  Program Style:
  Maintenance History:
  Date         Issue#  Name                         Remarks
  -----------  ------  -------------------      ------------------------------------------------
  25-Feb-2016          Khristine Austero        Initial Development
  04-May-2016          Khristine Austero        Add Procedure process_cm_to_opm_by_element,
                                                cm_to_opm_by_element_main

  */
  ----------------------------------------------------------------------------------------------
    g_created_by            NUMBER(15)              := fnd_global.user_id;
    g_last_updated_by       NUMBER(15)              := fnd_global.user_id;
    g_last_update_login     NUMBER(15)              := fnd_global.login_id;
    g_request_id            NUMBER(15)              := fnd_global.conc_request_id;
    g_resp_appl_id          NUMBER(15)              := fnd_global.resp_appl_id;
    g_resp_id               NUMBER(15)              := fnd_global.resp_id;
    g_user_id               NUMBER(15)              := fnd_global.user_id;
    g_user_name             VARCHAR2(20)            := fnd_global.user_name;
    g_rec_stat_n            CONSTANT VARCHAR2(10)   := 'NEW';
    g_rec_stat_e            CONSTANT VARCHAR2(10)   := 'ERROR';
    g_rec_stat_i            CONSTANT VARCHAR2(10)   := 'IMPORTED';
    g_rec_stat_v            CONSTANT VARCHAR2(10)   := 'VALID';
    g_rec_stat_p            CONSTANT VARCHAR2(10)   := 'PROCESSED';
    g_rec_stat_d            CONSTANT VARCHAR2(10)   := 'DUPLICATE';
    g_source_ebs            CONSTANT VARCHAR2(10)   := 'EBS';
    g_source_as             CONSTANT VARCHAR2(10)   := 'AS400';
    g_res_oh                CONSTANT VARCHAR2(10)   := 'RES_OH';
    g_res_cost              CONSTANT VARCHAR2(10)   := 'RES_COST';
    g_mat_rmw               CONSTANT VARCHAR2(10)   := 'RMW';
    g_fg_mtl                CONSTANT VARCHAR2(10)   := 'FG_MTL';
    g_con_res               CONSTANT VARCHAR2(10)   := 'CON_RES';
    g_yield_res             CONSTANT VARCHAR2(10)   := 'YIELD_RES';
    g_item                  CONSTANT VARCHAR2(10)   := 'Item';
    g_mat_oh                CONSTANT VARCHAR2(10)   := 'MAT_OH';
    g_error                 VARCHAR2(500)           := '';
    g_retcode               NUMBER                  := 0;

    PROCEDURE validate_opm_rec      ( x_errbuf      OUT VARCHAR2,
                                    x_retcode       OUT VARCHAR2);

    PROCEDURE validate_cm_rec       ( x_errbuf      OUT VARCHAR2,
                                    x_retcode       OUT VARCHAR2,
                                    p_request_id    IN VARCHAR2);

    PROCEDURE process_opm_records   ( x_errbuf      OUT VARCHAR2,
                                    x_retcode       OUT VARCHAR2);

    PROCEDURE process_cm_records    ( x_errbuf      OUT VARCHAR2,
                                    x_retcode       OUT VARCHAR2,
                                    p_request_id    IN VARCHAR2);

    PROCEDURE process_cm_to_opm_by_element  ( x_errbuf      OUT VARCHAR2,
                                              x_retcode       OUT VARCHAR2,
                                              p_org            IN VARCHAR2,
                                              p_item           IN VARCHAR2,
                                              p_request_id    IN VARCHAR2
                                             );
    PROCEDURE copy_opm_to_cmstg     ( x_errbuf      OUT VARCHAR2,
                                    x_retcode       OUT VARCHAR2);

    PROCEDURE process_opm_to_cm     ( x_errbuf      OUT VARCHAR2,
                                    x_retcode       OUT VARCHAR2);

    PROCEDURE copy_cm_to_opmstg     ( x_errbuf      OUT VARCHAR2,
                                    x_retcode       OUT VARCHAR2,
                                    p_request_id    IN VARCHAR2);

    PROCEDURE process_cm_to_opm     ( x_errbuf      OUT VARCHAR2,
                                    x_retcode       OUT VARCHAR2
                                    );

    PROCEDURE call_import_process   ( x_errbuf      OUT VARCHAR2,
                                    x_retcode       OUT VARCHAR2
                                    );

    PROCEDURE cm_main               ( x_errbuf          OUT VARCHAR2,
                                    x_retcode           OUT VARCHAR2,
                                    p_filename          IN VARCHAR2,
                                    p_sourcedirectory   IN VARCHAR2,
                                    p_archive           IN VARCHAR2
                                    );

    PROCEDURE opm_main              ( x_errbuf          OUT VARCHAR2,
                                    x_retcode           OUT VARCHAR2,
                                    p_filename          IN VARCHAR2,
                                    p_sourcedirectory   IN VARCHAR2,
                                    p_archive           IN VARCHAR2
                                    );

    PROCEDURE opm_to_cm_main        ( x_errbuf      OUT VARCHAR2,
                                    x_retcode       OUT VARCHAR2
                                    );

    PROCEDURE cm_to_opm_main        ( x_errbuf      OUT VARCHAR2,
                                    x_retcode       OUT VARCHAR2
                                    );

    PROCEDURE cm_to_opm_by_element_main( x_errbuf        OUT VARCHAR2,
                                         x_retcode       OUT VARCHAR2,
                                         p_org            IN VARCHAR2,
                                         p_item           IN VARCHAR2
                                         );

END XXNBTY_CONV01_ICOST_CONV_PKG;

/

show errors;
