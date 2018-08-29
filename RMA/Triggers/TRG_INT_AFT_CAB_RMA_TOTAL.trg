DROP TRIGGER TOTALPRD.TRG_INT_AFT_CAB_RMA_TOTAL;

CREATE OR REPLACE TRIGGER TOTALPRD.TRG_INT_AFT_CAB_RMA_TOTAL 
   AFTER INSERT OR UPDATE ON TOTALPRD.TGFCAB FOR EACH ROW
DECLARE
PUSUPROD VARCHAR(1);
    PQTD INT;
BEGIN
/* 
    AUTOR: Mauricio Rodrigues
    Data: 26/01/2018
    DESCRIÇÃO: Inserir ou excluir produtos da tabela AD_PRODDTENT de acordo com a top.
    OBJETIVO: Criado tabela AD_PRODDTENT (Produto data entrada) para receber os produtos de qualquer entrada com data e remover
    os produtos de qualquer saida do mais antigo..
*/  

    --insere produtos na tabela AD_PRODDTENT caso seja das tops abeixo e quando estiverem confirmadas.
    IF :NEW.CODTIPOPER IN (2104, 2200, 2201, 2209, 2205, 3211, 3212, 2207, 2202, 2204, 2209, 2299) THEN
        IF (:OLD.STATUSNOTA  <> :NEW.STATUSNOTA) AND (:NEW.STATUSNOTA = 'L') THEN
            FOR I IN (SELECT ITE.CODPROD, ITE.QTDNEG, ITE.CODLOCALORIG FROM TGFITE ITE WHERE ITE.NUNOTA = :NEW.NUNOTA)
            LOOP
                INSERT INTO AD_PRODDTENT (ID, NUNOTA, CODPROD, DTENTRADA, QTDNEG, CODLOCAL, CODEMP, CODUSU, CODTIPOPER) VALUES ((SELECT MAX(ID)+1 FROM AD_PRODDTENT),:NEW.NUNOTA, I.CODPROD, :NEW.DTFATUR, I.QTDNEG, I.CODLOCALORIG, :NEW.CODEMP, :NEW.CODUSU, :NEW.CODTIPOPER);
            END LOOP;
        END IF;
    END IF;

