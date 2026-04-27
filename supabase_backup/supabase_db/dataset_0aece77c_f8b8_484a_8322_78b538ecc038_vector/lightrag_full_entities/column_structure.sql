CREATE TABLE IF NOT EXISTS "dataset_0aece77c_f8b8_484a_8322_78b538ecc038_vector"."lightrag_full_entities"(
 "id" character varying(255)   NOT NULL ,
 "workspace" character varying(255)   NOT NULL ,
 "entity_names" jsonb   ,
 "count" integer   ,
 "create_time" timestamp(0) without time zone  DEFAULT CURRENT_TIMESTAMP   ,
 "update_time" timestamp(0) without time zone  DEFAULT CURRENT_TIMESTAMP   
);
