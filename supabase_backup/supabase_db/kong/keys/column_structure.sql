CREATE TABLE IF NOT EXISTS "kong"."keys"(
 "id" uuid   NOT NULL ,
 "set_id" uuid   ,
 "name" text   ,
 "cache_key" text   ,
 "ws_id" uuid   ,
 "kid" text   ,
 "jwk" text   ,
 "pem" jsonb   ,
 "tags" text[]   ,
 "created_at" timestamp with time zone   ,
 "updated_at" timestamp with time zone   
);
