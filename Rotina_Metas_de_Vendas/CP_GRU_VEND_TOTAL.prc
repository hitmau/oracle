CREATE OR REPLACE PROCEDURE TOTALPRD."CP_GRU_VEND_TOTAL" (
       P_CODUSU NUMBER,        -- Código do usuário logado
       P_IDSESSAO VARCHAR2,    -- Identificador da execução. Serve para buscar informações dos parâmetros/campos da execução.
       P_QTDLINHAS NUMBER,     -- Informa a quantidade de registros selecionados no momento da execução.
       P_MENSAGEM OUT VARCHAR2 -- Caso seja passada uma mensagem aqui, ela será exibida como uma informação ao usuário.
) AS
       FIELD_ID NUMBER;
       PCODTIPOPER VARCHAR(100) := '3200';
       
       CONT2 INT;
       PK_GRUPO INT;
       CONT INT;
       CONTDIAS INT;
       CONTGRU INT;
       PCODUSU INT;
       PDATA_PK INT;
       OPCAOC INT;
       OPCAOR CHAR;
       ATUEMP CHAR := 'N';
       PARAM_CODGER INT;
       PARAM_CODGRU INT;
       PARAM_RECALC CHAR;
       RECMET CHAR;
       
       PPDATA DATE;
       INTDATA INT;
       
       PMSG VARCHAR(4000);
       
       PDTINI DATE;
       PDTFIN DATE;
       
       IDGRUVENDFILHOPK INT;
       IDIAVENDPK INT;
       IDEMPGRUFIPK INT;
       IEMPVEND INT;
       PVLRANOANT INT;
       IVENDDIAGRUPK INT;
BEGIN

/*
    Autor: Mauricio Rodrigues
    Data: 10/09/2018
    Descrição: Botão de ação chamado: Configurar metas, criado para;
        1. copiar todos os grupos anteriores
        2. Recalcular grupos de produtos ou subgrupos
        3. Inserir vendedores pelo grupo de usuário ou pelo gerente.
        4. Recalcular os vendedores caso seja inserido posteriormente.
        5. gerar ou atualizar o grupo de produtos para cada vendedor.
*/
        SELECT STP_GET_CODUSULOGADO() INTO PCODUSU FROM DUAL;
        
        EXECUTE IMMEDIATE 'ALTER TRIGGER AD_GRUPROSPRODMETVEN_TOTAL DISABLE';
        EXECUTE IMMEDIATE 'ALTER TRIGGER AD_GRUPOSPRODUSU_TOTAL DISABLE';
        
        --Parametros
        OPCAOC := ACT_INT_PARAM(P_IDSESSAO,'OPCAOC');    --Copia Grupos anteriores C = copiar
        OPCAOR := ACT_TXT_PARAM(P_IDSESSAO,'OPCAOR');    --Recalcula Grupos R = recalcular
        PARAM_CODGER := ACT_INT_PARAM(P_IDSESSAO,'CODGER');   --Insere vendedores por Gerente
        PARAM_CODGRU := ACT_INT_PARAM(P_IDSESSAO,'CODGRU');   --ou Insere vendedores por Grupo
        PARAM_RECALC := ACT_TXT_PARAM(P_IDSESSAO,'RECALC'); --Recalcula Vendedores
        RECMET := ACT_TXT_PARAM(P_IDSESSAO,'RECMET');   --Inserir/Recalcular grupos de Meta
        ATUEMP := ACT_TXT_PARAM(P_IDSESSAO,'ATUEMP');   --Inserir/Recalcular grupos de Meta
        PDTINI := ACT_DTA_PARAM(P_IDSESSAO,'DTINI');   --Inserir/Recalcular grupos de Meta
        PDTFIN := ACT_DTA_PARAM(P_IDSESSAO,'DTFIN');   --Inserir/Recalcular grupos de Meta
       -- Os valores informados pelo formulário de parâmetros, podem ser obtidos com as funções:
       --     ACT_INT_PARAM
       --     ACT_DEC_PARAM
       --     ACT_TXT_PARAM
       --     ACT_DTA_PARAM
       -- Estas funções recebem 2 argumentos:
       --     ID DA SESSÃO - Identificador da execução (Obtido através de P_IDSESSAO))
       --     NOME DO PARAMETRO - Determina qual parametro deve se deseja obter.


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
        --SE COPIAR
        IF OPCAOC IS NOT NULL THEN

            --VERIFICA SE O GRUPO DE METAS SELECIONADO TEM GRUPOS INSERIDOS.
            SELECT COUNT(*)
            INTO CONT
            FROM AD_GRUPOSPRODUSU
            WHERE ID = OPCAOC;
            
            IF CONT = 0 THEN
                PMSG := 'Meta anterior (Cód.: ' || to_char(FIELD_ID -1) || ') não tem nenhum grupo, utilize o código que não contém grupos ou exclua-o! <br>';
                EXIT;
            ELSE
                --Grupos do dia
                DELETE FROM AD_GRUDIAS WHERE ID = FIELD_ID;
                --Grupo de metas por dias
                DELETE FROM AD_GRUMETDIAS WHERE ID = FIELD_ID;
                --Grupos da meta por dia
                DELETE FROM AD_GRUPOSPRODUSUDIA WHERE ID = FIELD_ID;
                --DELETA TODOS OS REGISTRO IGUAIS AOS REGISTROS DA LINHA ANTERIOR, CASO HAJA REGISTROS INSERIDOS MANUALMENTE, QUA NÃO EXISTE NA LINHA ANTERIOR, NÃO SERÃO AFETADOS.
                DELETE FROM AD_GRUPOSPRODUSU A WHERE A.ID = FIELD_ID AND A.CODGRUPOPROD IN (SELECT CODGRUPOPROD
                FROM AD_GRUPOSPRODUSU
                WHERE ID = FIELD_ID);
------------------------------------------------------------------------------------------------------------------------------------------------------------
--INICIA FOR DOS GRUPOS
------------------------------------------------------------------------------------------------------------------------------------------------------------
                FOR IGRU IN (SELECT GRUPO, TOTALZAO, TOTAL, 10 AS PERC
                             FROM (
                                   SELECT ADA.CODGRUPOPROD AS GRUPO
                                        --TOTALZAO      
                                        , (SELECT SUM(TT) 
                                           FROM (
                                                 SELECT AD.CODGRUPOPROD
                                                      , SUM( ((ITE.VLRTOT - ITE.VLRDESC - ITE.VLRREPRED + ITE.VLRSUBST + ITE.VLRIPI)  * VCA.INDITENSBRUTO) * CASE WHEN TOP.BONIFICACAO = 'S' THEN 0 ELSE 1 END * TOP.GOLDEV ) AS TT
                                                 FROM TGFCAB CAB INNER JOIN TGFITE ITE ON (CAB.NUNOTA = ITE.NUNOTA)
                                                                 INNER JOIN TGFPRO PRO ON (ITE.CODPROD = PRO.CODPROD)
                                                                 INNER JOIN VGFCAB VCA ON (CAB.NUNOTA = VCA.NUNOTA)
                                                                 INNER JOIN TGFTOP TOP ON (CAB.CODTIPOPER = TOP.CODTIPOPER AND CAB.DHTIPOPER = TOP.DHALTER AND TOP.GOLSINAL = -1)
                                                                 , AD_GRUPOSPRODUSU AD
                                                 WHERE CAB.CODTIPOPER IN (SELECT REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''),'[^,]+', 1, LEVEL) AS RESULTADO FROM DUAL CONNECT BY REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''), '[^,]+', 1, LEVEL) IS NOT NULL)
                                                   AND CAB.STATUSNFE= 'A'
                                                   --LOCALIZA GRUPO INDEPENDENTE DO NIVEL
                                                   AND (SELECT (CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = OPCAOC AND  G2.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))) IS NOT NULL  
                                                                     THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = OPCAOC AND  G2.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))
                                                                     ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = OPCAOC AND  G2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))) IS NOT NULL
                                                                               THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = OPCAOC AND  G2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))
                                                                               ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = OPCAOC AND  G2.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))) IS NOT NULL
                                                                                           THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = OPCAOC AND  G2.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))
                                                                                           ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = OPCAOC AND  G2.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))) IS NOT NULL
                                                                                                   THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = OPCAOC AND  G2.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))
                                                                                                   ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = OPCAOC AND  G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))) IS NOT NULL
                                                                                                               THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = OPCAOC AND  G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))))
                                                                                                               ELSE TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = OPCAOC AND  G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU5.CODGRUPAI FROM TGFGRU GRU5 WHERE GRU5.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))))
                                                                                                        END
                                                                                                   
                                                                                                END 
                                                                                           
                                                                                    END 
                                                                               
                                                                          END 
                                                                END) 
                                                        FROM TGFGRU GG 
                                                        WHERE GG.CODGRUPOPROD = PRO.CODGRUPOPROD) = AD.CODGRUPOPROD
                                                   --
                                                   AND TRUNC(CAB.DTFATUR) BETWEEN PDTINI AND PDTFIN
--                                                                        --Data do mesmo período no ano passado.        
--                                                                        ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (TO_DATE(SYSDATE, 'DD/MM/YYYY'),'MONTH'),'DD/MM/YY'),-11),'MONTH'),'DD/MM/YY'),-1)
--                                                                        AND ADD_MONTHS (TO_DATE (LAST_DAY (TO_DATE(SYSDATE, 'DD/MM/YYYY')),'DD/MM/YY'),-12)
                                                   AND AD.ID = OPCAOC
                                              GROUP BY AD.CODGRUPOPROD)) AS TOTALZAO
                                        --TOTALZAO
                                       , SUM( ((ITE.VLRTOT - ITE.VLRDESC - ITE.VLRREPRED + ITE.VLRSUBST + ITE.VLRIPI)  * VCA.INDITENSBRUTO) * CASE WHEN TOP.BONIFICACAO = 'S' THEN 0 ELSE 1 END * TOP.GOLDEV ) AS TOTAL
                                   FROM TGFCAB CAB INNER JOIN TGFITE ITE ON (CAB.NUNOTA = ITE.NUNOTA)
                                                   INNER JOIN TGFPRO PRO ON (ITE.CODPROD = PRO.CODPROD)
                                                   INNER JOIN VGFCAB VCA ON (CAB.NUNOTA = VCA.NUNOTA)
                                                   INNER JOIN TGFTOP TOP ON (CAB.CODTIPOPER = TOP.CODTIPOPER AND CAB.DHTIPOPER = TOP.DHALTER AND TOP.GOLSINAL = -1)
                                                   , AD_GRUPOSPRODUSU ADA
                                   WHERE CAB.CODTIPOPER IN (SELECT REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''),'[^,]+', 1, LEVEL) AS RESULTADO FROM DUAL CONNECT BY REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''), '[^,]+', 1, LEVEL) IS NOT NULL)
                                     AND CAB.STATUSNFE = 'A'
                                     --LOCALIZA GRUPO INDEPENDENTE DO NIVEL
                                     AND (SELECT (CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = OPCAOC AND  G2.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))) IS NOT NULL  
                                                       THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = OPCAOC AND  G2.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))
                                                       ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = OPCAOC AND  G2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))) IS NOT NULL
                                                           THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = OPCAOC AND  G2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))
                                                           ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = OPCAOC AND  G2.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))) IS NOT NULL
                                                                       THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = OPCAOC AND  G2.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))
                                                                       ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = OPCAOC AND  G2.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))) IS NOT NULL
                                                                               THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = OPCAOC AND  G2.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))
                                                                               ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = OPCAOC AND  G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))) IS NOT NULL
                                                                                           THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = OPCAOC AND  G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))))
                                                                                           ELSE TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = OPCAOC AND  G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU5.CODGRUPAI FROM TGFGRU GRU5 WHERE GRU5.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))))
                                                                                   END
                                                                               
                                                                           END 
                                                                       
                                                               END 
                                                           
                                                           END 
                                     END) 
                                   FROM TGFGRU GG 
                                   WHERE GG.CODGRUPOPROD = PRO.CODGRUPOPROD) = ADA.CODGRUPOPROD
                                     AND TRUNC(CAB.DTFATUR) BETWEEN PDTINI AND PDTFIN
                                     AND ADA.ID = OPCAOC 
                             GROUP BY ADA.CODGRUPOPROD)
                             ORDER BY PERC) 
                LOOP
                    SELECT COUNT(*)
                    INTO CONT
                    FROM AD_GRUPOSPRODUSU AD
                    WHERE AD.ID = FIELD_ID;
                    
                    IF CONT = 0 THEN
                        PK_GRUPO := 1;
                        INSERT INTO AD_GRUPOSPRODUSU (ID, IDGRU, CODGRUPOPROD, META, DATA, CODUSU, SUGESTAO, PERC) VALUES
                        (FIELD_ID, PK_GRUPO,IGRU.GRUPO, IGRU.TOTAL,SYSDATE, PCODUSU, ((IGRU.TOTAL*0.10)+IGRU.TOTAL), IGRU.PERC);
                    ELSE
                        SELECT MAX(IDGRU) + 1 
                        INTO PK_GRUPO
                        FROM AD_GRUPOSPRODUSU;
                        
                        INSERT INTO AD_GRUPOSPRODUSU (ID, IDGRU, CODGRUPOPROD, META, DATA, CODUSU, SUGESTAO, PERC) VALUES
                        (FIELD_ID, PK_GRUPO,IGRU.GRUPO, IGRU.TOTAL,SYSDATE, PCODUSU, ((IGRU.TOTAL*0.10)+IGRU.TOTAL), IGRU.PERC);
                    END IF;
------------------------------------------------------------------------------------------------------------------------------------------------------------
--INICIA FOR DOS GRUPOS POR DIAS
------------------------------------------------------------------------------------------------------------------------------------------------------------
                    FOR IGRU2 IN (SELECT GRUPO
                                       , DATA
                                       , FATUR
                                       , TOTAL
                                       , ((TOTAL / IGRU.TOTAL) * 100) AS PER 
                                  FROM ( 
                                       SELECT ADA.CODGRUPOPROD AS GRUPO
                                            , TO_CHAR(TRUNC(CAB.DTFATUR), 'd') AS DATA
                                            , TRUNC(CAB.DTFATUR) AS FATUR
                                            , SUM( ((ITE.VLRTOT - ITE.VLRDESC - ITE.VLRREPRED + ITE.VLRSUBST + ITE.VLRIPI)  * VCA.INDITENSBRUTO) * CASE WHEN TOP.BONIFICACAO = 'S' THEN 0 ELSE 1 END * TOP.GOLDEV ) AS TOTAL
                                       FROM TGFCAB CAB INNER JOIN TGFITE ITE ON (CAB.NUNOTA = ITE.NUNOTA)
                                                       INNER JOIN TGFPRO PRO ON (ITE.CODPROD = PRO.CODPROD)
                                                       INNER JOIN VGFCAB VCA ON (CAB.NUNOTA = VCA.NUNOTA)
                                                       INNER JOIN TGFTOP TOP ON (CAB.CODTIPOPER = TOP.CODTIPOPER AND CAB.DHTIPOPER = TOP.DHALTER AND TOP.GOLSINAL = -1)
                                                       , AD_GRUPOSPRODUSU ADA
                                       WHERE CAB.CODTIPOPER IN (SELECT REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''),'[^,]+', 1, LEVEL) AS RESULTADO FROM DUAL CONNECT BY REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''), '[^,]+', 1, LEVEL) IS NOT NULL)
                                         AND CAB.STATUSNFE= 'A'
                                         --LOCALIZA GRUPO INDEPENDENTE DO NIVEL
                                         AND (SELECT (CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND G2.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))) IS NOT NULL  
                                                           THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND G2.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))
                                                           ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND G2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))) IS NOT NULL
                                                               THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND G2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))
                                                               ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND G2.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))) IS NOT NULL
                                                                           THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND G2.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))
                                                                           ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND G2.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))) IS NOT NULL
                                                                                   THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND G2.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))
                                                                                   ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))) IS NOT NULL
                                                                                               THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))))
                                                                                               ELSE TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU5.CODGRUPAI FROM TGFGRU GRU5 WHERE GRU5.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))))
                                                                                       END
                                                                                   
                                                                               END 
                                                                           
                                                                   END 
                                                               
                                                               END 
                                                     END) 
                                              FROM TGFGRU GG
                                              WHERE GG.CODGRUPOPROD = PRO.CODGRUPOPROD) = ADA.CODGRUPOPROD
                                         AND TRUNC(CAB.DTFATUR) BETWEEN PDTINI AND PDTFIN
                                         AND ADA.ID = FIELD_ID 
                                         AND ADA.CODGRUPOPROD = IGRU.GRUPO
                                       GROUP BY ADA.CODGRUPOPROD, TO_CHAR(TRUNC(CAB.DTFATUR), 'd'), TRUNC(CAB.DTFATUR)
                                    ORDER BY FATUR))
                    LOOP
                        SELECT COUNT(*)
                        INTO CONTDIAS
                        FROM AD_GRUPOSPRODUSUDIA AD
                        WHERE AD.ID = FIELD_ID
                          AND AD.IDGRU = PK_GRUPO;
                        
                        IF CONTDIAS = 0 THEN
                            INSERT INTO AD_GRUPOSPRODUSUDIA (ID, IDGRU,IDMETDIA, CODGRUPOPROD, DIAANOANT, PERCRES, PESO, METADIA, DATA) VALUES
                            (FIELD_ID, PK_GRUPO,1, IGRU2.GRUPO, IGRU2.TOTAL,10, IGRU2.PER, ((IGRU2.TOTAL/100)* 10)+IGRU2.TOTAL, IGRU2.FATUR);
                        ELSE
                            INSERT INTO AD_GRUPOSPRODUSUDIA (ID, IDGRU,IDMETDIA, CODGRUPOPROD, DIAANOANT, PERCRES, PESO, METADIA,DATA) VALUES
                            (FIELD_ID, PK_GRUPO, (SELECT MAX(IDMETDIA) + 1 FROM AD_GRUPOSPRODUSUDIA AD WHERE AD.ID = FIELD_ID AND AD.IDGRU = PK_GRUPO), IGRU2.GRUPO, IGRU2.TOTAL,10, IGRU2.PER, ((IGRU2.TOTAL/100)* 10)+IGRU2.TOTAL, IGRU2.FATUR); 
                        END IF;
                        
                        --VERIFICA SE EXISTE REGISTRO DE DATA
                        SELECT COUNT(IDGRUMETDIAS)
                        INTO CONT2
                        FROM AD_GRUMETDIAS
                        WHERE id = FIELD_ID and IDGRUMETDIAS = IGRU2.FATUR;

                        IF CONT2 = 0 THEN
                            --insere nova data
                            INSERT INTO AD_GRUMETDIAS (ID, IDGRUMETDIAS, METAGRUDIA, CODGRUPOPROD) VALUES (FIELD_ID, IGRU2.FATUR,IGRU.TOTAL, IGRU.GRUPO); --IGRU.TOTAL
                            
                            SELECT COUNT(*)
                            INTO PDATA_PK
                            FROM AD_GRUDIAS DIAS
                            WHERE DIAS.ID = FIELD_ID
                              AND DIAS.IDGRUMETDIAS = IGRU2.FATUR;
                              
                            IF PDATA_PK = 0 THEN
                                PDATA_PK := 1;
                                INSERT INTO AD_GRUDIAS (ID, IDGRUMETDIAS, IDGRUDIAS2, CODGRUPOPROD, DIAANOANTINV, PESO, PERCRES, METADIA) VALUES
                                (FIELD_ID, IGRU2.FATUR, PDATA_PK, IGRU2.GRUPO,IGRU2.TOTAL, IGRU2.PER, 10, ((IGRU2.TOTAL/100)* 10)+IGRU2.TOTAL);
                            ELSE
                                SELECT MAX(IDGRUDIAS2) + 1
                                INTO PDATA_PK
                                FROM AD_GRUDIAS DIAS
                                WHERE DIAS.ID = FIELD_ID
                                  AND DIAS.IDGRUMETDIAS = IGRU2.FATUR;
                                  
                                INSERT INTO AD_GRUDIAS (ID, IDGRUMETDIAS, IDGRUDIAS2, CODGRUPOPROD, DIAANOANTINV, PESO, PERCRES, METADIA) VALUES
                                (FIELD_ID, IGRU2.FATUR, PDATA_PK, IGRU2.GRUPO,IGRU2.TOTAL, IGRU2.PER, 10, ((IGRU2.TOTAL/100)* 10)+IGRU2.TOTAL);
                            END IF;
                        ELSE
                            SELECT MAX(IDGRUDIAS2) + 1
                            INTO PDATA_PK
                            FROM AD_GRUDIAS DIAS
                            WHERE DIAS.ID = FIELD_ID
                              AND DIAS.IDGRUMETDIAS = IGRU2.FATUR;
                              
                            INSERT INTO AD_GRUDIAS (ID, IDGRUMETDIAS, IDGRUDIAS2, CODGRUPOPROD, DIAANOANTINV, PESO, PERCRES, METADIA) VALUES
                            (FIELD_ID, IGRU2.FATUR, PDATA_PK, IGRU2.GRUPO,IGRU2.TOTAL, IGRU2.PER, 10, ((IGRU2.TOTAL/100)* 10)+IGRU2.TOTAL);
                        END IF; 
                    END LOOP;  --FIM DO FOR DA INSERÇÃO DOS DIAS DOS GRUPOS      
                END LOOP; --FIM DO FOR DA INSERÇÃO DOS GRUPOS
                
