CREATE OR REPLACE PROCEDURE TOTALPRD."ACERTA_ALIQ_INTEL_M_TOTAL" (
       P_CODUSU NUMBER,        -- Código do usuário logado
       P_IDSESSAO VARCHAR2,    -- Identificador da execução. Serve para buscar informações dos parâmetros/campos da execução.
       P_QTDLINHAS NUMBER,     -- Informa a quantidade de registros selecionados no momento da execução.
       P_MENSAGEM OUT VARCHAR2 -- Caso seja passada uma mensagem aqui, ela será exibida como uma informação ao usuário.
) AS

    FIELD_NUNOTA NUMBER;    --numero único
    PDTFATUR DATE;          --não utilizado
    PCODTIPOPER INT;        --tipo de operação
    PCDOTIPOPERMANAL INT := 3000; --tipo de top
    PCODPARC INT;           --parceiro

    TESTE INT;              --teste

    PBST FLOAT;             --base da substituição
    PVLRST FLOAT;           --valor da substituição

    PTBST FLOAT := 0;       --total da base de substituição da nota
    PTVLRST FLOAT  := 0;    --total da base de substituição da nota
    PALIQSUBTRIB FLOAT;

    PDTINI DATE;            --data inicio para basear a tabela de aliquotas
    PDTFIM DATE;            --data fim para basear a tabela de aliquotas

    PCODORIGEM INT;         --estado origem para basear a tabela de aliquotas
    PCODDESTINO INT;        --estado origem para basear a tabela de aliquotas

    PTEXT VARCHAR(300);     --mensagem final.

    CONT INT;               --contador para verificar se tem algum produto na tabela daquela data
    PCONTALIQSUBTRIB INT;    --contador para verificar se existe imposto estadual na tabela de Aliquotas do ICMS.

