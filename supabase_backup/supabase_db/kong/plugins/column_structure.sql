CREATE TABLE IF NOT EXISTS "kong"."plugins"(
 "id" uuid   NOT NULL ,
 "created_at" timestamp with time zone  DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'::text)   ,
 "name" text   NOT NULL ,
 "consumer_id" uuid   ,
 "service_id" uuid   ,
 "route_id" uuid   ,
 "config" jsonb   NOT NULL ,
 "enabled" boolean   NOT NULL ,
 "cache_key" text   ,
 "protocols" text[]   ,
 "tags" text[]   ,
 "ws_id" uuid   ,
 "instance_name" text   ,
 "updated_at" timestamp with time zone  DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'::text)   
);