--                    FOR IRESTO IN (SELECT A.CODGRUPOPROD AS GRUPO
--                            FROM AD_GRUPOSPRODUSU A 
--                            WHERE A.ID = OPCAOC
--                              AND A.CODGRUPOPROD NOT IN (SELECT B.CODGRUPOPROD
--                                                         FROM AD_GRUPOSPRODUSU B
--                                                         WHERE B.ID = FIELD_ID))
--                    LOOP
--                        SELECT COUNT(*)
--                        INTO CONT
--                        FROM AD_GRUPOSPRODUSU AD
--                        WHERE AD.ID = FIELD_ID;
--                        
--                        IF CONT = 0 THEN
--                            INSERT INTO AD_GRUPOSPRODUSU (ID, IDGRU, CODGRUPOPROD, META, DATA, CODUSU, SUGESTAO, PERC) VALUES
--                            (FIELD_ID, 1,IRESTO.GRUPO, 0,SYSDATE, PCODUSU, 0, 0);
--                        ELSE
--                            INSERT INTO AD_GRUPOSPRODUSU (ID, IDGRU, CODGRUPOPROD, META, DATA, CODUSU, SUGESTAO, PERC) VALUES
--                            (FIELD_ID, (SELECT MAX(IDGRU) + 1 FROM AD_GRUPOSPRODUSU),IRESTO.GRUPO, 0,SYSDATE, PCODUSU, 0, 0);
--                    END IF;
--                    END LOOP;
                    PMSG := PMSG || 'Dados dos grupos copiados com sucesso! <br>';
           END IF; --FINALIZA OPÇÃO DE COPIAR 
------------------------------------------------------------------------------------------------------------------------------------------------------------
--INICIA FOR DOS GRUPOS PARA "RECALCULAR GRUPOS" INSERIDOS POSTERIORMENTE.
------------------------------------------------------------------------------------------------------------------------------------------------------------      
        ELSIF NVL(OPCAOR, 'N') = 'S' THEN
            SELECT COUNT(*)
            INTO CONT
            FROM AD_GRUPOSPRODUSU
            WHERE ID = FIELD_ID;
            
        IF CONT = 0 THEN
            PMSG := PMSG || 'Não existe grupo registro para recalcular. (Cód.: ' || to_char(FIELD_ID) || ')<br>';
            EXIT; 
        ELSE
            DELETE FROM AD_GRUPOSPRODUSUDIA WHERE ID = FIELD_ID;
        
            FOR IUPDATE IN (SELECT GRUPO
                                 , TOTALZAO
                                 , TOTAL 
                                 , PERC 
                                 , ((TOTAL*PERC)/100)+TOTAL AS SUGESTAO
                                FROM (
                                      SELECT ADA.CODGRUPOPROD AS GRUPO
                                           , ADA.PERC
                                           ---TOTALZAO
                                           , (SELECT SUM(TT) 
                                              FROM (
                                                   SELECT AD.CODGRUPOPROD
                                                        , SUM( ((ITE.VLRTOT - ITE.VLRDESC - ITE.VLRREPRED + ITE.VLRSUBST + ITE.VLRIPI)  * VCA.INDITENSBRUTO) * CASE WHEN TOP.BONIFICACAO = 'S' THEN 0 ELSE 1 END * TOP.GOLDEV ) AS TT
                                                   --NOVO
                                                   FROM TGFCAB CAB INNER JOIN TGFITE ITE ON (CAB.NUNOTA = ITE.NUNOTA)
                                                                   INNER JOIN TGFPRO PRO ON (ITE.CODPROD = PRO.CODPROD)
                                                                   INNER JOIN VGFCAB VCA ON (CAB.NUNOTA = VCA.NUNOTA)
                                                                   INNER JOIN TGFTOP TOP ON (CAB.CODTIPOPER = TOP.CODTIPOPER AND CAB.DHTIPOPER = TOP.DHALTER AND TOP.GOLSINAL = -1)
                                                                   , AD_GRUPOSPRODUSU AD
                                                   WHERE CAB.CODTIPOPER IN (SELECT REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''),'[^,]+', 1, LEVEL) AS RESULTADO FROM DUAL CONNECT BY REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''), '[^,]+', 1, LEVEL) IS NOT NULL)
                                                     AND CAB.STATUSNFE= 'A'
                                                     -----LOCALIZA GRUPO INDEPENDENTE DO NIVEL
                                                     AND (SELECT (CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = FIELD_ID AND  G2.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))) IS NOT NULL  
                                                                       THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = FIELD_ID AND  G2.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))
                                                                       ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = FIELD_ID AND  G2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))) IS NOT NULL
                                                                           THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = FIELD_ID AND  G2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))
                                                                           ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = FIELD_ID AND  G2.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))) IS NOT NULL
                                                                                       THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = FIELD_ID AND  G2.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))
                                                                                       ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = FIELD_ID AND  G2.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))) IS NOT NULL
                                                                                               THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = FIELD_ID AND  G2.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))
                                                                                               ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = FIELD_ID AND  G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))) IS NOT NULL
                                                                                                           THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = FIELD_ID AND  G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))))
                                                                                                           ELSE TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = FIELD_ID AND  G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU5.CODGRUPAI FROM TGFGRU GRU5 WHERE GRU5.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))))
                                                                                                   END
                                                                                               
                                                                                           END 
                                                                                       
                                                                               END 
                                                                           
                                                                           END 
                                                     END) FROM TGFGRU GG 
                                                          WHERE GG.CODGRUPOPROD = PRO.CODGRUPOPROD) = AD.CODGRUPOPROD
                                                     -----
                                                     AND TRUNC(CAB.DTFATUR) BETWEEN PDTINI AND PDTFIN
                                                     AND AD.ID = FIELD_ID
                                                   --NOVO
                                                   GROUP BY AD.CODGRUPOPROD)) AS TOTALZAO,
                                       ---TOTALZAO
                                      SUM( ((ITE.VLRTOT - ITE.VLRDESC - ITE.VLRREPRED + ITE.VLRSUBST + ITE.VLRIPI)  * VCA.INDITENSBRUTO) * CASE WHEN TOP.BONIFICACAO = 'S' THEN 0 ELSE 1 END * TOP.GOLDEV ) AS TOTAL
                                FROM TGFCAB CAB INNER JOIN TGFITE ITE ON (CAB.NUNOTA = ITE.NUNOTA)
                                                INNER JOIN TGFPRO PRO ON (ITE.CODPROD = PRO.CODPROD)
                                                INNER JOIN VGFCAB VCA ON (CAB.NUNOTA = VCA.NUNOTA)
                                                INNER JOIN TGFTOP TOP ON (CAB.CODTIPOPER = TOP.CODTIPOPER AND CAB.DHTIPOPER = TOP.DHALTER AND TOP.GOLSINAL = -1)
                                                , AD_GRUPOSPRODUSU ADA
                                WHERE CAB.CODTIPOPER IN (SELECT REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''),'[^,]+', 1, LEVEL) AS RESULTADO FROM DUAL CONNECT BY REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''), '[^,]+', 1, LEVEL) IS NOT NULL)
                                  AND CAB.STATUSNFE= 'A'
                                  -----LOCALIZA GRUPO INDEPENDENTE DO NIVEL
                                  AND (SELECT (CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = FIELD_ID AND  G2.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))) IS NOT NULL  
                                                    THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = FIELD_ID AND  G2.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))
                                                    ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = FIELD_ID AND  G2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))) IS NOT NULL
                                                        THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = FIELD_ID AND  G2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))
                                                        ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = FIELD_ID AND  G2.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))) IS NOT NULL
                                                                    THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = FIELD_ID AND  G2.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))
                                                                    ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = FIELD_ID AND  G2.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))) IS NOT NULL
                                                                            THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = FIELD_ID AND  G2.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))
                                                                            ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = FIELD_ID AND  G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))) IS NOT NULL
                                                                                        THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = FIELD_ID AND  G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))))
                                                                                        ELSE TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = FIELD_ID AND  G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU5.CODGRUPAI FROM TGFGRU GRU5 WHERE GRU5.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))))
                                                                                END
                                                                            
                                                                        END 
                                                                    
                                                            END 
                                                        
                                                        END 
                                  END) FROM TGFGRU GG WHERE GG.CODGRUPOPROD = PRO.CODGRUPOPROD) = ADA.CODGRUPOPROD
                                  -----
                                  AND TRUNC(CAB.DTFATUR) BETWEEN PDTINI AND PDTFIN
                                  AND ADA.ID = FIELD_ID
                                GROUP BY ADA.CODGRUPOPROD, ADA.PERC)
                                ORDER BY PERC)
            LOOP
                UPDATE AD_GRUPOSPRODUSU SET CODUSU = PCODUSU, PERC = NVL(IUPDATE.PERC,10), META = IUPDATE.TOTAL, SUGESTAO = NVL(IUPDATE.SUGESTAO, ((IUPDATE.TOTAL*10)/100+IUPDATE.TOTAL)) WHERE ID = FIELD_ID AND CODGRUPOPROD = IUPDATE.GRUPO;
                
                SELECT IDGRU 
                INTO PK_GRUPO
                FROM AD_GRUPOSPRODUSU
                WHERE ID = FIELD_ID 
                  AND CODGRUPOPROD = IUPDATE.GRUPO;
------------------------------------------------------------------------------------------------------------------------------------------------------------
--INICIA FOR DOS GRUPOS POR DIA, PARA "RECALCULAR" INSERIDOS POSTERIORMENTE.
------------------------------------------------------------------------------------------------------------------------------------------------------------     
            FOR IGRU2 IN (SELECT GRUPO, DATA, FATUR,  TOTAL, ((TOTAL / IUPDATE.TOTAL) * 100) AS PER FROM ( 
                               SELECT ADA.CODGRUPOPROD AS GRUPO,
                                  TO_CHAR(TRUNC(CAB.DTFATUR), 'd') AS DATA,
                                  TRUNC(CAB.DTFATUR) AS FATUR,
                                  --ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (TO_DATE(SYSDATE, 'DD/MM/YYYY'),'MONTH'),'DD/MM/YY'),-11),'MONTH'),'DD/MM/YY'),-1) AS DIAS,
                                  SUM( ((ITE.VLRTOT - ITE.VLRDESC - ITE.VLRREPRED + ITE.VLRSUBST + ITE.VLRIPI)  * VCA.INDITENSBRUTO) * CASE WHEN TOP.BONIFICACAO = 'S' THEN 0 ELSE 1 END * TOP.GOLDEV ) AS TOTAL
                            FROM TGFCAB CAB INNER JOIN TGFITE ITE ON (CAB.NUNOTA = ITE.NUNOTA)
                                            INNER JOIN TGFPRO PRO ON (ITE.CODPROD = PRO.CODPROD)
                                            INNER JOIN VGFCAB VCA ON (CAB.NUNOTA = VCA.NUNOTA)
                                            INNER JOIN TGFTOP TOP ON (CAB.CODTIPOPER = TOP.CODTIPOPER AND CAB.DHTIPOPER = TOP.DHALTER AND TOP.GOLSINAL = -1)
                                            , AD_GRUPOSPRODUSU ADA
                            WHERE CAB.CODTIPOPER IN (SELECT REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''),'[^,]+', 1, LEVEL) AS RESULTADO FROM DUAL CONNECT BY REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''), '[^,]+', 1, LEVEL) IS NOT NULL)
                              AND CAB.STATUSNFE= 'A'
                              -----LOCALIZA GRUPO INDEPENDENTE DO NIVEL
                              AND (SELECT (CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = FIELD_ID AND    G2.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))) IS NOT NULL  
                                                THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = FIELD_ID AND    G2.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))
                                                ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = FIELD_ID AND    G2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))) IS NOT NULL
                                                    THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = FIELD_ID AND    G2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))
                                                    ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = FIELD_ID AND    G2.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))) IS NOT NULL
                                                                THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = FIELD_ID AND    G2.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))
                                                                ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = FIELD_ID AND    G2.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))) IS NOT NULL
                                                                        THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = FIELD_ID AND    G2.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))
                                                                        ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = FIELD_ID AND    G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))) IS NOT NULL
                                                                                    THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = FIELD_ID AND    G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))))
                                                                                    ELSE TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = FIELD_ID AND    G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU5.CODGRUPAI FROM TGFGRU GRU5 WHERE GRU5.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))))
                                                                            END
                                                                        
                                                                    END 
                                                                
                                                        END 
                                                    
                                                    END 
                              END) FROM TGFGRU GG WHERE GG.CODGRUPOPROD = PRO.CODGRUPOPROD) = ADA.CODGRUPOPROD
                              -----
                              AND TRUNC(CAB.DTFATUR) BETWEEN  PDTINI AND PDTFIN
                              AND ADA.ID = FIELD_ID 
                              AND ADA.CODGRUPOPROD = IUPDATE.GRUPO
                            GROUP BY ADA.CODGRUPOPROD, TO_CHAR(TRUNC(CAB.DTFATUR), 'd'), TRUNC(CAB.DTFATUR)
                            ORDER BY 3))
                    LOOP
                        SELECT COUNT(*)
                        INTO CONTDIAS
                        FROM AD_GRUPOSPRODUSUDIA AD
                        WHERE AD.ID = FIELD_ID
                          AND AD.IDGRU = PK_GRUPO;

                        IF CONTDIAS = 0 THEN
                            INSERT INTO AD_GRUPOSPRODUSUDIA (ID, IDGRU,IDMETDIA, CODGRUPOPROD, DIAANOANT, PERCRES,PESO, METADIA, DATA) VALUES
                            (FIELD_ID, PK_GRUPO,1, IGRU2.GRUPO, IGRU2.TOTAL, IGRU2.PER,IUPDATE.PERC , ((IGRU2.TOTAL/100)* IUPDATE.PERC) + IGRU2.TOTAL, IGRU2.FATUR);
                        ELSE
                            INSERT INTO AD_GRUPOSPRODUSUDIA (ID, IDGRU,IDMETDIA, CODGRUPOPROD, DIAANOANT, PERCRES,PESO, METADIA,DATA) VALUES
                            (FIELD_ID, PK_GRUPO, (SELECT MAX(IDMETDIA) + 1 FROM AD_GRUPOSPRODUSUDIA AD WHERE AD.ID = FIELD_ID AND AD.IDGRU = PK_GRUPO), IGRU2.GRUPO, IGRU2.TOTAL, IGRU2.PER,IUPDATE.PERC ,((IGRU2.TOTAL/100)* IUPDATE.PERC) + IGRU2.TOTAL, IGRU2.FATUR);
                        END IF;
                    END LOOP;    
            END LOOP;
            PMSG := PMSG ||'Dados dos vendedores atualizados com sucesso! <br>';
        END IF;
    END IF;---------------------------------------------------------------------FINALIZA OPÇÃO DE COPIAR/RECALCULAR

