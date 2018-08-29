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
    DESCRIÇÃO: Usuário não pode apagar o orçamento a menos que esteja com checbox em
                usuário>Geral> Pode Apagar Orçamento, marcada.
*/
--SELECT CAB.CODTIPOPER INTO PCODTIPOPER FROM TGFCAB CAB CAB.NUNOTA = :NEW.NUNOTA;
SELECT STP_GET_CODUSULOGADO() INTO PCODUSU FROM DUAL;
SELECT COUNT(1) INTO PCONT FROM TSIUSU WHERE CODUSU = PCODUSU AND NVL(AD_APAGAORCAMENTO,'N') = 'S';

--TOPS na seguencia (Orpamento de Venda, Orçamento de Serviço, Orçamento WEB)
IF (PCONT = 0) AND :OLD.CODTIPOPER IN (3010, 3012, 5010)  THEN
RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><b> <font size="12" color="#FF0000">
O usuário logado não tem permissão para <br> apagar o orçamento!    
   </font></b><br>');
END IF;

END;
/
