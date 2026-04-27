CREATE TABLE IF NOT EXISTS "auth"."refresh_tokens"(
 "instance_id" uuid   ,
 "id" bigserial   NOT NULL ,
 "token" character varying(255)   ,
 "user_id" character varying(255)   ,
 "revoked" boolean   ,
 "created_at" timestamp with time zone   ,
 "updated_at" timestamp with time zone   ,
 "parent" character varying(255)   ,
 "session_id" uuid   
);
