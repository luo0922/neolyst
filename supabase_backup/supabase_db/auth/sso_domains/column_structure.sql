CREATE TABLE IF NOT EXISTS "auth"."sso_domains"(
 "id" uuid   NOT NULL ,
 "sso_provider_id" uuid   NOT NULL ,
 "domain" text   NOT NULL ,
 "created_at" timestamp with time zone   ,
 "updated_at" timestamp with time zone   
);