BEGIN

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
           --numero único da nota
           FIELD_NUNOTA := ACT_INT_FIELD(P_IDSESSAO, I, 'NUNOTA');

           --obter a top, o parceiro, o uf origem e destino da nota atual.
           SELECT CAB.CODTIPOPER
                , CAB.CODPARC
                , (SELECT CID.UF FROM TSIEMP EMP INNER JOIN TSICID CID ON (EMP.CODCID=CID.CODCID) WHERE EMP.CODEMP = CAB.CODEMP) AS UFORIG
                , (SELECT CID.UF FROM TSICID CID WHERE CID.CODCID = (SELECT PARC.CODCID FROM TGFPAR PARC WHERE PARC.CODPARC = CAB.CODPARC)) AS UFDEST
           INTO PCODTIPOPER, PCODPARC, PCODORIGEM, PCODDESTINO
           FROM TGFCAB CAB
           WHERE CAB.NUNOTA = FIELD_NUNOTA;

            --se a nota for top 3005 e conter os parceiros abaixo...
            IF PCODTIPOPER = PCDOTIPOPERMANAL AND PCODPARC IN (50910, 51674, 50943) THEN

                --obtem primeiro dia do mes de referencia e o ultimo.
                SELECT ADD_MONTHS(TO_DATE(TRUNC(NVL(C.DTFATUR, C.DTNEG), 'MONTH'), 'DD/MM/YY'), 0) AS DTINI --PRIMEIRO DIA DO MES DA NOTA DE COMPRA
                     , ADD_MONTHS(TO_DATE(LAST_DAY (NVL(C.DTFATUR, C.DTNEG)), 'DD/MM/YY'),0) AS DTFIM --ULTIMO DIA DO MES DA NOTA DE COMPRA  
                     --, C.DTFATUR
                INTO PDTINI, PDTFIM
                FROM TGFCAB C 
                WHERE C.NUNOTA = case when (SELECT count(VAR.NUNOTAORIG) FROM TGFVAR VAR WHERE VAR.NUNOTA = FIELD_NUNOTA) <> 0 
                                 THEN (SELECT MAX(VAR.NUNOTAORIG) FROM TGFVAR VAR WHERE VAR.NUNOTA = FIELD_NUNOTA)
                                 ELSE FIELD_NUNOTA END;


                --obter infomação se existe registo
                SELECT COUNT(*)
                INTO CONT
                FROM TGFITE ITE inner join TGFPRO PROD ON (ITE.CODPROD=PROD.CODPROD)
                                  INNER JOIN (SELECT AD.NCM
                                                   , AD.ORIGPRODUTO
                                                   , AD.ST AS MVA
                                             FROM AD_IMPOSTOSINTELBRAS AD INNER JOIN AD_CALCULOSTINTELBRAS IMP ON (AD.ID=IMP.ID) 
                                             WHERE TO_CHAR(IMP.DATA, 'DD/MM/YY') BETWEEN PDTINI AND PDTFIM
                                               AND IMP.CODUFO = PCODORIGEM
                                               AND IMP.CODUFD = PCODDESTINO
                                             GROUP BY NCM, ORIGPRODUTO, ST) AD ON (PROD.NCM = (AD.NCM) AND PROD.ORIGPROD=AD.ORIGPRODUTO)
                  WHERE ITE.NUNOTA = FIELD_NUNOTA;
                  
                --se exister entra no codigo  
                IF CONT <> 0 THEN
                
                    --obter as linhas de produtos com os valores a calcular
                    FOR P IN (SELECT ITE.CODPROD
                                   , ITE.SEQUENCIA 
                                   , ITE.VLRTOT
                                   , ITE.VLRIPI
                                   , ITE.ALIQICMS
                                   , ITE.VLRICMS
                                   , PROD.NCM || PROD.ORIGPROD AS PROD
                                   , NVL(AD.NCM || AD.ORIGPRODUTO, 'N') AS NPROD
                                   , MAX(AD.MVA) AS MVA
                                   , NVL(AD.REDUCAO, 0) AS REDUCAO
                                   , AD.ORIGPRODUTO
                                   , DUPLICADO
                             FROM TGFITE ITE inner join TGFPRO PROD ON (ITE.CODPROD=PROD.CODPROD)
                                              INNER JOIN (SELECT AD.NCM
                                                               , AD.ORIGPRODUTO
                                                               , max(AD.ST) AS MVA
                                                               , count(*) as DUPLICADO
                                                               , MAX(AD.REDUCAO) AS REDUCAO
                                                         FROM AD_IMPOSTOSINTELBRAS AD INNER JOIN AD_CALCULOSTINTELBRAS IMP ON (AD.ID=IMP.ID) 
                                                         WHERE TO_CHAR(IMP.DATA, 'DD/MM/YY') BETWEEN PDTINI AND PDTFIM
                                                           AND IMP.CODUFO = PCODORIGEM
                                                           AND IMP.CODUFD = PCODDESTINO
                                                         GROUP BY NCM, ORIGPRODUTO) AD ON (PROD.NCM = (AD.NCM) AND PROD.ORIGPROD=AD.ORIGPRODUTO)
                              WHERE ITE.NUNOTA = FIELD_NUNOTA--160736 --
                              GROUP BY ITE.CODPROD
                                   , ITE.SEQUENCIA 
                                   , ITE.VLRTOT
                                   , ITE.VLRIPI
                                   , ITE.ALIQICMS
                                   , ITE.VLRICMS
                                   , PROD.NCM
                                   , AD.NCM
                                   , AD.ORIGPRODUTO
                                   , PROD.ORIGPROD
                                   , AD.ORIGPRODUTO
                                   , AD.REDUCAO
                                   , AD.DUPLICADO)
                    LOOP
                        
                    
                        IF P.DUPLICADO > 1 THEN
                            RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><b><font size="11" color="#FF00000">Cadastro de MVA da Intelbras duplicado para o NCM número: ' || to_char(SUBSTR(P.NPROD, 0, 8)) || ' e Origem de número: ' || to_char(P.ORIGPRODUTO) || '.<br><i>Exclua as duplicidades e deixe apenas 1!</i><br></b></font>');
                        END IF;
                        --se existir algum produto sem ncm na tabela mostra msg abaixo.
                        IF P.NPROD IS NULL THEN
                            RAISE_APPLICATION_ERROR(-20001, '<br><b><font size="11" color="#FF00000">NCM NÃO CADASTRADO NA TABELA.<br><br></b></font>');
                        END IF;
                        
                        --se o ncm com a origem for igual o da tabela de aliquotas entra no codigo.
                        IF P.PROD = P.NPROD THEN

                        SELECT COUNT(ICM.ALIQSUBTRIB)
                        INTO PCONTALIQSUBTRIB
                        FROM TGFICM ICM 
                        WHERE ICM.CODRESTRICAO = PCODTIPOPER 
                          AND ICM.UFORIG = PCODDESTINO
                          AND UFDEST = PCODORIGEM;
  
                        IF PCONTALIQSUBTRIB <> 0 THEN
                           
                            SELECT ICM.ALIQSUBTRIB
                            INTO PALIQSUBTRIB
                            FROM TGFICM ICM 
                            WHERE ICM.CODRESTRICAO = PCODTIPOPER 
                              AND ICM.UFORIG = PCODDESTINO
                              AND UFDEST = PCODORIGEM;
                        ELSE
                            RAISE_APPLICATION_ERROR(-20001, '<br><b><font size="11" color="#FF00000">Fantando configuração na tela Aliquotas de ICMS para obter a tributação estadual.<br><br></b></font>');
                        END IF;
                        
                            --calcula a base de substiguição
                            PBST := ROUND(((P.VLRTOT+P.VLRIPI)*(1+((P.MVA/100))))+(((P.VLRTOT+P.VLRIPI)*(1+((P.MVA/100))))*(-P.REDUCAO/100)),2);
                            --calcula o valor da substituição
                            PVLRST := ROUND(((PBST*(PALIQSUBTRIB/100))-P.VLRICMS),2);
                            
                            --update nos itens.
                            UPDATE TGFITE ITE SET ITE.BASESUBSTIT = PBST, ITE.VLRSUBST = PVLRST WHERE ITE.NUNOTA = FIELD_NUNOTA AND ITE.SEQUENCIA = P.SEQUENCIA;

                            --calcula base de st da nota
                            PTBST := PTBST + PBST;
                            --calcula vlr de st da nota
                            PTVLRST := PTVLRST + PVLRST;
                        ELSE
                            --caso exista algum produto sem referencia de ncm exibe msg.
                            RAISE_APPLICATION_ERROR(-20001, '<br><b><font size="11" color="#FF00000">NCM NÃO CADASTRADO NA TABELA.<br><br></b></font>');
                        END IF;
                    END LOOP;
                ELSE
            --caso não exista linha de produtos exibe a msn.
                RAISE_APPLICATION_ERROR(-20001, '<br><b><font size="11" color="#FF00000">
NENHUM NCM DESSA NOTA ESTÁ CADASTRADO NA TABELA.<br><br></b></font>');
                END IF;
            --caso a top ou parceiro não seja igual as regras exibe a msg.
            ELSE    
                RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#fff"><br><b><font size="11" color="#000">
Atualização não corresponde aos critérios: <br> Top 3244 diferente de ' || to_char(PCODTIPOPER) || '<br>ou o Parceiro (50910 ou 51674 ou 50943) diferente de ' || to_char(PCODPARC) || '.<br><br></b></font>');
            END IF;
            --ao final do loop atualiza a nota.
            UPDATE TGFCAB CAB SET CAB.BASESUBSTIT = PTBST, CAB.VLRSUBST = PTVLRST WHERE CAB.NUNOTA = FIELD_NUNOTA;
            --guarda texto para cada nota, caso atualiza varias notas de 1 só vez.
            PTEXT := PTEXT || 'Aliquota do Nº único: ' || to_char(FIELD_NUNOTA) || ' atualizada! Base substituição: ' || to_char(PTBST) || ' e Vlr. substituição: ' || to_char(PTVLRST) || '.';
       END LOOP;
    
   --msg final.
   P_MENSAGEM := PTEXT;

END;
/
