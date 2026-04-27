CREATE TABLE IF NOT EXISTS "dataset_0aece77c_f8b8_484a_8322_78b538ecc038_vector"."lightrag_vdb_relation"(
 "id" character varying(255)   NOT NULL ,
 "workspace" character varying(255)   NOT NULL ,
 "source_id" character varying(512)   ,
 "target_id" character varying(512)   ,
 "content" text   ,
 "content_vector" vector(1024)   ,
 "create_time" timestamp(0) without time zone  DEFAULT CURRENT_TIMESTAMP   ,
 "update_time" timestamp(0) without time zone  DEFAULT CURRENT_TIMESTAMP   ,
 "chunk_ids" character varying(255)[]   ,
 "file_path" text   
);
