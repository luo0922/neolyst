CREATE TABLE IF NOT EXISTS "dataset_0aece77c_f8b8_484a_8322_78b538ecc038_vector"."lightrag_vdb_skills"(
 "id" character varying(255)   NOT NULL ,
 "workspace" character varying(255)   NOT NULL ,
 "skill_id" character varying(255)   ,
 "chunk_id" character varying(255)   ,
 "chunk_type" character varying(64)   ,
 "content" text   ,
 "content_vector" vector(1024)   ,
 "metadata" jsonb   ,
 "create_time" timestamp(0) without time zone  DEFAULT CURRENT_TIMESTAMP   ,
 "update_time" timestamp(0) without time zone  DEFAULT CURRENT_TIMESTAMP   
);
