DROP TRIGGER TOTALPRD.TRG_INC_TGFITE_LOCAL_F_TOTAL;

CREATE OR REPLACE TRIGGER TOTALPRD.TRG_INC_TGFITE_LOCAL_F_TOTAL 
   BEFORE INSERT OR UPDATE   
   ON TOTALPRD.TGFITE FOR EACH ROW
DECLARE
   PCODLOCAL     INT;
   PCODLOCALPROD INT;
   PCODTIPOPER   INT;
   PCODEMP       INT;
   PCODEMPEST    INT;
   PUSOPROD      VARCHAR (1);
   PCODTIPVENDA  INT;
   PCODUSU          INT;
   PCONT         INT;
   P_COUNT       INT;
   PCODPRODEST   INT;
   PCONTEST      INT;
   PGRUPO         INT;
   PCODVOLCOMPRA VARCHAR(2);
   PSEQ          INT;
   PCOUNT        INT;
   PQTDNEG       NUMBER;
   PNUNOTA       INT;
   PVALOR        NUMBER;
   PMOTIVO       VARCHAR(1);
   PCODPARC      INT;
   PCODTIPPARC   INT;
   PPRECO        VARCHAR(50);
   PPARCPROD     INT;
   PPARCFORN     INT;
   PNOMEPARC     VARCHAR(50);
   PNOMEPARCPROD VARCHAR(50);
   PNOMEPROD     INT;
   PCODPARCPROD  INT;
   VCODPRODPARC  INT;
   PDATANOTA    DATE;
   PSTATUSNOTA  VARCHAR(1);
   pcodlocalEXPRESS INT;
   PCODPRODS INT;
   PINSEREFORDIF INT;
BEGIN
   /*
   AUTOR: Mauricio Rodrigues
   DESCRIÇÃO: Atualizar Local conforme cadastro da Empresa.
   OBJETIVO:
   1- Todos os itens da nota, inclusive os insumos (que só estava fazendo manualmente), tenha seu local atualizado automaticamente.
   2- Ao duplicar nota de venda em um pedido de compra, mudando a empresa para Cabo Frio, atualizar os itens.
   OBSERVAÇÃO: Não pode utilizar o PRAGMA nessa condição, pois senão o tópico 2 não irá funcionar, uma vez que mudo a empresa na CAB e ele atualiza o ITE novamente.
   ATUALIZAÇÃO 12/09/2017: Mauricio Rodrigues
   1 - Inclusão de TOPs 1422, 1423 transferencia rio entre estoques rma e laboratório
   2 - Inclusão de TOPs 1433, 1434 transferencia CF entre estoques rma e laboratório
   3 - Bloqueio na devolução TOPs 2200 e 2201 para não alterar quandidade de produtos maior que o da nota venda origem.
   4 - Nas transferencias é gerado aviso caso o produto não tenha no estoque referente a top selecionada.
   ATUALIZAÇÃO 09/11/2017: Mauricio Rodrigues
   1 - Criado nova top (1405) de transferencia do rma para saldo (produtos reparados e aptos para venda)
   
   ATUALIZAÇÃO: BLOQUEIA ENVIO PARA FORNECEDOR COM PRODUTOS QUE NÃO SÃO DO MESMO (A pedido do Sr. Julio)
   AUTOR: Mauricio Rodrigues
   Data: 13/12/2017
   */
SELECT STP_GET_CODUSULOGADO() INTO PCODUSU FROM DUAL;
SELECT COUNT(1) INTO PCONT FROM TSIUSU WHERE CODUSU = PCODUSU AND NVL(AD_ALTVLRDEV,'N') = 'S';
SELECT COUNT(1) INTO PINSEREFORDIF FROM TSIUSU WHERE CODUSU = PCODUSU AND NVL(AD_INSEREFORDIF,'N') = 'S';

   SELECT EMP.LOCALPAD, CAB.CODTIPOPER, CAB.CODEMP, CAB.CODTIPVENDA, CAB.CODPARC
     INTO PCODLOCAL, PCODTIPOPER, PCODEMP, PCODTIPVENDA, PCODPARC
     FROM TGFEMP EMP INNER JOIN TGFCAB CAB ON EMP.CODEMP = CAB.CODEMP AND CAB.NUNOTA = :NEW.NUNOTA;
        
   SELECT CAB.AD_MOTDEVOLUCAO, CAB.DTFATUR
     INTO PMOTIVO, PDATANOTA
     FROM TGFCAB CAB WHERE NUNOTA = :NEW.NUNOTA;

   SELECT PRO.USOPROD INTO PUSOPROD FROM TGFPRO PRO WHERE PRO.CODPROD = :NEW.CODPROD;
    
   SELECT PROD.CODGRUPOPROD
      INTO PGRUPO
      FROM TGFPRO PROD
      WHERE PROD.CODPROD = :NEW.CODPROD; 



--SELECT * FROM TGFVAR WHERE NUNOTA = 85058
--SELECT * FROM TGFCAB WHERE NUNOTA = 80474
    --Aqui não entra transferencia     
   IF PCODTIPOPER NOT IN (1100,3103,3104,3200,3010, 1000, 1005,1401,1101, 1400,1410, 1420, 1423, 1425, 1403, 1411, 1433, 2104, 2200
   , 2201, 2202, 2204, 2205, 2222, 2223, 3202, 3204, 3205, 3213, 3216, 3214, 3000, 3212, 3005, 3006, 3007, 2209, 3218, 3207, 3244, 3211) THEN
      IF PUSOPROD <> 'S' THEN
         :NEW.CODLOCALORIG := PCODLOCAL;
      END IF;
   END IF;
