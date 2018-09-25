CREATE OR REPLACE PROCEDURE TOTALPRD."CP_GRU_VEND_TOTAL" (
       P_CODUSU NUMBER,        -- Código do usuário logado
       P_IDSESSAO VARCHAR2,    -- Identificador da execução. Serve para buscar informações dos parâmetros/campos da execução.
       P_QTDLINHAS NUMBER,     -- Informa a quantidade de registros selecionados no momento da execução.
       P_MENSAGEM OUT VARCHAR2 -- Caso seja passada uma mensagem aqui, ela será exibida como uma informação ao usuário.
) AS
       FIELD_ID NUMBER;
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
       
       PVLRANOANT INT; PANODTINI INT; PANODTFIN INT;
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
        PDTINI := ACT_DTA_PARAM(P_IDSESSAO,'PDTINI');   --Inserir/Recalcular grupos de Meta
        PDTFIN := ACT_DTA_PARAM(P_IDSESSAO,'PDTFIN');   --Inserir/Recalcular grupos de Meta
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

           SELECT COUNT(*)
           INTO CONT
           FROM AD_GRUPOSPRODUSU
           WHERE ID = (SELECT MAX(A.ID) 
                       FROM AD_GRUPOSPRODUSU A 
                       WHERE A.ID IN (SELECT MAX(AD.ID) 
                                      FROM AD_GRUPOSPRODUSU AD INNER JOIN AD_GRUPROSPROD AA ON (AA.ID = AD.ID)
                                      WHERE TO_CHAR(AA.DTVIGOR, 'MM') = TO_CHAR(ADD_MONTHS(TRUNC(SYSDATE),-1), 'MM') 
                                      GROUP BY AD.ID))
           ORDER BY IDGRU;
           
           IF CONT = 0 THEN
               PMSG := 'Meta anterior (Cód.: ' || to_char(FIELD_ID -1) || ') não tem nenhum grupo, utilize o código que não contém grupos ou exclua-o! <br>';
               EXIT;
           ELSE
               DELETE FROM AD_GRUDIAS WHERE ID = FIELD_ID;
           
               DELETE FROM AD_GRUMETDIAS WHERE ID = FIELD_ID;
               
               DELETE FROM AD_GRUPOSPRODUSUDIA WHERE ID = FIELD_ID;
               --DELETA TODOS OS REGISTRO IGUAIS AOS REGISTROS DA LINHA ANTERIOR, CASO HAJA REGISTROS INSERIDOS MANUALMENTE, QUA NÃO EXISTE NA LINHA ANTERIOR, NÃO SERÃO AFETADOS.
               DELETE FROM AD_GRUPOSPRODUSU A WHERE A.ID = FIELD_ID AND A.CODGRUPOPROD IN (SELECT CODGRUPOPROD
               FROM AD_GRUPOSPRODUSU
               WHERE ID = FIELD_ID); 
