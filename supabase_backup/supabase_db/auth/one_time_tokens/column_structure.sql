CREATE TABLE IF NOT EXISTS "auth"."one_time_tokens"(
 "id" uuid   NOT NULL ,
 "user_id" uuid   NOT NULL ,
 "token_type" auth.one_time_token_type   NOT NULL ,
 "token_hash" text   NOT NULL ,
 "relates_to" text   NOT NULL ,
 "created_at" timestamp without time zone  DEFAULT now()   NOT NULL ,
 "updated_at" timestamp without time zone  DEFAULT now()   NOT NULL 
);