------------------------------------------------------------------------------------------------------------------------------------------------------------
--INICIA FOR DOS VENDEDORES PARA RECALCULAR OS VENDEDORES INSERIDOS POSTERIORMENTE.
------------------------------------------------------------------------------------------------------------------------------------------------------------   

    IF NVL(PARAM_RECALC, 'N') = 'S' THEN---------------------------------------INÍCIO DE INSERE/RECALCULA VENDEDORES
        FOR IUPDATE IN (SELECT CODVEND
                          , VALOR
                          , TOTAL
                          , (VALOR/TOTAL)*100 AS PERC 
                     FROM (
                           SELECT VEN.CODVEND
                                        , NVL((SELECT SUM( ((ITE.VLRTOT - ITE.VLRDESC - ITE.VLRREPRED + ITE.VLRSUBST + ITE.VLRIPI) * VCA.INDITENSBRUTO) * CASE WHEN TOP.BONIFICACAO = 'S' THEN 0 ELSE 1 END * TOP.GOLDEV )
                                    FROM TGFCAB CAB INNER JOIN TGFITE ITE ON (CAB.NUNOTA = ITE.NUNOTA)
                                                    INNER JOIN VGFCAB VCA ON (CAB.NUNOTA = VCA.NUNOTA)
                                                    INNER JOIN TGFVEN VE  ON (CAB.CODVEND = VE.CODVEND)
                                                    INNER JOIN TGFTOP TOP ON (CAB.CODTIPOPER = TOP.CODTIPOPER AND CAB.DHTIPOPER = TOP.DHALTER AND TOP.GOLSINAL = -1)
                                    WHERE CAB.CODTIPOPER IN (SELECT REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''),'[^,]+', 1, LEVEL) AS RESULTADO FROM DUAL CONNECT BY REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''), '[^,]+', 1, LEVEL) IS NOT NULL)
                                      AND CAB.STATUSNFE = 'A'
                                      AND VE.ATIVO = 'S'
                                            AND CAB.CODVEND = VEN.CODVEND
                                            AND TRUNC(CAB.DTFATUR) BETWEEN ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (TO_DATE(SYSDATE, 'DD/MM/YYYY'),'MONTH'),'DD/MM/YY'),0),'MONTH'),'DD/MM/YY'),-1)
                                                                       AND ADD_MONTHS (TO_DATE (LAST_DAY (TO_DATE(SYSDATE, 'DD/MM/YYYY')),'DD/MM/YY'),-1)),0) 
                                                AS VALOR
                                        , (SELECT SUM( ((ITE.VLRTOT - ITE.VLRDESC - ITE.VLRREPRED + ITE.VLRSUBST + ITE.VLRIPI) * VCA.INDITENSBRUTO) * CASE WHEN TOP.BONIFICACAO = 'S' THEN 0 ELSE 1 END * TOP.GOLDEV )
                                    FROM TGFCAB CAB INNER JOIN TGFITE ITE ON (CAB.NUNOTA = ITE.NUNOTA)
                                                    INNER JOIN VGFCAB VCA ON (CAB.NUNOTA = VCA.NUNOTA)
                                                    INNER JOIN TGFVEN VE  ON (CAB.CODVEND = VE.CODVEND)
                                                    INNER JOIN TGFTOP TOP ON (CAB.CODTIPOPER = TOP.CODTIPOPER AND CAB.DHTIPOPER = TOP.DHALTER AND TOP.GOLSINAL = -1)
                                    WHERE CAB.CODTIPOPER IN (SELECT REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''),'[^,]+', 1, LEVEL) AS RESULTADO FROM DUAL CONNECT BY REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''), '[^,]+', 1, LEVEL) IS NOT NULL)
                                      AND CAB.STATUSNFE = 'A'
                                      AND VE.ATIVO = 'S'
                                             AND CAB.CODVEND IN (SELECT CODVEND FROM AD_GRUPROSPRODMETVEN WHERE ID = FIELD_ID)
                                             AND TRUNC(CAB.DTFATUR) BETWEEN ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (TO_DATE(SYSDATE, 'DD/MM/YYYY'),'MONTH'),'DD/MM/YY'),0),'MONTH'),'DD/MM/YY'),-1)
                                                                            AND ADD_MONTHS (TO_DATE (LAST_DAY (TO_DATE(SYSDATE, 'DD/MM/YYYY')),'DD/MM/YY'),-1)) 
                                                AS TOTAL
                    FROM TGFVEN VEN INNER JOIN AD_GRUPROSPRODMETVEN AD ON (VEN.CODVEND = AD.CODVEND))
                    ORDER BY PERC, CODVEND)
        LOOP
            UPDATE AD_GRUPROSPRODMETVEN A SET PERCVEND = IUPDATE.PERC, METVEND = IUPDATE.VALOR WHERE CODVEND = IUPDATE.CODVEND AND ID = FIELD_ID;
        END LOOP;       
    ELSE

----------------------------------------------------------------INSERE NOVOS VENDEDORES POR GERENTE

        IF PARAM_CODGER IS NOT NULL THEN   
            SELECT COUNT(*)
            INTO CONT
            FROM AD_GRUPROSPRODMETVEN AD
            WHERE AD.ID = FIELD_ID;
     
            DELETE FROM AD_SUBGRUPOVENDMET AD WHERE AD.ID = FIELD_ID;
            DELETE FROM  AD_GRUPROSPRODMETVEN A WHERE (A.CODVENDGER = PARAM_CODGER OR A.CODGRUPO IS NOT NULL) AND A.ID = FIELD_ID;
            
            FOR IVEND IN (SELECT CODVEND
                               , VALOR
                               , TOTAL AS TOTAL
                               , (VALOR/TOTAL)*100 AS PERC 
                          FROM (
                                SELECT VEN.CODVEND
                                    , NVL((SELECT SUM( ((ITE.VLRTOT - ITE.VLRDESC - ITE.VLRREPRED + ITE.VLRSUBST + ITE.VLRIPI) * VCA.INDITENSBRUTO) * CASE WHEN TOP.BONIFICACAO = 'S' THEN 0 ELSE 1 END * TOP.GOLDEV )
                                           FROM TGFCAB CAB INNER JOIN TGFITE ITE ON (CAB.NUNOTA = ITE.NUNOTA)
                                                          INNER JOIN VGFCAB VCA ON (CAB.NUNOTA = VCA.NUNOTA)
                                                          INNER JOIN TGFVEN VE  ON (CAB.CODVEND = VE.CODVEND)
                                                          INNER JOIN TGFTOP TOP ON (CAB.CODTIPOPER = TOP.CODTIPOPER AND CAB.DHTIPOPER = TOP.DHALTER AND TOP.GOLSINAL = -1)
                                           WHERE CAB.CODTIPOPER IN (SELECT REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''),'[^,]+', 1, LEVEL) AS RESULTADO FROM DUAL CONNECT BY REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''), '[^,]+', 1, LEVEL) IS NOT NULL)
                                             AND CAB.STATUSNFE = 'A'
                                             AND VE.ATIVO = 'S'
                                             --ELIMINA VENDEDOR COM 0 DE VENDA
                                             AND (NVL((SELECT SUM( ((ITE.VLRTOT - ITE.VLRDESC - ITE.VLRREPRED + ITE.VLRSUBST + ITE.VLRIPI) * VCA.INDITENSBRUTO) * CASE WHEN TOP.BONIFICACAO = 'S' THEN 0 ELSE 1 END * TOP.GOLDEV )
                                                      FROM TGFCAB CAB INNER JOIN TGFITE ITE ON (CAB.NUNOTA = ITE.NUNOTA)
                                                                     INNER JOIN VGFCAB VCA ON (CAB.NUNOTA = VCA.NUNOTA)
                                                                     INNER JOIN TGFVEN VE  ON (CAB.CODVEND = VE.CODVEND)
                                                                     INNER JOIN TGFTOP TOP ON (CAB.CODTIPOPER = TOP.CODTIPOPER AND CAB.DHTIPOPER = TOP.DHALTER AND TOP.GOLSINAL = -1)
                                                      WHERE CAB.CODTIPOPER IN (SELECT REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''),'[^,]+', 1, LEVEL) AS RESULTADO FROM DUAL CONNECT BY REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''), '[^,]+', 1, LEVEL) IS NOT NULL)
                                                        AND CAB.STATUSNFE = 'A'
                                                        AND VE.ATIVO = 'S'
                                                        AND CAB.CODVEND = VEN.CODVEND
                                                        AND TRUNC(CAB.DTFATUR) BETWEEN ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (TO_DATE(SYSDATE, 'DD/MM/YYYY'),'MONTH'),'DD/MM/YY'),0),'MONTH'),'DD/MM/YY'),-1)
                                                                                          AND ADD_MONTHS (TO_DATE (LAST_DAY (TO_DATE(SYSDATE, 'DD/MM/YYYY')),'DD/MM/YY'),-1)),0) ) <> 0
                                                        --FIM DO VENDEDOR COM 0 DE VENDA 
                                                        AND CAB.CODVEND = VEN.CODVEND
                                                        AND TRUNC(CAB.DTFATUR) BETWEEN ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (TO_DATE(SYSDATE, 'DD/MM/YYYY'),'MONTH'),'DD/MM/YY'),0),'MONTH'),'DD/MM/YY'),-1)
                                                                                    AND ADD_MONTHS (TO_DATE (LAST_DAY (TO_DATE(SYSDATE, 'DD/MM/YYYY')),'DD/MM/YY'),-1)),0) 
                                        AS VALOR
                                    , (SELECT SUM( ((ITE.VLRTOT - ITE.VLRDESC - ITE.VLRREPRED + ITE.VLRSUBST + ITE.VLRIPI) * VCA.INDITENSBRUTO) * CASE WHEN TOP.BONIFICACAO = 'S' THEN 0 ELSE 1 END * TOP.GOLDEV )
                                       FROM TGFCAB CAB INNER JOIN TGFITE ITE ON (CAB.NUNOTA = ITE.NUNOTA)
                                                      INNER JOIN VGFCAB VCA ON (CAB.NUNOTA = VCA.NUNOTA)
                                                      INNER JOIN TGFVEN VE  ON (CAB.CODVEND = VE.CODVEND)
                                                      INNER JOIN TGFTOP TOP ON (CAB.CODTIPOPER = TOP.CODTIPOPER AND CAB.DHTIPOPER = TOP.DHALTER AND TOP.GOLSINAL = -1)
                                       WHERE CAB.CODTIPOPER IN (SELECT REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''),'[^,]+', 1, LEVEL) AS RESULTADO FROM DUAL CONNECT BY REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''), '[^,]+', 1, LEVEL) IS NOT NULL)                                
                                         AND CAB.STATUSNFE = 'A'
                                         AND VE.ATIVO = 'S'
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
            END LOOP;
        END IF;
----------------------------------------------------------------INSERE NOVOS VENDEDORES POR GRUPO
        IF PARAM_CODGRU IS NOT NULL THEN   
            SELECT COUNT(*)
            INTO CONT
            FROM AD_GRUPROSPRODMETVEN AD
            WHERE AD.ID = FIELD_ID;
                    
            DELETE FROM AD_SUBGRUPOVENDMET AD WHERE AD.ID = FIELD_ID;
            
            DELETE FROM  AD_GRUPROSPRODMETVEN A WHERE A.ID = FIELD_ID AND NVL(A.CODGRUPO, PARAM_CODGRU) = PARAM_CODGRU;
               
            FOR IVEND IN (SELECT CODVEND, APELIDO
                               , TOTAL AS TOTAL
                               , VALOR
                               , (VALOR/TOTAL)*100 AS PERC 
                         FROM (
                               SELECT VEN.CODVEND
                                   , VEN.APELIDO
                                   , ATIVO
                                   , NVL((SELECT SUM( ((ITE.VLRTOT - ITE.VLRDESC - ITE.VLRREPRED + ITE.VLRSUBST + ITE.VLRIPI) * VCA.INDITENSBRUTO) * CASE WHEN TOP.BONIFICACAO = 'S' THEN 0 ELSE 1 END * TOP.GOLDEV )
                                      FROM TGFCAB CAB INNER JOIN TGFITE ITE ON (CAB.NUNOTA = ITE.NUNOTA)
                                                      INNER JOIN VGFCAB VCA ON (CAB.NUNOTA = VCA.NUNOTA)
                                                      INNER JOIN TGFVEN VE  ON (CAB.CODVEND = VE.CODVEND)
                                                      INNER JOIN TGFTOP TOP ON (CAB.CODTIPOPER = TOP.CODTIPOPER AND CAB.DHTIPOPER = TOP.DHALTER AND TOP.GOLSINAL = -1)
                                      WHERE CAB.CODTIPOPER IN (SELECT REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''),'[^,]+', 1, LEVEL) AS RESULTADO FROM DUAL CONNECT BY REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''), '[^,]+', 1, LEVEL) IS NOT NULL)
                                        AND CAB.STATUSNFE = 'A'
                                        AND VE.ATIVO = 'S'
                                        AND CAB.CODVEND NOT IN (0, 76)
                                        AND CAB.CODVEND = VEN.CODVEND -- 75, 57< o grupo dos usuários
                                        AND TRUNC(CAB.DTFATUR) BETWEEN ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (TO_DATE(SYSDATE, 'DD/MM/YYYY'),'MONTH'),'DD/MM/YY'),0),'MONTH'),'DD/MM/YY'),-1)
                                                                       AND ADD_MONTHS (TO_DATE (LAST_DAY (TO_DATE(SYSDATE, 'DD/MM/YYYY')),'DD/MM/YY'),-1)),0 
                                          ) AS VALOR
                                   , (SELECT SUM( ((ITE.VLRTOT - ITE.VLRDESC - ITE.VLRREPRED + ITE.VLRSUBST + ITE.VLRIPI) * VCA.INDITENSBRUTO) * CASE WHEN TOP.BONIFICACAO = 'S' THEN 0 ELSE 1 END * TOP.GOLDEV )
                                      FROM TGFCAB CAB INNER JOIN TGFITE ITE ON (CAB.NUNOTA = ITE.NUNOTA)
                                                      INNER JOIN VGFCAB VCA ON (CAB.NUNOTA = VCA.NUNOTA)
                                                      INNER JOIN TGFVEN VE  ON (CAB.CODVEND = VE.CODVEND)
                                                      INNER JOIN TGFTOP TOP ON (CAB.CODTIPOPER = TOP.CODTIPOPER AND CAB.DHTIPOPER = TOP.DHALTER AND TOP.GOLSINAL = -1)
                                      WHERE CAB.CODTIPOPER IN (SELECT REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''),'[^,]+', 1, LEVEL) AS RESULTADO FROM DUAL CONNECT BY REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''), '[^,]+', 1, LEVEL) IS NOT NULL)
                                        AND CAB.STATUSNFE = 'A'
                                        AND VE.ATIVO = 'S'
                                        AND CAB.CODVEND NOT IN (0, 76)
                                        AND CAB.CODVEND IN (SELECT USU.CODVEND FROM TSIUSU USU WHERE USU.CODGRUPO = PARAM_CODGRU AND USU.DTULTACESSO IS NOT NULL) -- < o grupo dos usuários
                                        AND TRUNC(CAB.DTFATUR) BETWEEN ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (TO_DATE(SYSDATE, 'DD/MM/YYYY'),'MONTH'),'DD/MM/YY'),0),'MONTH'),'DD/MM/YY'),-1)
                                                                       AND ADD_MONTHS (TO_DATE (LAST_DAY (TO_DATE(SYSDATE, 'DD/MM/YYYY')),'DD/MM/YY'),-1)
                                          ) AS TOTAL
                               FROM TGFVEN VEN 
                               WHERE VEN.CODVEND IN (SELECT USU.CODVEND FROM TSIUSU USU WHERE USU.CODGRUPO = PARAM_CODGRU) -- < o grupo dos usuários
                                 AND VEN.ATIVO = 'S'
                                 --ELIMINA VENDEDOR COM 0 DE VENDA
                                 AND (NVL((SELECT SUM( ((ITE.VLRTOT - ITE.VLRDESC - ITE.VLRREPRED + ITE.VLRSUBST + ITE.VLRIPI) * VCA.INDITENSBRUTO) * CASE WHEN TOP.BONIFICACAO = 'S' THEN 0 ELSE 1 END * TOP.GOLDEV )
                                       FROM TGFCAB CAB INNER JOIN TGFITE ITE ON (CAB.NUNOTA = ITE.NUNOTA)
                                                      INNER JOIN VGFCAB VCA ON (CAB.NUNOTA = VCA.NUNOTA)
                                                      INNER JOIN TGFVEN VE  ON (CAB.CODVEND = VE.CODVEND)
                                                      INNER JOIN TGFTOP TOP ON (CAB.CODTIPOPER = TOP.CODTIPOPER AND CAB.DHTIPOPER = TOP.DHALTER AND TOP.GOLSINAL = -1)
                                       WHERE CAB.CODTIPOPER IN (SELECT REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''),'[^,]+', 1, LEVEL) AS RESULTADO FROM DUAL CONNECT BY REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''), '[^,]+', 1, LEVEL) IS NOT NULL)
                                         AND CAB.STATUSNFE = 'A'
                                         AND VE.ATIVO = 'S'
                                         AND CAB.CODVEND = VEN.CODVEND
                                         AND TRUNC(CAB.DTFATUR) BETWEEN ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (TO_DATE(SYSDATE, 'DD/MM/YYYY'),'MONTH'),'DD/MM/YY'),0),'MONTH'),'DD/MM/YY'),-1)
                                                                    AND ADD_MONTHS (TO_DATE (LAST_DAY (TO_DATE(SYSDATE, 'DD/MM/YYYY')),'DD/MM/YY'),-1)),0) ) <> 0
                                         --FIM DO VENDEDOR COM 0 DE VENDA 
                                         AND VEN.CODVEND NOT IN (0, 76))
                         ORDER BY PERC, CODVEND)
            LOOP
                SELECT COUNT(*)
                INTO CONT
                FROM AD_GRUPROSPRODMETVEN AD
                WHERE AD.ID = FIELD_ID;
                     IF CONT = 0 THEN
                         INSERT INTO AD_GRUPROSPRODMETVEN (ID, IDMETVEND,CODVEND, PERCVEND, METVEND, CODVENDGER, CODGRUPO) VALUES
                         (FIELD_ID, 1, IVEND.CODVEND, IVEND.PERC, IVEND.VALOR, (SELECT MAX(USU.CODVEND) FROM TSIUSU USU WHERE USU.CODUSU = PCODUSU), PARAM_CODGRU);
                     ELSE
                         INSERT INTO AD_GRUPROSPRODMETVEN (ID, IDMETVEND,CODVEND, PERCVEND, METVEND, CODVENDGER, CODGRUPO) VALUES
                         (FIELD_ID, (SELECT MAX(IDMETVEND) + 1 FROM AD_GRUPROSPRODMETVEN WHERE ID = FIELD_ID), IVEND.CODVEND, IVEND.PERC, IVEND.VALOR, (SELECT MAX(USU.CODVEND) FROM TSIUSU USU WHERE USU.CODUSU = PCODUSU), PARAM_CODGRU);
                     END IF;
            END LOOP;
        END IF;-------------------------------------------------------FIM DO INSERE NOVOS VENDEDORES POR GRUPO
    END IF; -- RECALCULA VENDEDORES
