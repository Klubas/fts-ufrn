CREATE PROCEDURE "Acervo"."populate_db"("registro_inicial" integer, "registro_final" integer)
    LANGUAGE "plpgsql"
    AS $_$
DECLARE
	v_obra RECORD;
	v_material_id integer;
	v_editora_id integer;
	v_autores_ids integer[] := '{}';
	v_assuntos_ids integer[] := '{}';
	v_autor_id integer;
	v_assunto_id integer;
	v_autor text;
	v_assunto text;
	v_obra_id integer;
	v_registro_inicial integer := registro_inicial;
	v_registro_final integer:= registro_final;
	
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
				, registro_sistema::integer
				FROM "Acervo"."acervo-temp"
			WHERE registro_sistema::integer >= v_registro_inicial
			AND registro_sistema::integer <= v_registro_final
		LOOP
			IF (SELECT registro_sistema 
				FROM "Acervo"."obra" o 
				WHERE o.registro_sistema = v_obra.registro_sistema) IS NULL 
			THEN
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
					
					IF v_editora_id IS NULL THEN 
						SELECT editora_id INTO v_editora_id
						FROM "Acervo"."editora"
						WHERE editora.nome = '<<INDEFINIDO>>';
					END IF;
					
				END IF;

				-- v_obra.ano := translate(v_obra.ano, 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLHMNOPQRSTUVWXYZáéíóúàèìòùãẽĩõâêîôûç,.:|$[]-\?!@#%&*', '');
				v_obra.ano := translate(v_obra.ano, ',.:|$\?!@#%&*', '');

				IF v_obra.ano = '' THEN
					v_obra.ano := NULL;
				END IF;

				-- Inserir obra
				WITH t_obra AS (
					INSERT INTO "Acervo".obra(
						registro_sistema
						, titulo
						, sub_titulo
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
							
				IF v_obra.assunto IS NOT NULL THEN
					-- Inserir assunto		
					FOREACH v_assunto IN ARRAY string_to_array(v_obra.assunto, '#$&')::text[] LOOP
						WITH t_assunto AS (
							INSERT INTO "Acervo".assunto(descricao)
							VALUES (v_assunto)
							ON CONFLICT ON CONSTRAINT ukc_assunto_descricao DO NOTHING
							RETURNING assunto_id
						)
						SELECT assunto_id INTO v_assunto_id
						FROM t_assunto;

						IF v_assunto_id IS NULL THEN
							SELECT assunto_id INTO v_assunto_id
							FROM "Acervo"."assunto"
							WHERE v_assunto = assunto.descricao;
						END IF;

						SELECT v_assunto_id::integer || v_assuntos_ids::integer[] INTO v_assuntos_ids;

					END LOOP;

					-- Inserir assunto_obra
					FOREACH v_assunto_id IN ARRAY v_assuntos_ids LOOP
						INSERT INTO "Acervo".assunto_obra(
							assunto_id, obra_id)
						VALUES (v_assunto_id, v_obra_id)
						ON CONFLICT ON CONSTRAINT assunto_obra_pkey DO NOTHING;
					END LOOP;
				END IF;

				IF v_obra.autor IS NOT NULL THEN
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

					-- Inserir autor_obra
					FOREACH v_autor_id IN ARRAY v_autores_ids LOOP
						INSERT INTO "Acervo".autor_obra(
							autor_id, obra_id)
						VALUES (v_autor_id, v_obra_id);
					END LOOP;
				END IF;

				RAISE NOTICE '[OK] Obra "% - %" registrada com sucesso.', v_obra.registro_sistema, v_obra.titulo;
			
			ELSE
				RAISE NOTICE '[ATENÇÃO] Obra "% - %" já existe.', v_obra.registro_sistema, v_obra.titulo;
			END IF;
		END LOOP;
	END;

END;
$_$;