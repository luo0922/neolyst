CREATE TABLE IF NOT EXISTS "kong"."oauth2_authorization_codes"(
 "id" uuid   NOT NULL ,
 "created_at" timestamp with time zone  DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'::text)   ,
 "credential_id" uuid   ,
 "service_id" uuid   ,
 "code" text   ,
 "authenticated_userid" text   ,
 "scope" text   ,
 "ttl" timestamp with time zone   ,
 "challenge" text   ,
 "challenge_method" text   ,
 "ws_id" uuid   ,
 "plugin_id" uuid   
);
