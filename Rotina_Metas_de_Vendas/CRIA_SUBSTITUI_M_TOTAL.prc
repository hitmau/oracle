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

        --VERIFICA SE A EMPRESA DESTINO REALMENTE TEM VALOR = 0. 
--        IF PEMPVLRDEST = 0 THEN
            UPDATE AD_GRUMETEMP SET META = VLREMP WHERE ID = FIELD_ID AND CODEMP = EMPORIG;
--        END IF;
        
        --Verifica a existência de vendedores cadastrados
        SELECT COUNT(VEN.CODVEND)
        INTO CONT
        FROM AD_GRUMETEMP EMP INNER JOIN AD_METEMPVENDDIA VEN ON (VEN.IDMETEMP = EMP.IDMETEMP AND VEN.ID=EMP.ID) 
        WHERE EMP.ID = FIELD_ID AND EMP.CODEMP = EMPDEST;

        IF CONT > 0 THEN
RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#000000">
Favor inserir vendedor(es) na aba:<br>Metas por empresa > Vendedores (dia-grupo pai)!</font></b><br><font>');  
        ELSE
            FOR IVEND IN (SELECT VEN.ID
                            , (SELECT MAX(E.IDMETEMP) FROM  AD_GRUMETEMP E WHERE E.ID = EMP.ID AND E.CODEMP = EMPDEST) AS PIDMETEMP
                            , VEN.IDMETEMP
                            , VEN.IDGRUEMPVEN
                            , VEN.CODGRUPOPROD AS GRUPO
                            , VEN.CODEMP
                            , VEN.CODVEND
                            , VEN.DATA
                            , VEN.VLR
                            , VEN.PESO
                            , VEN.T
                            , EMP.META 
                         FROM AD_GRUMETEMP EMP INNER JOIN AD_METEMPVENDDIA VEN ON (VEN.IDMETEMP = EMP.IDMETEMP AND VEN.ID=EMP.ID) 
                         WHERE EMP.ID = FIELD_ID 
                           AND EMP.CODEMP = EMPORIG) 
            LOOP
                
                INSERT INTO AD_METEMPVENDDIA (ID, IDMETEMP, IDGRUEMPVEN, CODGRUPOPROD, CODEMP, CODVEND, DATA, VLR, PESO, T) VALUES
                (FIELD_ID, IVEND.PIDMETEMP, IVEND.IDGRUEMPVEN, IVEND.GRUPO, IVEND.CODEMP, IVEND.CODVEND, IVEND.DATA, VLREMP - ((VLREMP / 100) * IVEND.T), IVEND.PESO, IVEND.T) ;
                VLR := VLREMP - ((VLREMP / 100) * IVEND.T) ;
            END LOOP;       
        END IF;
    END LOOP;

    P_MENSAGEM := PMSG;

END;
/
