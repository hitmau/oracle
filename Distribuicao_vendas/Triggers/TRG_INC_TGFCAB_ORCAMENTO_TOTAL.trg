DROP TRIGGER TOTALPRD.TRG_INC_TGFCAB_ORCAMENTO_TOTAL;

CREATE OR REPLACE TRIGGER TOTALPRD.TRG_INC_TGFCAB_ORCAMENTO_TOTAL
--REFERENCING OLD AS OLD NEW AS NEW
BEFORE DELETE ON TOTALPRD.TGFCAB FOR EACH ROW
DECLARE
PCODUSU     INT;
PCONT       INT;
Pragma Autonomous_Transaction;

BEGIN
/*
    AUTOR: Mauricio Rodrigues
    DESCRI��O: Usu�rio n�o pode apagar o or�amento a menos que esteja com checbox em
                usu�rio>Geral> Pode Apagar Or�amento, marcada.
*/
--SELECT CAB.CODTIPOPER INTO PCODTIPOPER FROM TGFCAB CAB CAB.NUNOTA = :NEW.NUNOTA;
SELECT STP_GET_CODUSULOGADO() INTO PCODUSU FROM DUAL;
SELECT COUNT(1) INTO PCONT FROM TSIUSU WHERE CODUSU = PCODUSU AND NVL(AD_APAGAORCAMENTO,'N') = 'S';

--TOPS na seguencia (Orpamento de Venda, Or�amento de Servi�o, Or�amento WEB)
IF (PCONT = 0) AND :OLD.CODTIPOPER IN (3010, 3012, 5010)  THEN
RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><b> <font size="12" color="#FF0000">
O usu�rio logado n�o tem permiss�o para <br> apagar o or�amento!    
   </font></b><br>');
END IF;

END;
/
