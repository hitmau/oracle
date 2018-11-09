DROP TRIGGER TOTALPRD.TRG_INS_AFT_TGFPAR_TOTAL;

CREATE OR REPLACE TRIGGER TOTALPRD.TRG_INS_AFT_TGFPAR_TOTAL
   AFTER INSERT OR UPDATE ON TOTALPRD.TGFPAR
   FOR EACH ROW
DECLARE

BEGIN
        /*
            DESCRIÇÃO: Para a pré-venda (tela de negociação) é necessário que o parceiro tenha uma forma de pagamento na sugestão de saída
            sendo assim, no momento da insersão é inserido uma linha na TGFCPL setando a forma de pagamento dinheiro. É possível que o usuário
            altere isso tanto na venda quanto no cadastro do cliente, caso necessário.
            CRIAÇÃO: Mauricio Rodrigues
            DATA: 07/11/2017 08:21
        */

    IF INSERTING THEN
      INSERT INTO TGFCPL (CODPARC, CODUSU, DTALTER, SUGTIPNEGSAID, EXIGEPEDIDO, USASAIDAFATPER, LIMCREDAUTOM, GERARFRETE) VALUES (:NEW.CODPARC, 0, SYSDATE, 1, 'S', 'N', 'N', 'N');    
    END IF;

END;
/
