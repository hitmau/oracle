DROP TRIGGER TOTALPRD.TRG_DEL_TGFCAB_RMA_TOTAL;

CREATE OR REPLACE TRIGGER TOTALPRD.TRG_DEL_TGFCAB_RMA_TOTAL 
   BEFORE DELETE ON TOTALPRD.TGFCAB FOR EACH ROW
DECLARE
PUSOPROD VARCHAR(1);
   --PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
/* 
    AUTOR: Mauricio Rodrigues
    Data: 26/01/2018
    DESCRIÇÃO: remover produtos ou incluir produtos da tabela de log com data (AD_PRODDTENT)
    OBJETIVO: Quando um ou vários produtos entram nos estoques do RMA, temo a necessidade de saber qual a data de cada entrada
    para que possamos controlar o tempo desse produto no estoque, com isso, com a junção de varias trigger, essa é destinada a
    remover os produtos caso a nota (antes da confirmação) seja excluida ou incluir os produtos na exclução da nota confirmada.

*/  

    IF :OLD.CODTIPOPER IN (2200, 2201, 2205, 3211, 2104, 2209, 2299) THEN
        IF (:OLD.STATUSNOTA = 'L') THEN
            DELETE FROM AD_PRODDTENT AD WHERE AD.NUNOTA = :OLD.NUNOTA;
        END IF;
    END IF;
    --QUANDO REMOVEMOS UMA TRANSFERENCIA
    IF :OLD.CODTIPOPER IN (1400, 1423, 1433, 1425) THEN
        IF (:OLD.STATUSNOTA = 'L') THEN
            --Percorremos os produtos da nota
            FOR I IN (SELECT ITE.SEQUENCIA, ITE.CODPROD, ITE.QTDNEG, ITE.CODLOCALORIG FROM TGFITE ITE WHERE ITE.NUNOTA = :OLD.NUNOTA)
            LOOP 
                SELECT PRO.USOPROD 
                INTO PUSOPROD 
                FROM TGFPRO PRO 
                WHERE PRO.CODPROD = I.CODPROD;
                
                IF PUSOPROD = 'R' THEN
                    IF I.SEQUENCIA < 0 THEN 
                        DELETE FROM AD_PRODDTENT AA WHERE AA.NUNOTA = :OLD.NUNOTA;
                    END IF;
                    IF I.SEQUENCIA > 0 THEN 
                        INSERT INTO AD_PRODDTENT (ID, NUNOTA, CODPROD, DTENTRADA, QTDNEG, CODLOCAL, CODEMP, CODUSU, CODTIPOPER) VALUES 
                        ((SELECT MAX(ID)+1 FROM AD_PRODDTENT),:OLD.NUNOTA, I.CODPROD, :OLD.DTFATUR, I.QTDNEG, I.CODLOCALORIG, :OLD.CODEMP, :OLD.CODUSU, :OLD.CODTIPOPER);
                    END IF;
                END IF;
            END LOOP;
        END IF;    
   END IF;
--    IF :OLD.CODTIPOPER IN (3202, 3204) THEN
--        --IF (:OLD.STATUSNOTA  <> :NEW.STATUSNOTA) AND (:NEW.STATUSNOTA = 'L') THEN
--            --FOR I IN (SELECT ITE.CODPROD, ITE.QTDNEG, ITE.CODLOCALORIG FROM TGFITE ITE WHERE ITE.NUNOTA = :OLD.NUNOTA)
--            --    LOOP
--                    INSERT INTO AD_PRODDTENT (ID, NUNOTA, CODPROD, DTENTRADA, QTDNEG, CODLOCAL, CODEMP) VALUES ((SELECT MAX(ID)+1 FROM AD_PRODDTENT),:OLD.NUNOTA, I.CODPROD, NVL(:OLD.DTFATUR, SYSDATE), I.QTDNEG, I.CODLOCALORIG, :OLD.CODEMP);
--             --   END LOOP;
--        --ELSE
--           DELETE FROM AD_PRODDTENT AD WHERE AD.NUNOTA = :OLD.NUNOTA;
--        --END IF;
--    END IF;
--RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
--AGUARDE 1 MINUTO E TENTE NOVAMENTE.  || PCODEMP) || </font></b><br><font>');
END;
/
