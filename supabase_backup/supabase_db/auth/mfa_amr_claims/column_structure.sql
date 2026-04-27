CREATE TABLE IF NOT EXISTS "auth"."mfa_amr_claims"(
 "session_id" uuid   NOT NULL ,
 "created_at" timestamp with time zone   NOT NULL ,
 "updated_at" timestamp with time zone   NOT NULL ,
 "authentication_method" text   NOT NULL ,
 "id" uuid   NOT NULL 
);
