CREATE TABLE IF NOT EXISTS "kong"."certificates"(
 "id" uuid   NOT NULL ,
 "created_at" timestamp with time zone  DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'::text)   ,
 "cert" text   ,
 "key" text   ,
 "tags" text[]   ,
 "ws_id" uuid   ,
 "cert_alt" text   ,
 "key_alt" text   ,
 "updated_at" timestamp with time zone  DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'::text)   
);
