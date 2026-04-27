CREATE TABLE IF NOT EXISTS "kong"."jwt_secrets"(
 "id" uuid   NOT NULL ,
 "created_at" timestamp with time zone  DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'::text)   ,
 "consumer_id" uuid   ,
 "key" text   ,
 "secret" text   ,
 "algorithm" text   ,
 "rsa_public_key" text   ,
 "tags" text[]   ,
 "ws_id" uuid   
);
