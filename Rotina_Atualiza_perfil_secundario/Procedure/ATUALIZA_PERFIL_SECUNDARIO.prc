/* Formatted on 28/08/2018 18:03:25 (QP5 v5.287) */
CREATE OR REPLACE PROCEDURE TOTALPRD.ATUALIZA_PERFIL_SECUNDARIO (
   P_CODUSU          NUMBER,                       -- Código do usuário logado
   P_IDSESSAO        VARCHAR2, -- Identificador da execução. Serve para buscar informações dos parâmetros/campos da execução.
   P_QTDLINHAS       NUMBER, -- Informa a quantidade de registros selecionados no momento da execução.
   P_MENSAGEM    OUT VARCHAR2 -- Caso seja passada uma mensagem aqui, ela será exibida como uma informação ao usuário.
                             )
AS
   PIGUALINS     INT;
   PIGUALDEL     INT;
   PGRUPOPROD    INT;
   PPRODUTOS     INT;
   PCONTINSERT   INT := 0;
   PCONTDELETE   INT := 0;
   PCONTVENDA    INT;
BEGIN
   /*
   AUTOR: Mauricio Rodrigues
   Data da criação: 28/11/2017
   DESCRIÇÃO: Existe uma tela chamada: MKT - Regras de perfis Sec. do Parceiro no
              qual configuramos uma relação de definições para que o código abaixo
              passe por todos os parceiro e identifique as regras configuradas,
              com isso ele insere perfis secundários ou remove. Com isso existe
              o dashboard MKT - exportação parceiros que pelos filtros podemos
              consultar esses parceiros.
   */
   --1. Loop para executar cada regra pelo seu indice (CODREGPERFIL).
   FOR CUR_CUS IN (SELECT REG.CODREGPERFIL,
                          REG.CODTIPPARC,
                          REG.CHCLIENTE,
                          REG.CHFORNECEDOR,
                          REG.CHVENDEDOR,
                          REG.CHCONTRATO,
                          REG.CODGRUPOPROD,
                          REG.PERIODO,
                          REG.ATIVO,
                          REG.CONTRATOATIVO,
                          REG.VLRMENOR,
                          REG.VLRMAIOR,
                          REG.VENDAOK
                     FROM AD_MKTREGPERFIS REG
                    WHERE NVL (REG.ATIVO, 'N') = 'S')
   LOOP
      --Verifica se o campo grupo de produtos tem informação.
      IF CUR_CUS.CODGRUPOPROD IS NULL
      THEN
         PGRUPOPROD := 0;
      ELSE
         PGRUPOPROD := 1;
      END IF;

      --Verificar se existem produtos para serem considerados na query.
      SELECT COUNT (PRO.CODPROD)
        INTO PPRODUTOS
        FROM AD_MKTREGPERFIS REG, AD_MKTPROPERFIS PRO
       WHERE     REG.CODREGPERFIL = PRO.CODREGPERFIL
             AND REG.CODREGPERFIL = CUR_CUS.CODREGPERFIL; --CUR_CUS.CODREGPERFIL

      --Verificar contrato ou venda
      IF CUR_CUS.CHCONTRATO = 'v'
      THEN
         PCONTVENDA := 0;
      ELSE
         PCONTVENDA := 1;
      END IF;

      --inicio------------------------------------------------------------------------------------------------------------------------------------------
      IF PGRUPOPROD = 0
      THEN --SEM GRUPO----Primeiro IF--------------------------------------------------------------------------------------------------
         IF PPRODUTOS = 0
         THEN --SEM PRODUTO--IF-1.1.---------------------------------------------------------------------------------------
            FOR CUR_CUS2
               IN (  SELECT PARC.CODPARC,
                            PARC.CODTIPPARC,
                            PARC.CLIENTE,
                            PARC.FORNECEDOR,
                            PARC.VENDEDOR
                       FROM TGFPAR PARC
                      WHERE     PARC.CODTIPPARC = CUR_CUS.CODTIPPARC --PERFIL 30000001, 10403000
                            AND PARC.CLIENTE = NVL (CUR_CUS.CHCLIENTE, 'N') --CLIENTE S/N
                            AND PARC.FORNECEDOR =
                                   NVL (CUR_CUS.CHFORNECEDOR, 'N') --FORNECEDOR S/N
                            AND PARC.VENDEDOR = NVL (CUR_CUS.CHVENDEDOR, 'N') --VENDEDOR S/N
                   ORDER BY 1)
            LOOP
               --3. Ao localizar um parceiro que se enquadra nas regras acima,
               --   localizamos se existem perfis já cadastrado neste parceiro 3.1
               --   eliminamos os já cadastrado e inserimos os demais 3.2
               --   depois removemos os perfis segundo as regras 4.
               --3.1
               SELECT COUNT (INS.CODTIPPARC)
                 INTO PIGUALINS
                 FROM AD_MKTINCPERFIS INS
                WHERE     INS.CODREGPERFIL = CUR_CUS.CODREGPERFIL
                      AND INS.CODTIPPARC NOT IN
                             (SELECT PARC.CODTIPPARC
                                FROM TGFPPA PARC
                               WHERE PARC.CODPARC = CUR_CUS2.CODPARC);

               IF PIGUALINS <> 0
               THEN
                  --3.2
                  INSERT INTO TGFPPA (CODPARC,
                                      CODCONTATO,
                                      CODTIPPARC,
                                      CODUSU,
                                      DTALTER)
                     (SELECT CUR_CUS2.CODPARC AS CODPARC,
                             0 AS CODCONTATO,
                             INS.CODTIPPARC,
                             0 AS CODUSU,
                             SYSDATE
                        FROM AD_MKTINCPERFIS INS
                       WHERE     INS.CODTIPPARC NOT IN
                                    (SELECT PARC.CODTIPPARC
                                       FROM TGFPPA PARC
                                      WHERE PARC.CODPARC = CUR_CUS2.CODPARC)
                             AND INS.CODREGPERFIL = CUR_CUS.CODREGPERFIL);

                  COMMIT;
                  PCONTINSERT := PCONTINSERT + 1;
               END IF;

               --4.Deletando segunto as regras.
               SELECT COUNT (INS.CODTIPPARC)
                 INTO PIGUALDEL
                 FROM AD_MKTREMPERFIS INS
                WHERE     INS.CODREGPERFIL = CUR_CUS.CODREGPERFIL
                      AND INS.CODTIPPARC IN
                             (SELECT PARC.CODTIPPARC
                                FROM TGFPPA PARC
                               WHERE PARC.CODPARC = CUR_CUS2.CODPARC);

               IF PIGUALDEL <> 0
               THEN
                  DELETE FROM TGFPPA PPA
                        WHERE     PPA.CODPARC = CUR_CUS2.CODPARC
                              AND PPA.CODTIPPARC IN
                                     (SELECT INS.CODTIPPARC
                                        FROM AD_MKTREMPERFIS INS
                                       WHERE     INS.CODTIPPARC IN
                                                    (SELECT PARC.CODTIPPARC
                                                       FROM TGFPPA PARC
                                                      WHERE PARC.CODPARC =
                                                               CUR_CUS2.CODPARC)
                                             AND INS.CODREGPERFIL =
                                                    CUR_CUS.CODREGPERFIL);

                  COMMIT;
                  PCONTDELETE := PCONTDELETE + 1;
               END IF;
            END LOOP;
         ELSE -------------------COM PRODUTO--ELSE-1.1.-------------------------------------------------------------------------------------
            IF PCONTVENDA = 0
            THEN --COM VENDA-----------IF-1.2.---------------------------------------------------------------------------------------
               --2.Rodando a primeira regra acima, roda por todos os parceiros procurando as regras do primeiro indice.
               FOR CUR_CUS2
                  IN (  SELECT PARC.CODPARC,
                               PARC.CODTIPPARC,
                               PARC.CLIENTE,
                               PARC.FORNECEDOR,
                               PARC.VENDEDOR
                          FROM TGFPAR PARC
                         WHERE     PARC.CODTIPPARC = 10403000 --CUR_CUS.CODTIPPARC                            --PERFIL 30000001, 10403000
                               AND PARC.CLIENTE = 'S' --NVL(CUR_CUS.CHCLIENTE, 'N')                  --CLIENTE S/N
                               AND PARC.FORNECEDOR = 'N' --NVL(CUR_CUS.CHFORNECEDOR, 'N')            --FORNECEDOR S/N
                               AND PARC.VENDEDOR = 'N' --NVL(CUR_CUS.CHVENDEDOR, 'N')                --VENDEDOR S/N
                               AND (SELECT COUNT (P.CODPROD)
                                      FROM ---------Sub tabela
                                           (SELECT DISTINCT
                                                   PROD.CODPROD,
                                                   CAB.CODPARC
                                              FROM TGFPRO PROD,
                                                   TGFITE ITE,
                                                   TGFCAB CAB
                                             WHERE     PROD.CODPROD =
                                                          ITE.CODPROD
                                                   AND ITE.NUNOTA =
                                                          CAB.NUNOTA
                                                   AND CAB.DTFATUR BETWEEN (  SYSDATE
                                                                            - CUR_CUS.PERIODO)
                                                                       AND (SYSDATE) --CUR_CUS.PERIODO (30/180/365)
                                                   AND CAB.VLRNOTA BETWEEN NVL (
                                                                              CUR_CUS.VLRMENOR,
                                                                              0)
                                                                       AND NVL (
                                                                              CUR_CUS.VLRMAIOR,
                                                                              99999999) --CUR_CUS.VLRMENOR) AND (CUR_CUS.VLRMAIOR) (00.00)
                                                   AND (CASE
                                                           WHEN CAB.STATUSNFE =
                                                                   'A'
                                                           THEN
                                                              'S'
                                                           ELSE
                                                              'N'
                                                        END) =
                                                          CUR_CUS.VENDAOK
                                                   AND PROD.CODPROD IN
                                                          (SELECT DISTINCT
                                                                  PRO.CODPROD
                                                             FROM AD_MKTREGPERFIS
                                                                  REG,
                                                                  AD_MKTPROPERFIS
                                                                  PRO
                                                            WHERE     REG.CODREGPERFIL =
                                                                         PRO.CODREGPERFIL
                                                                  AND REG.CODREGPERFIL =
                                                                         CUR_CUS.CODREGPERFIL --CUR_CUS.CODREGPERFIL
                                                                                             ))
                                           P
                                     WHERE P.CODPARC = PARC.CODPARC) <> 0
                      ORDER BY 1)
               LOOP
                  --3. Ao localizar um parceiro que se enquadra nas regras acima,
                  --   localizamos se existem perfis já cadastrado neste parceiro 3.1
                  --   eliminamos os já cadastrado e inserimos os demais 3.2
                  --   depois removemos os perfis segundo as regras 4.
                  --3.1


                  SELECT COUNT (INS.CODTIPPARC)
                    INTO PIGUALINS
                    FROM AD_MKTINCPERFIS INS
                   WHERE     INS.CODREGPERFIL = CUR_CUS.CODREGPERFIL
                         AND INS.CODTIPPARC NOT IN
                                (SELECT PARC.CODTIPPARC
                                   FROM TGFPPA PARC
                                  WHERE PARC.CODPARC = CUR_CUS2.CODPARC);

                  IF PIGUALINS <> 0
                  THEN
                     --3.2
                     INSERT INTO TGFPPA (CODPARC,
                                         CODCONTATO,
                                         CODTIPPARC,
                                         CODUSU,
                                         DTALTER)
                        (SELECT CUR_CUS2.CODPARC AS CODPARC,
                                0 AS CODCONTATO,
                                INS.CODTIPPARC,
                                0 AS CODUSU,
                                SYSDATE
                           FROM AD_MKTINCPERFIS INS
                          WHERE     INS.CODTIPPARC NOT IN
                                       (SELECT PARC.CODTIPPARC
                                          FROM TGFPPA PARC
                                         WHERE PARC.CODPARC =
                                                  CUR_CUS2.CODPARC)
                                AND INS.CODREGPERFIL = CUR_CUS.CODREGPERFIL);

                     COMMIT;
                     PCONTINSERT := PCONTINSERT + 1;
                  END IF;

                  --4.Deletando segunto as regras.
                  SELECT COUNT (INS.CODTIPPARC)
                    INTO PIGUALDEL
                    FROM AD_MKTREMPERFIS INS
                   WHERE     INS.CODREGPERFIL = CUR_CUS.CODREGPERFIL
                         AND INS.CODTIPPARC IN
                                (SELECT PARC.CODTIPPARC
                                   FROM TGFPPA PARC
                                  WHERE PARC.CODPARC = CUR_CUS2.CODPARC);

                  IF PIGUALDEL <> 0
                  THEN
                     DELETE FROM TGFPPA PPA
                           WHERE     PPA.CODPARC = CUR_CUS2.CODPARC
                                 AND PPA.CODTIPPARC IN
                                        (SELECT INS.CODTIPPARC
                                           FROM AD_MKTREMPERFIS INS
                                          WHERE     INS.CODTIPPARC IN
                                                       (SELECT PARC.CODTIPPARC
                                                          FROM TGFPPA PARC
                                                         WHERE PARC.CODPARC =
                                                                  CUR_CUS2.CODPARC)
                                                AND INS.CODREGPERFIL =
                                                       CUR_CUS.CODREGPERFIL);

                     COMMIT;
                     PCONTDELETE := PCONTDELETE + 1;
                  END IF;
               END LOOP;
            --COM CONTRATO
            ELSE --------------------COM CONTRATO--------ELSE-1.2.-------------------------------------------------------------------------------------
 --2.Rodando a primeira regra acima, roda por todos os parceiros procurando as regras do primeiro indice.
               FOR CUR_CUS2
                  IN (  SELECT PARC.CODPARC,
                               PARC.CODTIPPARC,
                               PARC.CLIENTE,
                               PARC.FORNECEDOR,
                               PARC.VENDEDOR
                          FROM TGFPAR PARC
                         WHERE     PARC.CODTIPPARC = CUR_CUS.CODTIPPARC --PERFIL 30000001, 10403000
                               AND PARC.CLIENTE = NVL (CUR_CUS.CHCLIENTE, 'N') --CLIENTE S/N
                               AND PARC.FORNECEDOR =
                                      NVL (CUR_CUS.CHFORNECEDOR, 'N') --FORNECEDOR S/N
                               AND PARC.VENDEDOR =
                                      NVL (CUR_CUS.CHVENDEDOR, 'N') --VENDEDOR S/N
                               AND (SELECT COUNT (P.CODPROD)
                                      FROM (SELECT PSC.CODPROD, CON.CODPARC
                                              FROM TCSCON CON, TCSPSC PSC
                                             WHERE     CON.NUMCONTRATO =
                                                          PSC.NUMCONTRATO
                                                   AND CON.DTCONTRATO BETWEEN (  SYSDATE
                                                                               - CUR_CUS.PERIODO)
                                                                          AND (SYSDATE) --CUR_CUS.PERIODO (30/180/365)
                                                   AND CON.ATIVO =
                                                          CUR_CUS.CONTRATOATIVO
                                                   AND PSC.CODPROD IN
                                                          (SELECT DISTINCT
                                                                  PRO.CODPROD
                                                             FROM AD_MKTREGPERFIS
                                                                  REG,
                                                                  AD_MKTPROPERFIS
                                                                  PRO
                                                            WHERE     REG.CODREGPERFIL =
                                                                         PRO.CODREGPERFIL
                                                                  AND REG.CODREGPERFIL =
                                                                         CUR_CUS.CODREGPERFIL))
                                           P            --CUR_CUS.CODREGPERFIL
                                     WHERE P.CODPARC = PARC.CODPARC) <> 0
                               AND (SELECT SUM ( (PRE.VALOR * PSC.NUMUSUARIOS))
                                              AS TOTAL
                                      FROM TCSCON CON, TCSPSC PSC, TCSPRE PRE
                                     WHERE     CON.NUMCONTRATO =
                                                  PSC.NUMCONTRATO
                                           AND PSC.NUMCONTRATO =
                                                  PRE.NUMCONTRATO
                                           AND PSC.CODPROD = PRE.CODPROD
                                           AND CON.DTCONTRATO BETWEEN (  SYSDATE
                                                                       - CUR_CUS.PERIODO)
                                                                  AND (SYSDATE) --CUR_CUS.PERIODO (30/180/365)
                                           AND CON.ATIVO =
                                                  CUR_CUS.CONTRATOATIVO
                                           AND CON.CODPARC = PARC.CODPARC) BETWEEN NVL (
                                                                                      CUR_CUS.VLRMENOR,
                                                                                      0)
                                                                               AND NVL (
                                                                                      CUR_CUS.VLRMAIOR,
                                                                                      99999999) --CUR_CUS.VLRMENOR) AND (CUR_CUS.VLRMAIOR) (00.00)
                      ORDER BY 1)
               LOOP
                  --3. Ao localizar um parceiro que se enquadra nas regras acima,
                  --   localizamos se existem perfis já cadastrado neste parceiro 3.1
                  --   eliminamos os já cadastrado e inserimos os demais 3.2
                  --   depois removemos os perfis segundo as regras 4.
                  --3.1


                  SELECT COUNT (INS.CODTIPPARC)
                    INTO PIGUALINS
                    FROM AD_MKTINCPERFIS INS
                   WHERE     INS.CODREGPERFIL = CUR_CUS.CODREGPERFIL
                         AND INS.CODTIPPARC NOT IN
                                (SELECT PARC.CODTIPPARC
                                   FROM TGFPPA PARC
                                  WHERE PARC.CODPARC = CUR_CUS2.CODPARC);

                  IF PIGUALINS <> 0
                  THEN
                     --3.2
                     INSERT INTO TGFPPA (CODPARC,
                                         CODCONTATO,
                                         CODTIPPARC,
                                         CODUSU,
                                         DTALTER)
                        (SELECT CUR_CUS2.CODPARC AS CODPARC,
                                0 AS CODCONTATO,
                                INS.CODTIPPARC,
                                0 AS CODUSU,
                                SYSDATE
                           FROM AD_MKTINCPERFIS INS
                          WHERE     INS.CODTIPPARC NOT IN
                                       (SELECT PARC.CODTIPPARC
                                          FROM TGFPPA PARC
                                         WHERE PARC.CODPARC =
                                                  CUR_CUS2.CODPARC)
                                AND INS.CODREGPERFIL = CUR_CUS.CODREGPERFIL);

                     COMMIT;
                     PCONTINSERT := PCONTINSERT + 1;
                  END IF;

                  --4.Deletando segunto as regras.
                  SELECT COUNT (INS.CODTIPPARC)
                    INTO PIGUALDEL
                    FROM AD_MKTREMPERFIS INS
                   WHERE     INS.CODREGPERFIL = CUR_CUS.CODREGPERFIL
                         AND INS.CODTIPPARC IN
                                (SELECT PARC.CODTIPPARC
                                   FROM TGFPPA PARC
                                  WHERE PARC.CODPARC = CUR_CUS2.CODPARC);

                  IF PIGUALDEL <> 0
                  THEN
                     DELETE FROM TGFPPA PPA
                           WHERE     PPA.CODPARC = CUR_CUS2.CODPARC
                                 AND PPA.CODTIPPARC IN
                                        (SELECT INS.CODTIPPARC
                                           FROM AD_MKTREMPERFIS INS
                                          WHERE     INS.CODTIPPARC IN
                                                       (SELECT PARC.CODTIPPARC
                                                          FROM TGFPPA PARC
                                                         WHERE PARC.CODPARC =
                                                                  CUR_CUS2.CODPARC)
                                                AND INS.CODREGPERFIL =
                                                       CUR_CUS.CODREGPERFIL);

                     COMMIT;
                     PCONTDELETE := PCONTDELETE + 1;
                  END IF;
               END LOOP;
            --FIM CONTRATO
            END IF;
         --fim produtos
         END IF;
      -- GRUPO
      ELSE --------------------COM GRUPO----Fim do Primeiro IF (else)-------------------------------------------------------------------------------------------
         IF PPRODUTOS = 0
         THEN --SEM PRODUTO--IF-2.1.---------------------------------------------------------------------------------------
            IF PCONTVENDA = 0
            THEN --COM VENDA----------------------------------------------------------------------------------------------------------
               --Roda com grupo, com produto sendo venda.
               FOR CUR_CUS2
                  IN (  SELECT PARC.CODPARC,
                               PARC.CODTIPPARC,
                               PARC.CLIENTE,
                               PARC.FORNECEDOR,
                               PARC.VENDEDOR
                          FROM TGFPAR PARC
                         WHERE     PARC.CODTIPPARC = CUR_CUS.CODTIPPARC --PERFIL 30000001
                               AND PARC.CLIENTE = NVL (CUR_CUS.CHCLIENTE, 'N') --CLIENTE S/N
                               AND PARC.FORNECEDOR =
                                      NVL (CUR_CUS.CHFORNECEDOR, 'N') --FORNECEDOR S/N
                               AND PARC.VENDEDOR =
                                      NVL (CUR_CUS.CHVENDEDOR, 'N') --VENDEDOR S/N
                               AND (CUR_CUS.CODGRUPOPROD) IN
                                      (SELECT DISTINCT PROD.CODGRUPOPROD --CUR_CUS.CODGRUPOPROD 99000000/
                                         FROM TGFPRO PROD
                                        WHERE PROD.CODPROD IN
                                                 (SELECT ITE.CODPROD
                                                    FROM TGFITE ITE
                                                   WHERE ITE.NUNOTA IN
                                                            (SELECT CAB.NUNOTA
                                                               FROM TGFCAB CAB
                                                              WHERE     CAB.CODPARC =
                                                                           PARC.CODPARC
                                                                    AND CAB.VLRNOTA BETWEEN NVL (
                                                                                               CUR_CUS.VLRMENOR,
                                                                                               0)
                                                                                        AND NVL (
                                                                                               CUR_CUS.VLRMAIOR,
                                                                                               99999999) --CUR_CUS.VLRMENOR) AND (CUR_CUS.VLRMAIOR) (00.00)
                                                                    AND CAB.DTFATUR BETWEEN (  SYSDATE
                                                                                             - CUR_CUS.PERIODO)
                                                                                        AND (SYSDATE) --CUR_CUS.PERIODO (30/180/365)
                                                                    AND CASE
                                                                           WHEN CAB.STATUSNFE =
                                                                                   'A'
                                                                           THEN
                                                                              'S'
                                                                           ELSE
                                                                              'N'
                                                                        END =
                                                                           CUR_CUS.VENDAOK)))
                      ORDER BY 1)
               LOOP
                  --3. Ao localizar um parceiro que se enquadra nas regras acima,
                  --   localizamos se existem perfis já cadastrado neste parceiro 3.1
                  --   eliminamos os já cadastrado e inserimos os demais 3.2
                  --   depois removemos os perfis segundo as regras 4.
                  --3.1


                  SELECT COUNT (INS.CODTIPPARC)
                    INTO PIGUALINS
                    FROM AD_MKTINCPERFIS INS
                   WHERE     INS.CODREGPERFIL = CUR_CUS.CODREGPERFIL
                         AND INS.CODTIPPARC NOT IN
                                (SELECT PARC.CODTIPPARC
                                   FROM TGFPPA PARC
                                  WHERE PARC.CODPARC = CUR_CUS2.CODPARC);

                  IF PIGUALINS <> 0
                  THEN
                     --3.2
                     INSERT INTO TGFPPA (CODPARC,
                                         CODCONTATO,
                                         CODTIPPARC,
                                         CODUSU,
                                         DTALTER)
                        (SELECT CUR_CUS2.CODPARC AS CODPARC,
                                0 AS CODCONTATO,
                                INS.CODTIPPARC,
                                0 AS CODUSU,
                                SYSDATE
                           FROM AD_MKTINCPERFIS INS
                          WHERE     INS.CODTIPPARC NOT IN
                                       (SELECT PARC.CODTIPPARC
                                          FROM TGFPPA PARC
                                         WHERE PARC.CODPARC =
                                                  CUR_CUS2.CODPARC)
                                AND INS.CODREGPERFIL = CUR_CUS.CODREGPERFIL);

                     COMMIT;
                     PCONTINSERT := PCONTINSERT + 1;
                  END IF;

                  --4.Deletando segunto as regras.
                  SELECT COUNT (INS.CODTIPPARC)
                    INTO PIGUALDEL
                    FROM AD_MKTREMPERFIS INS
                   WHERE     INS.CODREGPERFIL = CUR_CUS.CODREGPERFIL
                         AND INS.CODTIPPARC IN
                                (SELECT PARC.CODTIPPARC
                                   FROM TGFPPA PARC
                                  WHERE PARC.CODPARC = CUR_CUS2.CODPARC);

                  IF PIGUALDEL <> 0
                  THEN
                     DELETE FROM TGFPPA PPA
                           WHERE     PPA.CODPARC = CUR_CUS2.CODPARC
                                 AND PPA.CODTIPPARC IN
                                        (SELECT INS.CODTIPPARC
                                           FROM AD_MKTREMPERFIS INS
                                          WHERE     INS.CODTIPPARC IN
                                                       (SELECT PARC.CODTIPPARC
                                                          FROM TGFPPA PARC
                                                         WHERE PARC.CODPARC =
                                                                  CUR_CUS2.CODPARC)
                                                AND INS.CODREGPERFIL =
                                                       CUR_CUS.CODREGPERFIL);

                     COMMIT;
                     PCONTDELETE := PCONTDELETE + 1;
                  END IF;
               END LOOP;
            ELSE --------------------COM CONTRATO-------------------------------------------------------------------------------------------------------
                                                           --2.Roda com grupo,
               FOR CUR_CUS2
                  IN (  SELECT PARC.CODPARC,
                               PARC.CODTIPPARC,
                               PARC.CLIENTE,
                               PARC.FORNECEDOR,
                               PARC.VENDEDOR
                          FROM TGFPAR PARC
                         WHERE     PARC.CODTIPPARC = CUR_CUS.CODTIPPARC --PERFIL 30000001
                               AND PARC.CLIENTE = NVL (CUR_CUS.CHCLIENTE, 'N') --CLIENTE S/N
                               AND PARC.FORNECEDOR =
                                      NVL (CUR_CUS.CHFORNECEDOR, 'N') --FORNECEDOR S/N
                               AND PARC.VENDEDOR =
                                      NVL (CUR_CUS.CHVENDEDOR, 'N') --VENDEDOR S/N
                               --BUSCA GRUPO DE PRODUTO NO CONTRATO
                               AND (CUR_CUS.CODGRUPOPROD) IN
                                      (SELECT DISTINCT PROD.CODGRUPOPROD --CUR_CUS.CODGRUPOPROD 99000000/
                                         FROM TGFPRO PROD
                                        WHERE PROD.CODPROD IN
                                                 (SELECT PSC.CODPROD
                                                    FROM TCSPSC PSC
                                                   WHERE PSC.NUMCONTRATO IN
                                                            (SELECT CON.NUMCONTRATO
                                                               FROM TCSCON CON
                                                              WHERE     CON.CODPARC =
                                                                           PARC.CODPARC
                                                                    --AND CAB.VLRNOTA BETWEEN NVL(CUR_CUS.VLRMENOR, 0) AND NVL(CUR_CUS.VLRMAIOR, 99999999) --CUR_CUS.VLRMENOR) AND (CUR_CUS.VLRMAIOR) (00.00)
                                                                    AND CON.DTCONTRATO BETWEEN (  SYSDATE
                                                                                                - CUR_CUS.PERIODO)
                                                                                           AND (SYSDATE)))) --CUR_CUS.PERIODO (30/180/365)
                               --BUSCA VALOR DO CONTRATO
                               AND (SELECT DISTINCT
                                           (SUM (
                                               (PRE.VALOR * PSC.NUMUSUARIOS)))
                                      FROM TCSCON CON, TCSPSC PSC, TCSPRE PRE
                                     WHERE     CON.NUMCONTRATO =
                                                  PSC.NUMCONTRATO
                                           AND PSC.NUMCONTRATO =
                                                  PRE.NUMCONTRATO
                                           AND PSC.CODPROD = PRE.CODPROD
                                           AND CON.DTCONTRATO BETWEEN (  SYSDATE
                                                                       - CUR_CUS.PERIODO)
                                                                  AND (SYSDATE) --CUR_CUS.PERIODO (30/180/365)
                                           AND CON.ATIVO =
                                                  CUR_CUS.CONTRATOATIVO
                                           AND CON.CODPARC = PARC.CODPARC) BETWEEN NVL (
                                                                                      CUR_CUS.VLRMENOR,
                                                                                      0)
                                                                               AND NVL (
                                                                                      CUR_CUS.VLRMAIOR,
                                                                                      99999999) --CUR_CUS.VLRMENOR) AND (CUR_CUS.VLRMAIOR) (00.00)
                      ORDER BY 1)
               LOOP
                  --3. Ao localizar um parceiro que se enquadra nas regras acima,
                  --   localizamos se existem perfis já cadastrado neste parceiro 3.1
                  --   eliminamos os já cadastrado e inserimos os demais 3.2
                  --   depois removemos os perfis segundo as regras 4.
                  --3.1


                  SELECT COUNT (INS.CODTIPPARC)
                    INTO PIGUALINS
                    FROM AD_MKTINCPERFIS INS
                   WHERE     INS.CODREGPERFIL = CUR_CUS.CODREGPERFIL
                         AND INS.CODTIPPARC NOT IN
                                (SELECT PARC.CODTIPPARC
                                   FROM TGFPPA PARC
                                  WHERE PARC.CODPARC = CUR_CUS2.CODPARC);

                  IF PIGUALINS <> 0
                  THEN
                     --3.2
                     INSERT INTO TGFPPA (CODPARC,
                                         CODCONTATO,
                                         CODTIPPARC,
                                         CODUSU,
                                         DTALTER)
                        (SELECT CUR_CUS2.CODPARC AS CODPARC,
                                0 AS CODCONTATO,
                                INS.CODTIPPARC,
                                0 AS CODUSU,
                                SYSDATE
                           FROM AD_MKTINCPERFIS INS
                          WHERE     INS.CODTIPPARC NOT IN
                                       (SELECT PARC.CODTIPPARC
                                          FROM TGFPPA PARC
                                         WHERE PARC.CODPARC =
                                                  CUR_CUS2.CODPARC)
                                AND INS.CODREGPERFIL = CUR_CUS.CODREGPERFIL);

                     COMMIT;
                     PCONTINSERT := PCONTINSERT + 1;
                  END IF;

                  --4.Deletando segunto as regras.
                  SELECT COUNT (INS.CODTIPPARC)
                    INTO PIGUALDEL
                    FROM AD_MKTREMPERFIS INS
                   WHERE     INS.CODREGPERFIL = CUR_CUS.CODREGPERFIL
                         AND INS.CODTIPPARC IN
                                (SELECT PARC.CODTIPPARC
                                   FROM TGFPPA PARC
                                  WHERE PARC.CODPARC = CUR_CUS2.CODPARC);

                  IF PIGUALDEL <> 0
                  THEN
                     DELETE FROM TGFPPA PPA
                           WHERE     PPA.CODPARC = CUR_CUS2.CODPARC
                                 AND PPA.CODTIPPARC IN
                                        (SELECT INS.CODTIPPARC
                                           FROM AD_MKTREMPERFIS INS
                                          WHERE     INS.CODTIPPARC IN
                                                       (SELECT PARC.CODTIPPARC
                                                          FROM TGFPPA PARC
                                                         WHERE PARC.CODPARC =
                                                                  CUR_CUS2.CODPARC)
                                                AND INS.CODREGPERFIL =
                                                       CUR_CUS.CODREGPERFIL);

                     COMMIT;
                     PCONTDELETE := PCONTDELETE + 1;
                  END IF;
               END LOOP;
            --FIM DO CONTRATO + GRUPO
            END IF;
         ELSE -------------------COM PRODUTO--IF-2.1.-------------------------------------------------------------------------------------
            IF PCONTVENDA = 0
            THEN --COM VENDA----------------------------------------------------------------------------------------------------------
               --Roda com grupo, com produto sendo venda.
               FOR CUR_CUS2
                  IN (  SELECT PARC.CODPARC,
                               PARC.CODTIPPARC,
                               PARC.CLIENTE,
                               PARC.FORNECEDOR,
                               PARC.VENDEDOR
                          FROM TGFPAR PARC
                         WHERE     PARC.CODTIPPARC = CUR_CUS.CODTIPPARC --PERFIL 30000001
                               AND PARC.CLIENTE = NVL (CUR_CUS.CHCLIENTE, 'N') --CLIENTE S/N
                               AND PARC.FORNECEDOR =
                                      NVL (CUR_CUS.CHFORNECEDOR, 'N') --FORNECEDOR S/N
                               AND PARC.VENDEDOR =
                                      NVL (CUR_CUS.CHVENDEDOR, 'N') --VENDEDOR S/N
                               AND (CUR_CUS.CODGRUPOPROD) IN
                                      (SELECT DISTINCT PROD.CODGRUPOPROD --CUR_CUS.CODGRUPOPROD 99000000/
                                         FROM TGFPRO PROD
                                        WHERE PROD.CODPROD IN
                                                 (SELECT ITE.CODPROD
                                                    FROM TGFITE ITE
                                                   WHERE ITE.NUNOTA IN
                                                            (SELECT CAB.NUNOTA
                                                               FROM TGFCAB CAB
                                                              WHERE     CAB.CODPARC =
                                                                           PARC.CODPARC
                                                                    AND DTFATUR BETWEEN (  SYSDATE
                                                                                         - CUR_CUS.PERIODO)
                                                                                    AND (SYSDATE) --CUR_CUS.PERIODO (30/180/365)
                                                                    AND (CASE
                                                                            WHEN CAB.STATUSNFE =
                                                                                    'A'
                                                                            THEN
                                                                               'S'
                                                                            ELSE
                                                                               'N'
                                                                         END) =
                                                                           CUR_CUS.VENDAOK)))
                               AND (SELECT COUNT (P.CODPROD)
                                      FROM ---------Sub tabela
                                           (SELECT DISTINCT
                                                   PROD.CODPROD, CAB.CODPARC
                                              FROM TGFPRO PROD,
                                                   TGFITE ITE,
                                                   TGFCAB CAB
                                             WHERE     PROD.CODPROD =
                                                          ITE.CODPROD
                                                   AND ITE.NUNOTA = CAB.NUNOTA
                                                   AND CAB.DTFATUR BETWEEN (  SYSDATE
                                                                            - CUR_CUS.PERIODO)
                                                                       AND (SYSDATE) --CUR_CUS.PERIODO (30/180/365)
                                                   AND CAB.VLRNOTA BETWEEN NVL (
                                                                              CUR_CUS.VLRMENOR,
                                                                              0)
                                                                       AND NVL (
                                                                              CUR_CUS.VLRMAIOR,
                                                                              99999999) --CUR_CUS.VLRMENOR) AND (CUR_CUS.VLRMAIOR) (00.00)
                                                   AND PROD.CODPROD IN
                                                          (SELECT DISTINCT
                                                                  PRO.CODPROD
                                                             FROM AD_MKTREGPERFIS
                                                                  REG,
                                                                  AD_MKTPROPERFIS
                                                                  PRO
                                                            WHERE     REG.CODREGPERFIL =
                                                                         PRO.CODREGPERFIL
                                                                  AND REG.CODREGPERFIL =
                                                                         CUR_CUS.CODREGPERFIL --CUR_CUS.CODREGPERFIL
                                                                                             ))
                                           P
                                     WHERE P.CODPARC = PARC.CODPARC) <> 0
                      ORDER BY 1)
               LOOP
                  --3. Ao localizar um parceiro que se enquadra nas regras acima,
                  --   localizamos se existem perfis já cadastrado neste parceiro 3.1
                  --   eliminamos os já cadastrado e inserimos os demais 3.2
                  --   depois removemos os perfis segundo as regras 4.
                  --3.1


                  SELECT COUNT (INS.CODTIPPARC)
                    INTO PIGUALINS
                    FROM AD_MKTINCPERFIS INS
                   WHERE     INS.CODREGPERFIL = CUR_CUS.CODREGPERFIL
                         AND INS.CODTIPPARC NOT IN
                                (SELECT PARC.CODTIPPARC
                                   FROM TGFPPA PARC
                                  WHERE PARC.CODPARC = CUR_CUS2.CODPARC);

                  IF PIGUALINS <> 0
                  THEN
                     --3.2
                     INSERT INTO TGFPPA (CODPARC,
                                         CODCONTATO,
                                         CODTIPPARC,
                                         CODUSU,
                                         DTALTER)
                        (SELECT CUR_CUS2.CODPARC AS CODPARC,
                                0 AS CODCONTATO,
                                INS.CODTIPPARC,
                                0 AS CODUSU,
                                SYSDATE
                           FROM AD_MKTINCPERFIS INS
                          WHERE     INS.CODTIPPARC NOT IN
                                       (SELECT PARC.CODTIPPARC
                                          FROM TGFPPA PARC
                                         WHERE PARC.CODPARC =
                                                  CUR_CUS2.CODPARC)
                                AND INS.CODREGPERFIL = CUR_CUS.CODREGPERFIL);

                     COMMIT;
                     PCONTINSERT := PCONTINSERT + 1;
                  END IF;

                  --4.Deletando segunto as regras.
                  SELECT COUNT (INS.CODTIPPARC)
                    INTO PIGUALDEL
                    FROM AD_MKTREMPERFIS INS
                   WHERE     INS.CODREGPERFIL = CUR_CUS.CODREGPERFIL
                         AND INS.CODTIPPARC IN
                                (SELECT PARC.CODTIPPARC
                                   FROM TGFPPA PARC
                                  WHERE PARC.CODPARC = CUR_CUS2.CODPARC);

                  IF PIGUALDEL <> 0
                  THEN
                     DELETE FROM TGFPPA PPA
                           WHERE     PPA.CODPARC = CUR_CUS2.CODPARC
                                 AND PPA.CODTIPPARC IN
                                        (SELECT INS.CODTIPPARC
                                           FROM AD_MKTREMPERFIS INS
                                          WHERE     INS.CODTIPPARC IN
                                                       (SELECT PARC.CODTIPPARC
                                                          FROM TGFPPA PARC
                                                         WHERE PARC.CODPARC =
                                                                  CUR_CUS2.CODPARC)
                                                AND INS.CODREGPERFIL =
                                                       CUR_CUS.CODREGPERFIL);

                     COMMIT;
                     PCONTDELETE := PCONTDELETE + 1;
                  END IF;
               END LOOP;
            ELSE --------------------COM CONTRATO-------------------------------------------------------------------------------------------------------
                                                           --2.Roda com grupo,
               FOR CUR_CUS2
                  IN (  SELECT PARC.CODPARC,
                               PARC.CODTIPPARC,
                               PARC.CLIENTE,
                               PARC.FORNECEDOR,
                               PARC.VENDEDOR
                          FROM TGFPAR PARC
                         WHERE     PARC.CODTIPPARC = CUR_CUS.CODTIPPARC --PERFIL 30000001
                               AND PARC.CLIENTE = NVL (CUR_CUS.CHCLIENTE, 'N') --CLIENTE S/N
                               AND PARC.FORNECEDOR =
                                      NVL (CUR_CUS.CHFORNECEDOR, 'N') --FORNECEDOR S/N
                               AND PARC.VENDEDOR =
                                      NVL (CUR_CUS.CHVENDEDOR, 'N') --VENDEDOR S/N
                               AND (CUR_CUS.CODGRUPOPROD) IN
                                      (SELECT DISTINCT PROD.CODGRUPOPROD --CUR_CUS.CODGRUPOPROD 99000000/
                                         FROM TGFPRO PROD
                                        WHERE PROD.CODPROD IN
                                                 (SELECT ITE.CODPROD
                                                    FROM TGFITE ITE
                                                   WHERE ITE.NUNOTA IN
                                                            (SELECT CAB.NUNOTA
                                                               FROM TGFCAB CAB
                                                              WHERE     CAB.CODPARC =
                                                                           PARC.CODPARC
                                                                    AND DTFATUR BETWEEN (  SYSDATE
                                                                                         - CUR_CUS.PERIODO)
                                                                                    AND (SYSDATE)))) --CUR_CUS.PERIODO (30/180/365)
                               AND (SELECT COUNT (P.CODPROD)
                                      FROM ---------Sub tabela
                                           (SELECT DISTINCT
                                                   PROD.CODPROD, CAB.CODPARC
                                              FROM TGFPRO PROD,
                                                   TGFITE ITE,
                                                   TGFCAB CAB
                                             WHERE     PROD.CODPROD =
                                                          ITE.CODPROD
                                                   --AND CAB.CODPARC = PARC.CODPARC
                                                   AND ITE.NUNOTA = CAB.NUNOTA
                                                   AND DTFATUR BETWEEN (  SYSDATE
                                                                        - CUR_CUS.PERIODO)
                                                                   AND (SYSDATE) --CUR_CUS.PERIODO (30/180/365)
                                                   AND PROD.CODPROD IN
                                                          (SELECT DISTINCT
                                                                  PRO.CODPROD
                                                             FROM AD_MKTREGPERFIS
                                                                  REG,
                                                                  AD_MKTPROPERFIS
                                                                  PRO
                                                            WHERE     REG.CODREGPERFIL =
                                                                         PRO.CODREGPERFIL
                                                                  AND REG.CODREGPERFIL =
                                                                         CUR_CUS.CODREGPERFIL --CUR_CUS.CODREGPERFIL
                                                                                             ))
                                           P
                                     WHERE P.CODPARC = PARC.CODPARC) <> 0
                               AND (SELECT COUNT (P.CODPROD)
                                      FROM (SELECT PSC.CODPROD, CON.CODPARC
                                              FROM TCSCON CON, TCSPSC PSC
                                             WHERE     CON.NUMCONTRATO =
                                                          PSC.NUMCONTRATO
                                                   AND DTCONTRATO BETWEEN (  SYSDATE
                                                                           - CUR_CUS.PERIODO)
                                                                      AND (SYSDATE) --CUR_CUS.PERIODO (30/180/365)
                                                   AND CON.ATIVO =
                                                          CUR_CUS.CONTRATOATIVO
                                                   AND PSC.CODPROD IN
                                                          (SELECT DISTINCT
                                                                  PRO.CODPROD
                                                             FROM AD_MKTREGPERFIS
                                                                  REG,
                                                                  AD_MKTPROPERFIS
                                                                  PRO
                                                            WHERE     REG.CODREGPERFIL =
                                                                         PRO.CODREGPERFIL
                                                                  AND REG.CODREGPERFIL =
                                                                         CUR_CUS.CODREGPERFIL))
                                           P            --CUR_CUS.CODREGPERFIL
                                     WHERE P.CODPARC = PARC.CODPARC) <> 0
                               AND (SELECT DISTINCT
                                           (SUM (
                                               (PRE.VALOR * PSC.NUMUSUARIOS)))
                                      FROM TCSCON CON, TCSPSC PSC, TCSPRE PRE
                                     WHERE     CON.NUMCONTRATO =
                                                  PSC.NUMCONTRATO
                                           AND PSC.NUMCONTRATO =
                                                  PRE.NUMCONTRATO
                                           AND PSC.CODPROD = PRE.CODPROD
                                           AND CON.DTCONTRATO BETWEEN (  SYSDATE
                                                                       - CUR_CUS.PERIODO)
                                                                  AND (SYSDATE) --CUR_CUS.PERIODO (30/180/365)
                                           AND CON.ATIVO =
                                                  CUR_CUS.CONTRATOATIVO
                                           AND CON.CODPARC = PARC.CODPARC) BETWEEN NVL (
                                                                                      CUR_CUS.VLRMENOR,
                                                                                      0)
                                                                               AND NVL (
                                                                                      CUR_CUS.VLRMAIOR,
                                                                                      99999999) --CUR_CUS.VLRMENOR) AND (CUR_CUS.VLRMAIOR) (00.00)
                      ORDER BY 1)
               LOOP
                  --3. Ao localizar um parceiro que se enquadra nas regras acima,
                  --   localizamos se existem perfis já cadastrado neste parceiro 3.1
                  --   eliminamos os já cadastrado e inserimos os demais 3.2
                  --   depois removemos os perfis segundo as regras 4.
                  --3.1


                  SELECT COUNT (INS.CODTIPPARC)
                    INTO PIGUALINS
                    FROM AD_MKTINCPERFIS INS
                   WHERE     INS.CODREGPERFIL = CUR_CUS.CODREGPERFIL
                         AND INS.CODTIPPARC NOT IN
                                (SELECT PARC.CODTIPPARC
                                   FROM TGFPPA PARC
                                  WHERE PARC.CODPARC = CUR_CUS2.CODPARC);

                  IF PIGUALINS <> 0
                  THEN
                     --3.2
                     INSERT INTO TGFPPA (CODPARC,
                                         CODCONTATO,
                                         CODTIPPARC,
                                         CODUSU,
                                         DTALTER)
                        (SELECT CUR_CUS2.CODPARC AS CODPARC,
                                0 AS CODCONTATO,
                                INS.CODTIPPARC,
                                0 AS CODUSU,
                                SYSDATE
                           FROM AD_MKTINCPERFIS INS
                          WHERE     INS.CODTIPPARC NOT IN
                                       (SELECT PARC.CODTIPPARC
                                          FROM TGFPPA PARC
                                         WHERE PARC.CODPARC =
                                                  CUR_CUS2.CODPARC)
                                AND INS.CODREGPERFIL = CUR_CUS.CODREGPERFIL);

                     COMMIT;
                     PCONTINSERT := PCONTINSERT + 1;
                  END IF;

                  --4.Deletando segunto as regras.
                  SELECT COUNT (INS.CODTIPPARC)
                    INTO PIGUALDEL
                    FROM AD_MKTREMPERFIS INS
                   WHERE     INS.CODREGPERFIL = CUR_CUS.CODREGPERFIL
                         AND INS.CODTIPPARC IN
                                (SELECT PARC.CODTIPPARC
                                   FROM TGFPPA PARC
                                  WHERE PARC.CODPARC = CUR_CUS2.CODPARC);

                  IF PIGUALDEL <> 0
                  THEN
                     DELETE FROM TGFPPA PPA
                           WHERE     PPA.CODPARC = CUR_CUS2.CODPARC
                                 AND PPA.CODTIPPARC IN
                                        (SELECT INS.CODTIPPARC
                                           FROM AD_MKTREMPERFIS INS
                                          WHERE     INS.CODTIPPARC IN
                                                       (SELECT PARC.CODTIPPARC
                                                          FROM TGFPPA PARC
                                                         WHERE PARC.CODPARC =
                                                                  CUR_CUS2.CODPARC)
                                                AND INS.CODREGPERFIL =
                                                       CUR_CUS.CODREGPERFIL);

                     COMMIT;
                     PCONTDELETE := PCONTDELETE + 1;
                  END IF;
               END LOOP;
            --FIM DO CONTRATO + GRUPO
            END IF;
         --FIM PRODUTOS + GRUPO
         END IF;
      END IF;
   END LOOP;

   P_MENSAGEM :=
      (   '<font size="12">Perfil secundário dos Parceiros atualizados com sucesso!<br>Total de Registros inseridos: '
       || TO_CHAR (PCONTINSERT)
       || '.<br>Total de Registros Removidos: '
       || TO_CHAR (PCONTDELETE)
       || '.</font>');
END;
/