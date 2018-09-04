CREATE OR REPLACE PROCEDURE TOTALPRD."GER_VEND_METAS_TOTAL" (
       P_CODUSU NUMBER,        -- Código do usuário logado
       P_IDSESSAO VARCHAR2,    -- Identificador da execução. Serve para buscar informações dos parâmetros/campos da execução.
       P_QTDLINHAS NUMBER,     -- Informa a quantidade de registros selecionados no momento da execução.
       P_MENSAGEM OUT VARCHAR2 -- Caso seja passada uma mensagem aqui, ela será exibida como uma informação ao usuário.
) AS
       PARAM_CODGER VARCHAR2(4000);
       PARAM_RECALC CHAR;
       FIELD_ID NUMBER;
       CONT INT;
BEGIN

       -- Os valores informados pelo formulário de parâmetros, podem ser obtidos com as funções:
       --     ACT_INT_PARAM
       --     ACT_DEC_PARAM
       --     ACT_TXT_PARAM
       --     ACT_DTA_PARAM
       -- Estas funções recebem 2 argumentos:
       --     ID DA SESSÃO - Identificador da execução (Obtido através de P_IDSESSAO))
       --     NOME DO PARAMETRO - Determina qual parametro deve se deseja obter.

       PARAM_CODGER := ACT_TXT_PARAM(P_IDSESSAO, 'CODGER');
       PARAM_RECALC := ACT_TXT_PARAM(P_IDSESSAO, 'RECALC');

       FOR I IN 1..P_QTDLINHAS -- Este loop permite obter o valor de campos dos registros envolvidos na execução.
       LOOP                    -- A variável "I" representa o registro corrente.
           -- Para obter o valor dos campos utilize uma das seguintes funções:
           --     ACT_INT_FIELD (Retorna o valor de um campo tipo NUMÉRICO INTEIRO))
           --     ACT_DEC_FIELD (Retorna o valor de um campo tipo NUMÉRICO DECIMAL))
           --     ACT_TXT_FIELD (Retorna o valor de um campo tipo TEXTO),
           --     ACT_DTA_FIELD (Retorna o valor de um campo tipo DATA)
           -- Estas funções recebem 3 argumentos:
           --     ID DA SESSÃO - Identificador da execução (Obtido através do parâmetro P_IDSESSAO))
           --     NÚMERO DA LINHA - Relativo a qual linha selecionada.
           --     NOME DO CAMPO - Determina qual campo deve ser obtido.
           FIELD_ID := ACT_INT_FIELD(P_IDSESSAO, I, 'ID');
           
