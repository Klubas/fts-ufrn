--
-- PostgreSQL database dump
--

-- Dumped from database version 12.3
-- Dumped by pg_dump version 12.3

-- Started on 2020-08-03 20:27:23

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 6 (class 2615 OID 25434)
-- Name: Acervo; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA "Acervo";


--
-- TOC entry 299 (class 1255 OID 34053)
-- Name: busca_acervo("text", "text"); Type: FUNCTION; Schema: Acervo; Owner: -
--

CREATE FUNCTION "Acervo"."busca_acervo"("p_query" "text", "p_search_type" "text", OUT "p_result" "json") RETURNS "json"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  StartTime timestamptz;
  EndTime timestamptz;
  Delta double precision;
BEGIN
  	StartTime := clock_timestamp();
	
	p_search_type := upper(p_search_type);
	
	IF p_search_type = 'FTS' THEN
		SELECT "Acervo".fts_busca_acervo(p_query) INTO p_result;
	ELSIF p_search_type = 'NORMAL' THEN
		SELECT "Acervo".normal_busca_acervo(p_query) INTO p_result;
	ELSE
		RAISE EXCEPTION 'Tipo de busca (%) inválido.', p_search_type;
	END IF;
	
	EndTime := clock_timestamp();
	Delta := 1000 * ( extract(epoch from EndTime) - extract(epoch from StartTime) );
	
	RAISE NOTICE 'Duration in millisecs = %', Delta;
	
	p_result := to_json(
		to_jsonb(Delta::text)
		|| to_jsonb(json_array_length(p_result)) 
		|| to_jsonb(p_result)
	);
	RETURN;
END;
$$;


--
-- TOC entry 347 (class 1255 OID 25770)
-- Name: clear_db(); Type: PROCEDURE; Schema: Acervo; Owner: -
--

CREATE PROCEDURE "Acervo"."clear_db"()
    LANGUAGE "plpgsql"
    AS $$
begin
	delete from "Acervo".assunto_obra;
	delete from "Acervo".assunto;
	delete from "Acervo".autor;
	delete from "Acervo".autor_obra;
	delete from "Acervo".editora;
	delete from "Acervo".material;
	delete from "Acervo".obra;
end;
$$;


--
-- TOC entry 349 (class 1255 OID 25706)
-- Name: fts_busca_acervo("text"); Type: FUNCTION; Schema: Acervo; Owner: -
--

CREATE FUNCTION "Acervo"."fts_busca_acervo"("p_value" "text") RETURNS "json"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
	v_query text := p_value;
	v_result RECORD;
	v_results json[] := '{}';

BEGIN
	FOR v_result IN  
	 SELECT 
		concat(
			obra.titulo, ' ',
			obra.sub_titulo, ' ',
			assunto.assuntos, ' ',
			editora.nome, ' ',
			autor.autores, ' ',
			obra.ano, ' '
		) results
	   FROM "Acervo".obra obra
		 JOIN "Acervo".view_autor_obra autor 
		 	ON autor.obra_id = obra.obra_id
		 JOIN "Acervo".view_assunto_obra assunto 
		 	ON assunto.obra_id = obra.obra_id
		 LEFT JOIN "Acervo".editora editora 
			ON obra.editora_id = editora.editora_id
		 LEFT JOIN "Acervo".material 
		 	ON material.material_id = obra.material_id
		 WHERE (
			 obra.ts 
			 || autor.ts 
			 || editora.ts 
			 || material.ts 
			 || assunto.ts
		 ) @@ websearch_to_tsquery ('portuguese', v_query)
	LOOP
		v_results := v_results || to_json(v_result);
	END LOOP;
	
	RETURN to_json(v_results);
	
END;
$$;


--
-- TOC entry 304 (class 1255 OID 34051)
-- Name: import_csv("text"); Type: FUNCTION; Schema: Acervo; Owner: -
--

CREATE FUNCTION "Acervo"."import_csv"("p_file_path" "text") RETURNS boolean
    LANGUAGE "plpgsql"
    AS $_$
