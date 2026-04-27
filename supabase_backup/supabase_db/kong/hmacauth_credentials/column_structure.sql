CREATE TABLE IF NOT EXISTS "kong"."hmacauth_credentials"(
 "id" uuid   NOT NULL ,
 "created_at" timestamp with time zone  DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'::text)   ,
 "consumer_id" uuid   ,
 "username" text   ,
 "secret" text   ,
 "tags" text[]   ,
 "ws_id" uuid   
);
