CREATE OR REPLACE FUNCTION TOTALPRD.META_TOTAL_MRS(P_EMP IN INT,P_VouM IN INT, P_DTINI IN DATE, P_DTFIN IN DATE) 
RETURN INT
IS 
  P_TOTAL FLOAT;
  PID INT := 1;
  PFIM INT := 0;
  PFIM2 INT := 0;
  PVLR_EMP FLOAT;
  PVLR_MET FLOAT;
  PVLR_ALV FLOAT;
BEGIN
    WHILE PFIM <= 0
    LOOP
              SELECT SUM(VLR_ATUAL) AS VLR_EMP, SUM(META) AS VLR_META, (SUM(VLR_ATUAL)-SUM(META)) * (-1) AS ALVO
              INTO PVLR_EMP, PVLR_MET, PVLR_ALV
              FROM (
                  SELECT SUM(((ITE.VLRTOT - ITE.VLRDESC - ITE.VLRREPRED + ITE.VLRSUBST + ITE.VLRIPI)  * VCA.INDITENSBRUTO) * CASE WHEN TOP.BONIFICACAO = 'S' THEN 0 ELSE 1 END * TOP.GOLDEV ) AS VLR_ATUAL
                      , 0 AS META
                  FROM TGFCAB CAB INNER JOIN TGFITE ITE ON (CAB.NUNOTA = ITE.NUNOTA)
                                  INNER JOIN TGFPRO PRO ON (ITE.CODPROD = PRO.CODPROD)
                                  INNER JOIN VGFCAB VCA ON (CAB.NUNOTA = VCA.NUNOTA)
                                  INNER JOIN TGFTOP TOP ON (CAB.CODTIPOPER = TOP.CODTIPOPER AND CAB.DHTIPOPER = TOP.DHALTER AND TOP.GOLSINAL = -1)
                  WHERE CAB.CODTIPOPER IN (3200)
                    AND CAB.STATUSNFE = 'A'
                    AND OBTEM_GRUPO_META(PID, PRO.CODGRUPOPROD, P_DTINI, P_DTFIN) IN 
                        (SELECT CODGRUPOPROD
                         FROM AD_GRUPOSPRODUSU GR INNER JOIN AD_GRUPROSPROD GG ON (GR.ID = GG.ID)
                         WHERE GG.DTVIGOR BETWEEN P_DTINI AND P_DTFIN
                           AND GG.ID = ((SELECT ID FROM (SELECT ROW_NUMBER() OVER(ORDER BY G2.ID ASC) AS I, G2.ID
                              FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  
                              WHERE  G1.DTVIGOR BETWEEN P_DTINI AND P_DTFIN
                                   AND G1.ATIVO = 'S'
                              GROUP BY G2.ID)
                              WHERE I = PID)))
                    AND CAB.CODEMP IN (P_EMP)
                    AND TRUNC(CAB.DTFATUR) BETWEEN P_DTINI AND P_DTFIN
              
                  UNION ALL
              
                      SELECT 0 AS VLR_ATUAL, SUM(G2.SUGESTAO) AS META
                              FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)
                              WHERE G1.ID = (SELECT ID FROM (SELECT ROW_NUMBER() OVER(ORDER BY G2.ID ASC) AS I, G2.ID
                              FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  
                              WHERE  G1.DTVIGOR BETWEEN P_DTINI AND P_DTFIN
                                   AND G1.ATIVO = 'S'
                              GROUP BY G2.ID)
                              WHERE I = PID));
    
        IF PVLR_ALV <= 0 THEN
            PID := PID + 1;
            PFIM2 := 1;
        ELSIF PVLR_ALV IS NULL THEN
            PFIM := 1;
            PFIM2 := 0;
        ELSE
            PFIM := 1;
            PFIM2 := 1;
        END IF;
        
        IF PVLR_ALV = 0 AND PVLR_EMP = 0 AND PVLR_MET = 0 THEN
            PFIM := 2;
            PFIM2 := 0;
        END IF;
        
        IF PFIM2 = 1 THEN
            IF P_VouM = 1 THEN
                P_TOTAL := PVLR_MET;
            ELSIF P_VouM = 0 THEN
                P_TOTAL := PVLR_EMP;
            END IF;
            PFIM2 := 0;
        END IF;
        
    END LOOP;
    
    
    
  RETURN P_TOTAL; 
END;
/