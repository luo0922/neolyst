CREATE TABLE IF NOT EXISTS "_analytics"."backends"(
 "id" bigserial   NOT NULL ,
 "name" character varying(255)   ,
 "description" text   ,
 "user_id" bigint   ,
 "type" character varying(255)   ,
 "config" jsonb   ,
 "inserted_at" timestamp(0) without time zone   NOT NULL ,
 "updated_at" timestamp(0) without time zone   NOT NULL ,
 "token" uuid   NOT NULL ,
 "metadata" jsonb   ,
 "config_encrypted" bytea   ,
 "default_ingest" boolean  DEFAULT false   
);
