CREATE TABLE IF NOT EXISTS "kong"."acme_storage"(
 "id" uuid   NOT NULL ,
 "key" text   ,
 "value" text   ,
 "created_at" timestamp with time zone   ,
 "ttl" timestamp with time zone   
);
