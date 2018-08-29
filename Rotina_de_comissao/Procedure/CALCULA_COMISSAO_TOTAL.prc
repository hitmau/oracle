CREATE OR REPLACE PROCEDURE TOTALPRD."CALCULA_COMISSAO_TOTAL" (
       P_CODUSU NUMBER,        -- Código do usuário logado
       P_IDSESSAO VARCHAR2,    -- Identificador da execução. Serve para buscar informações dos parâmetros/campos da execução.
       P_QTDLINHAS NUMBER,     -- Informa a quantidade de registros selecionados no momento da execução.
       P_MENSAGEM OUT VARCHAR2 -- Caso seja passada uma mensagem aqui, ela será exibida como uma informação ao usuário.
) AS
--VETOR
--TYPE tVETOR IS VARRAY(10) OF NUMBER(5,4); -- define o tipo do vetor
--TYPE T_ARRAY_REC IS RECORD (
--                                COL1 VARCHAR2(50),
--                                COL2 FLOAT
--                             );
--V tVETOR; --declara um vetor com o nome V e o tipo tVetor
  TYPE T_ARRAY_REC IS RECORD (CODVEND INT := 0
                            , TIPMOV CHAR(1)
                            , CODGRU INT
                            , VLRTOT FLOAT := 0.0
                            , VLRTOTSEMDIV FLOAT := 0.0);
  TYPE T_ARRAY_TAB IS TABLE OF T_ARRAY_REC INDEX BY BINARY_INTEGER;
  V_ARRAY T_ARRAY_TAB;
  
  TYPE N_ARRAY_REC IS RECORD (CODVEND INT := 0
                             ,TIPMOV CHAR(1)
                             , CODGRU INT
                             , VLRTOT FLOAT := 0.0);
  TYPE N_ARRAY_TAB IS TABLE OF N_ARRAY_REC INDEX BY BINARY_INTEGER;
  N_ARRAY N_ARRAY_TAB;
  
  --Array das fatias da venda
  TYPE F_ARRAY_REC IS RECORD (IDCOM INT := 0
                             , IDTIPVENCOM INT := 0
                             , TIPO INT := 0
                             , QTDVENDEDOR INT := 0
                             , FATIA FLOAT := 0.0
                             , FVENDEDOR INT := 0);
  TYPE F_ARRAY_TAB IS TABLE OF F_ARRAY_REC INDEX BY BINARY_INTEGER;
  F_ARRAY F_ARRAY_TAB;
  
  --ARRAY PARA DEVOLUÇÕES
TYPE D_ARRAY_REC IS RECORD (GRUPO INT := 0, DEV FLOAT := 0.0
                            , TIPMOV CHAR(1)
                            , CODVEND INT);
TYPE D_ARRAY_TAB IS TABLE OF D_ARRAY_REC INDEX BY BINARY_INTEGER;
  D_ARRAY D_ARRAY_TAB;
  IDDEV INT := 0;
  --
-------
       FIELD_NUNOTA NUMBER;
       PCODUSU INT;
       --PVENDEDOR INT;
       PCARGO   INT;
       --indice do cargo
       PIDCOMCARGO INT;
       PCODPARC INT;
       --guarda top de venda ou devolução
       PTIPMOV CHAR(1);
       PVENDEDOR INT;
       PDATAINI DATE;
       PDATAFIM DATE;
       PGRUPO INT;

       PIDCATCOM1 INT;
       PIDCATCOMDESC VARCHAR(17) := 'SEM CLASSIFICACAO';

       --TOTAL DA NOTA
       PCOMISSAO FLOAT := 0.0;
       PINTER FLOAT := 0.0;
       --PINTERQTD INT := 0;
       --VARIAVEIS DE HARDWARE
       PDTVENDA DATE;
       --Var para mensagem final. 
       MSG VARCHAR(2000) := '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000"> <br>';
       
       --Var Executante 1
       PEXEC1 INT;
       PEXEC1PER1 FLOAT;
       PEXEC1PER2 FLOAT;
       PEXEC1PER3 FLOAT;

       --Var Executante 2
       PEXEC2 INT;
       PEXEC2PER1 FLOAT;
       PEXEC2PER2 FLOAT;
       PEXEC2PER3 FLOAT;

       --Var Executante 3
       PEXEC3 INT;     
       PPERVEND1 FLOAT; 
       PPERVEND2 FLOAT;
       PPERVEND3 FLOAT;
       
       --VAR VENDEDOR
       VLR1 FLOAT;
       VLR2 FLOAT;
       VLR3 FLOAT;
       VLRVEND FLOAT;   
       INDICE INT := 0;
       INDICEF INT;
       
       --valor da devolução
       PDEV FLOAT := 0.0;
       GDEV INT := 0;
       VLRDEV FLOAT;
       INDDEV INT := 0;
       SOMADEV1 FLOAT := 0;
       SOMADEV2 FLOAT;
       --PARA DEBUG
       STRTESTE VARCHAR(100);
       INTTESTE INT := 0;
BEGIN

    /*
        AUTOR: Mauricio Rodrigues
        DATA: 01/04/2018
        DESCRIÇÃO: Com a orientação do Alan aqui criado uma rotina de divisão 
        de comissão com um detalhe de personalização segundo os critérios passados por ele.
        O código deverá ser atualizado (29/08/2018).
    */

--Usuário logado
SELECT STP_GET_CODUSULOGADO() INTO PCODUSU FROM DUAL;

           PVENDEDOR := ACT_INT_PARAM(P_IDSESSAO,'VENDEDOR');
           PDATAINI := ACT_DTA_PARAM(P_IDSESSAO, 'DTINI');
           PDATAFIM := ACT_DTA_PARAM(P_IDSESSAO, 'DTFINAL');
           PGRUPO := ACT_INT_PARAM(P_IDSESSAO,'GRUPO');

--Cargo (tela de vendedor/comprador)
SELECT MAX(VEN.AD_CARGO) INTO PCARGO FROM TGFVEN VEN WHERE VEN.CODVEND = PVENDEDOR;
SELECT COUNT(IDCOM) INTO PIDCOMCARGO FROM AD_CONFCOMISSAO WHERE ATIVO = 'S' AND IDCOM = PCARGO;


IF PIDCOMCARGO = 0 THEN
    RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
Vendedor(a) CÓD: '||TO_CHAR(PVENDEDOR)||' não tem um cargo de comissão ativo!<br> (Tela Vendedor/Comprador).</font></b><br><font>');
ELSE
    SELECT IDCOM INTO PIDCOMCARGO FROM AD_CONFCOMISSAO WHERE ATIVO = 'S' AND IDCOM = PCARGO;
END IF;

SELECT COUNT(A.FATIA) INTO PPERVEND1 FROM AD_ADTIPCLIVENDCOM2 A WHERE A.IDCOM = PIDCOMCARGO;

