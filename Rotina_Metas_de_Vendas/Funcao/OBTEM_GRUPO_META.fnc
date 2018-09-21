CREATE OR REPLACE FUNCTION TOTALPRD.OBTEM_GRUPO_META(P_NIVEL_META IN INT, P_GRUPO_PROD IN INT, P_DTINI IN DATE, P_DTFIN IN DATE) 
RETURN INT
IS 
  P_GRUPO NUMBER;
BEGIN

    IF P_NIVEL_META IS NOT NULL THEN
        SELECT (CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = (SELECT ID FROM (SELECT ROW_NUMBER() OVER(ORDER BY G2.ID ASC) AS I, G2.ID FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID) WHERE  G1.DTVIGOR BETWEEN P_DTINI AND P_DTFIN AND G1.ATIVO = 'S' GROUP BY G2.ID) WHERE I = P_NIVEL_META)  AND  G2.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))) IS NOT NULL  
                     THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = (SELECT ID FROM (SELECT ROW_NUMBER() OVER(ORDER BY G2.ID ASC) AS I, G2.ID FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID) WHERE  G1.DTVIGOR BETWEEN P_DTINI AND P_DTFIN AND G1.ATIVO = 'S' GROUP BY G2.ID) WHERE I = P_NIVEL_META)  AND  G2.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))
                     ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = (SELECT ID FROM (SELECT ROW_NUMBER() OVER(ORDER BY G2.ID ASC) AS I, G2.ID FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID) WHERE  G1.DTVIGOR BETWEEN P_DTINI AND P_DTFIN AND G1.ATIVO = 'S' GROUP BY G2.ID) WHERE I = P_NIVEL_META)  AND  G2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))) IS NOT NULL
                               THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = (SELECT ID FROM (SELECT ROW_NUMBER() OVER(ORDER BY G2.ID ASC) AS I, G2.ID FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID) WHERE  G1.DTVIGOR BETWEEN P_DTINI AND P_DTFIN AND G1.ATIVO = 'S' GROUP BY G2.ID) WHERE I = P_NIVEL_META)  AND  G2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))
                               ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = (SELECT ID FROM (SELECT ROW_NUMBER() OVER(ORDER BY G2.ID ASC) AS I, G2.ID FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID) WHERE  G1.DTVIGOR BETWEEN P_DTINI AND P_DTFIN AND G1.ATIVO = 'S' GROUP BY G2.ID) WHERE I = P_NIVEL_META)  AND  G2.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))) IS NOT NULL
                                         THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = (SELECT ID FROM (SELECT ROW_NUMBER() OVER(ORDER BY G2.ID ASC) AS I, G2.ID FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID) WHERE  G1.DTVIGOR BETWEEN P_DTINI AND P_DTFIN AND G1.ATIVO = 'S' GROUP BY G2.ID) WHERE I = P_NIVEL_META)  AND  G2.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))
                                         ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = (SELECT ID FROM (SELECT ROW_NUMBER() OVER(ORDER BY G2.ID ASC) AS I, G2.ID FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID) WHERE  G1.DTVIGOR BETWEEN P_DTINI AND P_DTFIN AND G1.ATIVO = 'S' GROUP BY G2.ID) WHERE I = P_NIVEL_META)  AND  G2.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))) IS NOT NULL
                                                   THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = (SELECT ID FROM (SELECT ROW_NUMBER() OVER(ORDER BY G2.ID ASC) AS I, G2.ID FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID) WHERE  G1.DTVIGOR BETWEEN P_DTINI AND P_DTFIN AND G1.ATIVO = 'S' GROUP BY G2.ID) WHERE I = P_NIVEL_META)  AND  G2.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))
                                                   ELSE CASE WHEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = (SELECT ID FROM (SELECT ROW_NUMBER() OVER(ORDER BY G2.ID ASC) AS I, G2.ID FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID) WHERE  G1.DTVIGOR BETWEEN P_DTINI AND P_DTFIN AND G1.ATIVO = 'S' GROUP BY G2.ID) WHERE I = P_NIVEL_META)  AND  G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))) IS NOT NULL
                                                             THEN TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = (SELECT ID FROM (SELECT ROW_NUMBER() OVER(ORDER BY G2.ID ASC) AS I, G2.ID FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID) WHERE  G1.DTVIGOR BETWEEN P_DTINI AND P_DTFIN AND G1.ATIVO = 'S' GROUP BY G2.ID) WHERE I = P_NIVEL_META)  AND  G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD)))))))
                                                             ELSE TO_CHAR((SELECT G2.CODGRUPOPROD FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID)  WHERE G1.ID = (SELECT ID FROM (SELECT ROW_NUMBER() OVER(ORDER BY G2.ID ASC) AS I, G2.ID FROM AD_GRUPROSPROD G1 INNER JOIN AD_GRUPOSPRODUSU G2 ON (G1.ID=G2.ID) WHERE  G1.DTVIGOR BETWEEN P_DTINI AND P_DTFIN AND G1.ATIVO = 'S' GROUP BY G2.ID) WHERE I = P_NIVEL_META)  AND  G2.CODGRUPOPROD = (SELECT GRU4.CODGRUPAI FROM TGFGRU GRU4 WHERE GRU4.CODGRUPOPROD = (SELECT GRU5.CODGRUPAI FROM TGFGRU GRU5 WHERE GRU5.CODGRUPOPROD = (SELECT GRU3.CODGRUPAI FROM TGFGRU GRU3 WHERE GRU3.CODGRUPOPROD = (SELECT GRU2.CODGRUPAI FROM TGFGRU GRU2 WHERE GRU2.CODGRUPOPROD = (SELECT GRU.CODGRUPAI FROM TGFGRU GRU WHERE GRU.CODGRUPOPROD = (SELECT CODGRUPOPROD FROM TGFGRU WHERE CODGRUPOPROD = GG.CODGRUPOPROD))))))))
                                                        END
                                                 
                                               END 
                                           
                                    END 
                         
                          END 
                END) AS GRUPO 
        INTO P_GRUPO 
        FROM TGFGRU GG 
        WHERE GG.CODGRUPOPROD = P_GRUPO_PROD;
    ELSE
        P_GRUPO := 0;
    END IF;
    
  RETURN P_GRUPO; 
END;
/
