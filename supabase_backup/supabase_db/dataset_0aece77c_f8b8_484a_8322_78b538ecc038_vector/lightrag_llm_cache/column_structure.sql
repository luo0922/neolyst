CREATE TABLE IF NOT EXISTS "dataset_0aece77c_f8b8_484a_8322_78b538ecc038_vector"."lightrag_llm_cache"(
 "workspace" character varying(255)   NOT NULL ,
 "id" character varying(255)   NOT NULL ,
 "original_prompt" text   ,
 "return_value" text   ,
 "chunk_id" character varying(255)   ,
 "cache_type" character varying(32)   ,
 "queryparam" jsonb   ,
 "create_time" timestamp without time zone  DEFAULT CURRENT_TIMESTAMP   ,
 "update_time" timestamp without time zone  DEFAULT CURRENT_TIMESTAMP   
);
