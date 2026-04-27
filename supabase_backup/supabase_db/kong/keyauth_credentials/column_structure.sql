CREATE TABLE IF NOT EXISTS "kong"."keyauth_credentials"(
 "id" uuid   NOT NULL ,
 "created_at" timestamp with time zone  DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'::text)   ,
 "consumer_id" uuid   ,
 "key" text   ,
 "tags" text[]   ,
 "ttl" timestamp with time zone   ,
 "ws_id" uuid   
);
