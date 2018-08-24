CREATE OR REPLACE PROCEDURE TOTALPRD."DESF_DISTR_CARTEIRA_MAKE" (
       P_CODUSU NUMBER,        -- Código do usuário logado
       P_IDSESSAO VARCHAR2,    -- Identificador da execução. Serve para buscar informações dos parâmetros/campos da execução.
       P_QTDLINHAS NUMBER,     -- Informa a quantidade de registros selecionados no momento da execução.
       P_MENSAGEM OUT VARCHAR2 -- Caso seja passada uma mensagem aqui, ela será exibida como uma informação ao usuário.
) AS
       PARAM_DIALT NUMBER;
       PARAM_MOMENTO CHAR;
       PARAM_ALTDATA CHAR;
       FIELD_CODVEND NUMBER;
       PK_RESTOR INT;
       PSTATUS VARCHAR(50);
       PMSG VARCHAR(4000);
       CONT INT := 0;
BEGIN

/*
    AUTOR: Mauricio Rodrigues
    Data da criação: 17/08/2018
    Descrição: Desfaz Divisão de carterias da distribuição, com base na data ou no id ou nas últimas alterações.
*/

       SELECT MAX(RESTOR) + 1 
       INTO PK_RESTOR
       FROM AD_LOGDISTCARTEIRA;
       
       PARAM_DIALT := ACT_INT_PARAM(P_IDSESSAO, 'DIALT');
       PARAM_MOMENTO := NVL(ACT_TXT_PARAM(P_IDSESSAO, 'MOMENTO'), 'N');
       PARAM_ALTDATA := NVL(ACT_TXT_PARAM(P_IDSESSAO, 'ULTDATA'), 'N');

--SE FOR PELA ULTIMA DATA
    IF PARAM_ALTDATA <> 'N' THEN
        --OBTEM STATUS
       SELECT MAX(AD.DTHRALTER) 
       INTO PSTATUS 
       FROM AD_LOGDISTCARTEIRA AD 
       WHERE AD.TIPO <> 'D' AND TRUNC(AD.DTHRALTER) = (SELECT MAX(TRUNC(D.DTHRALTER)) 
                                                       FROM AD_LOGDISTCARTEIRA D 
                                                       WHERE D.RESTOR = (SELECT MAX(A.RESTOR)
                                                                         FROM AD_LOGDISTCARTEIRA A));
    
        FOR ANTIGO IN (SELECT AD.DTHRALTER, AD.CODPARC, AD.CODVENDANTIGO, AD.RESTOR, AD.CODREG 
                       FROM AD_LOGDISTCARTEIRA AD 
                       WHERE AD.TIPO <> 'D' AND TRUNC(AD.DTHRALTER) = (SELECT MAX(TRUNC(D.DTHRALTER)) 
                                                                       FROM AD_LOGDISTCARTEIRA D 
                                                                       WHERE D.RESTOR = (SELECT MAX(A.RESTOR)
                                                                                         FROM AD_LOGDISTCARTEIRA A)))
        LOOP
            --ATUALIZA OS VENDEDORES 
            UPDATE TGFPAR PAR SET CODVEND = ANTIGO.CODVENDANTIGO WHERE PAR.CODPARC = ANTIGO.CODPARC;
            --INSERE UM LOG DAS MUDANÇAS --SELECT MAX(RESTOR) + 1 FROM AD_LOGDISTCARTEIRA
            INSERT INTO AD_LOGDISTCARTEIRA (ID, DTHRALTER, CODPARC, CODVENDNOVO, CODUSU, TIPO, CODREG, RESTOR) 
                 VALUES ((SELECT MAX(ID) +1 FROM AD_LOGDISTCARTEIRA), SYSDATE, ANTIGO.CODPARC, ANTIGO.CODVENDANTIGO, P_CODUSU, 'D', ANTIGO.CODREG, PK_RESTOR);
        CONT := CONT + 1;
        END LOOP;
    PMSG := 'Desfeita divisão de carteira pela última data do dia ' || TO_CHAR(PSTATUS) || '.';
--SE FOR PELO MOMENTO                        
    ELSIF PARAM_MOMENTO <> 'N' THEN --U=ULTIMO / P=PENULTIMO / A=ANTIPENULTIMO
        IF PARAM_MOMENTO = 'U' THEN     
            FOR IULTIMO IN (SELECT AD.DTHRALTER, AD.CODPARC, AD.CODVENDANTIGO, AD.RESTOR, AD.CODREG 
                            FROM AD_LOGDISTCARTEIRA AD 
                            WHERE AD.TIPO <> 'D' AND RESTOR = (SELECT MAX(A.RESTOR)
                                                               FROM AD_LOGDISTCARTEIRA A))
            LOOP
                UPDATE TGFPAR PAR SET CODVEND = IULTIMO.CODVENDANTIGO WHERE PAR.CODPARC = IULTIMO.CODPARC;
