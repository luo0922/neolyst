CREATE TABLE IF NOT EXISTS "public"."chief_approve"(
 "id" uuid  DEFAULT gen_random_uuid()   NOT NULL ,
 "report_id" uuid   NOT NULL ,
 "file_path" text   NOT NULL ,
 "file_name" text   NOT NULL ,
 "file_type" text   NOT NULL ,
 "created_at" timestamp with time zone  DEFAULT now()   NOT NULL 
);
