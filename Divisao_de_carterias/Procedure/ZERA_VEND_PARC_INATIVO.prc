CREATE OR REPLACE PROCEDURE TOTALPRD."ZERA_VEND_PARC_INATIVO" 
AS
    PERFIL INT := 10403000; -- REVENDA
    PKPAI INT;
    PK INT;
BEGIN
/*
    AUTOR: Mauricio Rodrigues
    Data da criação: 11/10/2018
    Descrição: Todos os parceiros inativos que estão com vendedor preferencial diferente de 0 receberão 0.
*/
--A TRIGGER ABAIXO IMPEDE DE ATUALIZAR O PARCEIRO CASO O CADASTRO ESTEJA ERRADO.
EXECUTE IMMEDIATE 'ALTER TRIGGER TRG_UPD_TGFPAR_TOTAL DISABLE';
  
SELECT NVL(MAX(ID) + 1,1)
INTO PKPAI  
FROM AD_PARCEIROSINATIVOS;

INSERT INTO AD_PARCEIROSINATIVOS (ID, DTGRAVACAO) VALUES
                             (PKPAI, SYSDATE);

 FOR IPAR IN (SELECT CODPARC, CODVEND, DTULTIMAVENDA(CODPARC) AS DT
            FROM (
                SELECT 
                      A.CODPARC
                     , A.CODVEND
                FROM (SELECT DISTINCT P.CODPARC
                             , P.CODVEND
                             , AD.PERC
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
                                                                           AND CAB.STATUSNFE <> 'E') ELSE SYSDATE + 10 END) <= SYSDATE - 90
                               AND P.CLIENTE = 'S'
                               AND AD.NOVENTA = 'N'
                               AND P.CODTIPPARC = PERFIL
                               AND P.CODVEND <> 0
                               AND P.CODPARC NOT IN (SELECT EMP.CODEMP FROM TSIEMP EMP)
                   ORDER BY AD.PERC, P.CODPARC) A)) 
 LOOP
    SELECT NVL(MAX(IDPARC) + 1,1) 
    INTO PK
    FROM AD_PARCINATIVOSFILHO
    WHERE ID = 1;
    
    
    --INSERE NA TELA "PARCEIROS INATIVADOS AUTOMATICAMENTE"
    INSERT INTO AD_PARCINATIVOSFILHO (ID, IDPARC, CODPARC, CODVEND, DTULTCOMPRA, DTGRAVACAO) VALUES
    (PKPAI, PK, IPAR.CODPARC, IPAR.CODVEND, IPAR.DT, SYSDATE);
    
    --ATUALIZAS O PARCEIRO PARA VENDEDOR 0
    --UPDATE TGFPAR SET CODVEND = 0 WHERE CODPARC = IPAR.CODPARC;
    
 END LOOP;         

EXECUTE IMMEDIATE 'ALTER TRIGGER TRG_UPD_TGFPAR_TOTAL ENABLE';
END;
/
