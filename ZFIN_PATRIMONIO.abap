*&---------------------------------------------------------------------*
*& Report ZFIN_PATRIMONIO
*&---------------------------------------------------------------------*
*& Patrimonio actual de una sociedad FI: valor libros vs. valor mercado
*&
*& DESCRIPCION
*&   Lee saldos acumulados de cuentas de balance (activo y pasivo) desde
*&   FAGLFLEXT (New GL, ledger 0L) a una fecha clave y los muestra en ALV:
*&   - Cuentas en ARS : valor mercado = valor libros.
*&                      Equivalente USD al tipo VENTA (P_KURSV), es decir
*&                      los dolares que se obtendrian comprando con esos
*&                      pesos.
*&   - Cuentas en USD : valor mercado ARS = saldo USD x tipo COMPRA
*&                      (P_KURST), es decir los pesos que se obtendrian
*&                      vendiendo esos dolares. Equivalente USD = saldo.
*&   Encabezado con patrimonio neto a libros, a mercado, equivalente USD
*&   y la diferencia libros/mercado (ajuste de valuacion no contabilizado).
*&
*& COMPATIBILIDAD
*&   SAP ECC 6.0 (probado en EHP6, SAP_BASIS 731). Sin sintaxis 7.40+,
*&   sin ACDOCA. No apto para S/4HANA sin adaptar (FAGLFLEXT -> ACDOCA).
*&
*& REQUISITOS / DEPENDENCIAS
*&   1. New General Ledger activo (FAGLFLEXT, ledger lider 0L).
*&   2. Moneda local de la sociedad: ARS. Cuentas en moneda extranjera
*&      USD definidas con moneda de cuenta USD en el maestro (SKB1-WAERS).
*&   3. Tipos de cambio USD/ARS cargados en OB08 (tabla TCURR) para la
*&      fecha clave:
*&        G = compra (default de P_KURST)
*&        B = venta  (default de P_KURSV)
*&      Si los tipos G/B no existen, crear tambien factores en TCURF.
*&   4. Textos de cuenta (SKAT) en el idioma de logon.
*&   5. Rangos de cuentas usados para agrupar (ajustar a su plan):
*&        110000-119999 Caja         120000-129999 Bancos
*&        130000-139999 Billeteras   140000-149999 Brokers
*&        150000-159999 Inversiones  200000-299999 Pasivo
*&      Solo se leen cuentas 100000-299999 (balance).
*&
*& INSTALACION MANUAL (si no se usa abapGit)
*&   1. SE38: crear programa ejecutable ZFIN_PATRIMONIO y pegar codigo.
*&   2. Textos de seleccion (Goto > Text elements > Selection texts):
*&        P_BUKRS  Sociedad
*&        P_FECHA  Fecha clave
*&        P_KURST  Tipo cambio compra (USD->ARS)
*&        P_KURSV  Tipo cambio venta (ARS->USD)
*&   3. SE93 (opcional): transaccion de reporte ZFIN_PATRIMONIO,
*&      programa ZFIN_PATRIMONIO, pantalla de seleccion 1000.
*&
*& NOTAS
*&   - Solo lectura: no contabiliza ni modifica datos.
*&   - El programa no contiene saldos ni datos personales; todo se lee
*&     del sistema en tiempo de ejecucion.
*&---------------------------------------------------------------------*
REPORT zfin_patrimonio.

TYPES: BEGIN OF ty_out,
         grupo   TYPE char20,
         racct   TYPE racct,
         txt50   TYPE txt50_skat,
         waers   TYPE waers,
         sal_mon TYPE p LENGTH 15 DECIMALS 2,
         ars_lib TYPE p LENGTH 15 DECIMALS 2,
         ars_mer TYPE p LENGTH 15 DECIMALS 2,
         usd_eq  TYPE p LENGTH 15 DECIMALS 2,
         porc    TYPE p LENGTH 7  DECIMALS 2,
       END OF ty_out.

DATA: gt_out    TYPE STANDARD TABLE OF ty_out,
      gs_out    TYPE ty_out,
      gt_flext  TYPE STANDARD TABLE OF faglflext,
      gs_flext  TYPE faglflext,
      gv_gjahr  TYPE gjahr,
      gv_poper  TYPE poper,
      gv_ktopl  TYPE ktopl,
      gv_rate_c TYPE p LENGTH 15 DECIMALS 5,   "ARS por 1 USD - compra
      gv_rate_v TYPE p LENGTH 15 DECIMALS 5,   "ARS por 1 USD - venta
      gv_pn_lib TYPE p LENGTH 15 DECIMALS 2,
      gv_pn_mer TYPE p LENGTH 15 DECIMALS 2,
      gv_pn_usd TYPE p LENGTH 15 DECIMALS 2,
      gv_dif    TYPE p LENGTH 15 DECIMALS 2.

