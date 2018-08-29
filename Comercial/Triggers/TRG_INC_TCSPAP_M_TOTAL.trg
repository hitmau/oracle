DROP TRIGGER TOTALPRD.TRG_INC_TCSPAP_M_TOTAL;

CREATE OR REPLACE TRIGGER TOTALPRD.TRG_INC_TCSPAP_M_TOTAL
BEFORE INSERT OR UPDATE ON TOTALPRD.TCSPAP FOR EACH ROW
DECLARE
PCODUSU INT;
PCONT INT;
PCONTINSERT INT;
PCODVEND INT;
PCODGRUPO INT;
PGOOGLE VARCHAR(1000);

VSEQUENCIA INT;
PNUREL INT;
PCONTATO INT;
PCONTCTT INT;
PRAGMA AUTONOMOUS_TRANSACTION;
PDHPROXCHAM DATE;
BEGIN

/*
    AUTOR: Mauricio Rodrigues
    Data da criação: 24/10/2017 
    DESCRIÇÃO:1. Só permite a alteração do prospect o gerente (usuário > Permite alterar o cadastro do Prospect)
              2. Caso o campo vendedor estiver em branco ou vazio qualquer 1 pode alterar.
              3. Somente o(a) vendedor(a) que estiver no campo vendedor pode alterar o prospect, exeto o gerente.

*/

SELECT STP_GET_CODUSULOGADO()
INTO PCODUSU
FROM DUAL;

--PODE ALTERAR PROSPEC
SELECT COUNT(1)
INTO PCONT
FROM TSIUSU
WHERE CODUSU = PCODUSU AND NVL(AD_ALTPROSPECT,'N') = 'S';
--PODE INSERIR PROSPECT
SELECT COUNT(1)
INTO PCONTINSERT
FROM TSIUSU
WHERE CODUSU = PCODUSU AND NVL(AD_INSERTPAP,'N') = 'S';

SELECT CODVEND, CODGRUPO
INTO PCODVEND, PCODGRUPO
FROM TSIUSU
WHERE CODUSU = PCODUSU;

SELECT COUNT(*)
INTO PCONTCTT
FROM TCSCTT CTT
WHERE CTT.CODPAP = :NEW.CODPAP; 

:NEW.AD_SQL := NVL(:NEW.AD_SQL, 'N');

  IF (INSERTING) THEN
  --BLOQUEIA INCERÇÃO DE DADOS PELO SANKHYA PARA PESSOAS QUE NÃO FAZEM PARTE DOS GRUPOS: 1 SUP MASTER, 0 SUP E 12 GERENTE AUTOMAÇÃO.
  :NEW.AD_CODUSUCRIADOR := PCODUSU;
    IF PCONTINSERT = 0 THEN
        IF :NEW.AD_PLACEIDGOOGLE IS NULL THEN
