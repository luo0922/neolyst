CREATE TABLE IF NOT EXISTS "storage"."prefixes"(
 "bucket_id" text   NOT NULL ,
 "name" text   NOT NULL ,
 "created_at" timestamp with time zone  DEFAULT now()   ,
 "updated_at" timestamp with time zone  DEFAULT now()   
);
