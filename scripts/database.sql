--
-- PostgreSQL database dump
--

-- Dumped from database version 12.3
-- Dumped by pg_dump version 12.3

-- Started on 2020-07-31 23:11:12

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
-- Name: Acervo; Type: SCHEMA; Schema: -; Owner: lucas
--

CREATE SCHEMA "Acervo";


ALTER SCHEMA "Acervo" OWNER TO "lucas";

--
-- TOC entry 345 (class 1255 OID 25770)
-- Name: clear_db(); Type: PROCEDURE; Schema: Acervo; Owner: postgres
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


ALTER PROCEDURE "Acervo"."clear_db"() OWNER TO "postgres";

--
-- TOC entry 347 (class 1255 OID 25706)
-- Name: fts_busca_acervo("text"); Type: FUNCTION; Schema: Acervo; Owner: postgres
--

CREATE FUNCTION "Acervo"."fts_busca_acervo"("p_value" "text") RETURNS "json"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
	v_query text := p_value;
	v_result RECORD;
	v_results json[] := '{}';

BEGIN
	-- https://www.postgresql.org/docs/12/textsearch.html
	-- https://www.postgresql.eu/events/fosdem2020/sessions/session/2890/slides/273/FTS.pdf
	FOR v_result IN  
	 SELECT 
		concat(
			obra.titulo, ' ',
			obra.sub_titulo, ' ',
			assunto.descricao, ' ',
			editora.nome, ' ',
			autor.nome, ' ',
			obra.ano, ' '
		) fts_result
	   FROM "Acervo".obra obra
		 LEFT JOIN "Acervo".autor_obra autor_obra ON obra.obra_id = autor_obra.obra_id
		 LEFT JOIN "Acervo".autor autor ON autor.autor_id = autor_obra.autor_id
		 JOIN "Acervo".editora editora ON obra.editora_id = editora.editora_id
		 LEFT JOIN "Acervo".assunto_obra ON obra.obra_id = assunto_obra.obra_id
		 LEFT JOIN "Acervo".assunto ON assunto.assunto_id = assunto_obra.assunto_id
		 LEFT JOIN "Acervo".material ON material.material_id = obra.material_id
		 WHERE (obra.ts || autor.ts || editora.ts || material.ts || assunto.ts) @@ plainto_tsquery ('portuguese', v_query)
	LOOP
		v_results := v_results || to_json(v_result);
	END LOOP;
	
	RETURN to_json(v_results);
	
END;
$$;


ALTER FUNCTION "Acervo"."fts_busca_acervo"("p_value" "text") OWNER TO "postgres";

--
-- TOC entry 348 (class 1255 OID 25705)
-- Name: normal_busca_acervo("text"); Type: FUNCTION; Schema: Acervo; Owner: postgres
--

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


ALTER FUNCTION "Acervo"."normal_busca_acervo"("p_value" "text") OWNER TO "postgres";

--
-- TOC entry 346 (class 1255 OID 25437)
-- Name: populate_db(integer, integer); Type: PROCEDURE; Schema: Acervo; Owner: postgres
--

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


ALTER PROCEDURE "Acervo"."populate_db"("registro_inicial" integer, "registro_final" integer) OWNER TO "postgres";

--
-- TOC entry 344 (class 1255 OID 25769)
-- Name: populate_db_transactions(); Type: PROCEDURE; Schema: Acervo; Owner: postgres
--

CREATE PROCEDURE "Acervo"."populate_db_transactions"()
    LANGUAGE "plpgsql"
    AS $$
