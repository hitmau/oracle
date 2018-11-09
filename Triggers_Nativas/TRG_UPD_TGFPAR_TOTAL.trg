DROP TRIGGER TOTALPRD.TRG_UPD_TGFPAR_TOTAL;

CREATE OR REPLACE TRIGGER TOTALPRD.TRG_UPD_TGFPAR_TOTAL
   BEFORE INSERT OR UPDATE
   ON TOTALPRD.TGFPAR
   FOR EACH ROW
DECLARE
   P_COUNT     INT;
   PCOUNT INT;
   PCONT       INT;
   P_CODROTA   NUMBER;
   P_CODZONA   NUMBER;
   ERROR       EXCEPTION;
BEGIN
   IF UPDATING
   THEN
      BEGIN
         SELECT CODROTA
           INTO P_CODROTA
           FROM AD_BAIRRO
          WHERE CODBAI = :NEW.CODBAI AND CODCID = :NEW.CODCID;
      EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
            P_CODROTA := 0;
      END;

      SELECT COUNT (*)
        INTO P_COUNT
        FROM TGFRTP
       WHERE CODPARC = :NEW.CODPARC AND CODROTA = P_CODROTA;

      IF P_CODROTA > 0 AND P_COUNT = 0
      THEN
         INSERT INTO TGFRTP (CODROTA,
                             CODPARC,
                             CODUSU,
                             DTALTER)
              VALUES (P_CODROTA,
                      :NEW.CODPARC,
                      STP_GET_CODUSULOGADO,
                      SYSDATE);

         :NEW.CODROTA := P_CODROTA;
      END IF;
   END IF;


   -- adicionado por daniel

   -- para atualizar a zona do cliente


   IF UPDATING
   THEN
      BEGIN
         SELECT CODZONA
           INTO P_CODZONA
           FROM AD_ZONA
          WHERE CODBAI = :NEW.CODBAI AND CODCID = :NEW.CODCID;
      EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
            P_CODZONA := 0;
      END;


      IF P_CODROTA > 0
      THEN
         :NEW.AD_CODZONA := P_CODZONA;
      END IF;
   END IF;


   IF INSERTING
   THEN
      :NEW.LIMCRED := 0.01;
      :NEW.LIMCREDMENSAL := 0.01;
      IF :NEW.CLIENTE = 'N' AND :NEW.FORNECEDOR = 'S' THEN
        :NEW.GRUPOAUTOR := 'C';
      ELSE
        :NEW.GRUPOAUTOR := 'V';
      END IF;
      
      
      SELECT COUNT (1)
        INTO PCONT
        FROM TGFPAR
       WHERE CGC_CPF = :NEW.CGC_CPF;

      IF PCONT > 0
      THEN
         RAISE_APPLICATION_ERROR (
            -20001,
            '<br><br><b> <font size="11" color="#FF0000">
            O CGC/CPF já existe no cadastro.    
            </font></b><br>');
      END IF;
   END IF;

   -- adicionado por Samuel em 05/03/2018

   -- para validar se os dados do cadastro de clientes estão corretos ou são invalidos
  IF nvl(:NEW.AD_ORIGEMWEB,'N') <> 'S' THEN --Só verifica os dados de clientes que não sejam do e-Commerce  
        IF  :NEW.FAX IS NOT NULL
            AND (SUBSTR(:NEW.FAX,5,1) NOT IN ('9','7')
            OR SUBSTR(:NEW.FAX,6,8) = SUBSTR(:NEW.TELEFONE,5,8)
            OR :NEW.FAX LIKE '%98765%'
            OR :NEW.FAX LIKE '%12345%'
            OR :NEW.FAX LIKE '%11111%'
            OR :NEW.FAX LIKE '%22222%'
            OR :NEW.FAX LIKE '%33333%'
            OR :NEW.FAX LIKE '%44444%'
            OR :NEW.FAX LIKE '%55555%'
            OR :NEW.FAX LIKE '%66666%'
            OR :NEW.FAX LIKE '%77777%'
            OR :NEW.FAX LIKE '%88888%'
            OR :NEW.FAX LIKE '%99999%'
            ) THEN  
               
            RAISE_APPLICATION_ERROR (
                -20001,
                '<br><br><b> <font size="11" color="#FF0000">
                Celular inválido, por favor insira um número de celular válido.   
                </font></b><br>');
        END IF;
     


        IF :NEW.CLIENTE = 'S' AND :NEW.FAX IS NULL THEN
        RAISE_APPLICATION_ERROR (
                -20001,
                '<br><br><b> <font size="11" color="#FF0000">
                Para cadastro de clientes, o campo Celular/Fax é obrigatório.
                </font></b><br>');
        END IF;
 
    

        IF :NEW.CLIENTE = 'S' AND :NEW.email IS NULL THEN
        RAISE_APPLICATION_ERROR (
                -20001,
                '<br><br><b> <font size="11" color="#FF0000">
                Para cadastro de clientes, o campo email é obrigatório.
                </font></b><br>');
        
        END IF;

        
    
        IF :NEW.email IS NOT NULL AND 
            (:NEW.email LIKE 'email@email.com' OR 
             :NEW.email LIKE '%naopossui%') THEN
            RAISE_APPLICATION_ERROR (
                -20001,
                '<br><br><b> <font size="11" color="#FF0000">
                Email inválido, por favor insira um email válido.
                </font></b><br>');
    
        END IF;
    
    
        IF (SUBSTR(:NEW.TELEFONE,5,1) IN ('9','7') OR :NEW.FAX LIKE '%99999%' OR :NEW.FAX LIKE '%77777%') THEN
        
            RAISE_APPLICATION_ERROR (
                -20001,
                '<br><br><b> <font size="11" color="#FF0000">
                Telefone inválido, por favor insira um número de telefone válido.   
                </font></b><br>');
        END IF;
        

    
        IF (:NEW.CODCID = 0 OR :NEW.CODEND = 0 OR :NEW.CODBAI = 0)THEN
            RAISE_APPLICATION_ERROR (
            -20001,
                '<br><br><b> <font size="11" color="#FF0000">
                Enderço incorreto, por favor preencha os campos Endereço, Cidade e Bairro com valores válidos.   
                    </font></b><br>');
        END IF;

    END IF;
END;
/