/*

SELECT "Acervo".import_csv(
	'F:\data\exemplares-acervo .csv'
)

COPY "Acervo"."acervo-temp" (registro_sistema, titulo, sub_titulo, assunto, autor, tipo_material, quantidade, ano, edicao, editora, isbn, issn) 
FROM 'F:\data\exemplares-acervo.csv'
DELIMITER ';' 
CSV HEADER QUOTE '"' 
*/
DECLARE
	sql_query text;
	data_dir text;

BEGIN 

	SELECT setting INTO data_dir
	FROM pg_settings 
	WHERE name = 'data_directory';

	RAISE NOTICE 'O arquivo deve estar na pasta %', data_dir;
	sql_query := $$
		COPY "Acervo"."acervo-temp" (registro_sistema, titulo, sub_titulo, assunto, autor, tipo_material, quantidade, ano, edicao, editora, isbn, issn) 
		FROM '$$ || p_file_path || $$'
		DELIMITER ';' 
		CSV HEADER QUOTE '"'
	$$;

	RAISE NOTICE '%', sql_query;

	EXECUTE sql_query;

	RETURN true;	
END;
$_$;


--
-- TOC entry 351 (class 1255 OID 25705)
-- Name: normal_busca_acervo("text"); Type: FUNCTION; Schema: Acervo; Owner: -
--

CREATE FUNCTION "Acervo"."normal_busca_acervo"("p_value" "text") RETURNS "json"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
	v_query text := concat('%', LOWER(p_value), '%');
	v_result RECORD;
	v_results json[] := '{}';

BEGIN
	FOR v_result IN  
	 SELECT 
		concat(
			obra.titulo, ' ',
			obra.sub_titulo, ' ',
			assunto.assuntos, ' ',
			editora.nome, ' ',
			autor.autores, ' ',
			obra.ano, ' '
		) results
	   FROM "Acervo".obra obra
		 JOIN "Acervo".view_autor_obra autor 
		 	ON autor.obra_id = obra.obra_id
		 JOIN "Acervo".view_assunto_obra assunto 
		 	ON assunto.obra_id = obra.obra_id
		 LEFT JOIN "Acervo".editora editora 
		 	ON obra.editora_id = editora.editora_id
		 LEFT JOIN "Acervo".material 
		 	ON material.material_id = obra.material_id
		 WHERE
		 	LOWER(concat('%', obra.titulo, '%'))			like v_query
			OR LOWER(concat('%', obra.sub_titulo, '%'))		like v_query
			OR LOWER(concat('%', assunto.assuntos, '%'))	like v_query
			OR LOWER(concat('%', editora.nome, '%'))		like v_query
			OR LOWER(concat('%', material.descricao, '%')) 	like v_query
			OR LOWER(concat('%', autor.autores, '%'))		like v_query
			OR LOWER(concat('%', obra.ano, '%'))			like v_query
	LOOP
		v_results := v_results || to_json(v_result);
	END LOOP;
	RETURN to_json(v_results);
END;
$$;


--
-- TOC entry 348 (class 1255 OID 34050)
-- Name: populate_db(); Type: PROCEDURE; Schema: Acervo; Owner: -
--

CREATE PROCEDURE "Acervo"."populate_db"()
    LANGUAGE "plpgsql"
    AS $$
BEGIN
	call "Acervo".populate_db(	0	,	999999999	);
END;
$$;


--
-- TOC entry 350 (class 1255 OID 33869)
-- Name: populate_db(integer, integer, boolean); Type: PROCEDURE; Schema: Acervo; Owner: -
--

