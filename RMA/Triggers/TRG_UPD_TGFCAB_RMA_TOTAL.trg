DROP TRIGGER TOTALPRD.TRG_UPD_TGFCAB_RMA_TOTAL;

CREATE OR REPLACE TRIGGER TOTALPRD.TRG_UPD_TGFCAB_RMA_TOTAL 
   BEFORE UPDATE ON TOTALPRD.TGFCAB FOR EACH ROW
DECLARE
   PGRUPO         INT;
   PMOTIVO       VARCHAR(1);
   PUSOPROD      VARCHAR(1);
   PLOCALORIG    INT;
   PLOCALORIG_LOG    INT;
   P_COUNT       INT;
   PRAGMA AUTONOMOUS_TRANSACTION;
   
BEGIN


IF :NEW.CODTIPOPER IN (2200 --Devolução de nota de Terceiros
                              ,2201 --Devolução de nota de Própria
                              ,2205 --ENTRADA DE NOTAS ERRADAS RMA
                              ,2209 -- ENTRADA DE MERCADORIA COM PEÇAS OBSOLETAS (NOTA PRÓPRIA)
                              ,2299 -- ENTRADA DE MERCADORIA COM PEÇAS OBSOLETAS (NOTA DE TERCEIRO)
                              ) THEN
    IF :OLD.STATUSNOTA = :NEW.STATUSNOTA AND :NEW.STATUSNOTA <> 'L' THEN
            --Verifica se o campo está marcado como Compra errada (e) ou Venda errada (c).
        IF (:NEW.AD_MOTDEVOLUCAO = 'c') OR (:NEW.AD_MOTDEVOLUCAO = 'e') THEN --Motivo da devolução é Compra ou Venda errada
                                SELECT MAX(ITE.CODLOCALORIG)
                                INTO PLOCALORIG
                                FROM TGFITE ITE
                                WHERE ITE.NUNOTA = :NEW.NUNOTA;
            IF PLOCALORIG <> 3001 THEN --Verifico nocamente para não realizar update desnecessário
                    UPDATE TGFITE ITE SET ITE.CODLOCALORIG = 3001 WHERE ITE.NUNOTA = :NEW.NUNOTA;
                    COMMIT; --Estoque RMA Principal

                    PLOCALORIG_LOG := 3001;

            END IF; 
        END IF;
            --Verifica se o campo está marcado como Defeito = (v).
        IF (:NEW.AD_MOTDEVOLUCAO = 'v') THEN -----------Estoque RMA DOA ou Expresso
            FOR CUR_CUS IN (SELECT ITE.CODPROD
                                     , PROD.AD_TIPOTROCA
                                     , ITE.QTDNEG 
                                FROM TGFITE ITE
                                   , TGFPRO PROD 
                                WHERE PROD.CODPROD=ITE.CODPROD 
                                  AND ITE.NUNOTA = :NEW.NUNOTA 
                                ORDER BY 1)
            LOOP
                    SELECT ITE.CODLOCALORIG, ITE.USOPROD
                    INTO PLOCALORIG, PUSOPROD
                    FROM TGFITE ITE
                    WHERE ITE.NUNOTA =  :NEW.NUNOTA AND ITE.CODPROD = CUR_CUS.CODPROD;
                        
                IF PUSOPROD = 'R' THEN
                    IF (CUR_CUS.AD_TIPOTROCA = 1) AND (PLOCALORIG <> 3002) THEN--DOA
                            UPDATE TGFITE SET CODLOCALORIG = 3002 WHERE NUNOTA =  :NEW.NUNOTA AND CODPROD = CUR_CUS.CODPROD; 
                            COMMIT;
                    END IF;
                    IF (CUR_CUS.AD_TIPOTROCA = 2)  AND (PLOCALORIG <> 3003)THEN --EXPRESSO
                            UPDATE TGFITE SET CODLOCALORIG = 3003 WHERE NUNOTA = :NEW.NUNOTA AND CODPROD = CUR_CUS.CODPROD; 
                            COMMIT;
                    END IF; 
                    IF (CUR_CUS.AD_TIPOTROCA = 3) THEN --Sem Troca
                            RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
                            Produto: ' || TO_CHAR(CUR_CUS.CODPROD) || ' não pode ser trocado.<br>Entre em contato com o responsável pelo cadastro do produto.</font></b><br><font>');
                    END IF;
                END IF;
            END LOOP;
        END IF;
    END IF;
END IF;
END;
/
