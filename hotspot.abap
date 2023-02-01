
report hotpost .


class class_report definition .

  public section .

    types:
      begin of ty_out,
        bp_id         type snwd_bpa-bp_id,
        company_name  type snwd_bpa-company_name,
        currency_code type snwd_bpa-currency_code,
        web_address   type snwd_bpa-web_address,
        email_address type snwd_bpa-email_address,
        country       type snwd_ad-country,
        city          type snwd_ad-city,
        postal_code   type snwd_ad-postal_code,
        street        type snwd_ad-street,
      end of ty_out,

      tab_out     type table of ty_out,
      range_bp_id type range of snwd_bpa-bp_id,
      tab_bpa     type table of snwd_bpa, " Address Table
      tab_ad      type table of snwd_ad . " Business Partners

    methods search_data
      importing
        !bp_id   type class_report=>range_bp_id
      changing
        !bpa_tab type class_report=>tab_bpa
        !ad_tab  type class_report=>tab_ad .

    methods process_data
      importing
        !bpa_tab type class_report=>tab_bpa
        !ad_tab  type class_report=>tab_ad .

    methods display_information .

  protected section .

  private section .

    data:
      out_tab type class_report=>tab_out .


    methods on_link_click
      for event link_click of
                cl_salv_events_table
      importing row column .


endclass .


class class_report implementation .

  method search_data .

    refresh:
      bpa_tab, ad_tab .

    if ( lines( bp_id ) eq 0 ) .
    else .

      select *
        into table bpa_tab
        from snwd_bpa
       where bp_id in bp_id .

      if ( sy-subrc eq 0 ) .

        select *
          into table ad_tab
          from snwd_ad
           for all entries in bpa_tab
         where node_key eq bpa_tab-address_guid .

        if ( sy-subrc eq 0 ) .
        endif .

      endif .

    endif .

  endmethod .


  method process_data .

    data:
      out_line type class_report=>ty_out .

    refresh out_tab .

    if ( lines( bpa_tab ) gt 0 ) and
       ( lines( ad_tab )  gt 0 ) .

      loop at bpa_tab into data(bpa_line) .

        out_line-bp_id         = bpa_line-bp_id .
        out_line-company_name  = bpa_line-company_name .
        out_line-currency_code = bpa_line-currency_code .
        out_line-web_address   = bpa_line-web_address .
        out_line-email_address = bpa_line-email_address .

        read table ad_tab into data(ad_line)
          with key node_key = bpa_line-address_guid .

        if ( sy-subrc eq 0 ) .

          out_line-country     = ad_line-country .
          out_line-city        = ad_line-city .
          out_line-postal_code = ad_line-postal_code .
          out_line-street      = ad_line-street .

          append out_line to out_tab .
          clear  out_line .

        endif .

      endloop .

    endif .

  endmethod .


  method display_information .

    data:
      salv_table type ref to cl_salv_table,
      columns    type ref to cl_salv_columns_table,
      column     type ref to cl_salv_column_table,
      lo_events  type ref to cl_salv_events_table,
      display    type ref to cl_salv_display_settings.


    if ( lines( out_tab ) eq 0 ) .
    else .

      try .

          cl_salv_table=>factory(
*           exporting
*             list_display = if_salv_c_bool_sap=>true
            importing
              r_salv_table = salv_table
            changing
              t_table      = out_tab
          ) .

          " Optimize column
          columns = salv_table->get_columns( ) .
          if ( columns is bound ) .
            columns->set_optimize( cl_salv_display_settings=>true ).

            " Set Hotpost
            try .
                column ?= columns->get_column( 'BP_ID' ) .
              catch cx_salv_not_found.
                return .
            endtry .
            column->set_cell_type( if_salv_c_cell_type=>hotspot ).
          endif .

          " Set the event
          lo_events = salv_table->get_event( ) .
          if ( lo_events is bound ) .
            set handler me->on_link_click for lo_events.
          endif .

          " Set Standard status gui
          salv_table->set_screen_status(
            pfstatus      = 'STANDARD_FULLSCREEN'
            report        = 'SAPLKKBL'
            set_functions = salv_table->c_functions_all ) .

          " Zebra
          display = salv_table->get_display_settings( ) .
          if ( display is bound ) .
            display->set_striped_pattern( cl_salv_display_settings=>true ) .
          endif .

          salv_table->display( ).

        catch cx_salv_msg .
        catch cx_salv_not_found .
        catch cx_salv_existing .
        catch cx_salv_data_error .
        catch cx_salv_object_not_found .

      endtry.

    endif .


  endmethod .


  method on_link_click .

    if ( row eq 0 ) .
      return .
    endif .

    if ( column eq 'BP_ID' ) .
      data(bp_id) = value #( me->out_tab[ row ]-bp_id optional ) .
      if ( bp_id is not initial ) .
        " set parameter id 'MAT' field bp_id .
        " call transaction 'MM03' and skip first screen.
        " break-point .
      endif .

    endif .

  endmethod .