CREATE PROCEDURE "Acervo"."populate_db"("registro_inicial" integer, "registro_final" integer, "quiet" boolean DEFAULT true)
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
			v_material_id	:= NULL;
			v_editora_id	:= NULL;
			v_autores_ids	:= '{}';
			v_assuntos_ids	:= '{}';
			v_autor_id		:= NULL;
			v_assunto_id	:= NULL;
			v_autor			:= NULL;
			v_assunto 		:= NULL;
			v_obra_id 		:= NULL;
			-- Inserir material
			WITH t_material AS (
				INSERT INTO "Acervo".material(descricao)
				VALUES (v_obra.tipo_material)
				ON CONFLICT ON CONSTRAINT ukc_material_descricao DO NOTHING
				RETURNING material_id
			) SELECT material_id INTO v_material_id
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
			) SELECT editora_id INTO v_editora_id
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
					, v_obra.isbn
					, v_obra.issn)
				ON CONFLICT ON CONSTRAINT obra_registro_sistema_key DO NOTHING
				RETURNING obra_id
			) SELECT obra_id INTO v_obra_id
			FROM t_obra;

			IF v_obra_id IS NOT NULL THEN
				IF v_obra.assunto IS NOT NULL THEN
					-- Inserir assunto		
					FOREACH v_assunto IN ARRAY string_to_array(v_obra.assunto, '#$&')::text[] LOOP
						WITH t_assunto AS (
							INSERT INTO "Acervo".assunto(descricao)
							VALUES (v_assunto)
							ON CONFLICT ON CONSTRAINT ukc_assunto_descricao DO NOTHING
							RETURNING assunto_id
						) SELECT assunto_id INTO v_assunto_id
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
						) SELECT autor_id INTO v_autor_id
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

				IF NOT quiet THEN
					RAISE NOTICE '[OK] Obra "% - %" registrada com sucesso.', v_obra.registro_sistema, v_obra.titulo;
				END IF;
			ELSE
				IF NOT quiet THEN
					RAISE NOTICE '[ATENÇÃO] Obra "% - %" já existe.', v_obra.registro_sistema, v_obra.titulo;
				END IF;
			END IF;
		END LOOP;
	END;
	RAISE NOTICE 'OK';
END;
$_$;


SET default_tablespace = '';

SET default_table_access_method = "heap";

--
-- TOC entry 280 (class 1259 OID 25543)
-- Name: acervo-temp; Type: TABLE; Schema: Acervo; Owner: -
--

CREATE TABLE "Acervo"."acervo-temp" (
    "registro_sistema" integer,
    "titulo" "text",
    "sub_titulo" "text",
    "assunto" "text",
    "autor" "text",
    "tipo_material" "text",
    "quantidade" "text",
    "ano" "text",
    "edicao" "text",
    "editora" "text",
    "isbn" "text",
    "issn" "text"
);


--
-- TOC entry 281 (class 1259 OID 25644)
-- Name: assunto_assunto_id_seq; Type: SEQUENCE; Schema: Acervo; Owner: -
--

CREATE SEQUENCE "Acervo"."assunto_assunto_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 282 (class 1259 OID 25646)
-- Name: assunto; Type: TABLE; Schema: Acervo; Owner: -
--

CREATE TABLE "Acervo"."assunto" (
    "assunto_id" bigint DEFAULT "nextval"('"Acervo"."assunto_assunto_id_seq"'::"regclass") NOT NULL,
    "descricao" "text" NOT NULL,
    "ts" "tsvector"
);


--
-- TOC entry 284 (class 1259 OID 33898)
-- Name: assunto_obra; Type: TABLE; Schema: Acervo; Owner: -
--

CREATE TABLE "Acervo"."assunto_obra" (
    "assunto_id" integer NOT NULL,
    "obra_id" integer NOT NULL
);


--
-- TOC entry 272 (class 1259 OID 25446)
-- Name: autor; Type: TABLE; Schema: Acervo; Owner: -
--

CREATE TABLE "Acervo"."autor" (
    "nome" "text" NOT NULL,
    "sobrenome" "text",
    "autor_id" bigint NOT NULL,
    "ts" "tsvector"
);


--
-- TOC entry 273 (class 1259 OID 25452)
-- Name: autor_autor_id_seq; Type: SEQUENCE; Schema: Acervo; Owner: -
--

CREATE SEQUENCE "Acervo"."autor_autor_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3192 (class 0 OID 0)
-- Dependencies: 273
-- Name: autor_autor_id_seq; Type: SEQUENCE OWNED BY; Schema: Acervo; Owner: -
--

ALTER SEQUENCE "Acervo"."autor_autor_id_seq" OWNED BY "Acervo"."autor"."autor_id";


--
-- TOC entry 283 (class 1259 OID 33893)
-- Name: autor_obra; Type: TABLE; Schema: Acervo; Owner: -
--

CREATE TABLE "Acervo"."autor_obra" (
    "autor_id" integer NOT NULL,
    "obra_id" integer NOT NULL
);