IF PPERVEND1 = 0 THEN
    RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
    Vendedor(a) CÓD: '||TO_CHAR(PVENDEDOR)||' não tem Tipo de vendedor p/ Comissão (Tela Vendedor/Comprador).</font></b><br><font>');
END IF;

--APAGA CASO SEJA GERADO COMISSÃO NOVAMENTE

        DELETE FROM AD_COMISSAO WHERE NUCOM IN (SELECT AD.NUCOM
        FROM AD_COMISSAO AD
        WHERE (AD.DTHRCRIA BETWEEN PDATAINI AND PDATAFIM -- --TO_DATE('01/03/2018', 'DD/MM/YYYY') AND TO_DATE('30/03/2018', 'DD/MM/YYYY') AND --
                OR AD.DTHRINI = PDATAINI
                OR AD.DTHRFIM = PDATAFIM) AND
              AD.VENDEDORNOTA = PVENDEDOR AND
              AD.CARGO = PCARGO);

        DELETE FROM AD_COMISSAOSIMPLES WHERE IDCOMSIMPLES IN (SELECT AD.IDCOMSIMPLES
        FROM AD_COMISSAOSIMPLES AD
        WHERE (AD.DTCRIACAO BETWEEN PDATAINI AND PDATAFIM -- --TO_DATE('01/03/2018', 'DD/MM/YYYY') AND TO_DATE('30/03/2018', 'DD/MM/YYYY') AND --
                OR AD.DTINI = PDATAINI
                OR AD.DTFIN = PDATAFIM) AND
              AD.VENDEDORNOTA = PVENDEDOR AND
              AD.CARGO = PCARGO);

FOR I IN (SELECT CAB.NUNOTA FROM TGFCAB CAB WHERE 
           CAB.CODVEND = PVENDEDOR AND 
           CAB.DTENTSAI BETWEEN PDATAINI AND PDATAFIM AND
           CAB.STATUSNOTA = 'L' AND
           CAB.CODTIPOPER IN (SELECT CODTIPOPER FROM AD_TIPVENDEV)
           ORDER BY 1)--1..P_QTDLINHAS -- Este loop permite obter o valor de campos dos registros envolvidos na execução.
LOOP -- A variável "I" representa o registro corrente.
       FIELD_NUNOTA := I.NUNOTA; --ACT_INT_FIELD(P_IDSESSAO, I, 'NUNOTA');
       
       SELECT CAB.DTENTSAI, (SELECT TOP.TIPMOV FROM TGFTOP  TOP WHERE TOP.CODTIPOPER = CAB.CODTIPOPER AND TOP.DHALTER = (SELECT MAX(T.DHALTER) FROM TGFTOP T WHERE TOP.CODTIPOPER = T.CODTIPOPER))
       INTO PDTVENDA, PTIPMOV
       FROM TGFCAB CAB
       WHERE CAB.NUNOTA = FIELD_NUNOTA;    
               
       SELECT NVL(CAB.AD_EXEC, 0), NVL(CAB.AD_EXEC2, 0)
       INTO PEXEC1, PEXEC2
       FROM TGFCAB CAB
       WHERE CAB.NUNOTA = FIELD_NUNOTA;
       --vendedor
       INDICEF := 0;
        FOR F IN (select IDCOM, IDTIPVENCOM, TIPO, FATIA, QTDVENDEDOR from AD_ADTIPCLIVENDCOM2 WHERE IDCOM = PIDCOMCARGO)
        LOOP
            F_ARRAY(INDICEF).IDCOM := F.IDCOM;
            F_ARRAY(INDICEF).IDTIPVENCOM := F.IDTIPVENCOM;
            F_ARRAY(INDICEF).FATIA := F.FATIA;
            F_ARRAY(INDICEF).TIPO := F.TIPO;
            F_ARRAY(INDICEF).QTDVENDEDOR := F.QTDVENDEDOR;
            F_ARRAY(INDICEF).FVENDEDOR := PVENDEDOR;
            INDICEF := INDICEF + 1;
        END LOOP;
       --SE EXISTE EXECUTANTE 1
       IF PEXEC1 <> 0 THEN
            SELECT COUNT(CONF.IDTIPVENCOM)
            INTO PEXEC1PER1
            FROM TGFVEN VEN INNER JOIN AD_ADTIPCLIVENDCOM2 CONF ON (VEN.AD_CARGO = CONF.IDCOM)
            WHERE VEN.CODVEND = PEXEC1;
   
           IF PEXEC1PER1 = 0 THEN
                RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
Vendedor(a) CÓD: '||TO_CHAR(PEXEC1)||' não tem Tipo de vendedor p/ Comissão (Tela Vendedor/Comprador).</font></b><br><font>');
           ELSE
                SELECT DISTINCT CONF.IDCOM
                INTO PEXEC1PER1
                FROM TGFVEN VEN INNER JOIN AD_ADTIPCLIVENDCOM2 CONF ON (VEN.AD_CARGO = CONF.IDCOM)
                WHERE VEN.CODVEND = PEXEC1;

                FOR F IN (select IDCOM, IDTIPVENCOM, TIPO, FATIA, QTDVENDEDOR from AD_ADTIPCLIVENDCOM2 WHERE IDCOM = PEXEC1PER1)
                LOOP
                    F_ARRAY(INDICEF).IDCOM := F.IDCOM;
                    F_ARRAY(INDICEF).IDTIPVENCOM := F.IDTIPVENCOM;
                    F_ARRAY(INDICEF).FATIA := F.FATIA;
                    F_ARRAY(INDICEF).TIPO := F.TIPO;
                    F_ARRAY(INDICEF).QTDVENDEDOR := F.QTDVENDEDOR;
                    F_ARRAY(INDICEF).FVENDEDOR := PEXEC1;
                    INDICEF := INDICEF + 1;
                END LOOP;
           END IF;
        END IF;
        --FIM EXECUTANTE 1
        
        --SE EXISTE EXECUTANTE 2
        IF PEXEC2 <> 0 THEN
           SELECT COUNT(CONF.IDTIPVENCOM)
            INTO PEXEC2PER1
            FROM TGFVEN VEN INNER JOIN AD_ADTIPCLIVENDCOM2 CONF ON (VEN.AD_CARGO = CONF.IDCOM)
            WHERE VEN.CODVEND = PEXEC2;

           IF PEXEC2PER1 = 0 THEN
                RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