--IF PCODTIPOPER IN (2002, -- PEDIDO COMPRA(TRANSFERENCIA)
--                   2106, -- COMPRA CABOFRIO (TRANSFERENCIA)
--                   2105, -- COMPRA RIO (TRANSFERENCIA)
--                   3011, -- ORÇAMENTO DE TRANSFERENCIA - MAT E FILIAL
--                   3102, -- PEDIDO VENDA(TRANSFERENCIA)
--                   3206) THEN-- VENDA(TRANSFERENCIA) 
--      IF PUSOPROD <> 'S' THEN
--         :NEW.CODLOCALORIG := PCODLOCAL;
--      END IF;
--END IF;
   
   
   
   
   -- Regra de Local para Transferências nas TOPS específicas:-----------------------------------------------------------------------------------------------
   -- Obrigatoriamente vai para o local abaixo:
   IF INSERTING THEN
    IF :NEW.SEQUENCIA < 0 AND PCODTIPOPER IN (1400, 1410, 1411, 1425) THEN :NEW.CODLOCALORIG := 1001; END IF;
   END IF;
   IF :NEW.SEQUENCIA < 0 AND PCODTIPOPER IN (1403) THEN :NEW.CODLOCALORIG := 1003; END IF;

   
   --IF :NEW.SEQUENCIA < 0 AND PCODTIPOPER IN (1425) THEN :NEW.CODLOCALORIG := 3005; END IF;
   --LAB - RMA (CABO FRIO)-------------------------------------------------------------------
   --IF :NEW.SEQUENCIA < 0 AND PCODTIPOPER IN (1433) THEN :NEW.CODLOCALORIG := 2001; END IF;
   IF :NEW.SEQUENCIA < 0 AND PCODTIPOPER IN (1434) THEN :NEW.CODLOCALORIG := 2002; END IF;
   --LAB - RMA (RJ)--------------------------------------------------------------------------
   IF :NEW.SEQUENCIA < 0 AND PCODTIPOPER IN (1405) THEN :NEW.CODLOCALORIG := 1005; END IF;
   --IF :NEW.SEQUENCIA < 0 AND PCODTIPOPER IN (1422) THEN :NEW.CODLOCALORIG := 3004; END IF; --Transfere (RMA Lab. -> Descarte) FOI LIBERADA PARA TODO O RMA
   --IF :NEW.SEQUENCIA < 0 AND PCODTIPOPER IN (1423) THEN :NEW.CODLOCALORIG := 1002; END IF;
   IF :NEW.SEQUENCIA < 0 AND PCODTIPOPER IN (1498) THEN :NEW.CODLOCALORIG := 1098; END IF;
   IF :NEW.SEQUENCIA < 0 AND PCODTIPOPER IN (1499,1497) THEN :NEW.CODLOCALORIG := 1099; END IF;

   -- Obrigatoriamente sai do local abaixo:---------------------------------
   IF :NEW.SEQUENCIA > 0 THEN
       IF INSERTING THEN --As TOP abaixo forçam o local apenas na inserção pois é possível alterar.
            IF PCODTIPOPER IN (1400, 1405) THEN :NEW.CODLOCALORIG := 3001; END IF;
            IF PCODTIPOPER = 1425 THEN :NEW.CODLOCALORIG := 1001; END IF;
       END IF;
       IF PCODTIPOPER = 1410 THEN :NEW.CODLOCALORIG := 1003; END IF;
       IF PCODTIPOPER = 1411 THEN :NEW.CODLOCALORIG := 1011; END IF;
       IF PCODTIPOPER = 1403 THEN :NEW.CODLOCALORIG := 1001; END IF;
       --LAB - RMA (CABO FRIO)----------------------------------------------
       --IF PCODTIPOPER = 1433 THEN :NEW.CODLOCALORIG := 2002; END IF;
       IF PCODTIPOPER = 1434 THEN :NEW.CODLOCALORIG := 2001; END IF;
       --LAB - RMA (RJ)-----------------------------------------------------
       --IF PCODTIPOPER = 1422 THEN :NEW.CODLOCALORIG := 3006; END IF; --1422 - Transfere (RMA Lab. -> Descarte)FOI LIBERADO PARA TODO O RMA
       IF PCODTIPOPER = 1497 THEN :NEW.CODLOCALORIG := 1098; END IF;
       IF PCODTIPOPER IN (1498,1499) THEN :NEW.CODLOCALORIG := 1020; END IF;
   END IF; 
--Testa estoque e informa caso não tenha (RMA - Principal)----------------------------------------------------------------------------------------------------
    --1400 envia para Principal
    --1422 envia para Laboratório