--
-- TOC entry 274 (class 1259 OID 25457)
-- Name: editora; Type: TABLE; Schema: Acervo; Owner: -
--

CREATE TABLE "Acervo"."editora" (
    "nome" "text" NOT NULL,
    "editora_id" bigint NOT NULL,
    "ts" "tsvector"
);


--
-- TOC entry 275 (class 1259 OID 25463)
-- Name: editora_editora_id_seq; Type: SEQUENCE; Schema: Acervo; Owner: -
--

CREATE SEQUENCE "Acervo"."editora_editora_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3193 (class 0 OID 0)
-- Dependencies: 275
-- Name: editora_editora_id_seq; Type: SEQUENCE OWNED BY; Schema: Acervo; Owner: -
--

ALTER SEQUENCE "Acervo"."editora_editora_id_seq" OWNED BY "Acervo"."editora"."editora_id";


--
-- TOC entry 276 (class 1259 OID 25465)
-- Name: material; Type: TABLE; Schema: Acervo; Owner: -
--

CREATE TABLE "Acervo"."material" (
    "descricao" "text" NOT NULL,
    "material_id" bigint NOT NULL,
    "ts" "tsvector"
);


--
-- TOC entry 277 (class 1259 OID 25471)
-- Name: material_material_id_seq; Type: SEQUENCE; Schema: Acervo; Owner: -
--

CREATE SEQUENCE "Acervo"."material_material_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3194 (class 0 OID 0)
-- Dependencies: 277
-- Name: material_material_id_seq; Type: SEQUENCE OWNED BY; Schema: Acervo; Owner: -
--

ALTER SEQUENCE "Acervo"."material_material_id_seq" OWNED BY "Acervo"."material"."material_id";


--
-- TOC entry 278 (class 1259 OID 25473)
-- Name: obra; Type: TABLE; Schema: Acervo; Owner: -
--

CREATE TABLE "Acervo"."obra" (
    "registro_sistema" integer,
    "titulo" "text" NOT NULL,
    "sub_titulo" "text",
    "material_id" integer NOT NULL,
    "quantidade" integer NOT NULL,
    "editora_id" integer NOT NULL,
    "isbn" "text",
    "issn" "text",
    "obra_id" bigint NOT NULL,
    "edicao" "text",
    "ano" "text",
    "ts" "tsvector"
);


--
-- TOC entry 279 (class 1259 OID 25479)
-- Name: obra_obra_id_seq; Type: SEQUENCE; Schema: Acervo; Owner: -
--

CREATE SEQUENCE "Acervo"."obra_obra_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 3195 (class 0 OID 0)
-- Dependencies: 279
-- Name: obra_obra_id_seq; Type: SEQUENCE OWNED BY; Schema: Acervo; Owner: -
--

ALTER SEQUENCE "Acervo"."obra_obra_id_seq" OWNED BY "Acervo"."obra"."obra_id";


--
-- TOC entry 286 (class 1259 OID 34041)
-- Name: view_assunto_obra; Type: VIEW; Schema: Acervo; Owner: -
--

CREATE VIEW "Acervo"."view_assunto_obra" AS
 SELECT "assunto_obra"."obra_id",
    "string_agg"("assunto"."descricao", '; '::"text") AS "assuntos",
    ("string_agg"(("assunto"."ts")::"text", ' '::"text"))::"tsvector" AS "ts"
   FROM ("Acervo"."assunto_obra" "assunto_obra"
     JOIN "Acervo"."assunto" "assunto" ON (("assunto"."assunto_id" = "assunto_obra"."assunto_id")))
  GROUP BY "assunto_obra"."obra_id";


--
-- TOC entry 285 (class 1259 OID 33908)
-- Name: view_autor_obra; Type: VIEW; Schema: Acervo; Owner: -
--

CREATE VIEW "Acervo"."view_autor_obra" AS
 SELECT "autor_obra"."obra_id",
    "string_agg"("autor"."nome", '; '::"text") AS "autores",
    ("string_agg"(("autor"."ts")::"text", ' '::"text"))::"tsvector" AS "ts"
   FROM ("Acervo"."autor_obra" "autor_obra"
     JOIN "Acervo"."autor" "autor" ON (("autor"."autor_id" = "autor_obra"."autor_id")))
  GROUP BY "autor_obra"."obra_id";


