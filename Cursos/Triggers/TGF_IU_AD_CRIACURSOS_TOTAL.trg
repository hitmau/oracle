DROP TRIGGER TOTALPRD.TGF_IU_AD_CRIACURSOS_TOTAL;

CREATE OR REPLACE TRIGGER TOTALPRD.TGF_IU_AD_CRIACURSOS_TOTAL
BEFORE INSERT OR UPDATE ON TOTALPRD.AD_CRIACURSOS
FOR EACH ROW
DECLARE
    PNUREL INT;
    EMPPARC INT;
    PCODUSU INT;
    PCODCONTATOEMP INT;
    PCODCONTATO INT;
    PNOMECUR VARCHAR(1000);
    PNOMEPAL VARCHAR(1000);
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

SELECT  STP_GET_CODUSULOGADO()
    INTO PCODUSU
    FROM DUAL;

EXECUTE IMMEDIATE 'ALTER TRIGGER TRG_INC_TGFTEL_M_TOTAL DISABLE';
EXECUTE IMMEDIATE 'ALTER TRIGGER TRG_INC_AD_AGENDAPAP_M_TOTAL DISABLE';

--Obtem a descrição do curso o nome do palestrante e o código do usuário palestrante
--caso o usuário não tenha o parceiro vinculado a ele no cadastro de usuário será
--exibido um erro.
        SELECT DESCRCURSO, NOME, (SELECT MAX(USU.CODUSU) FROM TSIUSU USU WHERE USU.CODPARC = PAL.CODPARC) 
        INTO PNOMECUR, PNOMEPAL, PCODCONTATO
        FROM AD_CURSOS CUR LEFT JOIN AD_CADPALESTCURSO PAL ON (CUR.ID = PAL.ID)
        WHERE PAL.ID = :NEW.ID 
          AND PAL.CODPALEST = :NEW.IDPALEST;

--Obtem o PK da tabela de agenda
        SELECT MAX(NUREL) + 1
        INTO PNUREL
        FROM TGFTEL;

--Obtem o parceiro da empresa e o contato cadastrado nesse parceiro.   
        SELECT MAX(EMP.CODPARC), NVL(MAX(CTT.CODCONTATO), 0)
        INTO EMPPARC, PCODCONTATOEMP
        FROM TSIEMP EMP LEFT JOIN TGFCTT CTT ON (EMP.CODPARC = CTT.CODPARC)
        WHERE EMP.CODEMP = :NEW.CODEMP;

--Verifica se a agenda já foi criada e se o curso está ativo.
IF (:NEW.NUREL IS NOT NULL) AND (NVL(:NEW.ATIVO,'N') = 'S') THEN

        --Se já existir uma agenda, qualquer alteração será atualizada na agenda.
        UPDATE TGFTEL TEL SET 
        TEL.CODPARC = EMPPARC, 
        COMENTARIOS = CASE WHEN NVL(:NEW.NAOREALIZADO, 'N') = 'S' THEN 'Curso cancelado. ' || NVL(:NEW.MOTIVO, 'Motivo não informado') ELSE NVL(:NEW.MOTIVO, 'Curso de ' || PNOMECUR || ' marcado automaticamente!') END ,
        DHPROXCHAM = :NEW.DTHRINICIO,
        TEMPPREVISTO = TO_DATE(TRUNC(:NEW.DTHRINICIO) ||' ' || TO_CHAR(TO_DATE(SUBSTR(:NEW.HRFIM,0,2) ||':'|| SUBSTR(:NEW.HRFIM,3) || ':00', 'HH24:MI:SS'), 'HH24:MI:SS'), 'DD/MM/YY HH24:MI:SS'),
        CODUSU = PCODCONTATO,
        SITUACAO = 'P',
        CODATENDENTE = PCODCONTATO,
        DTALTER = SYSDATE,
        CODCONTATO = PCODCONTATOEMP
        WHERE NUREL = :NEW.NUREL; 

    END IF;

    --Caso não exista numero unico da atenda e o curso estiver ativo.    
    IF (:NEW.NUREL IS NULL) AND (NVL(:NEW.ATIVO,'N') = 'S') THEN
        --Se a empresa (local do curso) não tiver contato.
        IF PCODCONTATOEMP = 0 THEN
RAISE_APPLICATION_ERROR(-20101, 
'<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
Não existe contato cadastrado no parceiro: ' || to_char(EMPPARC) ||'.</font></b><br><font>');
        END IF;
        --insere a agenda.
        INSERT INTO TGFTEL (NUREL, CODPARC, DHCHAMADA, COMENTARIOS, DHPROXCHAM, TEMPPREVISTO, CODUSU, SITUACAO, CODATENDENTE, DTALTER, CODCONTATO) VALUES
        ((SELECT MAX(NUREL)+1 FROM TGFTEL), EMPPARC, SYSDATE, NVL(:NEW.MOTIVO,'Curso de ' || PNOMECUR || ' marcado automaticamente!'), :NEW.DTHRINICIO, TO_DATE(TRUNC(:NEW.DTHRINICIO) ||' ' || TO_CHAR(TO_DATE(SUBSTR(:NEW.HRFIM,0,2) ||':'|| SUBSTR(:NEW.HRFIM,3) || ':00', 'HH24:MI:SS'), 'HH24:MI:SS'), 'DD/MM/YY HH24:MI:SS'), PCODCONTATO, 'P', PCODCONTATO, SYSDATE, PCODCONTATOEMP);
        
        --Atualiza o campo nurel com o número da agenda
        :new.nurel := pnurel;

    END IF;

EXECUTE IMMEDIATE 'ALTER TRIGGER TOTALPRD.TRG_INC_TGFTEL_M_TOTAL ENABLE';
EXECUTE IMMEDIATE 'ALTER TRIGGER TOTALPRD.TRG_INC_AD_AGENDAPAP_M_TOTAL ENABLE';
END;
/
