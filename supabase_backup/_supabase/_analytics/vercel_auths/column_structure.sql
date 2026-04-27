CREATE TABLE IF NOT EXISTS "_analytics"."vercel_auths"(
 "id" bigserial   NOT NULL ,
 "access_token" character varying(255)   ,
 "installation_id" character varying(255)   ,
 "team_id" character varying(255)   ,
 "token_type" character varying(255)   ,
 "vercel_user_id" character varying(255)   ,
 "user_id" bigint   ,
 "inserted_at" timestamp(0) without time zone   NOT NULL ,
 "updated_at" timestamp(0) without time zone   NOT NULL 
);
