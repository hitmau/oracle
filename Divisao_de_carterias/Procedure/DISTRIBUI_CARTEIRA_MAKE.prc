CREATE OR REPLACE PROCEDURE TOTALPRD."DISTRIBUI_CARTEIRA_MAKE" (
       P_CODUSU NUMBER,        -- Código do usuário logado
       P_IDSESSAO VARCHAR2,    -- Identificador da execução. Serve para buscar informações dos parâmetros/campos da execução.
       P_QTDLINHAS NUMBER,     -- Informa a quantidade de registros selecionados no momento da execução.
       P_MENSAGEM OUT VARCHAR2 -- Caso seja passada uma mensagem aqui, ela será exibida como uma informação ao usuário.
) AS
       PARAM_PCODREG VARCHAR2(10);
       PARAM_PTIPONOVO CHAR;
       PARAM_PTIPOINATIVO CHAR;
       PARAM_PTIPOATIVO CHAR;
       PARAM_PDIAS INT  := 90;
       PARAM_PCOTTIPPARC VARCHAR2(10);
       PARAM_PNAOCODVEND VARCHAR2(255) := '23534639';
       FIELD_CODVEND INT;
       CONT INT := 0;
       PASSA INT;
       TEXTMSG VARCHAR(4000);
       PK_RESTOR INT;
       LOGVENDE VARCHAR(4000);
BEGIN
/*
    AUTOR: Mauricio Rodrigues
    Data da criação: 16/08/2018
    Descrição: Divisão de carterias da distribuição, com base nos parceiros da curva abs + regiões + ativos/inativos/novos.
	teste
*/
--A TRIGGER ABAIXO IMPEDE DE ATUALIZAR O PARCEIRO CASO O CADASTRO ESTEJA ERRADO.
EXECUTE IMMEDIATE 'ALTER TRIGGER TOTALPRD.TRG_UPD_TGFPAR_TOTAL DISABLE';

       -- Os valores informados pelo formulário de parâmetros, podem ser obtidos com as funções:
       --     ACT_INT_PARAM
       --     ACT_DEC_PARAM
       --     ACT_TXT_PARAM
       --     ACT_DTA_PARAM
       -- Estas funções recebem 2 argumentos:
       --     ID DA SESSÃO - Identificador da execução (Obtido através de P_IDSESSAO))
       --     NOME DO PARAMETRO - Determina qual parametro deve se deseja obter.

       PARAM_PCODREG := ACT_TXT_PARAM(P_IDSESSAO, 'PCODREG');
       PARAM_PTIPONOVO := NVL(ACT_TXT_PARAM(P_IDSESSAO, 'PTIPONOVO'), 'N');
       PARAM_PTIPOINATIVO := NVL(ACT_TXT_PARAM(P_IDSESSAO, 'PTIPOINATIVO'), 'N');
       PARAM_PTIPOATIVO := NVL(ACT_TXT_PARAM(P_IDSESSAO, 'PTIPOATIVO'), 'N');
       PARAM_PDIAS := NVL(ACT_INT_PARAM(P_IDSESSAO, 'PDIAS'), 90);
       PARAM_PCOTTIPPARC := ACT_TXT_PARAM(P_IDSESSAO, 'PCOTTIPPARC');
       PARAM_PNAOCODVEND := NVL(ACT_TXT_PARAM(P_IDSESSAO, 'PNAOCODVEND'), '23534639');
    
IF (PARAM_PTIPONOVO = 'N') AND (PARAM_PTIPOINATIVO = 'N') AND (PARAM_PTIPOATIVO = 'N') THEN
    TEXTMSG := 'Nenhuma opção marcada!';
ELSE
       SELECT MAX(RESTOR) + 1 
       INTO PK_RESTOR
       FROM AD_LOGDISTCARTEIRA;
       
       FOR I IN 1..P_QTDLINHAS
       LOOP                    

           FIELD_CODVEND := ACT_INT_FIELD(P_IDSESSAO, I, 'CODVEND');
           TEXTMSG := TEXTMSG || FIELD_CODVEND || '-';
           LOGVENDE := TO_CHAR(SYSDATE) || ' - ';
