DROP TRIGGER TOTALPRD.TRG_DLT_TGFPAR;

CREATE OR REPLACE TRIGGER TOTALPRD.TRG_DLT_TGFPAR
   BEFORE DELETE
   ON TOTALPRD.TGFPAR
   FOR EACH ROW
DECLARE
   P_COUNT   NUMBER (5);
   
   PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
   -- OS 1026302 VERIFICANDO SE O CLIENTE UTILIZA ESTA FUNCIONALIDADE
   IF :OLD.PERMITECORTE <> 'N'
   THEN
      SELECT COUNT (*)
        INTO P_COUNT
        FROM TGFPAR
       WHERE PERMITECORTE <> 'N';

      IF P_COUNT = 0
      THEN
         UPDATE TSIVARBD
            SET UTILIZA_VERIFCORTE = 'N';
      END IF;
   END IF;

   -- OS 1026302

   IF STP_GET_ATUALIZANDO
   THEN
      RETURN;
   END IF;

   EXISTSRESTRICAO ('TGFPAR', :OLD.CODPARC);

   IF (:OLD.CODPARC = 0)
   THEN
      RAISE_APPLICATION_ERROR (-20101, ERROS_PKG.ERRO_REGISTRO_PADRAO);
   END IF;

   /*  SET NULL EM "CODPARC" DA "TGFPAR"  */
   SELECT COUNT (1)
     INTO P_COUNT
     FROM TGFVEN
    WHERE CODPARC = :OLD.CODPARC;

   IF P_COUNT > 0
   THEN
      UPDATE TGFVEN
         SET CODPARC = 0
       WHERE CODPARC = :OLD.CODPARC;
   END IF;


   -- PASSADO PARA CASCADE
   /*  DELETE ALL CHILDREN IN "TGFRAT"  */
   -- DELETE TGFCTT
   -- WHERE  CODPARC = :OLD.CODPARC;

   /*  Passado para cascade
     DELETE TGFCPL
     WHERE  CODPARC = :OLD.CODPARC; */

   -- PASSADO PARA CASCADE
   /*  DELETE ALL CHILDREN IN "TGFPPA"  */
   -- DELETE TGFPPA
   -- WHERE  CODPARC = :OLD.CODPARC;


   /*  DELETE ALL CHILDREN IN "TGFATA"  */
   SELECT COUNT (1)
     INTO P_COUNT
     FROM TSIATA
    WHERE TIPO = 'P' AND CODATA = :OLD.CODPARC;

   IF P_COUNT > 0
   THEN
      DELETE TSIATA
       WHERE TIPO = 'P' AND CODATA = :OLD.CODPARC;
   END IF;


   /*  DELETE ALL CHILDREN IN "TGFIMA"  */
   SELECT COUNT (1)
     INTO P_COUNT
     FROM TGFIMA
    WHERE TIPO = 'P' AND CODIGO = :OLD.CODPARC;

   IF P_COUNT > 0
   THEN
      DELETE TGFIMA
       WHERE TIPO = 'P' AND CODIGO = :OLD.CODPARC;
   END IF;


   /*  DELETE ALL CHILDREN IN "TCAALU"  */
   SELECT COUNT (1)
     INTO P_COUNT
     FROM TCAALU
    WHERE CODPARC = :OLD.CODPARC;

   IF P_COUNT > 0
   THEN
      DELETE FROM TCAALU
            WHERE CODPARC = :OLD.CODPARC;
   END IF;


   /*  DELETE ALL CHILDREN IN "TGFVIS"  */
   SELECT COUNT (1)
     INTO P_COUNT
     FROM TGFVIS
    WHERE CODPARC = :OLD.CODPARC;

   IF P_COUNT > 0
   THEN
      DELETE FROM TGFVIS
            WHERE CODPARC = :OLD.CODPARC;
   END IF;

   -- INTEGRIDADE REFERENCIAL COM TGFUNP
   DELETE FROM TGFUNP
         WHERE CODPARC = :OLD.CODPARC;

   COMMIT;
END;
/