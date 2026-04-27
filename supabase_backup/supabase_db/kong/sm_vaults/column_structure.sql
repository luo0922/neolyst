CREATE TABLE IF NOT EXISTS "kong"."sm_vaults"(
 "id" uuid   NOT NULL ,
 "ws_id" uuid   ,
 "prefix" text   ,
 "name" text   NOT NULL ,
 "description" text   ,
 "config" jsonb   NOT NULL ,
 "created_at" timestamp with time zone  DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'::text)   ,
 "updated_at" timestamp with time zone   ,
 "tags" text[]   
);
