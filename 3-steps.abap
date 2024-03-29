REPORT YTEST01.

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
