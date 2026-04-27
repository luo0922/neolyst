CREATE TABLE IF NOT EXISTS "public"."template"(
 "id" uuid  DEFAULT gen_random_uuid()   NOT NULL ,
 "name" text   NOT NULL ,
 "report_type" text   NOT NULL ,
 "template_file_path" text   NOT NULL ,
 "uploaded_by" uuid   ,
 "created_at" timestamp with time zone  DEFAULT now()   NOT NULL ,
 "updated_at" timestamp with time zone  DEFAULT now()   NOT NULL ,
 "language" text  DEFAULT 'en'::text   NOT NULL ,
 "schema_file_path" text   ,
 "sort" integer  DEFAULT 0   NOT NULL ,
 "version" integer  DEFAULT 1   NOT NULL 
);
