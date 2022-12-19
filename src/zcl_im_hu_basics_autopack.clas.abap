class ZCL_IM_HU_BASICS_AUTOPACK definition
  public
  final
  create public .

public section.

  interfaces /SCWM/IF_EX_HU_BASICS_AUTOPACK .
  interfaces IF_BADI_INTERFACE .
protected section.
private section.

  class-data ST_TUOM_QCLA type /SCWM/TT_UOM_QCLA .
ENDCLASS.



CLASS ZCL_IM_HU_BASICS_AUTOPACK IMPLEMENTATION.


  method /SCWM/IF_EX_HU_BASICS_AUTOPACK~HU_PACKSPEC_VALIDATE.
  endmethod.


  METHOD /scwm/if_ex_hu_basics_autopack~hu_proposal.

    DATA: lt_mat_uom TYPE /scwm/tt_material_uom,
          lv_quancla TYPE /scwm/de_quancla.

    BREAK-POINT ID zewmdevbook_1fsa.
    DATA(lo_pack)  = CAST /scwm/cl_hu_packing( io_pack_ref ).
    DATA(lo_stock) = NEW /scwm/cl_ui_stock_fields( ).
* 1 get quantity classification (prefetch)
    IF st_tuom_qcla IS INITIAL.
      SELECT * FROM /scwm/tuom_qcla
               INTO TABLE st_tuom_qcla
               WHERE lgnum = lo_pack->gv_lgnum.
      IF st_tuom_qcla IS INITIAL.
        RETURN.
      ENDIF.
    ENDIF.

    LOOP AT ct_pack ASSIGNING FIELD-SYMBOL(<pack>).
      CLEAR: lt_mat_uom.
*2 get product master for each delivery-item
      TRY.
          CALL FUNCTION '/SCWM/MATERIAL_READ_SINGLE'
            EXPORTING
              iv_matid   = <pack>-matid
            IMPORTING
*             es_mat_global = ls_mat_global
              et_mat_uom = lt_mat_uom.
        CATCH /scwm/cx_md.
          io_pack_ref->go_log->add_message( ).
          cv_severity = sy-msgty.
          CONTINUE.
      ENDTRY.
      WHILE <pack>-quan > 0.
*3 get quantity classification based on open quantity
        TRY.
            CALL FUNCTION '/SCWM/QUANCLA_DET_UOM'
              EXPORTING
                iv_lgnum   = lo_pack->gv_lgnum
                iv_matid   = <pack>-matid
                iv_batchid = <pack>-batchid
                iv_quan    = <pack>-quan
                iv_unit    = <pack>-unit
                it_mat_uom = lt_mat_uom
              IMPORTING
                ev_quancla = lv_quancla.
          CATCH /scwm/cx_core.
            io_pack_ref->go_log->add_message( ).
            cv_severity = sy-msgty.
            CONTINUE.
        ENDTRY.
*4 determine packmat and hu_typ for the quancla
        SELECT SINGLE * FROM zhu_pmat
          INTO @DATA(ls_zhu_pmat)
          WHERE lgnum = @lo_pack->gv_lgnum
          AND quancla = @lv_quancla.
        IF ls_zhu_pmat-packmat IS INITIAL.
*error: No Packaging Material maintained for Quan.Class. &1.
          MESSAGE e001(zewmdevbook_1fsa) WITH lv_quancla.
          io_pack_ref->go_log->add_message( ).
          EXIT.
        ENDIF.
        DATA(lv_packmatid) = lo_stock->get_matid_by_no(
                             iv_matnr = ls_zhu_pmat-packmat ).
*5 determine target quantity and UoM
        LOOP AT st_tuom_qcla INTO DATA(ls_quancla) WHERE quancla = lv_quancla.
          DATA(ls_mat_uom) = VALUE #( lt_mat_uom[ matid = <pack>-matid
                                                  meinh = ls_quancla-unit ] ).
          IF sy-subrc IS NOT INITIAL.
            EXIT.
          ENDIF.
        ENDLOOP.
*6 create new hu
        DATA(ls_hu_crea) = VALUE /scwm/s_huhdr_create_ext(
          hutyp = ls_zhu_pmat-hutyp ).
        DATA(ls_huhdr) = io_pack_ref->create_hu(
          EXPORTING
            iv_pmat      = lv_packmatid
            is_hu_create = ls_hu_crea ).
        IF sy-subrc <> 0.
          io_pack_ref->go_log->add_message( ).
          EXIT.
        ENDIF.
*7 pack item
        DATA(ls_quan) = CORRESPONDING /scwm/s_quan( <pack> ).
        IF <pack>-quan >= ls_mat_uom-umrez.
          ls_quan-quan = 1.
          ls_quan-unit = ls_mat_uom-meinh.
          <pack>-quan  = <pack>-quan - ls_mat_uom-umrez.
        ELSE.
          ls_quan-quan = <pack>-quan.
          <pack>-quan = 0.
        ENDIF.
        DATA(ls_mat) = CORRESPONDING /scwm/s_pack_stock( <pack> ).
        io_pack_ref->pack_stock(
          EXPORTING
            iv_dest_hu  = ls_huhdr-guid_hu
            is_material = ls_mat
            is_quantity = ls_quan ).
        IF sy-subrc <> 0.
          io_pack_ref->go_log->add_message( ).
          EXIT.
        ENDIF.
        CLEAR: ls_mat, ls_quan, ls_hu_crea, lv_quancla,
               ls_huhdr, ls_quancla, ls_mat_uom, ls_zhu_pmat.
      ENDWHILE.
    ENDLOOP.

  ENDMETHOD.
ENDCLASS.
