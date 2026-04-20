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

" --- Select-Options (Múltiples valores, rangos y exclusiones) ---
SELECT-OPTIONS: s_date   FOR sy-datum,   " Fecha
                s_time   FOR sy-uzeit,   " Hora
                s_user   FOR sy-uname,   " Usuario
                s_tcode  FOR sy-tcode,   " Transacción
                s_prog   FOR sy-repid.   " Programa
PARAMETERS:     p_taskty TYPE c LENGTH 4. " Task Type (D/B)

" Variables de trabajo
DATA: lv_row_date       TYPE datum,
      lv_row_time       TYPE uzeit,
      lv_row_user       TYPE xubname,
      lv_row_tcode      TYPE c LENGTH 10,
      lv_row_prog       TYPE c LENGTH 40,
      lv_row_taskty     TYPE c LENGTH 4,
      lv_total_lines    TYPE i,
      lv_filtered_count TYPE i.

" Mantener comportamiento original: por defecto filtra solo HOY
INITIALIZATION.
  s_date-sign   = 'I'.
  s_date-option = 'EQ'.
  s_date-low    = sy-datum.
  APPEND s_date.

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

      " Obtener campos de la estructura dinámica
      ASSIGN COMPONENT 'ALGDATE'     OF STRUCTURE <ls_row> TO <f_date>.
      IF sy-subrc = 0 AND <f_date> IS NOT INITIAL. lv_row_date = <f_date>. ENDIF.

      ASSIGN COMPONENT 'ALGTIME'     OF STRUCTURE <ls_row> TO <f_time>.
      IF sy-subrc = 0 AND <f_time> IS NOT INITIAL. lv_row_time = <f_time>. ENDIF.

      ASSIGN COMPONENT 'ALGUSER'     OF STRUCTURE <ls_row> TO <f_user>.
      IF sy-subrc = 0 AND <f_user> IS NOT INITIAL. lv_row_user = <f_user>. ENDIF.

      ASSIGN COMPONENT 'ALGTCODE'    OF STRUCTURE <ls_row> TO <f_tcode>.
      IF sy-subrc = 0 AND <f_tcode> IS NOT INITIAL. lv_row_tcode = <f_tcode>. ENDIF.

      ASSIGN COMPONENT 'ALGREPNA'    OF STRUCTURE <ls_row> TO <f_prog>.
      IF sy-subrc = 0 AND <f_prog> IS NOT INITIAL. lv_row_prog = <f_prog>. ENDIF.

      ASSIGN COMPONENT 'ALGTASKTYPE' OF STRUCTURE <ls_row> TO <f_taskty>.
      IF sy-subrc = 0 AND <f_taskty> IS NOT INITIAL. lv_row_taskty = <f_taskty>. ENDIF.

      " --- Aplicación de filtros (Lógica unificada con SELECT-OPTIONS) ---

      " 1. Fecha
      IF s_date[] IS NOT INITIAL AND lv_row_date NOT IN s_date.
        CONTINUE.
      ENDIF.

      " 2. Hora
      IF s_time[] IS NOT INITIAL AND lv_row_time NOT IN s_time.
        CONTINUE.
      ENDIF.

      " 3. Usuario
      IF s_user[] IS NOT INITIAL.
        TRANSLATE lv_row_user TO UPPER CASE.
        CONDENSE lv_row_user.
        IF lv_row_user NOT IN s_user.
          CONTINUE.
        ENDIF.
      ENDIF.

      " 4. Transacción
      IF s_tcode[] IS NOT INITIAL.
        TRANSLATE lv_row_tcode TO UPPER CASE.
        CONDENSE lv_row_tcode.
        IF lv_row_tcode NOT IN s_tcode.
          CONTINUE.
        ENDIF.
      ENDIF.

      " 5. Programa
      IF s_prog[] IS NOT INITIAL.
        TRANSLATE lv_row_prog TO UPPER CASE.
        CONDENSE lv_row_prog.
        IF lv_row_prog NOT IN s_prog.
          CONTINUE.
        ENDIF.
      ENDIF.

      " 6. Task Type
      IF p_taskty IS NOT INITIAL.
        TRANSLATE lv_row_taskty TO UPPER CASE.
        CONDENSE lv_row_taskty.
        IF lv_row_taskty <> p_taskty.
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
