*&---------------------------------------------------------------------*
*& Report  ZAUDIT_SM20_ALV
*&---------------------------------------------------------------------*
*& Lectura de Audit Log
*& NOTA: Requiere activación previa por SM19 (Static)
*&---------------------------------------------------------------------*

REPORT zaudit_sm20_alv.

DATA: lr_data      TYPE REF TO data,
      lr_data_filt TYPE REF TO data,
      lr_line      TYPE REF TO data.

FIELD-SYMBOLS: <lt_data>     TYPE STANDARD TABLE,
               <lt_filtered> TYPE STANDARD TABLE,
               <ls_row>      TYPE any,
               <f_date>      TYPE any,
               <f_time>      TYPE any,
               <f_user>      TYPE any,
               <f_tcode>     TYPE any,
               <f_prog>      TYPE any,
               <f_taskty>    TYPE any.

" --- Parámetros de Filtro ---
PARAMETERS: p_date     TYPE datum DEFAULT sy-datum,
            p_timef    TYPE uzeit,
            p_timet    TYPE uzeit,
            p_user     TYPE xubname,
            p_tcode    TYPE c LENGTH 10,
            p_prog     TYPE c LENGTH 40,
            p_taskty   TYPE c LENGTH 4.   " <-- NUEVO: D=Dialog, B=Background

" Variables de trabajo
DATA: lv_row_date       TYPE datum,
      lv_row_time       TYPE uzeit,
      lv_row_user       TYPE xubname,
      lv_row_tcode      TYPE c LENGTH 10,
      lv_row_prog       TYPE c LENGTH 40,
      lv_row_taskty     TYPE c LENGTH 4,  " <-- NUEVA VARIABLE
      lv_total_lines    TYPE i,
      lv_filtered_count TYPE i.

" Variables auxiliares para comparación
DATA: lv_user_cmp       TYPE xubname,
      lv_tcode_cmp      TYPE c LENGTH 10,
      lv_prog_cmp       TYPE c LENGTH 40,
      lv_taskty_cmp     TYPE c LENGTH 4.

