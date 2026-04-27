CREATE TABLE IF NOT EXISTS "storage"."s3_multipart_uploads"(
 "id" text   NOT NULL ,
 "in_progress_size" bigint  DEFAULT 0   NOT NULL ,
 "upload_signature" text   NOT NULL ,
 "bucket_id" text   NOT NULL ,
 "key" text   NOT NULL ,
 "version" text   NOT NULL ,
 "owner_id" text   ,
 "created_at" timestamp with time zone  DEFAULT now()   NOT NULL ,
 "user_metadata" jsonb   
);
