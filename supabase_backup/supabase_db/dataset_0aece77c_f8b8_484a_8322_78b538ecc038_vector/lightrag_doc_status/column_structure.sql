CREATE TABLE IF NOT EXISTS "dataset_0aece77c_f8b8_484a_8322_78b538ecc038_vector"."lightrag_doc_status"(
 "workspace" character varying(255)   NOT NULL ,
 "id" character varying(255)   NOT NULL ,
 "content_summary" character varying(255)   ,
 "content_length" integer   ,
 "chunks_count" integer   ,
 "status" character varying(64)   ,
 "file_path" text   ,
 "chunks_list" jsonb  DEFAULT '[]'::jsonb   ,
 "track_id" character varying(255)   ,
 "metadata" jsonb  DEFAULT '{}'::jsonb   ,
 "error_msg" text   ,
 "created_at" timestamp without time zone  DEFAULT CURRENT_TIMESTAMP   ,
 "updated_at" timestamp without time zone  DEFAULT CURRENT_TIMESTAMP   
);
