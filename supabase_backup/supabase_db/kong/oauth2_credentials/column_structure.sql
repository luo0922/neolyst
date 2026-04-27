CREATE TABLE IF NOT EXISTS "kong"."oauth2_credentials"(
 "id" uuid   NOT NULL ,
 "created_at" timestamp with time zone  DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'::text)   ,
 "name" text   ,
 "consumer_id" uuid   ,
 "client_id" text   ,
 "client_secret" text   ,
 "redirect_uris" text[]   ,
 "tags" text[]   ,
 "client_type" text   ,
 "hash_secret" boolean   ,
 "ws_id" uuid   
);