endclass .

*----------------------------------------------------------------------
*- Events
*----------------------------------------------------------------------
initialization .


  data:
    gt_filter    type class_report=>range_bp_id,
    go_alv       type ref to class_report,
    gt_bpa_table type class_report=>tab_bpa,
    gt_ad_table  type class_report=>tab_ad,
    gt_out_table type class_report=>tab_out.

* Essa opcao pode/deve ser substituida por um parametro de selecao
  gt_filter =
    value #(
     ( sign = 'I' option = 'EQ' low = '0100000000' )
     ( sign = 'I' option = 'EQ' low = '0100000001' )
     ( sign = 'I' option = 'EQ' low = '0100000002' )
     ( sign = 'I' option = 'EQ' low = '0100000003' )
     ( sign = 'I' option = 'EQ' low = '0100000004' )
     ( sign = 'I' option = 'EQ' low = '0100000005' )
    ) .


  go_alv = new class_report( ) .

  if ( go_alv is bound ) .

    go_alv->search_data(
      exporting
        bp_id   = gt_filter
      changing
        bpa_tab = gt_bpa_table
        ad_tab  = gt_ad_table
    ).

    go_alv->process_data(
      exporting
        bpa_tab = gt_bpa_table
        ad_tab  = gt_ad_table
    ).

    go_alv->display_information( ).

  endif .



