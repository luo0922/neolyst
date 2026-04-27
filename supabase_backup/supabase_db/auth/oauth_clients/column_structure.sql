CREATE TABLE IF NOT EXISTS "auth"."oauth_clients"(
 "id" uuid   NOT NULL ,
 "client_secret_hash" text   ,
 "registration_type" auth.oauth_registration_type   NOT NULL ,
 "redirect_uris" text   NOT NULL ,
 "grant_types" text   NOT NULL ,
 "client_name" text   ,
 "client_uri" text   ,
 "logo_uri" text   ,
 "created_at" timestamp with time zone  DEFAULT now()   NOT NULL ,
 "updated_at" timestamp with time zone  DEFAULT now()   NOT NULL ,
 "deleted_at" timestamp with time zone   ,
 "client_type" auth.oauth_client_type  DEFAULT 'confidential'::auth.oauth_client_type   NOT NULL 
);
