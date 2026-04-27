CREATE TABLE IF NOT EXISTS "_supavisor"."users"(
 "id" uuid   NOT NULL ,
 "db_user_alias" character varying(255)   NOT NULL ,
 "db_user" character varying(255)   NOT NULL ,
 "db_pass_encrypted" bytea   NOT NULL ,
 "pool_size" integer   NOT NULL ,
 "mode_type" character varying(255)   NOT NULL ,
 "is_manager" boolean  DEFAULT false   NOT NULL ,
 "tenant_external_id" character varying(255)   ,
 "inserted_at" timestamp(0) without time zone   NOT NULL ,
 "updated_at" timestamp(0) without time zone   NOT NULL ,
 "pool_checkout_timeout" integer  DEFAULT 60000   NOT NULL ,
 "max_clients" integer   
);