PARAMETERS: p_bukrs TYPE bukrs      DEFAULT 'Z100' OBLIGATORY,
            p_fecha TYPE sy-datum   DEFAULT sy-datum OBLIGATORY,
            p_kurst TYPE kurst_curr DEFAULT 'G' OBLIGATORY,
            p_kursv TYPE kurst_curr DEFAULT 'B' OBLIGATORY.

START-OF-SELECTION.
  PERFORM get_periodo.
  PERFORM get_tipo_cambio USING p_kurst CHANGING gv_rate_c.
  PERFORM get_tipo_cambio USING p_kursv CHANGING gv_rate_v.
  PERFORM get_saldos.
  PERFORM calc_porcentajes.
  PERFORM mostrar_alv.

*&---------------------------------------------------------------------*
*& Determina ejercicio/periodo de la fecha clave y plan de cuentas
*&---------------------------------------------------------------------*
FORM get_periodo.
  DATA lv_periv TYPE periv.
  SELECT SINGLE periv ktopl FROM t001 INTO (lv_periv, gv_ktopl)
    WHERE bukrs = p_bukrs.
  IF sy-subrc <> 0.
    MESSAGE 'Sociedad inexistente' TYPE 'E'.
  ENDIF.
  CALL FUNCTION 'DATE_TO_PERIOD_CONVERT'
    EXPORTING
      i_date  = p_fecha
      i_periv = lv_periv
    IMPORTING
      e_buper = gv_poper
      e_gjahr = gv_gjahr
    EXCEPTIONS
      OTHERS  = 1.
  IF sy-subrc <> 0.
    MESSAGE 'No se pudo determinar el periodo contable' TYPE 'E'.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& Devuelve ARS por 1 USD para el tipo indicado (factores aplicados)
*&---------------------------------------------------------------------*
FORM get_tipo_cambio USING    iv_kurst TYPE kurst_curr
                     CHANGING cv_rate  TYPE p.
  DATA: lv_rate  TYPE ukurs_curr,
        lv_ffact TYPE ffact_curr,
        lv_lfact TYPE tfact_curr.
  CALL FUNCTION 'READ_EXCHANGE_RATE'
    EXPORTING
      date             = p_fecha
      foreign_currency = 'USD'
      local_currency   = 'ARS'
      type_of_rate     = iv_kurst
    IMPORTING
      exchange_rate    = lv_rate
      foreign_factor   = lv_ffact
      local_factor     = lv_lfact
    EXCEPTIONS
      OTHERS           = 1.
  IF sy-subrc <> 0 OR lv_rate IS INITIAL.
    MESSAGE e398(00) WITH 'No hay tipo de cambio USD/ARS tipo' iv_kurst.
  ENDIF.
  IF lv_ffact IS INITIAL. lv_ffact = 1. ENDIF.
  IF lv_lfact IS INITIAL. lv_lfact = 1. ENDIF.
  cv_rate = lv_rate * lv_lfact / lv_ffact.
ENDFORM.

*&---------------------------------------------------------------------*
*& Acumula saldos de balance (arrastre + periodos 1..N) y valoriza
*&---------------------------------------------------------------------*
FORM get_saldos.
  DATA: lv_fname TYPE fieldname,
        lv_n     TYPE n LENGTH 2,
        lv_hsl   TYPE p LENGTH 15 DECIMALS 2,
        lv_tsl   TYPE p LENGTH 15 DECIMALS 2.
  FIELD-SYMBOLS: <hsl> TYPE any,
                 <tsl> TYPE any,
                 <out> TYPE ty_out.

  SELECT * FROM faglflext INTO TABLE gt_flext
    WHERE ryear  = gv_gjahr
      AND rldnr  = '0L'
      AND rbukrs = p_bukrs
      AND racct BETWEEN '0000100000' AND '0000299999'.

  LOOP AT gt_flext INTO gs_flext.
    lv_hsl = gs_flext-hslvt.
    lv_tsl = gs_flext-tslvt.
    DO gv_poper TIMES.
      lv_n = sy-index.
      CONCATENATE 'HSL' lv_n INTO lv_fname.
      ASSIGN COMPONENT lv_fname OF STRUCTURE gs_flext TO <hsl>.
      CONCATENATE 'TSL' lv_n INTO lv_fname.
      ASSIGN COMPONENT lv_fname OF STRUCTURE gs_flext TO <tsl>.
      lv_hsl = lv_hsl + <hsl>.
      lv_tsl = lv_tsl + <tsl>.
    ENDDO.
    READ TABLE gt_out ASSIGNING <out> WITH KEY racct = gs_flext-racct.
    IF sy-subrc <> 0.
      CLEAR gs_out.
      gs_out-racct = gs_flext-racct.
      APPEND gs_out TO gt_out ASSIGNING <out>.
    ENDIF.
    <out>-ars_lib = <out>-ars_lib + lv_hsl.
    IF gs_flext-rtcur = 'USD'.
      <out>-sal_mon = <out>-sal_mon + lv_tsl.
    ENDIF.
  ENDLOOP.

  LOOP AT gt_out ASSIGNING <out>.
    SELECT SINGLE waers FROM skb1 INTO <out>-waers
      WHERE bukrs = p_bukrs AND saknr = <out>-racct.
    SELECT SINGLE txt50 FROM skat INTO <out>-txt50
      WHERE spras = sy-langu AND ktopl = gv_ktopl
        AND saknr = <out>-racct.
    IF <out>-waers = 'USD'.