Vendedor(a) CÓD: '||TO_CHAR(PEXEC1)||' não tem Tipo de vendedor p/ Comissão (Tela Vendedor/Comprador).</font></b><br><font>');
           ELSE
                SELECT DISTINCT CONF.IDCOM
                INTO PEXEC2PER1
                FROM TGFVEN VEN INNER JOIN AD_ADTIPCLIVENDCOM2 CONF ON (VEN.AD_CARGO = CONF.IDCOM)
                WHERE VEN.CODVEND = PEXEC2;

                FOR F IN (select IDCOM, IDTIPVENCOM, TIPO, FATIA, QTDVENDEDOR from AD_ADTIPCLIVENDCOM2 WHERE IDCOM = PEXEC2PER1)
                LOOP
                    F_ARRAY(INDICEF).IDCOM := F.IDCOM;
                    F_ARRAY(INDICEF).IDTIPVENCOM := F.IDTIPVENCOM;
                    F_ARRAY(INDICEF).FATIA := F.FATIA;
                    F_ARRAY(INDICEF).TIPO := F.TIPO;
                    F_ARRAY(INDICEF).QTDVENDEDOR := F.QTDVENDEDOR;
                    F_ARRAY(INDICEF).FVENDEDOR := PEXEC2;
                    INDICEF := INDICEF + 1;
                END LOOP;
           END IF;
        END IF;
        --FIM EXECUTANTE 2
       
        --FPRODUTOS
        FOR FPRODUTOS IN (SELECT ITE.CODPROD, 
                                 ITE.VLRTOT, 
                                 SUBSTR((SELECT GRU.CODGRUPAI 
                                   FROM TGFGRU GRU 
                                   WHERE GRU.CODGRUPOPROD = (SELECT PROD.CODGRUPOPROD 
                                                             FROM TGFPRO PROD 
                                                             WHERE PROD.CODPROD = ITE.CODPROD)),0,2) AS GRUPOPAI,
                                LENGTH((SELECT GRU.CODGRUPAI 
                                   FROM TGFGRU GRU 
                                   WHERE GRU.CODGRUPOPROD = (SELECT PROD.CODGRUPOPROD 
                                                             FROM TGFPRO PROD 
                                                             WHERE PROD.CODPROD = ITE.CODPROD))) AS QTDGRUPOPAI                             
                            FROM TGFITE ITE 
                            WHERE ITE.NUNOTA = FIELD_NUNOTA ORDER BY GRUPOPAI) --FIELD_NUNOTA
        LOOP
                --TIPOS DE GRUPOS CADASTRADOS - FREGRA
                FOR FREGRA IN (SELECT DISTINCT IDGRUPROD, (SELECT DESCRICAO FROM AD_GRUCOMISSAO C WHERE C.IDGRUPROD = AD.IDGRUPROD) AS DESCRICAO 
                               FROM AD_RCOMISSAO AD WHERE AD.IDCOM = PIDCOMCARGO/*PIDCOMCARGO*/ ORDER BY 1)
                LOOP
                    --FGRUPO - GRUPOS 
                    FOR FGRUPO IN (SELECT SUBSTR((CASE WHEN G.CODGRUPOPROD = 99000000 THEN (SELECT GRU.CODGRUPAI 
                                        FROM TGFGRU GRU 
                                        WHERE GRU.CODGRUPOPROD = G.CODGRUPOPROD) ELSE G.CODGRUPOPROD END),0,2) 
                                    AS GRUPOPAI,
                                   LENGTH((CASE WHEN G.CODGRUPOPROD = 99000000 THEN (SELECT GRU.CODGRUPAI 
                                                                                    FROM TGFGRU GRU 
                                                                                    WHERE GRU.CODGRUPOPROD = G.CODGRUPOPROD) ELSE G.CODGRUPOPROD END)) 
                                    AS QTDGRUPOPAI 
                                   FROM AD_GRUCOM G WHERE G.IDGRUPROD = FREGRA.IDGRUPROD) 
                    LOOP
                        --ARMAZENA VALOR NA VARIÁVEL.
                        IF FPRODUTOS.QTDGRUPOPAI = FGRUPO.QTDGRUPOPAI AND  FPRODUTOS.GRUPOPAI = FGRUPO.GRUPOPAI THEN
                                PINTER := FPRODUTOS.VLRTOT;
                                EXIT;
                            ELSE
                                PINTER := 0.0;
                        END IF;
                    END LOOP; --FGRUPO - FIM DOS GRUPOS
                        IF FREGRA.IDGRUPROD IS NULL THEN
                            RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
Regra de comissão sem grupo de produtos!</font></b><br><font>'); 
                        END IF;
                                N_ARRAY(FREGRA.IDGRUPROD).CODVEND := 0;
                                N_ARRAY(FREGRA.IDGRUPROD).CODGRU := FREGRA.IDGRUPROD;
                                N_ARRAY(FREGRA.IDGRUPROD).TIPMOV := PTIPMOV;
                                N_ARRAY(FREGRA.IDGRUPROD).VLRTOT := N_ARRAY(FREGRA.IDGRUPROD).VLRTOT + PINTER;
--                                
                END LOOP; --FREGRA - FIM DOS TIPOS DE GRUPOS CADASTRADOS
                    PINTER := 0.0;
        END LOOP; --FIM DOS FPRODUTOS
        
        --GRAVA NA TELA DE DADOS DETALHADOS DA COMISSÃO
          FOR M IN N_ARRAY.FIRST .. N_ARRAY.LAST
          LOOP
                    
                        IF N_ARRAY(M).TIPMOV = 'D' AND N_ARRAY(M).VLRTOT > 0 THEN
                                    D_ARRAY(N_ARRAY(M).CODGRU).GRUPO := N_ARRAY(M).CODGRU;
                                    D_ARRAY(N_ARRAY(M).CODGRU).TIPMOV := N_ARRAY(M).TIPMOV;
                                    D_ARRAY(N_ARRAY(M).CODGRU).CODVEND := N_ARRAY(M).CODVEND;
                                    D_ARRAY(N_ARRAY(M).CODGRU).DEV := D_ARRAY(N_ARRAY(M).CODGRU).DEV + N_ARRAY(M).VLRTOT;
                        --strteste := strteste || ' - ' || N_ARRAY(M).TIPMOV || ' vlr RS ' || N_ARRAY(M).VLRTOT || ' nunota = ' || field_nunota;
                         END IF;
          END LOOP;
                  
          FOR M IN N_ARRAY.FIRST .. N_ARRAY.LAST
          LOOP
                    IF (N_ARRAY(M).VLRTOT <> 0.0) THEN
                    --COM 3 PARTICIPANTES NA VENDA...
                        IF (PEXEC1 <> 0) AND (PEXEC2 <> 0) THEN
                        --TERCEIRO EXECUTANTE                 
                            FOR FF IN F_ARRAY.FIRST .. F_ARRAY.LAST
                            LOOP
                                IF F_ARRAY(FF).FVENDEDOR = PEXEC1 AND F_ARRAY(FF).TIPO = 1 AND F_ARRAY(FF).QTDVENDEDOR = 3 THEN
                                    PEXEC2PER3 := F_ARRAY(FF).FATIA;
                                    VLR2 := (N_ARRAY(M).VLRTOT /100) * PEXEC2PER3;
                                    exit;
                                ELSIF F_ARRAY(FF).FVENDEDOR = PEXEC1 AND F_ARRAY(FF).TIPO = 2 AND F_ARRAY(FF).QTDVENDEDOR = 3 THEN
                                    PEXEC2PER3 := F_ARRAY(FF).FATIA;
                                    IF N_ARRAY(M).VLRTOT < PEXEC2PER3 THEN
                                        RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