BEGIN
start transaction; call "Acervo".populate_db(	1		,	4819	); commit;
start transaction; call "Acervo".populate_db(	4820	,	14819	); commit;
start transaction; call "Acervo".populate_db(	14820	,	24819	); commit;
start transaction; call "Acervo".populate_db(	24820	,	34819	); commit;
start transaction; call "Acervo".populate_db(	34820	,	44819	); commit;
start transaction; call "Acervo".populate_db(	44820	,	54819	); commit;
start transaction; call "Acervo".populate_db(	54820	,	64819	); commit;
start transaction; call "Acervo".populate_db(	64820	,	74819	); commit;
start transaction; call "Acervo".populate_db(	74820	,	84819	); commit;
start transaction; call "Acervo".populate_db(	84820	,	94819	); commit;
start transaction; call "Acervo".populate_db(	94820	,	104819	); commit;
start transaction; call "Acervo".populate_db(	104820	,	114819	); commit;
start transaction; call "Acervo".populate_db(	114820	,	124819	); commit;
start transaction; call "Acervo".populate_db(	124820	,	134819	); commit;
start transaction; call "Acervo".populate_db(	134820	,	144819	); commit;
start transaction; call "Acervo".populate_db(	144820	,	154819	); commit;
start transaction; call "Acervo".populate_db(	154820	,	164819	); commit;
start transaction; call "Acervo".populate_db(	164820	,	174819	); commit;
start transaction; call "Acervo".populate_db(	174820	,	184819	); commit;
start transaction; call "Acervo".populate_db(	184820	,	194819	); commit;
start transaction; call "Acervo".populate_db(	194820	,	204819	); commit;
start transaction; call "Acervo".populate_db(	204820	,	214819	); commit;
start transaction; call "Acervo".populate_db(	214820	,	224819	); commit;
start transaction; call "Acervo".populate_db(	224820	,	234819	); commit;
start transaction; call "Acervo".populate_db(	234820	,	244819	); commit;
start transaction; call "Acervo".populate_db(	244820	,	254819	); commit;
start transaction; call "Acervo".populate_db(	254820	,	264819	); commit;
end;
$$;


ALTER PROCEDURE "Acervo"."populate_db_transactions"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";

--
-- TOC entry 281 (class 1259 OID 25543)
-- Name: acervo-temp; Type: TABLE; Schema: Acervo; Owner: lucas
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


ALTER TABLE "Acervo"."acervo-temp" OWNER TO "lucas";

--
-- TOC entry 283 (class 1259 OID 25644)
-- Name: assunto_assunto_id_seq; Type: SEQUENCE; Schema: Acervo; Owner: lucas
--

CREATE SEQUENCE "Acervo"."assunto_assunto_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "Acervo"."assunto_assunto_id_seq" OWNER TO "lucas";

--
-- TOC entry 284 (class 1259 OID 25646)
-- Name: assunto; Type: TABLE; Schema: Acervo; Owner: postgres
--

CREATE TABLE "Acervo"."assunto" (
    "assunto_id" bigint DEFAULT "nextval"('"Acervo"."assunto_assunto_id_seq"'::"regclass") NOT NULL,
    "descricao" "text" NOT NULL,
    "ts" "tsvector"
);


ALTER TABLE "Acervo"."assunto" OWNER TO "postgres";

--
-- TOC entry 282 (class 1259 OID 25614)
-- Name: assunto_obra; Type: TABLE; Schema: Acervo; Owner: postgres
--

CREATE TABLE "Acervo"."assunto_obra" (
    "assunto_id" integer NOT NULL,
    "obra_id" integer NOT NULL
);


ALTER TABLE "Acervo"."assunto_obra" OWNER TO "postgres";

--
-- TOC entry 272 (class 1259 OID 25446)
-- Name: autor; Type: TABLE; Schema: Acervo; Owner: lucas
--

CREATE TABLE "Acervo"."autor" (
    "nome" "text" NOT NULL,
    "sobrenome" "text",
    "autor_id" bigint NOT NULL,
    "ts" "tsvector"
);


ALTER TABLE "Acervo"."autor" OWNER TO "lucas";

--
-- TOC entry 273 (class 1259 OID 25452)
-- Name: autor_autor_id_seq; Type: SEQUENCE; Schema: Acervo; Owner: lucas
--

CREATE SEQUENCE "Acervo"."autor_autor_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "Acervo"."autor_autor_id_seq" OWNER TO "lucas";

--
-- TOC entry 3178 (class 0 OID 0)
-- Dependencies: 273
-- Name: autor_autor_id_seq; Type: SEQUENCE OWNED BY; Schema: Acervo; Owner: lucas
--

ALTER SEQUENCE "Acervo"."autor_autor_id_seq" OWNED BY "Acervo"."autor"."autor_id";


--
-- TOC entry 274 (class 1259 OID 25454)
-- Name: autor_obra; Type: TABLE; Schema: Acervo; Owner: lucas
--

CREATE TABLE "Acervo"."autor_obra" (
    "autor_id" integer NOT NULL,
    "obra_id" integer NOT NULL
);


ALTER TABLE "Acervo"."autor_obra" OWNER TO "lucas";

--
-- TOC entry 275 (class 1259 OID 25457)
-- Name: editora; Type: TABLE; Schema: Acervo; Owner: lucas
--

