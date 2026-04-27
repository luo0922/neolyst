CREATE TABLE IF NOT EXISTS "kong"."oauth2_tokens"(
 "id" uuid   NOT NULL ,
 "created_at" timestamp with time zone  DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'::text)   ,
 "credential_id" uuid   ,
 "service_id" uuid   ,
 "access_token" text   ,
 "refresh_token" text   ,
 "token_type" text   ,
 "expires_in" integer   ,
 "authenticated_userid" text   ,
 "scope" text   ,
 "ttl" timestamp with time zone   ,
 "ws_id" uuid   
);