--
-- TOC entry 2979 (class 2604 OID 25481)
-- Name: autor autor_id; Type: DEFAULT; Schema: Acervo; Owner: -
--

ALTER TABLE ONLY "Acervo"."autor" ALTER COLUMN "autor_id" SET DEFAULT "nextval"('"Acervo"."autor_autor_id_seq"'::"regclass");


--
-- TOC entry 2980 (class 2604 OID 25482)
-- Name: editora editora_id; Type: DEFAULT; Schema: Acervo; Owner: -
--

ALTER TABLE ONLY "Acervo"."editora" ALTER COLUMN "editora_id" SET DEFAULT "nextval"('"Acervo"."editora_editora_id_seq"'::"regclass");


--
-- TOC entry 2981 (class 2604 OID 25483)
-- Name: material material_id; Type: DEFAULT; Schema: Acervo; Owner: -
--

ALTER TABLE ONLY "Acervo"."material" ALTER COLUMN "material_id" SET DEFAULT "nextval"('"Acervo"."material_material_id_seq"'::"regclass");


--
-- TOC entry 2982 (class 2604 OID 25484)
-- Name: obra obra_id; Type: DEFAULT; Schema: Acervo; Owner: -
--

ALTER TABLE ONLY "Acervo"."obra" ALTER COLUMN "obra_id" SET DEFAULT "nextval"('"Acervo"."obra_obra_id_seq"'::"regclass");


--
-- TOC entry 3023 (class 2606 OID 33902)
-- Name: assunto_obra assunto_obra_pkey; Type: CONSTRAINT; Schema: Acervo; Owner: -
--

ALTER TABLE ONLY "Acervo"."assunto_obra"
    ADD CONSTRAINT "assunto_obra_pkey" PRIMARY KEY ("assunto_id", "obra_id");


--
-- TOC entry 3013 (class 2606 OID 25654)
-- Name: assunto assunto_pkey; Type: CONSTRAINT; Schema: Acervo; Owner: -
--

ALTER TABLE ONLY "Acervo"."assunto"
    ADD CONSTRAINT "assunto_pkey" PRIMARY KEY ("assunto_id");


--
-- TOC entry 3019 (class 2606 OID 33897)
-- Name: autor_obra autor_obra_pkey; Type: CONSTRAINT; Schema: Acervo; Owner: -
--

ALTER TABLE ONLY "Acervo"."autor_obra"
    ADD CONSTRAINT "autor_obra_pkey" PRIMARY KEY ("obra_id", "autor_id");


--
-- TOC entry 2985 (class 2606 OID 25488)
-- Name: autor autor_pkey; Type: CONSTRAINT; Schema: Acervo; Owner: -
--

ALTER TABLE ONLY "Acervo"."autor"
    ADD CONSTRAINT "autor_pkey" PRIMARY KEY ("autor_id");


--
-- TOC entry 2990 (class 2606 OID 25490)
-- Name: editora editora_pkey; Type: CONSTRAINT; Schema: Acervo; Owner: -
--

ALTER TABLE ONLY "Acervo"."editora"
    ADD CONSTRAINT "editora_pkey" PRIMARY KEY ("editora_id");


--
-- TOC entry 2998 (class 2606 OID 25492)
-- Name: material material_pkey; Type: CONSTRAINT; Schema: Acervo; Owner: -
--

ALTER TABLE ONLY "Acervo"."material"
    ADD CONSTRAINT "material_pkey" PRIMARY KEY ("material_id");


--
-- TOC entry 3006 (class 2606 OID 25494)
-- Name: obra obra_pkey; Type: CONSTRAINT; Schema: Acervo; Owner: -
--

ALTER TABLE ONLY "Acervo"."obra"
    ADD CONSTRAINT "obra_pkey" PRIMARY KEY ("obra_id");


--
-- TOC entry 3008 (class 2606 OID 25496)
-- Name: obra obra_registro_sistema_key; Type: CONSTRAINT; Schema: Acervo; Owner: -
--

