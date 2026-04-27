CREATE TABLE IF NOT EXISTS "_analytics"."oauth_access_grants"(
 "id" bigserial   NOT NULL ,
 "resource_owner_id" integer   NOT NULL ,
 "application_id" bigint   ,
 "token" character varying(255)   NOT NULL ,
 "expires_in" integer   NOT NULL ,
 "redirect_uri" text   NOT NULL ,
 "revoked_at" timestamp(0) without time zone   ,
 "scopes" character varying(255)   ,
 "inserted_at" timestamp(0) without time zone   NOT NULL 
);
