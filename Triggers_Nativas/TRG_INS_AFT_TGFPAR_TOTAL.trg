DROP TRIGGER TOTALPRD.TRG_INS_AFT_TGFPAR_TOTAL;

CREATE OR REPLACE TRIGGER TOTALPRD.TRG_INS_AFT_TGFPAR_TOTAL
   AFTER INSERT OR UPDATE ON TOTALPRD.TGFPAR
   FOR EACH ROW
DECLARE

BEGIN
        /*
            DESCRI��O: Para a pr�-venda (tela de negocia��o) � necess�rio que o parceiro tenha uma forma de pagamento na sugest�o de sa�da
            sendo assim, no momento da insers�o � inserido uma linha na TGFCPL setando a forma de pagamento dinheiro. � poss�vel que o usu�rio
            altere isso tanto na venda quanto no cadastro do cliente, caso necess�rio.
            CRIA��O: Mauricio Rodrigues
            DATA: 07/11/2017 08:21
        */

    IF INSERTING THEN
      INSERT INTO TGFCPL (CODPARC, CODUSU, DTALTER, SUGTIPNEGSAID, EXIGEPEDIDO, USASAIDAFATPER, LIMCREDAUTOM, GERARFRETE) VALUES (:NEW.CODPARC, 0, SYSDATE, 1, 'S', 'N', 'N', 'N');    
    END IF;

END;
/
