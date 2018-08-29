DROP TRIGGER TOTALPRD.TRG_INS_AD_RMA_M_TOTAL;

CREATE OR REPLACE TRIGGER TOTALPRD.TRG_INS_AD_RMA_M_TOTAL
   AFTER INSERT OR UPDATE ON TOTALPRD.AD_RMA
   FOR EACH ROW
BEGIN
        /*
            DESCRI��O: Na inclus�o de uma nova linha de acompanhamento na tela Acompanhamento do RMA 
            nesta trigger amos siltrar os fornecedores para facilitar a sele��o dos status.
            CRIA��O: Mauricio Rodrigues
            DATA: 12/11/2017 20:21
        */

              
    IF INSERTING OR updating THEN
        UPDATE AD_STATUSRMA SET STATUS = 'S' WHERE CODPARC = :NEW.CODPARC;
        UPDATE AD_STATUSRMA SET STATUS = 'N' WHERE CODPARC <> :NEW.CODPARC;
    END IF;
    

END;
/
