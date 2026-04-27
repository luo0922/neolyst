CREATE TABLE IF NOT EXISTS "auth"."identities"(
 "provider_id" text   NOT NULL ,
 "user_id" uuid   NOT NULL ,
 "identity_data" jsonb   NOT NULL ,
 "provider" text   NOT NULL ,
 "last_sign_in_at" timestamp with time zone   ,
 "created_at" timestamp with time zone   ,
 "updated_at" timestamp with time zone   ,
 "id" uuid  DEFAULT gen_random_uuid()   NOT NULL 
);
