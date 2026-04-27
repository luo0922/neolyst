CREATE TABLE IF NOT EXISTS "auth"."flow_state"(
 "id" uuid   NOT NULL ,
 "user_id" uuid   ,
 "auth_code" text   NOT NULL ,
 "code_challenge_method" auth.code_challenge_method   NOT NULL ,
 "code_challenge" text   NOT NULL ,
 "provider_type" text   NOT NULL ,
 "provider_access_token" text   ,
 "provider_refresh_token" text   ,
 "created_at" timestamp with time zone   ,
 "updated_at" timestamp with time zone   ,
 "authentication_method" text   NOT NULL ,
 "auth_code_issued_at" timestamp with time zone   
);
