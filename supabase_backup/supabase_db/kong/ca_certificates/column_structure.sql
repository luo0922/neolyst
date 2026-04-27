CREATE TABLE IF NOT EXISTS "kong"."ca_certificates"(
 "id" uuid   NOT NULL ,
 "created_at" timestamp with time zone  DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'::text)   ,
 "cert" text   NOT NULL ,
 "tags" text[]   ,
 "cert_digest" text   NOT NULL ,
 "updated_at" timestamp with time zone  DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'::text)   
);
