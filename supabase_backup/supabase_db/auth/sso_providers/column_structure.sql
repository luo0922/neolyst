CREATE TABLE IF NOT EXISTS "auth"."sso_providers"(
 "id" uuid   NOT NULL ,
 "resource_id" text   ,
 "created_at" timestamp with time zone   ,
 "updated_at" timestamp with time zone   ,
 "disabled" boolean   
);
