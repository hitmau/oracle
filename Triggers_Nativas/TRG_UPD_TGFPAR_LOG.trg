DROP TRIGGER TOTALPRD.TRG_UPD_TGFPAR_LOG;

CREATE OR REPLACE TRIGGER TOTALPRD.TRG_UPD_TGFPAR_LOG  
BEFORE UPDATE 
ON TOTALPRD.TGFPAR 
FOR EACH ROW
DECLARE 
    P_ACAO       VARCHAR2(10); 
    P_CHAVEPK VARCHAR(400);
    P_COUNT      NUMBER(10);

BEGIN

  IF STP_GET_ATUALIZANDO THEN
    RETURN;
  END IF;

  IF UPDATING('CODCID') OR UPDATING('CODBAI') OR UPDATING('CODEND') OR 
     UPDATING('COMPLEMENTO') OR UPDATING('NUMEND') OR UPDATING('IDENTINSCESTAD') OR 
     UPDATING('CGC_CPF') OR UPDATING('RAZAOSOCIAL') THEN
     P_COUNT := 0;
     BEGIN
         SELECT COUNT(1) INTO P_COUNT 
         FROM TGFCAB C
            , TGFTOP T 
         WHERE C.CODPARC = :NEW.CODPARC 
           AND C.CODTIPOPER = T.CODTIPOPER 
           AND C.DHTIPOPER = T.DHALTER 
           AND T.ATUALLIVFIS <> 'N';
     EXCEPTION WHEN NO_DATA_FOUND THEN
       P_COUNT := 0;
     END;
     IF P_COUNT = 0 THEN
         RETURN;
     END IF;
    P_CHAVEPK := :NEW.CODPARC;    
    IF ((NVL(:OLD.RAZAOSOCIAL,'null')) <> (NVL(:NEW.RAZAOSOCIAL,'null'))) THEN
        BEGIN
          SELECT COUNT(1) INTO P_COUNT
          FROM TSIALT          
          WHERE NOMETAB = 'TGFPAR'
            AND CONTEUDO = :OLD.RAZAOSOCIAL
            AND CHAVE = P_CHAVEPK;
        EXCEPTION WHEN NO_DATA_FOUND THEN
          P_COUNT := 0;
        END;
        IF P_COUNT = 0 THEN
           Stp_Logtsialt('TGFPAR', P_CHAVEPK,'RAZAOSOCIAL', :OLD.RAZAOSOCIAL, (SYSDATE -1));
        END IF;
        Stp_Logtsialt('TGFPAR', P_CHAVEPK,'RAZAOSOCIAL', :NEW.RAZAOSOCIAL);
    END IF;

    IF ((NVL(:OLD.CGC_CPF,'null')) <> (NVL(:NEW.CGC_CPF,'null'))) THEN
        BEGIN
          SELECT COUNT(1) INTO P_COUNT
          FROM TSIALT          
          WHERE NOMETAB = 'TGFPAR'
            AND CONTEUDO = :OLD.CGC_CPF
            AND CHAVE = P_CHAVEPK;
        EXCEPTION WHEN NO_DATA_FOUND THEN
          P_COUNT := 0;
        END;
        IF P_COUNT = 0 THEN
           Stp_Logtsialt('TGFPAR', P_CHAVEPK,'CGC_CPF', :OLD.CGC_CPF, (SYSDATE -1));
        END IF;   
        Stp_Logtsialt('TGFPAR', P_CHAVEPK,'CGC_CPF', :NEW.CGC_CPF);
    END IF;

    IF ((NVL(:OLD.IDENTINSCESTAD,'null')) <> (NVL(:NEW.IDENTINSCESTAD,'null'))) THEN
        BEGIN      
          SELECT COUNT(1) INTO P_COUNT
          FROM TSIALT          
          WHERE NOMETAB = 'TGFPAR'
            AND CONTEUDO = :OLD.IDENTINSCESTAD
            AND CHAVE = P_CHAVEPK;
        EXCEPTION WHEN NO_DATA_FOUND THEN
          P_COUNT := 0;
        END;
        IF P_COUNT = 0 THEN
           Stp_Logtsialt('TGFPAR', P_CHAVEPK,'IDENTINSCESTAD', :OLD.IDENTINSCESTAD, (SYSDATE -1));
        END IF;    
        Stp_Logtsialt('TGFPAR', P_CHAVEPK,'IDENTINSCESTAD', :NEW.IDENTINSCESTAD);
    END IF;

    IF ((NVL(:OLD.NUMEND,'null')) <> (NVL(:NEW.NUMEND,'null'))) THEN
        BEGIN
          SELECT COUNT(1) INTO P_COUNT
          FROM TSIALT          
          WHERE NOMETAB = 'TGFPAR'
            AND CONTEUDO = TO_CHAR(:OLD.NUMEND)
            AND CHAVE = P_CHAVEPK;            
        EXCEPTION WHEN NO_DATA_FOUND THEN
          P_COUNT := 0;
        END;
        IF P_COUNT = 0 THEN
           Stp_Logtsialt('TGFPAR', P_CHAVEPK,'NUMEND', TO_CHAR(:OLD.NUMEND), (SYSDATE -1));
        END IF;  
        Stp_Logtsialt('TGFPAR', P_CHAVEPK,'NUMEND', TO_CHAR(:NEW.NUMEND));
    END IF;

    IF ((NVL(:OLD.COMPLEMENTO,'null')) <> (NVL(:NEW.COMPLEMENTO,'null'))) THEN
        BEGIN
          SELECT COUNT(1) INTO P_COUNT
          FROM TSIALT          
          WHERE NOMETAB = 'TGFPAR'
            AND CONTEUDO = :OLD.COMPLEMENTO
            AND CHAVE = P_CHAVEPK;
        EXCEPTION WHEN NO_DATA_FOUND THEN
          P_COUNT := 0;
        END;
        IF P_COUNT = 0 THEN
           Stp_Logtsialt('TGFPAR', P_CHAVEPK,'COMPLEMENTO', :OLD.COMPLEMENTO, (SYSDATE -1));
        END IF;  
        Stp_Logtsialt('TGFPAR', P_CHAVEPK,'COMPLEMENTO', :NEW.COMPLEMENTO);
    END IF;

    IF ((NVL(:OLD.CODEND,0)) <> (NVL(:NEW.CODEND,0))) THEN
        BEGIN
          SELECT COUNT(1) INTO P_COUNT
          FROM TSIALT          
          WHERE NOMETAB = 'TGFPAR'
            AND CONTEUDO = TO_CHAR(:OLD.CODEND)
            AND CHAVE = P_CHAVEPK;
        EXCEPTION WHEN NO_DATA_FOUND THEN
          P_COUNT := 0;
        END;
        IF P_COUNT = 0 THEN
           Stp_Logtsialt('TGFPAR', P_CHAVEPK,'CODEND', TO_CHAR(:OLD.CODEND), (SYSDATE -1));
        END IF;    
        Stp_Logtsialt('TGFPAR', P_CHAVEPK,'CODEND', TO_CHAR(:NEW.CODEND));
    END IF;  

    IF ((NVL(:OLD.CODBAI,0)) <> (NVL(:NEW.CODBAI,0))) THEN
        BEGIN
          SELECT COUNT(1) INTO P_COUNT
          FROM TSIALT          
          WHERE NOMETAB = 'TGFPAR'
            AND CONTEUDO = TO_CHAR(:OLD.CODBAI)
            AND CHAVE = P_CHAVEPK;
        EXCEPTION WHEN NO_DATA_FOUND THEN
          P_COUNT := 0;
        END;
        IF P_COUNT = 0 THEN
           Stp_Logtsialt('TGFPAR', P_CHAVEPK,'CODBAI', TO_CHAR(:OLD.CODBAI), (SYSDATE -1));
        END IF; 
        Stp_Logtsialt('TGFPAR', P_CHAVEPK,'CODBAI', TO_CHAR(:NEW.CODBAI));
    END IF;

    IF ((NVL(:OLD.CODCID,0)) <> (NVL(:NEW.CODCID,0))) THEN
        BEGIN
          SELECT COUNT(1) INTO P_COUNT
          FROM TSIALT          
          WHERE NOMETAB = 'TGFPAR'
            AND CONTEUDO = TO_CHAR(:OLD.CODCID)
            AND CHAVE = P_CHAVEPK;
        EXCEPTION WHEN NO_DATA_FOUND THEN
          P_COUNT := 0;
        END;
        IF P_COUNT = 0 THEN
           Stp_Logtsialt('TGFPAR', P_CHAVEPK,'CODCID', TO_CHAR(:OLD.CODCID), (SYSDATE -1));
        END IF;  
        Stp_Logtsialt('TGFPAR', P_CHAVEPK,'CODCID', TO_CHAR(:NEW.CODCID));
    END IF;
  END IF;       
END;
/
