CREATE TABLE IF NOT EXISTS "_analytics"."saved_searches"(
 "id" bigserial   NOT NULL ,
 "querystring" text   ,
 "source_id" bigint   ,
 "inserted_at" timestamp(0) without time zone   NOT NULL ,
 "updated_at" timestamp(0) without time zone   NOT NULL ,
 "saved_by_user" boolean   ,
 "lql_filters" jsonb   ,
 "lql_charts" jsonb   ,
 "tailing?" boolean  DEFAULT true   NOT NULL ,
 "tailing" boolean  DEFAULT true   NOT NULL 
);
