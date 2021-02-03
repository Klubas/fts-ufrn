DO  $$
DECLARE
    success boolean;
BEGIN
    RAISE NOTICE 'Aguarde a inicialização do banco de dados...';
    
    SELECT "Acervo"."import_csv"('exemplares-acervo.csv')
    INTO success;

    IF  success THEN
        RAISE NOTICE 'Aguarde a atualização do banco de dados...';
        CALL "Acervo"."populate_db"();
        RAISE NOTICE 'POPULATE_DB: OK';
    ELSE    
        RAISE EXCEPTION 'Erro ao importar CSV.';
    END IF;
END $$;