--SE ATUALIZAR CLIENTE INATIVOS----------------------------------------------------------------------------------------------------
        
        IF PARAM_PTIPOINATIVO = 'S' THEN
            PASSA := I;
            
            FOR PINATIVO IN (SELECT SEQUENCIA, CODPARC, CODVEND, REG FROM (SELECT ROW_NUMBER() OVER (ORDER BY 'HHH') AS SEQUENCIA
                                  , A.CODPARC
                                  , A.CODVEND
                                  , A.AD_REGIAODISTRIBUICAO AS REG
                             FROM (SELECT DISTINCT P.CODPARC
                                          , P.CODVEND
                                          , AD.PERC
                                          , P.AD_REGIAODISTRIBUICAO
                                    FROM TGFPAR P,  AD_CURVAABCPARCEIROS AD 
                                    WHERE P.CODPARC=AD.CODPARC and (CASE WHEN (SELECT COUNT(1) 
                                                FROM TGFCAB CAB 
                                                WHERE CAB.CODPARC = P.CODPARC
                                                    AND CAB.CODTIPOPER IN (3200, 3210)
                                                    AND CAB.STATUSNOTA = 'L' 
                                                    AND CAB.STATUSNFE <> 'D' 
                                                    AND CAB.STATUSNFE <> 'C'
                                                    AND CAB.STATUSNFE <> 'V'
                                                    AND CAB.STATUSNFE IS NOT NULL
                                                    AND CAB.STATUSNFE <> 'R'
                                                    AND CAB.STATUSNFE <> 'E') <> 0 THEN (SELECT MAX(CAB.DTFATUR) 
                                                                                    FROM TGFCAB CAB 
                                                                                    WHERE CAB.CODPARC = P.CODPARC
                                                                                        AND CAB.CODTIPOPER IN (3200, 3210)
                                                                                        AND CAB.STATUSNOTA = 'L' 
                                                                                        AND CAB.STATUSNFE <> 'D' 
                                                                                        AND CAB.STATUSNFE <> 'C'
                                                                                        AND CAB.STATUSNFE <> 'V'
                                                                                        AND CAB.STATUSNFE IS NOT NULL
                                                                                        AND CAB.STATUSNFE <> 'R'
                                                                                        AND CAB.STATUSNFE <> 'E') ELSE SYSDATE + 10 END) <= SYSDATE - PARAM_PDIAS
                                            AND P.CLIENTE = 'S'
                                            AND AD.NOVENTA = 'N'
                                            AND P.CODTIPPARC = PARAM_PCOTTIPPARC--PARAM_PCOTTIPPARC --10403000--
                                            AND P.AD_REGIAODISTRIBUICAO = PARAM_PCODREG--PARAM_PCODREG --2020300--
                                            AND P.CODVEND NOT IN (SELECT REGEXP_SUBSTR(PARAM_PNAOCODVEND,'[^,]+', 1, LEVEL) AS RESULTADO FROM DUAL CONNECT BY REGEXP_SUBSTR(PARAM_PNAOCODVEND, '[^,]+', 1, LEVEL) IS NOT NULL)
                                            AND P.CODPARC NOT IN (SELECT EMP.CODEMP FROM TSIEMP EMP)
                                ORDER BY AD.PERC, P.CODPARC) A
                            ORDER BY SEQUENCIA))
            LOOP
                IF PASSA = PINATIVO.SEQUENCIA THEN
--              INSERE UM LOG DAS MUDANÇAS --SELECT MAX(RESTOR) + 1 FROM AD_LOGDISTCARTEIRA
                    INSERT INTO AD_LOGDISTCARTEIRA (ID, DTHRALTER, CODPARC, CODVENDANTIGO, CODVENDNOVO, CODUSU, TIPO, CODREG, RESTOR) 
                         VALUES ((SELECT MAX(ID) +1 FROM AD_LOGDISTCARTEIRA), SYSDATE, PINATIVO.CODPARC, PINATIVO.CODVEND, FIELD_CODVEND, P_CODUSU, 'I', PINATIVO.REG, PK_RESTOR);
 
--              ATUALIZA OS PARCEIROS ENCONTRADOS
                    UPDATE TGFPAR PAR SET PAR.CODVEND = FIELD_CODVEND WHERE PAR.CODPARC = PINATIVO.CODPARC;
                    
                    CONT := CONT + 1;
                    PASSA := PASSA + P_QTDLINHAS;
                END IF;
                
            END LOOP;
        TEXTMSG := TEXTMSG ||'(' || CONT || ') PARCEIROS IN., ';
        LOGVENDE := LOGVENDE ||' (' || CONT || ') inativos ';
        CONT := 0;
    
        END IF;
        
