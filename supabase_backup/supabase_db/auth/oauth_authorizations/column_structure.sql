CREATE TABLE IF NOT EXISTS "auth"."oauth_authorizations"(
 "id" uuid   NOT NULL ,
 "authorization_id" text   NOT NULL ,
 "client_id" uuid   NOT NULL ,
 "user_id" uuid   ,
 "redirect_uri" text   NOT NULL ,
 "scope" text   NOT NULL ,
 "state" text   ,
 "resource" text   ,
 "code_challenge" text   ,
 "code_challenge_method" auth.code_challenge_method   ,
 "response_type" auth.oauth_response_type  DEFAULT 'code'::auth.oauth_response_type   NOT NULL ,
 "status" auth.oauth_authorization_status  DEFAULT 'pending'::auth.oauth_authorization_status   NOT NULL ,
 "authorization_code" text   ,
 "created_at" timestamp with time zone  DEFAULT now()   NOT NULL ,
 "expires_at" timestamp with time zone  DEFAULT (now() + '00:03:00'::interval)   NOT NULL ,
 "approved_at" timestamp with time zone   
);