START-OF-SELECTION.

  " 1. Capturar datos de SM20 en segundo plano
  cl_salv_bs_runtime_info=>set(
    display  = abap_false
    metadata = abap_false
    data     = abap_true ).

  SUBMIT rsau_select_events AND RETURN.

  TRY.
      cl_salv_bs_runtime_info=>get_data_ref( IMPORTING r_data = lr_data ).
      ASSIGN lr_data->* TO <lt_data>.
      cl_salv_bs_runtime_info=>clear_all( ).
    CATCH cx_salv_bs_sc_runtime_info.
      MESSAGE 'No se pudo capturar SM20' TYPE 'E'.
  ENDTRY.

  IF <lt_data> IS ASSIGNED.
    DESCRIBE TABLE <lt_data> LINES lv_total_lines.

    IF lv_total_lines = 0.
      MESSAGE 'No hay datos en el registro de auditoría.' TYPE 'I'.
      EXIT.
    ENDIF.

    " 2. Preparar tabla filtrada
    CREATE DATA lr_data_filt LIKE <lt_data>.
    ASSIGN lr_data_filt->* TO <lt_filtered>.

    " 3. Recorrido y aplicación de filtros
    LOOP AT <lt_data> ASSIGNING <ls_row>.
      CLEAR: lv_row_date, lv_row_time, lv_row_user, 
             lv_row_tcode, lv_row_prog, lv_row_taskty.

      " Obtener fecha (ALGDATE)
      ASSIGN COMPONENT 'ALGDATE' OF STRUCTURE <ls_row> TO <f_date>.
      IF sy-subrc = 0 AND <f_date> IS NOT INITIAL.
        lv_row_date = <f_date>.
      ENDIF.

      " Obtener hora (ALGTIME)
      ASSIGN COMPONENT 'ALGTIME' OF STRUCTURE <ls_row> TO <f_time>.
      IF sy-subrc = 0 AND <f_time> IS NOT INITIAL.
        lv_row_time = <f_time>.
      ENDIF.

      " Obtener usuario (ALGUSER)
      ASSIGN COMPONENT 'ALGUSER' OF STRUCTURE <ls_row> TO <f_user>.
      IF sy-subrc = 0 AND <f_user> IS NOT INITIAL.
        lv_row_user = <f_user>.
      ENDIF.

      " Obtener transacción (ALGTCODE)
      ASSIGN COMPONENT 'ALGTCODE' OF STRUCTURE <ls_row> TO <f_tcode>.
      IF sy-subrc = 0 AND <f_tcode> IS NOT INITIAL.
        lv_row_tcode = <f_tcode>.
      ENDIF.

      " Obtener programa (ALGREPNA)
      ASSIGN COMPONENT 'ALGREPNA' OF STRUCTURE <ls_row> TO <f_prog>.
      IF sy-subrc = 0 AND <f_prog> IS NOT INITIAL.
        lv_row_prog = <f_prog>.
      ENDIF.

      " Obtener Task Type (ALGTASKTYPE)
      ASSIGN COMPONENT 'ALGTASKTYPE' OF STRUCTURE <ls_row> TO <f_taskty>.
      IF sy-subrc = 0 AND <f_taskty> IS NOT INITIAL.
        lv_row_taskty = <f_taskty>.
      ENDIF.

      " --- Aplicación de filtros ---
      
      " 1. Fecha
      IF p_date IS NOT INITIAL AND lv_row_date <> p_date.
        CONTINUE.
      ENDIF.

      " 2. Hora desde
      IF p_timef IS NOT INITIAL AND lv_row_time < p_timef.
        CONTINUE.
      ENDIF.

      " 3. Hora hasta
      IF p_timet IS NOT INITIAL AND lv_row_time > p_timet.
        CONTINUE.
      ENDIF.

      " 4. Usuario
      IF p_user IS NOT INITIAL.
        lv_user_cmp = p_user.
        CONDENSE lv_user_cmp.
        CONDENSE lv_row_user.
        IF lv_row_user <> lv_user_cmp.
          CONTINUE.
        ENDIF.
      ENDIF.

      " 5. Transacción
      IF p_tcode IS NOT INITIAL.
        lv_tcode_cmp = p_tcode.
        TRANSLATE lv_tcode_cmp TO UPPER CASE.
        TRANSLATE lv_row_tcode TO UPPER CASE.
        CONDENSE lv_tcode_cmp.
        CONDENSE lv_row_tcode.
        IF lv_row_tcode <> lv_tcode_cmp.
          CONTINUE.
        ENDIF.
      ENDIF.

      " 6. Programa
      IF p_prog IS NOT INITIAL.
        lv_prog_cmp = p_prog.
        TRANSLATE lv_prog_cmp TO UPPER CASE.
        TRANSLATE lv_row_prog TO UPPER CASE.
        CONDENSE lv_prog_cmp.
        CONDENSE lv_row_prog.
        IF lv_row_prog <> lv_prog_cmp.
          CONTINUE.
        ENDIF.
      ENDIF.

      " 7. Task Type (D=Dialog, B=Background)
      IF p_taskty IS NOT INITIAL.
        lv_taskty_cmp = p_taskty.
        TRANSLATE lv_taskty_cmp TO UPPER CASE.
        TRANSLATE lv_row_taskty TO UPPER CASE.
        CONDENSE lv_taskty_cmp.
        CONDENSE lv_row_taskty.
        IF lv_row_taskty <> lv_taskty_cmp.
          CONTINUE.
        ENDIF.
      ENDIF.

      APPEND <ls_row> TO <lt_filtered>.
    ENDLOOP.

    DESCRIBE TABLE <lt_filtered> LINES lv_filtered_count.

    IF lv_filtered_count = 0.
      MESSAGE 'No hay datos para los filtros seleccionados' TYPE 'I'.
      EXIT.
    ENDIF.

    <lt_data> = <lt_filtered>.

    " 4. Mostrar resultado en ALV
    DATA: lr_alv TYPE REF TO cl_salv_table.
    cl_salv_table=>factory(
      IMPORTING r_salv_table = lr_alv
      CHANGING  t_table      = <lt_data> ).
    lr_alv->display( ).

  ELSE.
    MESSAGE 'No se capturaron datos.' TYPE 'I'.
  ENDIF.