--           RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
--    --                  Vendedor(a) CÓD: '||TO_CHAR(PARAM_RECALC)||' .</font></b><br><font>');

           
            IF NVL(PARAM_RECALC, 'N') = 'S' THEN
                FOR IUPDATE IN (SELECT CODVEND
                                  , VALOR
                                  , TOTAL
                                  , ROUND((VALOR/TOTAL)*100,4) AS PERC 
                             FROM (
                                   SELECT VEN.CODVEND
                                                , NVL((SELECT SUM(CAB.VLRNOTA)
                                                  FROM TGFCAB CAB
                                                  WHERE CAB.CODTIPOPER = 3200
                                                    AND CAB.STATUSNFE = 'A'
                                                    AND CAB.CODVEND = VEN.CODVEND
                                                    AND TRUNC(CAB.DTFATUR) BETWEEN ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (TO_DATE(SYSDATE, 'DD/MM/YYYY'),'MONTH'),'DD/MM/YY'),0),'MONTH'),'DD/MM/YY'),-1)
                                                                               AND ADD_MONTHS (TO_DATE (LAST_DAY (TO_DATE(SYSDATE, 'DD/MM/YYYY')),'DD/MM/YY'),-1)),0) 
                                                        AS VALOR
                                                , (SELECT SUM(CAB.VLRNOTA)
                                                   FROM TGFCAB CAB
                                                   WHERE CAB.CODTIPOPER = 3200
                                                     AND CAB.STATUSNFE = 'A'
                                                     AND CAB.CODVEND IN (SELECT CODVEND FROM AD_GRUPROSPRODMETVEN WHERE ID = FIELD_ID)
                                                     AND TRUNC(CAB.DTFATUR) BETWEEN ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (TO_DATE(SYSDATE, 'DD/MM/YYYY'),'MONTH'),'DD/MM/YY'),0),'MONTH'),'DD/MM/YY'),-1)
                                                                                    AND ADD_MONTHS (TO_DATE (LAST_DAY (TO_DATE(SYSDATE, 'DD/MM/YYYY')),'DD/MM/YY'),-1)) 
                                                        AS TOTAL
                            FROM TGFVEN VEN INNER JOIN AD_GRUPROSPRODMETVEN AD ON (VEN.CODVEND = AD.CODVEND))
                            ORDER BY PERC, CODVEND)
                LOOP
                    UPDATE AD_GRUPROSPRODMETVEN A SET PERCVEND = IUPDATE.PERC, METVEND = IUPDATE.VALOR WHERE CODVEND = IUPDATE.CODVEND AND ID = FIELD_ID;
                END LOOP;       
            ELSE --------------------------------insere novos vendedores
               SELECT COUNT(*)
               INTO CONT
               FROM AD_GRUPROSPRODMETVEN AD
               WHERE AD.ID = FIELD_ID;
               
    --           IF CONT > 0 THEN
    --                DELETE FROM AD_GRUPROSPRODMETVEN;
    --           END IF;
               
               DELETE FROM  AD_GRUPROSPRODMETVEN A WHERE A.CODVENDGER = PARAM_CODGER AND A.ID = FIELD_ID;
               
               FOR IVEND IN (SELECT CODVEND
                                  , VALOR
                                  , TOTAL
                                  , ROUND((VALOR/TOTAL)*100,4) AS PERC 
                             FROM (
                                   SELECT VEN.CODVEND
                                                , NVL((SELECT SUM(CAB.VLRNOTA)
                                                  FROM TGFCAB CAB
                                                  WHERE CAB.CODTIPOPER = 3200
                                                    AND CAB.STATUSNFE = 'A'
                                                    AND CAB.CODVEND = VEN.CODVEND
                                                    AND TRUNC(CAB.DTFATUR) BETWEEN ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (TO_DATE(SYSDATE, 'DD/MM/YYYY'),'MONTH'),'DD/MM/YY'),0),'MONTH'),'DD/MM/YY'),-1)
                                                                               AND ADD_MONTHS (TO_DATE (LAST_DAY (TO_DATE(SYSDATE, 'DD/MM/YYYY')),'DD/MM/YY'),-1)),0) 
                                                        AS VALOR
                                                , (SELECT SUM(CAB.VLRNOTA)
                                                   FROM TGFCAB CAB
                                                   WHERE CAB.CODTIPOPER = 3200
                                                     AND CAB.STATUSNFE = 'A'
                                                     AND CAB.CODVEND IN (SELECT VEN.CODVEND FROM TGFVEN VEN WHERE CODGER = PARAM_CODGER)
                                                     AND TRUNC(CAB.DTFATUR) BETWEEN ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (TO_DATE(SYSDATE, 'DD/MM/YYYY'),'MONTH'),'DD/MM/YY'),0),'MONTH'),'DD/MM/YY'),-1)
                                                                                    AND ADD_MONTHS (TO_DATE (LAST_DAY (TO_DATE(SYSDATE, 'DD/MM/YYYY')),'DD/MM/YY'),-1)) 
                                                        AS TOTAL
                            FROM TGFVEN VEN 
                            WHERE CODGER = PARAM_CODGER)
                            ORDER BY PERC, CODVEND)
               LOOP
               
             SELECT COUNT(*)
               INTO CONT
               FROM AD_GRUPROSPRODMETVEN AD
               WHERE AD.ID = FIELD_ID;
               
                    IF CONT = 0 THEN
                        INSERT INTO AD_GRUPROSPRODMETVEN (ID, IDMETVEND,CODVEND, PERCVEND, METVEND, CODVENDGER) VALUES
                        (FIELD_ID, 1, IVEND.CODVEND, IVEND.PERC, IVEND.VALOR, PARAM_CODGER);
                    ELSE
                        INSERT INTO AD_GRUPROSPRODMETVEN (ID, IDMETVEND,CODVEND, PERCVEND, METVEND, CODVENDGER) VALUES
                        (FIELD_ID, (SELECT MAX(IDMETVEND) + 1 FROM AD_GRUPROSPRODMETVEN WHERE ID = FIELD_ID), IVEND.CODVEND, IVEND.PERC, IVEND.VALOR, PARAM_CODGER);
                    END IF;
    --                                  RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
    --                  Vendedor(a) CÓD: '||TO_CHAR(FIELD_ID)||' '||TO_CHAR(IVEND.CODVEND)||' '||TO_CHAR(IVEND.PERC)||' '||TO_CHAR(IVEND.VALOR)||' '||TO_CHAR(CONT)||'.</font></b><br><font>');

               END LOOP;
            END IF;

       END LOOP;




END;
/