O valor do terceiro executante a ser subtraído é maior que o valor da nota.</font></b><br><font>');   
                                    ELSE
                                        PEXEC2PER3 := F_ARRAY(FF).FATIA;
                                        VLR2 := PEXEC2PER3;
                                        N_ARRAY(M).VLRTOT := N_ARRAY(M).VLRTOT - PEXEC2PER3;
                                        exit;
                                    END IF;  
                                END IF;
                            END LOOP;
                            --SEGUNDO EXECUTANTE
                            FOR FF IN F_ARRAY.FIRST .. F_ARRAY.LAST
                            LOOP
                                IF F_ARRAY(FF).FVENDEDOR = PEXEC2 AND F_ARRAY(FF).TIPO = 1 AND F_ARRAY(FF).QTDVENDEDOR = 3 THEN
                                    PEXEC1PER3 := F_ARRAY(FF).FATIA;
                                    VLR1 := (N_ARRAY(M).VLRTOT /100) * PEXEC1PER3;
                                    exit;
                                ELSIF F_ARRAY(FF).FVENDEDOR = PEXEC2 AND F_ARRAY(FF).TIPO = 2 AND F_ARRAY(FF).QTDVENDEDOR = 3 THEN
                                    PEXEC1PER3 := F_ARRAY(FF).FATIA;
                                    IF N_ARRAY(M).VLRTOT < PEXEC1PER3 THEN
                                        RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
O valor do terceiro executante a ser subtraído é maior que o valor da nota.</font></b><br><font>');   
                                    ELSE
                                        PEXEC1PER3 := F_ARRAY(FF).FATIA;
                                        VLR1 := PEXEC1PER3;
                                        N_ARRAY(M).VLRTOT := N_ARRAY(M).VLRTOT - PEXEC1PER3;
                                        exit;
                                    END IF;  
                                END IF;
                            END LOOP;
                            --VENDEDOR
                            FOR FF IN F_ARRAY.FIRST .. F_ARRAY.LAST
                            LOOP
                                IF F_ARRAY(FF).FVENDEDOR = PVENDEDOR AND F_ARRAY(FF).TIPO = 1 AND F_ARRAY(FF).QTDVENDEDOR = 3 THEN
                                    IF (PEXEC2PER3 + PEXEC1PER3) > 100 THEN
                                        RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
O valor o valor do percentual do 1º e 2º executante somados é maior que 100% para o vendedor. Executante 1 = ' || to_date(PEXEC1PER3) || ', Executante 2 = ' || to_date(PEXEC2PER3) || '</font></b><br><font>');
                                    END IF;
                                    PPERVEND3 := 100 - (PEXEC2PER3 + PEXEC1PER3);
                                    VLRVEND := (N_ARRAY(M).VLRTOT /100) * PPERVEND3;
                                    exit;
                                ELSIF F_ARRAY(FF).FVENDEDOR = PVENDEDOR AND F_ARRAY(FF).TIPO = 2 AND F_ARRAY(FF).QTDVENDEDOR = 3 THEN
                                    PPERVEND3 := F_ARRAY(FF).FATIA;
                                    IF N_ARRAY(M).VLRTOT < PPERVEND3 THEN
                                        RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
O valor do terceiro executante a ser subtraído é maior que o valor da nota.</font></b><br><font>');   
                                    ELSE
                                        VLRVEND := PPERVEND3;
                                        N_ARRAY(M).VLRTOT := PEXEC1PER3;
                                    END IF;  
                                END IF;
                            END LOOP;
                                --SE FOR VENDA
                                IF N_ARRAY(M).TIPMOV = 'V' THEN
                                    INSERT INTO AD_COMISSAO (NUCOM,NUNOTA, DTHRCRIA, DTHRINI , DTHRFIM,DTVENDA, VLRATUAL, GRUPO, COMISSAO, CARGO, PERCENTUAL, VENDEDOR, VENDEDORNOTA) VALUES
                                    ((SELECT MAX(NUCOM)+1 FROM AD_COMISSAO),FIELD_NUNOTA, TO_DATE(SYSDATE, 'DD/MM/YY'),  PDATAINI, PDATAFIM, PDTVENDA, N_ARRAY(M).VLRTOT, N_ARRAY(M).CODGRU, VLRVEND, PCARGO, PPERVEND3, PVENDEDOR, PVENDEDOR);

                                    INSERT INTO AD_COMISSAO (NUCOM,NUNOTA, DTHRCRIA, DTHRINI , DTHRFIM,DTVENDA, VLRATUAL, GRUPO, COMISSAO, CARGO, PERCENTUAL, VENDEDOR, VENDEDORNOTA) VALUES
                                    ((SELECT MAX(NUCOM)+1 FROM AD_COMISSAO),FIELD_NUNOTA, TO_DATE(SYSDATE, 'DD/MM/YY'),  PDATAINI, PDATAFIM,PDTVENDA, N_ARRAY(M).VLRTOT, N_ARRAY(M).CODGRU, VLR1, PCARGO, PEXEC1PER3, PEXEC1, PVENDEDOR);
                             
                                    INSERT INTO AD_COMISSAO (NUCOM,NUNOTA, DTHRCRIA, DTHRINI , DTHRFIM,DTVENDA, VLRATUAL, GRUPO, COMISSAO, CARGO, PERCENTUAL, VENDEDOR, VENDEDORNOTA) VALUES
                                    ((SELECT MAX(NUCOM)+1 FROM AD_COMISSAO),FIELD_NUNOTA, TO_DATE(SYSDATE, 'DD/MM/YY'),  PDATAINI, PDATAFIM,PDTVENDA, N_ARRAY(M).VLRTOT, N_ARRAY(M).CODGRU, VLR2, PCARGO, PEXEC2PER3, PEXEC2, PVENDEDOR);
                                ELSE --DEVOLUÇÕES
                                    INSERT INTO AD_COMISSAO (NUCOM,NUNOTA, DTHRCRIA, DTHRINI , DTHRFIM, DTVENDA, VLRATUAL, GRUPO, DEVOLUCAO, CARGO, PERCENTUAL, VENDEDOR, VENDEDORNOTA) VALUES
                                    ((SELECT MAX(NUCOM)+1 FROM AD_COMISSAO),FIELD_NUNOTA, TO_DATE(SYSDATE, 'DD/MM/YY'),  PDATAINI, PDATAFIM, PDTVENDA, (N_ARRAY(M).VLRTOT * (-1)), N_ARRAY(M).CODGRU, (VLRVEND * (-1)), PCARGO, PPERVEND3, PVENDEDOR, PVENDEDOR);

                                    INSERT INTO AD_COMISSAO (NUCOM,NUNOTA, DTHRCRIA, DTHRINI , DTHRFIM, DTVENDA, VLRATUAL, GRUPO, DEVOLUCAO, CARGO, PERCENTUAL, VENDEDOR, VENDEDORNOTA) VALUES
                                    ((SELECT MAX(NUCOM)+1 FROM AD_COMISSAO),FIELD_NUNOTA, TO_DATE(SYSDATE, 'DD/MM/YY'),  PDATAINI, PDATAFIM, PDTVENDA, (N_ARRAY(M).VLRTOT * (-1)), N_ARRAY(M).CODGRU, (VLR1 * (-1)), PCARGO, PEXEC1PER3, PEXEC1, PVENDEDOR);
                             
                                    INSERT INTO AD_COMISSAO (NUCOM, NUNOTA, DTHRCRIA, DTHRINI , DTHRFIM, DTVENDA, VLRATUAL, GRUPO, DEVOLUCAO, CARGO, PERCENTUAL, VENDEDOR, VENDEDORNOTA) VALUES
                                    ((SELECT MAX(NUCOM)+1 FROM AD_COMISSAO),FIELD_NUNOTA, TO_DATE(SYSDATE, 'DD/MM/YY'),  PDATAINI, PDATAFIM, PDTVENDA, (N_ARRAY(M).VLRTOT * (-1)), N_ARRAY(M).CODGRU, (VLR2 * (-1)), PCARGO, PEXEC2PER3, PEXEC2, PVENDEDOR);
                                END IF;
                                VLR2 := 0.0;
                                VLR1 := 0.0;
                                VLRVEND := 0.0;
                        --VENDA COM 2 EXECUTANTES
                        ELSIF (PEXEC1 <> 0) AND (PEXEC2 = 0) THEN
                        --EXECUTANTE 1
                            FOR FF IN F_ARRAY.FIRST .. F_ARRAY.LAST
                            LOOP
                                IF (F_ARRAY(FF).FVENDEDOR = PEXEC1) AND (F_ARRAY(FF).TIPO = 1) AND (F_ARRAY(FF).QTDVENDEDOR = 2) THEN

                                    PEXEC1PER2 := F_ARRAY(FF).FATIA;
                                    VLR1 := (N_ARRAY(M).VLRTOT /100) * PEXEC1PER2;
                                    exit;
                                ELSIF F_ARRAY(FF).FVENDEDOR = PEXEC1 AND F_ARRAY(FF).TIPO = 2 AND F_ARRAY(FF).QTDVENDEDOR = 2 THEN
                                    PEXEC1PER2 := F_ARRAY(FF).FATIA;
                                    IF N_ARRAY(M).VLRTOT < PEXEC1PER2 THEN
                                        RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
