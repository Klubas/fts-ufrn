COPY "Acervo"."acervo-temp" (registro_sistema, titulo, sub_titulo, assunto, autor, tipo_material, quantidade, ano, edicao, editora, isbn, issn) 
FROM ../postgres_data_path/exemplares_acervo.csv
DELIMITER ';' 
CSV HEADER QUOTE '"' 
