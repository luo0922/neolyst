CREATE TABLE IF NOT EXISTS "kong"."filter_chains"(
 "id" uuid   NOT NULL ,
 "name" text   ,
 "enabled" boolean  DEFAULT true   ,
 "route_id" uuid   ,
 "service_id" uuid   ,
 "ws_id" uuid   ,
 "cache_key" text   ,
 "filters" jsonb[]   ,
 "tags" text[]   ,
 "created_at" timestamp with time zone   ,
 "updated_at" timestamp with time zone   
);
