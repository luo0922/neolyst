CREATE TABLE IF NOT EXISTS "_realtime"."extensions"(
 "id" uuid   NOT NULL ,
 "type" text   ,
 "settings" jsonb   ,
 "tenant_external_id" text   ,
 "inserted_at" timestamp(0) without time zone   NOT NULL ,
 "updated_at" timestamp(0) without time zone   NOT NULL 
);
