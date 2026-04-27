CREATE TABLE IF NOT EXISTS "dataset_0aece77c_f8b8_484a_8322_78b538ecc038_vector"."lightrag_vdb_chunks"(
 "id" character varying(255)   NOT NULL ,
 "workspace" character varying(255)   NOT NULL ,
 "full_doc_id" character varying(256)   ,
 "chunk_order_index" integer   ,
 "tokens" integer   ,
 "content" text   ,
 "content_vector" vector(1024)   ,
 "file_path" text   ,
 "create_time" timestamp(0) without time zone  DEFAULT CURRENT_TIMESTAMP   ,
 "update_time" timestamp(0) without time zone  DEFAULT CURRENT_TIMESTAMP   
);