*     Dolares: valor ARS al tipo compra; equivalente USD = saldo USD
      <out>-ars_mer = <out>-sal_mon * gv_rate_c.
      <out>-usd_eq  = <out>-sal_mon.
    ELSE.
*     Pesos: valor ARS = libros; equivalente USD al tipo venta
      <out>-sal_mon = <out>-ars_lib.
      <out>-ars_mer = <out>-ars_lib.
      <out>-usd_eq  = <out>-ars_lib / gv_rate_v.
    ENDIF.
    IF <out>-racct BETWEEN '0000110000' AND '0000119999'.
      <out>-grupo = 'Caja'.
    ELSEIF <out>-racct BETWEEN '0000120000' AND '0000129999'.
      <out>-grupo = 'Bancos'.
    ELSEIF <out>-racct BETWEEN '0000130000' AND '0000139999'.
      <out>-grupo = 'Billeteras'.
    ELSEIF <out>-racct BETWEEN '0000140000' AND '0000149999'.
      <out>-grupo = 'Brokers'.
    ELSEIF <out>-racct BETWEEN '0000150000' AND '0000159999'.
      <out>-grupo = 'Inversiones'.
    ELSEIF <out>-racct BETWEEN '0000200000' AND '0000299999'.
      <out>-grupo = 'Pasivo'.
    ENDIF.
    gv_pn_lib = gv_pn_lib + <out>-ars_lib.
    gv_pn_mer = gv_pn_mer + <out>-ars_mer.
    gv_pn_usd = gv_pn_usd + <out>-usd_eq.
  ENDLOOP.

  DELETE gt_out WHERE ars_lib = 0 AND sal_mon = 0.
  SORT gt_out BY racct.
  gv_dif = gv_pn_lib - gv_pn_mer.
ENDFORM.

*&---------------------------------------------------------------------*
*& Porcentaje de cada cuenta sobre el patrimonio a valor mercado
*&---------------------------------------------------------------------*
FORM calc_porcentajes.
  FIELD-SYMBOLS <out> TYPE ty_out.
  CHECK gv_pn_mer <> 0.
  LOOP AT gt_out ASSIGNING <out>.
    <out>-porc = <out>-ars_mer * 100 / gv_pn_mer.
  ENDLOOP.
ENDFORM.

