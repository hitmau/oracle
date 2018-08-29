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
    Descri��o: Quando o e-commerce insere no sankhya � inserido na tabela de avisos para o usu�rio que est� no campo "executante" (dono da venda)!
    */


    --Executa apenas para a top 5010 orpamento web (vinda do e-commerce)
    IF :NEW.CODTIPOPER = (5010) THEN
        --Guarda o c�digo do executante na vari�vel.
        PCODVEND := :NEW.AD_EXEC;
        --Verifica se a vari�vel est� nula caso contr�rio n�o entra.
        IF PCODVEND IS NOT NULL THEN
        
            --Obtem a quantidade de usu�rios com o c�digo do vendedor e o c�digo do usu�rio que est� atrelado ao vendedor.
            SELECT COUNT(*), MAX(CODUSU)
            INTO P_COUNT, PCODUSU
            FROM TSIUSU
            WHERE CODVEND = :NEW.CODVEND;
            
            --Obtem o nome do cliente
            SELECT PARC.NOMEPARC
            INTO PNOMEPARC
            FROM TGFPAR PARC
            WHERE PARC.CODPARC = :NEW.CODPARC;
            
            --Obtem o n�mero do contrato que est� vinculado ao numero do ecommerce.
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
        
            --Verifica se o vendedor est� atrelado a apenas 1 usu�rio caso contr�rio n�o entra.
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
                'Conferir o or�amento e dar continuidade!<br>Nro do Pedido ' || TO_CHAR(:NEW.NUNOTA) || ' (' || TO_CHAR(PNOMEPARC) || ')!' || PTEXTCONTRATO
                ,'PERSONALIZADO', 1, PCODUSU, 'P', SYSDATE, 0);
                
                --Insere aviso na tela (pop-up)
                INSERT INTO
                TSIAVI (NUAVISO, TITULO, DESCRICAO, IDENTIFICADOR, IMPORTANCIA, CODUSU, TIPO, DHCRIACAO, CODUSUREMETENTE,SOLUCAO)
                VALUES ((SELECT MAX(NUAVISO)+1 FROM TSIAVI),
                'Novo Pedido E-commerce!',
                'Favor conferir o or�amento e dar continuidade (faturar)!<br> Nro do Pedido ' || TO_CHAR(:NEW.NUNOTA) || '!' || PTEXTCONTRATO
                ,'PERSONALIZADO', 0, PCODUSU, 'P', SYSDATE, 0,'Caso existe alguma diverg�ncia em sua venda (pre�o, quantidade, produto) fale com seu supervisor.');
                
            END IF;
        END IF;
    END IF;

END;
/
