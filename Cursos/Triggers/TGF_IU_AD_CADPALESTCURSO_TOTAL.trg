DROP TRIGGER TOTALPRD.TGF_IU_AD_CADPALESTCURSO_TOTAL;

CREATE OR REPLACE TRIGGER TOTALPRD.TGF_IU_AD_CADPALESTCURSO_TOTAL
BEFORE INSERT OR UPDATE ON TOTALPRD.AD_CADPALESTCURSO
FOR EACH ROW
DECLARE
    PNOME VARCHAR(200);
    CONT INT;
    PARC1 INT;
    PARC2 INT;
    --PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN

/*
    Autor: Mauricio Rodrigues
    Data: 13/09/2018
    Descrição: 1. Esta trigger alimenta o campo Nome para que seja exibido o nome do contato na tabela de agendamento de curso.
               2. Verifica se o parceiro tem vínculo com o usuario pois precisamos do usuário para registrar na tela de compromissos.
               3. Verifica também se existe mais de um usuário com o mesmo parceiro.
*/

    --Obtem o nome do contato e guarda no campo Nome para que o mesmo seja
    --exibido no agendamento de curso
    SELECT CTT.NOMECONTATO 
    INTO PNOME
    FROM TGFCTT CTT 
    WHERE CTT.CODPARC = :NEW.CODPARC
      AND CTT.CODCONTATO = :NEW.CODCONTATO;
    
    :NEW.NOME := PNOME;
    
    --Verifica se o parceiro tem vínculo com algum usuário pois é obrigatório
    SELECT COUNT(*)
    INTO CONT
    FROM TSIUSU USU
    WHERE USU.CODPARC = :NEW.CODPARC;
    
    IF CONT = 0 THEN
RAISE_APPLICATION_ERROR(-20101, 
'<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
É obrigatório que o palestrante tenha o cadastro na tela de usuário e o seu "Parceiro" esteja cadastrado no campo "Parteiro".</font></b><br><font>'); 
    END IF;
    
    --verifica se existe mais de 1 usuário com o parceiro vinculado, seria apenas 1
    IF CONT > 1 THEN
    
        SELECT MAX(USU.CODUSU), MIN(CODUSU)
        INTO PARC1, PARC2
        FROM TSIUSU USU
        WHERE USU.CODPARC = :NEW.CODPARC;
        
        IF PARC1 <> PARC2 THEN
RAISE_APPLICATION_ERROR(-20101, 
'<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
O Parceiro do Pelestrante está<br>vinculado a mais de um usuário.<br>
Cód. usuário 1: ' || to_char(parc1) || ', Cód. usuário 2: '|| to_char(parc2) ||'.<br>
É preciso que esteja vinculado em apenas um usuário.</font></b><br><font>'); 
        END IF;
    END IF;
END;
/
