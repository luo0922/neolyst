CREATE TABLE IF NOT EXISTS "kong"."targets"(
 "id" uuid   NOT NULL ,
 "created_at" timestamp with time zone  DEFAULT (CURRENT_TIMESTAMP(3) AT TIME ZONE 'UTC'::text)   ,
 "upstream_id" uuid   ,
 "target" text   NOT NULL ,
 "weight" integer   NOT NULL ,
 "tags" text[]   ,
 "ws_id" uuid   ,
 "cache_key" text   ,
 "updated_at" timestamp with time zone  DEFAULT (CURRENT_TIMESTAMP(3) AT TIME ZONE 'UTC'::text)   
);
