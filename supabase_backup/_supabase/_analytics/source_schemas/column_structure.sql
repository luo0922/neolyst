CREATE TABLE IF NOT EXISTS "_analytics"."source_schemas"(
 "id" bigserial   NOT NULL ,
 "bigquery_schema" bytea   ,
 "source_id" bigint   ,
 "inserted_at" timestamp(0) without time zone   NOT NULL ,
 "updated_at" timestamp(0) without time zone   NOT NULL ,
 "schema_flat_map" bytea   
);
