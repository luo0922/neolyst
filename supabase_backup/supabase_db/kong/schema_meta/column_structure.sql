CREATE TABLE IF NOT EXISTS "kong"."schema_meta"(
 "key" text   NOT NULL ,
 "subsystem" text   NOT NULL ,
 "last_executed" text   ,
 "executed" text[]   ,
 "pending" text[]   
);
