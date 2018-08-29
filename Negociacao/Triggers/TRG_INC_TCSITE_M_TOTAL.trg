DROP TRIGGER TOTALPRD.TRG_INC_TCSITE_M_TOTAL;

CREATE OR REPLACE TRIGGER TOTALPRD.TRG_INC_TCSITE_M_TOTAL
BEFORE INSERT OR UPDATE ON TOTALPRD.TCSITE
FOR EACH ROW
DECLARE
   PCODUSU          INT;
   PCODUSUNEG    INT;
   PCONT         INT;
   PCODVEND      INT;
   PNEGOCIACAO   INT;
   PFECHAMENTO   INT;
   PITEM         INT;
   PCODPAP       INT;
   PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
/*
    ATUALIZA��O: Mauricio Rodrigues
    Data da cria��o: 13/12/2017
    DESCRI��O: 
*/
--USU�RIO LOGADO
SELECT  STP_GET_CODUSULOGADO() 
    INTO PCODUSU  
    FROM DUAL;
--VERIFICA SE CAMPO EST� MARCADO
SELECT COUNT(1) 
    INTO PCONT 
    FROM TSIUSU 
    WHERE CODUSU = PCODUSU AND NVL(AD_ALTNEGOCIACAO,'N') = 'S';
--VENDEDOR ATRELADO AO USU�RIO    
SELECT CODVEND 
    INTO PCODVEND 
    FROM TSIUSU 
    WHERE CODUSU = PCODUSU;
--VERIFICA SE � NEGOCIA��O (PODE SER OS POIS � A MEMA TABELA).    
    SELECT COUNT(TIPO)
    INTO PNEGOCIACAO
    FROM TCSOSE
    WHERE NUMOS = :NEW.NUMOS AND TIPO = 'P'; --TIPO = P (NEGOCIA��O)

        
--SUBERVISOR PODE ALTERAR O PROSPECT (USU�RIO>GERAL>PODE ALTERAR PROSPECT)
--VERIFICA SE � NEGOCIA��O
    IF (INSERTING) THEN

        IF PNEGOCIACAO = 1 THEN
            --ATUALIZA CODUSU QUE ENVIOU A VISITA.
            :NEW.AD_CODUSUENVIO := :NEW.CODUSUALTER;
            --UPDATE TCSPAP PAP SET PAP.AD_REGCHAMADA = TO_DATE(:NEW.DHPREVISTA, 'DD/MM/YYYY'), PAP.AD_PAPVALIDO = 'S' WHERE PAP.CODPAP = (SELECT OSE.CODPAP FROM TCSOSE OSE WHERE OSE.NUMOS = :NEW.NUMOS); COMMIT;
        END IF;
    END IF;
    IF (UPDATING) THEN
    
    SELECT OSE.CODPAP
        INTO PCODPAP
        FROM TCSOSE OSE
        WHERE OSE.NUMOS = :NEW.NUMOS;
    
         UPDATE TCSPAP PAP SET 
            PAP.AD_ATIVIDADESFLUXO = 7, 
            PAP.AD_FLUXOLEAD = 4,
            PAP.AD_PAPVALIDO = 'S',
            PAP.AD_SQL = 'S',
            PAP.AD_MQL = 'S'
         WHERE PAP.CODPAP = PCODPAP; COMMIT;
    
        IF PNEGOCIACAO = 1 THEN 
            IF (UPDATING) AND PCONT = 0 THEN
               --UPDATE TCSPAP PAP SET PAP.AD_REGCHAMADA = TO_DATE(:NEW.DHPREVISTA, 'DD/MM/YYYY'), PAP.AD_PAPVALIDO = 'S'  WHERE PAP.CODPAP = (SELECT OSE.CODPAP FROM TCSOSE OSE WHERE OSE.NUMOS = :NEW.NUMOS); COMMIT;    
            --Quando por a hora final da etapa da negocia��o, n�o ser� poss�vel modificar, apenas o supervisor
                select COUNT(ite.HRFINAL), NUMITEM
                INTO PFECHAMENTO, PITEM
                from tcsite ite 
                where NUMITEM = :NEW.NUMITEM AND NUMOS = :NEW.NUMOS GROUP BY NUMITEM; --:NEW.NUMITEM AND NUMOS = :NEW.NUMOS;
                
                IF PFECHAMENTO <> 0 THEN
        RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
        Essa Etapa j� est� finalizada.</font></b><br><font>');
                END IF;
            --Ninguem poder� mudar a Data/Hora do agendamento a n�o ser o supervisor.    
                IF (:NEW.DHPREVISTA <> :OLD.DHPREVISTA) AND :NEW.NUMITEM = PITEM THEN
        RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
        Somente o Supervisor pode alterar a Data/Hora do Agendamento.</font></b><br><font>');            
                END IF;
            --Somente o executante dono de sua etapa pode alter�-la.    
                IF PCODUSU <> :OLD.CODUSU THEN
        RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
        Somente o Executante dessa etapa pode alter�-la.</font></b><br><font>');
                END IF;
            END IF;
            
            IF :NEW.CODOCOROS = 90 THEN
                :NEW.CODPROD := 8999;
            END IF;
            IF :NEW.CODOCOROS = 91 THEN
                :NEW.CODPROD := 9000;
            END IF;
            IF :NEW.CODOCOROS = 92 THEN
                :NEW.CODPROD := 9001;
            END IF;
            IF :NEW.CODOCOROS = 93 THEN
                :NEW.CODPROD := 9002;
            END IF;   
            IF :NEW.CODOCOROS = 94 THEN
                :NEW.CODPROD := 9003;
            END IF;
            IF :NEW.CODOCOROS = 95 THEN
                :NEW.CODPROD := 9004;
            END IF;
        END IF;
    END IF;
END;
/
