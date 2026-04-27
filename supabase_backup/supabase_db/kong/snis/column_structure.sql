CREATE TABLE IF NOT EXISTS "kong"."snis"(
 "id" uuid   NOT NULL ,
 "created_at" timestamp with time zone  DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'::text)   ,
 "name" text   NOT NULL ,
 "certificate_id" uuid   ,
 "tags" text[]   ,
 "ws_id" uuid   ,
 "updated_at" timestamp with time zone  DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'::text)   
);