--                            (SELECT MAX(A.ID) 
--                           FROM AD_GRUPOSPRODUSU A 
--                           WHERE A.ID IN (SELECT MAX(AD.ID) 
--                                          FROM AD_GRUPOSPRODUSU AD INNER JOIN AD_GRUPROSPROD AA ON (AA.ID = AD.ID)
--                                          WHERE TO_CHAR(AA.DTVIGOR, 'MM') = TO_CHAR(ADD_MONTHS(TRUNC(SYSDATE),-1), 'MM') 
--                                          GROUP BY AD.ID)));


                FOR IGRU IN (SELECT GRUPO, TOTALZAO, TOTAL, 10 AS PERC
                            FROM (
                                  SELECT ADA.CODGRUPOPROD AS GRUPO,
                                  ---TOTALZAO
                                        (SELECT SUM(TT) 
                                         FROM (
                                               SELECT AD.CODGRUPOPROD,
                                               SUM( ((ITE.VLRTOT - ITE.VLRDESC - ITE.VLRREPRED + ITE.VLRSUBST + ITE.VLRIPI)  * VCA.INDITENSBRUTO) * CASE WHEN TOP.BONIFICACAO = 'S' THEN 0 ELSE 1 END * TOP.GOLDEV ) AS TT
                                               --NOVO
                                                FROM TGFCAB CAB INNER JOIN TGFITE ITE ON (CAB.NUNOTA = ITE.NUNOTA)
                                                                INNER JOIN TGFPRO PRO ON (ITE.CODPROD = PRO.CODPROD)
                                                                INNER JOIN VGFCAB VCA ON (CAB.NUNOTA = VCA.NUNOTA)
                                                                INNER JOIN TGFTOP TOP ON (CAB.CODTIPOPER = TOP.CODTIPOPER AND CAB.DHTIPOPER = TOP.DHALTER AND TOP.GOLSINAL = -1)
                                                                , AD_GRUPOSPRODUSU AD
                                                WHERE CAB.CODTIPOPER = 3200
                                                  AND CAB.STATUSNFE= 'A'
                                                  -----LOCALIZA GRUPO INDEPENDENTE DO NIVEL
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
                              END) FROM TGFGRU GG WHERE GG.CODGRUPOPROD = PRO.CODGRUPOPROD) = AD.CODGRUPOPROD
                                                  -----
                                                  AND TRUNC(CAB.DTFATUR) BETWEEN ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (TO_DATE(SYSDATE, 'DD/MM/YYYY'),'MONTH'),'DD/MM/YY'),-11),'MONTH'),'DD/MM/YY'),-1)
                                                                         AND ADD_MONTHS (TO_DATE (LAST_DAY (TO_DATE(SYSDATE, 'DD/MM/YYYY')),'DD/MM/YY'),-12)
                                                  AND AD.ID = OPCAOC
