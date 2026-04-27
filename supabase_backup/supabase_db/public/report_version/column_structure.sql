CREATE TABLE IF NOT EXISTS "public"."report_version"(
 "id" uuid  DEFAULT gen_random_uuid()   NOT NULL ,
 "report_id" uuid   NOT NULL ,
 "version_no" integer   NOT NULL ,
 "snapshot_json" jsonb  DEFAULT '{}'::jsonb   NOT NULL ,
 "word_file_path" text   ,
 "model_file_path" text   ,
 "changed_by" uuid   NOT NULL ,
 "changed_at" timestamp with time zone  DEFAULT now()   NOT NULL ,
 "created_at" timestamp with time zone  DEFAULT now()   NOT NULL ,
 "word_file_name" text   ,
 "model_file_name" text   ,
 "pdf_file_path" text   ,
 "pdf_file_name" text   
);
