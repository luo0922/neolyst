CREATE TABLE IF NOT EXISTS "storage"."s3_multipart_uploads_parts"(
 "id" uuid  DEFAULT gen_random_uuid()   NOT NULL ,
 "upload_id" text   NOT NULL ,
 "size" bigint  DEFAULT 0   NOT NULL ,
 "part_number" integer   NOT NULL ,
 "bucket_id" text   NOT NULL ,
 "key" text   NOT NULL ,
 "etag" text   NOT NULL ,
 "owner_id" text   ,
 "version" text   NOT NULL ,
 "created_at" timestamp with time zone  DEFAULT now()   NOT NULL 
);
