CREATE TABLE IF NOT EXISTS "public"."rating"(
 "id" uuid  DEFAULT gen_random_uuid()   NOT NULL ,
 "name" text   NOT NULL ,
 "code" text   NOT NULL ,
 "sort" integer  DEFAULT 1   NOT NULL ,
 "is_active" boolean  DEFAULT true   NOT NULL ,
 "created_at" timestamp with time zone  DEFAULT now()   NOT NULL 
);
