CREATE OR REPLACE PROCEDURE TOTALPRD.CRIA_SUBSTITUI_M_TOTAL (
       P_CODUSU NUMBER,        -- Código do usuário logado
       P_IDSESSAO VARCHAR2,    -- Identificador da execução. Serve para buscar informações dos parâmetros/campos da execução.
       P_QTDLINHAS NUMBER,     -- Informa a quantidade de registros selecionados no momento da execução.
       P_MENSAGEM OUT VARCHAR2 -- Caso seja passada uma mensagem aqui, ela será exibida como uma informação ao usuário.
) AS
    FIELD_ID INT;
    PMSG VARCHAR2(4000);
    CONT INT;
    
    EMPORIG INT;
    EMPDEST INT;
    VLREMP FLOAT;
    PEMPORIG INT;
    PEMPDEST INT;
    PEMPVLRDEST FLOAT;
    PEMPVLRORIG FLOAT;
    PNOMEEMP VARCHAR(100);
    VLR FLOAT;
BEGIN
    --Parametros
        EMPORIG := ACT_INT_PARAM(P_IDSESSAO,'EMPORIG');   --Insere vendedores por Gerente
        EMPDEST := ACT_INT_PARAM(P_IDSESSAO,'EMPDEST');   --ou Insere vendedores por Grupo
        VLREMP := ACT_DEC_PARAM(P_IDSESSAO,'VLREMP');   --ou Insere vendedores por Grupo
        
--        PARAM_RECALC := ACT_TXT_PARAM(P_IDSESSAO,'RECALC'); --Recalcula Vendedores
--        RECMET := ACT_TXT_PARAM(P_IDSESSAO,'RECMET');   --Inserir/Recalcular grupos de Meta
--        ATUEMP := ACT_TXT_PARAM(P_IDSESSAO,'ATUEMP');   --Inserir/Recalcular grupos de Meta
--        PDTINI := ACT_DTA_PARAM(P_IDSESSAO,'DTINI');   --Inserir/Recalcular grupos de Meta
--        PDTFIN := ACT_DTA_PARAM(P_IDSESSAO,'DTFIN');   --Inserir/Recalcular grupos de Meta
       -- Os valores informados pelo formulário de parâmetros, podem ser obtidos com as funções:
       --     ACT_INT_PARAM
       --     ACT_DEC_PARAM
       --     ACT_TXT_PARAM
       --     ACT_DTA_PARAM
       -- Estas funções recebem 2 argumentos:
       --     ID DA SESSÃO - Identificador da execução (Obtido através de P_IDSESSAO))
       --     NOME DO PARAMETRO - Determina qual parametro deve se deseja obter.


    FOR I IN 1..P_QTDLINHAS-- Este loop permite obter o valor de campos dos registros envolvidos na execução.
    LOOP                 -- A variável "I" representa o registro corrente.

       FIELD_ID := ACT_INT_FIELD(P_IDSESSAO, I, 'ID');
       
       
       SELECT count(*)
        INTO PEMPVLRORIG
        FROM AD_GRUMETEMP A 
        WHERE A.ID = FIELD_ID
          AND A.CODEMP = EMPORIG;
        
        IF PEMPVLRORIG = 0 THEN
RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#000000">
Empresa origem não existe abaixo!</font></b><br><font>');
        END IF;
        
        SELECT count(*)
        INTO PEMPVLRORIG
        FROM AD_GRUMETEMP A 
        WHERE A.ID = FIELD_ID
          AND A.CODEMP = EMPDEST;
        
        IF PEMPVLRORIG = 0 THEN
RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#000000">
Empresa destino não existe abaixo!</font></b><br><font>');
        END IF;
       
       
        --OBTEM O COD EMPRESA ORIGEM E O NOME.
        SELECT NVL(A.META,0), (SELECT NOMEFANTASIA FROM TSIEMP WHERE CODEMP = EMPORIG) AS NOMEEMP
        INTO PEMPVLRORIG, PNOMEEMP
        FROM AD_GRUMETEMP A 
        WHERE A.ID = FIELD_ID
          AND A.CODEMP = EMPORIG;

        --VERIFICA SE A EMPRESA ORIGEM TEM VALOR = 0.
        IF VLREMP = 0 THEN
RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#000000">
Primeiro insira o valor desejado no campo Meta da Empresa '|| to_char(EMPORIG) ||' - ' || TO_CHAR(PNOMEEMP) || '.</font></b><br><font>');
        END IF;
  
        --VERIFICA SE A EMPRESA ORIGEM É IGUAL A EMPRESA DESTINO.
        IF EMPORIG = EMPDEST THEN
RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#000000">
O campo Origem está igual ao campo Destino!</font></b><br><font>');
        END IF;
        
        --OBTEM VALOR E NOME DA EMPRESA DESTINO.
        SELECT NVL(A.META,0), (SELECT NOMEFANTASIA FROM TSIEMP WHERE CODEMP = EMPDEST) AS NOMEEMP
        INTO PEMPVLRDEST, PNOMEEMP
        FROM AD_GRUMETEMP A 
        WHERE A.ID = FIELD_ID
          AND A.CODEMP = EMPDEST;
------------------------------------------------------------------------------------------------------------------------------------------------------------
--ATUALIZA A EMPRESA ZERADA COM O VALOR PROPOSTO PELO USUÁRIO
------------------------------------------------------------------------------------------------------------------------------------------------------------
--        IF PEMPVLRDEST = 0 THEN
            UPDATE AD_GRUMETEMP SET META = VLREMP WHERE ID = FIELD_ID AND CODEMP = EMPDEST;
            PMSG := PMSG || 'Update OK!';
--        END IF;
        
        --Verifica a existência de vendedores cadastrados
--        SELECT COUNT(VEN.CODVEND)
--        INTO CONT
--        FROM AD_GRUMETEMP EMP INNER JOIN AD_METEMPVENDDIA VEN ON (VEN.IDMETEMP = EMP.IDMETEMP AND VEN.ID=EMP.ID) 
--        WHERE EMP.ID = FIELD_ID AND EMP.CODEMP = EMPDEST;

--        IF CONT <= 0 THEN
--RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#000000">
--Favor inserir vendedor(es) na aba:<br>Metas por empresa > Vendedores (dia-grupo pai)!</font></b><br><font>');  
--        ELSE
            

            DELETE FROM AD_EMPVENDIAGRU DEL WHERE ID = (SELECT MAX(EMP.ID)
                FROM AD_GRUMETEMP EMP INNER JOIN AD_EMPVEND VEN ON (VEN.IDMETEMP = EMP.IDMETEMP AND VEN.ID=EMP.ID) 
                WHERE EMP.ID = FIELD_ID AND EMP.CODEMP = EMPDEST)
                AND DEL.IDMETEMP = (SELECT MAX(EMP.IDMETEMP)
                FROM AD_GRUMETEMP EMP INNER JOIN AD_EMPVEND VEN ON (VEN.IDMETEMP = EMP.IDMETEMP AND VEN.ID=EMP.ID) 
                WHERE EMP.ID = FIELD_ID AND EMP.CODEMP = EMPDEST); 
        
            DELETE FROM AD_EMPVEND DEL WHERE DEL.ID = (SELECT MAX(EMP.ID)
                FROM AD_GRUMETEMP EMP INNER JOIN AD_EMPVEND VEN ON (VEN.IDMETEMP = EMP.IDMETEMP AND VEN.ID=EMP.ID) 
                WHERE EMP.ID = FIELD_ID AND EMP.CODEMP = EMPDEST)
                AND DEL.IDMETEMP = (SELECT MAX(EMP.IDMETEMP)
                FROM AD_GRUMETEMP EMP INNER JOIN AD_EMPVEND VEN ON (VEN.IDMETEMP = EMP.IDMETEMP AND VEN.ID=EMP.ID) 
                WHERE EMP.ID = FIELD_ID AND EMP.CODEMP = EMPDEST); 
                
            
