CREATE TABLE IF NOT EXISTS "_analytics"."oauth_access_tokens"(
 "id" bigserial   NOT NULL ,
 "application_id" bigint   ,
 "resource_owner_id" integer   ,
 "token" character varying(255)   NOT NULL ,
 "refresh_token" character varying(255)   ,
 "expires_in" integer   ,
 "revoked_at" timestamp(0) without time zone   ,
 "scopes" character varying(255)   ,
 "previous_refresh_token" character varying(255)  DEFAULT ''::character varying   NOT NULL ,
 "inserted_at" timestamp(0) without time zone   NOT NULL ,
 "updated_at" timestamp(0) without time zone   NOT NULL ,
 "description" text   
);