CREATE TABLE "Acervo"."editora" (
    "nome" "text" NOT NULL,
    "editora_id" bigint NOT NULL,
    "ts" "tsvector"
);


ALTER TABLE "Acervo"."editora" OWNER TO "lucas";

--
-- TOC entry 276 (class 1259 OID 25463)
-- Name: editora_editora_id_seq; Type: SEQUENCE; Schema: Acervo; Owner: lucas
--

CREATE SEQUENCE "Acervo"."editora_editora_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "Acervo"."editora_editora_id_seq" OWNER TO "lucas";

--
-- TOC entry 3179 (class 0 OID 0)
-- Dependencies: 276
-- Name: editora_editora_id_seq; Type: SEQUENCE OWNED BY; Schema: Acervo; Owner: lucas
--

ALTER SEQUENCE "Acervo"."editora_editora_id_seq" OWNED BY "Acervo"."editora"."editora_id";


--
-- TOC entry 277 (class 1259 OID 25465)
-- Name: material; Type: TABLE; Schema: Acervo; Owner: lucas
--

CREATE TABLE "Acervo"."material" (
    "descricao" "text" NOT NULL,
    "material_id" bigint NOT NULL,
    "ts" "tsvector"
);


ALTER TABLE "Acervo"."material" OWNER TO "lucas";

--
-- TOC entry 278 (class 1259 OID 25471)
-- Name: material_material_id_seq; Type: SEQUENCE; Schema: Acervo; Owner: lucas
--

CREATE SEQUENCE "Acervo"."material_material_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "Acervo"."material_material_id_seq" OWNER TO "lucas";

--
-- TOC entry 3180 (class 0 OID 0)
-- Dependencies: 278
-- Name: material_material_id_seq; Type: SEQUENCE OWNED BY; Schema: Acervo; Owner: lucas
--

ALTER SEQUENCE "Acervo"."material_material_id_seq" OWNED BY "Acervo"."material"."material_id";


--
-- TOC entry 279 (class 1259 OID 25473)
-- Name: obra; Type: TABLE; Schema: Acervo; Owner: lucas
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


ALTER TABLE "Acervo"."obra" OWNER TO "lucas";

--
-- TOC entry 280 (class 1259 OID 25479)
-- Name: obra_obra_id_seq; Type: SEQUENCE; Schema: Acervo; Owner: lucas
--

CREATE SEQUENCE "Acervo"."obra_obra_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "Acervo"."obra_obra_id_seq" OWNER TO "lucas";

--
-- TOC entry 3181 (class 0 OID 0)
-- Dependencies: 280
-- Name: obra_obra_id_seq; Type: SEQUENCE OWNED BY; Schema: Acervo; Owner: lucas
--

ALTER SEQUENCE "Acervo"."obra_obra_id_seq" OWNED BY "Acervo"."obra"."obra_id";


--
-- TOC entry 285 (class 1259 OID 25697)
-- Name: view_acervo; Type: VIEW; Schema: Acervo; Owner: postgres
--

CREATE VIEW "Acervo"."view_acervo" AS
 SELECT "obra"."titulo",
    "obra"."sub_titulo",
    "assunto"."descricao" AS "assunto",
    "editora"."nome" AS "editora",
    "autor"."nome" AS "autor",
    "obra"."ano"
   FROM ((((("Acervo"."obra" "obra"
     LEFT JOIN "Acervo"."autor_obra" "autor_obra" ON (("obra"."obra_id" = "autor_obra"."obra_id")))
     LEFT JOIN "Acervo"."autor" "autor" ON (("autor"."autor_id" = "autor_obra"."autor_id")))
     JOIN "Acervo"."editora" "editora" ON (("obra"."editora_id" = "editora"."editora_id")))
     JOIN "Acervo"."assunto_obra" ON (("obra"."obra_id" = "assunto_obra"."obra_id")))
     JOIN "Acervo"."assunto" ON (("assunto"."assunto_id" = "assunto_obra"."assunto_id")));


ALTER TABLE "Acervo"."view_acervo" OWNER TO "postgres";

--
-- TOC entry 2973 (class 2604 OID 25481)
-- Name: autor autor_id; Type: DEFAULT; Schema: Acervo; Owner: lucas
--

ALTER TABLE ONLY "Acervo"."autor" ALTER COLUMN "autor_id" SET DEFAULT "nextval"('"Acervo"."autor_autor_id_seq"'::"regclass");