RAISE_APPLICATION_ERROR(-20002, '<font size="0" color="#FFFFFF"><br><br><br>
<b><font size="12" color="#FF0000">A incerção de dados pelo Sankhya não é permitida. <br><i>Acesse: totalcontrol.com.br/mapa</i> <br> ou informe ao supervisor.</font></b><br><font>');
        END IF;
    END IF;
    
    --INSERE NOME DO PROSPECT EM MAIUSCULO.
    :NEW.NOMEPAP := UPPER(:NEW.NOMEPAP);
    --INSERE NA TABELA AD_LOGPROSPECT
        INSERT INTO AD_LOGPROSPECT (
            ID
            , PROSPECT
            , DTALTER
            , USUCRIADOR
            , USUARIO
            , SMARTLEADCOMPLETO
            , FLUXOLEAD
            , ATIVIDADESFLUXO
            , RESPOSTAAOFLUXO
            , RESPOSTANEGATIVA
            , DTINICIOFLX
            , PARCEIRO
            , SQL
            , MQL
            , SMARTLEADCOM_DTHR
            , FLUXOLEAD_DTHR
            , ATIVIDADESFLUXO_DTHR
            , MQL_DTHR
            , SQL_DTHR
         ) VALUES ( 
            (SELECT MAX(ID)+1 FROM AD_LOGPROSPECT)
            , :NEW.CODPAP
            , TO_DATE(SYSDATE, 'DD/MM/YYYY')
            , PCODUSU
            , PCODUSU
            , :NEW.AD_PAPVALIDO
            , :NEW.AD_FLUXOLEAD
            , :NEW.AD_ATIVIDADESFLUXO
            , :NEW.AD_RESPOSTAAOFLUXO
            , :NEW.AD_RESPOSTANEGATIVA
            , :NEW.AD_DTINIFLUXO
            , :NEW.CODPARC
            , NVL(:NEW.AD_SQL, 'N')
            , :NEW.AD_MQL
            , TO_DATE(SYSDATE, 'DD/MM/YYYY')
            , TO_DATE(SYSDATE, 'DD/MM/YYYY')
            , TO_DATE(SYSDATE, 'DD/MM/YYYY')
            , TO_DATE(SYSDATE, 'DD/MM/YYYY')
            , TO_DATE(SYSDATE, 'DD/MM/YYYY')
            ); COMMIT;
            
 END IF;
 
 :NEW.AD_SQL := NVL(:NEW.AD_SQL, 'N');

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--Atualização:
--Mauricio Rodrigues
--01/03/2018
--Descrição: Ao marcar as opções Nutrição MKT Pontencial e Dt./Hr. Próx. Nutrição é inserido uma linha na tabela de agenda.
     IF :OLD.AD_DTHRPROSNUTRICAO <> :NEW.AD_DTHRPROSNUTRICAO THEN
        IF NVL(:OLD.AD_NUTRIMKTP, 'N') = 'S' AND :NEW.AD_DTHRPROSNUTRICAO IS NOT NULL THEN
    PDHPROXCHAM := :NEW.AD_DTHRPROSNUTRICAO;
EXECUTE IMMEDIATE 'ALTER TRIGGER TRG_INC_TGFTEL_M_TOTAL DISABLE';
EXECUTE IMMEDIATE 'ALTER TRIGGER TRG_INC_AD_AGENDAPAP_M_TOTAL DISABLE';



    SELECT COUNT(*)
    INTO VSEQUENCIA
    FROM AD_AGENDAPAP PAP
    WHERE PAP.CODPAP = :NEW.CODPAP;
 
    SELECT MAX(NUREL) +1 INTO PNUREL FROM TGFTEL;
    
    SELECT COUNT(*)
    INTO PCONTATO
    FROM TCSCTT CTT
    WHERE CTT.CODPAP = :NEW.CODPAP;
    
            IF :NEW.AD_DTHRPROSNUTRICAO < SYSDATE THEN
RAISE_APPLICATION_ERROR(-20101, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
A data de nutrição para este prospect não pode ser menor que a data atual! (' || to_char(:NEW.AD_DTHRPROSNUTRICAO) || ')</font></b><br><font>');    
            END IF;
            IF PCONTATO <= 0 THEN
RAISE_APPLICATION_ERROR(-20101, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
Para gravar uma data no campo "Dt./Hr. Próx. Nutrição" é necessário ter um contato no Prospect!</font></b><br><font>');    
            END IF;
            
            IF SYSDATE < :NEW.AD_DTHRPROSNUTRICAO THEN
                DELETE FROM TGFTEL TEL WHERE :NEW.CODPAP = TEL.AD_CODPAP AND SYSDATE < DHPROXCHAM AND TEL.CODUSU = PCODUSU AND TEL.PENDENTE = 'S';
                DELETE FROM AD_AGENDAPAP AD WHERE :NEW.CODPAP = AD.CODPAP AND SYSDATE < AD.DATAHORAAGENDAMENTO AND AD.AD_FALLOWUP IS NOT NULL AND AD.SITUACAO = 'S';
            END IF;
            
            IF VSEQUENCIA <> 0 THEN
                Insert into TGFTEL (NUREL, CODPARC, DHCHAMADA, COMENTARIOS, DHPROXCHAM, PENDENTE, CODUSU, SITUACAO, CODATENDENTE, DTALTER, AD_CODPAP, AD_CODCONTATO, AD_FALLOWUP) Values
                (PNUREL, 1, SYSDATE, 'Agenda gerada automaticamente, entrar en contato com o cliente para retornar uma nutrição.', :NEW.AD_DTHRPROSNUTRICAO, 'S', PCODUSU, 'P', PCODUSU, SYSDATE, :NEW.CODPAP, 1, 'P');
                commit;
                
                Insert into AD_AGENDAPAP (CODNUREL, CODPAP, SEQ, ATENDENTE, CODCONTATO, DATAHORACADASTRO, DATAHORAAGENDAMENTO, SITUACAO, COMENTARIO, CODUSUEXEC, AD_FALLOWUP)
                VALUES (PNUREL, :NEW.CODPAP, (SELECT MAX(AD.SEQ)+1 FROM AD_AGENDAPAP AD WHERE AD.CODPAP = :NEW.CODPAP), PCODUSU, 1, SYSDATE, :NEW.AD_DTHRPROSNUTRICAO, 'S', 'Agenda gerada automaticamente, entrar en contato com o cliente para retornar uma nutrição.', PCODUSU, 'P');
                COMMIT;
            ELSE
                Insert into TGFTEL (NUREL, CODPARC, DHCHAMADA, COMENTARIOS, DHPROXCHAM, PENDENTE, CODUSU, SITUACAO, CODATENDENTE, DTALTER, AD_CODPAP, AD_CODCONTATO, AD_FALLOWUP) Values
                (PNUREL, 1, SYSDATE, 'Agenda gerada automaticamente, entrar em contato com o cliente para retornar uma nutrição.', :NEW.AD_DTHRPROSNUTRICAO, 'S', PCODUSU, 'P', PCODUSU, SYSDATE, :NEW.CODPAP, 1, 'P');
                commit;
            
                Insert into AD_AGENDAPAP (CODNUREL, CODPAP, SEQ, ATENDENTE, CODCONTATO, DATAHORACADASTRO, DATAHORAAGENDAMENTO, SITUACAO, COMENTARIO, CODUSUEXEC, AD_FALLOWUP)
                VALUES (PNUREL, :NEW.CODPAP, 1, PCODUSU, 1, SYSDATE, :NEW.AD_DTHRPROSNUTRICAO, 'S', 'Agenda gerada automaticamente, entrar en contato com o cliente para retornar uma nutrição.', PCODUSU, 'P');
                COMMIT;
            END IF;
EXECUTE IMMEDIATE 'ALTER TRIGGER TRG_INC_TGFTEL_M_TOTAL ENABLE';
EXECUTE IMMEDIATE 'ALTER TRIGGER TRG_INC_AD_AGENDAPAP_M_TOTAL ENABLE';
    END IF;
  END IF;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 
 IF (UPDATING) AND (NVL(:OLD.AD_SQL, 'N') <> NVL(:NEW.AD_SQL, 'N')) THEN
  INSERT INTO AD_LOGPROSPECT (
        ID
        , PROSPECT
        , DTALTER
        , USUCRIADOR
        , USUARIO
        , SMARTLEADCOMPLETO
        , FLUXOLEAD
        , ATIVIDADESFLUXO
        , RESPOSTAAOFLUXO
        , RESPOSTANEGATIVA
        , DTINICIOFLX
        , PARCEIRO
        , SQL
        , MQL
        , SQL_DTHR
     ) VALUES ( 
        (SELECT MAX(ID)+1 FROM AD_LOGPROSPECT)
        , :NEW.CODPAP
        , TO_DATE(SYSDATE, 'DD/MM/YY')
        , PCODUSU
        , PCODUSU
        , :NEW.AD_PAPVALIDO
        , :NEW.AD_FLUXOLEAD
        , :NEW.AD_ATIVIDADESFLUXO
        , :NEW.AD_RESPOSTAAOFLUXO
        , :NEW.AD_RESPOSTANEGATIVA
        , :NEW.AD_DTINIFLUXO
        , :NEW.CODPARC
        , NVL(:NEW.AD_SQL, 'N')
        , :NEW.AD_MQL
        , TO_DATE(SYSDATE, 'DD/MM/YY')
        ); COMMIT;
 END IF;
 --------------------------MQL
 IF (UPDATING) AND (NVL(:OLD.AD_MQL,'N') <> NVL(:NEW.AD_MQL,'N'))
     THEN
  INSERT INTO AD_LOGPROSPECT (
        ID
        , PROSPECT
        , DTALTER
        , USUCRIADOR
        , USUARIO
        , SMARTLEADCOMPLETO
        , FLUXOLEAD
        , ATIVIDADESFLUXO
        , RESPOSTAAOFLUXO
        , RESPOSTANEGATIVA
        , DTINICIOFLX
        , PARCEIRO
        , SQL
        , MQL
        , MQL_DTHR
     ) VALUES ( 
        (SELECT MAX(ID)+1 FROM AD_LOGPROSPECT)
        , :NEW.CODPAP
        , TO_DATE(SYSDATE, 'DD/MM/YY')
        , PCODUSU
        , PCODUSU
        , :NEW.AD_PAPVALIDO
        , :NEW.AD_FLUXOLEAD
        , :NEW.AD_ATIVIDADESFLUXO
        , :NEW.AD_RESPOSTAAOFLUXO
        , :NEW.AD_RESPOSTANEGATIVA
        , :NEW.AD_DTINIFLUXO
        , :NEW.CODPARC
        , NVL(:NEW.AD_SQL, 'N')
        , :NEW.AD_MQL
        , TO_DATE(SYSDATE, 'DD/MM/YY')
        ); COMMIT;
 END IF;
 --------------------------PAPVALIDO-SMARTLEADCOMPLETO
  IF (UPDATING) AND (NVL(:OLD.AD_PAPVALIDO,'N') <> NVL(:NEW.AD_PAPVALIDO,'N'))
     THEN
--RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
--Vendedor(a) CÓD: '||TO_CHAR(:NEW.AD_PAPVALIDO)||' - '||TO_CHAR(:OLD.AD_PAPVALIDO)|| 'não tem um cargo de comissão ativo!<br> (Tela Vendedor/Comprador).</font></b><br><font>');
  INSERT INTO AD_LOGPROSPECT (
        ID
        , PROSPECT
        , DTALTER
        , USUCRIADOR
        , USUARIO
        , SMARTLEADCOMPLETO
        , FLUXOLEAD
        , ATIVIDADESFLUXO
        , RESPOSTAAOFLUXO
        , RESPOSTANEGATIVA
        , DTINICIOFLX
        , PARCEIRO
        , SQL
        , MQL
        , SMARTLEADCOM_DTHR
     ) VALUES ( 
        (SELECT MAX(ID)+1 FROM AD_LOGPROSPECT)
        , :NEW.CODPAP
        , TO_DATE(SYSDATE, 'DD/MM/YY')
        , PCODUSU
        , PCODUSU
        , :NEW.AD_PAPVALIDO
        , :NEW.AD_FLUXOLEAD
        , :NEW.AD_ATIVIDADESFLUXO
        , :NEW.AD_RESPOSTAAOFLUXO
        , :NEW.AD_RESPOSTANEGATIVA
        , :NEW.AD_DTINIFLUXO
        , :NEW.CODPARC
        , NVL(:NEW.AD_SQL, 'N')
        , :NEW.AD_MQL
        , TO_DATE(SYSDATE, 'DD/MM/YY')
        ); COMMIT;
 END IF;
 --------------------------FLUXO LEAD
 IF (UPDATING) AND (NVL(:OLD.AD_FLUXOLEAD,'N') <> NVL(:NEW.AD_FLUXOLEAD,'N'))
     THEN
  INSERT INTO AD_LOGPROSPECT (
        ID
        , PROSPECT
        , DTALTER
        , USUCRIADOR
        , USUARIO
        , SMARTLEADCOMPLETO
        , FLUXOLEAD
        , ATIVIDADESFLUXO
        , RESPOSTAAOFLUXO
        , RESPOSTANEGATIVA
        , DTINICIOFLX
        , PARCEIRO
        , SQL
        , MQL
        , FLUXOLEAD_DTHR
     ) VALUES ( 
        (SELECT MAX(ID)+1 FROM AD_LOGPROSPECT)
        , :NEW.CODPAP
        , TO_DATE(SYSDATE, 'DD/MM/YY')
        , PCODUSU
        , PCODUSU
        , :NEW.AD_PAPVALIDO
        , :NEW.AD_FLUXOLEAD
        , :NEW.AD_ATIVIDADESFLUXO
        , :NEW.AD_RESPOSTAAOFLUXO
        , :NEW.AD_RESPOSTANEGATIVA
        , :NEW.AD_DTINIFLUXO
        , :NEW.CODPARC
        , NVL(:NEW.AD_SQL, 'N')
        , :NEW.AD_MQL
        , TO_DATE(SYSDATE, 'DD/MM/YY')
        ); COMMIT;
 END IF;
 -------------------------ATIVIDADESFLUXO
 IF (UPDATING) AND (NVL(:OLD.AD_ATIVIDADESFLUXO,'N') <> NVL(:NEW.AD_ATIVIDADESFLUXO,'N'))
     THEN
  INSERT INTO AD_LOGPROSPECT (
        ID
        , PROSPECT
        , DTALTER
        , USUCRIADOR
        , USUARIO
        , SMARTLEADCOMPLETO
        , FLUXOLEAD
        , ATIVIDADESFLUXO
        , RESPOSTAAOFLUXO
        , RESPOSTANEGATIVA
        , DTINICIOFLX
        , PARCEIRO
        , SQL
        , MQL
        , ATIVIDADESFLUXO_DTHR
     ) VALUES ( 
        (SELECT MAX(ID)+1 FROM AD_LOGPROSPECT)
        , :NEW.CODPAP
        , TO_DATE(SYSDATE, 'DD/MM/YY')
        , PCODUSU
        , PCODUSU
        , :NEW.AD_PAPVALIDO
        , :NEW.AD_FLUXOLEAD
        , :NEW.AD_ATIVIDADESFLUXO
        , :NEW.AD_RESPOSTAAOFLUXO
        , :NEW.AD_RESPOSTANEGATIVA
        , :NEW.AD_DTINIFLUXO
        , :NEW.CODPARC
        , NVL(:NEW.AD_SQL, 'N')
        , :NEW.AD_MQL
        , TO_DATE(SYSDATE, 'DD/MM/YY')
        ); COMMIT;
 END IF;
 -------------------------FIM
 :NEW.AD_PAPVALIDO := :NEW.AD_PAPVALIDO;
 :NEW.AD_REGCHAMADA := :NEW.AD_REGCHAMADA;
--SUBERVISOR PODE ALTERAR O PROSPECT (USUÁRIO>GERAL>PODE ALTERAR PROSPECT)
    IF (UPDATING) AND PCONT = 0 THEN
        IF (UPDATING) and :NEW.CODVEND <> 0 OR :OLD.CODVEND <> 0 THEN
            IF (UPDATING) and :OLD.CODVEND <> 0 AND PCODVEND <> :OLD.CODVEND AND :OLD.AD_PAPVALIDO = :NEW.AD_PAPVALIDO AND nvl(:OLD.AD_REGCHAMADA, sysdate) = nvl(:NEW.AD_REGCHAMADA, sysdate) THEN
RAISE_APPLICATION_ERROR(-20001, '<font size="0" color="#FFFFFF"><br><br><br><b><font size="12" color="#FF0000">
Somente o vendedor(a) ou o Supervisor podem alterar o cadastro deste Prospect.</font></b><br><font>');
            END IF;
        END IF;
    END IF;
END;
/