ALTER TABLE ONLY "Acervo"."obra"
    ADD CONSTRAINT "obra_registro_sistema_key" UNIQUE ("registro_sistema");


--
-- TOC entry 3017 (class 2606 OID 25656)
-- Name: assunto ukc_assunto_descricao; Type: CONSTRAINT; Schema: Acervo; Owner: -
--

ALTER TABLE ONLY "Acervo"."assunto"
    ADD CONSTRAINT "ukc_assunto_descricao" UNIQUE ("descricao");


--
-- TOC entry 2988 (class 2606 OID 25498)
-- Name: autor ukc_autor_nome_sobrenome; Type: CONSTRAINT; Schema: Acervo; Owner: -
--

ALTER TABLE ONLY "Acervo"."autor"
    ADD CONSTRAINT "ukc_autor_nome_sobrenome" UNIQUE ("nome", "sobrenome");


--
-- TOC entry 2994 (class 2606 OID 25500)
-- Name: editora ukc_editora_nome; Type: CONSTRAINT; Schema: Acervo; Owner: -
--

ALTER TABLE ONLY "Acervo"."editora"
    ADD CONSTRAINT "ukc_editora_nome" UNIQUE ("nome");


--
-- TOC entry 3000 (class 2606 OID 25502)
-- Name: material ukc_material_descricao; Type: CONSTRAINT; Schema: Acervo; Owner: -
--

ALTER TABLE ONLY "Acervo"."material"
    ADD CONSTRAINT "ukc_material_descricao" UNIQUE ("descricao");


--
-- TOC entry 3009 (class 1259 OID 25549)
-- Name: idx_acervo_obra_tmp; Type: INDEX; Schema: Acervo; Owner: -
--

CREATE INDEX "idx_acervo_obra_tmp" ON "Acervo"."acervo-temp" USING "btree" ("to_tsvector"('"portuguese"'::"regconfig", "titulo"), "to_tsvector"('"portuguese"'::"regconfig", "sub_titulo"), "to_tsvector"('"portuguese"'::"regconfig", "assunto"), "to_tsvector"('"portuguese"'::"regconfig", "edicao"), "to_tsvector"('"portuguese"'::"regconfig", "ano"), "to_tsvector"('"portuguese"'::"regconfig", "isbn"), "to_tsvector"('"portuguese"'::"regconfig", "issn"), "to_tsvector"('"portuguese"'::"regconfig", "autor"), "to_tsvector"('"portuguese"'::"regconfig", "tipo_material"), "to_tsvector"('"portuguese"'::"regconfig", "editora"));


--
-- TOC entry 3014 (class 1259 OID 33935)
-- Name: idx_hash_assunto_id; Type: INDEX; Schema: Acervo; Owner: -
--

CREATE INDEX "idx_hash_assunto_id" ON "Acervo"."assunto" USING "hash" ("assunto_id");


--
-- TOC entry 3024 (class 1259 OID 33934)
-- Name: idx_hash_assunto_obra_assunto_id; Type: INDEX; Schema: Acervo; Owner: -
--

CREATE INDEX "idx_hash_assunto_obra_assunto_id" ON "Acervo"."assunto_obra" USING "hash" ("assunto_id");


--
-- TOC entry 3025 (class 1259 OID 33933)
-- Name: idx_hash_assunto_obra_obra_id; Type: INDEX; Schema: Acervo; Owner: -
--

CREATE INDEX "idx_hash_assunto_obra_obra_id" ON "Acervo"."assunto_obra" USING "hash" ("obra_id");


--
-- TOC entry 2986 (class 1259 OID 33932)
-- Name: idx_hash_autor_id; Type: INDEX; Schema: Acervo; Owner: -
--

CREATE INDEX "idx_hash_autor_id" ON "Acervo"."autor" USING "hash" ("autor_id");


--
-- TOC entry 3020 (class 1259 OID 33930)
-- Name: idx_hash_autor_obra_autor_id; Type: INDEX; Schema: Acervo; Owner: -
--

CREATE INDEX "idx_hash_autor_obra_autor_id" ON "Acervo"."autor_obra" USING "hash" ("autor_id");


--
-- TOC entry 3021 (class 1259 OID 33931)
-- Name: idx_hash_autor_obra_obra_id; Type: INDEX; Schema: Acervo; Owner: -
--

