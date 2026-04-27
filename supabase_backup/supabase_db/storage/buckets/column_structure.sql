CREATE TABLE IF NOT EXISTS "storage"."buckets"(
 "id" text   NOT NULL ,
 "name" text   NOT NULL ,
 "owner" uuid   ,
 "created_at" timestamp with time zone  DEFAULT now()   ,
 "updated_at" timestamp with time zone  DEFAULT now()   ,
 "public" boolean  DEFAULT false   ,
 "avif_autodetection" boolean  DEFAULT false   ,
 "file_size_limit" bigint   ,
 "allowed_mime_types" text[]   ,
 "owner_id" text   
);
