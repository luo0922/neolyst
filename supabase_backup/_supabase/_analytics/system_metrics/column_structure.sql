CREATE TABLE IF NOT EXISTS "_analytics"."system_metrics"(
 "id" bigserial   NOT NULL ,
 "all_logs_logged" bigint   ,
 "node" character varying(255)   ,
 "inserted_at" timestamp(0) without time zone   NOT NULL ,
 "updated_at" timestamp(0) without time zone   NOT NULL 
);
