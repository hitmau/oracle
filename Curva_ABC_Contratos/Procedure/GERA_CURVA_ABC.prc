CREATE OR REPLACE PROCEDURE TOTALPRD."GERA_CURVA_ABC" (
       P_CODUSU NUMBER,        -- Código do usuário logado
       P_IDSESSAO VARCHAR2,    -- Identificador da execução. Serve para buscar informações dos parâmetros/campos da execução.
       P_QTDLINHAS NUMBER,     -- Informa a quantidade de registros selecionados no momento da execução.
       P_MENSAGEM OUT VARCHAR2 -- Caso seja passada uma mensagem aqui, ela será exibida como uma informação ao usuário.
) AS
       FIELD_ID NUMBER;
       VLRNOVO FLOAT := 0.0;
       ZERADO INT;
       STATUS FLOAT;
       ABC VARCHAR(1);
BEGIN

    /*
        Autor: Mauricio Rodrigues
        Data: 02/03/2018
        Descrição: Essa procedure varre todos os contratos ativos, juntanto 2 
                   ou mais contratos do mesmo parceiro ordena e define por curva ABC.
                   Salva o resultado na tabela AD_ABC
    */

        DELETE FROM AD_ABC WHERE ID <> 1;

       FOR I IN (SELECT ROW_NUMBER() OVER(ORDER BY TOTAL ASC) AS RowSD
                      , CODPARC
                      , VALOR
                      , TOTAL
                      , ROUND(VALOR/TOTAL,5) AS PERC
                    FROM (SELECT DISTINCT CON.CODPARC,
                                (SELECT SUM((SELECT ROUND(SUM(P.VALOR * PSC.NUMUSUARIOS)) 
                                             FROM TCSPRE P, TCSPSC PSC 
                                             WHERE P.NUMCONTRATO = PSC.NUMCONTRATO 
                                               AND P.CODPROD=PSC.CODPROD 
                                               AND P.NUMCONTRATO = CON.NUMCONTRATO)) AS VALOR 
                         FROM TCSCON CON
                         WHERE CON.ATIVO = 'S'
                          AND (SELECT ROUND(SUM(P.VALOR * PSC.NUMUSUARIOS)) FROM TCSPRE P, TCSPSC PSC WHERE P.NUMCONTRATO = PSC.NUMCONTRATO AND P.CODPROD=PSC.CODPROD AND P.NUMCONTRATO = CON.NUMCONTRATO) IS NOT NULL) AS TOTAL
                        , SUM((SELECT ROUND(SUM(P.VALOR * PSC.NUMUSUARIOS)) FROM TCSPRE P, TCSPSC PSC WHERE P.NUMCONTRATO = PSC.NUMCONTRATO AND P.CODPROD=PSC.CODPROD AND P.NUMCONTRATO = CON.NUMCONTRATO)) AS VALOR 
                    FROM TCSCON CON
                    WHERE CON.ATIVO = 'S'
                        AND (SELECT ROUND(SUM(P.VALOR * PSC.NUMUSUARIOS)) FROM TCSPRE P, TCSPSC PSC WHERE P.NUMCONTRATO = PSC.NUMCONTRATO AND P.CODPROD=PSC.CODPROD AND P.NUMCONTRATO = CON.NUMCONTRATO) IS NOT NULL
                    GROUP BY CON.CODPARC
                    ORDER BY VALOR DESC, CODPARC)
                    ORDER BY PERC) -- Este loop permite obter o valor de campos dos registros envolvidos na execução.
       LOOP                    
       
           VLRNOVO := VLRNOVO + I.PERC;
           IF VLRNOVO <= 1 THEN
                STATUS := 1;
                ABC := 'A';
           END IF;
           IF VLRNOVO < 0.90 THEN
                STATUS := 0.90;
                ABC := 'B';
           END IF;
           IF VLRNOVO < 0.65 THEN
                STATUS := 0.65;
                ABC := 'C';
           END IF;
     
            INSERT INTO AD_ABC (ID, INDECE, CODPARC, VLRCONTRATO, VLRTOTAL, PERC, PERCACUMULADO, VLR, INTERVALO) VALUES
            ((SELECT MAX(ID)+1 FROM AD_ABC) ,(SELECT MAX(ID)+1 FROM AD_ABC),I.CODPARC, I.VALOR, I.TOTAL, I.PERC, VLRNOVO, STATUS, ABC);

       END LOOP;

END;
/