------------------------------------------------------------------------------------------------------------------------------------------------------------
--GERA META DOS GRUPOS.
------------------------------------------------------------------------------------------------------------------------------------------------------------ 
    IF NVL(RECMET, 'N') = 'S' THEN
    
        SELECT COUNT(*)
        INTO CONT
        FROM AD_GRUPROSPRODMETVEN A
        WHERE A.ID = FIELD_ID;
        
        DELETE FROM AD_SUBGRUPOVENDMETDIAS A WHERE A.ID = FIELD_ID;
        
        DELETE FROM AD_SUBGRUPOVENDMET AD WHERE AD.ID = FIELD_ID;
          
        IF CONT = 0 THEN --VERIFICA SE EXISTE VENDEDORES
            PMSG := PMSG || 'Sem vendedor cadastrado na tela.<br>';
        ELSE
            FOR IVEN IN (SELECT VEN.IDMETVEND
                            , VEN.CODVEND
                            , VEN.PERCVEND AS PERC 
                          FROM AD_GRUPROSPROD A LEFT JOIN AD_GRUPROSPRODMETVEN VEN ON (A.ID=VEN.ID)--VENDEDORES
                          WHERE A.ID = FIELD_ID
                          ORDER BY 2)
            LOOP
                --Busca pelos grupos
                FOR IGRU IN (SELECT GRU.CODGRUPOPROD AS GRUPO
                                , GRU.SUGESTAO AS SUGESTAO
                            FROM AD_GRUPROSPROD A LEFT JOIN AD_GRUPOSPRODUSU GRU ON (A.ID=GRU.ID)--GRUPOS
                            WHERE A.ID = FIELD_ID
                            ORDER BY SUGESTAO)
                LOOP
                    SELECT COUNT(*)
                    INTO CONTGRU
                    FROM AD_SUBGRUPOVENDMET AD
                    WHERE AD.ID = FIELD_ID
                      AND AD.IDMETVEND = IVEN.IDMETVEND;
                
                    IF CONTGRU = 0 THEN
                        INSERT INTO AD_SUBGRUPOVENDMET (ID, IDMETVEND, IDSUBVENDMETA, CODGRUPOPROD, SUGESTAOGRUVEN) VALUES
                        (FIELD_ID, IVEN.IDMETVEND, 1, IGRU.GRUPO, ((IGRU.SUGESTAO * IVEN.PERC)/100));
                    ELSE
                        INSERT INTO AD_SUBGRUPOVENDMET (ID, IDMETVEND, IDSUBVENDMETA, CODGRUPOPROD, SUGESTAOGRUVEN) VALUES
                        (FIELD_ID, IVEN.IDMETVEND, (SELECT MAX(IDSUBVENDMETA) + 1 FROM AD_SUBGRUPOVENDMET A WHERE A.ID = FIELD_ID AND A.IDMETVEND = IVEN.IDMETVEND), IGRU.GRUPO, ((IGRU.SUGESTAO * IVEN.PERC)/100));
                    END IF;
                END LOOP;
                --Fim da busca pelos grupos
                --FOR PARA METAS POR DIA DO VENDEDOR
                FOR IVENDIA IN (SELECT GR.ID, GR.CODGRUPOPROD
                                   , CASE WHEN TO_CHAR(TO_DATE(TO_CHAR(GM.DATA, 'DD/MM/') || TO_CHAR(SYSDATE, 'YYYY'),'DD/MM/YYYY'), 'd') = 7
                                          THEN TO_DATE(TO_CHAR(GM.DATA, 'DD/MM/') || TO_CHAR(SYSDATE, 'YYYY'),'DD/MM/YYYY') + 2
                                          ELSE CASE WHEN TO_CHAR(TO_DATE(TO_CHAR(GM.DATA, 'DD/MM/') || TO_CHAR(SYSDATE, 'YYYY'),'DD/MM/YYYY'), 'd') = 1
                                                    THEN TO_DATE(TO_CHAR(GM.DATA, 'DD/MM/') || TO_CHAR(SYSDATE, 'YYYY'),'DD/MM/YYYY') + 1
                                                    ELSE TO_DATE(TO_CHAR(GM.DATA, 'DD/MM/') || TO_CHAR(SYSDATE, 'YYYY'),'DD/MM/YYYY')
                                               END
                                     END AS DATA
                                   , GM.METADIA AS METADIA
                                   , VEN.IDMETVEND, VEN.CODVEND
                                   , VEN.PERCVEND AS PERCVEND
                                   , GM.IDMETDIA
                                   , ((GM.METADIA/100) * VEN.PERCVEND) AS PERC
                                FROM AD_GRUPOSPRODUSU GR INNER JOIN AD_GRUPOSPRODUSUDIA GM ON (GR.ID = GM.ID AND GR.IDGRU = GM.IDGRU)
                                                        LEFT  JOIN AD_GRUPROSPRODMETVEN VEN ON (GR.ID = VEN.ID)
                                WHERE GR.ID = FIELD_ID
                                  AND VEN.IDMETVEND = IVEN.IDMETVEND
                                ORDER BY GR.DATA)
                LOOP
                 
                    SELECT COUNT(*) 
                    INTO CONT2
                    FROM AD_SUBGRUPOVENDMETDIAS A 
                    WHERE A.ID = FIELD_ID
                      AND A.IDMETVEND = IVEN.IDMETVEND;
                      
                    IF CONT2 = 0 THEN
                        INSERT INTO AD_SUBGRUPOVENDMETDIAS (ID, IDMETVEND, IDGRUVENDDIAS, CODGRUPOPROD, SUGMETVENDDIA, DATA, CODVEND) VALUES
                        (FIELD_ID, IVENDIA.IDMETVEND, 1, IVENDIA.CODGRUPOPROD,IVENDIA.PERC, IVENDIA.DATA, IVENDIA.CODVEND);
                    ELSE
                        SELECT MAX(A.IDGRUVENDDIAS) + 1 
                        INTO PK_GRUPO
                        FROM AD_SUBGRUPOVENDMETDIAS A
                        WHERE ID = FIELD_ID
                          AND A.IDMETVEND = IVENDIA.IDMETVEND;
                                
                        INSERT INTO AD_SUBGRUPOVENDMETDIAS (ID, IDMETVEND, IDGRUVENDDIAS, CODGRUPOPROD, SUGMETVENDDIA, DATA, CODVEND) VALUES
                        (FIELD_ID, IVENDIA.IDMETVEND, PK_GRUPO, IVENDIA.CODGRUPOPROD, IVENDIA.PERC, IVENDIA.DATA, IVENDIA.CODVEND);
                    END IF;
                END LOOP;
            END LOOP;
        END IF; --VERIFICA SE EXISTE VENDEDORES
    END IF;
-------------------------------------------------------------------------------------------------------------------------------------
--PROCEDIMENTOS COM EMPRESAS-------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------
    IF ATUEMP = 'S' THEN
        DELETE FROM AD_EMPVENDIAGRU AD WHERE AD.ID = FIELD_ID;
    
        DELETE FROM AD_EMPVEND AD WHERE AD.ID = FIELD_ID;
    
        DELETE FROM AD_EMPGRUVENFI AD WHERE AD.ID = FIELD_ID;
    
        DELETE FROM AD_METEMPVENDDIA AD WHERE AD.ID = FIELD_ID;
    
        DELETE FROM AD_METEMPGRUSUBGRUVEN AD WHERE AD.ID = FIELD_ID;
    
        DELETE FROM AD_METEMPGRUSUBGRU AD WHERE AD.ID = FIELD_ID;

        DELETE FROM AD_GRUMETEMPDIA WHERE ID = FIELD_ID;

        SELECT COUNT(*)
        INTO CONT
        FROM AD_GRUPOSPRODUSU G 
        WHERE ID = FIELD_ID;
        
        IF CONT = 0 THEN
RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#000000">
Favor inserir grupo(s) de produtos na aba "Grupos de meta".</font></b><br><font>');
        END IF; 
        
        SELECT COUNT(*)
        INTO CONT
        FROM AD_GRUMETEMP
        WHERE ID = FIELD_ID;

        IF CONT = 0 THEN
RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#000000">
Favor inserir Empresas(s) na aba "Metas por empresa".</font></b><br><font>');
        END IF;     

        --VALORES POR ANO
        FOR IVLREMP IN (SELECT CAB.CODEMP,
                           SUM( ((ITE.VLRTOT - ITE.VLRDESC - ITE.VLRREPRED + ITE.VLRSUBST + ITE.VLRIPI)  * VCA.INDITENSBRUTO) * CASE WHEN TOP.BONIFICACAO = 'S' THEN 0 ELSE 1 END * TOP.GOLDEV ) AS TT
                           --NOVO
                            FROM TGFCAB CAB INNER JOIN TGFITE ITE ON (CAB.NUNOTA = ITE.NUNOTA)
                                            INNER JOIN TGFPRO PRO ON (ITE.CODPROD = PRO.CODPROD)
                                            INNER JOIN VGFCAB VCA ON (CAB.NUNOTA = VCA.NUNOTA)
                                            INNER JOIN TGFTOP TOP ON (CAB.CODTIPOPER = TOP.CODTIPOPER AND CAB.DHTIPOPER = TOP.DHALTER AND TOP.GOLSINAL = -1)
                                            , AD_GRUPOSPRODUSU AD
                            WHERE CAB.CODTIPOPER IN (SELECT REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''),'[^,]+', 1, LEVEL) AS RESULTADO FROM DUAL CONNECT BY REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''), '[^,]+', 1, LEVEL) IS NOT NULL)
                              AND CAB.STATUSNFE= 'A'
                              AND CAB.CODEMP IN (SELECT A.CODEMP FROM AD_GRUMETEMP A WHERE A.ID = FIELD_ID)
                              -----LOCALIZA GRUPO INDEPENDENTE DO NIVEL
                              AND (SELECT (CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = FIELD_ID AND  G2.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))) IS NOT NULL  
                            THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = FIELD_ID AND  G2.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))
                            ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = FIELD_ID AND  G2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))) IS NOT NULL
                                THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = FIELD_ID AND  G2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))
                                ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = FIELD_ID AND  G2.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))) IS NOT NULL
                                            THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = FIELD_ID AND  G2.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))
                                            ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = FIELD_ID AND  G2.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))) IS NOT NULL
                                                    THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = FIELD_ID AND  G2.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))
                                                    ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = FIELD_ID AND  G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))) IS NOT NULL
                                                                THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = FIELD_ID AND  G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))))
                                                                ELSE TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = FIELD_ID AND  G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU5.CODGRUPAI FROM TGFGRU GRU5 WHERE GRU5.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))))
                                                        END
                                                    
                                                END 
                                            
                                    END 
                                
                                END 
                END) FROM TGFGRU GG WHERE GG.CODGRUPOPROD = PRO.CODGRUPOPROD) = AD.CODGRUPOPROD
                              -----
                              AND TRUNC(CAB.DTFATUR) BETWEEN PDTINI AND PDTFIN
                              AND AD.ID = FIELD_ID
                           GROUP BY CAB.CODEMP)
        LOOP

            UPDATE AD_GRUMETEMP SET VLRMESANT = IVLREMP.TT WHERE ID = FIELD_ID AND CODEMP = IVLREMP.CODEMP;

        END LOOP; 
---------------------------------------------------------------------------------------------------------------------------
--atualiza os campos da empresa calculando % e etc.
---------------------------------------------------------------------------------------------------------------------------
        FOR IEMP IN (SELECT A.ID
                        , A.IDMETEMP
                        , NVL(A.VLRMESANT,0) AS VLRMESANT
                        , NVL(((A.VLRMESANT / (SELECT SUM(B.VLRMESANT) FROM AD_GRUMETEMP B WHERE B.ID = A.ID)) * 100),0) AS PESO
                        , A.CODEMP
                        , CASE WHEN A.PER IS NULL THEN 10
                               ELSE A.PER END AS PER
                        , NVL(((NVL(VLRMESANT,1) / 100) * NVL(PER,10)) + VLRMESANT,0) AS META
                  FROM AD_GRUMETEMP A 
                  WHERE A.ID = FIELD_ID)
        LOOP
            UPDATE AD_GRUMETEMP SET VLRMESANT = IEMP.VLRMESANT, PESO = IEMP.PESO, META = IEMP.META, PER = IEMP.PER, DTMESINI = PDTINI, DTMESFIN = PDTFIN WHERE ID = FIELD_ID AND IDMETEMP = IEMP.IDMETEMP; --COMMIT;
            
