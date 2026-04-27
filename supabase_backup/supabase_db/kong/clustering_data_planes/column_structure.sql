CREATE TABLE IF NOT EXISTS "kong"."clustering_data_planes"(
 "id" uuid   NOT NULL ,
 "hostname" text   NOT NULL ,
 "ip" text   NOT NULL ,
 "last_seen" timestamp with time zone  DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'::text)   ,
 "config_hash" text   NOT NULL ,
 "ttl" timestamp with time zone   ,
 "version" text   ,
 "sync_status" text  DEFAULT 'unknown'::text   NOT NULL ,
 "updated_at" timestamp with time zone  DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'::text)   ,
 "labels" jsonb   ,
 "cert_details" jsonb   ,
 "rpc_capabilities" text[]   
);
