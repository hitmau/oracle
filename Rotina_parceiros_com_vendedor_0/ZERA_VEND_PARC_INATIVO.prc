CREATE OR REPLACE PROCEDURE TOTALPRD.ZERA_VEND_PARC_INATIVO
AS
    PERFIL INT := 10403000; -- REVENDA
    PKPAI INT;
    PK INT;
    PTOTAL INT := 0;
    PGRUPOUSUARIO INT := 10; --COD GRUPO DE USUÁRIO 10 = VENDEDORES DAS LOJAS.
    
    TEMPOINATIVO INT ;
    PINATIVO INT; 
    
    TEMPOORCAMENTO INT;
    PORCAMENTO INT;
    
    TEMPOTEL INT;
    PTEL INT;   
    
    dadosINA DATE;
    dadosORC DATE;
    dadosTEL DATE;
    
    PUP VARCHAR(1000);
BEGIN
/*
    AUTOR: Mauricio Rodrigues
    Data da criação: 11/10/2018
    Descrição: Todos os parceiros inativos que estão com vendedor preferencial diferente de 0 receberão 0.
*/
--A TRIGGER ABAIXO IMPEDE DE ATUALIZAR O PARCEIRO CASO O CADASTRO ESTEJA ERRADO.
EXECUTE IMMEDIATE 'ALTER TRIGGER TRG_UPD_TGFPAR_TOTAL DISABLE';
  
SELECT MAX(INTEIRO) INTO TEMPOINATIVO FROM TSIPAR WHERE TSIPAR.CHAVE = 'TEMPPARCINATT';
SELECT MAX(INTEIRO) INTO TEMPOORCAMENTO FROM TSIPAR WHERE TSIPAR.CHAVE = 'TEMPPARORCVENTT';
SELECT MAX(INTEIRO) INTO TEMPOTEL FROM TSIPAR WHERE TSIPAR.CHAVE = 'TEMPPARTELVENTT';

SELECT NVL(MAX(ID) + 1,1)
INTO PKPAI  
FROM AD_PARCEIROSINATIVOS;

