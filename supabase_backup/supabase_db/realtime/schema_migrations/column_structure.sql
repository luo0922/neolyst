CREATE TABLE IF NOT EXISTS "realtime"."schema_migrations"(
 "version" bigint   NOT NULL ,
 "inserted_at" timestamp without time zone  DEFAULT now()   NOT NULL 
);
