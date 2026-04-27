CREATE TABLE IF NOT EXISTS "auth"."oauth_consents"(
 "id" uuid   NOT NULL ,
 "user_id" uuid   NOT NULL ,
 "client_id" uuid   NOT NULL ,
 "scopes" text   NOT NULL ,
 "granted_at" timestamp with time zone  DEFAULT now()   NOT NULL ,
 "revoked_at" timestamp with time zone   
);
