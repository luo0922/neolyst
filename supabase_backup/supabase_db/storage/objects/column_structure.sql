CREATE TABLE IF NOT EXISTS "storage"."objects"(
 "id" uuid  DEFAULT gen_random_uuid()   NOT NULL ,
 "bucket_id" text   ,
 "name" text   ,
 "owner" uuid   ,
 "created_at" timestamp with time zone  DEFAULT now()   ,
 "updated_at" timestamp with time zone  DEFAULT now()   ,
 "last_accessed_at" timestamp with time zone  DEFAULT now()   ,
 "metadata" jsonb   ,
 "version" text   ,
 "owner_id" text   ,
 "user_metadata" jsonb   ,
 "level" integer   
);
