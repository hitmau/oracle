CREATE OR REPLACE PROCEDURE TOTALPRD.ATU_CAR_P_AREA_TOTAL
      (P_CODUSU NUMBER,        -- C�digo do usu�rio logado
       P_IDSESSAO VARCHAR2,    -- Identificador da execu��o. Serve para buscar informa��es dos par�metros/campos da execu��o.
       P_QTDLINHAS NUMBER,     -- Informa a quantidade de registros selecionados no momento da execu��o.
       P_MENSAGEM OUT VARCHAR2 -- Caso seja passada uma mensagem aqui, ela ser� exibida como uma informa��o ao usu�rio.

)AS
   VPROSPECT INT := 0;
   VPARCEIRO INT := 0;
BEGIN
    /*
DESCRI��O:1. 
AUTOR: Mauricio Rodrigues
ATUALIZA��O: Mauricio Rodrigues
Data da cria��o: 28/11/2017
*/
   --1. Loop para executar cada regra pelo seu indice (CODREGPERFIL).  
EXECUTE IMMEDIATE 'ALTER TRIGGER TRG_UPD_TGFPAR_TOTAL DISABLE'; 
   FOR CUR_CUS IN (SELECT REG.CODREG
                        , REG.NOMEREG
                        , REG.CODREGPAI
                        , NVL(REG.AD_ATIVAPARCEIRO, 'N') AS AD_ATIVAPARCEIRO
                        , NVL(REG.AD_ATIVAPROSPECT, 'N') AS AD_ATIVAPROSPECT
                        , (SELECT USU.CODGRUPO FROM TSIUSU USU WHERE REG.AD_GERENTE = USU.CODUSU) AS GRUPO
                    FROM TSIREG REG
                    WHERE REG.CODREGPAI LIKE '2%' AND REG.ANALITICA = 'S' AND REG.ATIVA = 'S' 
                        AND (SELECT USU.CODGRUPO FROM TSIUSU USU WHERE REG.AD_GERENTE = USU.CODUSU) IN (11,12,34)
                                                                                                        --11 = Distribui��o
                                                                                                        --12 = Automa��o
                                                                                                        --13 = Suporte
                    ORDER BY 1)
   LOOP
            IF CUR_CUS.AD_ATIVAPARCEIRO = 'S' THEN
                VPARCEIRO := 1;
            ELSE 
                VPARCEIRO := 0;
            END IF;
            
            IF CUR_CUS.AD_ATIVAPROSPECT = 'S' THEN
                VPROSPECT := 1;
            ELSE 
                VPROSPECT := 0;
            END IF;
            
            IF CUR_CUS.GRUPO = 11 THEN
                    FOR CUR2 IN (SELECT AREA.CODREG, AREA.CODBAI, AREA.CODCID, (SELECT CID.UF FROM TSICID CID WHERE AREA.CODCID=CID.CODCID) AS UF
                                 FROM AD_AREAS AREA 
                                 WHERE (SELECT REG.ATIVA FROM TSIREG REG WHERE AREA.CODREG = REG.CODREG) = 'S'
                                    AND AREA.CODREG = CUR_CUS.CODREG
                                 ORDER BY 1,2)
                    LOOP
                        -----------------------SEM BAIRRO                      
                        IF CUR2.CODBAI IS NULL THEN
                            -------------------SE FOR PROSPECT
                            IF VPROSPECT = 1 THEN
                                UPDATE TCSPAP PAP SET PAP.AD_REGIAODISTRIBUICAO = CUR2.CODREG WHERE (SELECT MAX(CID.CODCID) FROM TSICID CID WHERE CID.NOMECID = PAP.NOMECID) = CUR2.CODCID
                                                                                                AND (SELECT MAX(CID.UF)     FROM TSICID CID WHERE CID.NOMECID = PAP.NOMECID) = CUR2.UF;
                                COMMIT;                                                                
                            END IF;
                            -------------------SE FOR PARCEIRO
                            IF VPARCEIRO = 1 THEN
                                UPDATE TGFPAR PARC SET PARC.AD_REGIAODISTRIBUICAO = CUR2.CODREG WHERE PARC.CODCID = CUR2.CODCID
                                                                                                  AND (SELECT MAX(CID.UF) FROM TSICID CID WHERE CID.CODCID=PARC.CODCID) = CUR2.UF;
                                COMMIT;
                            END IF;                                                                 
                        ELSE-------------------COM BAIRRO
                            -------------------SE FOR PROSPECT
                            IF VPROSPECT = 1 THEN
                                UPDATE TCSPAP PAP SET PAP.AD_REGIAODISTRIBUICAO = CUR2.CODREG WHERE (SELECT MAX(CID.CODCID) FROM TSICID CID WHERE CID.NOMECID = PAP.NOMECID) = CUR2.CODCID
                                                                                                AND (SELECT MAX(CID.UF)     FROM TSICID CID WHERE CID.NOMECID = PAP.NOMECID) = CUR2.UF
                                                                                                AND PAP.AD_CODBAI = CUR2.CODBAI;
                                COMMIT;
                            END IF;
                            -------------------SE FOR PARCEIRO
                            IF VPARCEIRO = 1 THEN
                                UPDATE TGFPAR PARC SET PARC.AD_REGIAODISTRIBUICAO = CUR2.CODREG WHERE PARC.CODCID = CUR2.CODCID
                                                                                                  AND (SELECT MAX(CID.UF) FROM TSICID CID WHERE CID.CODCID=PARC.CODCID) = CUR2.UF
                                                                                                  AND PARC.CODBAI = CUR2.CODBAI;
                                COMMIT;
                            END IF; END IF;
                --P_MENSAGEM := ('<font size="12">Prospect ativo!</font>');
                END LOOP;                                   
            END IF;
            IF CUR_CUS.GRUPO = 12 THEN 
                FOR CUR2 IN (SELECT AREA.CODREG, AREA.CODBAI, AREA.CODCID, (SELECT CID.UF FROM TSICID CID WHERE AREA.CODCID=CID.CODCID) AS UF
                                 FROM AD_AREAS AREA 
                                 WHERE (SELECT REG.ATIVA FROM TSIREG REG WHERE AREA.CODREG = REG.CODREG) = 'S'
                                    AND AREA.CODREG = CUR_CUS.CODREG
                                 ORDER BY 1,2)
                    LOOP
                        -----------------------SEM BAIRRO                      
                        IF CUR2.CODBAI IS NULL THEN
                            -------------------SE FOR PROSPECT
                            IF VPROSPECT = 1 THEN
                                UPDATE TCSPAP PAP SET PAP.AD_REGIAOAUTOMACAO = CUR2.CODREG WHERE (SELECT MAX(CID.CODCID) FROM TSICID CID WHERE CID.NOMECID = PAP.NOMECID) = CUR2.CODCID
                                                                                                AND (SELECT MAX(CID.UF)     FROM TSICID CID WHERE CID.NOMECID = PAP.NOMECID) = CUR2.UF;
                                COMMIT;
                            END IF;
                            -------------------SE FOR PARCEIRO
                            IF VPARCEIRO = 1 THEN
                                UPDATE TGFPAR PARC SET PARC.AD_REGIAOAUTOMACAO = CUR2.CODREG WHERE PARC.CODCID = CUR2.CODCID
                                                                                                  AND (SELECT MAX(CID.UF) FROM TSICID CID WHERE CID.CODCID=PARC.CODCID) = CUR2.UF;
                                COMMIT;
                            END IF;                                                                 
                        ELSE-------------------COM BAIRRO
                            -------------------SE FOR PROSPECT
                            IF VPROSPECT = 1 THEN
                                UPDATE TCSPAP PAP SET PAP.AD_REGIAOAUTOMACAO = CUR2.CODREG WHERE (SELECT MAX(CID.CODCID) FROM TSICID CID WHERE CID.NOMECID = PAP.NOMECID) = CUR2.CODCID
                                                                                                AND (SELECT MAX(CID.UF)     FROM TSICID CID WHERE CID.NOMECID = PAP.NOMECID) = CUR2.UF
                                                                                                AND PAP.AD_CODBAI = CUR2.CODBAI;
                                COMMIT;
                            END IF;
                            -------------------SE FOR PARCEIRO
                            IF VPARCEIRO = 1 THEN
                                UPDATE TGFPAR PARC SET PARC.AD_REGIAOAUTOMACAO = CUR2.CODREG WHERE PARC.CODCID = CUR2.CODCID
                                                                                                  AND (SELECT MAX(CID.UF) FROM TSICID CID WHERE CID.CODCID=PARC.CODCID) = CUR2.UF
                                                                                                  AND PARC.CODBAI = CUR2.CODBAI;
                                COMMIT;
                            END IF;
                        END IF;
                END LOOP;
            END IF;
            IF CUR_CUS.GRUPO = 34 THEN
                    FOR CUR2 IN (SELECT AREA.CODREG, AREA.CODBAI, AREA.CODCID, (SELECT CID.UF FROM TSICID CID WHERE AREA.CODCID=CID.CODCID) AS UF
                                 FROM AD_AREAS AREA 
                                 WHERE (SELECT REG.ATIVA FROM TSIREG REG WHERE AREA.CODREG = REG.CODREG) = 'S'
                                    AND AREA.CODREG = CUR_CUS.CODREG
                                 ORDER BY 1,2)
                    LOOP
                        -----------------------SEM BAIRRO                      
                        IF CUR2.CODBAI IS NULL THEN
                            -------------------SE FOR PROSPECT
                            IF VPROSPECT = 1 THEN
                                UPDATE TCSPAP PAP SET PAP.AD_REGIAOSUPORTE = CUR2.CODREG WHERE (SELECT MAX(CID.CODCID) FROM TSICID CID WHERE CID.NOMECID = PAP.NOMECID) = CUR2.CODCID
                                                                                                AND (SELECT MAX(CID.UF)     FROM TSICID CID WHERE CID.NOMECID = PAP.NOMECID) = CUR2.UF;
                                COMMIT;                                                                
                            END IF;
                            -------------------SE FOR PARCEIRO
                            IF VPARCEIRO = 1 THEN
                                UPDATE TGFPAR PARC SET PARC.AD_REGIAOSUPORTE = CUR2.CODREG WHERE PARC.CODCID = CUR2.CODCID
                                                                                                  AND (SELECT MAX(CID.UF) FROM TSICID CID WHERE CID.CODCID=PARC.CODCID) = CUR2.UF;
                                COMMIT;
                            END IF;                                                                 
                        ELSE-------------------COM BAIRRO
                            -------------------SE FOR PROSPECT
                            IF VPROSPECT = 1 THEN
                                UPDATE TCSPAP PAP SET PAP.AD_REGIAOSUPORTE = CUR2.CODREG WHERE (SELECT MAX(CID.CODCID) FROM TSICID CID WHERE CID.NOMECID = PAP.NOMECID) = CUR2.CODCID
                                                                                                AND (SELECT MAX(CID.UF)     FROM TSICID CID WHERE CID.NOMECID = PAP.NOMECID) = CUR2.UF
                                                                                                AND PAP.AD_CODBAI = CUR2.CODBAI;
                                COMMIT;
                            END IF;
                            -------------------SE FOR PARCEIRO
                            IF VPARCEIRO = 1 THEN
                                UPDATE TGFPAR PARC SET PARC.AD_REGIAOSUPORTE = CUR2.CODREG WHERE PARC.CODCID = CUR2.CODCID
                                                                                                  AND (SELECT MAX(CID.UF) FROM TSICID CID WHERE CID.CODCID=PARC.CODCID) = CUR2.UF
                                                                                                  AND PARC.CODBAI = CUR2.CODBAI;
                                COMMIT;
                            END IF; END IF;
                --P_MENSAGEM := ('<font size="12">Prospect ativo!</font>');
                END LOOP;                                   
            END IF;
   END LOOP;  
   EXECUTE IMMEDIATE 'ALTER TRIGGER TRG_UPD_TGFPAR_TOTAL ENABLE'; 
   P_MENSAGEM := ('<span class="spans"><b>Atualiza��o das Regi�es finalizada!</b></span>');
END;
/