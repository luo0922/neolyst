CREATE TABLE IF NOT EXISTS "storage"."migrations"(
 "id" integer   NOT NULL ,
 "name" character varying(100)   NOT NULL ,
 "hash" character varying(40)   NOT NULL ,
 "executed_at" timestamp without time zone  DEFAULT CURRENT_TIMESTAMP   
);