CREATE INDEX "idx_hash_autor_obra_obra_id" ON "Acervo"."autor_obra" USING "hash" ("obra_id");


--
-- TOC entry 2991 (class 1259 OID 33886)
-- Name: idx_hash_editora_id; Type: INDEX; Schema: Acervo; Owner: -
--

CREATE INDEX "idx_hash_editora_id" ON "Acervo"."editora" USING "hash" ("editora_id");


--
-- TOC entry 2995 (class 1259 OID 33885)
-- Name: idx_hash_material_id; Type: INDEX; Schema: Acervo; Owner: -
--

CREATE INDEX "idx_hash_material_id" ON "Acervo"."material" USING "hash" ("material_id");


--
-- TOC entry 3001 (class 1259 OID 33883)
-- Name: idx_hash_obra_editora; Type: INDEX; Schema: Acervo; Owner: -
--

CREATE INDEX "idx_hash_obra_editora" ON "Acervo"."obra" USING "hash" ("editora_id");


--
-- TOC entry 3002 (class 1259 OID 33884)
-- Name: idx_hash_obra_material; Type: INDEX; Schema: Acervo; Owner: -
--

CREATE INDEX "idx_hash_obra_material" ON "Acervo"."obra" USING "hash" ("material_id");


--
-- TOC entry 3003 (class 1259 OID 33875)
-- Name: idx_hash_obra_registro_sistema; Type: INDEX; Schema: Acervo; Owner: -
--

CREATE INDEX "idx_hash_obra_registro_sistema" ON "Acervo"."obra" USING "hash" ("registro_sistema");


--
-- TOC entry 3010 (class 1259 OID 33870)
-- Name: idx_hash_registro_sistema; Type: INDEX; Schema: Acervo; Owner: -
--

CREATE INDEX "idx_hash_registro_sistema" ON "Acervo"."acervo-temp" USING "hash" ("registro_sistema");


--
-- TOC entry 3015 (class 1259 OID 25689)
-- Name: idx_ts_assunto; Type: INDEX; Schema: Acervo; Owner: -
--

CREATE INDEX "idx_ts_assunto" ON "Acervo"."assunto" USING "gin" ("ts");


--
-- TOC entry 2992 (class 1259 OID 25688)
-- Name: idx_ts_editora; Type: INDEX; Schema: Acervo; Owner: -
--

CREATE INDEX "idx_ts_editora" ON "Acervo"."editora" USING "gin" ("ts");


--
-- TOC entry 2996 (class 1259 OID 25690)
-- Name: idx_ts_material; Type: INDEX; Schema: Acervo; Owner: -
--

CREATE INDEX "idx_ts_material" ON "Acervo"."material" USING "gin" ("ts");


--
-- TOC entry 3004 (class 1259 OID 25691)
-- Name: idx_ts_obra; Type: INDEX; Schema: Acervo; Owner: -
--

CREATE INDEX "idx_ts_obra" ON "Acervo"."obra" USING "gin" ("ts");


--
-- TOC entry 3011 (class 1259 OID 25551)
-- Name: index_titulo; Type: INDEX; Schema: Acervo; Owner: -
--

CREATE INDEX "index_titulo" ON "Acervo"."acervo-temp" USING "btree" ("titulo" COLLATE "C" "text_pattern_ops" DESC NULLS LAST);


--
-- TOC entry 3036 (class 2620 OID 25685)
-- Name: assunto tsvector_update; Type: TRIGGER; Schema: Acervo; Owner: -
--

CREATE TRIGGER "tsvector_update" BEFORE INSERT OR UPDATE ON "Acervo"."assunto" FOR EACH ROW EXECUTE FUNCTION "tsvector_update_trigger"('ts', 'pg_catalog.portuguese', 'descricao');


--
-- TOC entry 3032 (class 2620 OID 25684)
-- Name: autor tsvector_update; Type: TRIGGER; Schema: Acervo; Owner: -
--

CREATE TRIGGER "tsvector_update" BEFORE INSERT OR UPDATE ON "Acervo"."autor" FOR EACH ROW EXECUTE FUNCTION "tsvector_update_trigger"('ts', 'pg_catalog.portuguese', 'nome');


