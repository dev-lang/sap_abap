*&---------------------------------------------------------------------*
*& Report  ZBLANQUEAR_USUARIOS
*&
*&---------------------------------------------------------------------*
*& Blanquea usuarios de acuerdo a la clave definida en p_pass (bapipwd)
*& 
*&---------------------------------------------------------------------*
REPORT zblanquear_usuarios.

DATA: ls_password  TYPE bapipwd,
      ls_passwordx TYPE bapipwdx, " Corregimos a la estructura correcta
      lt_return    TYPE TABLE OF bapiret2,
      ls_return    TYPE bapiret2.

PARAMETERS: p_user TYPE sy-uname OBLIGATORY,
            p_pass TYPE bapipwd OBLIGATORY.

START-OF-SELECTION.

  CLEAR: ls_password, ls_passwordx.

  ls_password = p_pass.
  ls_passwordx = 'X'. " Indica que queremos modificar la contraseña

  CALL FUNCTION 'BAPI_USER_CHANGE'
    EXPORTING
      username  = p_user
      password  = ls_password
      passwordx = ls_passwordx
    TABLES
      return    = lt_return.

  READ TABLE lt_return INTO ls_return WITH KEY type = 'E'.

  IF sy-subrc = 0.
    WRITE: 'Error al cambiar la contraseña:', ls_return-message.
    ROLLBACK WORK.
  ELSE.
    WRITE: 'Contraseña cambiada correctamente para el usuario:', p_user.
    COMMIT WORK.
  ENDIF.
