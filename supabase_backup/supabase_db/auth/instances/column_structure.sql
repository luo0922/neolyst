CREATE TABLE IF NOT EXISTS "auth"."instances"(
 "id" uuid   NOT NULL ,
 "uuid" uuid   ,
 "raw_base_config" text   ,
 "created_at" timestamp with time zone   ,
 "updated_at" timestamp with time zone   
);
