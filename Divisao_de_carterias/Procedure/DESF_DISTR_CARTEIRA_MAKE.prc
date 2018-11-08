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
       VENDATIVO CHAR;
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
       PARAM_MOMENTO := NVL(ACT_TXT_PARAM(P_IDSESSAO, 'MOMENTO'), 'N'); --U=ULTIMO / P=PENULTIMO / A=ANTIPENULTIMO
       PARAM_ALTDATA := NVL(ACT_TXT_PARAM(P_IDSESSAO, 'ULTDATA'), 'N');

--RAISE_APPLICATION_ERROR(-20101, 
--'<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
--PARAM_DIALT ' || to_char(PARAM_DIALT) ||'
--PARAM_MOMENTO ' || to_char(PARAM_MOMENTO) ||'
--PARAM_ALTDATA ' || to_char(PARAM_ALTDATA) ||'.</font></b><br><font>');

--A TRIGGER ABAIXO IMPEDE DE ATUALIZAR O PARCEIRO CASO O CADASTRO ESTEJA ERRADO.
EXECUTE IMMEDIATE 'ALTER TRIGGER TRG_UPD_TGFPAR_TOTAL DISABLE';
--SE FOR PELA ULTIMA DATA-----------------------------------------------------------------------------------------------------
    IF NVL(PARAM_ALTDATA, 'N') = 'S' THEN
        --OBTEM STATUS
       SELECT MAX(AD.DTHRALTER) 
       INTO PSTATUS 
       FROM AD_LOGDISTCARTEIRA AD 
       WHERE AD.TIPO <> 'D' AND TRUNC(AD.DTHRALTER) = (SELECT MAX(TRUNC(D.DTHRALTER)) 
                                                       FROM AD_LOGDISTCARTEIRA D 
                                                       WHERE D.RESTOR = (SELECT MAX(A.RESTOR)
                                                                         FROM AD_LOGDISTCARTEIRA A));
    
        FOR ANTIGO IN (SELECT AD.DTHRALTER, AD.CODPARC, AD.CODVENDANTIGO, AD.RESTOR, AD.CODREG, AD.TIPO 
                       FROM AD_LOGDISTCARTEIRA AD 
                       WHERE AD.TIPO <> 'D' AND TRUNC(AD.DTHRALTER) = (SELECT MAX(TRUNC(D.DTHRALTER)) 
                                                                       FROM AD_LOGDISTCARTEIRA D 
                                                                       WHERE D.RESTOR = (SELECT MAX(A.RESTOR)
                                                                                         FROM AD_LOGDISTCARTEIRA A)))
        LOOP
 
                    SELECT VEN.ATIVO
                    INTO VENDATIVO
                    FROM TGFVEN VEN
                    WHERE VEN.CODVEND = ANTIGO.CODVENDANTIGO;
                    
                    IF NVL(VENDATIVO,'N') = 'N' THEN
                        UPDATE TGFVEN VEN SET VEN.ATIVO = 'S' WHERE VEN.CODVEND = ANTIGO.CODVENDANTIGO;
                        VENDATIVO := 'A';
                    END IF;
            --ATUALIZA OS VENDEDORES 
            UPDATE TGFPAR PAR SET CODVEND = ANTIGO.CODVENDANTIGO WHERE PAR.CODPARC = ANTIGO.CODPARC AND ANTIGO.TIPO <> 'D';
            
                    IF VENDATIVO = 'A' THEN
                        UPDATE TGFVEN VEN SET VEN.ATIVO = 'N' WHERE VEN.CODVEND = ANTIGO.CODVENDANTIGO;
                        VENDATIVO := 'B';
                    END IF;
            
            --INSERE UM LOG DAS MUDANÇAS --SELECT MAX(RESTOR) + 1 FROM AD_LOGDISTCARTEIRA
            INSERT INTO AD_LOGDISTCARTEIRA (ID, DTHRALTER, CODPARC, CODVENDNOVO, CODUSU, TIPO, CODREG, RESTOR) 
                 VALUES ((SELECT MAX(ID) +1 FROM AD_LOGDISTCARTEIRA), SYSDATE, ANTIGO.CODPARC, ANTIGO.CODVENDANTIGO, P_CODUSU, 'D', ANTIGO.CODREG, PK_RESTOR);
        CONT := CONT + 1;
        END LOOP;
    PMSG := 'Desfeita divisão de carteira pela última data do dia ' || TO_CHAR(PSTATUS) || '.';
--SE FOR PELO MOMENTO--------------------------------------------------------------------------------------------
    ELSIF PARAM_MOMENTO <> 'N' THEN --U=ULTIMO / P=PENULTIMO / A=ANTIPENULTIMO
        IF PARAM_MOMENTO = 'U' THEN     
            FOR IULTIMO IN (SELECT AD.DTHRALTER, AD.CODPARC, AD.CODVENDANTIGO, AD.RESTOR, AD.CODREG, AD.TIPO
                            FROM AD_LOGDISTCARTEIRA AD 
                            WHERE AD.TIPO <> 'D' AND RESTOR = (SELECT MAX(A.RESTOR)
                                                               FROM AD_LOGDISTCARTEIRA A))
            LOOP
                    SELECT VEN.ATIVO
                    INTO VENDATIVO
                    FROM TGFVEN VEN
                    WHERE VEN.CODVEND = IULTIMO.CODVENDANTIGO;
                    IF NVL(VENDATIVO,'N') = 'N' THEN
                        UPDATE TGFVEN VEN SET VEN.ATIVO = 'S' WHERE VEN.CODVEND = IULTIMO.CODVENDANTIGO;
                        VENDATIVO := 'A';
                    END IF;           
            
                UPDATE TGFPAR PAR SET CODVEND = IULTIMO.CODVENDANTIGO WHERE PAR.CODPARC = IULTIMO.CODPARC AND IULTIMO.TIPO <> 'D';
                
                    IF VENDATIVO = 'A' THEN
                        UPDATE TGFVEN VEN SET VEN.ATIVO = 'N' WHERE VEN.CODVEND = IULTIMO.CODVENDANTIGO;
                        VENDATIVO := 'B';
                    END IF;
                
--INSERE UM LOG DAS MUDANÇAS --SELECT MAX(RESTOR) + 1 FROM AD_LOGDISTCARTEIRA
            INSERT INTO AD_LOGDISTCARTEIRA (ID, DTHRALTER, CODPARC, CODVENDNOVO, CODUSU, TIPO, CODREG, RESTOR) 
                 VALUES ((SELECT MAX(ID) +1 FROM AD_LOGDISTCARTEIRA), SYSDATE, IULTIMO.CODPARC, IULTIMO.CODVENDANTIGO, P_CODUSU, 'D', IULTIMO.CODREG, PK_RESTOR);                
            CONT := CONT + 1;
            END LOOP;                
        PMSG := 'Desfeita última atualização!';                   
        ELSIF PARAM_MOMENTO = 'P' THEN
            FOR IPENULTIMO IN (SELECT AD.DTHRALTER, AD.CODPARC, AD.CODVENDANTIGO, AD.RESTOR, AD.CODREG, AD.TIPO 
                               FROM AD_LOGDISTCARTEIRA AD 
                               WHERE AD.TIPO <> 'D' AND RESTOR = (SELECT MAX(A.RESTOR) -1
                                                                  FROM AD_LOGDISTCARTEIRA A))
            LOOP
            
                    SELECT VEN.ATIVO
                    INTO VENDATIVO
                    FROM TGFVEN VEN
                    WHERE VEN.CODVEND = IPENULTIMO.CODVENDANTIGO;
                    IF NVL(VENDATIVO,'N') = 'N' THEN
                        UPDATE TGFVEN VEN SET VEN.ATIVO = 'S' WHERE VEN.CODVEND = IPENULTIMO.CODVENDANTIGO;
                        VENDATIVO := 'A';
                    END IF;
            
                UPDATE TGFPAR PAR SET CODVEND = IPENULTIMO.CODVENDANTIGO WHERE PAR.CODPARC = IPENULTIMO.CODPARC AND IPENULTIMO.TIPO <> 'D';
                
                    IF VENDATIVO = 'A' THEN
                        UPDATE TGFVEN VEN SET VEN.ATIVO = 'N' WHERE VEN.CODVEND = IPENULTIMO.CODVENDANTIGO;
                        VENDATIVO := 'B';
                    END IF; 
                
--INSERE UM LOG DAS MUDANÇAS --SELECT MAX(RESTOR) + 1 FROM AD_LOGDISTCARTEIRA
            INSERT INTO AD_LOGDISTCARTEIRA (ID, DTHRALTER, CODPARC, CODVENDNOVO, CODUSU, TIPO, CODREG, RESTOR) 
                 VALUES ((SELECT MAX(ID) +1 FROM AD_LOGDISTCARTEIRA), SYSDATE, IPENULTIMO.CODPARC, IPENULTIMO.CODVENDANTIGO, P_CODUSU, 'D', IPENULTIMO.CODREG, PK_RESTOR);                
            CONT := CONT + 1;
            END LOOP;
        PMSG := 'Desfeita penúltima atualização!';    
        ELSIF PARAM_MOMENTO = 'A' THEN
            FOR IANTIPENULTIMO IN (SELECT AD.DTHRALTER, AD.CODPARC, AD.CODVENDANTIGO, AD.RESTOR, AD.CODREG, AD.TIPO
                                   FROM AD_LOGDISTCARTEIRA AD 
                                   WHERE AD.TIPO <> 'D' AND RESTOR = (SELECT MAX(A.RESTOR) -2
                                                                      FROM AD_LOGDISTCARTEIRA A))
            LOOP
            
                    SELECT VEN.ATIVO
                    INTO VENDATIVO
                    FROM TGFVEN VEN
                    WHERE VEN.CODVEND = IANTIPENULTIMO.CODVENDANTIGO;
                    IF NVL(VENDATIVO,'N') = 'N' THEN
                        UPDATE TGFVEN VEN SET VEN.ATIVO = 'S' WHERE VEN.CODVEND = IANTIPENULTIMO.CODVENDANTIGO;
                        VENDATIVO := 'A';
                    END IF;
            
                UPDATE TGFPAR PAR SET CODVEND = IANTIPENULTIMO.CODVENDANTIGO WHERE PAR.CODPARC = IANTIPENULTIMO.CODPARC AND IANTIPENULTIMO.TIPO <> 'D';
                
                    IF VENDATIVO = 'A' THEN
                        UPDATE TGFVEN VEN SET VEN.ATIVO = 'N' WHERE VEN.CODVEND = IANTIPENULTIMO.CODVENDANTIGO;
                        VENDATIVO := 'B';
                    END IF; 
                
--INSERE UM LOG DAS MUDANÇAS --SELECT MAX(RESTOR) + 1 FROM AD_LOGDISTCARTEIRA
            INSERT INTO AD_LOGDISTCARTEIRA (ID, DTHRALTER, CODPARC, CODVENDNOVO, CODUSU, TIPO, CODREG, RESTOR) 
                 VALUES ((SELECT MAX(ID) +1 FROM AD_LOGDISTCARTEIRA), SYSDATE, IANTIPENULTIMO.CODPARC, IANTIPENULTIMO.CODVENDANTIGO, P_CODUSU, 'D', IANTIPENULTIMO.CODREG, PK_RESTOR);                
            CONT := CONT + 1;    
            END LOOP;
        PMSG := 'Desfeita antipenúltima atualização!';    
        END IF;
--SE FOR PELO NUMERO DO RESTOR------------------------------------------------------------------------------------------
    ELSIF PARAM_DIALT IS NOT NULL THEN
        FOR IDRESTOR IN (SELECT AD.DTHRALTER, AD.CODPARC, AD.CODVENDANTIGO, AD.RESTOR, AD.CODREG, AD.TIPO 
                         FROM AD_LOGDISTCARTEIRA AD 
                         WHERE AD.TIPO <> 'D' AND RESTOR = PARAM_DIALT)
        LOOP
        
                    SELECT VEN.ATIVO
                    INTO VENDATIVO
                    FROM TGFVEN VEN
                    WHERE VEN.CODVEND = IDRESTOR.CODVENDANTIGO;
                    IF NVL(VENDATIVO,'N') = 'N' THEN
                        UPDATE TGFVEN VEN SET VEN.ATIVO = 'S' WHERE VEN.CODVEND = IDRESTOR.CODVENDANTIGO;
                        VENDATIVO := 'A';
                    END IF;
        
            UPDATE TGFPAR PAR SET CODVEND = IDRESTOR.CODVENDANTIGO WHERE PAR.CODPARC = IDRESTOR.CODPARC AND IDRESTOR.TIPO <> 'D';
            
                    IF VENDATIVO = 'A' THEN
                        UPDATE TGFVEN VEN SET VEN.ATIVO = 'N' WHERE VEN.CODVEND = IDRESTOR.CODVENDANTIGO;
                        VENDATIVO := 'B';
                    END IF; 
            
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
EXECUTE IMMEDIATE 'ALTER TRIGGER TRG_UPD_TGFPAR_TOTAL ENABLE';      
    

P_MENSAGEM := PMSG;

END;
/
