DROP TRIGGER TOTALPRD.TRG_INC_TGFPAR;

CREATE OR REPLACE TRIGGER TOTALPRD.TRG_INC_TGFPAR
   BEFORE INSERT
   ON TOTALPRD.TGFPAR
   REFERENCING OLD AS OLD NEW AS NEW
   FOR EACH ROW
DECLARE
   P_COUNT     INT := 0;
   ERROR       EXCEPTION;
   ERRMSG      VARCHAR2 (255);
   P_VALCTA    CHAR (1);
   P_VALIDAR   BOOLEAN;
   P_VALTAB    CHAR (1);
BEGIN
   IF STP_GET_ATUALIZANDO
   THEN
      RETURN;
   END IF;

   -- OS 1026302 VERIFICANDO SE O CLIENTE UTILIZA ESTA FUNCIONALIDADE
   IF :NEW.PERMITECORTE <> 'N'
   THEN
      SELECT COUNT (*)
        INTO P_COUNT
        FROM TSIVARBD
       WHERE UTILIZA_VERIFCORTE <> 'S';

      IF P_COUNT > 0
      THEN
         UPDATE TSIVARBD
            SET UTILIZA_VERIFCORTE = 'S';
      END IF;
   END IF;

   -- OS 1026302

   STP_VALIDA_ENQUADRAMENTO_IPI (:NEW.CSTIPIENT, :NEW.CODENQIPIENT);

   STP_VALIDA_ENQUADRAMENTO_IPI (:NEW.CSTIPISAI, :NEW.CODENQIPISAI);

   P_VALIDAR := Fpodevalidar ('TGFPAR');

   IF (NOT P_VALIDAR)
   THEN
      RETURN;
   END IF;

   BEGIN
      SELECT LOGICO
        INTO P_VALCTA
        FROM TSIPAR
       WHERE CHAVE = 'VALCTA';
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         P_VALCTA := 'N';
   END;

   IF :NEW.CODTAB IS NOT NULL
   THEN
      BEGIN
         SELECT ATIVO
           INTO P_VALTAB
           FROM TGFNTA
          WHERE CODTAB = :NEW.CODTAB;
      EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
            P_VALTAB := 'N';
      END;

      IF P_VALTAB = 'N'
      THEN
         ERRMSG := 'A tabela de preço não existe ou não está ativa.';
         RAISE ERROR;
      END IF;
   END IF;

   IF (:NEW.CODCID = 0)
   THEN
      ERRMSG := 'A cidade do parceiro não pode ser zero(0)';
      RAISE ERROR;
   END IF;

   IF (P_VALCTA = 'S')
   THEN
      IF (:NEW.CODCTACTB IS NOT NULL) AND (:NEW.CODCTACTB <> 0)
      THEN
         SELECT COUNT (1)
           INTO P_COUNT
           FROM TCBPLA
          WHERE     CODCTACTB = :NEW.CODCTACTB
                AND ATIVA = 'S'
                AND ANALITICA = 'S';

         IF (P_COUNT = 0)
         THEN
            Stp_Popula_Msg ('TCBPLA');
         END IF;
      END IF;

      IF (:NEW.CODCTACTB2 IS NOT NULL) AND (:NEW.CODCTACTB2 <> 0)
      THEN
         SELECT COUNT (1)
           INTO P_COUNT
           FROM TCBPLA
          WHERE     CODCTACTB = :NEW.CODCTACTB2
                AND ATIVA = 'S'
                AND ANALITICA = 'S';

         IF (P_COUNT = 0)
         THEN
            Stp_Popula_Msg ('TCBPLA');
         END IF;
      END IF;

      IF (:NEW.CODCTACTB3 IS NOT NULL) AND (:NEW.CODCTACTB3 <> 0)
      THEN
         SELECT COUNT (1)
           INTO P_COUNT
           FROM TCBPLA
          WHERE     CODCTACTB = :NEW.CODCTACTB3
                AND ATIVA = 'S'
                AND ANALITICA = 'S';

         IF (P_COUNT = 0)
         THEN
            Stp_Popula_Msg ('TCBPLA');
         END IF;
      END IF;

      IF (:NEW.CODCTACTB4 IS NOT NULL) AND (:NEW.CODCTACTB4 <> 0)
      THEN
         SELECT COUNT (1)
           INTO P_COUNT
           FROM TCBPLA
          WHERE     CODCTACTB = :NEW.CODCTACTB4
                AND ATIVA = 'S'
                AND ANALITICA = 'S';

         IF (P_COUNT = 0)
         THEN
            Stp_Popula_Msg ('TCBPLA');
         END IF;
      END IF;
   END IF;

   IF (:NEW.CODTIPPARC IS NOT NULL) AND (:NEW.CODTIPPARC <> 0)
   THEN
      SELECT COUNT (1)
        INTO P_COUNT
        FROM TGFTPP
       WHERE CODTIPPARC = :NEW.CODTIPPARC AND ATIVO = 'S' AND ANALITICO = 'S';

      IF (P_COUNT = 0)
      THEN
         Stp_Popula_Msg ('TGFTPP');
      END IF;
   END IF;

   IF (:NEW.CODVEND IS NOT NULL) AND (:NEW.CODVEND <> 0)
   THEN
      SELECT COUNT (1)
        INTO P_COUNT
        FROM TGFVEN
       WHERE CODVEND = :NEW.CODVEND AND ATIVO = 'S';

      IF (P_COUNT = 0)
      THEN
         Stp_Popula_Msg ('TGFVEN');
      END IF;
   END IF;

   IF (:NEW.CODREG IS NOT NULL)
   THEN
      SELECT COUNT (1)
        INTO P_COUNT
        FROM TSIREG
       WHERE CODREG = :NEW.CODREG AND ATIVA = 'S';

      IF (P_COUNT = 0)
      THEN
         Stp_Popula_Msg ('TSIREG');
      END IF;
   END IF;
EXCEPTION
   WHEN ERROR
   THEN
      RAISE_APPLICATION_ERROR (-20101, ERRMSG);
END;
/
