CREATE TABLE IF NOT EXISTS "auth"."mfa_factors"(
 "id" uuid   NOT NULL ,
 "user_id" uuid   NOT NULL ,
 "friendly_name" text   ,
 "factor_type" auth.factor_type   NOT NULL ,
 "status" auth.factor_status   NOT NULL ,
 "created_at" timestamp with time zone   NOT NULL ,
 "updated_at" timestamp with time zone   NOT NULL ,
 "secret" text   ,
 "phone" text   ,
 "last_challenged_at" timestamp with time zone   ,
 "web_authn_credential" jsonb   ,
 "web_authn_aaguid" uuid   ,
 "last_webauthn_challenge_data" jsonb   
);