--SE ATUALIZAR CLIENTE ATIVOS----------------------------------------------------------------------------------------------------
        
        IF PARAM_PTIPOATIVO = 'S' THEN
            PASSA := I;
            
            FOR PATIVO IN (SELECT SEQUENCIA, CODPARC, CODVEND, REG FROM (SELECT ROW_NUMBER() OVER (ORDER BY 'HHH') AS SEQUENCIA
                                  , A.CODPARC
                                  , A.CODVEND
                                  , A.AD_REGIAODISTRIBUICAO AS REG
                             FROM (SELECT DISTINCT P.CODPARC
                                          , P.CODVEND
                                          , AD.PERC
                                          , P.AD_REGIAODISTRIBUICAO
                                    FROM TGFPAR P,  AD_CURVAABCPARCEIROS AD 
                                    WHERE P.CODPARC = AD.CODPARC 
                                      AND (CASE WHEN (SELECT COUNT(1) 
                                            FROM TGFCAB CAB 
                                            WHERE CAB.CODPARC = P.CODPARC
                                                AND CAB.CODTIPOPER IN (3200, 3210)
                                                AND CAB.STATUSNOTA = 'L' 
                                                    AND CAB.STATUSNFE <> 'D' 
                                                    AND CAB.STATUSNFE <> 'C'
                                                    AND CAB.STATUSNFE <> 'V'
                                                    AND CAB.STATUSNFE IS NOT NULL
                                                    AND CAB.STATUSNFE <> 'R'
                                                    AND CAB.STATUSNFE <> 'E') <> 0 THEN (SELECT MAX(CAB.DTFATUR) 
                                                                                FROM TGFCAB CAB 
                                                                                WHERE CAB.CODPARC = P.CODPARC
                                                                                    AND CAB.CODTIPOPER IN (3200, 3210)
                                                                                    AND CAB.STATUSNOTA = 'L' 
                                                                                    AND CAB.STATUSNFE <> 'D' 
                                                                                    AND CAB.STATUSNFE <> 'C'
                                                                                    AND CAB.STATUSNFE <> 'V'
                                                                                    AND CAB.STATUSNFE IS NOT NULL
                                                                                    AND CAB.STATUSNFE <> 'R'
                                                                                    AND CAB.STATUSNFE <> 'E'
                                                                                    AND CAB.DTFATUR BETWEEN (SYSDATE - PARAM_PDIAS) AND SYSDATE) ELSE SYSDATE + 10 END) < SYSDATE
                                            AND P.CLIENTE = 'S'
                                            AND AD.NOVENTA = 'S'
                                            AND P.CODTIPPARC = PARAM_PCOTTIPPARC--PARAM_PCOTTIPPARC --10403000--
                                            AND P.AD_REGIAODISTRIBUICAO = PARAM_PCODREG--PARAM_PCODREG --2020300--
                                            AND P.CODVEND NOT IN (SELECT REGEXP_SUBSTR(PARAM_PNAOCODVEND,'[^,]+', 1, LEVEL) AS RESULTADO FROM DUAL CONNECT BY REGEXP_SUBSTR(PARAM_PNAOCODVEND, '[^,]+', 1, LEVEL) IS NOT NULL)
                                            AND P.CODPARC NOT IN (SELECT EMP.CODEMP FROM TSIEMP EMP)
                                ORDER BY AD.PERC, P.CODPARC) A
                            ORDER BY SEQUENCIA))
            LOOP
                IF PASSA = PATIVO.SEQUENCIA THEN
--              INSERE UM LOG DAS MUDANÇAS --SELECT * DELETE FROM AD_LOGDISTCARTEIRA
                    INSERT INTO AD_LOGDISTCARTEIRA (ID, DTHRALTER, CODPARC, CODVENDANTIGO, CODVENDNOVO, CODUSU, TIPO, CODREG, RESTOR) 
                         VALUES ((SELECT MAX(ID) +1 FROM AD_LOGDISTCARTEIRA), SYSDATE, PATIVO.CODPARC, PATIVO.CODVEND, FIELD_CODVEND, P_CODUSU, 'A', PATIVO.REG, PK_RESTOR);
 
