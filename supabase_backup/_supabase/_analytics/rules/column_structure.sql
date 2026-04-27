CREATE TABLE IF NOT EXISTS "_analytics"."rules"(
 "id" bigserial   NOT NULL ,
 "regex" character varying(255)   ,
 "sink" uuid   ,
 "source_id" bigint   NOT NULL ,
 "inserted_at" timestamp(0) without time zone   NOT NULL ,
 "updated_at" timestamp(0) without time zone   NOT NULL ,
 "regex_struct" bytea   ,
 "lql_string" text  DEFAULT ''::text   NOT NULL ,
 "lql_filters" bytea  DEFAULT '\x836a'::bytea   NOT NULL ,
 "backend_id" bigint   ,
 "token" uuid  DEFAULT gen_random_uuid()   
);
