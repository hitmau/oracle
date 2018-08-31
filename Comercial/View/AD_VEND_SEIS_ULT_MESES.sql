/* Formatted on 31/08/2018 13:09:43 (QP5 v5.287) */
DROP VIEW TOTALPRD.AD_VEND_SEIS_ULT_MESES;


CREATE OR REPLACE FORCE VIEW TOTALPRD.AD_VEND_SEIS_ULT_MESES
(
   CODVEND,
   MES,
   DATA,
   ORDEM,
   CODPARC
)
AS
   /*
       AUTOR:
       DATA:
       DESCRIÇÃO:
   */

   SELECT MESES.CODVEND,
          MES_1 AS MES,
          dt AS DATA,
          ORDEM,
          CODPARC
   FROM (
         SELECT MES1.CODVEND,
                NVL (SUM (MES1.MES_1), 0) AS MES_1,
                dt,
                ORDEM,
                CODPARC
         FROM (----------------------------------------------------------------------------------------------------------------------------------------------MÊS ATUAL 1
         ------------------------------------------------------------------------------------------------------------------------------------ (COM AGENTE) UNION ALL 1.1
               SELECT CAB.CODVEND,
                      CAB.CODPARC,
                      NVL (SUM (ROUND (ITE1.PRECOBASE * ITE1.QTDNEG, 2)),0) AS MES_1,
                      (TO_CHAR (ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (SYSDATE, 'MONTH'),'DD/MM/YY'),0),'MONTH'),'DD/MM/YY'),0),'MM/YYYY'))AS dt,
                      1 AS ORDEM
               FROM TGFCAB CAB INNER JOIN TGFITE ITE1 ON (CAB.NUNOTA = ITE1.NUNOTA)
               WHERE CAB.TIPMOV = 'V'
               --AND CAB.CODVEND IN :ACODVEND
                 AND CAB.STATUSNOTA = 'L'
                 AND CAB.AD_EXEC IS NOT NULL
                 AND ITE1.USOPROD IN ('R', 'S')
                 AND TRUNC(CAB.DTFATUR) BETWEEN ADD_MONTHS (TO_DATE (TRUNC (SYSDATE,'MONTH'),'DD/MM/YY'),0)
                                         AND SYSDATE
                 AND CAB.CODTIPVENDA NOT IN (16, 90)
                 AND CAB.CODTIPOPER IN (SELECT CODTIPOPER FROM AD_TIPVENDEV WHERE TIPMOV = 'V')
               --AND CAB.CODPARC = :ACODPARC
               GROUP BY CAB.CODVEND, CAB.CODPARC
            UNION ALL ----------------------------------------------------------------------------------------------------------------------0 (SEM AGENTE) UNION ALL 1.2
               SELECT CAB.CODVEND,
                      CAB.CODPARC,
                      NVL (SUM (ROUND (ITE1.VLRTOT, 2)), 0) AS MES_1,
                      (TO_CHAR (ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (SYSDATE, 'MONTH'),'DD/MM/YY'),0),'MONTH'),'DD/MM/YY'),0),'MM/YYYY')) AS dt,
                      1 AS ORDEM
               FROM TGFCAB CAB INNER JOIN TGFITE ITE1 ON (CAB.NUNOTA = ITE1.NUNOTA)
                               INNER JOIN TGFVEN VEN1 ON (CAB.CODVEND = VEN1.CODVEND)
               WHERE CAB.TIPMOV = 'V'
               --AND CAB.CODVEND IN :ACODVEND
                 AND CAB.STATUSNOTA = 'L'
                 AND CAB.AD_EXEC IS NULL
                 AND ITE1.USOPROD IN ('R', 'S')
                 AND TRUNC(CAB.DTFATUR) BETWEEN ADD_MONTHS (TO_DATE (TRUNC (SYSDATE,'MONTH'),'DD/MM/YY'),0)
                                         AND SYSDATE
                 AND CAB.CODTIPVENDA NOT IN (16, 90)
                 AND CAB.CODTIPOPER IN (SELECT CODTIPOPER FROM AD_TIPVENDEV WHERE TIPMOV = 'V')
               --AND CAB.CODPARC = :ACODPARC
               GROUP BY CAB.CODVEND, CAB.CODPARC
            UNION ALL ------------------------------------------------------------------------------------------------------------------------ (DEVOLUÇÃO) UNION ALL 1.3
               SELECT CAB.CODVEND,
                      CAB.CODPARC,
                      NVL (SUM (ROUND (ITE.VLRTOT, 2) * (-1)), 0) AS MES_1,
                      (TO_CHAR (ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (SYSDATE, 'MONTH'),'DD/MM/YY'),0),'MONTH'),'DD/MM/YY'),0),'MM/YYYY')) AS dt,
                      1 AS ORDEM
               FROM TGFCAB CAB INNER JOIN TGFITE ITE ON (ITE.NUNOTA = CAB.NUNOTA)
                               INNER JOIN TGFTOP TOP ON (CAB.CODTIPOPER = TOP.CODTIPOPER)
                               INNER JOIN TGFPAR PAR ON (CAB.CODPARC = PAR.CODPARC)
                               INNER JOIN TGFTPV TPV ON (CAB.CODTIPVENDA = TPV.CODTIPVENDA)
                               INNER JOIN TGFVEN VEN ON (CAB.CODVEND = VEN.CODVEND)
               WHERE CAB.DHTIPOPER = TOP.DHALTER
               --AND CAB.CODVEND IN :ACODVEND
                 AND CAB.DHTIPVENDA = TPV.DHALTER
                 AND ITE.USOPROD IN ('R', 'S')
                 AND TRUNC(CAB.DTFATUR) BETWEEN ADD_MONTHS (TO_DATE (TRUNC (SYSDATE,'MONTH'),'DD/MM/YY'),0)
                                         AND SYSDATE
                 AND CAB.CODTIPOPER IN (SELECT CODTIPOPER FROM AD_TIPVENDEV WHERE TIPMOV = 'D')
              --AND CAB.CODPARC = :ACODPARC
               GROUP BY CAB.CODVEND, CAB.CODPARC) MES1
         GROUP BY MES1.CODVEND,
                    dt,
                    ORDEM,
                    CODPARC
      UNION ALL --------------------------------------------------------------------------------------------------------------------------------------------------MÊS 2
      -------------------------------------------------------------------------------------------------------------------------------------- (COM AGENTE) UNION ALL 2.1
         SELECT MES1.CODVEND,
                NVL (SUM (MES1.MES_1), 0) AS MES_1,
                dt,
                ORDEM,
                CODPARC
         FROM (
               SELECT CAB.CODVEND,
                      CAB.CODPARC,
                      NVL (SUM (ROUND (ITE1.PRECOBASE * ITE1.QTDNEG, 2)),0)AS MES_1,
                      (TO_CHAR (ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (SYSDATE, 'MONTH'),'DD/MM/YY'),0),'MONTH'),'DD/MM/YY'),-1),'MM/YYYY'))AS dt,
                      2 AS ORDEM
               FROM TGFCAB CAB INNER JOIN TGFITE ITE1 ON (CAB.NUNOTA = ITE1.NUNOTA)
                               INNER JOIN TGFPAR PAR1 ON (CAB.CODPARC = PAR1.CODPARC)
                               INNER JOIN TGFVEN VEN1 ON (CAB.CODVEND = VEN1.CODVEND)
               WHERE CAB.TIPMOV = 'V'
               --AND CAB.CODVEND IN :ACODVEND
                 AND CAB.STATUSNOTA = 'L'
                 AND CAB.AD_EXEC IS NOT NULL
                 AND ITE1.USOPROD IN ('R', 'S')
                 AND TRUNC(CAB.DTFATUR) BETWEEN ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (SYSDATE,'MONTH'),'DD/MM/YY'),0),'MONTH'),'DD/MM/YY'),-1)
                                         AND ADD_MONTHS (TO_DATE (LAST_DAY (SYSDATE),'DD/MM/YY'),-1)
                 AND CAB.CODTIPVENDA NOT IN (16, 90)
                 AND CAB.CODTIPOPER IN (SELECT CODTIPOPER FROM AD_TIPVENDEV WHERE TIPMOV = 'V')
               --AND CAB.CODPARC = :ACODPARC
               GROUP BY CAB.CODVEND, CAB.CODPARC
            UNION ALL ---------------------------------------------------------------------------------------------------------------------0 (SEM AGENTE) UNION ALL 2.2
               SELECT CAB.CODVEND,
                      CAB.CODPARC,
                      NVL (SUM (ROUND (ITE1.VLRTOT, 2)), 0) AS MES_1,
                      (TO_CHAR (ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (SYSDATE, 'MONTH'),'DD/MM/YY'),0),'MONTH'),'DD/MM/YY'),-1),'MM/YYYY')) AS dt,
                      2 AS ORDEM
                FROM TGFCAB CAB INNER JOIN TGFITE ITE1 ON (CAB.NUNOTA = ITE1.NUNOTA)
                                INNER JOIN TGFPAR PAR1 ON (CAB.CODPARC = PAR1.CODPARC)
                                INNER JOIN TGFVEN VEN1 ON (CAB.CODVEND = VEN1.CODVEND)
               WHERE CAB.TIPMOV = 'V'
                 --AND CAB.CODVEND IN :ACODVEND
                 AND CAB.STATUSNOTA = 'L'
                 AND CAB.AD_EXEC IS NULL
                 AND ITE1.USOPROD IN ('R', 'S')
                 AND TRUNC(CAB.DTFATUR) BETWEEN ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (SYSDATE,'MONTH'),'DD/MM/YY'),0),'MONTH'),'DD/MM/YY'),-1)
                                         AND ADD_MONTHS (TO_DATE (LAST_DAY (SYSDATE),'DD/MM/YY'),-1)
                 AND CAB.CODTIPVENDA NOT IN (16, 90)
                 AND CAB.CODTIPOPER IN (SELECT CODTIPOPER FROM AD_TIPVENDEV WHERE TIPMOV = 'V')
               --AND CAB.CODPARC = :ACODPARC
               GROUP BY CAB.CODVEND, CAB.CODPARC
            UNION ALL ------------------------------------------------------------------------------------------------------------------------ (DEVOLUÇÃO) UNION ALL 2.3
               SELECT CAB.CODVEND,
                      CAB.CODPARC,
                      NVL (SUM (ROUND (ITE.VLRTOT, 2) * (-1)), 0) AS MES_1,
                      (TO_CHAR (ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (SYSDATE, 'MONTH'),'DD/MM/YY'),0),'MONTH'),'DD/MM/YY'),-1),'MM/YYYY'))AS dt,                      
                      2 AS ORDEM
               FROM TGFCAB CAB INNER JOIN TGFITE ITE ON (ITE.NUNOTA = CAB.NUNOTA)
                               INNER JOIN TGFTOP TOP ON (CAB.CODTIPOPER = TOP.CODTIPOPER)
                               INNER JOIN TGFPAR PAR ON (CAB.CODPARC = PAR.CODPARC)
                               INNER JOIN TGFTPV TPV ON (CAB.CODTIPVENDA = TPV.CODTIPVENDA)
                               INNER JOIN TGFVEN VEN ON (CAB.CODVEND = VEN.CODVEND)
               WHERE CAB.DHTIPOPER = TOP.DHALTER
               --AND CAB.CODVEND IN :ACODVEND
                 AND CAB.DHTIPVENDA = TPV.DHALTER
                 AND ITE.USOPROD IN ('R', 'S')
                 AND TRUNC(CAB.DTFATUR) BETWEEN ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (SYSDATE,'MONTH'),'DD/MM/YY'),0),'MONTH'),'DD/MM/YY'),-1)
                                                AND ADD_MONTHS (TO_DATE (LAST_DAY (SYSDATE),'DD/MM/YY'),-1)
                 AND CAB.CODTIPOPER IN (SELECT CODTIPOPER FROM AD_TIPVENDEV WHERE TIPMOV = 'D')
               --AND CAB.CODPARC = :ACODPARC
               GROUP BY CAB.CODVEND, CAB.CODPARC) MES1
         GROUP BY MES1.CODVEND,
                  dt,
                  ORDEM,
                  CODPARC
      UNION ALL --------------------------------------------------------------------------------------------------------------------------------------------------MÊS 3
      -------------------------------------------------------------------------------------------------------------------------------------- (COM AGENTE) UNION ALL 3.1
         SELECT MES1.CODVEND,
                NVL (SUM (MES1.MES_1), 0) AS MES_1,
                dt,
                ORDEM,
                CODPARC
         FROM (  
               SELECT CAB.CODVEND,
                      CAB.CODPARC,
                      NVL (SUM (ROUND (ITE1.PRECOBASE * ITE1.QTDNEG, 2)),0)AS MES_1,
                      (TO_CHAR (ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (SYSDATE, 'MONTH'),'DD/MM/YY'),0),'MONTH'),'DD/MM/YY'),-2),'MM/YYYY')) AS dt,
                       3 AS ORDEM
               FROM TGFCAB CAB INNER JOIN TGFITE ITE1 ON (CAB.NUNOTA = ITE1.NUNOTA)
                               INNER JOIN TGFPAR PAR1 ON (CAB.CODPARC = PAR1.CODPARC)
                               INNER JOIN TGFVEN VEN1 ON (CAB.CODVEND = VEN1.CODVEND)
               WHERE CAB.TIPMOV = 'V'
               --AND CAB.CODVEND IN :ACODVEND
                 AND CAB.STATUSNOTA = 'L'
                 AND CAB.AD_EXEC IS NOT NULL
                 AND ITE1.USOPROD IN ('R', 'S')
                 AND TRUNC(CAB.DTFATUR) BETWEEN ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (SYSDATE,'MONTH'),'DD/MM/YY'),0),'MONTH'),'DD/MM/YY'),-2)
                                                AND ADD_MONTHS (TO_DATE (LAST_DAY (SYSDATE),'DD/MM/YY'),-2)
                 AND CAB.CODTIPVENDA NOT IN (16, 90)
                 AND CAB.CODTIPOPER IN (SELECT CODTIPOPER FROM AD_TIPVENDEV WHERE TIPMOV = 'V')
               --AND CAB.CODPARC = :ACODPARC
               GROUP BY CAB.CODVEND, CAB.CODPARC
            UNION ALL ----------------------------------------------------------------------------------------------------------------------- (SEM AGENTE) UNION ALL 3.2
               SELECT CAB.CODVEND,
                      CAB.CODPARC,
                      NVL (SUM (ROUND (ITE1.VLRTOT, 2)), 0) AS MES_1,
                      (TO_CHAR (ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (SYSDATE, 'MONTH'),'DD/MM/YY'),0),'MONTH'),'DD/MM/YY'),-2),'MM/YYYY'))AS dt,
                      3 AS ORDEM
               FROM TGFCAB CAB INNER JOIN TGFITE ITE1 ON (CAB.NUNOTA = ITE1.NUNOTA)
                               INNER JOIN TGFPAR PAR1 ON (CAB.CODPARC = PAR1.CODPARC)
                               INNER JOIN TGFVEN VEN1 ON (CAB.CODVEND = VEN1.CODVEND)
               WHERE CAB.TIPMOV = 'V'
               --AND CAB.CODVEND IN :ACODVEND
                 AND CAB.STATUSNOTA = 'L'
                 AND CAB.AD_EXEC IS NULL
                 AND ITE1.USOPROD IN ('R', 'S')
                 AND TRUNC(CAB.DTFATUR) BETWEEN ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (SYSDATE,'MONTH'),'DD/MM/YY'),0),'MONTH'),'DD/MM/YY'),-2)
                                                AND ADD_MONTHS (TO_DATE (LAST_DAY (SYSDATE),'DD/MM/YY'),-2)
                 AND CAB.CODTIPVENDA NOT IN (16, 90)
                 AND CAB.CODTIPOPER IN (SELECT CODTIPOPER FROM AD_TIPVENDEV WHERE TIPMOV = 'V')
                     --AND CAB.CODPARC = :ACODPARC
               GROUP BY CAB.CODVEND, CAB.CODPARC
            UNION ALL ----------------------------------------------------------------------------------------------------------------------- (DEVOLUÇÃO) UNION ALL 3.3
               SELECT CAB.CODVEND,
                      CAB.CODPARC,
                      NVL (SUM (ROUND (ITE.VLRTOT, 2) * (-1)), 0) AS MES_1,
                      (TO_CHAR (ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (SYSDATE, 'MONTH'),'DD/MM/YY'),0),'MONTH'),'DD/MM/YY'),-2),'MM/YYYY'))AS dt,
				      3 AS ORDEM
               FROM TGFCAB CAB INNER JOIN TGFITE ITE ON (ITE.NUNOTA = CAB.NUNOTA)
                               INNER JOIN TGFTOP TOP ON (CAB.CODTIPOPER = TOP.CODTIPOPER)
                               INNER JOIN TGFPAR PAR ON (CAB.CODPARC = PAR.CODPARC)
                               INNER JOIN TGFTPV TPV ON (CAB.CODTIPVENDA = TPV.CODTIPVENDA)
                               INNER JOIN TGFVEN VEN ON (CAB.CODVEND = VEN.CODVEND)
               WHERE CAB.DHTIPOPER = TOP.DHALTER
                   --AND CAB.CODVEND IN :ACODVEND
                     AND CAB.DHTIPVENDA = TPV.DHALTER
                     AND ITE.USOPROD IN ('R', 'S')
                     AND TRUNC(CAB.DTFATUR) BETWEEN ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (SYSDATE,'MONTH'),'DD/MM/YY'),0),'MONTH'),'DD/MM/YY'),-2)
                                                    AND ADD_MONTHS (TO_DATE (LAST_DAY (SYSDATE),'DD/MM/YY'),-2)
                     AND CAB.CODTIPOPER IN (SELECT CODTIPOPER FROM AD_TIPVENDEV WHERE TIPMOV = 'D')
                   --AND CAB.CODPARC = :ACODPARC
               GROUP BY CAB.CODVEND, CAB.CODPARC) MES1
         GROUP BY MES1.CODVEND,
                  dt,
                  ORDEM,
                  CODPARC
      UNION ALL --------------------------------------------------------------------------------------------------------------------------------------------------MÊS 4
      -------------------------------------------------------------------------------------------------------------------------------------- (COM AGENTE) UNION ALL 4.1
         SELECT MES1.CODVEND,
                NVL (SUM (MES1.MES_1), 0) AS MES_1,
                dt,
                ORDEM,
                CODPARC
         FROM (
               SELECT CAB.CODVEND,
                      CAB.CODPARC,
                      NVL (SUM (ROUND (ITE1.PRECOBASE * ITE1.QTDNEG, 2)),0) AS MES_1,
                      (TO_CHAR (ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (SYSDATE, 'MONTH'),'DD/MM/YY'),0),'MONTH'),'DD/MM/YY'),-3),'MM/YYYY')) AS dt,
                      4 AS ORDEM
               FROM TGFCAB CAB INNER JOIN TGFITE ITE1 ON (CAB.NUNOTA = ITE1.NUNOTA)
                               INNER JOIN TGFPAR PAR1 ON (CAB.CODPARC = PAR1.CODPARC)
                               INNER JOIN TGFVEN VEN1 ON (CAB.CODVEND = VEN1.CODVEND)
               WHERE CAB.TIPMOV = 'V'
               --AND CAB.CODVEND IN :ACODVEND
                 AND CAB.STATUSNOTA = 'L'
                 AND CAB.AD_EXEC IS NOT NULL
                 AND ITE1.USOPROD IN ('R', 'S')
                 AND TRUNC(CAB.DTFATUR) BETWEEN ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (SYSDATE,'MONTH'),'DD/MM/YY'),0),'MONTH'),'DD/MM/YY'),-3)
                                                AND ADD_MONTHS (TO_DATE (LAST_DAY (SYSDATE),'DD/MM/YY'),-3)
                 AND CAB.CODTIPVENDA NOT IN (16, 90)
                 AND CAB.CODTIPOPER IN (SELECT CODTIPOPER FROM AD_TIPVENDEV WHERE TIPMOV = 'V')
               --AND CAB.CODPARC = :ACODPARC
               GROUP BY CAB.CODVEND, CAB.CODPARC
            UNION ALL ---------------------------------------------------------------------------------------------------------------------- (SEM AGENTE) UNION ALL 3.3
               SELECT CAB.CODVEND,
                      CAB.CODPARC,
                      NVL (SUM (ROUND (ITE1.VLRTOT, 2)), 0) AS MES_1,
                      (TO_CHAR (ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (SYSDATE, 'MONTH'),'DD/MM/YY'),0),'MONTH'),'DD/MM/YY'),-3),'MM/YYYY')) AS dt,
                      4 AS ORDEM
               FROM TGFCAB CAB INNER JOIN TGFITE ITE1 ON (CAB.NUNOTA = ITE1.NUNOTA)
                               INNER JOIN TGFPAR PAR1 ON (CAB.CODPARC = PAR1.CODPARC)
                               INNER JOIN TGFVEN VEN1 ON (CAB.CODVEND = VEN1.CODVEND)
               WHERE CAB.TIPMOV = 'V'
               --AND CAB.CODVEND IN :ACODVEND
                 AND CAB.STATUSNOTA = 'L'
                 AND CAB.AD_EXEC IS NULL
                 AND ITE1.USOPROD IN ('R', 'S')
                 AND TRUNC(CAB.DTFATUR) BETWEEN ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (SYSDATE,'MONTH'),'DD/MM/YY'),0),'MONTH'),'DD/MM/YY'),-3)
                                                AND ADD_MONTHS (TO_DATE (LAST_DAY (SYSDATE),'DD/MM/YY'),-3)
                 AND CAB.CODTIPVENDA NOT IN (16, 90)
                 AND CAB.CODTIPOPER IN (SELECT CODTIPOPER FROM AD_TIPVENDEV WHERE TIPMOV = 'V')
               --AND CAB.CODPARC = :ACODPARC
               GROUP BY CAB.CODVEND, CAB.CODPARC
            UNION ALL ----------------------------------------------------------------------------------------------------------------------- (DEVOLUÇÃO) UNION ALL 3.3
               SELECT CAB.CODVEND,
                      CAB.CODPARC,
                      NVL (SUM (ROUND (ITE.VLRTOT, 2) * (-1)), 0) AS MES_1,
                      (TO_CHAR (ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (SYSDATE, 'MONTH'),'DD/MM/YY'),0),'MONTH'),'DD/MM/YY'),-3),'MM/YYYY')) AS dt,
                      4 AS ORDEM
               FROM TGFCAB CAB INNER JOIN TGFITE ITE ON (ITE.NUNOTA = CAB.NUNOTA)
                               INNER JOIN TGFTOP TOP ON (CAB.CODTIPOPER = TOP.CODTIPOPER)
                               INNER JOIN TGFPAR PAR ON (CAB.CODPARC = PAR.CODPARC)
                               INNER JOIN TGFTPV TPV ON (CAB.CODTIPVENDA = TPV.CODTIPVENDA)
                               INNER JOIN TGFVEN VEN ON (CAB.CODVEND = VEN.CODVEND)
               WHERE CAB.DHTIPOPER = TOP.DHALTER
               --AND CAB.CODVEND IN :ACODVEND
                 AND CAB.DHTIPVENDA = TPV.DHALTER
                 AND ITE.USOPROD IN ('R', 'S')
                 AND TRUNC(CAB.DTFATUR) BETWEEN ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (SYSDATE,'MONTH'),'DD/MM/YY'),0),'MONTH'),'DD/MM/YY'),-3)
                                                AND ADD_MONTHS (TO_DATE (LAST_DAY (SYSDATE),'DD/MM/YY'),-3)
                 AND CAB.CODTIPOPER IN (SELECT CODTIPOPER FROM AD_TIPVENDEV WHERE TIPMOV = 'D')
               --AND CAB.CODPARC = :ACODPARC
               GROUP BY CAB.CODVEND, CAB.CODPARC) MES1
         GROUP BY MES1.CODVEND,
                  dt,
                  ORDEM,
                  CODPARC
      UNION ALL --------------------------------------------------------------------------------------------------------------------------------------------------MÊS 5
      -------------------------------------------------------------------------------------------------------------------------------------- (COM AGENTE) UNION ALL 4.1
             SELECT MES1.CODVEND,
                    NVL (SUM (MES1.MES_1), 0) AS MES_1,
                    dt,
                    ORDEM,
                    CODPARC
               FROM (  SELECT CAB.CODVEND,
                              CAB.CODPARC,
                              NVL (SUM (ROUND (ITE1.PRECOBASE * ITE1.QTDNEG, 2)),0) AS MES_1,
                              (TO_CHAR (ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (SYSDATE, 'MONTH'),'DD/MM/YY'),0),'MONTH'),'DD/MM/YY'),-4),'MM/YYYY')) AS dt,
                              5 AS ORDEM
                         FROM TGFCAB CAB
                              INNER JOIN TGFITE ITE1
                                 ON (CAB.NUNOTA = ITE1.NUNOTA)
                              INNER JOIN TGFPAR PAR1
                                 ON (CAB.CODPARC = PAR1.CODPARC)
                              INNER JOIN TGFVEN VEN1
                                 ON (CAB.CODVEND = VEN1.CODVEND)
                        WHERE     CAB.TIPMOV = 'V'
                              --AND CAB.CODVEND IN :ACODVEND
                              AND CAB.STATUSNOTA = 'L'
                              AND CAB.AD_EXEC IS NOT NULL
                              AND ITE1.USOPROD IN ('R', 'S')
                              AND TRUNC(CAB.DTFATUR) BETWEEN ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (SYSDATE,'MONTH'),'DD/MM/YY'),0),'MONTH'),'DD/MM/YY'),-4)
                                                  AND ADD_MONTHS (TO_DATE (LAST_DAY (SYSDATE),'DD/MM/YY'),-4)
                              AND CAB.CODTIPVENDA NOT IN (16, 90)
                              AND CAB.CODTIPOPER IN (SELECT CODTIPOPER
                                                       FROM AD_TIPVENDEV
                                                      WHERE TIPMOV = 'V')
                     --AND CAB.CODPARC = :ACODPARC
                     GROUP BY CAB.CODVEND, CAB.CODPARC
                     UNION
                       SELECT CAB.CODVEND,
                              CAB.CODPARC,
                              NVL (SUM (ROUND (ITE1.VLRTOT, 2)), 0) AS MES_1,
                              (TO_CHAR (ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (SYSDATE, 'MONTH'),'DD/MM/YY'),0),'MONTH'),'DD/MM/YY'),-4),'MM/YYYY')) AS dt,
                              5 AS ORDEM
                         FROM TGFCAB CAB
                              INNER JOIN TGFITE ITE1
                                 ON (CAB.NUNOTA = ITE1.NUNOTA)
                              INNER JOIN TGFPAR PAR1
                                 ON (CAB.CODPARC = PAR1.CODPARC)
                              INNER JOIN TGFVEN VEN1
                                 ON (CAB.CODVEND = VEN1.CODVEND)
                        WHERE     CAB.TIPMOV = 'V'
                              --AND CAB.CODVEND IN :ACODVEND
                              AND CAB.STATUSNOTA = 'L'
                              AND CAB.AD_EXEC IS NULL
                              AND ITE1.USOPROD IN ('R', 'S')
                              AND TRUNC(CAB.DTFATUR) BETWEEN ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (SYSDATE,'MONTH'),'DD/MM/YY'),0),'MONTH'),'DD/MM/YY'),-4)
                                                  AND ADD_MONTHS (TO_DATE (LAST_DAY (SYSDATE),'DD/MM/YY'),-4)
                              AND CAB.CODTIPVENDA NOT IN (16, 90)
                              AND CAB.CODTIPOPER IN (SELECT CODTIPOPER
                                                       FROM AD_TIPVENDEV
                                                      WHERE TIPMOV = 'V')
                     --AND CAB.CODPARC = :ACODPARC
                     GROUP BY CAB.CODVEND, CAB.CODPARC
                     UNION
                       SELECT CAB.CODVEND,
                              CAB.CODPARC,
                              NVL (SUM (ROUND (ITE.VLRTOT, 2) * (-1)), 0) AS MES_1,
                              (TO_CHAR (ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (SYSDATE, 'MONTH'),'DD/MM/YY'),0),'MONTH'),'DD/MM/YY'),-4),'MM/YYYY')) AS dt,
                              5 AS ORDEM
                         FROM TGFCAB CAB
                              INNER JOIN TGFITE ITE ON (ITE.NUNOTA = CAB.NUNOTA)
                              INNER JOIN TGFTOP TOP
                                 ON (CAB.CODTIPOPER = TOP.CODTIPOPER)
                              INNER JOIN TGFPAR PAR
                                 ON (CAB.CODPARC = PAR.CODPARC)
                              INNER JOIN TGFTPV TPV
                                 ON (CAB.CODTIPVENDA = TPV.CODTIPVENDA)
                              INNER JOIN TGFVEN VEN
                                 ON (CAB.CODVEND = VEN.CODVEND)
                        WHERE     CAB.DHTIPOPER = TOP.DHALTER
                              --AND CAB.CODVEND IN :ACODVEND
                              AND CAB.DHTIPVENDA = TPV.DHALTER
                              AND ITE.USOPROD IN ('R', 'S')
                              AND TRUNC(CAB.DTFATUR) BETWEEN ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (SYSDATE,'MONTH'),'DD/MM/YY'),0),'MONTH'),'DD/MM/YY'),-4)
                                                  AND ADD_MONTHS (TO_DATE (LAST_DAY (SYSDATE),'DD/MM/YY'),-4)
                              AND CAB.CODTIPOPER IN (SELECT CODTIPOPER
                                                       FROM AD_TIPVENDEV
                                                      WHERE TIPMOV = 'D')
                     --AND CAB.CODPARC = :ACODPARC
                     GROUP BY CAB.CODVEND, CAB.CODPARC) MES1
           GROUP BY MES1.CODVEND,
                    dt,
                    ORDEM,
                    CODPARC
           UNION ALL ----------------------------------------------------------------------------------------------UNION 5
             SELECT MES1.CODVEND,
                    NVL (SUM (MES1.MES_1), 0) AS MES_1,
                    dt,
                    ORDEM,
                    CODPARC
               FROM (  SELECT CAB.CODVEND,
                              CAB.CODPARC,
                              NVL (SUM (ROUND (ITE1.PRECOBASE * ITE1.QTDNEG, 2)),0) AS MES_1,
                              (TO_CHAR (ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (SYSDATE, 'MONTH'),'DD/MM/YY'),0),'MONTH'),'DD/MM/YY'),-5),'MM/YYYY')) AS dt,
                              6 AS ORDEM
                         FROM TGFCAB CAB
                              INNER JOIN TGFITE ITE1
                                 ON (CAB.NUNOTA = ITE1.NUNOTA)
                              INNER JOIN TGFPAR PAR1
                                 ON (CAB.CODPARC = PAR1.CODPARC)
                              INNER JOIN TGFVEN VEN1
                                 ON (CAB.CODVEND = VEN1.CODVEND)
                        WHERE     CAB.TIPMOV = 'V'
                              --AND CAB.CODVEND IN :ACODVEND
                              AND CAB.STATUSNOTA = 'L'
                              AND CAB.AD_EXEC IS NOT NULL
                              AND ITE1.USOPROD IN ('R', 'S')
                              AND TRUNC(CAB.DTFATUR) BETWEEN ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (SYSDATE,'MONTH'),'DD/MM/YY'),0),'MONTH'),'DD/MM/YY'),-5)
							  AND ADD_MONTHS (TO_DATE (LAST_DAY (SYSDATE),'DD/MM/YY'),-5)
                              AND CAB.CODTIPVENDA NOT IN (16, 90)
                              AND CAB.CODTIPOPER IN (SELECT CODTIPOPER
                                                       FROM AD_TIPVENDEV
                                                      WHERE TIPMOV = 'V')
                     --AND CAB.CODPARC = :ACODPARC
                     GROUP BY CAB.CODVEND, CAB.CODPARC
                     UNION
                       SELECT CAB.CODVEND,
                              CAB.CODPARC,
                              NVL (SUM (ROUND (ITE1.VLRTOT, 2)), 0) AS MES_1,
                              (TO_CHAR (ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (SYSDATE, 'MONTH'),'DD/MM/YY'),0),'MONTH'),'DD/MM/YY'),-5),'MM/YYYY')) AS dt,
                              6 AS ORDEM
                         FROM TGFCAB CAB
                              INNER JOIN TGFITE ITE1
                                 ON (CAB.NUNOTA = ITE1.NUNOTA)
                              INNER JOIN TGFPAR PAR1
                                 ON (CAB.CODPARC = PAR1.CODPARC)
                              INNER JOIN TGFVEN VEN1
                                 ON (CAB.CODVEND = VEN1.CODVEND)
                        WHERE     CAB.TIPMOV = 'V'
                              --AND CAB.CODVEND IN :ACODVEND
                              AND CAB.STATUSNOTA = 'L'
                              AND CAB.AD_EXEC IS NULL
                              AND ITE1.USOPROD IN ('R', 'S')
                              AND TRUNC(CAB.DTFATUR) BETWEEN ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (SYSDATE,'MONTH'),'DD/MM/YY'),0),'MONTH'),'DD/MM/YY'),-5)
                                                  AND ADD_MONTHS (TO_DATE (LAST_DAY (SYSDATE),'DD/MM/YY'),-5)
                              AND CAB.CODTIPVENDA NOT IN (16, 90)
                              AND CAB.CODTIPOPER IN (SELECT CODTIPOPER
                                                       FROM AD_TIPVENDEV
                                                      WHERE TIPMOV = 'V')
                     --AND CAB.CODPARC = :ACODPARC
                     GROUP BY CAB.CODVEND, CAB.CODPARC
                     UNION
                       SELECT CAB.CODVEND,
                              CAB.CODPARC,
                              NVL (SUM (ROUND (ITE.VLRTOT, 2) * (-1)), 0) AS MES_1,
                              (TO_CHAR (ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (SYSDATE, 'MONTH'),'DD/MM/YY'),0),'MONTH'),'DD/MM/YY'),-5),'MM/YYYY')) AS dt,
                              6 AS ORDEM
                         FROM TGFCAB CAB
                              INNER JOIN TGFITE ITE ON (ITE.NUNOTA = CAB.NUNOTA)
                              INNER JOIN TGFTOP TOP
                                 ON (CAB.CODTIPOPER = TOP.CODTIPOPER)
                              INNER JOIN TGFPAR PAR
                                 ON (CAB.CODPARC = PAR.CODPARC)
                              INNER JOIN TGFTPV TPV
                                 ON (CAB.CODTIPVENDA = TPV.CODTIPVENDA)
                              INNER JOIN TGFVEN VEN
                                 ON (CAB.CODVEND = VEN.CODVEND)
                        WHERE     CAB.DHTIPOPER = TOP.DHALTER
                        
                              --AND CAB.CODVEND IN :ACODVEND
                              AND CAB.DHTIPVENDA = TPV.DHALTER
                              AND ITE.USOPROD IN ('R', 'S')
                              AND TRUNC(CAB.DTFATUR) BETWEEN ADD_MONTHS (TO_DATE (TRUNC (ADD_MONTHS (TO_DATE (TRUNC (SYSDATE,'MONTH'),'DD/MM/YY'),0),'MONTH'),'DD/MM/YY'),-5)
                                                  AND ADD_MONTHS (TO_DATE (LAST_DAY (SYSDATE),'DD/MM/YY'),-5)
                              AND CAB.CODTIPOPER IN (SELECT CODTIPOPER
                                                       FROM AD_TIPVENDEV
                                                      WHERE TIPMOV = 'D')
                     --AND CAB.CODPARC = :ACODPARC
                     GROUP BY CAB.CODVEND, CAB.CODPARC) MES1
           GROUP BY MES1.CODVEND,
                    dt,
                    ORDEM,
                    CODPARC) MESES
--order by CODVEND, ordem ASC, CODPARC
;