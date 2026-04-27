CREATE TABLE IF NOT EXISTS "auth"."mfa_challenges"(
 "id" uuid   NOT NULL ,
 "factor_id" uuid   NOT NULL ,
 "created_at" timestamp with time zone   NOT NULL ,
 "verified_at" timestamp with time zone   ,
 "ip_address" inet   NOT NULL ,
 "otp_code" text   ,
 "web_authn_session_data" jsonb   
);
