*&---------------------------------------------------------------------*
*& Report  ZCREAR_USUARIO
*&
*&---------------------------------------------------------------------*
*& Crear un usuario por medio de Z en lugar de SU01
*& Por defecto será de tipo Diálogo
*&---------------------------------------------------------------------*

REPORT  ZCREAR_USUARIO.

PARAMETERS: p_uname TYPE sy-uname OBLIGATORY,
            p_fname TYPE string,
            p_lname TYPE string,
            p_passw TYPE bapipwd-bapipwd,
*            p_ustyp TYPE char1 OBLIGATORY, " <-- Nuevo parámetro
            p_ustyp TYPE char1 OBLIGATORY DEFAULT 'A', " <-- Nuevo parámetro con valor por defecto
            p_simul AS CHECKBOX DEFAULT abap_false.

DATA: ls_logondata TYPE bapilogond,
      ls_address   TYPE bapiaddr3,
      ls_password  TYPE bapipwd,
      lt_return    TYPE TABLE OF bapiret2,
      ls_return    TYPE bapiret2,
      lv_error     TYPE abap_bool VALUE abap_false,
      lt_reserved_names TYPE TABLE OF string,
      lv_reserved_name TYPE string,
      lv_min_length TYPE i VALUE 8,  " Longitud mínima de contraseña
      lv_max_length TYPE i VALUE 12. " Longitud máxima de contraseña

START-OF-SELECTION.

  "" INICIO VALIDACION DE PARAMETROS

  " Validación: contraseña por parámetros
  IF strlen( p_passw ) < lv_min_length OR strlen( p_passw ) > lv_max_length.
    WRITE: / '❌ La contraseña debe tener entre', lv_min_length, 'y', lv_max_length, 'caracteres.'.
    EXIT.
  ENDIF.

  "" FIN VALIDACION DE PARAMETROS

  " Validación: campo vacío
  IF p_uname IS INITIAL.
    WRITE: / '❌ El nombre de usuario no puede estar vacío.'.
    EXIT.
  ENDIF.

  " Validación: longitud mínima de usuario
  IF strlen( p_uname ) < 5.
    WRITE: / '❌ El nombre de usuario debe tener al menos 5 caracteres.'.
    EXIT.
  ENDIF.

  " Validación: contraseña igual al usuario
  IF p_uname = p_passw.
    WRITE: / '❌ La contraseña no puede ser igual al nombre de usuario.'.
    EXIT.
  ENDIF.

  " Validación: nombres reservados
  APPEND 'ADMIN' TO lt_reserved_names.
  APPEND 'ROOT' TO lt_reserved_names.
  APPEND 'SUPERUSER' TO lt_reserved_names.
  APPEND 'GUEST' TO lt_reserved_names.

  " Comprobar si el nombre de usuario es reservado
  READ TABLE lt_reserved_names WITH KEY table_line = p_uname INTO lv_reserved_name.
  IF sy-subrc = 0.
    WRITE: / '❌ El nombre de usuario no puede ser un nombre reservado: ', p_uname.
    EXIT.
  ENDIF.

  " Verificar si el usuario ya existe
  CALL FUNCTION 'BAPI_USER_EXISTENCE_CHECK'
    EXPORTING
      username = p_uname
    IMPORTING
      return   = ls_return.

  IF ls_return-type = 'S'.
    WRITE: / '⚠️ El usuario', p_uname, 'ya existe. No se puede crear nuevamente.'.
    EXIT.
  ENDIF.

 "" TIPOS DE USUARIOS VALIDOS
  " Validación del tipo de usuario (p_ustyp) - Nueva validación simple
  CASE p_ustyp.
    WHEN 'A' OR 'B' OR 'C' OR 'S'.
      " El tipo es válido, no hacer nada
    WHEN OTHERS.
      WRITE: / '❌ Tipo de usuario inválido. Debe ser A, B, C o S.'.
      EXIT.
  ENDCASE.
 "" FIN TIPOS DE USUARIOS VALIDOS

  " Datos del logon
*  CLEAR: ls_logondata.
*  ls_logondata-ustyp = 'A'. " Usuario diálogo
  CLEAR: ls_logondata.
  ls_logondata-ustyp = p_ustyp. " <-- Usás lo que el usuario eligió

  " Datos personales
  CLEAR: ls_address.
  ls_address-firstname = p_fname.
  ls_address-lastname  = p_lname.

  " Contraseña
  CLEAR: ls_password.
  ls_password-bapipwd = p_passw.

  " Simulación
*  IF p_simul = abap_true.
*    WRITE: / '# Simulación activada. El usuario', p_uname, 'no será creado.'.
*    EXIT.
*  ENDIF.
  IF p_simul = abap_true.
    WRITE: / '# Simulación activada. El usuario', p_uname, 'de tipo', p_ustyp, 'no será creado.'.
    EXIT.
  ENDIF.

  " Crear usuario
  CALL FUNCTION 'BAPI_USER_CREATE1'
    EXPORTING
      username   = p_uname
      logondata  = ls_logondata
      password   = ls_password
      address    = ls_address
    TABLES
      return     = lt_return.

  " Verificar mensajes
  LOOP AT lt_return INTO ls_return.
    WRITE: / ls_return-type, ls_return-id, ls_return-number, ls_return-message.
    IF ls_return-type = 'E' OR ls_return-type = 'A'.
      lv_error = abap_true.
    ENDIF.
  ENDLOOP.

  IF lv_error = abap_false.
    CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
      EXPORTING
        wait = 'X'.
*    WRITE: / '✅ Usuario', p_uname, 'creado correctamente.'.
    WRITE: / '✅ El usuario', p_uname, 'de tipo', p_ustyp, 'ha sido creado correctamente.'.
  ELSE.
    WRITE: / '❌ Error: no se pudo crear el usuario.'.
  ENDIF.
