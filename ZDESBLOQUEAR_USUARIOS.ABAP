*&---------------------------------------------------------------------*
*& Report  ZDESBLOQUEAR_USUARIOS
*&
*&---------------------------------------------------------------------*
*& Status 128 - Demasiados intentos de inicio de sesión
*& HARDCODEADO
*&---------------------------------------------------------------------*
REPORT ZDESBLOQUEAR_USUARIOS.

DATA: lt_usuarios TYPE TABLE OF usr02,
      ls_usuario  TYPE usr02.

SELECT-OPTIONS: so_bname FOR ls_usuario-bname.
PARAMETERS: p_dsb AS CHECKBOX USER-COMMAND desbloq. "Leyenda directa

START-OF-SELECTION.

  SELECT * FROM usr02
    INTO TABLE lt_usuarios
    WHERE uflag = 128
      AND bname IN so_bname.

  IF lt_usuarios IS INITIAL.
    WRITE: / 'No se encontraron usuarios bloqueados según el criterio seleccionado.'.
    RETURN.
  ENDIF.

  LOOP AT lt_usuarios INTO ls_usuario.
    WRITE: / 'Usuario:', ls_usuario-bname, 'está bloqueado (Flag 128)'.

    IF p_dsb = 'X'.
      " Desbloquear el usuario
      ls_usuario-uflag = 0.
      MODIFY usr02 FROM ls_usuario.

      " Confirmación de desbloqueo
      WRITE: ' -> Desbloqueado correctamente'.
    ENDIF.
  ENDLOOP.

  IF p_dsb = 'X'.
    COMMIT WORK.
    WRITE: / 'Proceso de desbloqueo completado.'.
  ENDIF.