--
-- TOC entry 2974 (class 2604 OID 25482)
-- Name: editora editora_id; Type: DEFAULT; Schema: Acervo; Owner: lucas
--

ALTER TABLE ONLY "Acervo"."editora" ALTER COLUMN "editora_id" SET DEFAULT "nextval"('"Acervo"."editora_editora_id_seq"'::"regclass");


--
-- TOC entry 2975 (class 2604 OID 25483)
-- Name: material material_id; Type: DEFAULT; Schema: Acervo; Owner: lucas
--

ALTER TABLE ONLY "Acervo"."material" ALTER COLUMN "material_id" SET DEFAULT "nextval"('"Acervo"."material_material_id_seq"'::"regclass");


--
-- TOC entry 2976 (class 2604 OID 25484)
-- Name: obra obra_id; Type: DEFAULT; Schema: Acervo; Owner: lucas
--

ALTER TABLE ONLY "Acervo"."obra" ALTER COLUMN "obra_id" SET DEFAULT "nextval"('"Acervo"."obra_obra_id_seq"'::"regclass");


--
-- TOC entry 3011 (class 2606 OID 25618)
-- Name: assunto_obra assunto_obra_pkey; Type: CONSTRAINT; Schema: Acervo; Owner: postgres
--

ALTER TABLE ONLY "Acervo"."assunto_obra"
    ADD CONSTRAINT "assunto_obra_pkey" PRIMARY KEY ("assunto_id", "obra_id");


--
-- TOC entry 3014 (class 2606 OID 25654)
-- Name: assunto assunto_pkey; Type: CONSTRAINT; Schema: Acervo; Owner: postgres
--

ALTER TABLE ONLY "Acervo"."assunto"
    ADD CONSTRAINT "assunto_pkey" PRIMARY KEY ("assunto_id");


--
-- TOC entry 2984 (class 2606 OID 25486)
-- Name: autor_obra autor_obra_pkey; Type: CONSTRAINT; Schema: Acervo; Owner: lucas
--

ALTER TABLE ONLY "Acervo"."autor_obra"
    ADD CONSTRAINT "autor_obra_pkey" PRIMARY KEY ("obra_id", "autor_id");


--
-- TOC entry 2979 (class 2606 OID 25488)
-- Name: autor autor_pkey; Type: CONSTRAINT; Schema: Acervo; Owner: lucas
--

ALTER TABLE ONLY "Acervo"."autor"
    ADD CONSTRAINT "autor_pkey" PRIMARY KEY ("autor_id");


--
-- TOC entry 2988 (class 2606 OID 25490)
-- Name: editora editora_pkey; Type: CONSTRAINT; Schema: Acervo; Owner: lucas
--

ALTER TABLE ONLY "Acervo"."editora"
    ADD CONSTRAINT "editora_pkey" PRIMARY KEY ("editora_id");


--
-- TOC entry 2996 (class 2606 OID 25492)
-- Name: material material_pkey; Type: CONSTRAINT; Schema: Acervo; Owner: lucas
--

ALTER TABLE ONLY "Acervo"."material"
    ADD CONSTRAINT "material_pkey" PRIMARY KEY ("material_id");


--
-- TOC entry 3004 (class 2606 OID 25494)
-- Name: obra obra_pkey; Type: CONSTRAINT; Schema: Acervo; Owner: lucas
--

ALTER TABLE ONLY "Acervo"."obra"
    ADD CONSTRAINT "obra_pkey" PRIMARY KEY ("obra_id");


--
-- TOC entry 3006 (class 2606 OID 25496)
-- Name: obra obra_registro_sistema_key; Type: CONSTRAINT; Schema: Acervo; Owner: lucas
--

ALTER TABLE ONLY "Acervo"."obra"
    ADD CONSTRAINT "obra_registro_sistema_key" UNIQUE ("registro_sistema");


--
-- TOC entry 3018 (class 2606 OID 25656)
-- Name: assunto ukc_assunto_descricao; Type: CONSTRAINT; Schema: Acervo; Owner: postgres
--

ALTER TABLE ONLY "Acervo"."assunto"
    ADD CONSTRAINT "ukc_assunto_descricao" UNIQUE ("descricao");


--
-- TOC entry 2982 (class 2606 OID 25498)
-- Name: autor ukc_autor_nome_sobrenome; Type: CONSTRAINT; Schema: Acervo; Owner: lucas
--

