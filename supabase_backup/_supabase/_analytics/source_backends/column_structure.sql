CREATE TABLE IF NOT EXISTS "_analytics"."source_backends"(
 "id" bigserial   NOT NULL ,
 "source_id" bigint   ,
 "type" character varying(255)   ,
 "config" jsonb   ,
 "inserted_at" timestamp(0) without time zone   NOT NULL ,
 "updated_at" timestamp(0) without time zone   NOT NULL 
);