--
-- TOC entry 3033 (class 2620 OID 25683)
-- Name: editora tsvector_update; Type: TRIGGER; Schema: Acervo; Owner: -
--

CREATE TRIGGER "tsvector_update" BEFORE INSERT OR UPDATE ON "Acervo"."editora" FOR EACH ROW EXECUTE FUNCTION "tsvector_update_trigger"('ts', 'pg_catalog.portuguese', 'nome');


--
-- TOC entry 3034 (class 2620 OID 25686)
-- Name: material tsvector_update; Type: TRIGGER; Schema: Acervo; Owner: -
--

CREATE TRIGGER "tsvector_update" BEFORE INSERT OR UPDATE ON "Acervo"."material" FOR EACH ROW EXECUTE FUNCTION "tsvector_update_trigger"('ts', 'pg_catalog.portuguese', 'descricao');


--
-- TOC entry 3035 (class 2620 OID 25682)
-- Name: obra tsvector_update; Type: TRIGGER; Schema: Acervo; Owner: -
--

CREATE TRIGGER "tsvector_update" BEFORE INSERT OR UPDATE ON "Acervo"."obra" FOR EACH ROW EXECUTE FUNCTION "tsvector_update_trigger"('ts', 'pg_catalog.portuguese', 'titulo', 'sub_titulo', 'ano');


--
-- TOC entry 3030 (class 2606 OID 33979)
-- Name: assunto_obra fkc_assunto_obra_assunto_id; Type: FK CONSTRAINT; Schema: Acervo; Owner: -
--

ALTER TABLE ONLY "Acervo"."assunto_obra"
    ADD CONSTRAINT "fkc_assunto_obra_assunto_id" FOREIGN KEY ("assunto_id") REFERENCES "Acervo"."assunto"("assunto_id") NOT VALID;


--
-- TOC entry 3031 (class 2606 OID 33984)
-- Name: assunto_obra fkc_assunto_obra_obra_id; Type: FK CONSTRAINT; Schema: Acervo; Owner: -
--

ALTER TABLE ONLY "Acervo"."assunto_obra"
    ADD CONSTRAINT "fkc_assunto_obra_obra_id" FOREIGN KEY ("obra_id") REFERENCES "Acervo"."obra"("obra_id") NOT VALID;


--
-- TOC entry 3029 (class 2606 OID 33994)
-- Name: autor_obra fkc_autor_obra_autor_id; Type: FK CONSTRAINT; Schema: Acervo; Owner: -
--

ALTER TABLE ONLY "Acervo"."autor_obra"
    ADD CONSTRAINT "fkc_autor_obra_autor_id" FOREIGN KEY ("autor_id") REFERENCES "Acervo"."autor"("autor_id") NOT VALID;


--
-- TOC entry 3028 (class 2606 OID 33989)
-- Name: autor_obra fkc_autor_obra_obra_id; Type: FK CONSTRAINT; Schema: Acervo; Owner: -
--

ALTER TABLE ONLY "Acervo"."autor_obra"
    ADD CONSTRAINT "fkc_autor_obra_obra_id" FOREIGN KEY ("obra_id") REFERENCES "Acervo"."obra"("obra_id") NOT VALID;


--
-- TOC entry 3026 (class 2606 OID 33999)
-- Name: obra fkc_obra_editora_id; Type: FK CONSTRAINT; Schema: Acervo; Owner: -
--

ALTER TABLE ONLY "Acervo"."obra"
    ADD CONSTRAINT "fkc_obra_editora_id" FOREIGN KEY ("editora_id") REFERENCES "Acervo"."editora"("editora_id") NOT VALID;


--
-- TOC entry 3027 (class 2606 OID 34004)
-- Name: obra fkc_obra_material_id; Type: FK CONSTRAINT; Schema: Acervo; Owner: -
--

ALTER TABLE ONLY "Acervo"."obra"
    ADD CONSTRAINT "fkc_obra_material_id" FOREIGN KEY ("material_id") REFERENCES "Acervo"."material"("material_id") NOT VALID;


-- Completed on 2020-08-03 20:27:23

--
-- PostgreSQL database dump complete
--