------------------------------------------------------------------------------------------------------------------------------------------------------------          
--INSERE VENDEDORES POR EMPRESA
------------------------------------------------------------------------------------------------------------------------------------------------------------
                FOR IVEND IN (SELECT TOTAL
                                      
                                      , CODVEND
                                      , (SELECT SUM(TOTAL)
                                                               FROM ( 
                                                                     SELECT 
                                                                     
                                                              
                                                              --ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (TO_DATE(SYSDATE, 'DD/MM/YYYY'),'MONTH'),'DD/MM/YY'),-11),'MONTH'),'DD/MM/YY'),-1) AS DIAS,
                                                              SUM( ((ITE.VLRTOT - ITE.VLRDESC - ITE.VLRREPRED + ITE.VLRSUBST + ITE.VLRIPI)  * VCA.INDITENSBRUTO) * CASE WHEN TOP.BONIFICACAO = 'S' THEN 0 ELSE 1 END * TOP.GOLDEV ) AS TOTAL
                                                        FROM TGFCAB C INNER JOIN TGFITE ITE ON (C.NUNOTA = ITE.NUNOTA)
                                                                        INNER JOIN TGFPRO PRO ON (ITE.CODPROD = PRO.CODPROD)
                                                                        INNER JOIN VGFCAB VCA ON (C.NUNOTA = VCA.NUNOTA)
                                                                        INNER JOIN TGFTOP TOP ON (C.CODTIPOPER = TOP.CODTIPOPER AND C.DHTIPOPER = TOP.DHALTER AND TOP.GOLSINAL = -1)
                                                                        , AD_GRUPOSPRODUSU ADA
                                                        WHERE C.CODTIPOPER IN (SELECT REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''),'[^,]+', 1, LEVEL) AS RESULTADO FROM DUAL CONNECT BY REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''), '[^,]+', 1, LEVEL) IS NOT NULL)
                                                          AND C.STATUSNFE= 'A'
                                                          AND C.CODEMP = IEMP.CODEMP
                                                          AND (SELECT (CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))) IS NOT NULL  
                                                                            THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))
                                                                            ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))) IS NOT NULL
                                                                                THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))
                                                                                ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))) IS NOT NULL
                                                                                            THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))
                                                                                            ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))) IS NOT NULL
                                                                                                    THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))
                                                                                                    ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))) IS NOT NULL
                                                                                                                THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))))
                                                                                                                ELSE TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU5.CODGRUPAI FROM TGFGRU GRU5 WHERE GRU5.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))))
                                                                                                        END
                                                                                                    
                                                                                                END 
                                                                                            
                                                                                    END 
                                                                                
                                                                                END 
                                                          END) FROM TGFGRU GG WHERE GG.CODGRUPOPROD = PRO.CODGRUPOPROD) = ADA.CODGRUPOPROD
                                                          AND TRUNC(C.DTFATUR) BETWEEN PDTINI AND PDTFIN
                                                          AND ADA.ID = FIELD_ID 
                                                        GROUP BY C.CODEMP)) AS TOTALZAO
                                      --FIM TOTALZAO -------------------------------------------------------------
                                       FROM ( 
                                             SELECT
                                      
                                      CAB.CODVEND,
                                      SUM( ((ITE.VLRTOT - ITE.VLRDESC - ITE.VLRREPRED + ITE.VLRSUBST + ITE.VLRIPI)  * VCA.INDITENSBRUTO) * CASE WHEN TOP.BONIFICACAO = 'S' THEN 0 ELSE 1 END * TOP.GOLDEV ) AS TOTAL
                                FROM TGFCAB CAB INNER JOIN TGFITE ITE ON (CAB.NUNOTA = ITE.NUNOTA)
                                                INNER JOIN TGFPRO PRO ON (ITE.CODPROD = PRO.CODPROD)
                                                INNER JOIN VGFCAB VCA ON (CAB.NUNOTA = VCA.NUNOTA)
                                                INNER JOIN TGFTOP TOP ON (CAB.CODTIPOPER = TOP.CODTIPOPER AND CAB.DHTIPOPER = TOP.DHALTER AND TOP.GOLSINAL = -1)
                                                , AD_GRUPOSPRODUSU ADA
                                WHERE CAB.CODTIPOPER IN (SELECT REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''),'[^,]+', 1, LEVEL) AS RESULTADO FROM DUAL CONNECT BY REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''), '[^,]+', 1, LEVEL) IS NOT NULL)
                                  AND CAB.STATUSNFE= 'A'
                                  AND CAB.CODEMP = IEMP.CODEMP
                                  AND (SELECT (CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))) IS NOT NULL  
                                                    THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))
                                                    ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))) IS NOT NULL
                                                        THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))
                                                        ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))) IS NOT NULL
                                                                    THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))
                                                                    ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))) IS NOT NULL
                                                                            THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))
                                                                            ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))) IS NOT NULL
                                                                                        THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))))
                                                                                        ELSE TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU5.CODGRUPAI FROM TGFGRU GRU5 WHERE GRU5.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))))
                                                                                END
                                                                            
                                                                        END 
                                                                    
                                                            END 
                                                        
                                                        END 
                                  END) FROM TGFGRU GG WHERE GG.CODGRUPOPROD = PRO.CODGRUPOPROD) = ADA.CODGRUPOPROD
                                  -----
                                  AND TRUNC(CAB.DTFATUR) BETWEEN PDTINI AND PDTFIN
                                  --AND (to_char(ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (TO_DATE(SYSDATE, 'DD/MM/YYYY'),'MONTH'),'DD/MM/YY'),-11),'MONTH'),'DD/MM/YY'),-1), 'd')) NOT IN (1,7)
                                  AND ADA.ID = FIELD_ID 

                                  --(SELECT MAX(A.ID) FROM AD_GRUPOSPRODUSU A WHERE A.ID IN (SELECT MAX(AD.ID) FROM AD_GRUPOSPRODUSU AD INNER JOIN AD_GRUPROSPROD AA ON (AA.ID = AD.ID) WHERE TO_CHAR(AA.DTVIGOR, 'MM') = TO_CHAR(ADD_MONTHS(TRUNC(SYSDATE),-1), 'MM') GROUP BY AD.ID))
                                GROUP BY CAB.CODVEND) A)
                LOOP
                    SELECT COUNT(*)
                    INTO IEMPVEND
                    FROM AD_EMPVEND AD
                    WHERE AD.ID = FIELD_ID
                      AND AD.IDMETEMP = IEMP.IDMETEMP;
                      
                    --SELECT * FROM AD_EMPVEND
                    IF IEMPVEND = 0 THEN
                        INSERT INTO AD_EMPVEND (ID, IDMETEMP, IDEMPVEND, CODEMP, CODVEND, VLR, PESO, META) VALUES
                        (FIELD_ID, IEMP.IDMETEMP, 1,  IEMP.CODEMP, IVEND.CODVEND, IVEND.TOTAL, (IVEND.TOTAL / IVEND.TOTALZAO) * 100, IVEND.TOTAL + ((IVEND.TOTAL / 100) * ((IVEND.TOTAL / IEMP.META) * 100)));
                        IEMPVEND := 1;
                    ELSE
                    
                        SELECT MAX(IDEMPVEND) + 1
                        INTO IEMPVEND
                        FROM AD_EMPVEND AD
                        WHERE AD.ID = FIELD_ID
                          AND AD.IDMETEMP = IEMP.IDMETEMP;
                    
                        INSERT INTO AD_EMPVEND (ID, IDMETEMP, IDEMPVEND, CODEMP, CODVEND, VLR, PESO, META) VALUES
                        (FIELD_ID, IEMP.IDMETEMP, IEMPVEND,  IEMP.CODEMP, IVEND.CODVEND, IVEND.TOTAL, (IVEND.TOTAL / IVEND.TOTALZAO) * 100, IVEND.TOTAL + ((IVEND.TOTAL / 100) * ((IVEND.TOTAL / IEMP.META) * 100)));
                    END IF;
                    
------------------------------------------------------------------------------------------------------------------------------------------------------------
--INICIA DISTRIGUIÇÃO POR DIA NAS EMPRESAS
------------------------------------------------------------------------------------------------------------------------------------------------------------
            FOR IEMPGRU2 IN (SELECT G.IDGRU, G.CODGRUPOPROD AS GRUPO, G.META, G.DATA, G.SUGESTAO, G.PERC, (SELECT SUM(A.META) FROM AD_GRUPOSPRODUSU A WHERE A.ID = G.ID) AS TOTALZAO
                            FROM AD_GRUPOSPRODUSU G 
                            WHERE ID = FIELD_ID)
            LOOP
------------------------------------------------------------------------------------------------------------------------------------------------------------          
--ATUALIZA VENDEDORES POR EMPRESA - POR DIA E GRUPOS PAI
------------------------------------------------------------------------------------------------------------------------------------------------------------
                    FOR IVENDDIAGRU IN (SELECT GRUPO
                                          , DATA
                                          , FATUR
                                          , TOTAL
                                          , ((TOTAL / IEMPGRU2.META)* 100) AS PERGRU
                                          , (SELECT SUM(TOTAL)
                                                                   FROM ( 
                                                                         SELECT ADA.CODGRUPOPROD AS GRUPO,
                                                                         C.CODVEND,
                                                                  TO_CHAR(TRUNC(C.DTFATUR), 'd') AS DATA,
                                                                  TRUNC(C.DTFATUR) AS FATUR,
                                                                  C.CODEMP,
                                                                  --ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (TO_DATE(SYSDATE, 'DD/MM/YYYY'),'MONTH'),'DD/MM/YY'),-11),'MONTH'),'DD/MM/YY'),-1) AS DIAS,
                                                                  SUM( ((ITE.VLRTOT - ITE.VLRDESC - ITE.VLRREPRED + ITE.VLRSUBST + ITE.VLRIPI)  * VCA.INDITENSBRUTO) * CASE WHEN TOP.BONIFICACAO = 'S' THEN 0 ELSE 1 END * TOP.GOLDEV ) AS TOTAL
                                                            FROM TGFCAB C INNER JOIN TGFITE ITE ON (C.NUNOTA = ITE.NUNOTA)
                                                                            INNER JOIN TGFPRO PRO ON (ITE.CODPROD = PRO.CODPROD)
                                                                            INNER JOIN VGFCAB VCA ON (C.NUNOTA = VCA.NUNOTA)
                                                                            INNER JOIN TGFTOP TOP ON (C.CODTIPOPER = TOP.CODTIPOPER AND C.DHTIPOPER = TOP.DHALTER AND TOP.GOLSINAL = -1)
                                                                            , AD_GRUPOSPRODUSU ADA
                                                            WHERE C.CODTIPOPER IN (SELECT REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''),'[^,]+', 1, LEVEL) AS RESULTADO FROM DUAL CONNECT BY REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''), '[^,]+', 1, LEVEL) IS NOT NULL)
                                                              AND C.STATUSNFE= 'A'
                                                              AND C.CODEMP = IEMP.CODEMP
                                                              AND (SELECT (CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))) IS NOT NULL  
                                                                                THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))
                                                                                ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))) IS NOT NULL
                                                                                    THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))
                                                                                    ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))) IS NOT NULL
                                                                                                THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))
                                                                                                ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))) IS NOT NULL
                                                                                                        THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))
                                                                                                        ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))) IS NOT NULL
                                                                                                                    THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))))
                                                                                                                    ELSE TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU5.CODGRUPAI FROM TGFGRU GRU5 WHERE GRU5.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))))
                                                                                                            END
                                                                                                        
                                                                                                    END 
                                                                                                
                                                                                        END 
                                                                                    
                                                                                    END 
                                                              END) FROM TGFGRU GG WHERE GG.CODGRUPOPROD = PRO.CODGRUPOPROD) = ADA.CODGRUPOPROD
                                                              AND TRUNC(C.DTFATUR) BETWEEN PDTINI AND PDTFIN
                                                              AND ADA.ID = FIELD_ID 
                                                              AND C.CODVEND = IVEND.CODVEND
                                                              AND ADA.CODGRUPOPROD = IEMPGRU2.GRUPO--APAGAR
                                                            GROUP BY C.CODEMP, ADA.CODGRUPOPROD, TO_CHAR(TRUNC(C.DTFATUR), 'd'), C.CODVEND, TRUNC(C.DTFATUR)) CC
                                                            WHERE CC.CODVEND = A.CODVEND) AS TOTALZAO
                                          --FIM TOTALZAO -------------------------------------------------------------

                                          , CODEMP
                                          , CODVEND
                                          , TOTAL+(TOTAL/100)*10 AS META 
                                           FROM ( 
                                                 SELECT ADA.CODGRUPOPROD AS GRUPO,
                                          TO_CHAR(TRUNC(CAB.DTFATUR), 'd') AS DATA,
                                          TRUNC(CAB.DTFATUR) AS FATUR,
                                          CAB.CODEMP,
                                          CAB.CODVEND,
                                          --ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (TO_DATE(SYSDATE, 'DD/MM/YYYY'),'MONTH'),'DD/MM/YY'),-11),'MONTH'),'DD/MM/YY'),-1) AS DIAS,
                                          SUM( ((ITE.VLRTOT - ITE.VLRDESC - ITE.VLRREPRED + ITE.VLRSUBST + ITE.VLRIPI)  * VCA.INDITENSBRUTO) * CASE WHEN TOP.BONIFICACAO = 'S' THEN 0 ELSE 1 END * TOP.GOLDEV ) AS TOTAL
                                    FROM TGFCAB CAB INNER JOIN TGFITE ITE ON (CAB.NUNOTA = ITE.NUNOTA)
                                                    INNER JOIN TGFPRO PRO ON (ITE.CODPROD = PRO.CODPROD)
                                                    INNER JOIN VGFCAB VCA ON (CAB.NUNOTA = VCA.NUNOTA)
                                                    INNER JOIN TGFTOP TOP ON (CAB.CODTIPOPER = TOP.CODTIPOPER AND CAB.DHTIPOPER = TOP.DHALTER AND TOP.GOLSINAL = -1)
                                                    , AD_GRUPOSPRODUSU ADA
                                    WHERE CAB.CODTIPOPER IN (SELECT REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''),'[^,]+', 1, LEVEL) AS RESULTADO FROM DUAL CONNECT BY REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''), '[^,]+', 1, LEVEL) IS NOT NULL)
                                      AND CAB.STATUSNFE= 'A'
                                      AND CAB.CODEMP = IEMP.CODEMP
                                      AND (SELECT (CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))) IS NOT NULL  
                                                        THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))
                                                        ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))) IS NOT NULL
                                                            THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))
                                                            ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))) IS NOT NULL
                                                                        THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))
                                                                        ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))) IS NOT NULL
                                                                                THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))
                                                                                ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))) IS NOT NULL
                                                                                            THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))))
                                                                                            ELSE TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU5.CODGRUPAI FROM TGFGRU GRU5 WHERE GRU5.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))))
                                                                                    END
                                                                                
                                                                            END 
                                                                        
                                                                END 
                                                            
                                                            END 
                                      END) FROM TGFGRU GG WHERE GG.CODGRUPOPROD = PRO.CODGRUPOPROD) = ADA.CODGRUPOPROD
                                      -----
                                      AND TRUNC(CAB.DTFATUR) BETWEEN PDTINI AND PDTFIN
                                      --AND (to_char(ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (TO_DATE(SYSDATE, 'DD/MM/YYYY'),'MONTH'),'DD/MM/YY'),-11),'MONTH'),'DD/MM/YY'),-1), 'd')) NOT IN (1,7)
                                      AND ADA.ID = FIELD_ID 
                                      AND CAB.CODVEND = IVEND.CODVEND
                                      AND ADA.CODGRUPOPROD = IEMPGRU2.GRUPO--APAGAR
                                      --(SELECT MAX(A.ID) FROM AD_GRUPOSPRODUSU A WHERE A.ID IN (SELECT MAX(AD.ID) FROM AD_GRUPOSPRODUSU AD INNER JOIN AD_GRUPROSPROD AA ON (AA.ID = AD.ID) WHERE TO_CHAR(AA.DTVIGOR, 'MM') = TO_CHAR(ADD_MONTHS(TRUNC(SYSDATE),-1), 'MM') GROUP BY AD.ID))
                                    GROUP BY CAB.CODVEND, CAB.CODEMP, ADA.CODGRUPOPROD, CAB.CODVEND, TO_CHAR(TRUNC(CAB.DTFATUR), 'd'), TRUNC(CAB.DTFATUR)
                                    ORDER BY 3) A)
                    LOOP
                        SELECT COUNT(*)
                        INTO IVENDDIAGRUPK
                        FROM AD_EMPVENDIAGRU AD
                        WHERE AD.ID = FIELD_ID
                          AND AD.IDMETEMP = IEMP.IDMETEMP
                          AND AD.IDEMPVEND = IEMPVEND;

                        IF IVENDDIAGRUPK = 0 THEN
                            INSERT INTO AD_EMPVENDIAGRU (ID, IDMETEMP, IDEMPVEND, IDEMPVENDIA, CODEMP, CODVEND, CODGRUPOPROD, VLR, PESO, META, DATA) VALUES
                            (FIELD_ID, IEMP.IDMETEMP, IEMPVEND, 1, IVENDDIAGRU.CODEMP, IVENDDIAGRU.CODVEND, IVENDDIAGRU.GRUPO, IVENDDIAGRU.TOTAL, (IVENDDIAGRU.TOTAL / IVENDDIAGRU.TOTALZAO) * 100 ,IVENDDIAGRU.META, IVENDDIAGRU.FATUR);
                            IVENDDIAGRUPK := 1;
                        ELSE
                        
                            SELECT MAX(IDEMPVENDIA) + 1
                            INTO IVENDDIAGRUPK
                            FROM AD_EMPVENDIAGRU AD
                            WHERE AD.ID = FIELD_ID
                              AND AD.IDMETEMP = IEMP.IDMETEMP
                              AND AD.IDEMPVEND = IEMPVEND;
                        
                            INSERT INTO AD_EMPVENDIAGRU (ID, IDMETEMP, IDEMPVEND, IDEMPVENDIA, CODEMP, CODVEND, CODGRUPOPROD, VLR, PESO, META, DATA) VALUES
                            (FIELD_ID, IEMP.IDMETEMP, IEMPVEND, IVENDDIAGRUPK, IVENDDIAGRU.CODEMP, IVENDDIAGRU.CODVEND, IVENDDIAGRU.GRUPO, IVENDDIAGRU.TOTAL, (IVENDDIAGRU.TOTAL / IVENDDIAGRU.TOTALZAO) * 100 ,IVENDDIAGRU.META, IVENDDIAGRU.FATUR);
                        END IF;
