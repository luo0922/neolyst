CREATE TABLE IF NOT EXISTS "kong"."key_sets"(
 "id" uuid   NOT NULL ,
 "name" text   ,
 "tags" text[]   ,
 "ws_id" uuid   ,
 "created_at" timestamp with time zone   ,
 "updated_at" timestamp with time zone   
);