--              ATUALIZA OS PARCEIROS ENCONTRADOS
                    UPDATE TGFPAR PAR SET PAR.CODVEND = FIELD_CODVEND WHERE PAR.CODPARC = PATIVO.CODPARC;
                    
                    CONT := CONT + 1;
                    PASSA := PASSA + P_QTDLINHAS;
                END IF;
                
            END LOOP;
        TEXTMSG := TEXTMSG ||'(' || CONT || ') PARCEIROS AT., ';
        LOGVENDE := LOGVENDE ||'/ (' || CONT || ') ativos ';
        CONT := 0;
    
        END IF;
        
--------Clientes novos
        IF PARAM_PTIPONOVO = 'S' THEN
       --RAISE_APPLICATION_ERROR(-20101, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
        --            O produto (' || TO_CHAR(PARAM_PNAOCODVEND) || ') tem quantidade no estoque do RMA igual a (' || TO_CHAR(P_QTDLINHAS) || '), informe quantidade menor.<br>Favor Verificar!</font></b><br><font>');
            PASSA := I;   
            FOR PNOVO IN (SELECT DISTINCT P.CODPARC
                               , P.CODVEND
                               , ROW_NUMBER() OVER (ORDER BY 'HHH') AS SEQUENCIA
                               , AD_REGIAODISTRIBUICAO AS REG
                          FROM TGFPAR P 
                          WHERE (SELECT COUNT(*) 
                                 FROM TGFCAB CAB 
                                 WHERE CAB.CODPARC = P.CODPARC
                                   AND CAB.CODTIPOPER IN (3210,3200)
                                   ) = 0
                            AND P.CLIENTE = 'S'
                            AND P.CODTIPPARC = PARAM_PCOTTIPPARC
                            AND P.AD_REGIAODISTRIBUICAO = PARAM_PCODREG
                            AND P.CODVEND NOT IN ((SELECT REGEXP_SUBSTR(PARAM_PNAOCODVEND,'[^,]+', 1, LEVEL) AS RESULTADO FROM DUAL cONNECT BY REGEXP_SUBSTR(PARAM_PNAOCODVEND, '[^,]+', 1, LEVEL) IS NOT NULL))
                            AND P.CODPARC NOT IN (SELECT EMP.CODEMP FROM TSIEMP EMP)
                          ORDER BY 1)
            LOOP
            
                IF PASSA = PNOVO.SEQUENCIA THEN 
                
    --              INSERE UM LOG DAS MUDANÇAS --SELECT * FROM AD_LOGDISTCARTEIRA
                    INSERT INTO AD_LOGDISTCARTEIRA (ID, DTHRALTER, CODPARC, CODVENDANTIGO, CODVENDNOVO, CODUSU, TIPO, CODREG, RESTOR) 
                         VALUES ((SELECT MAX(ID) +1 FROM AD_LOGDISTCARTEIRA), SYSDATE, PNOVO.CODPARC, PNOVO.CODVEND, FIELD_CODVEND, P_CODUSU, 'N', PNOVO.REG, PK_RESTOR);
 
    --              ATUALIZA OS PARCEIROS ENCONTRADOS
                    UPDATE TGFPAR PAR SET PAR.CODVEND = FIELD_CODVEND WHERE PAR.CODPARC = PNOVO.CODPARC;
                        
                    CONT := CONT + 1;
                    PASSA := PASSA + P_QTDLINHAS;
                END IF;
            END LOOP;
        TEXTMSG := TEXTMSG || '(' || CONT || ') PARCEIROS NO., ';
        LOGVENDE := LOGVENDE ||'/ (' || CONT || ') novos';
        CONT := 0;
--        RAISE_APPLICATION_ERROR(-20101, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
--                    O produto (' || TO_CHAR(PARAM_PNAOCODVEND) || ') tem quantidade no estoque do RMA igual a (' || TO_CHAR(P_QTDLINHAS) || '), informe quantidade menor.<br>Favor Verificar!</font></b><br><font>');
        END IF;
       update tgfven ven set ven.AD_LOGDIVCARD = LOGVENDE, VEN.CODREG = PARAM_PCODREG WHERE VEN.CODVEND = FIELD_CODVEND;
       END LOOP;

END IF; 
EXECUTE IMMEDIATE 'ALTER TRIGGER TOTALPRD.TRG_UPD_TGFPAR_TOTAL ENABLE';

P_MENSAGEM := TEXTMSG;

END;
/