------------------------------------------------------------------------------------------------------------------------------------------------------------
--INSERE FILHOS DOS GRUPOS DOS VENDEDORES DAS EMPRESAS NOVO
------------------------------------------------------------------------------------------------------------------------------------------------------------
                        FOR IGRUVENFI IN (SELECT PRO.CODGRUPOPROD AS GRUPO
                                       ,  TO_CHAR(TRUNC(CAB.DTFATUR), 'd') AS DATA
                                       ,  TRUNC(CAB.DTFATUR) AS FATUR
                                       ,  CAB.CODEMP
                                       ,  CAB.CODVEND
                                       ,  SUM(((ITE.VLRTOT - ITE.VLRDESC - ITE.VLRREPRED + ITE.VLRSUBST + ITE.VLRIPI)  * VCA.INDITENSBRUTO) * CASE WHEN TOP.BONIFICACAO = 'S' THEN 0 ELSE 1 END * TOP.GOLDEV ) AS TOTAL
                                       , (SELECT SUM(((ITE.VLRTOT - ITE.VLRDESC - ITE.VLRREPRED + ITE.VLRSUBST + ITE.VLRIPI)  * VCA.INDITENSBRUTO) * CASE WHEN TOP.BONIFICACAO = 'S' THEN 0 ELSE 1 END * TOP.GOLDEV ) AS TOTAL
                                    FROM TGFCAB CAB INNER JOIN TGFITE ITE ON (CAB.NUNOTA = ITE.NUNOTA)
                                                    INNER JOIN TGFPRO PRO ON (ITE.CODPROD = PRO.CODPROD)
                                                    INNER JOIN VGFCAB VCA ON (CAB.NUNOTA = VCA.NUNOTA)
                                                    INNER JOIN TGFTOP TOP ON (CAB.CODTIPOPER = TOP.CODTIPOPER AND CAB.DHTIPOPER = TOP.DHALTER AND TOP.GOLSINAL = -1)
                                                    , AD_GRUPOSPRODUSU ADA
                                    WHERE CAB.CODTIPOPER IN (SELECT REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''),'[^,]+', 1, LEVEL) AS RESULTADO FROM DUAL CONNECT BY REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''), '[^,]+', 1, LEVEL) IS NOT NULL)
                                      AND CAB.STATUSNFE= 'A'
                                      AND CAB.CODEMP = IEMP.CODEMP
                                      AND CAB.CODVEND = IDIAVEND.CODVEND
                                      AND (SELECT (CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))) IS NOT NULL  
                                                        THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))
                                                        ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))) IS NOT NULL
                                                            THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))
                                                            ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))) IS NOT NULL
                                                                        THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))
                                                                        ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))) IS NOT NULL
                                                                                THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))
                                                                                ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))) IS NOT NULL
                                                                                            THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))))
                                                                                            ELSE TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU5.CODGRUPAI FROM TGFGRU GRU5 WHERE GRU5.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))))
                                                                                    END
                                                                                
                                                                            END 
                                                                        
                                                                END 
                                                            
                                                            END 
                                        END) FROM TGFGRU GG WHERE GG.CODGRUPOPROD = PRO.CODGRUPOPROD) = ADA.CODGRUPOPROD
                                      AND ADA.CODGRUPOPROD = IDIAVEND.GRUPO
                                      AND TRUNC(CAB.DTFATUR) = IDIAVEND.FATUR
                                      AND ADA.ID = FIELD_ID
                                      AND CAB.CODVEND = IDIAVEND.CODVEND) AS TOTALZAO
                                    FROM TGFCAB CAB INNER JOIN TGFITE ITE ON (CAB.NUNOTA = ITE.NUNOTA)
                                                    INNER JOIN TGFPRO PRO ON (ITE.CODPROD = PRO.CODPROD)
                                                    INNER JOIN VGFCAB VCA ON (CAB.NUNOTA = VCA.NUNOTA)
                                                    INNER JOIN TGFTOP TOP ON (CAB.CODTIPOPER = TOP.CODTIPOPER AND CAB.DHTIPOPER = TOP.DHALTER AND TOP.GOLSINAL = -1)
                                                    , AD_GRUPOSPRODUSU ADA
                                    WHERE CAB.CODTIPOPER IN (SELECT REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''),'[^,]+', 1, LEVEL) AS RESULTADO FROM DUAL CONNECT BY REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''), '[^,]+', 1, LEVEL) IS NOT NULL)
                                      AND CAB.STATUSNFE= 'A'
                                      AND CAB.CODEMP = IEMP.CODEMP
                                      AND CAB.CODVEND = IDIAVEND.CODVEND
                                      AND (SELECT (CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))) IS NOT NULL  
                                                        THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))
                                                        ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))) IS NOT NULL
                                                            THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))
                                                            ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))) IS NOT NULL
                                                                        THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))
                                                                        ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))) IS NOT NULL
                                                                                THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))
                                                                                ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))) IS NOT NULL
                                                                                            THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))))
                                                                                            ELSE TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU5.CODGRUPAI FROM TGFGRU GRU5 WHERE GRU5.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))))
                                                                                    END
                                                                                
                                                                            END 
                                                                        
                                                                END 
                                                            
                                                            END 
                                        END) FROM TGFGRU GG WHERE GG.CODGRUPOPROD = PRO.CODGRUPOPROD) = ADA.CODGRUPOPROD
                                      AND ADA.CODGRUPOPROD = IDIAVEND.GRUPO
                                      AND TRUNC(CAB.DTFATUR) = IDIAVEND.FATUR
                                      AND ADA.ID = FIELD_ID
                                      AND CAB.CODVEND = IDIAVEND.CODVEND
                                    GROUP BY CAB.CODVEND, CAB.CODEMP, PRO.CODGRUPOPROD, TO_CHAR(TRUNC(CAB.DTFATUR), 'd'), TRUNC(CAB.DTFATUR)
                                    ORDER BY 1)
                        LOOP
                            SELECT COUNT(*)
                            INTO IDGRUVENDFILHOPK
                            FROM AD_EMPGRUVENFI AD
                            WHERE AD.ID = FIELD_ID
                              AND AD.IDMETEMP = IEMP.IDMETEMP
                              AND AD.IDGRUEMPVEN = IDIAVENDPK;
                            --select * from AD_METEMPGRUSUBGRU
--RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#000000">
----Grupo FILHO já existe! <br> ' || to_char(FIELD_ID) ||' / ' || to_char(PDTINI) ||' / ' || to_char(PDTFIN) ||'.</font></b><br><font>');                      
                            IF IDGRUVENDFILHOPK = 0 THEN
                                INSERT INTO AD_EMPGRUVENFI (ID, IDMETEMP, IDGRUEMPVEN, IDGRUVENDFILHO, CODGRUPOPROD, CODEMP, CODVEND, VLR, DATA) VALUES
                                (FIELD_ID, IEMP.IDMETEMP, IDIAVENDPK, 1, IGRUVENFI.GRUPO, IGRUVENFI.CODEMP, IGRUVENFI.CODVEND, IGRUVENFI.TOTAL, IGRUVENFI.FATUR); 
                                IDGRUVENDFILHOPK := 1;
                            ELSE
                            
                                SELECT MAX(IDGRUVENDFILHO) + 1
                                INTO IDGRUVENDFILHOPK
                                FROM AD_EMPGRUVENFI AD
                                WHERE AD.ID = FIELD_ID
                                  AND AD.IDMETEMP = IEMP.IDMETEMP
                                  AND AD.IDGRUEMPVEN = IDIAVENDPK;
                            
                                INSERT INTO AD_EMPGRUVENFI (ID, IDMETEMP, IDGRUEMPVEN, IDGRUVENDFILHO, CODGRUPOPROD, CODEMP, CODVEND, VLR, DATA) VALUES
                                (FIELD_ID, IEMP.IDMETEMP, IDIAVENDPK, IDGRUVENDFILHOPK, IGRUVENFI.GRUPO, IGRUVENFI.CODEMP, IGRUVENFI.CODVEND, IGRUVENFI.TOTAL, IGRUVENFI.FATUR); 
                            END IF;
                        END LOOP; --INSERE FILHOS DOS GRUPOS DOS VENDEDORES DAS EMPRESAS
                    END LOOP;
                END LOOP; --INSERE VENDEDORES POR EMPRESA
            END LOOP; --INICIA DISTRIGUIÇÃO POR DIA NAS EMPRESAS
------------------------------------------------------------------------------------------------------------------------------------------------------------
--INICIA DISTRIGUIÇÃO POR DIA NAS EMPRESAS
------------------------------------------------------------------------------------------------------------------------------------------------------------
            FOR IEMPGRU IN (SELECT G.IDGRU, G.CODGRUPOPROD AS GRUPO, G.META, G.DATA, G.SUGESTAO, G.PERC, (SELECT SUM(A.META) FROM AD_GRUPOSPRODUSU A WHERE A.ID = G.ID) AS TOTALZAO
                            FROM AD_GRUPOSPRODUSU G 
                            WHERE ID = FIELD_ID)
            LOOP
------------------------------------------------------------------------------------------------------------------------------------------------------------          
--ATUALIZA DIAS E VENDEDORES POR EMPRESA
------------------------------------------------------------------------------------------------------------------------------------------------------------
                FOR IDIAVEND IN (SELECT GRUPO
                                      , DATA
                                      , FATUR
                                      , TOTAL
                                      , ((TOTAL / IEMPGRU.META)* 100) AS PERGRU
                                      , (SELECT SUM(TOTAL)
                                                               FROM ( 
                                                                     SELECT ADA.CODGRUPOPROD AS GRUPO,
                                                                     C.CODVEND,
                                                              TO_CHAR(TRUNC(C.DTFATUR), 'd') AS DATA,
                                                              TRUNC(C.DTFATUR) AS FATUR,
                                                              C.CODEMP,
                                                              --ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (TO_DATE(SYSDATE, 'DD/MM/YYYY'),'MONTH'),'DD/MM/YY'),-11),'MONTH'),'DD/MM/YY'),-1) AS DIAS,
                                                              SUM( ((ITE.VLRTOT - ITE.VLRDESC - ITE.VLRREPRED + ITE.VLRSUBST + ITE.VLRIPI)  * VCA.INDITENSBRUTO) * CASE WHEN TOP.BONIFICACAO = 'S' THEN 0 ELSE 1 END * TOP.GOLDEV ) AS TOTAL
                                                        FROM TGFCAB C INNER JOIN TGFITE ITE ON (C.NUNOTA = ITE.NUNOTA)
                                                                        INNER JOIN TGFPRO PRO ON (ITE.CODPROD = PRO.CODPROD)
                                                                        INNER JOIN VGFCAB VCA ON (C.NUNOTA = VCA.NUNOTA)
                                                                        INNER JOIN TGFTOP TOP ON (C.CODTIPOPER = TOP.CODTIPOPER AND C.DHTIPOPER = TOP.DHALTER AND TOP.GOLSINAL = -1)
                                                                        , AD_GRUPOSPRODUSU ADA
                                                        WHERE C.CODTIPOPER IN (SELECT REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''),'[^,]+', 1, LEVEL) AS RESULTADO FROM DUAL CONNECT BY REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''), '[^,]+', 1, LEVEL) IS NOT NULL)
                                                          AND C.STATUSNFE= 'A'
                                                          AND C.CODEMP = IEMP.CODEMP
                                                          AND (SELECT (CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))) IS NOT NULL  
                                                                            THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))
                                                                            ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))) IS NOT NULL
                                                                                THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))
                                                                                ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))) IS NOT NULL
                                                                                            THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))
                                                                                            ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))) IS NOT NULL
                                                                                                    THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))
                                                                                                    ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))) IS NOT NULL
                                                                                                                THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))))
                                                                                                                ELSE TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU5.CODGRUPAI FROM TGFGRU GRU5 WHERE GRU5.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))))
                                                                                                        END
                                                                                                    
                                                                                                END 
                                                                                            
                                                                                    END 
                                                                                
                                                                                END 
                                                          END) FROM TGFGRU GG WHERE GG.CODGRUPOPROD = PRO.CODGRUPOPROD) = ADA.CODGRUPOPROD
                                                          AND TRUNC(C.DTFATUR) BETWEEN PDTINI AND PDTFIN
                                                          AND ADA.ID = FIELD_ID 
                                                          AND ADA.CODGRUPOPROD = IEMPGRU.GRUPO--APAGAR
                                                        GROUP BY C.CODEMP, ADA.CODGRUPOPROD, TO_CHAR(TRUNC(C.DTFATUR), 'd'), C.CODVEND, TRUNC(C.DTFATUR)) CC
                                                        WHERE CC.CODVEND = A.CODVEND) AS TOTALZAO
                                      --FIM TOTALZAO -------------------------------------------------------------

                                      , CODEMP
                                      , CODVEND
                                      , TOTAL+(TOTAL/100)*10 AS META 
                                       FROM ( 
                                             SELECT ADA.CODGRUPOPROD AS GRUPO,
                                      TO_CHAR(TRUNC(CAB.DTFATUR), 'd') AS DATA,
                                      TRUNC(CAB.DTFATUR) AS FATUR,
                                      CAB.CODEMP,
                                      CAB.CODVEND,
                                      --ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (TO_DATE(SYSDATE, 'DD/MM/YYYY'),'MONTH'),'DD/MM/YY'),-11),'MONTH'),'DD/MM/YY'),-1) AS DIAS,
                                      SUM( ((ITE.VLRTOT - ITE.VLRDESC - ITE.VLRREPRED + ITE.VLRSUBST + ITE.VLRIPI)  * VCA.INDITENSBRUTO) * CASE WHEN TOP.BONIFICACAO = 'S' THEN 0 ELSE 1 END * TOP.GOLDEV ) AS TOTAL
                                FROM TGFCAB CAB INNER JOIN TGFITE ITE ON (CAB.NUNOTA = ITE.NUNOTA)
                                                INNER JOIN TGFPRO PRO ON (ITE.CODPROD = PRO.CODPROD)
                                                INNER JOIN VGFCAB VCA ON (CAB.NUNOTA = VCA.NUNOTA)
                                                INNER JOIN TGFTOP TOP ON (CAB.CODTIPOPER = TOP.CODTIPOPER AND CAB.DHTIPOPER = TOP.DHALTER AND TOP.GOLSINAL = -1)
                                                , AD_GRUPOSPRODUSU ADA
                                WHERE CAB.CODTIPOPER IN (SELECT REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''),'[^,]+', 1, LEVEL) AS RESULTADO FROM DUAL CONNECT BY REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''), '[^,]+', 1, LEVEL) IS NOT NULL)
                                  AND CAB.STATUSNFE= 'A'
                                  AND CAB.CODEMP = IEMP.CODEMP
                                  AND (SELECT (CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))) IS NOT NULL  
                                                    THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))
                                                    ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))) IS NOT NULL
                                                        THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))
                                                        ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))) IS NOT NULL
                                                                    THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))
                                                                    ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))) IS NOT NULL
                                                                            THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))
                                                                            ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))) IS NOT NULL
                                                                                        THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))))
                                                                                        ELSE TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU5.CODGRUPAI FROM TGFGRU GRU5 WHERE GRU5.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))))
                                                                                END
                                                                            
                                                                        END 
                                                                    
                                                            END 
                                                        
                                                        END 
                                  END) FROM TGFGRU GG WHERE GG.CODGRUPOPROD = PRO.CODGRUPOPROD) = ADA.CODGRUPOPROD
                                  -----
                                  AND TRUNC(CAB.DTFATUR) BETWEEN PDTINI AND PDTFIN
                                  --AND (to_char(ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (TO_DATE(SYSDATE, 'DD/MM/YYYY'),'MONTH'),'DD/MM/YY'),-11),'MONTH'),'DD/MM/YY'),-1), 'd')) NOT IN (1,7)
                                  AND ADA.ID = FIELD_ID 
                                  AND ADA.CODGRUPOPROD = IEMPGRU.GRUPO--APAGAR
                                  --(SELECT MAX(A.ID) FROM AD_GRUPOSPRODUSU A WHERE A.ID IN (SELECT MAX(AD.ID) FROM AD_GRUPOSPRODUSU AD INNER JOIN AD_GRUPROSPROD AA ON (AA.ID = AD.ID) WHERE TO_CHAR(AA.DTVIGOR, 'MM') = TO_CHAR(ADD_MONTHS(TRUNC(SYSDATE),-1), 'MM') GROUP BY AD.ID))
                                GROUP BY CAB.CODVEND, CAB.CODEMP, ADA.CODGRUPOPROD, CAB.CODVEND, TO_CHAR(TRUNC(CAB.DTFATUR), 'd'), TRUNC(CAB.DTFATUR)
                                ORDER BY 3) A)
                LOOP
                    SELECT COUNT(*)
                    INTO IDIAVENDPK
                    FROM AD_METEMPVENDDIA AD
                    WHERE AD.ID = FIELD_ID
                      AND AD.IDMETEMP = IEMP.IDMETEMP;
                    
                    IF IDIAVENDPK = 0 THEN
                        INSERT INTO AD_METEMPVENDDIA (ID, IDMETEMP, IDGRUEMPVEN, CODGRUPOPROD, CODEMP, CODVEND, DATA, VLR, PESO, T) VALUES
                        (FIELD_ID, IEMP.IDMETEMP, 1, IDIAVEND.GRUPO, IEMP.CODEMP, IDIAVEND.CODVEND, IDIAVEND.FATUR, IDIAVEND.META, (IDIAVEND.TOTAL / IDIAVEND.TOTALZAO) * 100, (IDIAVEND.META / IEMP.META) * 100);
                        IDIAVENDPK := 1;
                    ELSE
                    
                        SELECT MAX(IDGRUEMPVEN) + 1
                        INTO IDIAVENDPK
                        FROM AD_METEMPVENDDIA AD
                        WHERE AD.ID = FIELD_ID
                          AND AD.IDMETEMP = IEMP.IDMETEMP;
                    
                        INSERT INTO AD_METEMPVENDDIA (ID, IDMETEMP, IDGRUEMPVEN, CODGRUPOPROD, CODEMP, CODVEND, DATA, VLR, PESO, T) VALUES
                        (FIELD_ID, IEMP.IDMETEMP, IDIAVENDPK, IDIAVEND.GRUPO, IEMP.CODEMP, IDIAVEND.CODVEND, IDIAVEND.FATUR, IDIAVEND.META, (IDIAVEND.TOTAL / IDIAVEND.TOTALZAO) * 100, (IDIAVEND.META / IEMP.META) * 100) ;
                    END IF;

