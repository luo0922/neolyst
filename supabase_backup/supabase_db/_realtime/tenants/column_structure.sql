CREATE TABLE IF NOT EXISTS "_realtime"."tenants"(
 "id" uuid   NOT NULL ,
 "name" text   ,
 "external_id" text   ,
 "jwt_secret" text   ,
 "max_concurrent_users" integer  DEFAULT 200   NOT NULL ,
 "inserted_at" timestamp(0) without time zone   NOT NULL ,
 "updated_at" timestamp(0) without time zone   NOT NULL ,
 "max_events_per_second" integer  DEFAULT 100   NOT NULL ,
 "postgres_cdc_default" text  DEFAULT 'postgres_cdc_rls'::text   ,
 "max_bytes_per_second" integer  DEFAULT 100000   NOT NULL ,
 "max_channels_per_client" integer  DEFAULT 100   NOT NULL ,
 "max_joins_per_second" integer  DEFAULT 500   NOT NULL ,
 "suspend" boolean  DEFAULT false   ,
 "jwt_jwks" jsonb   ,
 "notify_private_alpha" boolean  DEFAULT false   ,
 "private_only" boolean  DEFAULT false   NOT NULL 
);
