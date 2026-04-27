CREATE TABLE IF NOT EXISTS "kong"."acls"(
 "id" uuid   NOT NULL ,
 "created_at" timestamp with time zone  DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'::text)   ,
 "consumer_id" uuid   ,
 "group" text   ,
 "cache_key" text   ,
 "tags" text[]   ,
 "ws_id" uuid   
);
