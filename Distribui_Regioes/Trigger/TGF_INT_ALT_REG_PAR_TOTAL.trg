DROP TRIGGER TOTALTST.TGF_INT_ALT_REG_PAR_TOTAL;

CREATE OR REPLACE TRIGGER TOTALTST.TGF_INT_ALT_REG_PAR_TOTAL  
BEFORE INSERT OR UPDATE ON TOTALTST.AD_AREAS
FOR EACH ROW
DECLARE  
    CONT INT := 0;
    PREGIAO VARCHAR(4000) := 'TESTES';
BEGIN

/*
    Autor: Mauricio Rodrigues
    Data: 27/08/2018
    Destri��o: Trigguer para a tabela de Areas da tela de Regi�es que impede a 
               inser��o de bairro ou cidades duplicados dentro de um mesmo diret�rio.
*/
--Caso n�o tenha bairro
IF :NEW.CODBAI IS NULL THEN
    --Verifica se a inser��o tem duplicidade
    SELECT COUNT(*), NVL(MAX(AD.CODREG),0)
    INTO CONT, PREGIAO
    FROM AD_AREAS AD INNER JOIN TSIREG REG ON (AD.CODREG = REG.CODREG)
    WHERE AD.CODCID = :NEW.CODCID
      AND AD.CODREG = :NEW.CODREG
      AND SUBSTR(:NEW.CODREG,0,3) = SUBSTR(REG.CODREGPAI,0,3);
    
    --Verifica qual o diret�rio (regi�o) e armazena na vari�vel.
    SELECT CODREG ||' - '|| NOMEREG
    INTO PREGIAO FROM TSIREG WHERE CODREG = PREGIAO;
ELSE --caso tenha bairro

    --Verifica se existe duplicidade
    SELECT COUNT(*), NVL(MAX(AD.CODREG),0)
    INTO CONT, PREGIAO
    FROM AD_AREAS AD INNER JOIN TSIREG REG ON (AD.CODREG = REG.CODREG)
    WHERE NVL(AD.CODBAI,0) = NVL(:NEW.CODBAI,0) 
      AND AD.CODCID = :NEW.CODCID
      AND SUBSTR(:NEW.CODREG,0,3) = SUBSTR(REG.CODREGPAI,0,3);
    
    --Verifica qual o diret�rio (regi�o) e armazena na vari�vel.        
    SELECT CODREG ||' - '|| NOMEREG
    INTO PREGIAO FROM TSIREG WHERE CODREG = PREGIAO;
END IF;

    --Caso exista duplicidade o cont ser� diferente que 0
   IF CONT <> 0 THEN
        RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#0000000">
Registro j� existe na Regi�o:<br>' || TO_CHAR(PREGIAO) || '.</font></b><br><font>');
   END IF;
END;
/
