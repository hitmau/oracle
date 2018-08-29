DROP TRIGGER TOTALPRD.TRG_INC_AD_DESLOC_M_TOTAL;

CREATE OR REPLACE TRIGGER TOTALPRD.TRG_INC_AD_DESLOC_M_TOTAL
BEFORE INSERT OR UPDATE ON TOTALPRD.AD_DESLOCSUPORTE
FOR EACH ROW
DECLARE
   PCODUSU        INT;
   PCODGRUPO      INT;
   PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
/*
AUTOR: Mauricio Rodrigues
Data da cria��o: 24/4/2018
Descri��o: Na tela de Registro de deslocamentos, somente o gerente ou o pr�prio usu�rio que criou o deslocamente pode alterar.
*/
--Log das altera��es
SELECT  STP_GET_CODUSULOGADO() 
    INTO PCODUSU  
    FROM DUAL;

SELECT CODGRUPO 
    INTO PCODGRUPO 
    FROM TSIUSU 
    WHERE CODUSU = PCODUSU;
---------------------------------------------------
    --SUBERVISOR PODE ALTERAR O PROSPECT (USU�RIO>GERAL>PODE ALTERAR PROSPECT) and (:OLD.AD_PAPVALIDO = :NEW.AD_PAPVALIDO)
    IF INSERTING THEN
        :NEW.DTDESLOC := SYSDATE;
        :NEW.CODUSUALT := PCODUSU;
    END IF;
    IF (UPDATING) AND PCODGRUPO NOT IN (1, 34, 12) THEN
        IF :NEW.CODUSUALT <> 0 OR :OLD.CODUSUALT <> 0 THEN
            IF (:OLD.CODUSUALT <> 0) AND (PCODUSU <> :OLD.CODUSUALT) THEN
                 RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
    Somente o usu�rio(a) ou o Supervisor podem alterar o cadastro deste deslocamento!</font></b><br><font>');
            END IF;
        END IF;
    END IF;

END;
/
