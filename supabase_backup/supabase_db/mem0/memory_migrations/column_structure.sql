CREATE TABLE IF NOT EXISTS "mem0"."memory_migrations"(
 "id" serial   NOT NULL ,
 "user_id" text   NOT NULL ,
 "migrated_at" timestamp with time zone  DEFAULT CURRENT_TIMESTAMP   ,
 "migration_version" text   ,
 "metadata" jsonb   
);
