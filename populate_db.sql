-- PROCEDURE: "Acervo".populate_db()

-- DROP PROCEDURE "Acervo".populate_db();

CREATE OR REPLACE PROCEDURE "Acervo".populate_db(
	)
LANGUAGE 'plpgsql'

AS $BODY$DECLARE
	v_obra RECORD;
	v_material_id integer;
	v_editora_id integer;
	v_autores_ids integer[];
	v_autor_id integer;
	v_autor text;
	v_obra_id integer;
	
BEGIN

	BEGIN
		FOR v_obra IN
			SELECT titulo
				, sub_titulo
				, assunto
				, autor
				, tipo_material
				, quantidade
				, ano
				, edicao
				, editora
				, isbn
				, issn
				, registro_sistema
				FROM "Acervo"."acervo-temp"
		LOOP
			-- Inserir material
			WITH t_material AS (
				INSERT INTO "Acervo".material(descricao)
				VALUES (v_obra.tipo_material)
				ON CONFLICT ON CONSTRAINT ukc_material_descricao DO NOTHING
				RETURNING material_id
			)
			SELECT material_id INTO v_material_id
			FROM t_material;
			
			IF v_material_id IS NULL THEN
				SELECT material_id INTO v_material_id
				FROM "Acervo"."material"
				WHERE v_obra.tipo_material = material.descricao;
			END IF;
			
			-- Inserir editora
			WITH t_editora AS (
				INSERT INTO "Acervo".editora(nome)
				VALUES (v_obra.editora)
				ON CONFLICT ON CONSTRAINT ukc_editora_nome DO NOTHING
				RETURNING editora_id
			)
			SELECT editora_id INTO v_editora_id
			FROM t_editora;
			
			IF v_editora_id IS NULL THEN
				SELECT editora_id INTO v_editora_id
				FROM "Acervo"."editora"
				WHERE v_obra.editora = editora.nome;
			END IF;
			
			-- Inserir autores		
			FOREACH v_autor IN ARRAY string_to_array(v_obra.autor, ';')::text[] LOOP
				WITH t_autor AS (
					INSERT INTO "Acervo".autor(nome)
					VALUES (v_autor)
					ON CONFLICT ON CONSTRAINT ukc_autor_nome_sobrenome DO NOTHING
					RETURNING autor_id
				)
				SELECT autor_id INTO v_autor_id
				FROM t_autor;
				
				IF v_autor_id IS NULL THEN
					SELECT autor_id INTO v_autor_id
					FROM "Acervo"."autor"
					WHERE v_autor = autor.nome;
				END IF;
				
				SELECT v_autor_id::integer || v_autores_ids::integer[] INTO v_autores_ids;
				
			END LOOP;
			
			--v_obra.ano := translate(v_obra.ano, 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLHMNOPQRSTUVWXYZáéíóúàèìòùãẽĩõâêîôûç,.:|$[]-\?!@#%&*', '');
			
			IF v_obra.ano = '' THEN
				v_obra.ano := NULL;
			END IF;
			
			-- Inserir obra
			WITH t_obra AS (
				INSERT INTO "Acervo".obra(
					registro_sistema
					, titulo
					, sub_titulo
					, assunto
					, material_id
					, quantidade
					, ano
					, edicao
					, editora_id
					, isbn
					, issn)
				VALUES (
					v_obra.registro_sistema::integer
					, v_obra.titulo
					, v_obra.sub_titulo
					, v_obra.assunto
					, v_material_id
					, v_obra.quantidade::integer
					, v_obra.ano
					, v_obra.edicao
					, v_editora_id
					, v_obra.isbn, v_obra.issn)
				RETURNING obra_id
			)
			SELECT obra_id INTO v_obra_id
			FROM t_obra;
			
			-- Inserir autor_obra
			FOREACH v_autor_id IN ARRAY v_autores_ids LOOP
				INSERT INTO "Acervo".autor_obra(
					autor_id, obra_id)
				VALUES (v_autor_id, v_obra_id);
			END LOOP;
			
			RAISE NOTICE '%', v_obra;
			
		END LOOP;
	END;

END;
$BODY$;


-- call "Acervo".populate_db();
