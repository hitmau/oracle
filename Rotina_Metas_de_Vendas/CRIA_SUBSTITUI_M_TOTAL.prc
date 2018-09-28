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
    PEMPORIG INT;
    PEMPDEST INT;
    PEMPVLRDEST FLOAT;
    PEMPVLRORIG FLOAT;
    PNOMEEMP VARCHAR(100);
BEGIN
    --Parametros
--        OPCAOC := ACT_INT_PARAM(P_IDSESSAO,'OPCAOC');    --Copia Grupos anteriores C = copiar
--        OPCAOR := ACT_TXT_PARAM(P_IDSESSAO,'OPCAOR');    --Recalcula Grupos R = recalcular
        EMPORIG := ACT_INT_PARAM(P_IDSESSAO,'EMPORIG');   --Insere vendedores por Gerente
        EMPDEST := ACT_INT_PARAM(P_IDSESSAO,'EMPDEST');   --ou Insere vendedores por Grupo
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
       IF EMPORIG IS NULL OR EMPDEST IS NULL THEN
RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#000000">
Campo Empresa oritem ou Empresa destino em branco.</font></b><br><font>');
       ELSE
            SELECT NVL(A.META,0), (SELECT NOMEFANTASIA FROM TSIEMP WHERE CODEMP = EMPORIG) AS NOMEEMP
            INTO PEMPVLRORIG, PNOMEEMP
            FROM AD_GRUMETEMP A 
            WHERE A.ID = FIELD_ID
              AND A.CODEMP = EMPORIG;

                IF PEMPVLRORIG = 0 THEN
RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#000000">
Primeiro insira o valor desejado no campo Meta da Empresa '|| to_char(EMPORIG) ||' - ' || TO_CHAR(PNOMEEMP) || '.</font></b><br><font>');
                END IF;

            SELECT NVL(A.META,0), (SELECT NOMEFANTASIA FROM TSIEMP WHERE CODEMP = EMPDEST) AS NOMEEMP
            INTO PEMPVLRDEST, PNOMEEMP
            FROM AD_GRUMETEMP A 
            WHERE A.ID = FIELD_ID
              AND A.CODEMP = EMPDEST;
            
                IF PEMPVLRDEST = 0 THEN
RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#000000">
Primeiro insira o valor desejado no campo Meta da Empresa '|| to_char(EMPDEST) ||' - ' || TO_CHAR(PNOMEEMP) || '.</font></b><br><font>');
                END IF;
                
                IF EMPORIG = EMPDEST THEN
RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#000000">
O campo Origem está igual ao campo Destino!</font></b><br><font>');
                END IF;
        END IF;
    END LOOP;

    P_MENSAGEM := PMSG;

END;
/