IF (INSERTING) AND (PCODTIPOPER IN (1400)) THEN
        SELECT COUNT(1)
        INTO PCONTEST
        FROM TGFEST EST
        WHERE EST.CODPROD = :NEW.CODPROD AND EST.CODEMP = PCODEMP AND EST.CODLOCAL in (3001, 4001);
    IF PCONTEST = 0 THEN 
        RAISE_APPLICATION_ERROR(-20101, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
        O produto ' || TO_CHAR(:NEW.CODPROD) || ' não tem quantidade no estoque do RMA.<br>Favor Verificar!</font></b><br><font>');
    ELSE
    
            IF :NEW.CODVOL = 'MT' THEN
                SELECT MAX(EST.ESTOQUE * 10)
                INTO PCONTEST 
                FROM TGFEST EST
                WHERE EST.CODPROD = :NEW.CODPROD AND EST.CODEMP = PCODEMP AND EST.CODLOCAL in (3001, 4001) and est.CODPARC = 0;
            ELSE
                SELECT MAX(EST.ESTOQUE)
                INTO PCONTEST 
                FROM TGFEST EST
                WHERE EST.CODPROD = :NEW.CODPROD AND EST.CODEMP = PCODEMP AND EST.CODLOCAL in (3001,4001) and est.CODPARC = 0;
            END IF;
            
                IF :NEW.QTDNEG > PCONTEST THEN
                    RAISE_APPLICATION_ERROR(-20101, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
                    O produto ' || TO_CHAR(:NEW.CODPROD) || ' tem quantidade no estoque do RMA igual a (' || TO_CHAR(PCONTEST) || '), informe quantidade menor.<br>Favor Verificar!</font></b><br><font>');
                END IF;
    END IF;
END IF;
--Verifica se no estoque existe produto.
IF (INSERTING) AND (PCODTIPOPER IN (3214)) THEN
        SELECT COUNT(1)
        INTO PCONTEST
        FROM TGFEST EST
        WHERE EST.CODPROD = :NEW.CODPROD AND EST.CODEMP = PCODEMP AND EST.CODLOCAL in (3003, 3002);
    IF PCONTEST = 0 THEN 
        RAISE_APPLICATION_ERROR(-20101, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
        O produto ' || TO_CHAR(:NEW.CODPROD) || ' não tem quantidade no estoque do RMA.<br>Favor Verificar!</font></b><br><font>');
    ELSE
    
            IF :NEW.CODVOL = 'MT' THEN
                SELECT (EST.ESTOQUE * 10)
                INTO PCONTEST 
                FROM TGFEST EST
                WHERE EST.CODPROD = :NEW.CODPROD AND EST.CODEMP = PCODEMP AND EST.CODLOCAL in (3003, 3002) and est.CODPARC = 0;
            ELSE
                SELECT EST.ESTOQUE
                INTO PCONTEST 
                FROM TGFEST EST
                WHERE EST.CODPROD = :NEW.CODPROD AND EST.CODEMP = PCODEMP AND EST.CODLOCAL in (3003, 3002) and est.CODPARC = 0;
            END IF;
            
                IF :NEW.QTDNEG > PCONTEST THEN
                    RAISE_APPLICATION_ERROR(-20101, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
                    O produto ' || TO_CHAR(:NEW.CODPROD) || ' tem quantidade no estoque do RMA igual a (' || TO_CHAR(PCONTEST) || '), informe quantidade menor.<br>Favor Verificar!</font></b><br><font>');
                END IF;
    END IF;
END IF;
--Verifica se no estoque existe produto.
IF (INSERTING) AND (PCODTIPOPER IN (3204, 3202)) THEN
        SELECT COUNT(1)
        INTO PCONTEST
        FROM TGFEST EST
        WHERE EST.CODPROD = :NEW.CODPROD AND EST.CODEMP = PCODEMP AND EST.CODLOCAL in (3002, 3005, 3006);
    IF PCONTEST = 0 THEN 
        RAISE_APPLICATION_ERROR(-20101, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
        O produto ' || TO_CHAR(:NEW.CODPROD) || ' não tem quantidade no estoque do RMA DOA nem no RMA Garantia.<br>Favor Verificar!</font></b><br><font>');
    ELSE
    
            IF :NEW.CODVOL = 'MT' THEN
                SELECT (EST.ESTOQUE * 10)
                INTO PCONTEST 
                FROM TGFEST EST
                WHERE EST.CODPROD = :NEW.CODPROD AND EST.CODEMP = PCODEMP AND EST.CODLOCAL in (3002, 3005, 3006) and est.CODPARC = 0;
            ELSE
                SELECT EST.ESTOQUE
                INTO PCONTEST 
                FROM TGFEST EST
                WHERE EST.CODPROD = :NEW.CODPROD AND EST.CODEMP = PCODEMP AND EST.CODLOCAL in (3002, 3005, 3006) and est.CODPARC = 0;
            END IF;
            
                IF :NEW.QTDNEG > PCONTEST THEN
                    RAISE_APPLICATION_ERROR(-20101, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#000000">
O produto ' || TO_CHAR(:NEW.CODPROD) || ' tem quantidade igual a (' || TO_CHAR(PCONTEST) || '), nos estoque RMA DOA ou RMA Garantia, informe quantidade menor.</font></b><br><font>');
                END IF;
    END IF;
END IF;
--Testa estoque e informa caso não tenha (RMA - Principal)
    --1400 envia para Principal
--IF (INSERTING) AND (PCODTIPOPER IN (1423)) THEN --TRANSFERÊNCIA ENTRE LOC (PARA RMA) - TOP DESATIVADA EM 08/01/2017
--    SELECT COUNT(1)
--        INTO PCONTEST
--        FROM TGFEST EST
--        WHERE EST.CODPROD = :NEW.CODPROD AND EST.CODEMP IN (1, 4) AND EST.CODLOCAL = 1020;
--    IF (PCONTEST <= 0) THEN
--        RAISE_APPLICATION_ERROR(-20101, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
--        O produto ' || TO_CHAR(:NEW.CODPROD) || ' não tem quantidade no estoque do Laboratório para ser transferido.<br>Favor Verificar!</font></b><br><font>');
--    ELSE
--            SELECT EST.ESTOQUE
--            INTO PCONTEST
--            FROM TGFEST EST
--            WHERE EST.CODPROD = :NEW.CODPROD AND EST.CODEMP IN (1, 4) AND EST.CODLOCAL = 1020 and est.CODPARC = 0;
--            
--        IF :NEW.QTDNEG > PCONTEST THEN
--            RAISE_APPLICATION_ERROR(-20101, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
--            O produto ' || TO_CHAR(:NEW.CODPROD) || ' tem quantidade no estoque do Laboratório igual a (' || TO_CHAR(PCONTEST) || '), informe quantidade menor.<br>Favor Verificar!</font></b><br><font>');
--        END IF;
--    END IF;
--END IF;


--Testa estoque e informa caso não tenha (Principal CF - RMA CF)
--Testa estoque e informa caso não tenha (Principal CF - RMA CF)
--IF (INSERTING) AND (PCODTIPOPER = 1433) THEN -- TRANSFERÊNCIA ENTRE LOC (RMA P PRINC)  - TOP DESATIVADA EM 09/01/2017
--    SELECT COUNT(1)
--        INTO PCONTEST
--        FROM TGFEST EST
--        WHERE EST.CODPROD = :NEW.CODPROD AND EST.CODEMP = 6 AND EST.CODLOCAL = 2002;
--    IF (PCONTEST <= 0) THEN
--        RAISE_APPLICATION_ERROR(-20101, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
--        O produto ' || TO_CHAR(:NEW.CODPROD) || ' não tem quantidade no estoque RMA (CF) para ser transferido.<br>Favor Verificar!</font></b><br><font>');
--    ELSE
--        SELECT EST.ESTOQUE
--        INTO PCONTEST
--        FROM TGFEST EST
--        WHERE EST.CODPROD = :NEW.CODPROD AND EST.CODEMP = 6 AND EST.CODLOCAL = 2002 and est.CODPARC = 0;
--        IF :NEW.QTDNEG > PCONTEST THEN
--            RAISE_APPLICATION_ERROR(-20101, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
--            O produto ' || TO_CHAR(:NEW.CODPROD) || ' tem quantidade no estoque do RMA (cf) igual a (' || TO_CHAR(PCONTEST) || '), informe quantidade menor.<br>Favor Verificar!</font></b><br><font>');
--        END IF;
--    END IF;
--END IF;
--Testa estoque e informa caso não tenha (Principal CF - RMA CF)
IF (INSERTING) AND (PCODTIPOPER = 1434) THEN -- TRANSF. ENTRE LOC -C PRIN PARA RMA (CF) - TOP DESATIVADA EM 09/01/2017
    SELECT COUNT(1)
        INTO PCONTEST
        FROM TGFEST EST
        WHERE EST.CODPROD = :NEW.CODPROD AND EST.CODEMP = 6 AND EST.CODLOCAL = 3001;
    IF (PCONTEST <= 0) THEN
        RAISE_APPLICATION_ERROR(-20101, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
        O produto ' || TO_CHAR(:NEW.CODPROD) || ' não tem quantidade no estoque Laboratório (CF) para ser transferido.<br>Favor Verificar!</font></b><br><font>');
    ELSE
        SELECT EST.ESTOQUE
        INTO PCONTEST
        FROM TGFEST EST
        WHERE EST.CODPROD = :NEW.CODPROD AND EST.CODEMP = 6 AND EST.CODLOCAL = 3001 and est.CODPARC = 0;
        IF :NEW.QTDNEG > PCONTEST THEN
            RAISE_APPLICATION_ERROR(-20101, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
            O produto ' || TO_CHAR(:NEW.CODPROD) || ' tem quantidade no estoque do Laboratório (CF) igual a (' || TO_CHAR(PCONTEST) || '), informe quantidade menor.<br>Favor Verificar!</font></b><br><font>');
        END IF;
    END IF;
END IF;
--Testa estoque e informa caso não tenha (11 - Principal)
IF (INSERTING) AND (PCODTIPOPER = 1411) THEN
    SELECT COUNT(1)
        INTO PCONTEST
        FROM TGFEST EST
        WHERE EST.CODPROD = :NEW.CODPROD AND EST.CODEMP = 4 AND EST.CODLOCAL = 1011;
    IF (PCONTEST <= 0) THEN
        RAISE_APPLICATION_ERROR(-20101, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
        O produto ' || TO_CHAR(:NEW.CODPROD) || ' não tem quantidade no estoque do 11 para ser transferido.<br>Favor Verificar!</font></b><br><font>');
    ELSE
        SELECT EST.ESTOQUE
        INTO PCONTEST
        FROM TGFEST EST
        WHERE EST.CODPROD = :NEW.CODPROD AND EST.CODEMP = 4 AND EST.CODLOCAL = 1011 and est.CODPARC = 0;
        IF :NEW.QTDNEG > PCONTEST  THEN
            RAISE_APPLICATION_ERROR(-20101, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
            O produto ' || TO_CHAR(:NEW.CODPROD) || ' tem quantidade no estoque do 11 igual a (' || TO_CHAR(PCONTEST) || '), informe quantidade menor.<br>Favor Verificar!</font></b><br><font>');
        END IF;
    END IF;
END IF;
--Testa estoque e informa caso não tenha (ShowRoon - Principal)
IF (INSERTING) AND (PCODTIPOPER = 1410) THEN
    SELECT COUNT(1)
        INTO PCONTEST
        FROM TGFEST EST
        WHERE EST.CODPROD = :NEW.CODPROD AND EST.CODEMP = 4 AND EST.CODLOCAL = 1003;
    IF (PCONTEST <= 0) THEN
        RAISE_APPLICATION_ERROR(-20101, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
        O produto ' || TO_CHAR(:NEW.CODPROD) || ' não tem quantidade no estoque do Show Roon para ser transferido.<br>Favor Verificar!</font></b><br><font>');
    ELSE
        SELECT EST.ESTOQUE
        INTO PCONTEST
        FROM TGFEST EST
        WHERE EST.CODPROD = :NEW.CODPROD AND EST.CODEMP = 4 AND EST.CODLOCAL = 1003 and est.CODPARC = 0;
        IF :NEW.QTDNEG > PCONTEST THEN
            RAISE_APPLICATION_ERROR(-20101, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
            O produto ' || TO_CHAR(:NEW.CODPROD) || ' tem quantidade no estoque do Show Roon igual a (' || TO_CHAR(PCONTEST) || '), informe quantidade menor.<br>Favor Verificar!</font></b><br><font>');
        END IF;
    END IF;
END IF;
--Fim dos bloqueios de quantidade em estoque ()----------------------------------------------------------------------------------------------------

--BLOQUEIA ALTERAÇÃO NÓS VALORES DOS ITENS ()------------------------------------------------------------------------------------------------------
IF (PCONT = 0) AND (PCODTIPOPER IN (2200, 2201, 2209, 2299)) THEN
    IF (:OLD.QTDNEG < :NEW.QTDNEG) THEN
RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
O usuário logado não tem permissão para Alterar a quantidade dos produtos para mais!    
   </font></b><br><font>');
    END IF;

END IF;

IF (PCONT = 0) AND (PCODTIPOPER IN (2200, 2201, 2209, 2299)) THEN
    IF (:OLD.VLRUNIT <> :NEW.VLRUNIT) THEN
        
    RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
O usuário logado não tem permissão para Alterar o preço do produto!    
   </font></b><br><font>');

   END IF;
END IF;
   --DEVOLUÇÃO RIO, E CABO FRIO = 3214 - TROCA EXPRESSO, 3204 - REMESSA CONSERTO/DOA-----------------------------------------------------
   
-- IF PCODTIPOPER IN (2200, 2201, 2205) THEN
--    IF PUSOPROD <> 'S' THEN
--        IF PMOTIVO <> 'v' THEN --Motivo da devolução é Compra ou Venda errada
--            :NEW.CODLOCALORIG := 3001; --Estoque RMA Principal
--        END IF;
--        IF PMOTIVO = 'v' THEN -----------Estoque RMA DOA ou Expresso
--            FOR CUR_CUS IN (SELECT ITE.CODPROD, PROD.AD_TIPOTROCA FROM TGFITE ITE, TGFPRO PROD WHERE PROD.CODPROD=ITE.CODPROD AND ITE.NUNOTA = :NEW.NUNOTA ORDER BY 1)
--            LOOP
--                IF (CUR_CUS.AD_TIPOTROCA = 1) AND (:NEW.CODLOCALORIG <> 3002) THEN --DOA
--                    :NEW.CODLOCALORIG := 3002; 
--                END IF;
--                IF (CUR_CUS.AD_TIPOTROCA = 2)  AND (:NEW.CODLOCALORIG <> 3003)THEN --EXPRESSO
--                    :NEW.CODLOCALORIG := 3003; 
--                END IF; 
--                IF (CUR_CUS.AD_TIPOTROCA = 3) THEN --Sem Troca
--                    RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
--                    Produto: ' || TO_CHAR(CUR_CUS.CODPROD) || ' não pode ser trocado.<br>Entre em contato com o responsável pelo cadastro do produto.</font></b><br><font>');
--                END IF;
--            END LOOP;
--        END IF;
--        IF (PCODTIPVENDA <> 5) AND (PCODTIPOPER IN (2200, 2201)) THEN
--                    UPDATE TGFCAB C SET C.VLRFRETE = 0,C.CODTIPVENDA = 5, C.DHTIPVENDA = (SELECT MAX(DHALTER) FROM TGFTPV TPV WHERE TPV.CODTIPVENDA = 5)
--                    WHERE C.NUNOTA = :NEW.NUNOTA;
--                    DELETE FROM TGFFIN FIN WHERE FIN.NUNOTA = :NEW.NUNOTA; 
--        END IF;
--    END IF;
--END IF;  
IF PCODTIPOPER IN (2207) THEN --ESTOQUE GARANTIA
 SELECT COUNT(1) 
 INTO P_COUNT
 FROM TGFCAB CAB INNER JOIN TGFVAR VAR ON (CAB.NUNOTA = VAR.NUNOTAORIG) 
 WHERE SYSDATE - CAB.DTNEG > 15
 AND VAR.NUNOTA = :NEW.NUNOTA;
        IF PUSOPROD <> 'S' THEN  
            IF P_COUNT = 0 THEN
                :NEW.CODLOCALORIG := 3005;
            ELSE
RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
Nota de origem tem menos de 15 dias.</font></b><br><font>');
                                    
            END IF;               
        END IF;
END IF;

    IF PCODTIPOPER IN (2200, 2201, 2205, 3218, 2209, 2299) THEN
        IF PUSOPROD <> 'S' THEN
    IF INSERTING THEN
    --INSERT INTO AD_PRODDTENT (ID, NUNOTA, CODPROD, DTENTRADA, QTDNEG, CODLOCAL, CODEMP) VALUES ((SELECT MAX(ID)+1 FROM AD_PRODDTENT),:NEW.NUNOTA, :NEW.CODPROD, PDATANOTA, :NEW.QTDNEG, :NEW.CODLOCALORIG, PCODEMP);
                --:NEW.CODLOCALORIG := 1002;
                IF (PMOTIVO is null) THEN
                    :NEW.CODLOCALORIG := 3001;
                END IF;

                IF (PMOTIVO = 'c') OR (PMOTIVO = 'e') THEN --Motivo da devolução é Compra ou Venda errada
                    IF :NEW.CODLOCALORIG <> 3001 THEN --Verifico nocamente para não realizar update desnecessário
                        :NEW.CODLOCALORIG := 3001; --Estoque RMA Principal
                    END IF; 
                END IF;
                --Verifica se o campo está marcado como Defeito = (v).
                IF PMOTIVO = 'v' THEN -----------Estoque RMA DOA ou Expresso
    --                FOR CUR_CUS IN (SELECT ITE.CODPROD
    --                                     , PROD.AD_TIPOTROCA 
    --                                FROM TGFITE ITE
    --                                   , TGFPRO PROD 
    --                                WHERE PROD.CODPROD=ITE.CODPROD 
    --                                  AND ITE.NUNOTA = :new.nunota 
    --                                ORDER BY 1)
    --                
                                    SELECT PROD.AD_TIPOTROCA
                                    INTO pcodlocalEXPRESS
                                    FROM TGFPRO PROD 
                                    WHERE PROD.CODPROD = :NEW.CODPROD;

                        IF (pcodlocalEXPRESS = 1) AND (:NEW.CODLOCALORIG <> 3002) THEN --DOA
                            :NEW.CODLOCALORIG := 3002;
                        END IF;
                        IF (pcodlocalEXPRESS = 2)  AND (:NEW.CODLOCALORIG <> 3003)THEN --EXPRESSO
                            :NEW.CODLOCALORIG := 3003;
                        END IF; 
                        IF (pcodlocalEXPRESS = 3) THEN --Sem Troca
                            RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
Produto: ' || TO_CHAR(:NEW.CODPROD) || ' não pode ser trocado.<br>Entre em contato com o responsável pelo cadastro do produto.</font></b><br><font>');
                        END IF;
    --                END LOOP;
                END IF;
                
                /*Trigger alterada por Samuel Levy em 16/08/2018 para que a devolução possa ter o mesmo tipo de negociação da venda
                 *gerando o calculo correto de comissão para estorno da mesma no agenciamento.*/
                
                    IF /*(PCODTIPVENDA <> 5) AND */ PCODTIPOPER IN (2200, 2201) THEN
                        UPDATE TGFCAB C SET C.VLRFRETE = 0 /*,C.CODTIPVENDA = 5, C.DHTIPVENDA = (SELECT MAX(DHALTER) FROM TGFTPV TPV WHERE TPV.CODTIPVENDA = 5)*/
                        WHERE C.NUNOTA = :NEW.NUNOTA;
                        DELETE FROM TGFFIN FIN WHERE FIN.NUNOTA = :NEW.NUNOTA; 
                    END IF;
               /*Fim da alteração feita em 16/08/2018*/
            END IF;
        END IF;
END IF;
--devolução de mercadoria do fornecedor    
IF INSERTING THEN
    IF (PCODTIPOPER IN (2204, -- OUTRA ENTRADA NÃO ESPECIFICADA (ENT) ----(doa)
                        2202  -- RETORNO FORNECEDOR CONSERTO (ENT) ----(doa)
                        )) THEN 
        :NEW.CODLOCALORIG := 3001;
        --INSERT INTO AD_PRODDTENT (ID, NUNOTA, CODPROD, DTENTRADA, QTDNEG, CODLOCAL, CODEMP) VALUES ((SELECT MAX(ID)+1 FROM AD_PRODDTENT),:NEW.NUNOTA, :NEW.CODPROD, PDATANOTA, :NEW.QTDNEG, :NEW.CODLOCALORIG, PCODEMP);
    END IF;
END IF;
--saida de mercadoria para doa (fornecedor)
IF INSERTING THEN
    IF (PCODTIPOPER IN (3202, -- REMESSA P CONSERT. OU REPARO ----(doa)
                        3204 -- REMESSA P TROCA EM GARANTIA ----(doa)
                        )) THEN
                            
                    
        FOR CURSOR IN (SELECT EST.CODPROD, EST.CODLOCAL, EST.CODEMP
                        FROM TGFEST EST 
                        WHERE EST.CODPROD = :NEW.CODPROD AND EST.CODEMP = PCODEMP)
        LOOP
--RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
--AGUARDE 1 MINUTO E TENTE NOVAMENTE. ' || TO_CHAR(PCODLOCALPROD) || ' - ' || TO_CHAR(:NEW.CODLOCALORIG) || ' - ' || TO_CHAR(CURSOR.CODEMP || '-' || PCODEMP) || '</font></b><br><font>');
                IF (CURSOR.CODLOCAL = 3002) AND (CURSOR.CODEMP = PCODEMP) THEN --DOA
                    :NEW.CODLOCALORIG := 3002;
                     
                END IF;
                IF (CURSOR.CODLOCAL = 3005) AND (CURSOR.CODEMP = PCODEMP) THEN --GARANTIA
                    :NEW.CODLOCALORIG := 3005;
                END IF; 
        END LOOP;               
    END IF;
END IF;
--saida de mercadoria expresso (fornecedor)
    IF (INSERTING) AND (PUSOPROD <> 'S') AND (PCODTIPOPER IN (3214 -- REM MERC P/ CONSERTO - EXPRESSO (SAIDA) 
                                              )) THEN 
                    :NEW.CODLOCALORIG := 3003;
    END IF;
--END IF;
--DEVOLUÇÃO DE MERCADORIA COM CRÉDITO PARA ESTOQUE PRINCIPAL (elaine)
    
    IF (PUSOPROD <> 'S') AND (PCODTIPOPER IN (2211)) THEN 
--            IF PCODEMP IN (4, 1) THEN
--                :NEW.CODLOCALORIG := 1001;
--            ELSE
--                :NEW.CODLOCALORIG := 2001;
--            END IF;
            IF (PCODTIPVENDA <> 5) THEN
                    UPDATE TGFCAB C SET C.VLRFRETE = 0, C.CODTIPVENDA = 5, C.DHTIPVENDA = (SELECT MAX(DHALTER) FROM TGFTPV TPV WHERE TPV.CODTIPVENDA = 5)
                    WHERE C.NUNOTA = :NEW.NUNOTA;
                    DELETE FROM TGFFIN FIN WHERE FIN.NUNOTA = :NEW.NUNOTA; 
            END IF;
    END IF;
 
    --TOPS LABORATÓRIO RMA, 
IF INSERTING THEN
    IF (PUSOPROD <> 'S') AND (PCODTIPOPER IN (3211, 3212, 3213, 2207)) THEN
                :NEW.CODLOCALORIG := 3006;
    END IF;
END IF;

IF INSERTING THEN
    IF (PUSOPROD <> 'S') AND (PCODTIPOPER IN (3216)) THEN
                :NEW.CODLOCALORIG := 3005;
    END IF;
END IF;
    
    -- adicionado por daniel em 06/10/2017
    -- objetivo validar a unidade de compra
    
    SELECT CODVOLCOMPRA 
    INTO PCODVOLCOMPRA 
    FROM TGFPRO 
    WHERE CODPROD = :NEW.CODPROD;
 /*   
    IF PCODTIPOPER IN (2100,2101,2900,2104,2103,2222,2000,2001,2003) THEN
        IF :NEW.CODVOL <> PCODVOLCOMPRA THEN
            RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
            A unidade de compra desse item é diferente do cadastro! Verifique!    
            </font></b><br><font>');
        END IF;
    END IF;
   */ 
    -- objetivo incluir os componentes na hora da compra
 IF (INSERTING) THEN
    
    IF PCODTIPOPER IN (2000, 2104) THEN
    
        SELECT COUNT(*) INTO PCOUNT FROM TGFICP WHERE CODPROD = :NEW.CODPROD;
        
        IF PCOUNT > 0 THEN
        
        SELECT NVL(MAX(SEQUENCIA)+2, 2) INTO PSEQ FROM TGFITE WHERE NUNOTA = :NEW.NUNOTA;
        PNUNOTA := :NEW.NUNOTA;
        
            FOR CUR_PRO IN (SELECT CODMATPRIMA, QTDMISTURA, CODVOL FROM TGFICP WHERE CODPROD = :NEW.CODPROD )
                LOOP
                
                    --select max(1)+1 into pseq from tgfite where nunota = :new.nunota;
                    SELECT NVL(SUM(QTDNEG),0) INTO PQTDNEG FROM TGFITE WHERE NUNOTA = :NEW.NUNOTA AND CODPROD = CUR_PRO.CODMATPRIMA;
                    
                    IF PQTDNEG > 0 THEN
                    
                        PQTDNEG := PQTDNEG + (:NEW.QTDNEG * CUR_PRO.QTDMISTURA);
                        
                        UPDATE TGFITE SET QTDNEG = PQTDNEG WHERE NUNOTA = :NEW.NUNOTA AND CODPROD = CUR_PRO.CODMATPRIMA; 
                    
                    ELSE
   
                        PQTDNEG := :NEW.QTDNEG * CUR_PRO.QTDMISTURA;
                        
                        --pvalor := replace(snk_preco(0, cur_pro.codmatprima), 0,1);
                        PVALOR := 0;
                        
                        INSERT INTO TGFITE (NUNOTA, SEQUENCIA, CODEMP, CODPROD, CODLOCALORIG, USOPROD, CODCFO, QTDNEG, VLRUNIT, VLRTOT, VLRCUS, CODVOL, ATUALESTOQUE, DTALTER, QTDVOL )
                        VALUES (PNUNOTA ,PSEQ, PCODEMP, CUR_PRO.CODMATPRIMA, 1001, 'M', 0 , PQTDNEG , PVALOR,PVALOR*PQTDNEG, PVALOR, CUR_PRO.CODVOL, 0, SYSDATE, PQTDNEG);
                                                                                        --1102
                    
                    END IF;
                    
                    
                    PSEQ := PSEQ+1;
                    
            END LOOP;
            
        END IF;
    
    END IF;
 END IF;  
 
  --BLOQUEIA ENVIO PARA FORNECEDOR COM PRODUTOS QUE NÃO SÃO DO MESMO
  
    IF (INSERTING) THEN
        IF PCODTIPOPER IN (3202, 3204, 3244) THEN
            SELECT PROD.CODPARCFORN 
            INTO PPARCPROD
            FROM TGFPRO PROD
            WHERE PROD.CODPROD = :NEW.CODPROD;
            
            SELECT CAB.CODPARC, PARC.NOMEPARC || ' (' || UFS.UF || ')' 
            INTO PPARCFORN, PNOMEPARC
            FROM TGFCAB CAB, TGFPAR PARC INNER JOIN TSICID CID ON (PARC.CODCID=CID.CODCID) INNER JOIN TSIUFS UFS ON (CID.UF=UFS.CODUF)
            WHERE PARC.CODPARC=CAB.CODPARC AND CAB.NUNOTA = :NEW.NUNOTA;
            
        SELECT COUNT(PROD.CODPARCFORN)
                INTO VCODPRODPARC
            FROM TGFPRO PROD, TGFPAR PARC INNER JOIN TSICID CID ON (PARC.CODCID=CID.CODCID) INNER JOIN TSIUFS UFS ON (CID.UF=UFS.CODUF)
            WHERE PROD.CODPROD = :NEW.CODPROD
              AND PARC.CODPARC=PROD.CODPARCFORN;

        IF VCODPRODPARC = 0 THEN
            PPARCFORN := 0;
            PNOMEPARC := 'Produto em parceiro vinculado';
        ELSE
            SELECT PROD.CODPARCFORN, PARC.NOMEPARC || ' (' || UFS.UF || ')'
            INTO PNOMEPROD, PNOMEPARCPROD
            FROM TGFPRO PROD, TGFPAR PARC INNER JOIN TSICID CID ON (PARC.CODCID=CID.CODCID) INNER JOIN TSIUFS UFS ON (CID.UF=UFS.CODUF)
            WHERE PROD.CODPROD = :NEW.CODPROD
                AND PROD.CODPARCFORN=PARC.CODPARC;
        END IF;
            IF PINSEREFORDIF = 0 THEN
                IF PPARCPROD <> PPARCFORN THEN
RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#000000">
    Somente é possível inserir produtos do Fabricante: ' || TO_CHAR(PPARCFORN) || ' - ' || TO_CHAR(PNOMEPARC) || '<br><br><i>Verifique no Dashboard "RMA" o fabricante dos produtos! Atualmento o cadastro do produto está como: <br>' || TO_CHAR(PNOMEPROD) || ' - ' || TO_CHAR(PNOMEPARCPROD) || '.    
   </i></font></b><br><font>');
                END IF;
            END IF;
        END IF;
    END IF;  
 
 
 
 --TOP DE PRÉ-VENDA (NEGOCIAÇÕES)
     
     IF (INSERTING OR UPDATING) AND (PCODTIPOPER = 3150) THEN
            SELECT PARC.CODTIPPARC
                INTO PCODTIPPARC 
                FROM TGFPAR PARC WHERE PARC.CODPARC = PCODPARC;
                
                
        IF PCODTIPPARC = 10403000 THEN
                SELECT SNK_PRECO(10,:NEW.CODPROD)
                INTO PPRECO 
                FROM DUAL;
            IF PPRECO <= 0 THEN
                RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
                Produto: ' || TO_CHAR(:NEW.CODPROD) || ' está sem preço ou não pode ser vendido para este Parceiro.</font></b><br><font>');
            ELSE
                    IF :NEW.VLRUNIT <= PPRECO THEN
                        :NEW.VLRUNIT := PPRECO;
                        :NEW.VLRTOT := PPRECO * :NEW.QTDNEG;
                    END IF;
                END IF;
        END IF;
        IF PCODTIPPARC = 10402000 THEN
                SELECT SNK_PRECO(20,:NEW.CODPROD)
                INTO PPRECO 
                FROM DUAL;
            IF PPRECO <= 0 THEN
                RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
                Produto: ' || TO_CHAR(:NEW.CODPROD) || ' está sem preço ou não pode ser vendido para este Parceiro.<br></font></b><br><br><br><font>');
            ELSE
                IF :NEW.VLRUNIT <= PPRECO THEN
                    :NEW.VLRUNIT := PPRECO;
                    :NEW.VLRTOT := PPRECO * :NEW.QTDNEG;
                END IF;
            END IF;
        END IF;
     END IF;
    
END;
/
