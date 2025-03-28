*&---------------------------------------------------------------------*
*& Report  ZLISTAR_STATUS_USUARIOS
*&
*&---------------------------------------------------------------------*
*& Listar usuarios y tipos de bloqueos aplicados
*& Programa para resumir consulta de RSUSR200
*&---------------------------------------------------------------------*

REPORT  ZLISTAR_STATUS_USUARIOS.

DATA: lt_users TYPE TABLE OF usr02,
      ls_user  TYPE usr02.

SELECT * FROM usr02
  INTO TABLE lt_users.

LOOP AT lt_users INTO ls_user.
  CASE ls_user-uflag.
    WHEN 64.
      WRITE: / 'User:', ls_user-bname, 'is locked by admin (Flag 64)'.
    WHEN 192.
      WRITE: / 'User:', ls_user-bname, 'is locked by admin and incorrect logon (Flag 192)'.
    WHEN 128.
      WRITE: / 'User:', ls_user-bname, 'is locked by many fails (Incorrect Logon) (Flag 128)'.
    WHEN 0.
      WRITE: / 'User:', ls_user-bname, 'is unlocked (Flag 0)'.
    WHEN OTHERS.
      WRITE: / 'User:', ls_user-bname, 'has an unknown flag: ', ls_user-uflag.
  ENDCASE.
ENDLOOP.
