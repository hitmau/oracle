DROP TRIGGER TOTALPRD.TGF_AD_CURPARTICIPANTES_TOTAL;

CREATE OR REPLACE TRIGGER TOTALPRD.TGF_AD_CURPARTICIPANTES_TOTAL
BEFORE INSERT OR UPDATE ON TOTALPRD.AD_CURPARTICIPANTES
FOR EACH ROW
DECLARE
    PMAXALUNOS INT;
    PMAXALUNOSCAD INT;
    PDUPLICIDADE INT;
    PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN

/*
    Autor: Mauricio Rodrigues
    Data: 13/09/2018 09:21
    Descrição: No cadastro de alunos participantes para cursos, 
                bloqueio para que não seja possível cadastrar o 
                mesmo aluno mais de uma vez e
                não cadastrar mais alunos que o permitido.
*/

---------------------------------------------------Verifica duplicidade
     
        SELECT COUNT(*)
        INTO PDUPLICIDADE
        FROM AD_CURPARTICIPANTES A
        WHERE CODPARC2 = :NEW.CODPARC2
          AND CODCONTATO = :NEW.CODCONTATO
          AND IDCUR = :NEW.IDCUR
          AND IDPARCUR <> :NEW.IDPARCUR;

        IF PDUPLICIDADE <> 0 THEN
RAISE_APPLICATION_ERROR(-20101, 
'<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
Este ajuno já está cadastrado para este curso.</font></b><br><font>'); 
        END IF;
 
---------------------------------------------------Verifica quantidade máxima de alunos

    SELECT QTDALUNOS 
    INTO PMAXALUNOS
    FROM AD_CRIACURSOS CRI 
    WHERE CRI.IDCUR = :NEW.IDCUR;
    
    SELECT COUNT(*)
    INTO PMAXALUNOSCAD
    FROM AD_CURPARTICIPANTES
    WHERE IDCUR = :NEW.IDCUR;     

    IF PMAXALUNOSCAD >= PMAXALUNOS THEN
RAISE_APPLICATION_ERROR(-20101, 
'<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
Limite de alunos alcançado. <br>Máximo de '|| to_char(PMAXALUNOS) ||' alunos.</font></b><br><font>');
    END IF;

END;
/
