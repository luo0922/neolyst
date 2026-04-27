CREATE TABLE IF NOT EXISTS "_supavisor"."cluster_tenants"(
 "id" uuid   NOT NULL ,
 "type" character varying(255)   NOT NULL ,
 "active" boolean  DEFAULT false   NOT NULL ,
 "cluster_alias" character varying(255)   ,
 "tenant_external_id" character varying(255)   ,
 "inserted_at" timestamp(0) without time zone   NOT NULL ,
 "updated_at" timestamp(0) without time zone   NOT NULL 
);
