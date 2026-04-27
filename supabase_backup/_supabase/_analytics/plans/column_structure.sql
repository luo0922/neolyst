CREATE TABLE IF NOT EXISTS "_analytics"."plans"(
 "id" bigserial   NOT NULL ,
 "name" character varying(255)   ,
 "stripe_id" character varying(255)   ,
 "inserted_at" timestamp(0) without time zone   NOT NULL ,
 "updated_at" timestamp(0) without time zone   NOT NULL ,
 "period" character varying(255)   ,
 "price" integer   ,
 "limit_sources" integer   ,
 "limit_rate_limit" integer   ,
 "limit_alert_freq" integer   ,
 "limit_source_rate_limit" integer   ,
 "limit_saved_search_limit" integer   ,
 "limit_team_users_limit" integer   ,
 "limit_source_fields_limit" integer   ,
 "limit_source_ttl" bigint  DEFAULT 259200000   ,
 "type" character varying(255)  DEFAULT 'standard'::character varying   
);