*TYPES : BEGIN OF ty_int,
*          field1 TYPE i,
*          field2 TYPE i,
*          field3 TYPE i,
*        END OF ty_int.
*
*TYPES : tt_int TYPE STANDARD TABLE OF ty_int WITH DEFAULT KEY.
*
*DATA : wa_for TYPE ty_int.
*DATA : wa_for_old TYPE ty_int.
*DATA : itab_for_old TYPE tt_int.
*
**DATA(itab_for) = VALUE tt_int_deep( ( field1 = 10 field2 = 20 field3 = 30  )
*DATA(itab_for) = VALUE tt_int( ( field1 = 10 field2 = 20 field3 = 30  )
*                                     ( field1 = 100 field2 = 200 field3 = 300 )
*                                     ( field1 = 1000 field2 = 2000 field3 = 3000 )
*                                     ( field1 = 1000 field2 = 3000  field3 = 5000 )
*                                     ( field1 = 1000 field2 = 5000  field3 = 6000 )
*                                      ).
*****Old Syntax
*
*DATA : lv_x TYPE i VALUE 3.
*
*LOOP AT itab_for INTO wa_for.
*
*  wa_for_old-field1 = wa_for-field1.
*  wa_for_old-field2 = wa_for-field2 * 10.
*  wa_for_old-field3 = wa_for-field3 * lv_x.
*
*  APPEND wa_for_old TO itab_for_old.
*  CLEAR : wa_for_old.
*
*ENDLOOP.
*
**** New Syntax - For...Let
*DATA(itab_for_new) = VALUE tt_int( FOR <lfs_index3> IN itab_for
*                                       LET x = 3
**                                       IN field3 = <lfs_index3>-field3 * x
*                                        IN field3 = x
*                                      (
*                                        field1 = <lfs_index3>-field1
*                                        field2 = <lfs_index3>-field2 * 10
*                                       )
*        ).

  break-point .
        !bp_id   type class_report=>range_bp_id
      changing
        !bpa_tab type class_report=>tab_bpa
        !ad_tab  type class_report=>tab_ad .

    methods process_data
      importing
        !bpa_tab type class_report=>tab_bpa
        !ad_tab  type class_report=>tab_ad
      changing
        !out_tab type class_report=>tab_out .

    methods display_information
      changing
        !out_tab type class_report=>tab_out .

  protected section .

  private section .

endclass .


class class_report implementation .

  method search_data .

    refresh:
      bpa_tab, ad_tab .

    if ( lines( bp_id ) eq 0 ) .
    else .

      select *
        into table bpa_tab
        from snwd_bpa
       where bp_id in bp_id .

      if ( sy-subrc eq 0 ) .

        select *
          into table ad_tab
          from snwd_ad
           for all entries in bpa_tab
         where node_key eq bpa_tab-address_guid .

        if ( sy-subrc eq 0 ) .
        endif .

      endif .

    endif .

  endmethod .


  method process_data .

    data:
      out_line type class_report=>ty_out .

    refresh out_tab .

    if ( lines( bpa_tab ) gt 0 ) and
       ( lines( ad_tab )  gt 0 ) .

      loop at bpa_tab into data(bpa_line) .

        out_line-bp_id         = bpa_line-bp_id .
        out_line-company_name  = bpa_line-company_name .
        out_line-currency_code = bpa_line-currency_code .
        out_line-web_address   = bpa_line-web_address .
        out_line-email_address = bpa_line-email_address .

        read table ad_tab into data(ad_line)
          with key node_key = bpa_line-address_guid .

        if ( sy-subrc eq 0 ) .

          out_line-country     = ad_line-country .
          out_line-city        = ad_line-city .
          out_line-postal_code = ad_line-postal_code .
          out_line-street      = ad_line-street .

          append out_line to out_tab .
          clear  out_line .

        endif .

      endloop .

    endif .

  endmethod .


  method display_information .

    data:
      salv_table type ref to cl_salv_table,
      columns    type ref to cl_salv_columns_table,
      column     type ref to cl_salv_column_table,
      display    type ref to cl_salv_display_settings.


    if ( lines( out_tab ) eq 0 ) .
    else .

      try .

          cl_salv_table=>factory(
*           exporting
*             list_display = if_salv_c_bool_sap=>true
            importing
              r_salv_table = salv_table
            changing
              t_table      = out_tab
          ) .

          " Optimize column
          columns = salv_table->get_columns( ) .
          if ( columns is bound ) .
            columns->set_optimize( cl_salv_display_settings=>true ).

            " Set Hotpost
            try .
                column ?= columns->get_column( 'BP_ID' ) .
              catch cx_salv_not_found.
                return .
            endtry .
            column->set_cell_type( if_salv_c_cell_type=>hotspot ).

          endif .


          " Set Standard status gui
          salv_table->set_screen_status(
            pfstatus      = 'STANDARD_FULLSCREEN'
            report        = 'SAPLKKBL'
            set_functions = salv_table->c_functions_all ) .

          " Zebra
          display = salv_table->get_display_settings( ) .
          if ( display is bound ) .
            display->set_striped_pattern( cl_salv_display_settings=>true ) .
          endif .

          salv_table->display( ).

        catch cx_salv_msg .
        catch cx_salv_not_found .
        catch cx_salv_existing .
        catch cx_salv_data_error .
        catch cx_salv_object_not_found .

      endtry.

    endif .


  endmethod .


endclass .

*----------------------------------------------------------------------
*- Events
*----------------------------------------------------------------------
initialization .


  data:
    gt_filter    type class_report=>range_bp_id,
    go_alv       type ref to class_report,
    gt_bpa_table type class_report=>tab_bpa,
    gt_ad_table  type class_report=>tab_ad,
    gt_out_table type class_report=>tab_out.

* Essa opcao pode/deve ser substituida por um parametro de selecao
  gt_filter =
    value #(
     ( sign = 'I' option = 'EQ' low = '0100000000' )
     ( sign = 'I' option = 'EQ' low = '0100000001' )
     ( sign = 'I' option = 'EQ' low = '0100000002' )
     ( sign = 'I' option = 'EQ' low = '0100000003' )
     ( sign = 'I' option = 'EQ' low = '0100000004' )
     ( sign = 'I' option = 'EQ' low = '0100000005' )
    ) .


  go_alv = new class_report( ) .

  if ( go_alv is bound ) .

    go_alv->search_data(
      exporting
        bp_id   = gt_filter
      changing
        bpa_tab = gt_bpa_table
        ad_tab  = gt_ad_table
    ).

    go_alv->process_data(
      exporting
        bpa_tab = gt_bpa_table
        ad_tab  = gt_ad_table
      changing
        out_tab = gt_out_table
    ).

    go_alv->display_information(
      changing
        out_tab = gt_out_table
    ).

  endif .

