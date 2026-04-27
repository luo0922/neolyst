CREATE TABLE IF NOT EXISTS "kong"."sessions"(
 "id" uuid   NOT NULL ,
 "session_id" text   ,
 "expires" integer   ,
 "data" text   ,
 "created_at" timestamp with time zone   ,
 "ttl" timestamp with time zone   
);
