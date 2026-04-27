CREATE TABLE IF NOT EXISTS "_analytics"."team_users"(
 "id" bigserial   NOT NULL ,
 "email" character varying(255)   ,
 "token" text   ,
 "provider" character varying(255)   ,
 "email_preferred" character varying(255)   ,
 "name" character varying(255)   ,
 "image" character varying(255)   ,
 "email_me_product" boolean  DEFAULT false   NOT NULL ,
 "phone" character varying(255)   ,
 "valid_google_account" boolean  DEFAULT false   NOT NULL ,
 "provider_uid" text   ,
 "team_id" bigint   ,
 "inserted_at" timestamp(0) without time zone   NOT NULL ,
 "updated_at" timestamp(0) without time zone   NOT NULL ,
 "preferences" jsonb   
);