---------------------------------------------------------------------------------------------------------------------------------\
---------TRATANDO COM TRANSFERENCIAS---------------------------------------------------------------------------------------------->
---------------------------------------------------------------------------------------------------------------------------------/
    IF :NEW.CODTIPOPER IN (1400, 1423, 1433, 1425) THEN
        IF (:OLD.STATUSNOTA  <> :NEW.STATUSNOTA) AND (:NEW.STATUSNOTA = 'L') THEN
            --Percorremos os produtos da nota
            FOR I IN (SELECT ITE.SEQUENCIA, ITE.CODPROD, ITE.QTDNEG, ITE.CODLOCALORIG FROM TGFITE ITE WHERE ITE.NUNOTA = :NEW.NUNOTA)
            LOOP   
                IF I.SEQUENCIA < 0 THEN 
                    INSERT INTO AD_PRODDTENT (ID, NUNOTA, CODPROD, DTENTRADA, QTDNEG, CODLOCAL, CODEMP, CODUSU, CODTIPOPER) VALUES ((SELECT MAX(ID)+1 FROM AD_PRODDTENT),:NEW.NUNOTA, I.CODPROD, :NEW.DTFATUR, I.QTDNEG, I.CODLOCALORIG, :NEW.CODEMP, :NEW.CODUSU, :NEW.CODTIPOPER);
                END IF;
                IF I.SEQUENCIA > 0 THEN 
                    PQTD := I.QTDNEG;
                    --Percorremos os produtos que estão na tabela organizados pela data mais atiga.
                    FOR Y IN (SELECT * FROM AD_PRODDTENT AD WHERE AD.CODPROD = I.CODPROD AND AD.CODEMP = :NEW.CODEMP AND AD.CODLOCAL = I.CODLOCALORIG ORDER BY DTENTRADA ASC)
                    LOOP
                            --se quantidade mais aintiga for = a quantidade da nota
                            --Deletamos a linha.
                            --forçamos a saída para o próximo produto da nota.
                        IF (Y.QTDNEG = PQTD) THEN
                            DELETE FROM AD_PRODDTENT AA WHERE AA.ID = Y.ID;
                            EXIT;
                        END IF;
                            --se quantidade mais antiga for < que a quantidade da nota
                            --deletamos a linha
                            --armazenamos a diferença para andarmos para o segundo produto mais antigo.
                        IF (Y.QTDNEG < PQTD) THEN
                            DELETE FROM AD_PRODDTENT AA WHERE AA.ID = Y.ID;
                            PQTD := PQTD - Y.QTDNEG;
                        END IF;
                            --se quantidade mais antiga for > que a quantidade da nota
                            --armazenamos a diferença 
                            --e atualizamos o produto mais antigo com o restante.
                            --forçamos a saída para o próximo produto da nota.
                        IF (Y.QTDNEG > PQTD) THEN
                           PQTD := Y.QTDNEG - PQTD;
                           UPDATE AD_PRODDTENT ENT SET ENT.QTDNEG = PQTD WHERE ENT.ID = Y.ID;
                            EXIT;
                        END IF;
                    END LOOP;
                END IF;
            END LOOP;
        END IF;    
   END IF;
    
    --Deleta produtos da tabela AD_PRODDTENT caso seja das tops abeixo e quando estiverem confirmadas.
    --OBS.: Esses produtos na verdade são atualizados até que tenha quantidade = 1 depois deletados.
    IF :NEW.CODTIPOPER IN (3202, 3204, 3214, 3213, 3216, 3205, 3218, 3003) THEN
        IF (:OLD.STATUSNOTA  <> :NEW.STATUSNOTA) AND (:NEW.STATUSNOTA = 'C') THEN
            FOR I IN (SELECT ITE.CODPROD, ITE.QTDNEG, ITE.CODLOCALORIG FROM TGFITE ITE WHERE ITE.NUNOTA = :NEW.NUNOTA)
            LOOP
                INSERT INTO AD_PRODDTENT (ID, NUNOTA, CODPROD, DTENTRADA, QTDNEG, CODLOCAL, CODEMP, CODUSU, CODTIPOPER) VALUES ((SELECT MAX(ID)+1 FROM AD_PRODDTENT),:NEW.NUNOTA, I.CODPROD, :NEW.DTFATUR, I.QTDNEG, I.CODLOCALORIG, :NEW.CODEMP, :NEW.CODUSU, :NEW.CODTIPOPER);
            END LOOP;
        END IF;
        IF (:OLD.STATUSNOTA  <> :NEW.STATUSNOTA) AND (:NEW.STATUSNOTA = 'L') THEN
            --Percorremos os produtos da nota
            FOR I IN (SELECT ITE.CODPROD, ITE.QTDNEG, ITE.CODLOCALORIG FROM TGFITE ITE WHERE ITE.NUNOTA = :NEW.NUNOTA)
            LOOP
                --Variável recebe quandidade da nota.
                PQTD := I.QTDNEG;
                --Percorremos os produtos que estão na tabela organizados pela data mais atiga.
                FOR Y IN (SELECT * FROM AD_PRODDTENT AD WHERE AD.CODPROD = I.CODPROD AND AD.CODEMP = :NEW.CODEMP AND AD.CODLOCAL = I.CODLOCALORIG ORDER BY DTENTRADA ASC)
                LOOP
                        --se quantidade mais aintiga for = a quantidade da nota
                        --Deletamos a linha.
                        --forçamos a saída para o próximo produto da nota.
                    IF (Y.QTDNEG = PQTD) THEN
                        DELETE FROM AD_PRODDTENT AA WHERE AA.ID = Y.ID;
                        EXIT;
                    END IF;
                        --se quantidade mais antiga for < que a quantidade da nota
                        --deletamos a linha
                        --armazenamos a diferença para andarmos para o segundo produto mais antigo.
                    IF (Y.QTDNEG < PQTD) THEN
                        DELETE FROM AD_PRODDTENT AA WHERE AA.ID = Y.ID;
                        PQTD := PQTD - Y.QTDNEG;
                    END IF;
                        --se quantidade mais antiga for > que a quantidade da nota
                        --armazenamos a diferença 
                        --e atualizamos o produto mais antigo com o restante.
                        --forçamos a saída para o próximo produto da nota.
                    IF (Y.QTDNEG > PQTD) THEN
                       PQTD := Y.QTDNEG - PQTD;
                       UPDATE AD_PRODDTENT ENT SET ENT.QTDNEG = PQTD WHERE ENT.ID = Y.ID;
                        EXIT;
                    END IF;
                END LOOP;
            END LOOP;
        END IF;
    END IF;
    
END;
/