--                                                  (SELECT MAX(A.ID) 
--                                                                FROM AD_GRUPOSPRODUSU A 
--                                                                WHERE A.ID IN (SELECT MAX(AD.ID) 
--                                                                                FROM AD_GRUPOSPRODUSU AD INNER JOIN AD_GRUPROSPROD AA ON (AA.ID = AD.ID)
--                                                                                WHERE TO_CHAR(AA.DTVIGOR, 'MM') = TO_CHAR(ADD_MONTHS(TRUNC(SYSDATE),-1), 'MM') --<MUDAR O MÊS 0 = ATUAL
--                                                                                GROUP BY AD.ID))
                                               --NOVO
                                               GROUP BY AD.CODGRUPOPROD)) AS TOTALZAO,
                                   ---TOTALZAO
                                  SUM( ((ITE.VLRTOT - ITE.VLRDESC - ITE.VLRREPRED + ITE.VLRSUBST + ITE.VLRIPI)  * VCA.INDITENSBRUTO) * CASE WHEN TOP.BONIFICACAO = 'S' THEN 0 ELSE 1 END * TOP.GOLDEV ) AS TOTAL
                            FROM TGFCAB CAB INNER JOIN TGFITE ITE ON (CAB.NUNOTA = ITE.NUNOTA)
                                            INNER JOIN TGFPRO PRO ON (ITE.CODPROD = PRO.CODPROD)
                                            INNER JOIN VGFCAB VCA ON (CAB.NUNOTA = VCA.NUNOTA)
                                            INNER JOIN TGFTOP TOP ON (CAB.CODTIPOPER = TOP.CODTIPOPER AND CAB.DHTIPOPER = TOP.DHALTER AND TOP.GOLSINAL = -1)
                                            , AD_GRUPOSPRODUSU ADA
                            WHERE CAB.CODTIPOPER = 3200
                              AND CAB.STATUSNFE= 'A'
                              -----LOCALIZA GRUPO INDEPENDENTE DO NIVEL
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
                              END) FROM TGFGRU GG WHERE GG.CODGRUPOPROD = PRO.CODGRUPOPROD) = ADA.CODGRUPOPROD
                              -----
                              AND TRUNC(CAB.DTFATUR) BETWEEN ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (TO_DATE(SYSDATE, 'DD/MM/YYYY'),'MONTH'),'DD/MM/YY'),-11),'MONTH'),'DD/MM/YY'),-1)
                                                     AND ADD_MONTHS (TO_DATE (LAST_DAY (TO_DATE(SYSDATE, 'DD/MM/YYYY')),'DD/MM/YY'),-12)
                              AND ADA.ID = OPCAOC 
                              --(SELECT MAX(A.ID) FROM AD_GRUPOSPRODUSU A WHERE A.ID IN (SELECT MAX(AD.ID) FROM AD_GRUPOSPRODUSU AD INNER JOIN AD_GRUPROSPROD AA ON (AA.ID = AD.ID) WHERE TO_CHAR(AA.DTVIGOR, 'MM') = TO_CHAR(ADD_MONTHS(TRUNC(SYSDATE),-1), 'MM') GROUP BY AD.ID))
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
    

                    FOR IGRU2 IN (SELECT GRUPO, DATA, FATUR,  TOTAL, ((TOTAL / IGRU.TOTAL) * 100) AS PER FROM ( 
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
                            WHERE CAB.CODTIPOPER = 3200
                              AND CAB.STATUSNFE= 'A'
                              -----LOCALIZA GRUPO INDEPENDENTE DO NIVEL
                              AND (SELECT (CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = 22 AND  G2.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))) IS NOT NULL  
                                                THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = 22 AND  G2.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))
                                                ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = 22 AND  G2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))) IS NOT NULL
                                                    THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = 22 AND  G2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))
                                                    ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = 22 AND  G2.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))) IS NOT NULL
                                                                THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = 22 AND  G2.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))
                                                                ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = 22 AND  G2.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))) IS NOT NULL
                                                                        THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = 22 AND  G2.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))
                                                                        ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = 22 AND  G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))) IS NOT NULL
                                                                                    THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = 22 AND  G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))))
                                                                                    ELSE TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = 22 AND  G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU5.CODGRUPAI FROM TGFGRU GRU5 WHERE GRU5.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))))
                                                                            END
                                                                        
                                                                    END 
                                                                
                                                        END 
                                                    
                                                    END 
                              END) FROM TGFGRU GG WHERE GG.CODGRUPOPROD = PRO.CODGRUPOPROD) = ADA.CODGRUPOPROD
                              -----
                              AND TRUNC(CAB.DTFATUR) BETWEEN ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (TO_DATE(SYSDATE, 'DD/MM/YYYY'),'MONTH'),'DD/MM/YY'),-11),'MONTH'),'DD/MM/YY'),-1)
                                                     AND ADD_MONTHS (TO_DATE (LAST_DAY (TO_DATE(SYSDATE, 'DD/MM/YYYY')),'DD/MM/YY'),-12)
                              --AND (to_char(ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (TO_DATE(SYSDATE, 'DD/MM/YYYY'),'MONTH'),'DD/MM/YY'),-11),'MONTH'),'DD/MM/YY'),-1), 'd')) NOT IN (1,7)
                              AND ADA.ID = FIELD_ID 
                              AND ADA.CODGRUPOPROD = IGRU.GRUPO--APAGAR
                              --(SELECT MAX(A.ID) FROM AD_GRUPOSPRODUSU A WHERE A.ID IN (SELECT MAX(AD.ID) FROM AD_GRUPOSPRODUSU AD INNER JOIN AD_GRUPROSPROD AA ON (AA.ID = AD.ID) WHERE TO_CHAR(AA.DTVIGOR, 'MM') = TO_CHAR(ADD_MONTHS(TRUNC(SYSDATE),-1), 'MM') GROUP BY AD.ID))
                            GROUP BY ADA.CODGRUPOPROD, TO_CHAR(TRUNC(CAB.DTFATUR), 'd'), TRUNC(CAB.DTFATUR)
                            --)
                            ORDER BY 3))
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
                        
                        --Verifica se existe registro de data
                        SELECT COUNT(IDGRUMETDIAS)
                        INTO CONT2
                        FROM AD_GRUMETDIAS
                        WHERE id = FIELD_ID and IDGRUMETDIAS = IGRU2.FATUR; --'02/09/2018'
