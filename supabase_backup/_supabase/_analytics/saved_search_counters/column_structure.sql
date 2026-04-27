CREATE TABLE IF NOT EXISTS "_analytics"."saved_search_counters"(
 "id" bigserial   NOT NULL ,
 "timestamp" timestamp without time zone   NOT NULL ,
 "saved_search_id" bigint   NOT NULL ,
 "granularity" text  DEFAULT 'day'::text   NOT NULL ,
 "non_tailing_count" integer   ,
 "tailing_count" integer   
);
