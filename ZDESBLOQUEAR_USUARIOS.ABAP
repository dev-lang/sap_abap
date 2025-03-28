*&---------------------------------------------------------------------*
*& Report  ZDESBLOQUEAR_USUARIOS
*&
*&---------------------------------------------------------------------*
*& Status 128 - Demasiados intentos de inicio de sesión
*& HARDCODEADO (Se agregaron flags 64 y 192)
*&---------------------------------------------------------------------*

REPORT ZDESBLOQUEAR_USUARIOS.

DATA: lt_usuarios TYPE TABLE OF usr02,
      ls_usuario  TYPE usr02.

SELECT-OPTIONS: so_bname FOR ls_usuario-bname.
PARAMETERS: p_dsb AS CHECKBOX USER-COMMAND desbloq. "Leyenda directa

START-OF-SELECTION.

  " Se amplía la condición para incluir los flags 64 y 192
  SELECT * FROM usr02
    INTO TABLE lt_usuarios
    WHERE uflag IN (64, 128, 192)
      AND bname IN so_bname.

  IF lt_usuarios IS INITIAL.
    WRITE: / 'No se encontraron usuarios bloqueados según el criterio seleccionado.'.
    RETURN.
  ENDIF.

  LOOP AT lt_usuarios INTO ls_usuario.
    WRITE: / 'Usuario:', ls_usuario-bname, 'está bloqueado'.

    " Identificación del tipo de bloqueo
    CASE ls_usuario-uflag.
      WHEN 64.
        WRITE: ' -> Bloqueado por el administrador (Flag 64)'.
      WHEN 128.
        WRITE: ' -> Bloqueo global (Flag 128)'.
      WHEN 192.
        WRITE: ' -> Bloqueo por administrador e intentos fallidos (Flag 192)'.
    ENDCASE.

    " Desbloqueo si el checkbox está marcado
    IF p_dsb = 'X'.
      ls_usuario-uflag = 0.
      MODIFY usr02 FROM ls_usuario.
      WRITE: ' -> Desbloqueado correctamente'.
    ENDIF.
  ENDLOOP.

  IF p_dsb = 'X'.
    COMMIT WORK.
    WRITE: / 'Proceso de desbloqueo completado.'.
  ENDIF.
