CREATE TABLE IF NOT EXISTS "dataset_0aece77c_f8b8_484a_8322_78b538ecc038_vector"."lightrag_skills"(
 "id" character varying(255)   NOT NULL ,
 "workspace" character varying(255)   NOT NULL ,
 "name" character varying(255)   ,
 "version" character varying(64)   ,
 "author" character varying(255)   ,
 "description" text   ,
 "tags" jsonb   ,
 "entrypoint" text   ,
 "dependencies" jsonb   ,
 "compatibility" jsonb   ,
 "readme_text" text   ,
 "sha256" character varying(128)   ,
 "size_bytes" bigint   ,
 "visibility" character varying(32)   ,
 "storage_path" text   ,
 "create_time" timestamp(0) without time zone  DEFAULT CURRENT_TIMESTAMP   ,
 "update_time" timestamp(0) without time zone  DEFAULT CURRENT_TIMESTAMP   
);
