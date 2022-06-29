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

    DATA:
      lo_pack       TYPE REF TO /scwm/cl_hu_packing,
*      lv_string     TYPE string,                            "#EC NEEDED
      ls_mat_global TYPE /scwm/s_material_global,
      lt_mat_uom    TYPE /scwm/tt_material_uom,
      ls_mat_uom    TYPE /scwm/s_material_uom,
      ls_mat        TYPE /scwm/s_pack_stock,
      ls_quan       TYPE /scwm/s_quan,
      lt_matnr      TYPE /scmb/mdl_matnr_tab.

    BREAK-POINT ID zewmdevbook_432.
    lo_pack ?= io_pack_ref.
    DATA(lo_stock) = NEW /scwm/cl_ui_stock_fields( ).
* 1 get HU-types & packaging materials (prefetch)
    SELECT * FROM zhu_pmat
    INTO TABLE @DATA(lt_hutyp)
    WHERE lgnum = @lo_pack->gv_lgnum.
    IF lt_hutyp IS INITIAL.
      RETURN.
    ENDIF.
    LOOP AT lt_hutyp ASSIGNING FIELD-SYMBOL(<hutyp>).
      APPEND <hutyp>-packmat TO lt_matnr.
    ENDLOOP.
    lo_stock->prefetch_matid_by_no( EXPORTING it_matnr       = lt_matnr
                                    IMPORTING et_matid_matnr = DATA(lt_packmat) ).
    SORT lt_packmat BY matnr.
    LOOP AT ct_pack ASSIGNING FIELD-SYMBOL(<pack>).
      CLEAR: ls_mat_global, lt_mat_uom.
*2 get product master for each delivery-item
      TRY.
          CALL FUNCTION '/SCWM/MATERIAL_READ_SINGLE'
            EXPORTING
              iv_matid      = <pack>-matid
            IMPORTING
              es_mat_global = ls_mat_global
              et_mat_uom    = lt_mat_uom.
        CATCH /scwm/cx_md.
          io_pack_ref->go_log->add_message( ).
          cv_severity = sy-msgty.
          CONTINUE.
      ENDTRY.
*3 determine packmat for default HU-type
*     READ TABLE lt_hutyp WITH KEY lgnum = lo_pack->gv_lgnum
*                                  hutyp = ls_mat_global-hutyp_dflt
*     ASSIGNING <hutyp>.
      <hutyp> = VALUE #( lt_hutyp[ lgnum = lo_pack->gv_lgnum
                                   hutyp = ls_mat_global-hutyp_dflt ] ).
      IF sy-subrc IS NOT INITIAL.
*error: No Packaging Material maintained for HU-Type &1
        MESSAGE e001(zewmdevbook_432) WITH ls_mat_global-hutyp_dflt. "INTO lv_string.
        io_pack_ref->go_log->add_message( ).
        CONTINUE.
      ENDIF.
      READ TABLE lt_packmat
      ASSIGNING FIELD-SYMBOL(<packmat>) WITH KEY
      matnr = <hutyp>-packmat
      BINARY SEARCH.
      IF sy-subrc IS NOT INITIAL.
*error: Packaging Material &1 not found
        MESSAGE e002(zewmdevbook_432) WITH <hutyp>-packmat.
*        INTO lv_string.
        io_pack_ref->go_log->add_message( ).
        CONTINUE.
      ENDIF.
*4 get target quantity for the biggest UOM
      SORT lt_mat_uom BY umrez DESCENDING.
      READ TABLE lt_mat_uom INTO ls_mat_uom INDEX 1.
      IF ls_mat_uom-umrez = 1. "base UOM only
*error: No alternative UOM found for product &1
        MESSAGE e003(zewmdevbook_432) WITH ls_mat_global-matnr. "INTO lv_string.
        io_pack_ref->go_log->add_message( ).
        CONTINUE.
      ENDIF.
      WHILE <pack>-quan > 0.
        CLEAR: ls_quan.
*5 create new hu
        DATA(ls_hu_crea) = VALUE /scwm/s_huhdr_create_ext( hutyp = <hutyp>-hutyp ).
        DATA(ls_huhdr) = io_pack_ref->create_hu(
          EXPORTING
            iv_pmat      = <packmat>-matid
            is_hu_create = ls_hu_crea ).
*          RECEIVING
*            es_huhdr     = ls_huhdr
*          EXCEPTIONS
*            OTHERS       = 99 ).
        IF sy-subrc <> 0.
          io_pack_ref->go_log->add_message( ).
          EXIT.
        ENDIF.
*6 pack item
        ls_quan = CORRESPONDING #( BASE ( ls_quan ) <pack> ).
        IF <pack>-quan >= ls_mat_uom-umrez.
          ls_quan-quan = 1.
          ls_quan-unit = ls_mat_uom-meinh.
          <pack>-quan  = <pack>-quan - ls_mat_uom-umrez.
        ELSE.
          ls_quan-quan = <pack>-quan.
          <pack>-quan = 0.
        ENDIF.
*        MOVE-CORRESPONDING <pack> TO ls_mat.
        ls_mat = CORRESPONDING #( BASE ( ls_mat ) <pack> ).
        io_pack_ref->pack_stock(
          EXPORTING
            iv_dest_hu  = ls_huhdr-guid_hu
            is_material = ls_mat
            is_quantity = ls_quan
          EXCEPTIONS
            OTHERS      = 99 ).
        IF sy-subrc <> 0.
          io_pack_ref->go_log->add_message( ).
          EXIT.
        ENDIF.
      ENDWHILE.
    ENDLOOP.

  ENDMETHOD.
ENDCLASS.
