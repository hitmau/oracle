DROP TRIGGER TOTALPRD.TRG_INS_AD_ACOMPRMA_M_TOTAL;

CREATE OR REPLACE TRIGGER TOTALPRD.TRG_INS_AD_ACOMPRMA_M_TOTAL
   BEFORE INSERT OR UPDATE ON TOTALPRD.AD_ACOMPRMA
   FOR EACH ROW
DECLARE
    PCOUNT INT;
    PCODPARC INT;
BEGIN
        /*
            DESCRIÇÃO: Na inclusão de uma nova linha de acompanhamento na tela Acompanhamento do RMA 
            nesta trigger amos siltrar os fornecedores para facilitar a seleção dos status.
            CRIAÇÃO: Mauricio Rodrigues
            DATA: 12/11/2017 20:21
        */

Select count(codparc)
Into PCOUNT 
From AD_RMA 
Where nunota=:NEW.NUNOTA;

    IF PCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
         Falta Fornecedor no formulário principal.</font></b><br><font>');
        
    ELSE
        if Pcount > 1 then
            RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
            Número ùnico já existe.</font></b><br><font>');
         else
            Select RMA.codparc
            Into PCODPARC 
            From AD_RMA RMA 
            Where RMA.nunota = :NEW.NUNOTA;
                END IF;
    END IF;

    IF INSERTING OR updating THEN
        UPDATE AD_STATUSRMA SET STATUS = 'S' WHERE CODPARC = pcodparc;
        UPDATE AD_STATUSRMA SET STATUS = 'N' WHERE CODPARC <> pcodparc;
    END IF;
    

END;
/
