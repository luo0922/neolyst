CREATE TABLE IF NOT EXISTS "auth"."sessions"(
 "id" uuid   NOT NULL ,
 "user_id" uuid   NOT NULL ,
 "created_at" timestamp with time zone   ,
 "updated_at" timestamp with time zone   ,
 "factor_id" uuid   ,
 "aal" auth.aal_level   ,
 "not_after" timestamp with time zone   ,
 "refreshed_at" timestamp without time zone   ,
 "user_agent" text   ,
 "ip" inet   ,
 "tag" text   ,
 "oauth_client_id" uuid   
);