--SELECT * FRO
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
--                                SELECT COUNT(*)
--                                INTO PDATA_PK
--                                FROM AD_GRUDIAS DIAS
--                                WHERE DIAS.ID = 23 --FIELD_ID
--                                  AND DIAS.IDGRUMETDIAS = '01/09/2017'IGRU2.FATUR;
--                                  
--                                IF PDATA_PK = 0 THEN
--                                    PDATA_PK := 1;
--                                    INSERT INTO AD_GRUDIAS (ID, IDGRUMETDIAS, IDGRUDIAS2, CODGRUPOPROD, DIAANOANTINV, PESO, PERCRES, METADIA) VALUES
--                                    (FIELD_ID, IGRU2.FATUR, PDATA_PK, IGRU2.GRUPO,IGRU2.TOTAL, IGRU2.PER, 10, ((IGRU2.TOTAL/100)* 10)+IGRU2.TOTAL);
--                                ELSE
                                    SELECT MAX(IDGRUDIAS2) + 1
                                    INTO PDATA_PK
                                    FROM AD_GRUDIAS DIAS
                                    WHERE DIAS.ID = FIELD_ID
                                      AND DIAS.IDGRUMETDIAS = IGRU2.FATUR;
                                      
                                    INSERT INTO AD_GRUDIAS (ID, IDGRUMETDIAS, IDGRUDIAS2, CODGRUPOPROD, DIAANOANTINV, PESO, PERCRES, METADIA) VALUES
                                    (FIELD_ID, IGRU2.FATUR, PDATA_PK, IGRU2.GRUPO,IGRU2.TOTAL, IGRU2.PER, 10, ((IGRU2.TOTAL/100)* 10)+IGRU2.TOTAL);
--                                END IF;
                            END IF; 
