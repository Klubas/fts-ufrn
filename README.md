# fts-ufrn

## FTS Acervo UFRN

Implementação de busca textual usando técnicas de FTS e comparando com uma busca sem FTS.

### Uso (API)

    curl --header "Content-Type: application/json" --request POST --data '{\"query\": \"Assim falou Zaratustra\", \"type\": \"FTS\"}' http://localhost:5000/busca_acervo/

### Uso (DB):

Chamar o método de busca no banco de dados informando o termo e o tipo de busca desejada:

	SELECT "Acervo".busca_acervo(
		'Assim falou zaratustra', 
		'FTS'
	);

	SELECT "Acervo".busca_acervo(
		'Assim falou zaratustra', 
		'Normal'
	);


### Backup
	
	pg_dump.exe --file "...\\fts-ufrn\\scripts\\database.sql" --host "localhost" --port "5432" --username "postgres" --verbose --quote-all-identifiers --format=p --schema-only --no-owner --encoding "UTF8" --schema "\"Acervo\"" "postgres"
	
	pg_dump.exe --file "...\\fts-ufrn\\scripts\\database_dump.backup" --host "localhost" --port "5432" --username "postgres" --verbose --quote-all-identifiers --format=c --blobs --data-only --no-owner --encoding "UTF8" --schema "\"Acervo\"" "postgres"
