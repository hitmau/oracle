DROP TRIGGER TOTALPRD.TRG_INC_NOVO_ECOM_TOTAL;

CREATE OR REPLACE TRIGGER TOTALPRD.TRG_INC_NOVO_ECOM_TOTAL  
BEFORE INSERT ON TOTALPRD.TGFCAB  FOR EACH ROW
DECLARE 
--    P_COUNT                  INT:= 0;
--    P_NOMEUSU             TSIUSU.NOMEUSU%TYPE;
--    ERRMSG  VARCHAR2(255);
    P_COUNT INT;
    PCODUSU INT;
    PCODVEND INT;
    PTEXTCONTRATO VARCHAR(200);
    PCONTRATO INT;
    PNOMEPARC VARCHAR(100);
BEGIN
    /*
    Autor: Mauricio Rodrigues
    Data: 18/07/2018 13:00
    Descrição: Quando o e-commerce insere no sankhya é inserido na tabela de avisos para o usuário que está no campo "executante" (dono da venda)!
    */


    --Executa apenas para a top 5010 orpamento web (vinda do e-commerce)
    IF :NEW.CODTIPOPER = (5010) THEN
        --Guarda o código do executante na variável.
        PCODVEND := :NEW.AD_EXEC;
        --Verifica se a variável está nula caso contrário não entra.
        IF PCODVEND IS NOT NULL THEN
        
            --Obtem a quantidade de usuários com o código do vendedor e o código do usuário que está atrelado ao vendedor.
            SELECT COUNT(*), MAX(CODUSU)
            INTO P_COUNT, PCODUSU
            FROM TSIUSU
            WHERE CODVEND = :NEW.CODVEND;
            
            --Obtem o nome do cliente
            SELECT PARC.NOMEPARC
            INTO PNOMEPARC
            FROM TGFPAR PARC
            WHERE PARC.CODPARC = :NEW.CODPARC;
            
            --Obtem o número do contrato que está vinculado ao numero do ecommerce.
            SELECT COUNT(CON.NUMCONTRATO)
            INTO PCONTRATO
            FROM TCSCON CON
            WHERE CON.AD_NUPEDECOMMERCE = :NEW.AD_NUNOTA_ECOMMERCE;
            
            if PCONTRATO <> 0 THEN
                SELECT CASE WHEN COUNT(CON.NUMCONTRATO) <> 0 THEN CON.NUMCONTRATO ELSE 0 END
                INTO PCONTRATO
                FROM TCSCON CON
                WHERE CON.AD_NUPEDECOMMERCE = :NEW.AD_NUNOTA_ECOMMERCE;
            END IF;
        
            --Verifica se o vendedor está atrelado a apenas 1 usuário caso contrário não entra.
            IF P_COUNT = 1 THEN
                
                --Verifica se existe contrato.
                IF PCONTRATO <> 0 THEN
                    PTEXTCONTRATO := ('<br>Nro do Contrato ' || TO_CHAR(PCONTRATO) || '!');
                END IF;
                       
               --Insere mensagem no chat.
               INSERT INTO
                TSIAVI (NUAVISO, TITULO, DESCRICAO, IDENTIFICADOR, IMPORTANCIA, CODUSU, TIPO, DHCRIACAO, CODUSUREMETENTE)
                VALUES ((SELECT MAX(NUAVISO)+1 FROM TSIAVI),
                'Novo E-commerce!',
                'Conferir o orçamento e dar continuidade!<br>Nro do Pedido ' || TO_CHAR(:NEW.NUNOTA) || ' (' || TO_CHAR(PNOMEPARC) || ')!' || PTEXTCONTRATO
                ,'PERSONALIZADO', 1, PCODUSU, 'P', SYSDATE, 0);
                
                --Insere aviso na tela (pop-up)
                INSERT INTO
                TSIAVI (NUAVISO, TITULO, DESCRICAO, IDENTIFICADOR, IMPORTANCIA, CODUSU, TIPO, DHCRIACAO, CODUSUREMETENTE,SOLUCAO)
                VALUES ((SELECT MAX(NUAVISO)+1 FROM TSIAVI),
                'Novo Pedido E-commerce!',
                'Favor conferir o orçamento e dar continuidade (faturar)!<br> Nro do Pedido ' || TO_CHAR(:NEW.NUNOTA) || '!' || PTEXTCONTRATO
                ,'PERSONALIZADO', 0, PCODUSU, 'P', SYSDATE, 0,'Caso existe alguma divergência em sua venda (preço, quantidade, produto) fale com seu supervisor.');
                
            END IF;
        END IF;
    END IF;

END;
/