O valor do segundo executante a ser subtraído é maior que o valor da nota.</font></b><br><font>');   
                                    ELSE
                                        PEXEC1PER2 := F_ARRAY(FF).FATIA;
                                        VLR1 := PEXEC1PER2;
                                        N_ARRAY(M).VLRTOT := N_ARRAY(M).VLRTOT - PEXEC1PER2;
                                    END IF;  
                                END IF;

                            END LOOP;
                        --VENDEDOR
                            FOR FF IN F_ARRAY.FIRST .. F_ARRAY.LAST
                            LOOP

                                IF F_ARRAY(FF).FVENDEDOR = PVENDEDOR AND F_ARRAY(FF).TIPO = 1 AND F_ARRAY(FF).QTDVENDEDOR = 2 THEN

                                    IF (PEXEC2PER3 + PEXEC1PER3) > 100 THEN
                                        RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
O valor do percentual do 1º é maior que 100% para o vendedor. Executante 1 = ' || to_date(PEXEC1PER3) || '.</font></b><br><font>');
                                    END IF;
                                    PPERVEND2 := 100 - PEXEC1PER2;
                                    VLRVEND := (N_ARRAY(M).VLRTOT /100) * PPERVEND2;
                                    exit;
                                ELSIF F_ARRAY(FF).FVENDEDOR = PVENDEDOR AND F_ARRAY(FF).TIPO = 2 AND F_ARRAY(FF).QTDVENDEDOR = 2 THEN
                                    PPERVEND2 := F_ARRAY(FF).FATIA;
                                    IF N_ARRAY(M).VLRTOT < PPERVEND2 THEN
                                        RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
O valor do Vendedor a ser subtraído é maior que o valor da nota.</font></b><br><font>');   
                                    ELSE
                                        VLRVEND := PPERVEND2;
                                        N_ARRAY(M).VLRTOT := PEXEC1PER2;
                                    END IF;  
                                END IF;
                            END LOOP;

                                IF N_ARRAY(M).TIPMOV = 'V' THEN
                                    INSERT INTO AD_COMISSAO (NUCOM,NUNOTA, DTHRCRIA, DTHRINI , DTHRFIM,DTVENDA, VLRATUAL, GRUPO, COMISSAO, CARGO, PERCENTUAL, VENDEDOR, VENDEDORNOTA) VALUES
                                    ((SELECT MAX(NUCOM)+1 FROM AD_COMISSAO),FIELD_NUNOTA, TO_DATE(SYSDATE, 'DD/MM/YY'),  PDATAINI, PDATAFIM,PDTVENDA, N_ARRAY(M).VLRTOT, N_ARRAY(M).CODGRU, VLRVEND, PCARGO, PPERVEND2, PVENDEDOR, PVENDEDOR);
                             
                                    INSERT INTO AD_COMISSAO (NUCOM,NUNOTA, DTHRCRIA, DTHRINI , DTHRFIM,DTVENDA, VLRATUAL, GRUPO, COMISSAO, CARGO, PERCENTUAL, VENDEDOR, VENDEDORNOTA) VALUES
                                    ((SELECT MAX(NUCOM)+1 FROM AD_COMISSAO),FIELD_NUNOTA, TO_DATE(SYSDATE, 'DD/MM/YY'),  PDATAINI, PDATAFIM,PDTVENDA, N_ARRAY(M).VLRTOT, N_ARRAY(M).CODGRU, VLR1, PCARGO, PEXEC1PER2, PEXEC1, PVENDEDOR);
                                ELSE
                                    INSERT INTO AD_COMISSAO (NUCOM,NUNOTA, DTHRCRIA, DTHRINI , DTHRFIM,DTVENDA, VLRATUAL, GRUPO, DEVOLUCAO, CARGO, PERCENTUAL, VENDEDOR, VENDEDORNOTA) VALUES
                                    ((SELECT MAX(NUCOM)+1 FROM AD_COMISSAO),FIELD_NUNOTA, TO_DATE(SYSDATE, 'DD/MM/YY'),  PDATAINI, PDATAFIM,PDTVENDA, (N_ARRAY(M).VLRTOT * (-1)), N_ARRAY(M).CODGRU, (VLRVEND * (-1)), PCARGO, PPERVEND2, PVENDEDOR, PVENDEDOR);
                             
                                    INSERT INTO AD_COMISSAO (NUCOM,NUNOTA, DTHRCRIA, DTHRINI , DTHRFIM,DTVENDA, VLRATUAL, GRUPO, DEVOLUCAO, CARGO, PERCENTUAL, VENDEDOR, VENDEDORNOTA) VALUES
                                    ((SELECT MAX(NUCOM)+1 FROM AD_COMISSAO),FIELD_NUNOTA, TO_DATE(SYSDATE, 'DD/MM/YY'),  PDATAINI, PDATAFIM,PDTVENDA, (N_ARRAY(M).VLRTOT * (-1)), N_ARRAY(M).CODGRU, (VLR1 * (-1)), PCARGO, PEXEC1PER2, PEXEC1, PVENDEDOR);
                                END IF;    
                                VLRVEND := 0.0;
                                VLR2 := 0.0;
                                VLR1 := 0.0;
                        --APENAS 1 VENDEDOR NA VENDA
                        ELSIF PEXEC1 = 0 AND PEXEC2 = 0 THEN
                            FOR FF IN F_ARRAY.FIRST .. F_ARRAY.LAST
                            LOOP
                                IF INTTESTE <> 0 THEN  
                                    FOR DD IN D_ARRAY.FIRST .. D_ARRAY.LAST
                                    LOOP
                                        IF D_ARRAY(DD).GRUPO = N_ARRAY(M).CODGRU AND D_ARRAY(DD).TIPMOV <> 'D' THEN
                                            N_ARRAY(M).VLRTOT := N_ARRAY(M).VLRTOT - D_ARRAY(DD).DEV;

                                        --INTTESTE := 0;
                                        END IF;
                                        strteste := strteste || D_ARRAY(DD).DEV || ' - tipmov (' || D_ARRAY(DD).tipmov || ') D_ARRAY(DD).GRUPO (' || D_ARRAY(DD).GRUPO || ')' ;
                                    END LOOP;
RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
D_ARRAY(DD).DEV ' || to_char(strteste) || '.</font></b><br><font>'); 
                                

                                END IF;
                                    --VERIFICA VENDEDOR - TIPO (1 % OU 2$) E QTD DE VENDEDOR (DIVISAO)
                                    IF F_ARRAY(FF).FVENDEDOR = PVENDEDOR AND F_ARRAY(FF).TIPO = 1 AND F_ARRAY(FF).QTDVENDEDOR = 1 THEN
                                        PPERVEND1 := F_ARRAY(FF).FATIA;
                                        VLRVEND := ((N_ARRAY(M).VLRTOT)/100) * PPERVEND1;
                                        EXIT;
                                    ELSIF F_ARRAY(FF).FVENDEDOR = PVENDEDOR AND F_ARRAY(FF).TIPO = 2 AND F_ARRAY(FF).QTDVENDEDOR = 1 THEN
                                        IF N_ARRAY(M).VLRTOT < F_ARRAY(FF).FATIA THEN
                                            RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
O valor do terceiro executante a ser subtraído é maior que o valor da nota.</font></b><br><font>');   
                                        ELSE
                                            PPERVEND1 := F_ARRAY(FF).FATIA;
                                            VLRVEND := PPERVEND2;
                                            N_ARRAY(M).VLRTOT := F_ARRAY(FF).FATIA;
                                        END IF;  
                                END IF;
                                
                            END LOOP;

                            IF N_ARRAY(M).TIPMOV = 'V' THEN
                                INSERT INTO AD_COMISSAO (NUCOM,NUNOTA, DTHRCRIA, DTHRINI , DTHRFIM,DTVENDA, VLRATUAL, GRUPO, COMISSAO, CARGO, PERCENTUAL, VENDEDOR, VENDEDORNOTA) VALUES
                                ((SELECT MAX(NUCOM)+1 FROM AD_COMISSAO),FIELD_NUNOTA, TO_DATE(SYSDATE, 'DD/MM/YY'),  PDATAINI, PDATAFIM,PDTVENDA, N_ARRAY(M).VLRTOT, N_ARRAY(M).CODGRU, VLRVEND, PCARGO, PPERVEND1, PVENDEDOR, PVENDEDOR);
                            ELSE
                                INSERT INTO AD_COMISSAO (NUCOM,NUNOTA, DTHRCRIA, DTHRINI , DTHRFIM,DTVENDA, VLRATUAL, GRUPO, DEVOLUCAO, CARGO, PERCENTUAL, VENDEDOR, VENDEDORNOTA) VALUES
                                ((SELECT MAX(NUCOM)+1 FROM AD_COMISSAO),FIELD_NUNOTA, TO_DATE(SYSDATE, 'DD/MM/YY'),  PDATAINI, PDATAFIM,PDTVENDA, (N_ARRAY(M).VLRTOT * (-1)), N_ARRAY(M).CODGRU, (N_ARRAY(M).VLRTOT * (-1)), PCARGO, PPERVEND1, PVENDEDOR, PVENDEDOR);
                            END IF;
                            VLR3 := 0.0;
                            VLR2 := 0.0;
                            VLR1 := 0.0;
                        END IF;
                    END IF;
          END LOOP;       
          N_ARRAY.Delete;  
          F_ARRAY.Delete;

      END LOOP; -- NOTAS
--RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
--gRUPO ' || TO_CHAR(strteste) || '.</font></b><br><font>');
      D_ARRAY.Delete;
 --STOP
      --GUARDA DADOS NO ARRAY SOMANDO OS DADOS SIMPLES
        FOR FSIMPLES IN (SELECT DISTINCT VENDEDOR FROM AD_COMISSAO 
                       WHERE DTHRCRIA = TO_DATE(SYSDATE, 'DD/MM/YY')
                             AND VENDEDORNOTA = PVENDEDOR)
        LOOP
            FOR FVALOR IN (SELECT SUM(ad.VLRATUAL) - CASE WHEN (SELECT COUNT(SUM(aa.DEVOLUCAO)) 
                                                                FROM AD_COMISSAO aa
                                                                WHERE aa.DTHRCRIA = TO_DATE(SYSDATE, 'DD/MM/YY') 
                                                                    AND aa.VENDEDOR = FSIMPLES.VENDEDOR 
                                                                    AND aa.VENDEDORNOTA = PVENDEDOR 
                                                                    AND aa.devolucao is not null 
                                                                    AND aa.grupo = AD.GRUPO
                                    GROUP BY aa.GRUPO, aa.VENDEDOR) = 0 THEN 0 ELSE (SELECT NVL(SUM(aa.DEVOLUCAO),0) 
                                                                                     FROM AD_COMISSAO aa
                                                                                     WHERE aa.DTHRCRIA = TO_DATE(SYSDATE, 'DD/MM/YY') 
                                                                                         AND aa.VENDEDOR = FSIMPLES.VENDEDOR 
                                                                                         AND aa.VENDEDORNOTA = PVENDEDOR 
                                                                                         AND aa.devolucao is not null 
                                                                                         and aa.grupo = ad.grupo
                                                                                     GROUP BY aa.GRUPO, aa.VENDEDOR) END AS VLRATUAL -- <--
    , SUM(ad.COMISSAO) - CASE WHEN (SELECT COUNT(SUM(aa.DEVOLUCAO)) 
                       FROM AD_COMISSAO aa
                       WHERE aa.DTHRCRIA = TO_DATE(SYSDATE, 'DD/MM/YY') 
                             AND aa.VENDEDOR = FSIMPLES.VENDEDOR 
                             AND aa.VENDEDORNOTA = PVENDEDOR 
                             AND aa.devolucao is not null 
                             and aa.grupo = AD.GRUPO
                       GROUP BY aa.GRUPO, aa.VENDEDOR) = 0 THEN 0 ELSE (SELECT NVL(SUM(aa.DEVOLUCAO),0)
                       FROM AD_COMISSAO aa
                       WHERE aa.DTHRCRIA = TO_DATE(SYSDATE, 'DD/MM/YY') 
                             AND aa.VENDEDOR = FSIMPLES.VENDEDOR 
                             AND aa.VENDEDORNOTA = PVENDEDOR 
                             AND aa.devolucao is not null 
                             and aa.grupo = ad.grupo
                       GROUP BY aa.GRUPO, aa.VENDEDOR) END AS COMISSAO  -- <--
    , SUM(ad.DEVOLUCAO) AS DEVOLUCAO  -- <--
    , ad.GRUPO  -- <--
    , ad.VENDEDOR   -- <--
                       FROM AD_COMISSAO ad
                       WHERE ad.DTHRCRIA = TO_DATE(SYSDATE, 'DD/MM/YY') 
                             AND ad.VENDEDOR = FSIMPLES.VENDEDOR 
                             AND ad.VENDEDORNOTA = PVENDEDOR 
                             AND ad.VLRATUAL <> 0 
                       GROUP BY ad.GRUPO, ad.VENDEDOR)
            LOOP
            
                IF FVALOR.DEVOLUCAO IS NOT NULL THEN
                --NOTA DE ORIGEM DA DEVOLUÇÃO.
                --SELECT NUNOTAORIG FROM TGFVAR WHERE NUNOTA = FIELDS_NUNOTA; 
--IF SOMADEV1 > 0 THEN
                    --FOR D IN D_ARRAY.FIRST..D_ARRAY.LAST
                    --LOOP
                         INSERT INTO AD_COMISSAOSIMPLES (IDCOMSIMPLES, VLRATUAL, DEVOLUCAO, VENDEDOR, TIPOCLIENTE, CARGO, DTINI, DTFIN, DTCRIACAO, IDGRUPROD, VENDEDORNOTA) VALUES
                        ((SELECT MAX(IDCOMSIMPLES)+1 FROM AD_COMISSAOSIMPLES), FVALOR.devolucao, FVALOR.devolucao, FSIMPLES.VENDEDOR, 4, PCARGO, PDATAINI, PDATAFIM, SYSDATE, FVALOR.GRUPO, PVENDEDOR);
                    --END LOOP;
                --SOMADEV1 := 0;
--                END IF;                
--                        SOMADEV1 := SOMADEV1 + FVALOR.VLRATUAL;
--                        D_ARRAY(INDDEV).GRUPO := FVALOR.GRUPO;
--                        D_ARRAY(INDDEV).TIPMOV := 'D';
--                        D_ARRAY(INDDEV).CODVEND := PVENDEDOR;
--                        D_ARRAY(INDDEV).DEV := D_ARRAY(INDDEV).DEV + FVALOR.VLRATUAL;
--                        INDDEV := INDDEV + 1;
--RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
--GRUPO ' || TO_CHAR(D_ARRAY(0).GRUPO) || ' indice: ' || to_char(PTIPMOV) || 'FIELD_NUNOTA ' || TO_CHAR(FIELD_NUNOTA) ||'.</font></b><br><font>');   

                END IF;
                    FOR FMETAS IN (SELECT IDGRUPROD , IDCOM,IDRCOM, IDCATCOM, VLRMIN, NVL(VLRMAX,-1) AS VLRMAX, PER, (SELECT NVL(MAX(C.FATIA), 0) FROM AD_CONFCOMISSAO C WHERE C.IDCOM = AD.IDCOM) AS FATIA 
                                FROM AD_RCOMISSAO AD 
                                WHERE AD.IDCOM = (SELECT AD_CARGO FROM TGFVEN WHERE CODVEND = FSIMPLES.VENDEDOR) AND AD.IDGRUPROD = FVALOR.GRUPO ORDER BY VLRMAX DESC)
                    LOOP
                
                    
                
                    IF FMETAS.FATIA = 0 THEN
                        RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
Configuração de comissão está faltando "Calculo sobre" Total ou Fatia.</font></b><br><font>');
                    END IF;
                    --CALCULO SOBRE O TOTAL
                    IF FMETAS.FATIA = 2 THEN
--                        RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
--SOBRE O TOTAL.</font></b><br><font>');
                    --SE CAMPO VLRMAX ESTIVER VAZIO, SERÁ A MAIOR META.
                    IF FMETAS.VLRMAX = -1 THEN
                        PCOMISSAO := (FVALOR.COMISSAO/100) * FMETAS.PER;
                                IF PVENDEDOR = FSIMPLES.VENDEDOR THEN
                                    INTTESTE := INTTESTE + PCOMISSAO;
                                END IF;
                            INSERT INTO AD_COMISSAOSIMPLES (IDCOMSIMPLES, VLRATUAL, COMISSAO, PERCENTUAL, VENDEDOR, TIPOCLIENTE, CARGO, DTINI, DTFIN, DTCRIACAO, IDGRUPROD, IDCATCOM, VENDEDORNOTA, VLRTIPMETA) VALUES
                            ((SELECT MAX(IDCOMSIMPLES)+1 FROM AD_COMISSAOSIMPLES), FVALOR.VLRATUAL, PCOMISSAO, FMETAS.PER, FSIMPLES.VENDEDOR, 4, PCARGO, PDATAINI, PDATAFIM, SYSDATE, FVALOR.GRUPO, FMETAS.IDCATCOM, PVENDEDOR, FMETAS.FATIA);
                        PCOMISSAO := 0.0;
                        EXIT;
                    ELSE
                        IF FVALOR.VLRATUAL >= FMETAS.VLRMIN AND FVALOR.VLRATUAL < FMETAS.VLRMAX THEN
                            PCOMISSAO := (FVALOR.COMISSAO/100)  * FMETAS.PER;
                                IF PVENDEDOR = FSIMPLES.VENDEDOR THEN
                                    INTTESTE := INTTESTE + PCOMISSAO;
                                END IF;
                                 INSERT INTO AD_COMISSAOSIMPLES (IDCOMSIMPLES, VLRATUAL, COMISSAO, PERCENTUAL, VENDEDOR, TIPOCLIENTE, CARGO, DTINI, DTFIN, DTCRIACAO, IDGRUPROD, IDCATCOM, VENDEDORNOTA, VLRTIPMETA) VALUES
                                ((SELECT MAX(IDCOMSIMPLES)+1 FROM AD_COMISSAOSIMPLES), FVALOR.VLRATUAL, PCOMISSAO, FMETAS.PER, FSIMPLES.VENDEDOR, 4, PCARGO, PDATAINI, PDATAFIM, SYSDATE, FVALOR.GRUPO, FMETAS.IDCATCOM, PVENDEDOR, FMETAS.FATIA); 
                            
                            PCOMISSAO := 0.0;
                            EXIT;
                        ELSIF FVALOR.VLRATUAL < FMETAS.VLRMIN THEN
                            SELECT COUNT(A.IDCATCOM), A.DESCCATCOM 
                            INTO PIDCATCOM1, PIDCATCOMDESC 
                            FROM AD_CATEGORIACOM A
                            WHERE A.IDCATCOM = 1 GROUP BY A.DESCCATCOM;
                            
                            IF PIDCATCOM1 = 0 OR PIDCATCOMDESC <> 'SEM CLASSIFICACAO' THEN
                                RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
    Na tela "Categoria de Comissão" é obrigatório ter o Item: "1 - SEM CLASSIFICACAO".</font></b><br><font>');