------------------------------------------------------------------------------------------------------------------------------------------------------------
--INSERE FILHOS DOS GRUPOS DOS VENDEDORES DAS EMPRESAS NOVO
------------------------------------------------------------------------------------------------------------------------------------------------------------
            FOR IVEND IN (SELECT VEN.ID
                            , (SELECT MAX(E.IDMETEMP) FROM  AD_GRUMETEMP E WHERE E.ID = EMP.ID AND E.CODEMP = EMPDEST) AS IDMETEMP
                            , VEN.IDEMPVEND
                            , VEN.CODEMP
                            , VEN.CODVEND
                            , VEN.VLR
                            , VEN.PESO
                            , EMP.META 
                         FROM AD_GRUMETEMP EMP INNER JOIN AD_EMPVEND VEN ON (VEN.IDMETEMP = EMP.IDMETEMP AND VEN.ID=EMP.ID) 
                         WHERE EMP.ID = FIELD_ID 
                           AND EMP.CODEMP = EMPORIG
                         ORDER BY CODVEND) 
            LOOP

                --SELECT * FROM AD_EMPVEND
                INSERT INTO AD_EMPVEND (ID, IDMETEMP, IDEMPVEND,CODEMP, CODVEND, VLR, PESO, META) VALUES
                (FIELD_ID, IVEND.IDMETEMP, IVEND.IDEMPVEND, IVEND.CODEMP, IVEND.CODVEND, IVEND.VLR, IVEND.PESO, (VLREMP / 100) * IVEND.PESO);
                --VLR := VLREMP - ((VLREMP / 100) * IVEND.T) ;
------------------------------------------------------------------------------------------------------------------------------------------------------------
--OBTEM GRUPOS DE PRODUTOS PAI - CADASTRO
------------------------------------------------------------------------------------------------------------------------------------------------------------
--                FOR IEMPGRU2 IN (SELECT G.IDGRU, G.CODGRUPOPROD AS GRUPO, G.META, G.DATA, G.SUGESTAO, G.PERC, (SELECT SUM(A.META) FROM AD_GRUPOSPRODUSU A WHERE A.ID = G.ID) AS TOTALZAO
--                                FROM AD_GRUPOSPRODUSU G 
--                                WHERE ID = FIELD_ID)
--                LOOP
                
                
                    FOR IEMPGRUFI IN (SELECT ID, IDMETEMP, IDEMPVEND, IDEMPVENDIA, CODEMP, CODVEND, CODGRUPOPROD, VLR, PESO, META, DATA 
                                    FROM AD_EMPVENDIAGRU order by 1,2,3,4)
                    LOOP
--                 
--RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#000000">
----' ||TO_CHAR(FIELD_ID)||'--' ||TO_CHAR(IVEND.IDMETEMP)||'--' ||TO_CHAR(IEMPGRUFI.IDEMPVEND)||'--' ||TO_CHAR(IEMPGRUFI.CODVEND)||'--' ||TO_CHAR(IEMPGRUFI.CODGRUPOPROD)||'--' ||TO_CHAR(IEMPGRUFI.VLR)||'--' ||TO_CHAR((VLREMP / 100) * IEMPGRUFI.PESO)||'--' ||TO_CHAR(IEMPGRUFI.DATA)||'</font></b><br><font>');
--                        SELECT * --MAX(IDEMPVENDIA) + 1
--                        FROM AD_EMPVENDIAGRU AD
--                        WHERE AD.ID = 26
--                          AND AD.IDMETEMP = 4

                        INSERT INTO AD_EMPVENDIAGRU (ID, IDMETEMP, IDEMPVEND, IDEMPVENDIA, CODEMP, CODVEND, CODGRUPOPROD, VLR, PESO, META, DATA) VALUES
                        (FIELD_ID, IVEND.IDMETEMP, IEMPGRUFI.IDEMPVEND, IEMPGRUFI.IDEMPVENDIA, EMPDEST, IEMPGRUFI.CODVEND, IEMPGRUFI.CODGRUPOPROD, IEMPGRUFI.VLR, IEMPGRUFI.PESO, (VLREMP / 100) * IEMPGRUFI.PESO, IEMPGRUFI.DATA);
                    END LOOP;
--                END LOOP;
            END LOOP;       
--        END IF;
    END LOOP;
    PMSG := PMSG || 'Atualiação dos vendedores = OK!';

    P_MENSAGEM := PMSG;

END;
/
