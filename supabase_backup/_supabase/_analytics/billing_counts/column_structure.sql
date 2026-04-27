CREATE TABLE IF NOT EXISTS "_analytics"."billing_counts"(
 "id" bigserial   NOT NULL ,
 "node" character varying(255)   ,
 "count" integer   ,
 "user_id" bigint   ,
 "source_id" bigint   ,
 "inserted_at" timestamp(0) without time zone   NOT NULL ,
 "updated_at" timestamp(0) without time zone   NOT NULL 
);