--                            ELSE
--
--                                    INSERT INTO AD_COMISSAOSIMPLES (IDCOMSIMPLES, VLRATUAL, COMISSAO, PERCENTUAL, VENDEDOR, TIPOCLIENTE, CARGO, DTINI, DTFIN, DTCRIACAO, IDGRUPROD, IDCATCOM, VENDEDORNOTA, VLRTIPMETA) VALUES
--                                    ((SELECT MAX(IDCOMSIMPLES)+1 FROM AD_COMISSAOSIMPLES), FVALOR.VLRATUAL, 0.0, 0.0, FSIMPLES.VENDEDOR, 4, PCARGO, PDATAINI, PDATAFIM, SYSDATE, FVALOR.GRUPO, FMETAS.IDCATCOM, PVENDEDOR, FMETAS.FATIA);

                            END IF;
                            --EXIT;
                        END IF;
                    END IF;
                -- CALCULO SOBRE A FATIA
                ELSIF FMETAS.FATIA = 1 THEN
                    IF FMETAS.VLRMAX = -1 THEN
                        PCOMISSAO := (FVALOR.COMISSAO/100) * FMETAS.PER;
                            IF PVENDEDOR = FSIMPLES.VENDEDOR THEN
                                    INTTESTE := INTTESTE + PCOMISSAO;
                                END IF;
                            INSERT INTO AD_COMISSAOSIMPLES (IDCOMSIMPLES, VLRATUAL, COMISSAO, PERCENTUAL, VENDEDOR, TIPOCLIENTE, CARGO, DTINI, DTFIN, DTCRIACAO, IDGRUPROD, IDCATCOM, VENDEDORNOTA, VLRTIPMETA) VALUES
                            ((SELECT MAX(IDCOMSIMPLES)+1 FROM AD_COMISSAOSIMPLES), FVALOR.VLRATUAL, PCOMISSAO, FMETAS.PER, FSIMPLES.VENDEDOR, 4, PCARGO, PDATAINI, PDATAFIM, SYSDATE, FVALOR.GRUPO, FMETAS.IDCATCOM, PVENDEDOR, FMETAS.FATIA);
                        PCOMISSAO := 0.0;
                        EXIT;
                    ELSE
                        IF FVALOR.COMISSAO >= FMETAS.VLRMIN AND FVALOR.COMISSAO < FMETAS.VLRMAX THEN
                            PCOMISSAO := (FVALOR.COMISSAO/100)  * FMETAS.PER;
                                IF PVENDEDOR = FSIMPLES.VENDEDOR THEN
                                    INTTESTE := INTTESTE + PCOMISSAO;
                                END IF;
                                 INSERT INTO AD_COMISSAOSIMPLES (IDCOMSIMPLES, VLRATUAL, COMISSAO, PERCENTUAL, VENDEDOR, TIPOCLIENTE, CARGO, DTINI, DTFIN, DTCRIACAO, IDGRUPROD, IDCATCOM, VENDEDORNOTA, VLRTIPMETA) VALUES
                                ((SELECT MAX(IDCOMSIMPLES)+1 FROM AD_COMISSAOSIMPLES), FVALOR.VLRATUAL, PCOMISSAO, FMETAS.PER, FSIMPLES.VENDEDOR, 4, PCARGO, PDATAINI, PDATAFIM, SYSDATE, FVALOR.GRUPO, FMETAS.IDCATCOM, PVENDEDOR, FMETAS.FATIA); 
                            
                            PCOMISSAO := 0.0;
                            EXIT;
                        ELSIF FVALOR.COMISSAO < FMETAS.VLRMIN THEN
                            SELECT COUNT(A.IDCATCOM), A.DESCCATCOM 
                            INTO PIDCATCOM1, PIDCATCOMDESC 
                            FROM AD_CATEGORIACOM A
                            WHERE A.IDCATCOM = 1 GROUP BY A.DESCCATCOM;
                            
                            IF PIDCATCOM1 = 0 OR PIDCATCOMDESC <> 'SEM CLASSIFICACAO' THEN
                                RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
    Na tela "Categoria de Comissão" é obrigatório ter o Item: "1 - SEM CLASSIFICACAO".</font></b><br><font>');
--                            ELSE
--
--                                    INSERT INTO AD_COMISSAOSIMPLES (IDCOMSIMPLES, VLRATUAL, COMISSAO, PERCENTUAL, VENDEDOR, TIPOCLIENTE, CARGO, DTINI, DTFIN, DTCRIACAO, IDGRUPROD, IDCATCOM, VENDEDORNOTA, VLRTIPMETA) VALUES
--                                    ((SELECT MAX(IDCOMSIMPLES)+1 FROM AD_COMISSAOSIMPLES), FVALOR.VLRATUAL, 0.0, 0.0, FSIMPLES.VENDEDOR, 4, PCARGO, PDATAINI, PDATAFIM, SYSDATE, FVALOR.GRUPO, FMETAS.IDCATCOM, PVENDEDOR, FMETAS.FATIA);

                                END IF;
                                --EXIT;
                            END IF;
                        END IF;
                        END IF;
                    END LOOP; 
                
            END LOOP; 
                
      END LOOP;

     P_MENSAGEM  := 'Comissão gravada com sucesso!';
END;
/