------------------------------------------------------------------------------------------------------------------------------------------------------------
--INSERE FILHOS DOS GRUPOS DOS VENDEDORES DAS EMPRESAS
------------------------------------------------------------------------------------------------------------------------------------------------------------
                        FOR IGRUVENFI IN (SELECT PRO.CODGRUPOPROD AS GRUPO
                                       ,  TO_CHAR(TRUNC(CAB.DTFATUR), 'd') AS DATA
                                       ,  TRUNC(CAB.DTFATUR) AS FATUR
                                       ,  CAB.CODEMP
                                       ,  CAB.CODVEND
                                       ,  SUM(((ITE.VLRTOT - ITE.VLRDESC - ITE.VLRREPRED + ITE.VLRSUBST + ITE.VLRIPI)  * VCA.INDITENSBRUTO) * CASE WHEN TOP.BONIFICACAO = 'S' THEN 0 ELSE 1 END * TOP.GOLDEV ) AS TOTAL
                                       , (SELECT SUM(((ITE.VLRTOT - ITE.VLRDESC - ITE.VLRREPRED + ITE.VLRSUBST + ITE.VLRIPI)  * VCA.INDITENSBRUTO) * CASE WHEN TOP.BONIFICACAO = 'S' THEN 0 ELSE 1 END * TOP.GOLDEV ) AS TOTAL
                                    FROM TGFCAB CAB INNER JOIN TGFITE ITE ON (CAB.NUNOTA = ITE.NUNOTA)
                                                    INNER JOIN TGFPRO PRO ON (ITE.CODPROD = PRO.CODPROD)
                                                    INNER JOIN VGFCAB VCA ON (CAB.NUNOTA = VCA.NUNOTA)
                                                    INNER JOIN TGFTOP TOP ON (CAB.CODTIPOPER = TOP.CODTIPOPER AND CAB.DHTIPOPER = TOP.DHALTER AND TOP.GOLSINAL = -1)
                                                    , AD_GRUPOSPRODUSU ADA
                                    WHERE CAB.CODTIPOPER IN (SELECT REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''),'[^,]+', 1, LEVEL) AS RESULTADO FROM DUAL CONNECT BY REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''), '[^,]+', 1, LEVEL) IS NOT NULL)
                                      AND CAB.STATUSNFE= 'A'
                                      AND CAB.CODEMP = IEMP.CODEMP
                                      AND CAB.CODVEND = IDIAVEND.CODVEND
                                      AND (SELECT (CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))) IS NOT NULL  
                                                        THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))
                                                        ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))) IS NOT NULL
                                                            THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))
                                                            ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))) IS NOT NULL
                                                                        THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))
                                                                        ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))) IS NOT NULL
                                                                                THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))
                                                                                ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))) IS NOT NULL
                                                                                            THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))))
                                                                                            ELSE TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU5.CODGRUPAI FROM TGFGRU GRU5 WHERE GRU5.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))))
                                                                                    END
                                                                                
                                                                            END 
                                                                        
                                                                END 
                                                            
                                                            END 
                                        END) FROM TGFGRU GG WHERE GG.CODGRUPOPROD = PRO.CODGRUPOPROD) = ADA.CODGRUPOPROD
                                      AND ADA.CODGRUPOPROD = IDIAVEND.GRUPO
                                      AND TRUNC(CAB.DTFATUR) = IDIAVEND.FATUR
                                      AND ADA.ID = FIELD_ID
                                      AND CAB.CODVEND = IDIAVEND.CODVEND) AS TOTALZAO
                                    FROM TGFCAB CAB INNER JOIN TGFITE ITE ON (CAB.NUNOTA = ITE.NUNOTA)
                                                    INNER JOIN TGFPRO PRO ON (ITE.CODPROD = PRO.CODPROD)
                                                    INNER JOIN VGFCAB VCA ON (CAB.NUNOTA = VCA.NUNOTA)
                                                    INNER JOIN TGFTOP TOP ON (CAB.CODTIPOPER = TOP.CODTIPOPER AND CAB.DHTIPOPER = TOP.DHALTER AND TOP.GOLSINAL = -1)
                                                    , AD_GRUPOSPRODUSU ADA
                                    WHERE CAB.CODTIPOPER IN (SELECT REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''),'[^,]+', 1, LEVEL) AS RESULTADO FROM DUAL CONNECT BY REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''), '[^,]+', 1, LEVEL) IS NOT NULL)
                                      AND CAB.STATUSNFE= 'A'
                                      AND CAB.CODEMP = IEMP.CODEMP
                                      AND CAB.CODVEND = IDIAVEND.CODVEND
                                      AND (SELECT (CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))) IS NOT NULL  
                                                        THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))
                                                        ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))) IS NOT NULL
                                                            THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))
                                                            ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))) IS NOT NULL
                                                                        THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))
                                                                        ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))) IS NOT NULL
                                                                                THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))
                                                                                ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))) IS NOT NULL
                                                                                            THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))))
                                                                                            ELSE TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU5.CODGRUPAI FROM TGFGRU GRU5 WHERE GRU5.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))))
                                                                                    END
                                                                                
                                                                            END 
                                                                        
                                                                END 
                                                            
                                                            END 
                                        END) FROM TGFGRU GG WHERE GG.CODGRUPOPROD = PRO.CODGRUPOPROD) = ADA.CODGRUPOPROD
                                      AND ADA.CODGRUPOPROD = IDIAVEND.GRUPO
                                      AND TRUNC(CAB.DTFATUR) = IDIAVEND.FATUR
                                      AND ADA.ID = FIELD_ID
                                      AND CAB.CODVEND = IDIAVEND.CODVEND
                                    GROUP BY CAB.CODVEND, CAB.CODEMP, PRO.CODGRUPOPROD, TO_CHAR(TRUNC(CAB.DTFATUR), 'd'), TRUNC(CAB.DTFATUR)
                                    ORDER BY 1)
                        LOOP
                            SELECT COUNT(*)
                            INTO IDGRUVENDFILHOPK
                            FROM AD_EMPGRUVENFI AD
                            WHERE AD.ID = FIELD_ID
                              AND AD.IDMETEMP = IEMP.IDMETEMP
                              AND AD.IDGRUEMPVEN = IDIAVENDPK;
                            --select * from AD_METEMPGRUSUBGRU
--RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#000000">
----Grupo FILHO já existe! <br> ' || to_char(FIELD_ID) ||' / ' || to_char(PDTINI) ||' / ' || to_char(PDTFIN) ||'.</font></b><br><font>');                      
                            IF IDGRUVENDFILHOPK = 0 THEN
                                INSERT INTO AD_EMPGRUVENFI (ID, IDMETEMP, IDGRUEMPVEN, IDGRUVENDFILHO, CODGRUPOPROD, CODEMP, CODVEND, VLR, DATA) VALUES
                                (FIELD_ID, IEMP.IDMETEMP, IDIAVENDPK, 1, IGRUVENFI.GRUPO, IGRUVENFI.CODEMP, IGRUVENFI.CODVEND, IGRUVENFI.TOTAL, IGRUVENFI.FATUR); 
                                IDGRUVENDFILHOPK := 1;
                            ELSE
                            
                                SELECT MAX(IDGRUVENDFILHO) + 1
                                INTO IDGRUVENDFILHOPK
                                FROM AD_EMPGRUVENFI AD
                                WHERE AD.ID = FIELD_ID
                                  AND AD.IDMETEMP = IEMP.IDMETEMP
                                  AND AD.IDGRUEMPVEN = IDIAVENDPK;
                            
                                INSERT INTO AD_EMPGRUVENFI (ID, IDMETEMP, IDGRUEMPVEN, IDGRUVENDFILHO, CODGRUPOPROD, CODEMP, CODVEND, VLR, DATA) VALUES
                                (FIELD_ID, IEMP.IDMETEMP, IDIAVENDPK, IDGRUVENDFILHOPK, IGRUVENFI.GRUPO, IGRUVENFI.CODEMP, IGRUVENFI.CODVEND, IGRUVENFI.TOTAL, IGRUVENFI.FATUR); 
                            END IF;
                        END LOOP; --INSERE FILHOS DOS GRUPOS DOS VENDEDORES DAS EMPRESAS
                END LOOP; --ATUALIZA DIAS E VENDEDORES POR EMPRESA
------------------------------------------------------------------------------------------------------------------------------------------------------------          
--INSERE OS GRUPOS PAI POR DIAS DAS EMPRESAS
------------------------------------------------------------------------------------------------------------------------------------------------------------
                FOR IEMPDIAS IN (SELECT GRUPO
                                      , DATA
                                      , FATUR
                                      , TOTAL
                                      , ((TOTAL / IEMPGRU.META)* 100) AS PERGRU
                                      , ((TOTAL / (
                                      --TOTALZAO------------------------------------------------------------------
                                                               SELECT SUM(TOTAL)
                                                               FROM ( 
                                                                     SELECT ADA.CODGRUPOPROD AS GRUPO,
                                                              TO_CHAR(TRUNC(CAB.DTFATUR), 'd') AS DATA,
                                                              TRUNC(CAB.DTFATUR) AS FATUR,
                                                              CAB.CODEMP,
                                                              --ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (TO_DATE(SYSDATE, 'DD/MM/YYYY'),'MONTH'),'DD/MM/YY'),-11),'MONTH'),'DD/MM/YY'),-1) AS DIAS,
                                                              SUM( ((ITE.VLRTOT - ITE.VLRDESC - ITE.VLRREPRED + ITE.VLRSUBST + ITE.VLRIPI)  * VCA.INDITENSBRUTO) * CASE WHEN TOP.BONIFICACAO = 'S' THEN 0 ELSE 1 END * TOP.GOLDEV ) AS TOTAL
                                                        FROM TGFCAB CAB INNER JOIN TGFITE ITE ON (CAB.NUNOTA = ITE.NUNOTA)
                                                                        INNER JOIN TGFPRO PRO ON (ITE.CODPROD = PRO.CODPROD)
                                                                        INNER JOIN VGFCAB VCA ON (CAB.NUNOTA = VCA.NUNOTA)
                                                                        INNER JOIN TGFTOP TOP ON (CAB.CODTIPOPER = TOP.CODTIPOPER AND CAB.DHTIPOPER = TOP.DHALTER AND TOP.GOLSINAL = -1)
                                                                        , AD_GRUPOSPRODUSU ADA
                                                        WHERE CAB.CODTIPOPER IN (SELECT REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''),'[^,]+', 1, LEVEL) AS RESULTADO FROM DUAL CONNECT BY REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''), '[^,]+', 1, LEVEL) IS NOT NULL)
                                                          AND CAB.STATUSNFE= 'A'
                                                          AND CAB.CODEMP = IEMP.CODEMP
                                                          AND (SELECT (CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))) IS NOT NULL  
                                                                            THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))
                                                                            ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))) IS NOT NULL
                                                                                THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))
                                                                                ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))) IS NOT NULL
                                                                                            THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))
                                                                                            ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))) IS NOT NULL
                                                                                                    THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))
                                                                                                    ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))) IS NOT NULL
                                                                                                                THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))))
                                                                                                                ELSE TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU5.CODGRUPAI FROM TGFGRU GRU5 WHERE GRU5.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))))
                                                                                                        END
                                                                                                    
                                                                                                END 
                                                                                            
                                                                                    END 
                                                                                
                                                                                END 
                                                          END) FROM TGFGRU GG WHERE GG.CODGRUPOPROD = PRO.CODGRUPOPROD) = ADA.CODGRUPOPROD
                                                          AND TRUNC(CAB.DTFATUR) BETWEEN PDTINI AND PDTFIN
                                                          AND ADA.ID = FIELD_ID 
                                                          AND ADA.CODGRUPOPROD = IEMPGRU.GRUPO
                                                        GROUP BY CAB.CODEMP, ADA.CODGRUPOPROD, TO_CHAR(TRUNC(CAB.DTFATUR), 'd'), TRUNC(CAB.DTFATUR))
                                      --FIM TOTALZAO -------------------------------------------------------------
                                      ) * 100)) AS PER
                                      , CODEMP
                                      , TOTAL+(TOTAL/100)*10 AS META 
                                       FROM ( 
                                             SELECT ADA.CODGRUPOPROD AS GRUPO,
                                      TO_CHAR(TRUNC(CAB.DTFATUR), 'd') AS DATA,
                                      TRUNC(CAB.DTFATUR) AS FATUR,
                                      CAB.CODEMP,
                                      --ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (TO_DATE(SYSDATE, 'DD/MM/YYYY'),'MONTH'),'DD/MM/YY'),-11),'MONTH'),'DD/MM/YY'),-1) AS DIAS,
                                      SUM( ((ITE.VLRTOT - ITE.VLRDESC - ITE.VLRREPRED + ITE.VLRSUBST + ITE.VLRIPI)  * VCA.INDITENSBRUTO) * CASE WHEN TOP.BONIFICACAO = 'S' THEN 0 ELSE 1 END * TOP.GOLDEV ) AS TOTAL
                                FROM TGFCAB CAB INNER JOIN TGFITE ITE ON (CAB.NUNOTA = ITE.NUNOTA)
                                                INNER JOIN TGFPRO PRO ON (ITE.CODPROD = PRO.CODPROD)
                                                INNER JOIN VGFCAB VCA ON (CAB.NUNOTA = VCA.NUNOTA)
                                                INNER JOIN TGFTOP TOP ON (CAB.CODTIPOPER = TOP.CODTIPOPER AND CAB.DHTIPOPER = TOP.DHALTER AND TOP.GOLSINAL = -1)
                                                , AD_GRUPOSPRODUSU ADA
                                WHERE CAB.CODTIPOPER IN (SELECT REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''),'[^,]+', 1, LEVEL) AS RESULTADO FROM DUAL CONNECT BY REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''), '[^,]+', 1, LEVEL) IS NOT NULL)
                                  AND CAB.STATUSNFE= 'A'
                                  AND CAB.CODEMP = IEMP.CODEMP
                                  AND (SELECT (CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))) IS NOT NULL  
                                                    THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))
                                                    ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))) IS NOT NULL
                                                        THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))
                                                        ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))) IS NOT NULL
                                                                    THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))
                                                                    ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))) IS NOT NULL
                                                                            THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))
                                                                            ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))) IS NOT NULL
                                                                                        THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))))
                                                                                        ELSE TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU5.CODGRUPAI FROM TGFGRU GRU5 WHERE GRU5.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))))
                                                                                END
                                                                            
                                                                        END 
                                                                    
                                                            END 
                                                        
                                                        END 
                                  END) FROM TGFGRU GG WHERE GG.CODGRUPOPROD = PRO.CODGRUPOPROD) = ADA.CODGRUPOPROD
                                  AND TRUNC(CAB.DTFATUR) BETWEEN PDTINI AND PDTFIN
                                  AND ADA.ID = FIELD_ID 
                                  AND ADA.CODGRUPOPROD = IEMPGRU.GRUPO
                                GROUP BY CAB.CODEMP, ADA.CODGRUPOPROD, TO_CHAR(TRUNC(CAB.DTFATUR), 'd'), TRUNC(CAB.DTFATUR)
                                ORDER BY 3))
                LOOP
                    SELECT COUNT(*)
                    INTO CONTDIAS
                    FROM AD_GRUMETEMPDIA AD
                    WHERE AD.ID = FIELD_ID
                      AND AD.IDMETEMP = IEMP.IDMETEMP;
                    
                    IF CONTDIAS = 0 THEN
                        INSERT INTO AD_GRUMETEMPDIA (ID, IDMETEMP, IDGRUMETDIA, CODGRUPOPROD, DATA, PESO, PER, VLRVENDA, META, PERGRUEMP, CODEMP) VALUES 
                        (FIELD_ID, IEMP.IDMETEMP, 1, IEMPDIAS.GRUPO, IEMPDIAS.FATUR, IEMPDIAS.PER, 10, IEMPDIAS.TOTAL, IEMPDIAS.META, IEMPDIAS.PERGRU, IEMPDIAS.CODEMP);
                    ELSE
                        INSERT INTO AD_GRUMETEMPDIA (ID, IDMETEMP, IDGRUMETDIA, CODGRUPOPROD, DATA, PESO, PER, VLRVENDA, META, PERGRUEMP, CODEMP) VALUES 
                        (FIELD_ID, IEMP.IDMETEMP, (SELECT MAX(IDGRUMETDIA) + 1 FROM AD_GRUMETEMPDIA), IEMPDIAS.GRUPO, IEMPDIAS.FATUR, IEMPDIAS.PER, 10, IEMPDIAS.TOTAL, IEMPDIAS.META, IEMPDIAS.PERGRU, IEMPDIAS.CODEMP); 
                    END IF;