--INSERE UM LOG DAS MUDANÇAS --SELECT MAX(RESTOR) + 1 FROM AD_LOGDISTCARTEIRA
            INSERT INTO AD_LOGDISTCARTEIRA (ID, DTHRALTER, CODPARC, CODVENDNOVO, CODUSU, TIPO, CODREG, RESTOR) 
                 VALUES ((SELECT MAX(ID) +1 FROM AD_LOGDISTCARTEIRA), SYSDATE, IULTIMO.CODPARC, IULTIMO.CODVENDANTIGO, P_CODUSU, 'D', IULTIMO.CODREG, PK_RESTOR);                
            CONT := CONT + 1;
            END LOOP;                
        PMSG := 'Desfeita última atualização!';                   
        ELSIF PARAM_MOMENTO = 'P' THEN
            FOR IPENULTIMO IN (SELECT AD.DTHRALTER, AD.CODPARC, AD.CODVENDANTIGO, AD.RESTOR, AD.CODREG 
                               FROM AD_LOGDISTCARTEIRA AD 
                               WHERE AD.TIPO <> 'D' AND RESTOR = (SELECT MAX(A.RESTOR) -1
                                                                  FROM AD_LOGDISTCARTEIRA A))
            LOOP
                UPDATE TGFPAR PAR SET CODVEND = IPENULTIMO.CODVENDANTIGO WHERE PAR.CODPARC = IPENULTIMO.CODPARC;
--INSERE UM LOG DAS MUDANÇAS --SELECT MAX(RESTOR) + 1 FROM AD_LOGDISTCARTEIRA
            INSERT INTO AD_LOGDISTCARTEIRA (ID, DTHRALTER, CODPARC, CODVENDNOVO, CODUSU, TIPO, CODREG, RESTOR) 
                 VALUES ((SELECT MAX(ID) +1 FROM AD_LOGDISTCARTEIRA), SYSDATE, IPENULTIMO.CODPARC, IPENULTIMO.CODVENDANTIGO, P_CODUSU, 'D', IPENULTIMO.CODREG, PK_RESTOR);                
            CONT := CONT + 1;
            END LOOP;
        PMSG := 'Desfeita penúltima atualização!';    
        ELSIF PARAM_MOMENTO = 'A' THEN
            FOR IANTIPENULTIMO IN (SELECT AD.DTHRALTER, AD.CODPARC, AD.CODVENDANTIGO, AD.RESTOR, AD.CODREG 
                                   FROM AD_LOGDISTCARTEIRA AD 
                                   WHERE AD.TIPO <> 'D' AND RESTOR = (SELECT MAX(A.RESTOR) -2
                                                                      FROM AD_LOGDISTCARTEIRA A))
            LOOP
                UPDATE TGFPAR PAR SET CODVEND = IANTIPENULTIMO.CODVENDANTIGO WHERE PAR.CODPARC = IANTIPENULTIMO.CODPARC;
--INSERE UM LOG DAS MUDANÇAS --SELECT MAX(RESTOR) + 1 FROM AD_LOGDISTCARTEIRA
            INSERT INTO AD_LOGDISTCARTEIRA (ID, DTHRALTER, CODPARC, CODVENDNOVO, CODUSU, TIPO, CODREG, RESTOR) 
                 VALUES ((SELECT MAX(ID) +1 FROM AD_LOGDISTCARTEIRA), SYSDATE, IANTIPENULTIMO.CODPARC, IANTIPENULTIMO.CODVENDANTIGO, P_CODUSU, 'D', IANTIPENULTIMO.CODREG, PK_RESTOR);                
            CONT := CONT + 1;    
            END LOOP;
        PMSG := 'Desfeita antipenúltima atualização!';    
        END IF;
--SE FOR PELO NUMERO DO RESTOR                        
    ELSIF PARAM_DIALT IS NOT NULL THEN
        FOR IDRESTOR IN (SELECT AD.DTHRALTER, AD.CODPARC, AD.CODVENDANTIGO, AD.RESTOR, AD.CODREG 
                         FROM AD_LOGDISTCARTEIRA AD 
                         WHERE AD.TIPO <> 'D' AND RESTOR = PARAM_DIALT)
        LOOP
            UPDATE TGFPAR PAR SET CODVEND = IDRESTOR.CODVENDANTIGO WHERE PAR.CODPARC = IDRESTOR.CODPARC;
--INSERE UM LOG DAS MUDANÇAS --SELECT MAX(RESTOR) + 1 FROM AD_LOGDISTCARTEIRA
            INSERT INTO AD_LOGDISTCARTEIRA (ID, DTHRALTER, CODPARC, CODVENDNOVO, CODUSU, TIPO, CODREG, RESTOR) 
                 VALUES ((SELECT MAX(ID) +1 FROM AD_LOGDISTCARTEIRA), SYSDATE, IDRESTOR.CODPARC, IDRESTOR.CODVENDANTIGO, P_CODUSU, 'D', IDRESTOR.CODREG, PK_RESTOR);                
        CONT := CONT + 1;
        END LOOP;
    PMSG := 'Desfeita atualização por ID!';    
--SE NÃO TIVER NADA MARCADO        
    ELSE
        PMSG := 'Nenhuma opção foi informada!';
    END IF;
        
    

P_MENSAGEM := PMSG;

END;
/