ALTER TABLE ONLY "Acervo"."autor"
    ADD CONSTRAINT "ukc_autor_nome_sobrenome" UNIQUE ("nome", "sobrenome");


--
-- TOC entry 2992 (class 2606 OID 25500)
-- Name: editora ukc_editora_nome; Type: CONSTRAINT; Schema: Acervo; Owner: lucas
--

ALTER TABLE ONLY "Acervo"."editora"
    ADD CONSTRAINT "ukc_editora_nome" UNIQUE ("nome");


--
-- TOC entry 2998 (class 2606 OID 25502)
-- Name: material ukc_material_descricao; Type: CONSTRAINT; Schema: Acervo; Owner: lucas
--

ALTER TABLE ONLY "Acervo"."material"
    ADD CONSTRAINT "ukc_material_descricao" UNIQUE ("descricao");


--
-- TOC entry 3007 (class 1259 OID 25549)
-- Name: idx_acervo_obra_tmp; Type: INDEX; Schema: Acervo; Owner: lucas
--

CREATE INDEX "idx_acervo_obra_tmp" ON "Acervo"."acervo-temp" USING "btree" ("to_tsvector"('"portuguese"'::"regconfig", "titulo"), "to_tsvector"('"portuguese"'::"regconfig", "sub_titulo"), "to_tsvector"('"portuguese"'::"regconfig", "assunto"), "to_tsvector"('"portuguese"'::"regconfig", "edicao"), "to_tsvector"('"portuguese"'::"regconfig", "ano"), "to_tsvector"('"portuguese"'::"regconfig", "isbn"), "to_tsvector"('"portuguese"'::"regconfig", "issn"), "to_tsvector"('"portuguese"'::"regconfig", "autor"), "to_tsvector"('"portuguese"'::"regconfig", "tipo_material"), "to_tsvector"('"portuguese"'::"regconfig", "editora"));


--
-- TOC entry 2985 (class 1259 OID 25503)
-- Name: idx_ao_autor; Type: INDEX; Schema: Acervo; Owner: lucas
--

CREATE INDEX "idx_ao_autor" ON "Acervo"."autor_obra" USING "btree" ("autor_id");


--
-- TOC entry 2986 (class 1259 OID 25504)
-- Name: idx_ao_obra; Type: INDEX; Schema: Acervo; Owner: lucas
--

CREATE INDEX "idx_ao_obra" ON "Acervo"."autor_obra" USING "btree" ("obra_id");


--
-- TOC entry 3015 (class 1259 OID 25658)
-- Name: idx_assunto_id; Type: INDEX; Schema: Acervo; Owner: postgres
--

CREATE INDEX "idx_assunto_id" ON "Acervo"."assunto" USING "btree" ("assunto_id" DESC NULLS LAST);


--
-- TOC entry 3012 (class 1259 OID 25619)
-- Name: idx_assunto_obra; Type: INDEX; Schema: Acervo; Owner: postgres
--

CREATE INDEX "idx_assunto_obra" ON "Acervo"."assunto_obra" USING "btree" ("assunto_id", "obra_id");


--
-- TOC entry 2980 (class 1259 OID 25510)
-- Name: idx_autor_id; Type: INDEX; Schema: Acervo; Owner: lucas
--

CREATE INDEX "idx_autor_id" ON "Acervo"."autor" USING "btree" ("autor_id" DESC NULLS LAST);


--
-- TOC entry 2989 (class 1259 OID 25512)
-- Name: idx_editora_id; Type: INDEX; Schema: Acervo; Owner: lucas
--

CREATE INDEX "idx_editora_id" ON "Acervo"."editora" USING "btree" ("editora_id" DESC NULLS LAST);


--
-- TOC entry 2993 (class 1259 OID 25514)
-- Name: idx_material_id; Type: INDEX; Schema: Acervo; Owner: lucas
--

CREATE INDEX "idx_material_id" ON "Acervo"."material" USING "btree" ("material_id" DESC NULLS LAST);


--
-- TOC entry 2999 (class 1259 OID 25505)
-- Name: idx_obra_editora; Type: INDEX; Schema: Acervo; Owner: lucas
--

CREATE INDEX "idx_obra_editora" ON "Acervo"."obra" USING "btree" ("editora_id" DESC);


--
-- TOC entry 3000 (class 1259 OID 25516)
-- Name: idx_obra_id; Type: INDEX; Schema: Acervo; Owner: lucas
--

CREATE INDEX "idx_obra_id" ON "Acervo"."obra" USING "btree" ("obra_id" DESC NULLS LAST);