------------------------------------------------------------------------------------------------------------------------------------------------------------          
--INSERE OS GRUPOS FILHOS DOS GRUPOS PAI DA EMPRESA
------------------------------------------------------------------------------------------------------------------------------------------------------------
                    FOR IGRUFI IN ( 
                               SELECT PRO.CODGRUPOPROD AS GRUPO,
                                      TO_CHAR(TRUNC(CAB.DTFATUR), 'd') AS DATA,
                                      TRUNC(CAB.DTFATUR) AS FATUR,
                    ------------------------------------TOTALZAO
                                      (SELECT SUM( ((ITE.VLRTOT - ITE.VLRDESC - ITE.VLRREPRED + ITE.VLRSUBST + ITE.VLRIPI)  * VCA.INDITENSBRUTO) * CASE WHEN TOP.BONIFICACAO = 'S' THEN 0 ELSE 1 END * TOP.GOLDEV ) AS TOTAL
                                FROM TGFCAB CAB INNER JOIN TGFITE ITE ON (CAB.NUNOTA = ITE.NUNOTA)
                                                INNER JOIN TGFPRO PRO ON (ITE.CODPROD = PRO.CODPROD)
                                                INNER JOIN VGFCAB VCA ON (CAB.NUNOTA = VCA.NUNOTA)
                                                INNER JOIN TGFTOP TOP ON (CAB.CODTIPOPER = TOP.CODTIPOPER AND CAB.DHTIPOPER = TOP.DHALTER AND TOP.GOLSINAL = -1)
                                                , AD_GRUPOSPRODUSU ADA
                                WHERE CAB.CODTIPOPER IN (SELECT REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''),'[^,]+', 1, LEVEL) AS RESULTADO FROM DUAL CONNECT BY REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''), '[^,]+', 1, LEVEL) IS NOT NULL)
                                  AND CAB.STATUSNFE= 'A'
                                  AND CAB.CODEMP = IEMP.CODEMP
                                  AND (SELECT (CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))) IS NOT NULL  
                                                    THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))
                                                    ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))) IS NOT NULL
                                                        THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))
                                                        ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))) IS NOT NULL
                                                                    THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))
                                                                    ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))) IS NOT NULL
                                                                            THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))
                                                                            ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))) IS NOT NULL
                                                                                        THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))))
                                                                                        ELSE TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU5.CODGRUPAI FROM TGFGRU GRU5 WHERE GRU5.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))))
                                                                                END
                                                                            
                                                                        END 
                                                                    
                                                            END 
                                                        
                                                        END 
                                  END) FROM TGFGRU GG WHERE GG.CODGRUPOPROD = PRO.CODGRUPOPROD) = ADA.CODGRUPOPROD
                                  AND ADA.CODGRUPOPROD = IEMPDIAS.GRUPO
                                  AND TRUNC(CAB.DTFATUR) = IEMPDIAS.FATUR
                                  AND ADA.ID = FIELD_ID) AS TOTALZAO,
                    --------------------------------------------
                                      CAB.CODEMP,
                                      (SELECT AD.IDGRUMETDIA FROM AD_GRUMETEMPDIA AD WHERE AD.ID = FIELD_ID  AND AD.CODEMP = IEMP.CODEMP  AND AD.DATA = IEMPDIAS.FATUR  AND AD.CODGRUPOPROD = IEMPDIAS.GRUPO) AS IDGRUMETDIA,
                                      ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (TO_DATE(SYSDATE, 'DD/MM/YYYY'),'MONTH'),'DD/MM/YY'),-11),'MONTH'),'DD/MM/YY'),-1) AS DIAS,
                                      SUM( ((ITE.VLRTOT - ITE.VLRDESC - ITE.VLRREPRED + ITE.VLRSUBST + ITE.VLRIPI)  * VCA.INDITENSBRUTO) * CASE WHEN TOP.BONIFICACAO = 'S' THEN 0 ELSE 1 END * TOP.GOLDEV ) AS TOTAL
                                FROM TGFCAB CAB INNER JOIN TGFITE ITE ON (CAB.NUNOTA = ITE.NUNOTA)
                                                INNER JOIN TGFPRO PRO ON (ITE.CODPROD = PRO.CODPROD)
                                                INNER JOIN VGFCAB VCA ON (CAB.NUNOTA = VCA.NUNOTA)
                                                INNER JOIN TGFTOP TOP ON (CAB.CODTIPOPER = TOP.CODTIPOPER AND CAB.DHTIPOPER = TOP.DHALTER AND TOP.GOLSINAL = -1)
                                                , AD_GRUPOSPRODUSU ADA
                                WHERE CAB.CODTIPOPER IN (SELECT REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''),'[^,]+', 1, LEVEL) AS RESULTADO FROM DUAL CONNECT BY REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''), '[^,]+', 1, LEVEL) IS NOT NULL)
                                  AND CAB.STATUSNFE= 'A'
                                  AND CAB.CODEMP = IEMP.CODEMP
                                  AND (SELECT (CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))) IS NOT NULL  
                                                    THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))
                                                    ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))) IS NOT NULL
                                                        THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))
                                                        ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))) IS NOT NULL
                                                                    THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))
                                                                    ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))) IS NOT NULL
                                                                            THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))
                                                                            ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))) IS NOT NULL
                                                                                        THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))))
                                                                                        ELSE TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU5.CODGRUPAI FROM TGFGRU GRU5 WHERE GRU5.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))))
                                                                                END
                                                                            
                                                                        END 
                                                                    
                                                            END 
                                                        
                                                        END 
                                  END) FROM TGFGRU GG WHERE GG.CODGRUPOPROD = PRO.CODGRUPOPROD) = ADA.CODGRUPOPROD
                                  AND ADA.CODGRUPOPROD = IEMPDIAS.GRUPO
                                  AND TRUNC(CAB.DTFATUR) = IEMPDIAS.FATUR
                                  AND ADA.ID = FIELD_ID
                                GROUP BY CAB.CODEMP, PRO.CODGRUPOPROD, TO_CHAR(TRUNC(CAB.DTFATUR), 'd'), TRUNC(CAB.DTFATUR)
                                ORDER BY 1)
                    LOOP
                        SELECT COUNT(*)
                        INTO CONTDIAS
                        FROM AD_METEMPGRUSUBGRU AD
                        WHERE AD.ID = FIELD_ID
                          AND AD.IDMETEMP = IEMP.IDMETEMP
                          AND AD.IDGRUMETDIA = IGRUFI.IDGRUMETDIA;
                        
                        IF CONTDIAS = 0 THEN
                            INSERT INTO AD_METEMPGRUSUBGRU (ID, IDMETEMP, IDGRUMETDIA, IDEMPGRUFI, CODGRUPOPROD, VLR, CODEMP, DATA, PESO) VALUES
                            (FIELD_ID, IEMP.IDMETEMP, IGRUFI.IDGRUMETDIA, 1, IGRUFI.GRUPO, IGRUFI.TOTAL, IEMP.CODEMP, IGRUFI.FATUR, (IGRUFI.TOTAL / IGRUFI.TOTALZAO)*100 );
                            IDEMPGRUFIPK := 1;
                        ELSE
                        
                            SELECT MAX(IDEMPGRUFI) + 1
                            INTO IDEMPGRUFIPK
                            FROM AD_METEMPGRUSUBGRU AD
                            WHERE AD.ID = FIELD_ID
                              AND AD.IDMETEMP = IEMP.IDMETEMP
                              AND AD.IDGRUMETDIA = IGRUFI.IDGRUMETDIA;
                        
                            INSERT INTO AD_METEMPGRUSUBGRU (ID, IDMETEMP, IDGRUMETDIA, IDEMPGRUFI, CODGRUPOPROD, VLR, CODEMP, DATA, PESO) VALUES
                            (FIELD_ID, IEMP.IDMETEMP, IGRUFI.IDGRUMETDIA, IDEMPGRUFIPK, IGRUFI.GRUPO, IGRUFI.TOTAL, IEMP.CODEMP, IGRUFI.FATUR, (IGRUFI.TOTAL / IGRUFI.TOTALZAO)*100 ); 
                        END IF;
------------------------------------------------------------------------------------------------------------------------------------------------------------          
--INSERE OS VENDEDORES COM GRUPOS FILHOS
------------------------------------------------------------------------------------------------------------------------------------------------------------
                        FOR IGRUFIVEND IN (SELECT GRUPO
                                             , DATA
                                             , FATUR
                                             , CODEMP
                                             , CODVEND
                                             , IDGRUMETDIA
                                             , DIAS
                                             , TOTAL,
 -----TOTALZAO----------------------------------------------------------------------------------------------------
                                               (SELECT SUM(TOTAL) 
                                                FROM (
                                                      SELECT PRO.CODGRUPOPROD AS GRUPO
                                                          , TO_CHAR(TRUNC(CAB.DTFATUR), 'd') AS DATA
                                                          , TRUNC(CAB.DTFATUR) AS FATUR
                                                          , CAB.CODEMP
                                                          , CAB.CODVEND
                                                          , (SELECT AD.IDGRUMETDIA FROM AD_GRUMETEMPDIA AD WHERE AD.ID = FIELD_ID  AND AD.CODEMP = IEMP.CODEMP  AND AD.DATA = IEMPDIAS.FATUR  AND AD.CODGRUPOPROD = IEMPDIAS.GRUPO) AS IDGRUMETDIA
                                                          , ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (TO_DATE(SYSDATE, 'DD/MM/YYYY'),'MONTH'),'DD/MM/YY'),-11),'MONTH'),'DD/MM/YY'),-1) AS DIAS
                                                          , SUM( ((ITE.VLRTOT - ITE.VLRDESC - ITE.VLRREPRED + ITE.VLRSUBST + ITE.VLRIPI)  * VCA.INDITENSBRUTO) * CASE WHEN TOP.BONIFICACAO = 'S' THEN 0 ELSE 1 END * TOP.GOLDEV ) AS TOTAL
                                                      FROM TGFCAB CAB INNER JOIN TGFITE ITE ON (CAB.NUNOTA = ITE.NUNOTA)
                                                                     INNER JOIN TGFPRO PRO ON (ITE.CODPROD = PRO.CODPROD)
                                                                     INNER JOIN VGFCAB VCA ON (CAB.NUNOTA = VCA.NUNOTA)
                                                                     INNER JOIN TGFTOP TOP ON (CAB.CODTIPOPER = TOP.CODTIPOPER AND CAB.DHTIPOPER = TOP.DHALTER AND TOP.GOLSINAL = -1)
                                                                     , AD_GRUPOSPRODUSU ADA
                                                      WHERE CAB.CODTIPOPER IN (SELECT REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''),'[^,]+', 1, LEVEL) AS RESULTADO FROM DUAL CONNECT BY REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''), '[^,]+', 1, LEVEL) IS NOT NULL)
                                                        AND CAB.STATUSNFE= 'A'
                                                        AND CAB.CODEMP = IEMP.CODEMP
                                                        AND (SELECT (CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))) IS NOT NULL  
                                                                            THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))
                                                                            ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))) IS NOT NULL
                                                                                THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))
                                                                                ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))) IS NOT NULL
                                                                                            THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))
                                                                                            ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))) IS NOT NULL
                                                                                                    THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))
                                                                                                    ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))) IS NOT NULL
                                                                                                                THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))))
                                                                                                                ELSE TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU5.CODGRUPAI FROM TGFGRU GRU5 WHERE GRU5.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))))
                                                                                                        END
                                                                                                    
                                                                                                END 
                                                                                            
                                                                                    END 
                                                                                
                                                                                END 
                                                        END) FROM TGFGRU GG WHERE GG.CODGRUPOPROD = PRO.CODGRUPOPROD) = ADA.CODGRUPOPROD
                                                        AND ADA.CODGRUPOPROD = IEMPDIAS.GRUPO
                                                        AND TRUNC(CAB.DTFATUR) = IEMPDIAS.FATUR
                                                        AND ADA.ID = FIELD_ID
                                                      GROUP BY CAB.CODEMP, PRO.CODGRUPOPROD, TO_CHAR(TRUNC(CAB.DTFATUR), 'd'), TRUNC(CAB.DTFATUR), CAB.CODVEND
                                                      ORDER BY 1)
                                                WHERE GRUPO = IGRUFI.GRUPO) AS TOTALZAO
---------------------------------------------------------------------------------------------------------- 
                                          FROM (
                                               SELECT PRO.CODGRUPOPROD AS GRUPO
                                                   , TO_CHAR(TRUNC(CAB.DTFATUR), 'd') AS DATA
                                                   , TRUNC(CAB.DTFATUR) AS FATUR
                                                   , CAB.CODEMP    
                                                   , CAB.CODVEND
                                                   , (SELECT AD.IDGRUMETDIA FROM AD_GRUMETEMPDIA AD WHERE AD.ID = FIELD_ID  AND AD.CODEMP = IEMP.CODEMP  AND AD.DATA = IEMPDIAS.FATUR  AND AD.CODGRUPOPROD = IEMPDIAS.GRUPO) AS IDGRUMETDIA
                                                   , ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (TO_DATE(SYSDATE, 'DD/MM/YYYY'),'MONTH'),'DD/MM/YY'),-11),'MONTH'),'DD/MM/YY'),-1) AS DIAS
                                                   , SUM( ((ITE.VLRTOT - ITE.VLRDESC - ITE.VLRREPRED + ITE.VLRSUBST + ITE.VLRIPI)  * VCA.INDITENSBRUTO) * CASE WHEN TOP.BONIFICACAO = 'S' THEN 0 ELSE 1 END * TOP.GOLDEV ) AS TOTAL
                                                FROM TGFCAB CAB INNER JOIN TGFITE ITE ON (CAB.NUNOTA = ITE.NUNOTA)
                                                               INNER JOIN TGFPRO PRO ON (ITE.CODPROD = PRO.CODPROD)
                                                               INNER JOIN VGFCAB VCA ON (CAB.NUNOTA = VCA.NUNOTA)
                                                               INNER JOIN TGFTOP TOP ON (CAB.CODTIPOPER = TOP.CODTIPOPER AND CAB.DHTIPOPER = TOP.DHALTER AND TOP.GOLSINAL = -1)
                                                               , AD_GRUPOSPRODUSU ADA
                                                WHERE CAB.CODTIPOPER IN (SELECT REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''),'[^,]+', 1, LEVEL) AS RESULTADO FROM DUAL CONNECT BY REGEXP_SUBSTR(REPLACE(PCODTIPOPER, ' ',''), '[^,]+', 1, LEVEL) IS NOT NULL)
                                                  AND CAB.STATUSNFE= 'A'
                                                  AND CAB.CODEMP = IEMP.CODEMP
                                                  AND (SELECT (CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))) IS NOT NULL  
                                                                      THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))
                                                                      ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))) IS NOT NULL
                                                                          THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))
                                                                          ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))) IS NOT NULL
                                                                                      THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))
                                                                                      ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))) IS NOT NULL
                                                                                              THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))
                                                                                              ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))) IS NOT NULL
                                                                                                          THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))))
                                                                                                          ELSE TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = ADA.ID AND    G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU5.CODGRUPAI FROM TGFGRU GRU5 WHERE GRU5.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))))
                                                                                                  END
                                                                                              
                                                                                          END 
                                                                                      
                                                                              END 
                                                                          
                                                                          END 
                                                  END) FROM TGFGRU GG WHERE GG.CODGRUPOPROD = PRO.CODGRUPOPROD) = ADA.CODGRUPOPROD
                                                  AND ADA.CODGRUPOPROD = IEMPDIAS.GRUPO
                                                  AND TRUNC(CAB.DTFATUR) = IEMPDIAS.FATUR
                                                  AND ADA.ID = FIELD_ID
                                                GROUP BY CAB.CODEMP, PRO.CODGRUPOPROD, TO_CHAR(TRUNC(CAB.DTFATUR), 'd'), TRUNC(CAB.DTFATUR), CAB.CODVEND
                                                ORDER BY 1)
                                           WHERE GRUPO = IGRUFI.GRUPO)
                        LOOP
                            SELECT COUNT(*)
                            INTO CONTDIAS
                            FROM AD_METEMPGRUSUBGRUVEN AD
                            WHERE AD.ID = FIELD_ID
                              AND AD.IDMETEMP = IEMP.IDMETEMP
                              AND AD.IDGRUMETDIA = IGRUFI.IDGRUMETDIA
                              AND AD.IDEMPGRUFI = IDEMPGRUFIPK;
                            
                            IF CONTDIAS = 0 THEN
                                INSERT INTO AD_METEMPGRUSUBGRUVEN (ID, IDMETEMP, IDGRUMETDIA, IDEMPGRUFI, IDVENDGRUFI, CODGRUPOPROD, VLR, CODEMP, DATA, CODVEND, PESO) VALUES
                                (FIELD_ID, IEMP.IDMETEMP, IGRUFI.IDGRUMETDIA, IDEMPGRUFIPK,1, IGRUFIVEND.GRUPO, IGRUFIVEND.TOTAL, IEMP.CODEMP, IGRUFIVEND.FATUR, IGRUFIVEND.CODVEND, (IGRUFIVEND.TOTAL/IGRUFIVEND.TOTALZAO)*100); 
                            ELSE
                            
                                SELECT MAX(IDVENDGRUFI) + 1
                                INTO CONTDIAS
                                FROM AD_METEMPGRUSUBGRUVEN AD
                                WHERE AD.ID = FIELD_ID
                                  AND AD.IDMETEMP = IEMP.IDMETEMP
                                  AND AD.IDGRUMETDIA = IGRUFI.IDGRUMETDIA
                                  AND AD.IDEMPGRUFI = IDEMPGRUFIPK;
 
                                INSERT INTO AD_METEMPGRUSUBGRUVEN (ID, IDMETEMP, IDGRUMETDIA, IDEMPGRUFI, IDVENDGRUFI, CODGRUPOPROD, VLR, CODEMP, DATA, CODVEND, PESO) VALUES
                                (FIELD_ID, IEMP.IDMETEMP, IGRUFI.IDGRUMETDIA, IDEMPGRUFIPK ,CONTDIAS , IGRUFIVEND.GRUPO, IGRUFIVEND.TOTAL, IEMP.CODEMP, IGRUFIVEND.FATUR, IGRUFIVEND.CODVEND, (IGRUFIVEND.TOTAL/IGRUFIVEND.TOTALZAO)*100);
                            END IF;
                        END LOOP; --INSERE OS VENDEDORES COM GRUPOS FILHOS                       
                    END LOOP; --INSERE OS GRUPOS FILHOS DOS GRUPOS PAI DA EMPRESA
                END LOOP; --INSERE OS GRUPOS PAI POR DIAS DAS EMPRESAS
            END LOOP; --INICIA DISTRIGUIÇÃO POR DIA NAS EMPRESAS
        END LOOP; --ATUALIZA OS CAMPOS DA EMPRESA CALCULANDO % E ETC.
    END IF;
END LOOP; --LOOP DAS LINHAS SELECIONADAS

    CONT := 99;
    FOR IEMP2 IN (SELECT NVL(A.VLRMESANT,0) AS VLRMESANT
                , A.CODEMP
            FROM AD_GRUMETEMP A 
            WHERE A.ID = FIELD_ID
            ORDER BY CODEMP)
    LOOP
            --VERIFICA SE EXISTE EMPRESA ZERADA
            IF IEMP2.VLRMESANT = 0 THEN
                IF CONT = 99 THEN
                    PMSG := PMSG || '<br>Empresa(s) ' || TO_CHAR(IEMP2.CODEMP);
                    CONT := 0;
                ELSE
                    PMSG := PMSG || ', ' || TO_CHAR(IEMP2.CODEMP);
                END IF;
            END IF;
    END LOOP;
        IF CONT = 0 THEN
            PMSG := PMSG || ' não tem valor de venda no período, inserir valor no botão <i>Outras Opções</i> <b>></b><i>Gerar dados para nova Empresa</i>!';
        END IF;

PMSG := PMSG || ' Script finalizado!';
EXECUTE IMMEDIATE 'ALTER TRIGGER AD_GRUPROSPRODMETVEN_TOTAL ENABLE';
EXECUTE IMMEDIATE 'ALTER TRIGGER AD_GRUPOSPRODUSU_TOTAL ENABLE';
P_MENSAGEM := PMSG;

END;
/
