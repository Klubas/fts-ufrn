CREATE FUNCTION "Acervo"."normal_busca_acervo"("p_value" "text") RETURNS "json"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
	v_query text := concat('%', p_value, '%');
	v_result RECORD;
	v_results json[] := '{}';

BEGIN
	FOR v_result IN  
	 SELECT 
		concat(
			obra.titulo, ' ',
			obra.sub_titulo, ' ',
			assunto.descricao, ' ',
			editora.nome, ' ',
			autor.nome, ' ',
			obra.ano, ' '
		) normal_result
	   FROM "Acervo".obra obra
		 LEFT JOIN "Acervo".autor_obra autor_obra ON obra.obra_id = autor_obra.obra_id
		 LEFT JOIN "Acervo".autor autor ON autor.autor_id = autor_obra.autor_id
		 JOIN "Acervo".editora editora ON obra.editora_id = editora.editora_id
		 LEFT JOIN "Acervo".assunto_obra ON obra.obra_id = assunto_obra.obra_id
		 LEFT JOIN "Acervo".assunto ON assunto.assunto_id = assunto_obra.assunto_id
		 LEFT JOIN "Acervo".material ON material.material_id = obra.material_id
		 WHERE 
		 	obra.titulo like v_query
			OR concat('%', obra.sub_titulo, '%') like v_query
			OR concat('%', assunto.descricao, '%') like v_query
			OR concat('%', editora.nome, '%') like v_query
			OR concat('%', autor.nome, '%') like v_query
			OR concat('%', obra.ano, '%') like v_query
	LOOP
		v_results := v_results || to_json(v_result);
	END LOOP;
	RETURN to_json(v_results);
END;
$$;