--                        END IF;
                    END LOOP;        

                END LOOP;
                    FOR IRESTO IN (SELECT A.CODGRUPOPROD AS GRUPO
                            FROM AD_GRUPOSPRODUSU A 
                            WHERE A.ID = OPCAOC
                              AND A.CODGRUPOPROD NOT IN (SELECT B.CODGRUPOPROD
                                                         FROM AD_GRUPOSPRODUSU B
                                                         WHERE B.ID = FIELD_ID))
                    LOOP
                        SELECT COUNT(*)
                        INTO CONT
                        FROM AD_GRUPOSPRODUSU AD
                        WHERE AD.ID = FIELD_ID;
                        
                        IF CONT = 0 THEN
                            INSERT INTO AD_GRUPOSPRODUSU (ID, IDGRU, CODGRUPOPROD, META, DATA, CODUSU, SUGESTAO, PERC) VALUES
                            (FIELD_ID, 1,IRESTO.GRUPO, 0,SYSDATE, PCODUSU, 0, 0);
                        ELSE
                            INSERT INTO AD_GRUPOSPRODUSU (ID, IDGRU, CODGRUPOPROD, META, DATA, CODUSU, SUGESTAO, PERC) VALUES
                            (FIELD_ID, (SELECT MAX(IDGRU) + 1 FROM AD_GRUPOSPRODUSU),IRESTO.GRUPO, 0,SYSDATE, PCODUSU, 0, 0);
                    END IF;
                    END LOOP;
                    PMSG := PMSG || 'Dados dos grupos copiados com sucesso! <br>';
           END IF;
    --FINALIZA OPÇÃO DE COPIAR       
    ELSIF NVL(OPCAOR, 'N') = 'S' THEN
        SELECT COUNT(*)
        INTO CONT
            FROM AD_GRUPOSPRODUSU
            WHERE ID = FIELD_ID
        ORDER BY IDGRU;
        IF CONT = 0 THEN
            PMSG := PMSG || 'Não existe grupo registro para recalcular. (Cód.: ' || to_char(FIELD_ID) || ')<br>';
            EXIT; 
        ELSE
            DELETE FROM AD_GRUPOSPRODUSUDIA WHERE ID = FIELD_ID;
        
            FOR IUPDATE IN (SELECT GRUPO, TOTALZAO, TOTAL , PERC , ((TOTAL*PERC)/100)+TOTAL AS SUGESTAO

                                FROM (
                                      SELECT ADA.CODGRUPOPROD AS GRUPO,
                                             ADA.PERC,
                                      ---TOTALZAO
                                            (SELECT SUM(TT) 
                                             FROM (
                                                   SELECT AD.CODGRUPOPROD,
                                                   SUM( ((ITE.VLRTOT - ITE.VLRDESC - ITE.VLRREPRED + ITE.VLRSUBST + ITE.VLRIPI)  * VCA.INDITENSBRUTO) * CASE WHEN TOP.BONIFICACAO = 'S' THEN 0 ELSE 1 END * TOP.GOLDEV ) AS TT
                                                   --NOVO
                                                    FROM TGFCAB CAB INNER JOIN TGFITE ITE ON (CAB.NUNOTA = ITE.NUNOTA)
                                                                    INNER JOIN TGFPRO PRO ON (ITE.CODPROD = PRO.CODPROD)
                                                                    INNER JOIN VGFCAB VCA ON (CAB.NUNOTA = VCA.NUNOTA)
                                                                    INNER JOIN TGFTOP TOP ON (CAB.CODTIPOPER = TOP.CODTIPOPER AND CAB.DHTIPOPER = TOP.DHALTER AND TOP.GOLSINAL = -1)
                                                                    , AD_GRUPOSPRODUSU AD
                                                    WHERE CAB.CODTIPOPER = 3200
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
                                                      END) FROM TGFGRU GG WHERE GG.CODGRUPOPROD = PRO.CODGRUPOPROD) = AD.CODGRUPOPROD
                                                      -----
                                                      AND TRUNC(CAB.DTFATUR) BETWEEN ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (TO_DATE(SYSDATE, 'DD/MM/YYYY'),'MONTH'),'DD/MM/YY'),-11),'MONTH'),'DD/MM/YY'),-1)
                                                                             AND ADD_MONTHS (TO_DATE (LAST_DAY (TO_DATE(SYSDATE, 'DD/MM/YYYY')),'DD/MM/YY'),-12)
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
                                WHERE CAB.CODTIPOPER = 3200
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
                                  AND TRUNC(CAB.DTFATUR) BETWEEN ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (TO_DATE(SYSDATE, 'DD/MM/YYYY'),'MONTH'),'DD/MM/YY'),-11),'MONTH'),'DD/MM/YY'),-1)
                                                         AND ADD_MONTHS (TO_DATE (LAST_DAY (TO_DATE(SYSDATE, 'DD/MM/YYYY')),'DD/MM/YY'),-12)
                                  AND ADA.ID = FIELD_ID
                                GROUP BY ADA.CODGRUPOPROD, ADA.PERC)
                                ORDER BY PERC)
            LOOP
                UPDATE AD_GRUPOSPRODUSU SET CODUSU = PCODUSU, PERC = NVL(IUPDATE.PERC,10), META = IUPDATE.TOTAL, SUGESTAO = NVL(IUPDATE.SUGESTAO, ((IUPDATE.TOTAL*10)/100+IUPDATE.TOTAL)) WHERE ID = FIELD_ID AND CODGRUPOPROD = IUPDATE.GRUPO;
                
                SELECT IDGRU 
                INTO PK_GRUPO
                FROM AD_GRUPOSPRODUSU
                WHERE ID = FIELD_ID AND CODGRUPOPROD = IUPDATE.GRUPO;
                
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
                            WHERE CAB.CODTIPOPER = 3200
                              AND CAB.STATUSNFE= 'A'
                              -----LOCALIZA GRUPO INDEPENDENTE DO NIVEL
                              AND (SELECT (CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = 22 AND  G2.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))) IS NOT NULL  
                                                THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = 22 AND  G2.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))
                                                ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = 22 AND  G2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))) IS NOT NULL
                                                    THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = 22 AND  G2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))
                                                    ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = 22 AND  G2.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))) IS NOT NULL
                                                                THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = 22 AND  G2.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))
                                                                ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = 22 AND  G2.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))) IS NOT NULL
                                                                        THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = 22 AND  G2.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))
                                                                        ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = 22 AND  G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))) IS NOT NULL
                                                                                    THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = 22 AND  G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))))
                                                                                    ELSE TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = 22 AND  G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU5.CODGRUPAI FROM TGFGRU GRU5 WHERE GRU5.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))))
                                                                            END
                                                                        
                                                                    END 
                                                                
                                                        END 
                                                    
                                                    END 
                              END) FROM TGFGRU GG WHERE GG.CODGRUPOPROD = PRO.CODGRUPOPROD) = ADA.CODGRUPOPROD
                              -----
                              AND TRUNC(CAB.DTFATUR) BETWEEN ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (TO_DATE(SYSDATE, 'DD/MM/YYYY'),'MONTH'),'DD/MM/YY'),-11),'MONTH'),'DD/MM/YY'),-1)
                                                     AND ADD_MONTHS (TO_DATE (LAST_DAY (TO_DATE(SYSDATE, 'DD/MM/YYYY')),'DD/MM/YY'),-12)
                              --AND (to_char(ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (TO_DATE(SYSDATE, 'DD/MM/YYYY'),'MONTH'),'DD/MM/YY'),-11),'MONTH'),'DD/MM/YY'),-1), 'd')) NOT IN (1,7)
                              AND ADA.ID = FIELD_ID 
                              AND ADA.CODGRUPOPROD = IUPDATE.GRUPO--APAGAR
                              --(SELECT MAX(A.ID) FROM AD_GRUPOSPRODUSU A WHERE A.ID IN (SELECT MAX(AD.ID) FROM AD_GRUPOSPRODUSU AD INNER JOIN AD_GRUPROSPROD AA ON (AA.ID = AD.ID) WHERE TO_CHAR(AA.DTVIGOR, 'MM') = TO_CHAR(ADD_MONTHS(TRUNC(SYSDATE),-1), 'MM') GROUP BY AD.ID))
                            GROUP BY ADA.CODGRUPOPROD, TO_CHAR(TRUNC(CAB.DTFATUR), 'd'), TRUNC(CAB.DTFATUR)
                            --)
                            ORDER BY 3))
                    LOOP
                        SELECT COUNT(*)
                        INTO CONTDIAS
                        FROM AD_GRUPOSPRODUSUDIA AD
                        WHERE AD.ID = FIELD_ID
                          AND AD.IDGRU = PK_GRUPO;

                        IF CONTDIAS = 0 THEN
                            INSERT INTO AD_GRUPOSPRODUSUDIA (ID, IDGRU,IDMETDIA, CODGRUPOPROD, DIAANOANT, PERCRES,PESO, METADIA, DATA) VALUES
                            (FIELD_ID, PK_GRUPO,1, IGRU2.GRUPO, IGRU2.TOTAL, IGRU2.PER,10, ((IGRU2.TOTAL/100)* 10)+IGRU2.TOTAL, IGRU2.FATUR);
                        ELSE
                            INSERT INTO AD_GRUPOSPRODUSUDIA (ID, IDGRU,IDMETDIA, CODGRUPOPROD, DIAANOANT, PERCRES,PESO, METADIA,DATA) VALUES
                            (FIELD_ID, PK_GRUPO, (SELECT MAX(IDMETDIA) + 1 FROM AD_GRUPOSPRODUSUDIA AD WHERE AD.ID = FIELD_ID AND AD.IDGRU = PK_GRUPO), IGRU2.GRUPO, IGRU2.TOTAL, IGRU2.PER,10, ((IGRU2.TOTAL/100)* 10)+IGRU2.TOTAL, IGRU2.FATUR);
                        END IF;
                    END LOOP;    
            END LOOP;
            PMSG := PMSG ||'Dados dos vendedores atualizados com sucesso! <br>';
        END IF;
    END IF;---------------------------------------------------------------------FINALIZA OPÇÃO DE COPIAR/RECALCULAR
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
                                    WHERE CAB.CODTIPOPER = 3200
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
                                    WHERE CAB.CODTIPOPER = 3200
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
--RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
--Vendedor(a) CÓD: '||TO_CHAR(PARAM_CODGER)||'.</font></b><br><font>');
        IF PARAM_CODGER IS NOT NULL THEN   --------------------------------insere novos vendedores por gerente
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
                                            WHERE CAB.CODTIPOPER = 3200
                                              AND CAB.STATUSNFE = 'A'
                                              AND VE.ATIVO = 'S'
                                              --ELIMINA VENDEDOR COM 0 DE VENDA
                                          AND (NVL((SELECT SUM( ((ITE.VLRTOT - ITE.VLRDESC - ITE.VLRREPRED + ITE.VLRSUBST + ITE.VLRIPI) * VCA.INDITENSBRUTO) * CASE WHEN TOP.BONIFICACAO = 'S' THEN 0 ELSE 1 END * TOP.GOLDEV )
                                        FROM TGFCAB CAB INNER JOIN TGFITE ITE ON (CAB.NUNOTA = ITE.NUNOTA)
                                                        INNER JOIN VGFCAB VCA ON (CAB.NUNOTA = VCA.NUNOTA)
                                                        INNER JOIN TGFVEN VE  ON (CAB.CODVEND = VE.CODVEND)
                                                        INNER JOIN TGFTOP TOP ON (CAB.CODTIPOPER = TOP.CODTIPOPER AND CAB.DHTIPOPER = TOP.DHALTER AND TOP.GOLSINAL = -1)
                                        WHERE CAB.CODTIPOPER = 3200
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
                                        WHERE CAB.CODTIPOPER = 3200                                       
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
        --                                   RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
        --                   Vendedor(a) CÓD: '||TO_CHAR(FIELD_ID)||' '||TO_CHAR(IVEND.CODVEND)||' '||TO_CHAR(IVEND.PERC)||' '||TO_CHAR(IVEND.VALOR)||' '||TO_CHAR(CONT)||'.</font></b><br><font>');
            END LOOP;
        END IF;
        IF PARAM_CODGRU IS NOT NULL THEN   --------------------------------insere novos vendedores por grupo
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
                                        WHERE CAB.CODTIPOPER = 3200
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
                                        WHERE CAB.CODTIPOPER = 3200
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
                                        WHERE CAB.CODTIPOPER = 3200
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
        --                                   RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
        --                   Vendedor(a) CÓD: '||TO_CHAR(FIELD_ID)||' '||TO_CHAR(IVEND.CODVEND)||' '||TO_CHAR(IVEND.PERC)||' '||TO_CHAR(IVEND.VALOR)||' '||TO_CHAR(CONT)||'.</font></b><br><font>');
            END LOOP;
        END IF;--fim do insere novos vendedores por grupo
    END IF; -- RECALCULA VENDEDORES
    IF NVL(RECMET, 'N') = 'S' THEN
    
        SELECT COUNT(*)
        INTO CONT
        FROM AD_GRUPROSPRODMETVEN A
        WHERE A.ID = FIELD_ID;
        
        DELETE
        FROM AD_SUBGRUPOVENDMETDIAS A
        WHERE A.ID = FIELD_ID;
        
        DELETE
        FROM AD_SUBGRUPOVENDMET AD
        WHERE AD.ID = FIELD_ID;
          
        IF CONT = 0 THEN --VERIFICA SE EXISTE VENDEDORES
            PMSG := PMSG || 'Sem vendedor cadastrado na tela.<br>';
        ELSE
            FOR IVEN IN (SELECT VEN.IDMETVEND, VEN.CODVEND, VEN.PERCVEND AS PERC 
                          FROM AD_GRUPROSPROD A LEFT JOIN AD_GRUPROSPRODMETVEN VEN ON (A.ID=VEN.ID)--VENDEDORES
                          WHERE A.ID = FIELD_ID
                          ORDER BY 2)
            LOOP
                --Busca pelos grupos
                FOR IGRU IN (SELECT GRU.CODGRUPOPROD AS GRUPO, GRU.SUGESTAO AS SUGESTAO
                              FROM AD_GRUPROSPROD A LEFT JOIN AD_GRUPOSPRODUSU GRU ON (A.ID=GRU.ID)--GRUPOS
                              WHERE A.ID = FIELD_ID
                              ORDER BY 2)
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
    --PROCEDIMENTOS COM EMPRESAS
    IF ATUEMP = 'S' THEN
        --VALORES POR ANO
        FOR IVLREMP IN (SELECT CAB.CODEMP,
               SUM( ((ITE.VLRTOT - ITE.VLRDESC - ITE.VLRREPRED + ITE.VLRSUBST + ITE.VLRIPI)  * VCA.INDITENSBRUTO) * CASE WHEN TOP.BONIFICACAO = 'S' THEN 0 ELSE 1 END * TOP.GOLDEV ) AS TT
               --NOVO
                FROM TGFCAB CAB INNER JOIN TGFITE ITE ON (CAB.NUNOTA = ITE.NUNOTA)
                                INNER JOIN TGFPRO PRO ON (ITE.CODPROD = PRO.CODPROD)
                                INNER JOIN VGFCAB VCA ON (CAB.NUNOTA = VCA.NUNOTA)
                                INNER JOIN TGFTOP TOP ON (CAB.CODTIPOPER = TOP.CODTIPOPER AND CAB.DHTIPOPER = TOP.DHALTER AND TOP.GOLSINAL = -1)
                                , AD_GRUPOSPRODUSU AD
                WHERE CAB.CODTIPOPER = 3200
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
            UPDATE AD_GRUMETEMP SET META = IVLREMP.TT WHERE ID = FIELD_ID AND CODEMP = IVLREMP.CODEMP;
        END LOOP; 
 

    --INICIO DAS ATUALIZAÇÕES DE PERCENTUAL
         FOR IEMP IN (SELECT ID
                       , IDMETEMP
                       , NVL((NVL(A.VLRMESANT,1) / (SELECT SUM(B.VLRMESANT) FROM AD_GRUMETEMP B WHERE B.ID = A.ID)) * 100,0) AS PERANO
                       , NVL((NVL(A.VLRANOANT,1) / (SELECT SUM(B.VLRANOANT) FROM AD_GRUMETEMP B WHERE B.ID = A.ID)) * 100,0) AS PERMES
                       , NVL(((NVL(VLRMESANT,1) / 100) * NVL(PER,10)) + VLRMESANT,0) AS PER
                  FROM AD_GRUMETEMP A 
                  WHERE A.ID = FIELD_ID)
        LOOP
        
            UPDATE AD_GRUMETEMP SET PESO = IEMP.PERANO, META = IEMP.PER, PER = (CASE WHEN IEMP.PER IS NULL THEN 10 ELSE IEMP.PER END) WHERE ID = FIELD_ID AND IDMETEMP = IEMP.IDMETEMP; --COMMIT;
            
--            RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#000000">
--Grupo FILHO já existe! <br> ' || to_char(I.PERANO) ||' / ' || to_char(I.ID) ||' / ' || to_char(I.IDMETEMP) ||'.</font></b><br><font>');

        END LOOP;
    END IF;
    
END LOOP; --LOOP DAS LINHAS SELECIONADAS
PMSG := PMSG || 'Script finalizado!';
EXECUTE IMMEDIATE 'ALTER TRIGGER AD_GRUPROSPRODMETVEN_TOTAL ENABLE';
EXECUTE IMMEDIATE 'ALTER TRIGGER AD_GRUPOSPRODUSU_TOTAL ENABLE';
P_MENSAGEM := PMSG;

END;
/