*&---------------------------------------------------------------------*
*& Salida ALV (CL_SALV_TABLE) con encabezado y totales
*&---------------------------------------------------------------------*
FORM mostrar_alv.
  DATA: lo_alv  TYPE REF TO cl_salv_table,
        lo_cols TYPE REF TO cl_salv_columns_table,
        lo_aggr TYPE REF TO cl_salv_aggregations,
        lo_func TYPE REF TO cl_salv_functions_list,
        lo_head TYPE REF TO cl_salv_form_layout_grid,
        lv_txt  TYPE string,
        lv_c1   TYPE c LENGTH 25,
        lv_c2   TYPE c LENGTH 25,
        lv_c3   TYPE c LENGTH 25,
        lv_c4   TYPE c LENGTH 25,
        lv_rc   TYPE c LENGTH 15,
        lv_rv   TYPE c LENGTH 15,
        lv_r2   TYPE p LENGTH 15 DECIMALS 2,
        lx_msg  TYPE REF TO cx_salv_msg.

  TRY.
      cl_salv_table=>factory(
        IMPORTING r_salv_table = lo_alv
        CHANGING  t_table      = gt_out ).
    CATCH cx_salv_msg INTO lx_msg.
      MESSAGE lx_msg TYPE 'E'.
  ENDTRY.

  lo_cols = lo_alv->get_columns( ).
  lo_cols->set_optimize( abap_true ).
  PERFORM set_col USING lo_cols 'GRUPO'   'Grupo'.
  PERFORM set_col USING lo_cols 'RACCT'   'Cuenta'.
  PERFORM set_col USING lo_cols 'TXT50'   'Descripcion'.
  PERFORM set_col USING lo_cols 'WAERS'   'Mon.'.
  PERFORM set_col USING lo_cols 'SAL_MON' 'Saldo origen'.
  PERFORM set_col USING lo_cols 'ARS_LIB' 'ARS libros'.
  PERFORM set_col USING lo_cols 'ARS_MER' 'ARS mercado'.
  PERFORM set_col USING lo_cols 'USD_EQ'  'USD equiv.'.
  PERFORM set_col USING lo_cols 'PORC'    '% patrim.'.

  lo_aggr = lo_alv->get_aggregations( ).
  TRY.
      lo_aggr->add_aggregation( columnname = 'ARS_LIB' ).
      lo_aggr->add_aggregation( columnname = 'ARS_MER' ).
      lo_aggr->add_aggregation( columnname = 'USD_EQ' ).
      lo_aggr->add_aggregation( columnname = 'PORC' ).
    CATCH cx_salv_not_found cx_salv_data_error cx_salv_existing.
  ENDTRY.

  WRITE gv_pn_lib TO lv_c1 CURRENCY 'ARS'.
  WRITE gv_pn_mer TO lv_c2 CURRENCY 'ARS'.
  WRITE gv_dif    TO lv_c3 CURRENCY 'ARS'.
  WRITE gv_pn_usd TO lv_c4 CURRENCY 'USD'.
  lv_r2 = gv_rate_c.
  WRITE lv_r2 TO lv_rc.
  lv_r2 = gv_rate_v.
  WRITE lv_r2 TO lv_rv.
  CONDENSE: lv_c1, lv_c2, lv_c3, lv_c4, lv_rc, lv_rv.

  CREATE OBJECT lo_head.
  lo_head->create_label( row = 1 column = 1
                         text = 'PATRIMONIO - Valor libros vs. mercado' ).
  CONCATENATE 'Sociedad:' p_bukrs
              '- Fecha clave:' p_fecha+6(2) '.' p_fecha+4(2) '.' p_fecha(4)
              '- USD compra (' p_kurst '):' lv_rc
              '- USD venta (' p_kursv '):' lv_rv
              INTO lv_txt SEPARATED BY space.
  lo_head->create_text( row = 2 column = 1 text = lv_txt ).
  CONCATENATE 'Patrimonio neto a valor libros ARS:' lv_c1
              INTO lv_txt SEPARATED BY space.
  lo_head->create_text( row = 3 column = 1 text = lv_txt ).
  CONCATENATE 'Patrimonio neto a valor mercado ARS:' lv_c2
              INTO lv_txt SEPARATED BY space.
  lo_head->create_text( row = 4 column = 1 text = lv_txt ).
  CONCATENATE 'Patrimonio neto equivalente USD:' lv_c4
              INTO lv_txt SEPARATED BY space.
  lo_head->create_text( row = 5 column = 1 text = lv_txt ).
  CONCATENATE 'Diferencia (ajuste pendiente) ARS:' lv_c3
              INTO lv_txt SEPARATED BY space.
  lo_head->create_text( row = 6 column = 1 text = lv_txt ).
  lo_alv->set_top_of_list( lo_head ).

  lo_func = lo_alv->get_functions( ).
  lo_func->set_all( abap_true ).
  lo_alv->display( ).
ENDFORM.

*&---------------------------------------------------------------------*
*& Textos de cabecera de columna
*&---------------------------------------------------------------------*
FORM set_col USING io_cols TYPE REF TO cl_salv_columns_table
                   iv_name TYPE lvc_fname
                   iv_text TYPE scrtext_l.
  DATA lo_col TYPE REF TO cl_salv_column.
  TRY.
      lo_col = io_cols->get_column( iv_name ).
      lo_col->set_long_text( iv_text ).
      lo_col->set_medium_text( iv_text(20) ).
      lo_col->set_short_text( iv_text(10) ).
    CATCH cx_salv_not_found.
  ENDTRY.
ENDFORM.
