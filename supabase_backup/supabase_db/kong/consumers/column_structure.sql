CREATE TABLE IF NOT EXISTS "kong"."consumers"(
 "id" uuid   NOT NULL ,
 "created_at" timestamp with time zone  DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'::text)   ,
 "username" text   ,
 "custom_id" text   ,
 "tags" text[]   ,
 "ws_id" uuid   ,
 "updated_at" timestamp with time zone  DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'::text)   
);