--
-- TOC entry 3001 (class 1259 OID 25506)
-- Name: idx_obra_registro; Type: INDEX; Schema: Acervo; Owner: lucas
--

CREATE INDEX "idx_obra_registro" ON "Acervo"."obra" USING "btree" ("registro_sistema" DESC);


--
-- TOC entry 3008 (class 1259 OID 25550)
-- Name: idx_registro_sistema_tmp; Type: INDEX; Schema: Acervo; Owner: lucas
--

CREATE INDEX "idx_registro_sistema_tmp" ON "Acervo"."acervo-temp" USING "btree" ("registro_sistema");


--
-- TOC entry 3016 (class 1259 OID 25689)
-- Name: idx_ts_assunto; Type: INDEX; Schema: Acervo; Owner: postgres
--

CREATE INDEX "idx_ts_assunto" ON "Acervo"."assunto" USING "gin" ("ts");


--
-- TOC entry 2990 (class 1259 OID 25688)
-- Name: idx_ts_editora; Type: INDEX; Schema: Acervo; Owner: lucas
--

CREATE INDEX "idx_ts_editora" ON "Acervo"."editora" USING "gin" ("ts");


--
-- TOC entry 2994 (class 1259 OID 25690)
-- Name: idx_ts_material; Type: INDEX; Schema: Acervo; Owner: lucas
--

CREATE INDEX "idx_ts_material" ON "Acervo"."material" USING "gin" ("ts");


--
-- TOC entry 3002 (class 1259 OID 25691)
-- Name: idx_ts_obra; Type: INDEX; Schema: Acervo; Owner: lucas
--

CREATE INDEX "idx_ts_obra" ON "Acervo"."obra" USING "gin" ("ts");


--
-- TOC entry 3009 (class 1259 OID 25551)
-- Name: index_titulo; Type: INDEX; Schema: Acervo; Owner: lucas
--

CREATE INDEX "index_titulo" ON "Acervo"."acervo-temp" USING "btree" ("titulo" COLLATE "C" "text_pattern_ops" DESC NULLS LAST);


--
-- TOC entry 3023 (class 2620 OID 25685)
-- Name: assunto tsvector_update; Type: TRIGGER; Schema: Acervo; Owner: postgres
--

CREATE TRIGGER "tsvector_update" BEFORE INSERT OR UPDATE ON "Acervo"."assunto" FOR EACH ROW EXECUTE FUNCTION "tsvector_update_trigger"('ts', 'pg_catalog.portuguese', 'descricao');


--
-- TOC entry 3019 (class 2620 OID 25684)
-- Name: autor tsvector_update; Type: TRIGGER; Schema: Acervo; Owner: lucas
--

CREATE TRIGGER "tsvector_update" BEFORE INSERT OR UPDATE ON "Acervo"."autor" FOR EACH ROW EXECUTE FUNCTION "tsvector_update_trigger"('ts', 'pg_catalog.portuguese', 'nome');


--
-- TOC entry 3020 (class 2620 OID 25683)
-- Name: editora tsvector_update; Type: TRIGGER; Schema: Acervo; Owner: lucas
--

CREATE TRIGGER "tsvector_update" BEFORE INSERT OR UPDATE ON "Acervo"."editora" FOR EACH ROW EXECUTE FUNCTION "tsvector_update_trigger"('ts', 'pg_catalog.portuguese', 'nome');


--
-- TOC entry 3021 (class 2620 OID 25686)
-- Name: material tsvector_update; Type: TRIGGER; Schema: Acervo; Owner: lucas
--

CREATE TRIGGER "tsvector_update" BEFORE INSERT OR UPDATE ON "Acervo"."material" FOR EACH ROW EXECUTE FUNCTION "tsvector_update_trigger"('ts', 'pg_catalog.portuguese', 'descricao');


--
-- TOC entry 3022 (class 2620 OID 25682)
-- Name: obra tsvector_update; Type: TRIGGER; Schema: Acervo; Owner: lucas
--

CREATE TRIGGER "tsvector_update" BEFORE INSERT OR UPDATE ON "Acervo"."obra" FOR EACH ROW EXECUTE FUNCTION "tsvector_update_trigger"('ts', 'pg_catalog.portuguese', 'titulo', 'sub_titulo', 'ano');


-- Completed on 2020-07-31 23:11:13

--
-- PostgreSQL database dump complete
--