INSERT INTO AD_PARCEIROSINATIVOS (ID, DTGRAVACAO) VALUES
                             (PKPAI, SYSDATE);

    FOR IPAR IN (SELECT PARC.CODPARC, PARC.CODVEND, DTULTIMAVENDA(PARC.CODPARC) AS DT
                FROM TGFPAR PARC
                WHERE PARC.CODVEND <> 0
                  AND PARC.CODPARC NOT IN (SELECT EMP.CODEMP FROM TSIEMP EMP)
                  AND PARC.CODTIPPARC = 10403000
                  AND PARC.CLIENTE = 'S')
    LOOP
 
    --VERIFICA SE CLIENTE ESTÁ INATIVO
    SELECT COUNT(CODPARC)--, CODVEND, DTULTIMAVENDA(CODPARC) AS DT
    INTO PINATIVO
    FROM (
        SELECT 
              A.CODPARC
             , A.CODVEND
        FROM (SELECT DISTINCT P.CODPARC
                     , P.CODVEND
               FROM TGFPAR P
               WHERE (CASE WHEN (SELECT COUNT(1) 
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
                                                                   AND CAB.STATUSNFE <> 'E') ELSE SYSDATE + 10 END) <= SYSDATE - TEMPOINATIVO
                               --VERIFICA SE EXISTE AGENTE E ELIMINA DA LISTA 
                               AND P.CODPARC NOT IN (SELECT DISTINCT VEN.CODPARC FROM TGFCCM CCM INNER JOIN TGFVEN VEN ON (CCM.CODVEND = VEN.CODVEND)
                                                                                           INNER JOIN TGFCAB CAB ON (CCM.NUNOTA=CAB.NUNOTA)
                                                   WHERE CAB.DTFATUR >= SYSDATE - TEMPOINATIVO
                                                     AND CAB.STATUSNFE = 'A')
                       AND P.CLIENTE = 'S'
                       AND P.CODTIPPARC = 10403000--PERFIL
                       AND P.CODVEND <> 0
                       AND P.CODPARC NOT IN (SELECT EMP.CODEMP FROM TSIEMP EMP)
           ORDER BY P.CODPARC) A)
       WHERE CODPARC = IPAR.CODPARC
         AND CODPARC NOT IN (SELECT CON.CODPARC FROM TCSCON CON WHERE CON.CODPARC = CODPARC AND CON.ATIVO = 'S');
        
    ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

    --VERIFICA SE EXISTE ORÇAMENTO
    SELECT COUNT(*)
    INTO PORCAMENTO
    FROM TGFPAR P
    WHERE P.CODPARC = IPAR.CODPARC
         AND (CASE WHEN (SELECT COUNT(1) 
                    FROM TGFCAB CAB 
                    WHERE CAB.CODPARC = P.CODPARC
                        AND CAB.CODTIPOPER IN (3010, 3011,3012,3200,3210)
                        AND CAB.STATUSNOTA = 'L') <> 0 THEN (SELECT MAX(CAB.DTFATUR)
                                                        FROM TGFCAB CAB 
                                                        WHERE CAB.CODPARC = P.CODPARC
                                                            AND CAB.CODTIPOPER IN (3010, 3011,3012,3200,3210)
                                                            AND CAB.STATUSNOTA = 'L') ELSE SYSDATE + 10 END) >= SYSDATE - TEMPOORCAMENTO
                    --VERIFICA SE EXISTE AGENTE E ELIMINA DA LISTA 
                    AND P.CODPARC NOT IN (SELECT DISTINCT VEN.CODPARC FROM TGFCCM CCM INNER JOIN TGFVEN VEN ON (CCM.CODVEND = VEN.CODVEND)
                                                                                INNER JOIN TGFCAB CAB ON (CCM.NUNOTA=CAB.NUNOTA)
                                        WHERE CAB.DTFATUR >= SYSDATE - TEMPOORCAMENTO
                                          AND CAB.STATUSNFE = 'A')
            AND P.CLIENTE = 'S'
            --AND P.CODTIPPARC = 10403000--PERFIL
            AND P.CODVEND <> 0
            AND P.CODPARC NOT IN (SELECT CON.CODPARC FROM TCSCON CON WHERE CON.CODPARC = P.CODPARC AND CON.ATIVO = 'S')
            AND P.CODPARC NOT IN (SELECT EMP.CODEMP FROM TSIEMP EMP);
            
    
    -------------------------------------------------------------------------------------------------------------------------------------------------

    --VERIFICA SE EXISTE AGENDA
    SELECT COUNT(DISTINCT TEL.CODPARC)
    INTO PTEL
    FROM TGFTEL TEL
    WHERE TEL.CODPARC = IPAR.CODPARC
     AND TEL.CODUSU IN (SELECT USU.CODUSU FROM TSIUSU USU WHERE USU.CODGRUPO = PGRUPOUSUARIO)
     AND (CASE WHEN (SELECT COUNT(1) 
                    FROM TGFTEL TELS 
                    WHERE TELS.CODPARC = IPAR.CODPARC
                        AND TELS.PENDENTE = 'S') <> 0 THEN (SELECT MAX(TELA.DHCHAMADA)
                                                        FROM TGFTEL TELA
                                                        WHERE TELA.CODPARC = IPAR.CODPARC
                                                          AND TELA.PENDENTE = 'S'
                                                          AND (SELECT COUNT(H.CODHIST) FROM TGFHTE H WHERE H.AD_TP_RESULTADO = 1 AND TEL.CODHIST = H.CODHIST) = 1) ELSE SYSDATE - 100 END) >= SYSDATE - TEMPOTEL
                    --VERIFICA SE EXISTE AGENTE E ELIMINA DA LISTA 
     AND TEL.CODPARC NOT IN (SELECT DISTINCT VEN.CODPARC FROM TGFCCM CCM INNER JOIN TGFVEN VEN ON (CCM.CODVEND = VEN.CODVEND)
                                                                   INNER JOIN TGFCAB CAB ON (CCM.NUNOTA=CAB.NUNOTA)
                           WHERE CAB.DTFATUR >= SYSDATE - TEMPOTEL
                            AND CAB.STATUSNFE = 'A')
     AND TEL.CODPARC NOT IN (SELECT CON.CODPARC FROM TCSCON CON WHERE CON.CODPARC = IPAR.CODPARC AND CON.ATIVO = 'S');
    
    --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    --PORCAMENTO, PTEL, PINATIVO
    PUP := 0;
    IF PINATIVO = 1 AND PORCAMENTO = 0 AND PTEL = 0 THEN

    SELECT DTULTIMAVENDA(IPAR.CODPARC), DTULTORCPED(IPAR.CODPARC), DTULTTELEMARKETING(IPAR.CODPARC)
    INTO dadosINA, dadosORC, dadosTEL
    FROM DUAL;
--    
--    PUP := 'V: ' || to_char(dadosINA) || ' OP: ' || to_char(dadosORC) || ' Mkt: ' ||  to_char(dadosTEL);

                SELECT NVL(MAX(IDPARC) + 1,1) 
                INTO PK
                FROM AD_PARCINATIVOSFILHO
                WHERE ID = PKPAI;
                
                --INSERE NA TELA "PARCEIROS INATIVADOS AUTOMATICAMENTE"
                INSERT INTO AD_PARCINATIVOSFILHO (ID, IDPARC, CODPARC, CODVEND, DTULTCOMPRA, DTGRAVACAO, UP, ORCPED, TEL) VALUES
                (PKPAI, PK, IPAR.CODPARC, IPAR.CODVEND, IPAR.DT, SYSDATE, dadosINA, dadosORC, dadosTEL);
                
                --ATUALIZAS O PARCEIRO PARA VENDEDOR 0
                --UPDATE TGFPAR SET CODVEND = 0 WHERE CODPARC = IPAR.CODPARC;
                
                PTOTAL := PTOTAL + 1;
    END IF;

 END LOOP;         
 --ATUALIZA FORMULÁRIO PRINCIPAL COM O TOTAL DOS REGISTROS INSERIDOS (TOTAL DE PARCEIROS COM VENDEDOR ZERADO).
 UPDATE AD_PARCEIROSINATIVOS SET TOTAL = PTOTAL WHERE ID = PKPAI;

EXECUTE IMMEDIATE 'ALTER TRIGGER TRG_UPD_TGFPAR_TOTAL ENABLE';
END;
/
